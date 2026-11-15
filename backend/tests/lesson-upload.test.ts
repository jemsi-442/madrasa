import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";
import { mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
const mocks = vi.hoisted(() => ({ env: { LESSON_MEDIA_DIR: "" }, db: {
  courseLesson: { findFirst: vi.fn() }, mediaAsset: { create: vi.fn() },
} }));
vi.mock("../src/config/env", () => ({ env: mocks.env }));
vi.mock("../src/shared/db/prisma", () => ({ prisma: mocks.db }));
import { uploadLessonResource, MAX_LESSON_UPLOAD_BYTES, MAX_LESSON_VIDEO_UPLOAD_BYTES } from "../src/modules/learning/lesson-upload";
import { localLessonMedia } from "../src/modules/learning/local-lesson-media";
const teacher = { userId: "7", orgId: "2", role: "TEACHER" as const };
const metadata = { title: "Synthetic guide", format: "pdf" };
const pdf = Buffer.from("%PDF-1.7\nSynthetic fixture, not a real document.");
async function* chunks(bytes: Buffer = pdf) { yield bytes.subarray(0, 3); yield bytes.subarray(3); }
describe("lesson file uploads", () => {
  beforeEach(async () => {
    vi.resetAllMocks();
    mocks.env.LESSON_MEDIA_DIR = await mkdtemp(join(tmpdir(), "afaq-upload-test-"));
    mocks.db.courseLesson.findFirst.mockResolvedValue({ id: 9n, courseId: 4n });
    mocks.db.mediaAsset.create.mockResolvedValue({ id: 11n });
  });
  afterEach(async () => { await rm(mocks.env.LESSON_MEDIA_DIR, { recursive: true, force: true }); });
  it("streams a file into private storage and uses a scoped opaque key", async () => {
    expect(await uploadLessonResource(teacher, "9", metadata, chunks())).toEqual({ id: "11" });
    const data = mocks.db.mediaAsset.create.mock.calls[0]![0].data;
    expect(data).toMatchObject({ assetType: "PDF", visibility: "LOCKED", downloadAllowed: false, fileSizeBytes: BigInt(pdf.length) });
    const resource = localLessonMedia(data)!;
    expect(resource.playerKind).toBe("PDF");
    expect(await readFile(resource.filePath)).toEqual(pdf);
    expect(localLessonMedia({ ...data, orgId: 3n })).toBeNull();
    expect(localLessonMedia({ ...data, assetType: "VIDEO" })).toBeNull();
    expect(localLessonMedia({ ...data, storageKey: "afaq-file:2/../../secret.pdf" })).toBeNull();
    expect(mocks.db.courseLesson.findFirst.mock.calls[0]![0].where.course).toEqual({ orgId: 2n, primaryInstructorUserId: 7n });
  });
  it.each(["ACCOUNTANT", "LEARNER", "PARENT"] as const)("blocks %s before consuming the body", async role => {
    await expect(uploadLessonResource({ ...teacher, role }, "9", metadata, chunks())).rejects.toMatchObject({ statusCode: 403 });
    expect(await readdir(mocks.env.LESSON_MEDIA_DIR)).toEqual([]);
  });
  it("blocks an unassigned lesson", async () => {
    mocks.db.courseLesson.findFirst.mockResolvedValue(null);
    await expect(uploadLessonResource(teacher, "9", metadata, chunks())).rejects.toMatchObject({ statusCode: 404 });
    expect(await readdir(mocks.env.LESSON_MEDIA_DIR)).toEqual([]);
  });
  it.each([Buffer.alloc(0), Buffer.from("<html>not a PDF</html>")])("rejects empty or mismatched content and removes the file", async bytes => {
    await expect(uploadLessonResource(teacher, "9", metadata, chunks(bytes))).rejects.toMatchObject({ statusCode: 415 });
    expect(await readdir(join(mocks.env.LESSON_MEDIA_DIR, "2"))).toEqual([]);
    expect(mocks.db.mediaAsset.create).not.toHaveBeenCalled();
  });
  it("cleans up interrupted uploads", async () => {
    async function* interrupted() { yield pdf; throw new Error("Interrupted"); }
    await expect(uploadLessonResource(teacher, "9", metadata, interrupted())).rejects.toThrow("Interrupted");
    expect(await readdir(join(mocks.env.LESSON_MEDIA_DIR, "2"))).toEqual([]);
  });
  it("enforces the limit while streaming", async () => {
    async function* large() { const block = Buffer.alloc(1024 * 1024); for (let n = 0; n <= MAX_LESSON_UPLOAD_BYTES / block.length; n++) yield block; }
    await expect(uploadLessonResource(teacher, "9", metadata, large())).rejects.toMatchObject({ statusCode: 413 });
    expect(await readdir(join(mocks.env.LESSON_MEDIA_DIR, "2"))).toEqual([]);
  });
  it("accepts a streamed MP4 larger than 50 MB", async () => {
    async function* video() {
      yield Buffer.from("\0\0\0\u0018ftypisom0000");
      const block = Buffer.alloc(1024 * 1024);
      for (let n = 0; n < 51; n++) yield block;
    }
    await uploadLessonResource(teacher, "9", { ...metadata, format: "mp4" }, video());
    expect(mocks.db.mediaAsset.create.mock.calls[0]![0].data).toMatchObject({
      assetType: "VIDEO", fileSizeBytes: BigInt(51 * 1024 * 1024 + 16),
    });
  });
  it("rejects videos above 250 MB and removes the partial file", async () => {
    async function* video() {
      const block = Buffer.alloc(1024 * 1024);
      for (let n = 0; n <= MAX_LESSON_VIDEO_UPLOAD_BYTES / block.length; n++) yield block;
    }
    await expect(uploadLessonResource(teacher, "9", { ...metadata, format: "mp4" }, video()))
      .rejects.toMatchObject({ statusCode: 413 });
    expect(await readdir(join(mocks.env.LESSON_MEDIA_DIR, "2"))).toEqual([]);
    expect(mocks.db.mediaAsset.create).not.toHaveBeenCalled();
  });
  it("removes the file if course access changes during upload", async () => {
    mocks.db.courseLesson.findFirst.mockResolvedValueOnce({ id: 9n, courseId: 4n }).mockResolvedValueOnce(null);
    await expect(uploadLessonResource(teacher, "9", metadata, chunks())).rejects.toMatchObject({ statusCode: 403 });
    expect(await readdir(join(mocks.env.LESSON_MEDIA_DIR, "2"))).toEqual([]);
  });
  it("removes the file on database failure", async () => {
    mocks.db.mediaAsset.create.mockRejectedValue(new Error("Database failure"));
    await expect(uploadLessonResource(teacher, "9", metadata, chunks())).rejects.toThrow("Database failure");
    expect(await readdir(join(mocks.env.LESSON_MEDIA_DIR, "2"))).toEqual([]);
  });
  it.each(["svg", "html", "exe"])("rejects unsupported %s", async format => {
    await expect(uploadLessonResource(teacher, "9", { ...metadata, format }, chunks())).rejects.toThrow();
    expect(await readdir(mocks.env.LESSON_MEDIA_DIR)).toEqual([]);
  });
  it.each([
    ["png", "IMAGE", Buffer.from([137,80,78,71,13,10,26,10,0,0,0,0])],
    ["jpg", "IMAGE", Buffer.from([255,216,255,224,0,0,0,0,0,0,0,0])],
    ["mp4", "VIDEO", Buffer.from("\0\0\0\u0018ftypisom0000")],
    ["mp3", "AUDIO", Buffer.from("ID3synthetic audio")],
    ["wav", "AUDIO", Buffer.from("RIFF0000WAVEdata")],
  ])("routes %s to the matching player", async (format, kind, bytes) => {
    await uploadLessonResource(teacher, "9", { ...metadata, format }, chunks(bytes as Buffer));
    const data = mocks.db.mediaAsset.create.mock.calls[0]![0].data;
    expect(data.assetType).toBe(kind === "IMAGE" ? "ATTACHMENT" : kind);
    expect(localLessonMedia(data)?.playerKind).toBe(kind);
  });
});
