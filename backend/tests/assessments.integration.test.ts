import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { beforeAll, afterAll, describe, expect, it } from "vitest";
import { prisma } from "../src/shared/db/prisma";
import { env } from "../src/config/env";
import { api } from "./helpers/api-client";

describe("reviewed academic assessments", () => {
  let orgId: bigint, otherOrg: bigint, branchId: bigint, branch2: bigint;
  let teacher: bigint, teacher2: bigint, admin: bigint, parent: bigint, stranger: bigint;
  let classId: bigint, subjectId: bigint, child: bigint, peer: bigint, guardianId: bigint;
  let id: string, revision: number;
  const auth = (user: bigint, role?: string, org = orgId) => `Bearer ${jwt.sign({
    sub: String(user), orgId: String(org), role: role ?? (user === admin ? "ADMIN" : [teacher, teacher2].includes(user) ? "TEACHER" : "PARENT"), type: "access",
  }, env.JWT_SECRET, { expiresIn: "10m" })}`;
  const get = (path: string, user = teacher, role?: string, org = orgId) =>
    api.get(`/api/assessments${path}`).set("Authorization", auth(user, role, org));
  const post = (path: string, body: object, user = teacher, role?: string) =>
    api.post(`/api/assessments${path}`).set("Authorization", auth(user, role)).send(body);
  const creation = () => ({ clientId: randomUUID(), classId: String(classId), subjectId: String(subjectId),
    title: "Wudu practical", assessedOn: "2026-09-20", maxScore: 10 });
  const results = (score: number | null = 8) => [
    { studentId: String(child), score, feedback: "Good sequence" },
    { studentId: String(peer), score: 6, feedback: "PEER PRIVATE FEEDBACK" },
  ];
  const academic = (user = parent, student = child) => get(`/children/${student}/academic?year=2026`, user);
  const transition = (action: string, user = teacher, reason?: string) =>
    post(`/${id}/transition`, { action, revision, ...(reason ? { reason } : {}) }, user);

  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Academic test", code: randomUUID() } })).id;
    otherOrg = (await prisma.organization.create({ data: { name: "Other academic test", code: randomUUID() } })).id;
    branchId = (await prisma.branch.create({ data: { orgId, name: "Main" } })).id;
    branch2 = (await prisma.branch.create({ data: { orgId, name: "Other" } })).id;
    const users = [];
    for (const role of ["TEACHER", "TEACHER", "ADMIN", "PARENT", "PARENT"] as const)
      users.push((await prisma.user.create({ data: { orgId, role, fullName: role, passwordHash: "not-a-login" } })).id);
    [teacher, teacher2, admin, parent, stranger] = users as [bigint, bigint, bigint, bigint, bigint];
    classId = (await prisma.class.create({ data: { orgId, branchId, name: "Level 2A", level: "Primary", academicYear: "2026", teacherId: teacher } })).id;
    subjectId = (await prisma.subject.create({ data: { orgId, code: "FIQH", name: "Fiqh" } })).id;
    child = (await prisma.student.create({ data: { orgId, branchId, classId, fullName: "Amina", admissionNo: "A1", notes: "INTERNAL SUPPORT" } })).id;
    peer = (await prisma.student.create({ data: { orgId, branchId, classId, fullName: "PEER PRIVATE NAME", admissionNo: "A2" } })).id;
    guardianId = (await prisma.guardian.create({ data: { orgId, userId: parent, fullName: "Parent", phone: "PRIVATE PHONE" } })).id;
    await prisma.studentGuardian.create({ data: { orgId, guardianId, studentId: child } });
  });
  afterAll(async () => {
    const where = { orgId: { in: [orgId, otherOrg].filter(Boolean) } };
    await prisma.assessmentRelease.deleteMany({ where });
    await prisma.assessmentResult.deleteMany({ where });
    await prisma.assessment.deleteMany({ where });
    await prisma.auditLog.deleteMany({ where });
    await prisma.studentGuardian.deleteMany({ where });
    await prisma.student.deleteMany({ where });
    await prisma.guardian.deleteMany({ where });
    await prisma.subject.deleteMany({ where });
    await prisma.class.deleteMany({ where });
    await prisma.user.deleteMany({ where });
    await prisma.branch.deleteMany({ where });
    await prisma.organization.deleteMany({ where: { id: where.orgId } });
  });
  it("requires live staff assignment and validates inputs before taking a roster snapshot", async () => {
    expect((await api.get("/api/assessments")).status).toBe(401);
    expect((await get("", parent)).status).toBe(403);
    expect((await get("", parent, "TEACHER")).status).toBe(403);
    expect((await get("/options", teacher2)).body.data.classes).toEqual([]);
    expect((await post("", creation(), teacher2)).status).toBe(404);
    expect((await post("", creation(), admin)).status).toBe(403);
    for (const patch of [{ maxScore: 0 }, { assessedOn: "2026-02-30" }, { assessedOn: "2099-01-01" }, { published: true }])
      expect((await post("", { ...creation(), ...patch })).status).toBe(422);
    const foreign = await prisma.subject.create({ data: { orgId: otherOrg, code: "OTHER", name: "Other subject" } });
    expect((await post("", { ...creation(), subjectId: String(foreign.id) })).status).toBe(422);
    const input = creation(), response = await post("", input);
    expect(response.status).toBe(200);
    id = response.body.data.id; revision = response.body.data.revision;
    expect(response.body.data.results).toHaveLength(2);
    expect(response.body.data.results.every((r: { score: unknown }) => r.score === null)).toBe(true);
    expect((await post("", input)).body.data.id).toBe(id);
    expect((await post("", { ...input, title: "Changed request" })).status).toBe(409);
    expect((await academic()).body.data.records).toEqual([]);
    expect((await get(`/${id}`, teacher2)).status).toBe(404);
    expect((await get(`/${id}`, parent)).status).toBe(403);
  });
  it("saves complete rosters atomically, keeps blanks distinct from zero, rejects stale edits", async () => {
    expect((await transition("submit")).status).toBe(422);
    expect((await post(`/${id}/results`, { revision, results: results(11) })).status).toBe(422);
    expect((await post(`/${id}/results`, { revision, results: results().slice(0, 1) })).status).toBe(422);
    expect((await post(`/${id}/results`, { revision, results: [results()[0], results()[0]] })).status).toBe(422);
    expect((await post(`/${id}/results`, { revision, results: results() }, admin)).status).toBe(403);
    const saved = await post(`/${id}/results`, { revision, results: results(0) });
    expect(saved.status).toBe(200);
    expect(saved.body.data.results[0].score).toBe(0);
    expect((await post(`/${id}/results`, { revision, results: results() })).status).toBe(409);
    revision = saved.body.data.revision;
    const updated = await post(`/${id}/results`, { revision, results: results() });
    expect(updated.status).toBe(200); revision = updated.body.data.revision;
  });
  it("keeps submitted marks private and limits review/publication to administrators", async () => {
    expect((await transition("publish")).status).toBe(403);
    const submitted = await transition("submit");
    expect(submitted.status).toBe(200); revision = submitted.body.data.revision;
    expect((await academic()).body.data.records).toEqual([]);
    expect((await post(`/${id}/results`, { revision, results: results() })).status).toBe(409);
    expect((await transition("return", admin)).status).toBe(422);
    const returned = await transition("return", admin, "Please verify the observation");
    expect(returned.status).toBe(200); revision = returned.body.data.revision;
    expect(returned.body.data.status).toBe("DRAFT");
    revision = (await transition("submit")).body.data.revision;
    const published = await transition("publish", admin);
    expect(published.status).toBe(200); revision = published.body.data.revision;
    const data = await academic();
    expect(data.status).toBe(200); expect(data.headers["cache-control"]).toBe("no-store");
    expect(data.body.data.average).toBe(80);
    expect(data.body.data.subjects).toMatchObject([{ name: "Fiqh", average: 80, assessments: 1 }]);
    expect(JSON.stringify(data.body)).not.toMatch(/PEER PRIVATE|INTERNAL SUPPORT|PRIVATE PHONE/);
    expect((await academic(parent, peer)).status).toBe(404);
    expect((await academic(stranger)).status).toBe(404);
    expect((await get("/children/1/academic?year=2026&parentId=1", parent)).status).toBe(422);
  });
  it("publishes immutable snapshots and retracts without destroying the prior publication", async () => {
    const released = await prisma.assessmentRelease.findFirstOrThrow({ where: { assessmentId: BigInt(id) } });
    await prisma.subject.update({ where: { id: subjectId }, data: { name: "Renamed subject" } });
    await prisma.assessmentResult.update({ where: { assessmentId_studentId: { assessmentId: BigInt(id), studentId: child } }, data: { score: 9 } });
    expect((await academic()).body.data.records[0]).toMatchObject({ score: 8, subject: { name: "Fiqh" } });
    expect((await transition("retract", teacher, "Correction")).status).toBe(403);
    const retracted = await transition("retract", admin, "Correct a transcription error");
    expect(retracted.status).toBe(200); revision = retracted.body.data.revision;
    expect((await academic()).body.data.records).toEqual([]);
    const previous = await prisma.assessmentRelease.findUniqueOrThrow({ where: { id: released.id } });
    expect(previous.snapshot).toEqual(released.snapshot); expect(previous.retractedAt).not.toBeNull();
    revision = (await transition("submit")).body.data.revision;
    revision = (await transition("publish", admin)).body.data.revision;
    expect((await academic()).body.data.average).toBe(90);
    expect(await prisma.assessmentRelease.count({ where: { assessmentId: BigInt(id) } })).toBe(2);
  });
  it("rechecks guardian, teacher, branch and account access; protects class history", async () => {
    await prisma.class.update({ where: { id: classId }, data: { teacherId: teacher2 } });
    expect((await get(`/${id}`)).status).toBe(404);
    expect((await get(`/${id}`, teacher2)).status).toBe(200);
    await prisma.user.update({ where: { id: teacher2 }, data: { branchId: branch2 } });
    expect((await get(`/${id}`, teacher2)).status).toBe(404);
    await prisma.studentGuardian.deleteMany({ where: { orgId, guardianId } });
    expect((await academic()).status).toBe(404);
    await prisma.studentGuardian.create({ data: { orgId, guardianId, studentId: child } });
    await prisma.user.update({ where: { id: parent }, data: { status: "DISABLED" } });
    expect((await academic()).status).toBe(403);
    await prisma.user.update({ where: { id: parent }, data: { status: "ACTIVE" } });
    const management = await api.get(`/api/admin/classes/${classId}/record`).set("Authorization", auth(admin));
    // The FK protects history even if a future removal path forgets its guard.
    await expect(prisma.class.delete({ where: { id: classId } })).rejects.toMatchObject({ code: "P2003" });
    const audit = await prisma.auditLog.findMany({ where: { orgId, entityType: "Assessment" } });
    expect(audit.some(a => a.action === "assessment.retract")).toBe(true);
    expect(JSON.stringify(audit.map(a => a.metadata))).not.toContain("PEER PRIVATE");
    expect(management.status).toBe(200);
    expect(management.body.data._count.assessments).toBe(1);
    expect(management.body.data.canRemove).toBe(false);
  });
  it("rejects cross-tenant result relations and scopes dates and school suspension", async () => {
    const foreignBranch = await prisma.branch.create({ data: { orgId: otherOrg, name: "Foreign" } });
    const foreignChild = await prisma.student.create({ data: { orgId: otherOrg, branchId: foreignBranch.id, fullName: "Foreign", admissionNo: "F1" } });
    await expect(prisma.assessmentResult.create({ data: { orgId, assessmentId: BigInt(id), studentId: foreignChild.id, score: 5 } })).rejects.toMatchObject({ code: "P2003" });
    expect((await get(`/children/${child}/academic?year=2025`, parent)).body.data.average).toBeNull();
    await prisma.organization.update({ where: { id: orgId }, data: { status: "SUSPENDED" } });
    expect((await academic()).status).toBe(403);
    await prisma.organization.update({ where: { id: orgId }, data: { status: "ACTIVE" } });
  });
});
