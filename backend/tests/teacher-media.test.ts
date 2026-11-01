import { beforeEach, describe, expect, it, vi } from "vitest";
import jwt from "jsonwebtoken";
const db = vi.hoisted(() => ({ user: { findFirst: vi.fn() }, mediaAsset: { findFirst: vi.fn() } }));
vi.mock("../src/shared/db/prisma", () => ({ prisma: db }));
vi.mock("../src/config/env", () => ({ env: { JWT_SECRET: "synthetic-teacher-media-test-key" } }));
import { deliverTeacherMedia, openTeacherMedia } from "../src/modules/learning/teacher-media";

const teacher = { userId: "7", orgId: "2", role: "TEACHER" as const };
const asset = { id: 9n, courseId: 4n, lesson: { courseId: 4n }, title: "Synthetic audio",
  storageProvider: "S3", storageKey: "https://media.example.test/lesson.mp3", assetType: "AUDIO" };
const getToken = async () => {
  const result = await openTeacherMedia(teacher, "9");
  return new URL(result.delivery.inlineUrl!, "https://school.test").searchParams.get("token")!;
};

describe("teacher media authorization", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    db.user.findFirst.mockResolvedValue({ authVersion: 3 });
    db.mediaAsset.findFirst.mockResolvedValue(asset);
  });
  it("creates a teacher-only signed route and rechecks assignment on delivery", async () => {
    const token = await getToken();
    expect(await deliverTeacherMedia("9", token)).toBe(asset.storageKey);
    expect(db.mediaAsset.findFirst).toHaveBeenCalledTimes(2);
    expect(db.mediaAsset.findFirst.mock.calls[1]?.[0].where).toMatchObject({
      id: 9n, orgId: 2n, course: { orgId: 2n, primaryInstructorUserId: 7n },
      lesson: { orgId: 2n, course: { orgId: 2n, primaryInstructorUserId: 7n } },
    });
    expect(db.user.findFirst.mock.calls[1]?.[0].where).toMatchObject({
      status: "ACTIVE", role: "TEACHER", organization: { status: { in: ["ACTIVE", "TRIAL"] } },
    });
  });
  it.each(["ADMIN", "ACCOUNTANT", "LEARNER", "PARENT"] as const)("rejects %s at the service boundary", async role => {
    await expect(openTeacherMedia({ ...teacher, role }, "9")).rejects.toMatchObject({ statusCode: 403 });
    expect(db.mediaAsset.findFirst).not.toHaveBeenCalled();
  });
  it("rejects missing or reassigned courses on open and delivery", async () => {
    const token = await getToken();
    db.mediaAsset.findFirst.mockResolvedValue(null);
    await expect(deliverTeacherMedia("9", token)).rejects.toMatchObject({ statusCode: 404 });
    await expect(openTeacherMedia(teacher, "9")).rejects.toMatchObject({ statusCode: 404 });
  });
  it("rejects inactive accounts and sign-out-all token versions", async () => {
    const token = await getToken();
    db.user.findFirst.mockResolvedValue({ authVersion: 4 });
    await expect(deliverTeacherMedia("9", token)).rejects.toMatchObject({ statusCode: 403 });
    db.user.findFirst.mockResolvedValue(null);
    await expect(deliverTeacherMedia("9", token)).rejects.toMatchObject({ statusCode: 403 });
  });
  it("rejects mismatched assets, tampering, wrong audiences and expired links", async () => {
    const token = await getToken();
    await expect(deliverTeacherMedia("10", token)).rejects.toMatchObject({ statusCode: 401 });
    await expect(deliverTeacherMedia("9", `${token}x`)).rejects.toMatchObject({ statusCode: 401 });
    for (const options of [{ audience: "learner", expiresIn: 300 }, { audience: "teacher-media-delivery", expiresIn: -1 }]) {
      const invalid = jwt.sign({ type: "teacher-media", userId: "7", orgId: "2", assetId: "9", ver: 3 },
        "synthetic-teacher-media-test-key", options);
      await expect(deliverTeacherMedia("9", invalid)).rejects.toMatchObject({ statusCode: 401 });
    }
  });
  it("does not expose unconnected sources or inconsistent course relationships", async () => {
    db.mediaAsset.findFirst.mockResolvedValue({ ...asset, storageKey: "not-connected" });
    expect((await openTeacherMedia(teacher, "9")).delivery).toMatchObject({ status: "PENDING_SOURCE", inlineUrl: null });
    db.mediaAsset.findFirst.mockResolvedValue({ ...asset, lesson: { courseId: 5n } });
    await expect(openTeacherMedia(teacher, "9")).rejects.toMatchObject({ statusCode: 404 });
  });
});
