import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { env } from "../src/config/env";
import { prisma } from "../src/shared/db/prisma";
import { api } from "./helpers/api-client";

describe("teacher and parent course activity through scoped APIs", () => {
  const organizations: bigint[] = [];
  let orgId: bigint, teacher: bigint, parent: bigint, guardian: bigint;
  let learner: bigint, former: bigint, student: bigint, group: bigint, course: bigint;
  const inaccessible: bigint[] = [];
  const roles = ["TEACHER", "PARENT"] as const;
  const read = (role: typeof roles[number], id = student) => {
    const token = jwt.sign({ sub: String(role === "TEACHER" ? teacher : parent),
      orgId: String(orgId), role, type: "access" }, env.JWT_SECRET, { expiresIn: "10m" });
    return api.get(role === "TEACHER" ? `/api/teacher-workspace/students/${id}`
      : `/api/parent-portal/workspace/children/${id}/profile`).set("Authorization", `Bearer ${token}`);
  };
  const history = () => prisma.courseLessonProgress.findMany({
    where: { orgId }, orderBy: { id: "asc" },
  });

  beforeAll(async () => {
    if (env.NODE_ENV === "production") throw new Error("Synthetic fixtures must not run in production");
    for (const name of ["Synthetic scoped tracking", "Synthetic foreign tracking"]) {
      organizations.push((await prisma.organization.create({ data: { name, code: randomUUID() } })).id);
    }
    orgId = organizations[0]!;
    const branch = await prisma.branch.create({ data: { orgId, name: "Synthetic main" } });
    const otherBranch = await prisma.branch.create({ data: { orgId, name: "Synthetic other campus" } });
    const foreignBranch = await prisma.branch.create({ data: { orgId: organizations[1]!, name: "Synthetic foreign" } });
    teacher = (await prisma.user.create({ data: { orgId, branchId: branch.id,
      fullName: "Synthetic teacher", role: "TEACHER", passwordHash: "not-a-login" } })).id;
    parent = (await prisma.user.create({ data: { orgId, fullName: "Synthetic parent",
      role: "PARENT", passwordHash: "not-a-login" } })).id;
    learner = (await prisma.user.create({ data: { orgId, fullName: "Synthetic current learner",
      role: "LEARNER", passwordHash: "not-a-login" } })).id;
    former = (await prisma.user.create({ data: { orgId, fullName: "Synthetic former learner",
      role: "LEARNER", passwordHash: "not-a-login" } })).id;
    guardian = (await prisma.guardian.create({ data: { orgId, userId: parent,
      fullName: "Synthetic guardian", relationship: "Parent", phone: "255700000000" } })).id;
    group = (await prisma.class.create({ data: { orgId, branchId: branch.id, teacherId: teacher,
      name: "Synthetic assigned class", level: "Primary", academicYear: "2026" } })).id;
    const otherClass = await prisma.class.create({ data: { orgId, branchId: otherBranch.id, teacherId: teacher,
      name: "Synthetic other campus class", level: "Primary", academicYear: "2026" } });
    student = (await prisma.student.create({ data: { orgId, branchId: branch.id, classId: group,
      fullName: "Synthetic linked student", admissionNo: "LINKED", learnerUserId: learner } })).id;
    await prisma.studentGuardian.create({ data: { orgId, guardianId: guardian, studentId: student } });
    for (const data of [
      { orgId, branchId: branch.id, admissionNo: "UNASSIGNED" },
      { orgId, branchId: otherBranch.id, classId: otherClass.id, admissionNo: "OTHER-CAMPUS" },
      { orgId: organizations[1]!, branchId: foreignBranch.id, admissionNo: "FOREIGN" },
    ]) inaccessible.push((await prisma.student.create({ data: { ...data, fullName: "Synthetic outside scope" } })).id);
    const subject = await prisma.subject.create({ data: { orgId, name: "Synthetic subject", code: "SYNTHETIC" } });
    course = (await prisma.course.create({ data: { orgId, subjectId: subject.id,
      createdByUserId: teacher, title: "Synthetic course", slug: "synthetic", summary: "Test only",
      publicationStatus: "PUBLISHED", programCategory: "MADRASA_CHILD" } })).id;
    const module = await prisma.courseModule.create({ data: { orgId, courseId: course, title: "Synthetic module", position: 1 } });
    for (let index = 0; index < 4; index++) {
      const lesson = await prisma.courseLesson.create({ data: { orgId, courseId: course, moduleId: module.id,
        title: `Synthetic lesson ${index}`, slug: `synthetic-${index}`, position: index,
        publicationStatus: index === 2 ? "DRAFT" : "PUBLISHED", visibility: index === 3 ? "UNLISTED" : "LOCKED" } });
      await prisma.courseLessonProgress.create({ data: { orgId, courseId: course, lessonId: lesson.id,
        studentId: student, learnerUserId: learner, progressPercent: index === 0 ? 35 : 100 } });
      if (index === 0) await prisma.courseLessonProgress.create({ data: { orgId, courseId: course,
        lessonId: lesson.id, studentId: student, learnerUserId: former, progressPercent: 100 } });
    }
  }, 20000);

  afterAll(async () => {
    const where = { orgId: { in: organizations } };
    await prisma.courseLessonProgress.deleteMany({ where });
    await prisma.courseLesson.deleteMany({ where });
    await prisma.courseModule.deleteMany({ where });
    await prisma.course.deleteMany({ where });
    await prisma.subject.deleteMany({ where });
    await prisma.studentGuardian.deleteMany({ where });
    await prisma.student.deleteMany({ where });
    await prisma.guardian.deleteMany({ where });
    await prisma.class.deleteMany({ where });
    await prisma.user.deleteMany({ where });
    await prisma.branch.deleteMany({ where });
    await prisma.organization.deleteMany({ where: { id: { in: organizations } } });
  });

  for (const role of roles) {
    it(`${role}: returns current-account published activity without changing history or caching`, async () => {
      const before = await history();
      const response = await read(role);
      expect(response.status).toBe(200);
      expect(response.headers["cache-control"]).toBe("no-store");
      const summary = response.body.data.courseProgress;
      expect(summary).toMatchObject({ linked: true, trackedLessons: 2, completedLessons: 1 });
      expect(summary.recent.map((row: { lesson: { title: string } }) => row.lesson.title).sort())
        .toEqual(["Synthetic lesson 0", "Synthetic lesson 1"]);
      for (const row of summary.recent) {
        expect(Object.keys(row).sort()).toEqual(["completedAt", "course", "lesson", "progressPercent", "updatedAt"]);
        expect(Object.keys(row.course)).toEqual(["title"]);
        expect(Object.keys(row.lesson)).toEqual(["title"]);
      }
      expect(await history()).toEqual(before);
    });

    it(`${role}: refuses students outside the caller's scope`, async () => {
      for (const id of inaccessible) expect((await read(role, id)).status).toBe(404);
    });

    it(`${role}: follows account links without merging or deleting historical activity`, async () => {
      const before = await history();
      try {
        await prisma.student.update({ where: { id: student }, data: { learnerUserId: null } });
        const unlinked = await read(role);
        expect(unlinked.status).toBe(200);
        expect(unlinked.body.data.courseProgress).toEqual({ linked: false, trackedLessons: 0, completedLessons: 0, recent: [] });
        await prisma.student.update({ where: { id: student }, data: { learnerUserId: former } });
        const relinked = await read(role);
        expect(relinked.status).toBe(200);
        expect(relinked.body.data.courseProgress).toMatchObject({ linked: true, trackedLessons: 1, completedLessons: 1 });
        expect(await history()).toEqual(before);
      } finally {
        await prisma.student.update({ where: { id: student }, data: { learnerUserId: learner } });
      }
    });

    it(`${role}: hides unpublished courses without erasing progress`, async () => {
      const before = await history();
      try {
        await prisma.course.update({ where: { id: course }, data: { publicationStatus: "DRAFT" } });
        const response = await read(role);
        expect(response.status).toBe(200);
        expect(response.body.data.courseProgress).toEqual({ linked: true, trackedLessons: 0, completedLessons: 0, recent: [] });
        expect(await history()).toEqual(before);
      } finally {
        await prisma.course.update({ where: { id: course }, data: { publicationStatus: "PUBLISHED" } });
      }
    });

    it(`${role}: excludes a previous programme without changing its records`, async () => {
      const before = await history();
      try {
        await prisma.student.update({ where: { id: student }, data: { programCategory: "COURSE_STUDENT" } });
        const response = await read(role);
        expect(response.status).toBe(200);
        expect(response.body.data.courseProgress).toEqual({ linked: true, trackedLessons: 0, completedLessons: 0, recent: [] });
        expect(await history()).toEqual(before);
      } finally {
        await prisma.student.update({ where: { id: student }, data: { programCategory: "MADRASA_CHILD" } });
      }
    });
  }

  it("rechecks teacher assignment and guardian links on the next request", async () => {
    const before = await history();
    try {
      await prisma.class.update({ where: { id: group }, data: { teacherId: null } });
      expect((await read("TEACHER")).status).toBe(404);
      expect((await read("PARENT")).status).toBe(200);
      await prisma.studentGuardian.deleteMany({ where: { orgId, guardianId: guardian, studentId: student } });
      expect((await read("PARENT")).status).toBe(404);
      expect(await history()).toEqual(before);
    } finally {
      await prisma.class.update({ where: { id: group }, data: { teacherId: teacher } });
    }
  });
});
