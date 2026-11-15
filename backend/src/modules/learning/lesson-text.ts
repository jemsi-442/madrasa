import { z } from "zod";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { storeLessonText } from "./local-lesson-media";

const inputSchema = z.object({
  title: z.string().trim().min(1).max(150),
  text: z.string().trim().min(1).max(50000).refine(value => !value.includes("\0")),
  visibility: z.enum(["FREE", "LOCKED"]).default("LOCKED"),
}).strict();

export async function createLessonText(user: AuthenticatedUser, lessonId: string, body: unknown) {
  if (!["ADMIN", "TEACHER"].includes(user.role)) throw new HttpError(403, "Course author access required");
  z.string().regex(/^[1-9][0-9]*$/).max(20).parse(lessonId);
  const input = inputSchema.parse(body);
  const lesson = await prisma.courseLesson.findFirst({
    where: {
      id: BigInt(lessonId), orgId: BigInt(user.orgId),
      course: { orgId: BigInt(user.orgId), ...(user.role === "TEACHER" ? { primaryInstructorUserId: BigInt(user.userId) } : {}) },
    }, select: { id: true, courseId: true },
  });
  if (!lesson) throw new HttpError(404, "Lesson not found in your assigned courses");
  const file = await storeLessonText(user.orgId, input.text);
  try {
    const asset = await prisma.mediaAsset.create({ data: {
      orgId: BigInt(user.orgId), courseId: lesson.courseId, lessonId: lesson.id,
      assetType: "TEXT", storageProvider: "LOCAL", storageKey: file.storageKey,
      title: input.title, mimeType: "text/plain", fileSizeBytes: BigInt(file.fileSizeBytes),
      visibility: input.visibility, downloadAllowed: false,
    }, select: { id: true, title: true, assetType: true, visibility: true } });
    return { ...asset, id: String(asset.id) };
  } catch (error) {
    await file.remove().catch(() => undefined);
    throw error;
  }
}
