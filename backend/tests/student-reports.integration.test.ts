import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/shared/db/prisma";
import { env } from "../src/config/env";
import { api } from "./helpers/api-client";

describe("reviewed student reports and protected PDFs", () => {
  let orgId: bigint, otherOrg: bigint, branchId: bigint, classId: bigint, subjectId: bigint;
  let teacher: bigint, otherTeacher: bigint, admin: bigint, parent: bigint, stranger: bigint;
  let child: bigint, peer: bigint, guardianId: bigint, assessmentId: bigint, assessmentReleaseId: bigint;
  let periodId: string, id: string, revision: number, releaseId: string;
  const auth = (user: bigint) => `Bearer ${jwt.sign({ sub: String(user), orgId: String(orgId),
    role: user === admin ? "ADMIN" : [teacher, otherTeacher].includes(user) ? "TEACHER" : "PARENT", type: "access" }, env.JWT_SECRET, { expiresIn: "10m" })}`;
  const get = (path: string, user = teacher) => api.get(`/api/student-reports${path}`).set("Authorization", auth(user));
  const post = (path: string, body: object, user = teacher) => api.post(`/api/student-reports${path}`).set("Authorization", auth(user)).send(body);
  const family = (user = parent, student = child) => get(`/children/${student}`, user);
  const transition = (action: string, user = teacher, reason?: string) => post(`/${id}/transition`, { action, revision, ...(reason ? { reason } : {}) }, user);
  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Report Test School", code: randomUUID() } })).id;
    otherOrg = (await prisma.organization.create({ data: { name: "Foreign report school", code: randomUUID() } })).id;
    branchId = (await prisma.branch.create({ data: { orgId, name: "Main" } })).id;
    const users: bigint[] = [];
    for (const role of ["TEACHER", "TEACHER", "ADMIN", "PARENT", "PARENT"] as const)
      users.push((await prisma.user.create({ data: { orgId, role, fullName: role, passwordHash: "not-a-login" } })).id);
    [teacher, otherTeacher, admin, parent, stranger] = users as [bigint, bigint, bigint, bigint, bigint];
    classId = (await prisma.class.create({ data: { orgId, branchId, teacherId: teacher, name: "Level 1A", level: "Primary", academicYear: "2026" } })).id;
    subjectId = (await prisma.subject.create({ data: { orgId, code: "FIQH", name: "Fiqh" } })).id;
    child = (await prisma.student.create({ data: { orgId, branchId, classId, fullName: "Amina Hassan", admissionNo: "AFQ-1", notes: "INTERNAL NOTE" } })).id;
    peer = (await prisma.student.create({ data: { orgId, branchId, classId, fullName: "SECRET PEER", admissionNo: "AFQ-2" } })).id;
    guardianId = (await prisma.guardian.create({ data: { orgId, userId: parent, fullName: "Parent", phone: "PRIVATE PHONE" } })).id;
    await prisma.studentGuardian.create({ data: { orgId, guardianId, studentId: child } });
    assessmentId = (await prisma.assessment.create({ data: { orgId, classId, subjectId, createdById: teacher,
      clientId: randomUUID(), title: "Wudu", assessedOn: new Date("2026-09-10"), maxScore: 10, status: "PUBLISHED" } })).id;
    await prisma.assessmentResult.createMany({ data: [child, peer].map(studentId => ({ orgId, assessmentId, studentId, score: 8 })) });
    assessmentReleaseId = (await prisma.assessmentRelease.create({ data: { orgId, assessmentId, revision: 1, publishedById: admin,
      snapshot: { title: "Wudu", assessedOn: "2026-09-10", subject: { id: String(subjectId), name: "Fiqh" }, maxScore: 10,
        teacher: "Teacher", results: [{ studentId: String(child), score: 8, feedback: "Good sequence" },
          { studentId: String(peer), score: 9, feedback: "SECRET PEER FEEDBACK" }] } } })).id;
    for (const [index, status] of (["PRESENT", "LATE", "ABSENT", "EXCUSED"] as const).entries())
      await prisma.attendanceRecord.create({ data: { orgId, branchId, classId, studentId: child, markedById: teacher,
        date: new Date(`2026-09-${10 + index}`), status, reason: "PRIVATE ABSENCE REASON" } });
    for (const [from, to, activity] of [[1, 5, "MEMORIZATION"], [3, 8, "MEMORIZATION"], [1, 10, "READING"], [1, 4, "REVISION"]] as const)
      await prisma.quranSession.create({ data: { orgId, classId, studentId: child, teacherId: teacher, clientId: randomUUID(),
        requestHash: "0".repeat(64), surahId: 67, ayahFrom: from, ayahTo: to, activity, observation: "INDEPENDENT",
        learnedOn: new Date("2026-09-15"), note: "PRIVATE QURAN NOTE" } });
  });
  afterAll(async () => {
    const where = { orgId: { in: [orgId, otherOrg].filter(Boolean) } };
    await prisma.reportAssessmentSource.deleteMany({ where }); await prisma.reportRelease.deleteMany({ where });
    await prisma.studentReport.deleteMany({ where }); await prisma.reportingPeriod.deleteMany({ where });
    await prisma.assessmentRelease.deleteMany({ where }); await prisma.assessmentResult.deleteMany({ where });
    await prisma.assessment.deleteMany({ where }); await prisma.attendanceRecord.deleteMany({ where });
    await prisma.quranSession.deleteMany({ where }); await prisma.auditLog.deleteMany({ where });
    await prisma.studentGuardian.deleteMany({ where }); await prisma.student.deleteMany({ where });
    await prisma.guardian.deleteMany({ where }); await prisma.subject.deleteMany({ where }); await prisma.class.deleteMany({ where });
    await prisma.user.deleteMany({ where }); await prisma.branch.deleteMany({ where });
    await prisma.organization.deleteMany({ where: { id: where.orgId } });
  });
  it("validates administrator-owned periods and idempotent preparation", async () => {
    const input = { clientId: randomUUID(), name: "September learning", startsOn: "2026-09-01", endsOn: "2026-09-20" };
    expect((await api.get("/api/student-reports")).status).toBe(401);
    expect((await post("/periods", input)).status).toBe(403);
    expect((await post("/periods", { ...input, endsOn: "2026-02-30" }, admin)).status).toBe(422);
    expect((await post("/periods", { ...input, endsOn: "2025-09-20" }, admin)).status).toBe(422);
    const period = await post("/periods", input, admin);
    expect(period.status).toBe(200); periodId = period.body.data.id;
    expect((await post("/periods", input, admin)).body.data.id).toBe(periodId);
    expect((await post("/periods", { ...input, name: "Changed" }, admin)).status).toBe(409);
    const prepare = { periodId, studentId: String(child) };
    expect((await post("", prepare, otherTeacher)).status).toBe(404);
    expect((await post("", prepare, admin)).status).toBe(403);
    const draft = await post("", prepare);
    expect(draft.status).toBe(200); id = draft.body.data.id; revision = draft.body.data.revision;
    expect(draft.body.data.sourcesCurrent).toBe(true);
    expect((await post("", prepare)).body.data.id).toBe(id);
    expect((await get(`/${id}`, parent)).status).toBe(403);
    expect((await get(`/${id}`, otherTeacher)).status).toBe(404);
    expect((await get("/not-an-id")).status).toBe(422);
  });
  it("composes only this learner's records with correct attendance and unique ayahs", async () => {
    const draft = (await get(`/${id}`)).body.data.draft;
    expect(draft.attendance).toEqual({ present: 1, late: 1, absent: 1, excused: 1, recorded: 4, rate: 66.67 });
    expect(draft.quran).toEqual({ sessions: 4, memorisedAyahs: 8, reading: 1, revision: 1, tajweed: 0 });
    expect(draft.assessments).toMatchObject([{ subject: "Fiqh", score: 8, maxScore: 10 }]);
    expect(JSON.stringify(draft)).not.toMatch(/SECRET PEER|PRIVATE|INTERNAL/);
    expect((await family()).body.data.items).toEqual([]);
    expect((await transition("submit")).status).toBe(422);
    const saved = await post(`/${id}/draft`, { revision, feedback: "Continue revising at home." });
    expect(saved.status).toBe(200);
    expect((await post(`/${id}/draft`, { revision, feedback: "Stale" })).status).toBe(409);
    revision = saved.body.data.revision;
  });
  it("requires renewed teacher review when source data changes before publication", async () => {
    revision = (await transition("submit")).body.data.revision;
    expect((await family()).body.data.items).toEqual([]);
    expect((await transition("publish")).status).toBe(403);
    await prisma.attendanceRecord.update({ where: { orgId_studentId_date: { orgId, studentId: child, date: new Date("2026-09-12") } }, data: { status: "PRESENT" } });
    expect((await get(`/${id}`, admin)).body.data.sourcesCurrent).toBe(false);
    expect((await transition("publish", admin)).status).toBe(409);
    expect((await transition("return", admin)).status).toBe(422);
    revision = (await transition("return", admin, "Refresh attendance before release")).body.data.revision;
    revision = (await post(`/${id}/draft`, { revision, feedback: "Continue revising at home." })).body.data.revision;
    revision = (await transition("submit")).body.data.revision;
    const published = await transition("publish", admin);
    expect(published.status).toBe(200); revision = published.body.data.revision;
    releaseId = published.body.data.releases[0].id;
    const released = await family();
    expect(released.status).toBe(200); expect(released.headers["cache-control"]).toBe("no-store");
    expect(released.body.data.items).toHaveLength(1);
    const issued = released.body.data.items[0];
    expect(issued.publishedOn).toBe(new Date(new Date(issued.createdAt).getTime() + 3 * 3600000).toISOString().slice(0, 10));
    expect(JSON.stringify(released.body)).not.toMatch(/SECRET PEER|PRIVATE|INTERNAL/);
  });
  it("downloads authenticated PDF snapshots and never exposes another child's report", async () => {
    const path = `/children/${child}/${releaseId}/pdf`;
    const pdf = await get(path, parent);
    expect(pdf.status).toBe(200); expect(pdf.headers["cache-control"]).toBe("no-store");
    expect(pdf.body.data.contentType).toBe("application/pdf");
    const bytes = Buffer.from(pdf.body.data.base64, "base64");
    expect(bytes.subarray(0, 5).toString()).toBe("%PDF-"); expect(bytes.length).toBeGreaterThan(5000);
    expect((await get(path, stranger)).status).toBe(404);
    expect((await get(`/children/${peer}/${releaseId}/pdf`, parent)).status).toBe(404);
    expect((await api.get(`/api/student-reports${path}`)).status).toBe(401);
    const prior = (await family()).body.data.items[0].snapshot;
    await prisma.student.update({ where: { id: child }, data: { fullName: "Changed name" } });
    expect((await family()).body.data.items[0].snapshot).toEqual(prior);
    expect((await post(`/${id}/draft`, { revision, feedback: "Changed" })).status).toBe(409);
  });
  it("withholds reports whose source publication is retracted, and preserves report history", async () => {
    await prisma.assessmentRelease.update({ where: { id: assessmentReleaseId }, data: { retractedAt: new Date(), retractionReason: "Correction" } });
    expect((await family()).body.data.items).toEqual([]);
    expect((await get(`/children/${child}/${releaseId}/pdf`, parent)).status).toBe(404);
    expect((await get(`/${id}`, admin)).body.data.sourcesCurrent).toBe(false);
    expect((await transition("retract", teacher, "Correction")).status).toBe(403);
    const old = await prisma.reportRelease.findUniqueOrThrow({ where: { id: BigInt(releaseId) } });
    const retracted = await transition("retract", admin, "Assessment correction requires a new report");
    expect(retracted.status).toBe(200); revision = retracted.body.data.revision;
    expect((await prisma.reportRelease.findUniqueOrThrow({ where: { id: old.id } })).snapshot).toEqual(old.snapshot);
    revision = (await post(`/${id}/draft`, { revision, feedback: "Corrected learning report" })).body.data.revision;
    revision = (await transition("submit")).body.data.revision;
    const published = await transition("publish", admin);
    expect(published.status).toBe(200); revision = published.body.data.revision;
    expect(published.body.data.releases[0].id).not.toBe(releaseId);
    expect((await family()).body.data.items[0].snapshot.assessments).toEqual([]);
    expect(await prisma.reportRelease.count({ where: { orgId } })).toBe(2);
    expect((await get(`/children/${child}/${releaseId}/pdf`, parent)).status).toBe(404);
  });
  it("blocks incomplete and future-period reports and handles concurrent draft saves", async () => {
    const future = (await post("/periods", { clientId: randomUUID(), name: "Future", startsOn: "2099-01-01", endsOn: "2099-02-01" }, admin)).body.data;
    const futureReport = (await post("", { periodId: future.id, studentId: String(child) })).body.data;
    expect((await post(`/${futureReport.id}/transition`, { action: "submit", revision: 1 })).status).toBe(422);
    const emptyStudent = await prisma.student.create({ data: { orgId, branchId, classId, fullName: "No records", admissionNo: "EMPTY" } });
    const empty = (await post("", { periodId, studentId: String(emptyStudent.id) })).body.data;
    const saved = await Promise.all([1, 2].map(() => post(`/${empty.id}/draft`, { revision: 1, feedback: "Needs learning records" })));
    expect(saved.map(r => r.status).sort()).toEqual([200, 409]);
    expect((await post(`/${empty.id}/transition`, { action: "submit", revision: 2 })).status).toBe(422);
    expect((await get(`/${empty.id}/pdf`)).status).toBe(200);
    expect((await get("/options", parent)).status).toBe(403);
  });
  it("rechecks links, disabled accounts, class assignments, and restrictive tenant relations", async () => {
    await prisma.studentGuardian.deleteMany({ where: { orgId, guardianId } });
    expect((await family()).status).toBe(404);
    await prisma.studentGuardian.create({ data: { orgId, guardianId, studentId: child } });
    await prisma.user.update({ where: { id: parent }, data: { status: "DISABLED" } });
    expect((await family()).status).toBe(403);
    await prisma.user.update({ where: { id: parent }, data: { status: "ACTIVE" } });
    await prisma.class.update({ where: { id: classId }, data: { teacherId: otherTeacher } });
    expect((await get(`/${id}`)).status).toBe(404);
    expect((await get(`/${id}`, otherTeacher)).status).toBe(200);
    const foreign = await prisma.user.create({ data: { orgId: otherOrg, role: "ADMIN", fullName: "Foreign", passwordHash: "not-a-login" } });
    await expect(prisma.reportingPeriod.create({ data: { orgId, createdById: foreign.id, clientId: randomUUID(), name: "Invalid",
      startsOn: new Date("2026-09-01"), endsOn: new Date("2026-09-20") } })).rejects.toMatchObject({ code: "P2003" });
    await expect(prisma.class.delete({ where: { id: classId } })).rejects.toMatchObject({ code: "P2003" });
    const log = await prisma.auditLog.findMany({ where: { orgId, action: "student-report.retract" } });
    expect(log).toHaveLength(1);
  });
});
