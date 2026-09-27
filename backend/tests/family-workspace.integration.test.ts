import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/shared/db/prisma";
import { env } from "../src/config/env";
import { api } from "./helpers/api-client";

describe("parent family workspace", () => {
  let orgId: bigint, otherOrg: bigint, parent: bigint, teacher: bigint, guardianId: bigint;
  let student: bigint, sibling: bigint, unrelated: bigint, foreign: bigint, branch: bigint, otherBranch: bigint;
  const token = (role = "PARENT") => jwt.sign({ sub: String(parent), orgId: String(orgId), role, type: "access" }, env.JWT_SECRET, { expiresIn: "10m" });
  const get = (path: string, role = "PARENT") => api.get(`/api/parent-portal/workspace/${path}`).set("Authorization", `Bearer ${token(role)}`);
  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Family workspace test", code: randomUUID() } })).id;
    otherOrg = (await prisma.organization.create({ data: { name: "Private family school", code: randomUUID() } })).id;
    branch = (await prisma.branch.create({ data: { orgId, name: "Main" } })).id;
    otherBranch = (await prisma.branch.create({ data: { orgId, name: "Sibling campus" } })).id;
    const privateBranch = (await prisma.branch.create({ data: { orgId: otherOrg, name: "Private" } })).id;
    parent = (await prisma.user.create({ data: { orgId, branchId: branch, fullName: "Parent One", role: "PARENT", passwordHash: "not-a-login" } })).id;
    teacher = (await prisma.user.create({ data: { orgId, fullName: "Teacher One", role: "TEACHER", passwordHash: "not-a-login", phone: "PRIVATE-PHONE" } })).id;
    guardianId = (await prisma.guardian.create({ data: { orgId, userId: parent, fullName: "Parent One", phone: "255700000000", relationship: "Mother" } })).id;
    const group = await prisma.class.create({ data: { orgId, branchId: branch, name: "Year One", level: "Primary", academicYear: "2026", teacherId: teacher } });
    for (const [index, admissionNo] of ["ONE", "SIBLING", "UNRELATED", "FOREIGN"].entries()) {
      const row = await prisma.student.create({ data: { orgId: index === 3 ? otherOrg : orgId,
        branchId: index === 3 ? privateBranch : index === 1 ? otherBranch : branch,
        fullName: admissionNo, admissionNo, notes: "INTERNAL-STUDENT-NOTE", ...(index === 0 ? { classId: group.id } : {}) } });
      if (index === 0) student = row.id;
      if (index === 1) sibling = row.id;
      if (index === 2) unrelated = row.id;
      if (index === 3) foreign = row.id;
      if (index < 2) await prisma.studentGuardian.create({ data: { orgId, guardianId, studentId: row.id } });
    }
    for (const [i, status] of (["PRESENT", "LATE", "ABSENT", "EXCUSED"] as const).entries())
      await prisma.attendanceRecord.create({ data: { orgId, branchId: branch, classId: group.id, studentId: student, markedById: teacher, date: new Date(`2026-09-0${i + 1}`), status } });
    for (const data of [
      { ayahFrom: 1, ayahTo: 5, activity: "MEMORIZATION" as const, observation: "INDEPENDENT" as const },
      { ayahFrom: 3, ayahTo: 8, activity: "MEMORIZATION" as const, observation: "INDEPENDENT" as const },
      { ayahFrom: 9, ayahTo: 15, activity: "READING" as const, observation: "INDEPENDENT" as const },
      { ayahFrom: 9, ayahTo: 15, activity: "MEMORIZATION" as const, observation: "NEEDS_PRACTICE" as const },
      { ayahFrom: 16, ayahTo: 30, activity: "MEMORIZATION" as const, observation: "INDEPENDENT" as const, voidedAt: new Date() },
    ]) await prisma.quranSession.create({ data: { orgId, classId: group.id, studentId: student, teacherId: teacher,
      surahId: 67, clientId: randomUUID(), requestHash: "a".repeat(64), note: "PRIVATE-TEACHER-NOTE", learnedOn: new Date("2026-09-01"), ...data } });
    for (const [title, audience, publishAt, expiresAt] of [
      ["Family notice", "PARENTS", "2026-01-01", null], ["Staff only", "TEACHERS", "2026-01-01", null],
      ["Future notice", "PARENTS", "2099-01-01", null], ["Expired notice", "PARENTS", "2020-01-01", "2020-02-01"],
    ] as const) await prisma.announcement.create({ data: { orgId, title, audience, message: title, publishAt: new Date(publishAt), expiresAt: expiresAt ? new Date(expiresAt) : null, createdById: teacher } });
  });
  afterAll(async () => {
    const where = { orgId: { in: [orgId, otherOrg].filter(Boolean) } };
    await prisma.quranSession.deleteMany({ where });
    await prisma.attendanceRecord.deleteMany({ where });
    await prisma.announcement.deleteMany({ where });
    await prisma.studentGuardian.deleteMany({ where });
    await prisma.student.deleteMany({ where });
    await prisma.guardian.deleteMany({ where });
    await prisma.class.deleteMany({ where });
    await prisma.user.deleteMany({ where });
    await prisma.branch.deleteMany({ where });
    await prisma.organization.deleteMany({ where: { id: where.orgId } });
  });

  it("requires an active parent and refuses impersonation or unrelated children", async () => {
    expect((await api.get("/api/parent-portal/workspace/overview")).status).toBe(401);
    for (const role of ["ADMIN", "TEACHER", "ACCOUNTANT", "LEARNER"]) expect((await get("overview", role)).status).toBe(403);
    expect((await get(`overview?parentUserId=${parent}`)).status).toBe(422);
    for (const id of [unrelated, foreign, 999999999n]) for (const area of ["profile", "attendance", "quran"])
      expect((await get(`children/${id}/${area}`)).status).toBe(404);
    await prisma.user.update({ where: { id: parent }, data: { status: "DISABLED" } });
    expect((await get("overview")).status).toBe(403);
    expect((await api.get("/api/parent-portal/students").set("Authorization", `Bearer ${token()}`)).status).toBe(403);
    await prisma.user.update({ where: { id: parent }, data: { status: "ACTIVE" } });
    await prisma.organization.update({ where: { id: orgId }, data: { status: "SUSPENDED" } });
    expect((await get("overview")).status).toBe(403);
    await prisma.organization.update({ where: { id: orgId }, data: { status: "ACTIVE" } });
  });
  it("shows linked siblings across campuses and only published family announcements", async () => {
    const response = await get("overview?month=2026-09");
    expect(response.status).toBe(200);
    expect(response.headers["cache-control"]).toBe("no-store");
    expect(response.body.data.children.map((c: { id: string }) => c.id)).toEqual([String(student), String(sibling)]);
    expect(response.body.data.announcements.map((a: { title: string }) => a.title)).toEqual(["Family notice"]);
    expect(response.body.data.children[1].attendance.rate).toBeNull();
    expect(JSON.stringify(response.body)).not.toContain("INTERNAL-STUDENT-NOTE");
    expect(JSON.stringify(response.body)).not.toContain("PRIVATE-PHONE");
  });
  it("does not fabricate absent days and counts late as present, excused separately", async () => {
    const response = await get(`children/${student}/attendance?month=2026-09`);
    expect(response.body.data.summary).toEqual({ PRESENT: 1, LATE: 1, ABSENT: 1, EXCUSED: 1, markedDays: 4, rate: 67 });
    expect(response.body.data.records).toHaveLength(4);
    expect((await get(`children/${student}/attendance?month=2026-10`)).body.data.summary.rate).toBeNull();
    for (const month of ["2026-13", "0000-01", "2026-00", "2026-1"])
      expect((await get(`children/${student}/attendance?month=${month}`)).status).toBe(422);
  });
  it("deduplicates confirmed memorisation and excludes voided sessions/private notes", async () => {
    const response = await get(`children/${student}/quran`);
    expect(response.status).toBe(200);
    const data = response.body.data;
    expect(data.memorisedAyahs).toBe(8);
    expect(data.totalAyahs).toBe(6236);
    expect(data.chapters.find((c: { id: number }) => c.id === 67).memorisedAyahs).toBe(8);
    expect(data.juzs.find((j: { number: number }) => j.number === 29).memorisedAyahs).toBe(8);
    expect(data.meta.totalItems).toBe(4);
    expect(data.sessions).toHaveLength(4);
    expect(JSON.stringify(data)).not.toContain("PRIVATE-TEACHER-NOTE");
    expect((await get(`children/${student}/quran?page=2`)).body.data.sessions).toHaveLength(0);
    expect((await get(`children/${student}/quran?page=0`)).status).toBe(422);
  });
  it("returns safe profile details and revokes access immediately after unlinking", async () => {
    expect((await get(`children/${student}/profile`)).body.data.student.currentClass.teacher.fullName).toBe("Teacher One");
    await prisma.studentGuardian.deleteMany({ where: { guardianId, studentId: sibling } });
    for (const area of ["profile", "attendance", "quran"]) expect((await get(`children/${sibling}/${area}`)).status).toBe(404);
    expect((await get("overview")).body.data.children).toHaveLength(1);
    await prisma.studentGuardian.deleteMany({ where: { guardianId } });
    const empty = await get("overview");
    expect(empty.status).toBe(200);
    expect(empty.body.data.children).toHaveLength(0);
  });
});
