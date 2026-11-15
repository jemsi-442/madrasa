import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const mocks = vi.hoisted(() => ({
  env: { LESSON_MEDIA_DIR: "" },
  db: { courseLesson: { findFirst: vi.fn() }, mediaAsset: { create: vi.fn() } },
}));
vi.mock("../src/config/env", () => ({ env: mocks.env }));
vi.mock("../src/shared/db/prisma", () => ({ prisma: mocks.db }));
import { createLessonText } from "../src/modules/learning/lesson-text";
import { localLessonMedia } from "../src/modules/learning/local-lesson-media";

const teacher = { userId: "7", orgId: "2", role: "TEACHER" as const };
describe("private lesson text authoring", () => {
  beforeEach(async () => {
    vi.resetAllMocks();
    mocks.env.LESSON_MEDIA_DIR = await mkdtemp(join(tmpdir(), "afaq-text-test-"));
    mocks.db.courseLesson.findFirst.mockResolvedValue({ id: 9n, courseId: 4n });
    mocks.db.mediaAsset.create.mockResolvedValue({ id: 11n, title: "Notes", assetType: "TEXT", visibility: "LOCKED" });
  });
  afterEach(async () => { await rm(mocks.env.LESSON_MEDIA_DIR, { recursive: true, force: true }); });

  it("stores UTF-8 text privately, scoped to the assigned course and locked by default", async () => {
    const result = await createLessonText(teacher, "9", { title: " Notes ", text: " Synthetic lesson notes. " });
    expect(result.id).toBe("11");
    expect(mocks.db.courseLesson.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: {
      id: 9n, orgId: 2n, course: { orgId: 2n, primaryInstructorUserId: 7n },
    } }));
    const data = mocks.db.mediaAsset.create.mock.calls[0]![0].data;
    expect(data).toMatchObject({ title: "Notes", visibility: "LOCKED", lessonId: 9n, courseId: 4n, downloadAllowed: false });
    const source = localLessonMedia(data)!;
    expect(source.playerKind).toBe("TEXT");
    expect(await readFile(source.filePath, "utf8")).toBe("Synthetic lesson notes.");
    expect(localLessonMedia({ ...data, orgId: 3n })).toBeNull();
    expect(localLessonMedia({ ...data, storageKey: "afaq-text:2/../../secret.txt" })).toBeNull();
  });

  it.each(["LEARNER", "ACCOUNTANT", "PARENT"] as const)("rejects %s before writing", async role => {
    await expect(createLessonText({ ...teacher, role }, "9", { title: "Notes", text: "Text" })).rejects.toMatchObject({ statusCode: 403 });
    expect(mocks.db.courseLesson.findFirst).not.toHaveBeenCalled();
    expect(await readdir(mocks.env.LESSON_MEDIA_DIR)).toEqual([]);
  });
  it("rejects a lesson outside the teacher assignment without creating a file", async () => {
    mocks.db.courseLesson.findFirst.mockResolvedValue(null);
    await expect(createLessonText(teacher, "9", { title: "Notes", text: "Text" })).rejects.toMatchObject({ statusCode: 404 });
    expect(await readdir(mocks.env.LESSON_MEDIA_DIR)).toEqual([]);
  });
  it.each([{ title: " ", text: "Text" }, { title: "Notes", text: " " }, { title: "Notes", text: "x".repeat(50001) }, { title: "Notes", text: "Text", storageKey: "/tmp/file" }])("rejects invalid content", async body => {
    await expect(createLessonText(teacher, "9", body)).rejects.toThrow();
    expect(mocks.db.courseLesson.findFirst).not.toHaveBeenCalled();
  });
  it("removes the new file when metadata saving fails", async () => {
    mocks.db.mediaAsset.create.mockRejectedValue(new Error("Synthetic database failure"));
    await expect(createLessonText(teacher, "9", { title: "Notes", text: "Text" })).rejects.toThrow("Synthetic database failure");
    expect(await readdir(join(mocks.env.LESSON_MEDIA_DIR, "2"))).toEqual([]);
  });
});
