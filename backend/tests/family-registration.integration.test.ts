import { randomBytes } from "node:crypto";
import bcrypt from "bcryptjs";
import request from "supertest";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/shared/db/prisma";
import { createApp } from "../src/app/create-app";
import { issueFamilyRegistration } from "../src/modules/users/family-registration";

const enabled = process.env.PLATFORM_STAGING_RUN === "isolated";
if (enabled && !/^mysql:\/\/root@127\.0\.0\.1:\d+\/afaq_platform_staging_[a-f0-9]+$/.test(process.env.DATABASE_URL ?? "")) {
  throw new Error("Family tests require the disposable staging database");
}

describe.skipIf(!enabled)("family accounts in disposable MariaDB", () => {
  const password = randomBytes(20).toString("hex");
  let api: ReturnType<typeof request>;
  let orgId: bigint, branchId: bigint, adminId: bigint, parentId: bigint, otherParentId: bigint;
  let adminToken: string, familyNumber: string, originalHash: string;
  let children: bigint[], unrelated: bigint;
  const actor = () => ({ userId: String(adminId), orgId: String(orgId) });
  const issue = (id: bigint, token = adminToken) => api.post(`/api/users/${id}/family-registration`)
    .set("Authorization", `Bearer ${token}`).send({ regionCode: "DSM" });

  beforeAll(async () => {
    api = request(createApp());
    const org = await prisma.organization.create({ data: { name: "Family test school", code: "family-test" } });
    orgId = org.id;
    const branch = await prisma.branch.create({ data: { orgId, name: "Main" } });
    branchId = branch.id;
    originalHash = await bcrypt.hash(password, 4);
    const admin = await prisma.user.create({ data: { orgId, branchId, fullName: "School Admin", email: "family-admin@example.test", role: "ADMIN", passwordHash: originalHash } });
    adminId = admin.id;
    const parent = await prisma.user.create({ data: { orgId, branchId, fullName: "Family Parent", email: "family-parent@example.test", role: "PARENT", passwordHash: originalHash } });
    parentId = parent.id;
    const guardian = await prisma.guardian.create({ data: { orgId, userId: parentId, fullName: "Family Parent", phone: "255700000100" } });
    const other = await prisma.user.create({ data: { orgId, branchId, fullName: "Other Parent", email: "other-family@example.test", role: "PARENT", passwordHash: originalHash } });
    otherParentId = other.id;
    await prisma.guardian.create({ data: { orgId, userId: other.id, fullName: "Other Parent", phone: "255700000200" } });
    children = [];
    for (const n of [1, 2]) {
      const child = await prisma.student.create({ data: { orgId, branchId, admissionNo: `CHILD-${n}`, fullName: `Child ${n}` } });
      children.push(child.id);
      await prisma.studentGuardian.create({ data: { orgId, studentId: child.id, guardianId: guardian.id } });
    }
    unrelated = (await prisma.student.create({ data: { orgId, branchId, admissionNo: "OTHER-CHILD", fullName: "Unrelated Child" } })).id;
    const response = await api.post("/api/auth/login").send({ login: admin.email, password }).expect(200);
    adminToken = response.body.data.accessToken;
  }, 30_000);
  afterAll(async () => { await prisma.$disconnect(); });

  it("issues once through HTTP and keeps the password and children's admission numbers", async () => {
    const first = await issue(parentId).expect(200);
    familyNumber = first.body.data.familyLoginId;
    expect(familyNumber).toMatch(/^DSM\/FAM\/\d{2}\/001$/);
    expect((await issue(parentId).expect(200)).body.data.familyLoginId).toBe(familyNumber);
    expect((await prisma.user.findUniqueOrThrow({ where: { id: parentId } })).passwordHash).toBe(originalHash);
    expect(await prisma.auditLog.count({ where: { action: "family.registration.issued", entityId: String(parentId) } })).toBe(1);
    expect((await prisma.student.findMany({ where: { id: { in: children } }, orderBy: { id: "asc" } })).map(c => c.admissionNo)).toEqual(["CHILD-1", "CHILD-2"]);
  });

  it("logs in with the family number and only exposes its two linked children", async () => {
    const login = await api.post("/api/auth/login").send({ login: ` ${familyNumber.toLowerCase()} `, password }).expect(200);
    const token = login.body.data.accessToken;
    expect(login.body.data.user.role).toBe("PARENT");
    for (const path of ["/api/parent-portal/me", "/api/parent-portal/workspace/overview"]) {
      const profile = await api.get(path).set("Authorization", `Bearer ${token}`).expect(200);
      expect(profile.body.data.guardian.familyLoginId).toBe(familyNumber);
      expect(profile.body.data.guardian.user).toBeUndefined();
      expect(JSON.stringify(profile.body)).not.toContain("passwordHash");
    }
    const response = await api.get("/api/parent-portal/students").set("Authorization", `Bearer ${token}`).expect(200);
    expect(response.body.data.map((child: { id: string }) => child.id).sort()).toEqual(children.map(String).sort());
    await api.get(`/api/parent-portal/students/${unrelated}/attendance`).set("Authorization", `Bearer ${token}`).expect(404);
    await issue(otherParentId, token).expect(403);
    const denied = await api.post("/api/auth/login").send({ login: familyNumber, password: "wrong" }).expect(401);
    expect(denied.body.message).toBe("Invalid credentials");
  });

  it("rejects cross-school, cross-branch and unlinked targets", async () => {
    const otherOrg = await prisma.organization.create({ data: { name: "Other school", code: "other-family-school" } });
    const foreignParent = await prisma.user.create({ data: { orgId: otherOrg.id, fullName: "Foreign", role: "PARENT", passwordHash: originalHash } });
    await issue(foreignParent.id).expect(404);
    const branch = await prisma.branch.create({ data: { orgId, name: "Other branch" } });
    await prisma.user.update({ where: { id: otherParentId }, data: { branchId: branch.id } });
    try {
      await issue(otherParentId).expect(404);
      const list = await api.get("/api/users?role=PARENT").set("Authorization", `Bearer ${adminToken}`).expect(200);
      expect(list.body.data.map((row: { id: string }) => row.id)).not.toContain(String(otherParentId));
      expect(list.body.data.map((row: { id: string }) => row.id)).not.toContain(String(foreignParent.id));
      const family = list.body.data.find((row: { id: string }) => row.id === String(parentId));
      expect(family.guardianProfile.children.map((row: { id: string }) => row.id).sort()).toEqual(children.map(String).sort());
      expect(family.passwordHash).toBeUndefined();
    }
    finally { await prisma.user.update({ where: { id: otherParentId }, data: { branchId } }); }
    const unlinked = await prisma.user.create({ data: { orgId, branchId, fullName: "Unlinked", role: "PARENT", passwordHash: originalHash } });
    await issue(unlinked.id).expect(404);
  });

  it("supports browser cookie login and refresh without exposing a refresh token", async () => {
    const browser = request.agent(createApp());
    const login = await browser.post("/api/auth/browser/login")
      .set("Origin", "http://127.0.0.1:8087").set("X-MIF-Browser", "1")
      .send({ login: familyNumber, password }).expect(200);
    expect(login.body.data.refreshToken).toBeUndefined();
    expect(String(login.headers["set-cookie"] ?? "")).toContain("HttpOnly");
    const refreshed = await browser.post("/api/auth/browser/refresh")
      .set("Origin", "http://127.0.0.1:8087").set("X-MIF-Browser", "1").expect(200);
    expect(refreshed.body.data.user.id).toBe(String(parentId));
    expect(refreshed.body.data.refreshToken).toBeUndefined();
  });

  it("serializes concurrent issuance for one family without duplicate audit entries", async () => {
    const results = await Promise.all([
      issueFamilyRegistration(prisma, actor(), String(otherParentId), "DSM"),
      issueFamilyRegistration(prisma, actor(), String(otherParentId), "DSM"),
    ]);
    expect(results[0]!.familyLoginId).toBe(results[1]!.familyLoginId);
    expect(results[0]!.familyLoginId).not.toBe(familyNumber);
    expect(await prisma.auditLog.count({ where: { action: "family.registration.issued", entityId: String(otherParentId) } })).toBe(1);
  });

  it("rolls back both allocation and identity when the audit insert fails", async () => {
    const parent = await prisma.user.create({ data: { orgId, branchId, fullName: "Rollback Family", role: "PARENT", passwordHash: originalHash } });
    await prisma.guardian.create({ data: { orgId, userId: parent.id, fullName: "Rollback Family", phone: "255700000300" } });
    await prisma.$executeRawUnsafe("CREATE TRIGGER family_audit_failure BEFORE INSERT ON audit_logs FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'test audit failure'");
    try {
      await expect(issueFamilyRegistration(prisma, actor(), String(parent.id), "TST")).rejects.toThrow();
      expect((await prisma.user.findUniqueOrThrow({ where: { id: parent.id } })).familyLoginId).toBeNull();
      expect(await prisma.familyRegistrationCounter.count({ where: { regionCode: "TST" } })).toBe(0);
    } finally { await prisma.$executeRawUnsafe("DROP TRIGGER family_audit_failure"); }
  });

  it("allocates distinct numbers across schools sharing a region and year", async () => {
    const org = await prisma.organization.create({ data: { name: "Second issuing school", code: "second-issuer" } });
    const admin = await prisma.user.create({ data: { orgId: org.id, fullName: "Second Admin", role: "ADMIN", passwordHash: originalHash } });
    const makeParent = async (school: bigint, name: string, phone: string) => {
      const parent = await prisma.user.create({ data: { orgId: school, branchId: school === orgId ? branchId : null, fullName: name, role: "PARENT", passwordHash: originalHash } });
      await prisma.guardian.create({ data: { orgId: school, userId: parent.id, fullName: name, phone } });
      return parent;
    };
    const first = await makeParent(orgId, "First school family", "255700000401");
    const second = await makeParent(org.id, "Second school family", "255700000402");
    const results = await Promise.all([
      issueFamilyRegistration(prisma, actor(), String(first.id), "ARU"),
      issueFamilyRegistration(prisma, { userId: String(admin.id), orgId: String(org.id) }, String(second.id), "ARU"),
    ]);
    expect(new Set(results.map(result => result.familyLoginId)).size).toBe(2);
    expect(results.map(result => result.familyLoginId.split("/").at(-1)).sort()).toEqual(["001", "002"]);
  });

  it("concurrent parent creation never steals an existing guardian link or leaves an orphan account", async () => {
    const guardian = await prisma.guardian.create({ data: { orgId, fullName: "New Family", phone: "255700000500" } });
    const child = await prisma.student.create({ data: { orgId, branchId, fullName: "New Family Child", admissionNo: "NEW-FAMILY-CHILD" } });
    await prisma.studentGuardian.create({ data: { orgId, guardianId: guardian.id, studentId: child.id } });
    const available = await api.get('/api/users/family-guardians?page=1&pageSize=10&search=New%20Family')
      .set('Authorization', `Bearer ${adminToken}`).expect(200);
    expect(available.body.data.items.map((row: { id: string }) => row.id)).toContain(String(guardian.id));
    expect(available.body.data.items.find((row: { id: string }) => row.id === String(guardian.id)).displayName)
      .toContain('New Family Child (NEW-FAMILY-CHILD)');
    const guardianOption = available.body.data.items.find((row: { id: string }) => row.id === String(guardian.id));
    expect(guardianOption.contactLabel).toBe('New Family - 255700000500');
    expect(guardianOption.childrenSummary).toBe('Linked children (up to 3): New Family Child (NEW-FAMILY-CHILD)');
    for (const search of ['NEW-FAMILY-CHILD', 'New Family Child']) {
      const found = await api.get('/api/users/family-guardians').query({ search })
        .set('Authorization', `Bearer ${adminToken}`).expect(200);
      expect(found.body.data.items.map((row: { id: string }) => row.id)).toEqual([String(guardian.id)]);
    }
    const emails = ["new-family-a@example.test", "new-family-b@example.test"];
    const responses = await Promise.all(emails.map(email => api.post("/api/users")
      .set("Authorization", `Bearer ${adminToken}`).send({
        fullName: "New Family", email, password, role: "PARENT", branchId: String(branchId), guardianId: String(guardian.id),
      })));
    expect(responses.map(response => response.status).sort()).toEqual([201, 409]);
    const winner = responses.find(response => response.status === 201)!.body.data;
    expect((await prisma.guardian.findUniqueOrThrow({ where: { id: guardian.id } })).userId).toBe(BigInt(winner.id));
    expect(await prisma.user.count({ where: { orgId, email: { in: emails } } })).toBe(1);
    const after = await api.get('/api/users/family-guardians?page=1&pageSize=10&search=New%20Family')
      .set('Authorization', `Bearer ${adminToken}`).expect(200);
    expect(after.body.data.items.map((row: { id: string }) => row.id)).not.toContain(String(guardian.id));
    await api.post("/api/users").set("Authorization", `Bearer ${adminToken}`).send({
      fullName: "Duplicate Family", email: "new-family-c@example.test", password, role: "PARENT", guardianId: String(guardian.id),
    }).expect(409);
    expect((await prisma.guardian.findUniqueOrThrow({ where: { id: guardian.id } })).userId).toBe(BigInt(winner.id));
  }, 20_000);

  it("guardian picker and creation reject families outside the admin branch", async () => {
    const branch = await prisma.branch.create({ data: { orgId, name: "Restricted branch" } });
    const guardian = await prisma.guardian.create({ data: { orgId, fullName: "Restricted Family", phone: "255700000501" } });
    const child = await prisma.student.create({ data: { orgId, branchId: branch.id, fullName: "Restricted Child", admissionNo: "RESTRICTED-CHILD" } });
    await prisma.studentGuardian.create({ data: { orgId, guardianId: guardian.id, studentId: child.id } });
    const list = await api.get('/api/users/family-guardians?search=Restricted').set('Authorization', `Bearer ${adminToken}`).expect(200);
    const byAdmission = await api.get('/api/users/family-guardians?search=RESTRICTED-CHILD')
      .set('Authorization', `Bearer ${adminToken}`).expect(200);
    expect(byAdmission.body.data.items).toEqual([]);
    expect(list.body.data.items).toEqual([]);
    const body = { fullName: "Restricted Family", email: "restricted-family@example.test", password, role: "PARENT", guardianId: String(guardian.id) };
    await api.post('/api/users').set('Authorization', `Bearer ${adminToken}`).send(body).expect(404);
    await api.post('/api/users').set('Authorization', `Bearer ${adminToken}`).send({ ...body, branchId: String(branch.id) }).expect(403);
    expect(await prisma.user.count({ where: { email: body.email } })).toBe(0);
    await api.get('/api/users/family-guardians?pageSize=1000').set('Authorization', `Bearer ${adminToken}`).expect(422);
  });

  it("concurrent learner creation preserves the student's first account link", async () => {
    const student = await prisma.student.create({ data: { orgId, branchId, fullName: "Independent Student", admissionNo: "CONCURRENT-LEARNER" } });
    const emails = ["learner-a@example.test", "learner-b@example.test"];
    const responses = await Promise.all(emails.map(email => api.post("/api/users")
      .set("Authorization", `Bearer ${adminToken}`).send({
        fullName: "Independent Student", email, password, role: "LEARNER", branchId: String(branchId), studentId: String(student.id),
      })));
    expect(responses.map(response => response.status).sort()).toEqual([201, 409]);
    const winner = responses.find(response => response.status === 201)!.body.data;
    expect((await prisma.student.findUniqueOrThrow({ where: { id: student.id } })).learnerUserId).toBe(BigInt(winner.id));
    expect(await prisma.user.count({ where: { orgId, email: { in: emails } } })).toBe(1);
  }, 20_000);

  it("denies disabled parents at login and revoked admins at issuance", async () => {
    await prisma.user.update({ where: { id: parentId }, data: { status: "DISABLED" } });
    await api.post("/api/auth/login").send({ login: familyNumber, password }).expect(401);
    await prisma.user.update({ where: { id: adminId }, data: { status: "DISABLED" } });
    await issue(otherParentId).expect(403);
    await api.get("/api/users?role=PARENT").set("Authorization", `Bearer ${adminToken}`).expect(403);
  });
});
