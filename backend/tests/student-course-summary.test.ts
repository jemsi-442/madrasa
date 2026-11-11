import { describe, expect, it, vi } from "vitest";
import type { Prisma } from "@prisma/client";
import { studentCourseSummary } from "../src/modules/learner/student-course-summary";

function fixture(student: { learnerUserId: bigint | null; programCategory: string } | null) {
  const mock = {
    student: { findFirst: vi.fn().mockResolvedValue(student) },
    courseLessonProgress: {
      count: vi.fn().mockResolvedValueOnce(12).mockResolvedValueOnce(4),
      findMany: vi.fn().mockResolvedValue([]),
    },
  };
  return { mock, db: mock as unknown as Prisma.TransactionClient };
}

describe("authorised student course summary", () => {
  it.each([null, { learnerUserId: null, programCategory: "MADRASA_CHILD" }])(
    "does not load course records without a current scoped learner link", async student => {
      const { db, mock } = fixture(student);
      expect(await studentCourseSummary(db, 1n, 2n)).toEqual({
        linked: false, trackedLessons: 0, completedLessons: 0, recent: [],
      });
      expect(mock.student.findFirst).toHaveBeenCalledWith({
        where: { orgId: 1n, id: 2n }, select: { learnerUserId: true, programCategory: true },
      });
      expect(mock.courseLessonProgress.count).not.toHaveBeenCalled();
      expect(mock.courseLessonProgress.findMany).not.toHaveBeenCalled();
    },
  );

  it("scopes all counts and recent records to the current account, school and programme", async () => {
    const { db, mock } = fixture({ learnerUserId: 9n, programCategory: "MADRASA_CHILD" });
    const result = await studentCourseSummary(db, 1n, 2n);
    expect(result).toMatchObject({ linked: true, trackedLessons: 12, completedLessons: 4 });
    const scope = {
      orgId: 1n, studentId: 2n, learnerUserId: 9n,
      lesson: { orgId: 1n, publicationStatus: "PUBLISHED", visibility: { not: "UNLISTED" } },
      course: { orgId: 1n, publicationStatus: "PUBLISHED", visibility: { not: "UNLISTED" }, programCategory: "MADRASA_CHILD" },
    };
    expect(mock.courseLessonProgress.count).toHaveBeenNthCalledWith(1, { where: scope });
    expect(mock.courseLessonProgress.count).toHaveBeenNthCalledWith(2, {
      where: { ...scope, OR: [{ completedAt: { not: null } }, { progressPercent: { gte: 100 } }] },
    });
    expect(mock.courseLessonProgress.findMany).toHaveBeenCalledWith({
      where: scope, take: 5, orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
      select: { progressPercent: true, completedAt: true, updatedAt: true,
        course: { select: { title: true } }, lesson: { select: { title: true } } },
    });
  });

  it("does not disguise a database failure as zero progress", async () => {
    const { db, mock } = fixture({ learnerUserId: 9n, programCategory: "MADRASA_CHILD" });
    mock.courseLessonProgress.findMany.mockRejectedValueOnce(new Error("Unavailable"));
    await expect(studentCourseSummary(db, 1n, 2n)).rejects.toThrow("Unavailable");
  });
});
