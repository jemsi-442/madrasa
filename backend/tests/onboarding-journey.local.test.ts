import { randomBytes } from 'node:crypto';
import { PrismaClient } from '@prisma/client';
import { expect, it, vi } from 'vitest';
import express from 'express';
import request from 'supertest';
import bcrypt from 'bcryptjs';

// Production services use the real transaction connection, not mocked model
// results. Nested service transactions join this rollback-only test boundary.
// This tests sequential behavior, not concurrent commit/isolation guarantees.
const state = vi.hoisted(() => ({ client: null as unknown as PrismaClient }));
const mail = vi.hoisted(() => ({ sendMail: vi.fn() }));
vi.mock('nodemailer', () => ({ default: { createTransport: () => mail } }));
vi.mock('../src/shared/db/prisma', () => ({
  prisma: new Proxy({}, { get: (_, key) => Reflect.get(state.client, key) }),
}));

const enabled = process.env.AFAQ_LOCAL_ONBOARDING === 'rollback-only';
it.skipIf(!enabled)('checks school onboarding, admin login and tenant isolation without retaining fixtures', async () => {
  const target = new URL(process.env.DATABASE_URL!);
  expect(['127.0.0.1', 'localhost', '[::1]'].includes(target.hostname)).toBe(true);
  expect(process.env.NODE_ENV).not.toBe('production');
  const { createPlatformRouter } = await import('../src/modules/platform/platform.routes');
  const { createSchoolInvitationRouter } = await import('../src/modules/platform/platform.invitation-routes');
  const { createInvitationDelivery } = await import('../src/modules/platform/platform.invitation-delivery');
  const { verifyPlatformAccess } = await import('../src/modules/platform/platform.authentication');
  const { unifiedLogin } = await import('../src/modules/auth/unified-login');
  const { loginHandler, meHandler } = await import('../src/modules/auth/auth.controller');
  const { authenticate } = await import('../src/shared/middleware/authenticate');
  const { requireTenantContext } = await import('../src/shared/middleware/tenant-context');
  const { getStudentById } = await import('../src/modules/students/students.service');
  const { createStudent } = await import('../src/modules/students/students.service');
  const { organizationsRouter } = await import('../src/modules/organizations/organizations.routes');
  const { studentsRouter } = await import('../src/modules/students/students.routes');
  const { asyncHandler } = await import('../src/shared/utils/async-handler');
  const { errorHandler } = await import('../src/shared/middleware/error-handler');
  const db = new PrismaClient({ log: [] });
  const suffix = randomBytes(8).toString('hex');
  const code = `journey-${suffix}`;
  const email = `admin-${suffix}@example.test`;
  const password = randomBytes(24).toString('base64url');
  const signing = process.env.PLATFORM_JWT_SECRET!;
  const rollback = new Error('Expected onboarding rollback');
  try {
    try {
      await db.$transaction(async tx => {
        const client = new Proxy(tx, {
          get: (object, key) => key === '$transaction'
            ? async (fn: (connection: typeof tx) => Promise<unknown>) => fn(tx)
            : Reflect.get(object, key),
        }) as unknown as PrismaClient;
        state.client = client;
        const app = express();
        app.use(express.json());
        const noExternalLimiter = async () => {};
        mail.sendMail.mockReset().mockResolvedValue({ accepted: [email], rejected: [] });
        // Exercise the real message builder and delivery adapter; only the SMTP
        // transport is captured so this test cannot email an external recipient.
        const delivery = createInvitationDelivery({
          SCHOOL_INVITATIONS_ENABLED: 'true', EMAIL_MODE: 'smtp',
          EMAIL_FROM: 'sender@example.test', EMAIL_SENDER_VERIFIED: 'true',
          EMAIL_LOGIN_URL: 'https://example.test/#/login',
          SMTP_HOST: 'smtp.example.test', SMTP_PORT: '587',
          SMTP_USER: 'synthetic', SMTP_PASSWORD: 'synthetic',
          SCHOOL_INVITATION_URL: 'https://example.test/#/school-invitation',
        }, noExternalLimiter);
        app.use('/api/platform', createPlatformRouter(client, signing, [], {
          encryptionKey: randomBytes(32).toString('hex'), passwordOnly: true, consumeLimit: noExternalLimiter,
        }, undefined, delivery));
        // Acceptance is explicitly enabled only in this in-process test app.
        app.use('/api/school-invitations', createSchoolInvitationRouter(client, { enabled: true, consumeLimit: noExternalLimiter }));
        app.post('/api/auth/login', unifiedLogin(client, signing, noExternalLimiter), asyncHandler(loginHandler));
        app.get('/api/auth/me', authenticate, requireTenantContext, asyncHandler(meHandler));
        app.use('/api/organizations', organizationsRouter);
        app.use('/api/students', studentsRouter);
        app.get('/api/students/:id', authenticate, requireTenantContext, asyncHandler(async (req, res) => {
          await getStudentById(req.authUser!, req.params.id!);
          res.sendStatus(200);
        }));
        app.use(errorHandler);
        const passwordHash = await bcrypt.hash(password, 4);
        const office = async (name: string, role: 'SUPER_ADMIN' | 'IT_SECURITY') => {
          const account = await tx.platformAccount.create({ data: {
            email: `${name}-${suffix}@example.test`, fullName: 'Synthetic Journey Operator', role, status: 'ACTIVE', passwordHash,
          } });
          const response = await request(app).post('/api/auth/login').send({ login: account.email, password });
          expect(response.status).toBe(200);
          const token = response.body.data.accessToken as string;
          return { authorization: `Bearer ${token}`, actor: await verifyPlatformAccess(client, token, signing) };
        };
        const author = await office('author', 'SUPER_ADMIN');
        const reviewer = await office('reviewer', 'SUPER_ADMIN');
        const operator = await office('operator', 'IT_SECURITY');
        const location = { country: 'Tanzania', region: 'Synthetic Region', district: 'Synthetic District', ward: 'Synthetic Ward', village: 'Synthetic Village' };
        const input = { schoolName: 'Synthetic Journey Madrasa', requestedCode: code, adminEmail: email, location, governmentRegistrationNumber: 'SYNTHETIC/123' };
        const create = (body: unknown) => request(app).post('/api/platform/tenant-applications').set('Authorization', author.authorization).send(body as object);
        expect((await create({ ...input, location: { country: 'Tanzania', region: 'Synthetic Region' } })).status).toBe(422);
        const created = await create(input);
        const { requestedCode: _legacyCode, ...automaticInput } = input;
        const automatic = await create(automaticInput);
        expect(automatic.status).toBe(201);
        expect(automatic.body.data.requestedCode).toMatch(/^AFQ-\d{6,}$/);
        expect(automatic.body.data.governmentRegistrationNumber).toBe('SYNTHETIC/123');
        expect(created.status).toBe(201);
        const id = created.body.data.id as string;
        const path = `/api/platform/tenant-applications/${id}`;
        const decision = { decision: 'APPROVED', reason: 'Synthetic ownership evidence for rollback test' };
        expect((await request(app).post(`${path}/review`).set('Authorization', author.authorization).send(decision)).status).toBe(403);
        expect((await request(app).post(`${path}/review`).set('Authorization', reviewer.authorization).send(decision)).status).toBe(200);
        expect((await request(app).post(`${path}/provision`).set('Authorization', reviewer.authorization).send({})).status).toBe(403);
        const provisioned = await request(app).post(`${path}/provision`).set('Authorization', operator.authorization).send({});
        expect(provisioned.status).toBe(201);
        const orgId = BigInt(provisioned.body.data.organizationId);
        const organization = await tx.organization.findUniqueOrThrow({ where: { id: orgId } });
        expect(organization.status).toBe('PENDING_ACTIVATION');
        expect(organization.location).toEqual(location);
        expect(organization.governmentRegistrationNumber).toBe('SYNTHETIC/123');
        console.log('PASS: registration, required address, independent review and inactive provisioning');

        const sendInvitation = (authorization: string) => request(app).post(`${path}/send-invitation`)
          .set('Authorization', authorization).send({});
        expect((await sendInvitation(reviewer.authorization)).status).toBe(403);
        expect(mail.sendMail).not.toHaveBeenCalled();
        const sent = await sendInvitation(operator.authorization);
        expect(sent.status).toBe(200);
        expect(sent.body.data.status).toBe('SMTP_ACCEPTED');
        expect(Object.keys(sent.body.data).sort()).toEqual(['expiresAt', 'status']);
        const capturedCode = () => {
          const draft = mail.sendMail.mock.calls.at(-1)![0];
          expect(draft.to === email).toBe(true);
          expect(draft.text.includes(password)).toBe(false);
          expect(draft.text).toContain('Open: https://example.test/#/school-invitation');
          const code = draft.text.match(/^([A-Za-z0-9_-]{43})$/m)?.[1];
          expect(typeof code === 'string').toBe(true);
          expect(JSON.stringify(sent.body).includes(code)).toBe(false);
          return code as string;
        };
        const firstCode = capturedCode();
        const accept = { token: firstCode, fullName: 'Synthetic First Admin', password };
        await tx.schoolAdminInvitation.update({ where: { applicationId: id }, data: { expiresAt: new Date(0) } });
        expect((await request(app).post('/api/school-invitations/accept').send(accept)).status).toBe(410);
        expect(await tx.user.count({ where: { orgId, role: 'ADMIN' } })).toBe(0);
        expect((await sendInvitation(operator.authorization)).status).toBe(200);
        const secondCode = capturedCode();
        expect(secondCode !== firstCode).toBe(true);
        expect((await request(app).post('/api/school-invitations/accept').send(accept)).status).toBe(410);
        expect((await request(app).post('/api/school-invitations/accept').send({ ...accept, token: 'z'.repeat(43) })).status).toBe(410);
        expect(await tx.user.count({ where: { orgId, role: 'ADMIN' } })).toBe(0);
        accept.token = secondCode;
        const storedInvitation = await tx.schoolAdminInvitation.findUniqueOrThrow({ where: { applicationId: id } });
        const invitation = { invitationId: storedInvitation.id };
        expect((await request(app).post('/api/school-invitations/accept').send(accept)).status).toBe(200);
        expect((await request(app).post('/api/school-invitations/accept').send(accept)).status).toBe(410);
        expect(await tx.user.count({ where: { orgId, role: 'ADMIN' } })).toBe(1);
        expect(mail.sendMail).toHaveBeenCalledTimes(2);
        console.log('PASS: captured SMTP message, expired/rotated/invalid codes denied and one-use acceptance');
        const schoolLogin = () => request(app).post('/api/auth/login').send({ login: email, password });
        expect((await schoolLogin()).status).toBe(401);
        const reviewInput = {
          invitationId: invitation.invitationId, evidenceReference: 'SYNTHETIC ROLLBACK TEST; not production readiness evidence',
          checks: { tenantIsolation: true, accessControls: true, auditTrail: true, backupRecovery: true, supportEscalation: true },
        };
        const review = (authorization: string, body: unknown = reviewInput) => request(app)
          .post(`${path}/technical-review`).set('Authorization', authorization).send(body as object);
        expect((await request(app).post(`${path}/technical-review`).send(reviewInput)).status).toBe(401);
        expect((await review(reviewer.authorization)).status).toBe(403);
        expect((await review(operator.authorization, { ...reviewInput,
          checks: { ...reviewInput.checks, tenantIsolation: false } })).status).toBe(422);
        const reviewed = await review(operator.authorization);
        expect(reviewed.status).toBe(201);
        const receipt = reviewed.body.data;
        const approval = { invitationId: invitation.invitationId, technicalReviewId: receipt.reviewId, approvalReason: 'Synthetic activation for rollback test only' };
        const activate = (authorization: string) => request(app)
          .post(`${path}/activate`).set('Authorization', authorization).send(approval);
        expect((await activate(author.authorization)).status).toBe(403);
        expect((await activate(operator.authorization)).status).toBe(403);
        const withdrawal = { technicalReviewId: receipt.reviewId, reason: 'Synthetic evidence needs a fresh review' };
        const withdraw = (authorization: string) => request(app)
          .post(`${path}/technical-review/withdraw`).set('Authorization', authorization).send(withdrawal);
        expect((await withdraw(reviewer.authorization)).status).toBe(403);
        expect((await withdraw(operator.authorization)).body.data.withdrawn).toBe(true);
        expect((await withdraw(operator.authorization)).body.data.withdrawn).toBe(false);
        expect((await activate(reviewer.authorization)).status).toBe(409);
        // PostgreSQL now() is fixed inside our outer rollback transaction;
        // separate real requests normally commit in separate transactions.
        const firstReview = await tx.platformAuditEvent.findUniqueOrThrow({ where: { id: receipt.reviewId } });
        await tx.platformAuditEvent.update({ where: { id: receipt.reviewId },
          data: { createdAt: new Date(firstReview.createdAt.getTime() - 1000) } });
        const refreshedReview = await review(operator.authorization);
        expect(refreshedReview.status).toBe(201);
        expect((await activate(reviewer.authorization)).status).toBe(409);
        approval.technicalReviewId = refreshedReview.body.data.reviewId;
        const activated = await activate(reviewer.authorization);
        expect(activated.status).toBe(200);
        expect(activated.body.data.activated).toBe(true);
        expect((await activate(reviewer.authorization)).body.data.activated).toBe(false);
        expect((await withdraw(operator.authorization)).status).toBe(409);
        console.log('PASS: HTTP technical review, withdrawal, stale receipt denial and independent activation');

        const login = await schoolLogin();
        expect(login.status).toBe(200);
        expect(login.body.data.user.orgId).toBe(orgId.toString());
        expect(login.body.data.user.role).toBe('ADMIN');
        const authorization = `Bearer ${login.body.data.accessToken}`;
        const me = await request(app).get('/api/auth/me').set('Authorization', authorization);
        expect(me.status).toBe(200);
        expect(me.body.data.orgId).toBe(orgId.toString());
        const suggestionPath = '/api/organizations/location-suggestions?field=country&q=Tan';
        expect((await request(app).get(suggestionPath)).status).toBe(401);
        const suggestions = await request(app).get(suggestionPath).set('Authorization', authorization);
        expect(suggestions.status).toBe(200);
        expect(suggestions.body.data.items).toContain('Tanzania');
        const homeBranch = await tx.branch.create({ data: { orgId, name: 'Synthetic Home Branch' } });
        const branchList = await request(app).get('/api/organizations/branches').set('Authorization', authorization);
        expect(branchList.status).toBe(200);
        const branchInput = { revision: branchList.body.data[0].revision, location };
        const branchPath = `/api/organizations/branches/${homeBranch.id}/location`;
        expect((await request(app).post(branchPath).set('Authorization', authorization).send(branchInput)).status).toBe(200);
        expect((await request(app).post(branchPath).set('Authorization', authorization).send(branchInput)).status).toBe(409);
        expect((await tx.branch.findUniqueOrThrow({ where: { id: homeBranch.id } })).structuredLocation).toEqual(location);
        expect(await tx.auditLog.count({ where: { orgId, action: 'branch.location.updated' } })).toBe(1);
        const siblingBranch = await tx.branch.create({ data: { orgId, name: 'Synthetic Restricted Branch' } });
        const schoolAdmin = await tx.user.findFirstOrThrow({ where: { orgId, email } });
        await tx.user.update({ where: { id: schoolAdmin.id }, data: { branchId: homeBranch.id } });
        const scopedBranches = await request(app).get('/api/organizations/branches').set('Authorization', authorization);
        expect(scopedBranches.body.data.map((row: { id: string }) => row.id)).toEqual([homeBranch.id.toString()]);
        expect((await request(app).post(`/api/organizations/branches/${siblingBranch.id}/location`)
          .set('Authorization', authorization).send(branchInput)).status).toBe(404);
        await tx.user.update({ where: { id: schoolAdmin.id }, data: { branchId: null } });
        const residence = { country: 'Tanzania', ward: 'Synthetic Ward', village: 'Synthetic Village' };
        const admitted = await createStudent(orgId.toString(), {
          admissionNo: 'SYN-RESIDENCE', fullName: 'Synthetic Resident Learner', gender: 'female',
          branchId: homeBranch.id.toString(), guardian: {
            fullName: 'Synthetic Resident Guardian', phone: '255700000000',
            address: 'Legacy address retained', residenceLocation: residence,
          },
        });
        const storedGuardian = await tx.guardian.findUniqueOrThrow({ where: { id: BigInt(admitted.primaryGuardian!.id) } });
        expect(storedGuardian.residenceLocation).toEqual(residence);
        expect(storedGuardian.address).toBe('Legacy address retained');
        expect(admitted.primaryGuardian?.residenceLocation).toEqual(residence);
        const residencePath = `/api/students/${admitted.id}/guardian-residence`;
        expect((await request(app).get(residencePath)).status).toBe(401);
        const residenceRead = await request(app).get(residencePath).set('Authorization', authorization);
        expect(residenceRead.status).toBe(200);
        await tx.user.update({ where: { id: schoolAdmin.id }, data: { role: 'TEACHER' } });
        const teacherLogin = await schoolLogin();
        expect(teacherLogin.status).toBe(200);
        const teacherAuthorization = `Bearer ${teacherLogin.body.data.accessToken}`;
        expect((await request(app).get(residencePath).set('Authorization', teacherAuthorization)).status).toBe(403);
        expect((await request(app).post(residencePath).set('Authorization', teacherAuthorization).send({})).status).toBe(403);
        await tx.user.update({ where: { id: schoolAdmin.id }, data: { role: 'ADMIN' } });
        const updateResidence = { guardianId: residenceRead.body.data.guardianId,
          revision: residenceRead.body.data.revision,
          location: { ...residence, street: 'Synthetic Street' }, reason: 'Synthetic household correction' };
        const saveResidence = (body: unknown) => request(app).post(residencePath)
          .set('Authorization', authorization).send(body as object);
        expect((await saveResidence({ ...updateResidence, reason: 'short' })).status).toBe(422);
        expect((await saveResidence({ ...updateResidence, guardianId: '0' })).status).toBe(409);
        expect((await saveResidence(updateResidence)).status).toBe(200);
        expect((await saveResidence(updateResidence)).status).toBe(409);
        const afterUpdate = await request(app).get(residencePath).set('Authorization', authorization);
        expect(afterUpdate.body.data.location.street).toBe('Synthetic Street');
        expect(afterUpdate.body.data.legacyAddress).toBe('Legacy address retained');
        const linkedSibling = await tx.student.create({ data: { orgId, branchId: siblingBranch.id,
          fullName: 'Synthetic Linked Learner', admissionNo: 'SYN-SIBLING', primaryGuardianId: storedGuardian.id } });
        await tx.user.update({ where: { id: schoolAdmin.id }, data: { branchId: homeBranch.id } });
        expect((await request(app).get(residencePath).set('Authorization', authorization)).status).toBe(403);
        expect((await saveResidence({ ...updateResidence, revision: afterUpdate.body.data.revision })).status).toBe(403);
        expect((await request(app).get(`/api/students/${linkedSibling.id}/guardian-residence`)
          .set('Authorization', authorization)).status).toBe(404);
        await tx.user.update({ where: { id: schoolAdmin.id }, data: { branchId: null } });
        expect((await saveResidence({ ...updateResidence, revision: afterUpdate.body.data.revision, location: null })).status).toBe(200);
        const cleared = await tx.guardian.findUniqueOrThrow({ where: { id: storedGuardian.id } });
        expect(cleared.residenceLocation).toBeNull();
        expect(cleared.address).toBe('Legacy address retained');
        const residenceAudits = await tx.auditLog.findMany({ where: { orgId, action: 'guardian.residence.updated' } });
        expect(residenceAudits).toHaveLength(2);
        expect(residenceAudits.every(row => !JSON.stringify(row.metadata).includes('Synthetic Street'))).toBe(true);
        console.log('PASS: guardian residence editing, stale/link conflict, shared-branch denial and audited clearing');
        const studentResidencePath = `/api/students/${admitted.id}/residence`;
        const readResidence = () => request(app).get(studentResidencePath).set('Authorization', authorization);
        const saveLiving = (body: object) => request(app).post(studentResidencePath).set('Authorization', authorization).send(body);
        expect((await request(app).get(studentResidencePath)).status).toBe(401);
        expect((await request(app).get(studentResidencePath).set('Authorization', teacherAuthorization)).status).toBe(403);
        const initialLiving = await readResidence();
        expect(initialLiving.body.data.residence.mode).toBe('UNKNOWN');
        const living = { revision: initialLiving.body.data.revision, reason: 'Synthetic residence confirmation',
          residence: { mode: 'GUARDIAN', guardianId: storedGuardian.id.toString() } };
        expect((await saveLiving(living)).status).toBe(200);
        expect((await saveLiving(living)).status).toBe(409);
        await tx.guardian.update({ where: { id: storedGuardian.id }, data: { residenceLocation: residence } });
        expect((await readResidence()).body.data.effectiveLocation).toEqual(residence);
        await tx.student.update({ where: { id: BigInt(admitted.id) }, data: { primaryGuardianId: null } });
        const changedLiving = await readResidence();
        expect(changedLiving.body.data.needsReview).toBe(true);
        expect(changedLiving.body.data.effectiveLocation).toBeNull();
        expect((await saveLiving({ ...living, revision: changedLiving.body.data.revision })).status).toBe(409);
        const separate = { ...living, revision: changedLiving.body.data.revision,
          residence: { mode: 'SEPARATE', location: { country: 'Tanzania', ward: 'Synthetic Separate Ward' } } };
        expect((await saveLiving(separate)).status).toBe(200);
        expect((await readResidence()).body.data.effectiveLocation.ward).toBe('Synthetic Separate Ward');
        expect((await tx.guardian.findUniqueOrThrow({ where: { id: storedGuardian.id } })).residenceLocation).toEqual(residence);
        const finalLiving = await readResidence();
        expect((await saveLiving({ ...living, revision: finalLiving.body.data.revision, residence: { mode: 'UNKNOWN' } })).status).toBe(200);
        expect((await readResidence()).body.data.effectiveLocation).toBeNull();
        expect(await tx.auditLog.count({ where: { orgId, action: 'student.residence.updated' } })).toBe(3);
        console.log('PASS: explicit student living arrangement, dynamic guardian address, changed-link guard and separate residence');
        console.log('PASS: structured guardian residence persists through admission without replacing legacy address');
        expect((await request(app).get('/api/platform/madrasas').set('Authorization', authorization)).status).toBe(401);
        const foreign = await tx.organization.create({ data: { name: 'Synthetic Other Madrasa', code: `${code}-other`, status: 'ACTIVE' } });
        const branch = await tx.branch.create({ data: { orgId: foreign.id, name: 'Synthetic Branch' } });
        expect((await request(app).post(`/api/organizations/branches/${branch.id}/location`)
          .set('Authorization', authorization).send(branchInput)).status).toBe(404);
        const student = await tx.student.create({ data: { orgId: foreign.id, branchId: branch.id, admissionNo: 'SYN-01', fullName: 'Synthetic Learner' } });
        expect((await request(app).get(`/api/students/${student.id}/guardian-residence`).set('Authorization', authorization)).status).toBe(404);
        expect((await request(app).get(`/api/students/${student.id}`).set('Authorization', authorization)).status).toBe(404);
        await tx.organization.update({ where: { id: orgId }, data: { status: 'SUSPENDED' } });
        expect((await activate(reviewer.authorization)).status).toBe(409);
        expect((await request(app).get('/api/auth/me').set('Authorization', authorization)).status).toBe(403);
        expect((await schoolLogin()).status).toBe(401);
        console.log('PASS: correct admin tenant, cross-school denial and suspended-school denial');
        throw rollback;
      }, { timeout: 90000, maxWait: 10000 });
      throw new Error('Rollback sentinel was not reached');
    } catch (error) {
      if (error !== rollback) throw error;
    }
    expect(await db.organization.count({ where: { code: { startsWith: code } } })).toBe(0);
    expect(await db.tenantApplication.count({ where: { requestedCode: code } })).toBe(0);
    expect(await db.user.count({ where: { email } })).toBe(0);
    expect(await db.platformAccount.count({ where: { email: { endsWith: `-${suffix}@example.test` } } })).toBe(0);
    console.log('PASS: test records rolled back; no demo reset and no email sent');
  } finally {
    await db.$disconnect();
  }
}, 120000);
