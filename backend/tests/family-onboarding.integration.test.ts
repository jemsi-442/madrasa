import bcrypt from "bcryptjs";
import request from "supertest";
import { beforeAll, afterAll, describe, it, expect, vi } from "vitest";
import { prisma } from "../src/shared/db/prisma";
import { env } from "../src/config/env";
import { createApp } from "../src/app/create-app";

const enabled = process.env.PLATFORM_STAGING_RUN === "isolated";
if (enabled) vi.setConfig({ testTimeout: 30000 });
if (enabled && !/^mysql:\/\/root@127\.0\.0\.1:\d+\/afaq_platform_staging_[a-f0-9]+$/.test(process.env.DATABASE_URL ?? "")) throw new Error("Disposable database required");

describe.skipIf(!enabled)("family self-registration and recovery", () => {
  const api = request(createApp());
  const password = "Family-test-Password42!";
  const newer = "Changed-test-Password43!";
  let orgId: bigint, branchId: bigint, guardianId: bigint, adminToken: string, applicationId: string;
  let userId: string, number: string, parentAccess: string, parentRefresh: string;
  let receipt: string;
  const body = { fullName: "Applicant Parent", email: "applicant@family.test", phone: "255700009001", childReference: "Child Application, APP-001", password, confirmPassword: password };
  const registration = (input = body) => api.post('/api/auth/family-registration').send(input);
  const review = (id: string, data: object) => api.post(`/api/users/family-applications/${id}/review`).set('Authorization', `Bearer ${adminToken}`).send(data);
  beforeAll(async () => {
    const org = await prisma.organization.create({ data: { code: env.PUBLIC_SITE_ORG_CODE, name: "Public family school" } });
    orgId = org.id;
    branchId = (await prisma.branch.create({ data: { orgId, name: "Main", isMain: true } })).id;
    const hash = await bcrypt.hash(password, 4);
    await prisma.user.create({ data: { orgId, branchId, fullName: "Review Admin", email: "review-admin@family.test", passwordHash: hash, role: "ADMIN" } });
    adminToken = (await api.post('/api/auth/login').send({ login: "review-admin@family.test", password }).expect(200)).body.data.accessToken;
    guardianId = (await prisma.guardian.create({ data: { orgId, fullName: "Verified Parent", phone: body.phone } })).id;
    const student = await prisma.student.create({ data: { orgId, branchId, fullName: "Child Application", admissionNo: "APP-001" } });
    await prisma.studentGuardian.create({ data: { orgId, studentId: student.id, guardianId } });
  });
  afterAll(async () => { await prisma.$disconnect(); });

  it('accepts a pending request without granting a session or child access', async () => {
    const response = await registration().expect(202);
    receipt = response.body.data.receipt;
    expect(receipt).toMatch(/^[a-f0-9]{32}$/);
    expect(response.body.data.accessToken).toBeUndefined();
    expect(response.headers['set-cookie']).toBeUndefined();
    expect(await prisma.user.count({ where: { email: body.email } })).toBe(0);
    const application = await prisma.familyApplication.findFirstOrThrow({ where: { email: body.email } });
    applicationId = application.id;
    expect(application.passwordHash).not.toBe(password);
    expect(await bcrypt.compare(password, application.passwordHash!)).toBe(true);
    await api.post('/api/auth/login').send({ login: body.email, password }).expect(401);
    await api.get('/api/users/family-applications').expect(401);
  });

  it('duplicate submissions have the same response and cannot replace the password', async () => {
    const before = await prisma.familyApplication.findUniqueOrThrow({ where: { id: applicationId } });
    const response = await registration({ ...body, password: newer, confirmPassword: newer }).expect(202);
    expect(response.body.data.message).toContain('request has been received');
    expect((await prisma.familyApplication.findUniqueOrThrow({ where: { id: applicationId } })).passwordHash).toBe(before.passwordHash);
    await api.post('/api/auth/family-registration').send({ ...body, role: 'ADMIN' }).expect(422);
    await api.post('/api/auth/family-registration').send({ ...body, orgId: '123' }).expect(422);
  });

  it('lists only scoped requests without passwords and requires explicit verification', async () => {
    const list = await api.get('/api/users/family-applications').set('Authorization', `Bearer ${adminToken}`).expect(200);
    expect(list.body.data.items.map((r: { id: string }) => r.id)).toContain(applicationId);
    expect(JSON.stringify(list.body)).not.toContain('passwordHash');
    await review(applicationId, { decision: 'APPROVE', guardianId: String(guardianId), regionCode: 'DSM' }).expect(422);
    const other = await prisma.branch.create({ data: { orgId, name: "Other application branch" } });
    const hidden = await prisma.familyApplication.create({ data: { orgId, branchId: other.id, fullName: 'Hidden', email: 'hidden@family.test', phone: '255700009002', childReference: 'Private', passwordHash: 'unused', receiptHash: 'unused' } });
    const filtered = await api.get('/api/users/family-applications').set('Authorization', `Bearer ${adminToken}`).expect(200);
    expect(filtered.body.data.items.map((r: { id: string }) => r.id)).not.toContain(hidden.id);
    await review(hidden.id, { decision: 'REJECT', verified: true }).expect(404);
  });

  it('concurrent approval creates one account, links one guardian and issues one number', async () => {
    const input = { decision: 'APPROVE', guardianId: String(guardianId), regionCode: 'ONB', verified: true, receipt };
    await review(applicationId, { ...input, receipt: '0'.repeat(32) }).expect(409);
    const responses = await Promise.all([review(applicationId, input), review(applicationId, input)]);
    expect(responses.map(r => r.status).sort()).toEqual([200, 409]);
    const success = responses.find(r => r.status === 200)!;
    userId = success.body.data.userId; number = success.body.data.familyLoginId;
    expect(number).toMatch(/^ONB\/FAM\/\d{2}\/\d{3}$/);
    expect(await prisma.user.count({ where: { email: body.email } })).toBe(1);
    expect((await prisma.guardian.findUniqueOrThrow({ where: { id: guardianId } })).userId?.toString()).toBe(userId);
    expect((await prisma.familyApplication.findUniqueOrThrow({ where: { id: applicationId } })).passwordHash).toBeNull();
    const login = await api.post('/api/auth/login').send({ login: number, password }).expect(200);
    parentAccess = login.body.data.accessToken; parentRefresh = login.body.data.refreshToken;
    expect(login.body.data.user.role).toBe('PARENT');
    const children = await api.get('/api/parent-portal/students').set('Authorization', `Bearer ${parentAccess}`).expect(200);
    expect(children.body.data).toHaveLength(1);
    await api.get('/api/users/family-applications').set('Authorization', `Bearer ${parentAccess}`).expect(403);
  });

  it('changing password invalidates all previous access and refresh tokens', async () => {
    await api.post('/api/auth/change-password').set('Authorization', `Bearer ${parentAccess}`)
      .send({ currentPassword: 'incorrect', password: newer, confirmPassword: newer }).expect(400);
    await api.post('/api/auth/change-password').set('Authorization', `Bearer ${parentAccess}`)
      .send({ currentPassword: password, password: newer, confirmPassword: newer }).expect(200);
    await api.get('/api/parent-portal/students').set('Authorization', `Bearer ${parentAccess}`).expect(401);
    await api.post('/api/auth/refresh').send({ refreshToken: parentRefresh }).expect(401);
    await api.post('/api/auth/login').send({ login: number, password }).expect(401);
    const login = await api.post('/api/auth/login').send({ login: number, password: newer }).expect(200);
    parentAccess = login.body.data.accessToken;
  });

  it('admin recovery is scoped, verified and cannot reset administrators', async () => {
    const reset = { password, confirmPassword: password, verified: true };
    await api.post(`/api/users/${userId}/reset-family-password`).set('Authorization', `Bearer ${parentAccess}`).send(reset).expect(403);
    await api.post(`/api/users/${userId}/reset-family-password`).set('Authorization', `Bearer ${adminToken}`).send({ password, confirmPassword: password }).expect(422);
    const admin = await prisma.user.findFirstOrThrow({ where: { email: 'review-admin@family.test' } });
    await api.post(`/api/users/${admin.id}/reset-family-password`).set('Authorization', `Bearer ${adminToken}`).send(reset).expect(404);
    await api.post(`/api/users/${userId}/reset-family-password`).set('Authorization', `Bearer ${adminToken}`).send(reset).expect(200);
    await api.get('/api/parent-portal/students').set('Authorization', `Bearer ${parentAccess}`).expect(401);
    await api.post('/api/auth/login').send({ login: number, password }).expect(200);
    expect((await prisma.user.findUniqueOrThrow({ where: { id: BigInt(userId) } })).familyLoginId).toBe(number);
    const audit = await prisma.auditLog.findFirstOrThrow({ where: { action: 'family.password.reset', entityId: userId } });
    expect(JSON.stringify(audit.metadata)).not.toContain(password);
  });

  it('rejection deletes the stored password and creates no account', async () => {
    await registration({ ...body, email: 'reject@family.test', phone: '255700009003' }).expect(202);
    const app = await prisma.familyApplication.findFirstOrThrow({ where: { email: 'reject@family.test' } });
    await review(app.id, { decision: 'REJECT', verified: true }).expect(200);
    expect((await prisma.familyApplication.findUniqueOrThrow({ where: { id: app.id } })).passwordHash).toBeNull();
    expect(await prisma.user.count({ where: { email: app.email } })).toBe(0);
    await review(app.id, { decision: 'REJECT', verified: true }).expect(409);
    await registration({ ...body, email: app.email, phone: app.phone }).expect(202);
    expect((await prisma.familyApplication.findUniqueOrThrow({ where: { id: app.id } })).status).toBe('PENDING');
  });

  it('company password changes revoke company sessions without touching school credentials', async () => {
    const account = await prisma.platformAccount.create({ data: { email: 'password-officer@company.test', fullName: 'Password Officer',
      role: 'IT_SECURITY', status: 'ACTIVE', passwordHash: await bcrypt.hash(password, 4) } });
    const login = await api.post('/api/auth/login').send({ login: account.email, password }).expect(200);
    const token = login.body.data.accessToken;
    await api.post('/api/platform/change-password').set('Authorization', `Bearer ${token}`)
      .send({ currentPassword: password, password: newer, confirmPassword: newer }).expect(200);
    await api.get('/api/platform/me').set('Authorization', `Bearer ${token}`).expect(401);
    await api.post('/api/auth/login').send({ login: account.email, password }).expect(401);
    await api.post('/api/auth/login').send({ login: account.email, password: newer }).expect(200);
    await api.post('/api/auth/login').send({ login: number, password }).expect(200);
  });

  it('school-wide approval supports siblings in different branches without exposing unrelated children', async () => {
    const schoolAdmin = await prisma.user.create({ data: { orgId, fullName: 'School-wide admin', email: 'schoolwide@family.test',
      role: 'ADMIN', passwordHash: await bcrypt.hash(password, 4) } });
    const token = (await api.post('/api/auth/login').send({ login: schoolAdmin.email, password }).expect(200)).body.data.accessToken;
    const guardian = await prisma.guardian.create({ data: { orgId, fullName: 'Multi-branch parent', phone: '255700009010' } });
    const otherBranch = await prisma.branch.create({ data: { orgId, name: 'Sibling branch' } });
    for (const [index, branch] of [branchId, otherBranch.id].entries()) {
      const child = await prisma.student.create({ data: { orgId, branchId: branch, fullName: `Sibling ${index}`, admissionNo: `SIBLING-${index}` } });
      await prisma.studentGuardian.create({ data: { orgId, guardianId: guardian.id, studentId: child.id } });
    }
    const signup = await registration({ ...body, email: 'siblings@family.test', phone: guardian.phone }).expect(202);
    const application = await prisma.familyApplication.findFirstOrThrow({ where: { email: 'siblings@family.test' } });
    const input = { decision: 'APPROVE', verified: true, receipt: signup.body.data.receipt, guardianId: String(guardian.id), regionCode: 'ONB' };
    await review(application.id, input).expect(409);
    const approved = await api.post(`/api/users/family-applications/${application.id}/review`).set('Authorization', `Bearer ${token}`).send(input).expect(200);
    const session = (await api.post('/api/auth/login').send({ login: approved.body.data.familyLoginId, password }).expect(200)).body.data;
    expect(session.user.branchId).toBeNull();
    const children = await api.get('/api/parent-portal/students').set('Authorization', `Bearer ${session.accessToken}`).expect(200);
    expect(children.body.data.map((child: { admissionNo: string }) => child.admissionNo).sort()).toEqual(['SIBLING-0', 'SIBLING-1']);
  });
});
