import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/shared/db/prisma";
import { env } from "../src/config/env";
import { api } from "./helpers/api-client";

describe("admin student management", () => {
  let orgId: bigint, otherOrg: bigint, admin: bigint, teacher: bigint;
  let student: bigint, outside: bigint, foreign: bigint, learner: bigint;
  const token = (role = "ADMIN") => jwt.sign({
    sub: String(role === "ADMIN" ? admin : teacher), orgId: String(orgId), role, type: "access",
  }, env.JWT_SECRET, { expiresIn: "10m" });
  const read = (id = student, role = "ADMIN") => api.get(`/api/admin/students/${id}/record`)
    .set("Authorization", `Bearer ${token(role)}`);
  const change = (id: bigint, action: string, body: object, role = "ADMIN") =>
    api.post(`/api/admin/students/${id}/${action}`).set("Authorization", `Bearer ${token(role)}`).send(body);
  const details = (revision: string, extra = {}) => ({
    revision, reason: "Corrected office record", fullName: "Updated Student", admissionNo: "ONE",
    gender: "female", dob: "2015-02-28", joinedOn: "2026-01-01", notes: "Reading support", ...extra,
  });
  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Student CRUD test", code: randomUUID() } })).id;
    otherOrg = (await prisma.organization.create({ data: { name: "Other school", code: randomUUID() } })).id;
    const branch = await prisma.branch.create({ data: { orgId, name: "Main" } });
    const otherBranch = await prisma.branch.create({ data: { orgId, name: "Other" } });
    const privateBranch = await prisma.branch.create({ data: { orgId: otherOrg, name: "Private" } });
    admin = (await prisma.user.create({ data: { orgId, branchId: branch.id, fullName: "Office Admin", role: "ADMIN", passwordHash: "not-a-login" } })).id;
    teacher = (await prisma.user.create({ data: { orgId, branchId: branch.id, fullName: "Class Teacher", role: "TEACHER", passwordHash: "not-a-login" } })).id;
    const group = await prisma.class.create({ data: { orgId, branchId: branch.id, name: "One", level: "Foundation", academicYear: "2026", teacherId: teacher } });
    for (const [index, admissionNo] of ["ONE", "TWO", "OTHER-BRANCH", "OTHER-SCHOOL", "ONLINE"].entries()) {
      const record = await prisma.student.create({ data: {
        orgId: index === 3 ? otherOrg : orgId,
        branchId: index === 3 ? privateBranch.id : index === 2 ? otherBranch.id : branch.id,
        fullName: `Student ${admissionNo}`, admissionNo,
        ...(index === 0 ? { classId: group.id } : {}),
        programCategory: index === 4 ? "COURSE_STUDENT" : "MADRASA_CHILD",
      } });
      if (index === 0) student = record.id;
      if (index === 2) outside = record.id;
      if (index === 3) foreign = record.id;
      if (index === 4) learner = record.id;
    }
    await prisma.quranSession.create({ data: {
      orgId, classId: group.id, studentId: student, teacherId: teacher,
      clientId: randomUUID(), requestHash: "a".repeat(64), surahId: 67, ayahFrom: 1, ayahTo: 5,
      activity: "READING", observation: "INDEPENDENT", learnedOn: new Date("2026-09-01"),
    } });
  });
  afterAll(async () => {
    const where = { orgId: { in: [orgId, otherOrg].filter(Boolean) } };
    await prisma.quranSession.deleteMany({ where });
    await prisma.auditLog.deleteMany({ where });
    await prisma.student.deleteMany({ where });
    await prisma.class.deleteMany({ where });
    await prisma.user.deleteMany({ where });
    await prisma.branch.deleteMany({ where });
    await prisma.organization.deleteMany({ where: { id: where.orgId } });
  });

  it("requires an active admin and scopes every action to the current school and branch", async () => {
    expect((await api.get(`/api/admin/students/${student}/record`)).status).toBe(401);
    const directory = await api.get("/api/students").set("Authorization", `Bearer ${token()}`);
    expect(directory.body.data.items.find((item: { id: string }) => item.id === String(student)))
      .toMatchObject({ programCategory: "MADRASA_CHILD" });
    for (const role of ["TEACHER", "PARENT", "LEARNER", "ACCOUNTANT"]) {
      expect((await read(student, role)).status).toBe(403);
      expect((await change(student, "archive", { revision: "a".repeat(64), reason: "Leaving school" }, role)).status).toBe(403);
    }
    for (const id of [outside, foreign]) {
      expect((await read(id)).status).toBe(404);
      expect((await change(id, "edit", details("a".repeat(64)))).status).toBe(404);
      expect((await change(id, "archive", { revision: "a".repeat(64), reason: "Leaving school" })).status).toBe(404);
      expect((await change(id, "restore", { revision: "a".repeat(64), reason: "Returning student" })).status).toBe(404);
    }
    await prisma.user.update({ where: { id: admin }, data: { status: "DISABLED" } });
    expect((await read()).status).toBe(403);
    await prisma.user.update({ where: { id: admin }, data: { status: "ACTIVE" } });
  });
  it("validates dates, protected fields and duplicate admission numbers without partial writes", async () => {
    const revision = (await read()).body.data.revision;
    for (const extra of [{ dob: "2025-02-30" }, { dob: "2099-01-01" }, { joinedOn: "2014-01-01" },
      { joinedOn: "2099-01-01" }, { branchId: "99" }, { status: "ACTIVE" }, { reason: " " }])
      expect((await change(student, "edit", details(revision, extra))).status).toBe(422);
    expect((await change(student, "edit", details(revision, { admissionNo: "TWO" }))).status).toBe(409);
    expect((await read()).body.data.fullName).toBe("Student ONE");
    expect(await prisma.auditLog.count({ where: { orgId } })).toBe(0);
  });
  it("edits personal details, rejects stale forms and keeps actor/reason/before/after history", async () => {
    const revision = (await read()).body.data.revision;
    const edited = await change(student, "edit", details(revision));
    expect(edited.status).toBe(200);
    expect(edited.body.data).toMatchObject({ fullName: "Updated Student", notes: "Reading support", status: "ACTIVE" });
    expect(edited.body.data.revision).not.toBe(revision);
    expect((await change(student, "edit", details(revision, { fullName: "Stale form" }))).status).toBe(409);
    const history = (await read()).body.data.history;
    expect(history).toHaveLength(1);
    expect(history[0]).toMatchObject({ action: "student.admin_edit", actorUser: { fullName: "Office Admin" },
      metadata: { reason: "Corrected office record", before: { fullName: "Student ONE" }, after: { fullName: "Updated Student" } } });
    expect((await change(student, "edit", details(edited.body.data.revision, { gender: null, dob: null, joinedOn: null, notes: null }))).status).toBe(200);
    expect((await read()).body.data).toMatchObject({ gender: null, dob: null, joinedOn: null, notes: null });
  });
  it("archives and restores without deleting class links or learning history", async () => {
    const before = (await read()).body.data;
    const archived = await change(student, "archive", { revision: before.revision, reason: "Family requested a pause" });
    expect(archived.status).toBe(200);
    expect(archived.body.data).toMatchObject({ status: "INACTIVE", classId: before.classId });
    expect(archived.body.data.leftOn).not.toBeNull();
    expect(await prisma.quranSession.count({ where: { studentId: student } })).toBe(1);
    const roster = await api.get("/api/teacher-workspace/students").set("Authorization", `Bearer ${token("TEACHER")}`);
    expect(roster.status).toBe(200);
    expect(roster.body.data.items).toHaveLength(0);
    expect((await change(student, "archive", { revision: archived.body.data.revision, reason: "Repeated request" })).status).toBe(409);
    const restored = await change(student, "restore", { revision: archived.body.data.revision, reason: "Student has returned" });
    expect(restored.status).toBe(200);
    expect(restored.body.data).toMatchObject({ status: "ACTIVE", leftOn: null, classId: before.classId });
    expect(await prisma.quranSession.count({ where: { studentId: student } })).toBe(1);
    expect((await read()).body.data.history.map((h: { action: string }) => h.action).slice(0, 2))
      .toEqual(["student.admin_restore", "student.admin_archive"]);
  });
  it("does not treat an online learner profile as its login account", async () => {
    const revision = (await read(learner)).body.data.revision;
    expect((await change(learner, "archive", { revision, reason: "Disable online access" })).status).toBe(409);
    expect((await read(learner)).body.data.status).toBe("ACTIVE");
  });
});
