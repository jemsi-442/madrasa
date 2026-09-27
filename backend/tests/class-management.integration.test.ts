import { randomUUID } from "node:crypto";
import { Prisma } from "@prisma/client";
import jwt from "jsonwebtoken";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { classDependencies } from "../src/modules/admin-panel/class-management";
import { prisma } from "../src/shared/db/prisma";
import { env } from "../src/config/env";
import { api } from "./helpers/api-client";

describe("admin class management", () => {
  let orgId: bigint, otherOrg: bigint, branch: bigint, otherBranch: bigint;
  let admin: bigint, teacher: bigint, replacement: bigint, foreignTeacher: bigint;
  let group: bigint, outside: bigint, foreign: bigint, pupil: bigint;
  const token = (role = "ADMIN") => jwt.sign({ sub: String(role === "ADMIN" ? admin : teacher),
    orgId: String(orgId), role, type: "access" }, env.JWT_SECRET, { expiresIn: "10m" });
  const read = (id = group, role = "ADMIN") => api.get(`/api/admin/classes/${id}/record`)
    .set("Authorization", `Bearer ${token(role)}`);
  const change = (id: bigint, action: string, body: object, role = "ADMIN") =>
    api.post(`/api/admin/classes/${id}/${action}`).set("Authorization", `Bearer ${token(role)}`).send(body);
  const details = (revision: string, extra = {}) => ({ revision, reason: "Correct office record",
    name: "Updated class", level: "Primary", academicYear: "2026", teacherId: String(teacher), capacity: 20, ...extra });
  const makeClass = (name: string) => prisma.class.create({ data: { orgId, branchId: branch, name,
    level: "Foundation", academicYear: "2026", teacherId: teacher, capacity: 30 } });
  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Class CRUD test", code: randomUUID() } })).id;
    otherOrg = (await prisma.organization.create({ data: { name: "Other class school", code: randomUUID() } })).id;
    branch = (await prisma.branch.create({ data: { orgId, name: "Main" } })).id;
    otherBranch = (await prisma.branch.create({ data: { orgId, name: "Other" } })).id;
    const privateBranch = (await prisma.branch.create({ data: { orgId: otherOrg, name: "Private" } })).id;
    admin = (await prisma.user.create({ data: { orgId, branchId: branch, fullName: "Office Admin", role: "ADMIN", passwordHash: "not-a-login" } })).id;
    teacher = (await prisma.user.create({ data: { orgId, branchId: branch, fullName: "Teacher One", role: "TEACHER", passwordHash: "not-a-login" } })).id;
    replacement = (await prisma.user.create({ data: { orgId, fullName: "Teacher Two", role: "TEACHER", passwordHash: "not-a-login" } })).id;
    foreignTeacher = (await prisma.user.create({ data: { orgId: otherOrg, fullName: "Private teacher", role: "TEACHER", passwordHash: "not-a-login" } })).id;
    group = (await makeClass("Original class")).id;
    outside = (await prisma.class.create({ data: { orgId, branchId: otherBranch, name: "Outside", level: "Primary", academicYear: "2026" } })).id;
    foreign = (await prisma.class.create({ data: { orgId: otherOrg, branchId: privateBranch, name: "Foreign", level: "Primary", academicYear: "2026" } })).id;
    pupil = (await prisma.student.create({ data: { orgId, branchId: branch, fullName: "Test pupil", admissionNo: "ONE" } })).id;
  });
  afterAll(async () => {
    const where = { orgId: { in: [orgId, otherOrg].filter(Boolean) } };
    await prisma.studentSupportNote.deleteMany({ where });
    await prisma.quranSession.deleteMany({ where });
    await prisma.classTimetableSlot.deleteMany({ where });
    await prisma.attendanceRecord.deleteMany({ where });
    await prisma.enrollment.deleteMany({ where });
    await prisma.feeStructure.deleteMany({ where });
    await prisma.auditLog.deleteMany({ where });
    await prisma.student.deleteMany({ where });
    await prisma.class.deleteMany({ where });
    await prisma.user.deleteMany({ where });
    await prisma.branch.deleteMany({ where });
    await prisma.organization.deleteMany({ where: { id: where.orgId } });
  });

  it("guards every class child relation, including future schema additions", () => {
    const relations = Prisma.dmmf.datamodel.models.find(model => model.name === "Class")!
      .fields.filter(field => field.kind === "object" && field.isList).map(field => field.name);
    expect(Object.keys(classDependencies).sort()).toEqual(relations.sort());
  });
  it("scopes reads and writes to active admins in the current school and branch", async () => {
    expect((await api.get(`/api/admin/classes/${group}/record`)).status).toBe(401);
    for (const role of ["TEACHER", "PARENT", "LEARNER", "ACCOUNTANT"]) {
      expect((await read(group, role)).status).toBe(403);
      for (const action of ["edit", "remove"])
        expect((await change(group, action, action === "edit" ? details("a".repeat(64)) : { revision: "a".repeat(64), reason: "Remove empty class" }, role)).status).toBe(403);
    }
    for (const id of [outside, foreign]) {
      expect((await read(id)).status).toBe(404);
      expect((await change(id, "edit", details("a".repeat(64)))).status).toBe(404);
      expect((await change(id, "remove", { revision: "a".repeat(64), reason: "Remove class" })).status).toBe(404);
    }
    await prisma.user.update({ where: { id: admin }, data: { status: "DISABLED" } });
    expect((await read()).status).toBe(403);
    await prisma.user.update({ where: { id: admin }, data: { status: "ACTIVE", branchId: otherBranch } });
    expect((await read()).status).toBe(404);
    await prisma.user.update({ where: { id: admin }, data: { branchId: branch } });
    await prisma.organization.update({ where: { id: orgId }, data: { status: "SUSPENDED" } });
    expect((await read()).status).toBe(403);
    await prisma.organization.update({ where: { id: orgId }, data: { status: "ACTIVE" } });
  });
  it("validates fields and teacher scope without partial writes", async () => {
    const record = (await read()).body.data;
    expect(record.teacherOptions.map((t: { id: string }) => t.id)).toContain(String(replacement));
    expect(record.teacherOptions.map((t: { id: string }) => t.id)).not.toContain(String(foreignTeacher));
    for (const extra of [{ branchId: String(otherBranch) }, { name: " " }, { name: "a".repeat(101) },
      { capacity: 0 }, { capacity: 1.5 }, { teacherId: String(admin) }, { teacherId: String(foreignTeacher) }, { reason: " " }])
      expect((await change(group, "edit", details(record.revision, extra))).status).toBe(422);
    await prisma.user.update({ where: { id: replacement }, data: { branchId: otherBranch } });
    expect((await change(group, "edit", details(record.revision, { teacherId: String(replacement) }))).status).toBe(422);
    await prisma.user.update({ where: { id: replacement }, data: { branchId: null, status: "DISABLED" } });
    expect((await change(group, "edit", details(record.revision, { teacherId: String(replacement) }))).status).toBe(422);
    await prisma.user.update({ where: { id: replacement }, data: { status: "ACTIVE" } });
    expect((await read()).body.data.name).toBe("Original class");
    expect(await prisma.auditLog.count({ where: { orgId } })).toBe(0);
  });
  it("edits, clears optional fields, records history and rejects stale edits/removals", async () => {
    const revision = (await read()).body.data.revision;
    const result = await change(group, "edit", details(revision, { teacherId: String(replacement) }));
    expect(result.status).toBe(200);
    expect(result.body.data).toMatchObject({ name: "Updated class", teacherId: String(replacement), capacity: 20 });
    expect((await change(group, "edit", details(revision))).status).toBe(409);
    expect((await change(group, "remove", { revision, reason: "Outdated request" })).status).toBe(409);
    const record = (await read()).body.data;
    expect(record.history[0]).toMatchObject({ action: "class.admin_edit", actorUser: { fullName: "Office Admin" },
      metadata: { reason: "Correct office record", before: { name: "Original class" }, after: { name: "Updated class" } } });
    expect((await change(group, "edit", details(record.revision, { teacherId: null, capacity: null }))).status).toBe(200);
    expect((await read()).body.data).toMatchObject({ teacherId: null, capacity: null });
  });
  it("blocks academic year changes and undersized capacity when students are assigned", async () => {
    await prisma.student.update({ where: { id: pupil }, data: { classId: group } });
    await prisma.student.create({ data: { orgId, branchId: branch, classId: group, fullName: "Second pupil", admissionNo: "TWO" } });
    const revision = (await read()).body.data.revision;
    expect((await change(group, "edit", details(revision, { academicYear: "2027" }))).status).toBe(409);
    expect((await change(group, "edit", details(revision, { capacity: 1 }))).status).toBe(409);
    await prisma.student.updateMany({ where: { orgId, classId: group }, data: { classId: null } });
  });
  it("protects the timetable from teacher reassignment until live slots are cancelled", async () => {
    const slot = await prisma.classTimetableSlot.create({ data: { orgId, classId: group, createdById: admin,
      weekday: 1, startsAt: "08:00", endsAt: "08:45", subject: "Quran", validFrom: new Date("2026-01-01"), validUntil: new Date("2099-12-31") } });
    let revision = (await read()).body.data.revision;
    expect((await change(group, "edit", details(revision, { teacherId: String(replacement) }))).status).toBe(409);
    await prisma.classTimetableSlot.update({ where: { id: slot.id }, data: { cancelledAt: new Date() } });
    revision = (await read()).body.data.revision;
    expect((await change(group, "edit", details(revision, { teacherId: String(replacement) }))).status).toBe(200);
  });
  it("blocks removal for every linked record, including inactive and historical links", async () => {
    const makers: Record<keyof typeof classDependencies, (id: bigint) => Promise<unknown>> = {
      currentStudents: id => prisma.student.update({ where: { id: pupil }, data: { classId: id, status: "INACTIVE" } }),
      enrollments: id => prisma.enrollment.create({ data: { orgId, classId: id, studentId: pupil, academicYear: "2026", status: "COMPLETED" } }),
      attendance: id => prisma.attendanceRecord.create({ data: { orgId, branchId: branch, classId: id, studentId: pupil, markedById: teacher, date: new Date("2026-09-01"), status: "PRESENT" } }),
      feeStructures: id => prisma.feeStructure.create({ data: { orgId, classId: id, name: "Old fee", amount: 1000, billingCycle: "MONTHLY", isActive: false } }),
      timetable: id => prisma.classTimetableSlot.create({ data: { orgId, classId: id, createdById: admin, weekday: 1, startsAt: "08:00", endsAt: "08:45", subject: "Quran", validFrom: new Date("2026-01-01"), validUntil: new Date("2026-02-01"), cancelledAt: new Date() } }),
      quranSessions: id => prisma.quranSession.create({ data: { orgId, classId: id, studentId: pupil, teacherId: teacher, clientId: randomUUID(), requestHash: "b".repeat(64), surahId: 67, ayahFrom: 1, ayahTo: 5, activity: "READING", observation: "INDEPENDENT", learnedOn: new Date("2026-09-01") } }),
      supportNotes: id => prisma.studentSupportNote.create({ data: { orgId, classId: id, studentId: pupil, createdById: teacher, clientId: randomUUID(), note: "Follow-up resolved", resolvedAt: new Date() } }),
    };
    for (const [relation, create] of Object.entries(makers)) {
      const empty = await makeClass(`With ${relation}`);
      const stale = (await read(empty.id)).body.data.revision;
      await create(empty.id);
      expect((await change(empty.id, "remove", { revision: stale, reason: "Remove empty class" })).status).toBe(409);
      const record = (await read(empty.id)).body.data;
      expect(record.canRemove).toBe(false);
      expect(record._count[relation]).toBe(1);
      expect((await change(empty.id, "remove", { revision: record.revision, reason: "Remove class" })).status).toBe(409);
      expect(await prisma.class.findUnique({ where: { id: empty.id } })).not.toBeNull();
    }
  });
  it("permanently removes only an empty class and retains its audit trail", async () => {
    const empty = await makeClass("Created in error");
    const record = (await read(empty.id)).body.data;
    expect(record.canRemove).toBe(true);
    expect((await change(empty.id, "remove", { revision: record.revision, reason: " " })).status).toBe(422);
    expect((await change(empty.id, "remove", { revision: record.revision, reason: "Duplicate empty class" })).status).toBe(200);
    expect(await prisma.class.findUnique({ where: { id: empty.id } })).toBeNull();
    expect((await read(empty.id)).status).toBe(404);
    const audit = await prisma.auditLog.findFirst({ where: { orgId, entityType: "Class", entityId: String(empty.id), action: "class.admin_remove" } });
    expect(audit?.metadata).toMatchObject({ reason: "Duplicate empty class", before: { name: "Created in error" }, after: null });
    expect((await change(empty.id, "remove", { revision: record.revision, reason: "Duplicate retry" })).status).toBe(404);
    expect(await prisma.auditLog.count({ where: { orgId, entityId: String(empty.id), action: "class.admin_remove" } })).toBe(1);
  });
});
