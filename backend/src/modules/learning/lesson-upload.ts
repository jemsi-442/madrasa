import { randomUUID } from "node:crypto";
import { mkdir, open, unlink } from "node:fs/promises";
import { join } from "node:path";
import { z } from "zod";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { lessonMediaRoot } from "./local-lesson-media";

export const MAX_LESSON_UPLOAD_BYTES = 50 * 1024 * 1024;
export const MAX_LESSON_VIDEO_UPLOAD_BYTES = 250 * 1024 * 1024;
const formats = {
  pdf: { kind: "PDF", mime: "application/pdf" },
  png: { kind: "ATTACHMENT", mime: "image/png" },
  jpg: { kind: "ATTACHMENT", mime: "image/jpeg" },
  mp4: { kind: "VIDEO", mime: "video/mp4" },
  mp3: { kind: "AUDIO", mime: "audio/mpeg" },
  wav: { kind: "AUDIO", mime: "audio/wav" },
} as const;
const input = z.object({
  title: z.string().trim().min(1).max(150),
  format: z.enum(["pdf", "png", "jpg", "mp4", "mp3", "wav"]),
  visibility: z.enum(["FREE", "LOCKED"]).default("LOCKED"),
}).strict();

function matchesFormat(format: keyof typeof formats, bytes: Buffer) {
  if (bytes.length < 12) return false;
  switch (format) {
    case "pdf": return bytes.subarray(0, 5).toString() === "%PDF-";
    case "png": return bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
    case "jpg": return bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
    case "mp4": return bytes.subarray(4, 8).toString() === "ftyp" &&
      ["isom", "iso2", "mp41", "mp42", "avc1", "M4V "].includes(bytes.subarray(8, 12).toString());
    case "mp3": return bytes.subarray(0, 3).toString() === "ID3" ||
      (bytes[0] === 255 && (bytes[1]! & 0xe0) === 0xe0);
    case "wav": return bytes.subarray(0, 4).toString() === "RIFF" && bytes.subarray(8, 12).toString() === "WAVE";
  }
}

// Streaming avoids buffering a full video in process memory. Only allow opaque keys.
export async function uploadLessonResource(
  user: AuthenticatedUser, lessonId: string, metadata: unknown,
  source: AsyncIterable<Uint8Array>,
) {
  if (!["ADMIN", "TEACHER"].includes(user.role)) throw new HttpError(403, "Course author access required");
  z.string().regex(/^[1-9][0-9]*$/).max(20).parse(lessonId);
  z.string().regex(/^[1-9][0-9]*$/).max(20).parse(user.orgId);
  const fields = input.parse(metadata);
  const limit = fields.format === "mp4" ? MAX_LESSON_VIDEO_UPLOAD_BYTES : MAX_LESSON_UPLOAD_BYTES;
  const lesson = await prisma.courseLesson.findFirst({ where: {
    id: BigInt(lessonId), orgId: BigInt(user.orgId),
    course: { orgId: BigInt(user.orgId), ...(user.role === "TEACHER" ? { primaryInstructorUserId: BigInt(user.userId) } : {}) },
  }, select: { id: true, courseId: true } });
  if (!lesson) throw new HttpError(404, "Lesson not found in your assigned courses");
  const directory = join(lessonMediaRoot(), user.orgId);
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const name = `${randomUUID()}.${fields.format}`;
  const path = join(directory, name);
  const file = await open(path, "wx", 0o600);
  let size = 0;
  let signature = Buffer.alloc(0);
  try {
    for await (const chunk of source) {
      size += chunk.length;
      if (size > limit) throw new HttpError(413, `File exceeds the ${limit / (1024 * 1024)} MB upload limit`);
      if (signature.length < 16) signature = Buffer.concat([signature, Buffer.from(chunk).subarray(0, 16 - signature.length)]);
      await file.writeFile(chunk);
    }
    if (!matchesFormat(fields.format, signature)) throw new HttpError(415, "File content does not match its selected format");
    await file.close();
    // Assignment may have changed during a long upload. Recheck before attaching it.
    const stillAssigned = await prisma.courseLesson.findFirst({ where: {
      id: lesson.id, orgId: BigInt(user.orgId), courseId: lesson.courseId,
      course: { orgId: BigInt(user.orgId), ...(user.role === "TEACHER" ? { primaryInstructorUserId: BigInt(user.userId) } : {}) },
    }, select: { id: true } });
    if (!stillAssigned) throw new HttpError(403, "Course access changed during upload");
    const format = formats[fields.format];
    const asset = await prisma.mediaAsset.create({ data: {
      orgId: BigInt(user.orgId), courseId: lesson.courseId, lessonId: lesson.id,
      title: fields.title, assetType: format.kind, mimeType: format.mime,
      storageProvider: "LOCAL", storageKey: `afaq-file:${user.orgId}/${name}`,
      fileSizeBytes: BigInt(size), visibility: fields.visibility, downloadAllowed: false,
    }, select: { id: true, title: true, assetType: true, visibility: true, mimeType: true } });
    return { ...asset, id: String(asset.id) };
  } catch (error) {
    await file.close().catch(() => undefined);
    await unlink(path).catch(() => undefined);
    throw error;
  }
}
