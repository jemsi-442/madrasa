import { Router } from "express";
import { PlatformCurriculumService } from './platform.curriculum';
import { PlatformFundsService } from './platform.funds';
import { InstitutionalReportsService } from './platform.reports';
import { DonorMessagesService } from './platform.donor-messages';
import { jsonRecord } from '../../shared/utils/json-record';
import { tabularReportPdf } from '../../shared/utils/tabular-report-pdf';
import type { PrismaClient } from "@prisma/client";
import { z } from "zod";

import { HttpError } from "../../shared/errors/http-error";
import { asyncHandler } from "../../shared/utils/async-handler";
import { verifyPlatformAccess } from "./platform.authentication";
import { PlatformGovernanceService, type PlatformContext } from "./platform.service";
import { loginPlatform, type PlatformLoginOptions } from "./platform.login";
import { loginPlatformPassword } from "./platform.password-login";
import type { PlatformHealthReader } from "./platform.health";
import { changePlatformPassword } from "./platform.change-password";
import { recordTechnicalReview, withdrawTechnicalReview } from "./platform.technical-review";
import { activateSchool } from "./platform.activation";
import { issueSchoolAdminInvitation } from './platform.school-invitation';
import type { InvitationDelivery } from './platform.invitation-delivery';

const curriculumWriteBody = (body: unknown) => {
  const parsed = z.object({ expectedUpdatedAt: z.string().datetime() }).passthrough().parse(body);
  return { ...(body as Record<string, unknown>), expectedUpdatedAt: parsed.expectedUpdatedAt };
};

declare module "express-serve-static-core" {
  interface Request { platformContext?: PlatformContext }
}

export function createPlatformRouter(db: PrismaClient, secret: string, schoolSecrets: readonly string[], login?: PlatformLoginOptions, health?: PlatformHealthReader, delivery?: InvitationDelivery) {
  const router = Router();
  const service = new PlatformGovernanceService(db);
  const curriculum = new PlatformCurriculumService(db);
  const funds = new PlatformFundsService(db);
  const reports = new InstitutionalReportsService(db);
  const donorMessages = new DonorMessagesService(db);
  router.use(asyncHandler(async (req, res, next) => {
    res.setHeader("Cache-Control", "no-store");
    if (secret.length < 32 || schoolSecrets.includes(secret)) {
      throw new HttpError(503, "Platform access is not enabled");
    }
    next();
  }));
  if (login) router.post("/login", asyncHandler(async (req, res) => {
    if (schoolSecrets.includes(login.encryptionKey)) throw new HttpError(503, "Platform login is not configured");
    try {
      if (login.passwordOnly) {
        const input = z.object({ email: z.string().trim().toLowerCase().email(), password: z.string().min(1).max(72) }).strict().parse(req.body);
        await login.consumeLimit(input.email, req.ip ?? req.socket.remoteAddress ?? "unknown");
        const data = await loginPlatformPassword(db, secret, input);
        res.json({ success: true, data });
        return;
      }
      const data = await loginPlatform(db, secret, login, req.body, req.ip ?? req.socket.remoteAddress ?? "unknown");
      res.json({ success: true, data });
    } catch (error) {
      if (error instanceof HttpError && error.statusCode === 429) res.setHeader("Retry-After", "900");
      throw error;
    }
  }));
  router.use(asyncHandler(async (req, _res, next) => {
    const match = /^Bearer ([^\s]+)$/.exec(req.headers.authorization ?? "");
    if (!match?.[1]) throw new HttpError(401, "Platform Bearer token required");
    req.platformContext = await verifyPlatformAccess(db, match[1], secret);
    next();
  }));

  router.get("/me", asyncHandler(async (req, res) => {
    const account = await db.platformAccount.findUniqueOrThrow({
      where: { id: req.platformContext!.accountId },
      select: { id: true, fullName: true, role: true },
    });
    res.json({ success: true, data: account });
  }));
  router.get('/curriculum', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await curriculum.list(req.platformContext!, req.query) });
  }));
  router.get('/funds', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await funds.overview(req.platformContext!, req.query) });
  }));
  router.get('/institution-reports/options', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await reports.options(req.platformContext!) });
  }));
  router.post('/institution-reports/preview', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await reports.preview(req.platformContext!, req.body) });
  }));
  router.post('/institution-reports', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await reports.generate(req.platformContext!, req.body) });
  }));
  router.get('/institution-reports', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await reports.list(req.platformContext!, req.query) });
  }));
  router.get('/institution-reports/:id/pdf', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await reports.pdf(req.platformContext!, req.params.id!) });
  }));
  router.get('/funds/pdf', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await funds.pdf(req.platformContext!, req.query) });
  }));
  router.get('/funds/messages', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await funds.messages(req.platformContext!) });
  }));
  router.get('/funds/messaging/recipients', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await donorMessages.recipients(req.platformContext!, req.query) });
  }));
  router.post('/funds/messaging/recipients/:id/consent', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await donorMessages.consent(req.platformContext!, req.params.id, req.body) });
  }));
  router.get('/funds/messaging', asyncHandler(async (req, res) => {
    res.json({ success: true, data: jsonRecord(await donorMessages.list(req.platformContext!, req.query)) });
  }));
  router.post('/funds/messaging/drafts', asyncHandler(async (req, res) => {
    res.json({ success: true, data: jsonRecord(await donorMessages.save(req.platformContext!, req.body)) });
  }));
  router.post('/funds/messaging/:id/send', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await donorMessages.send(req.platformContext!, req.params.id, req.body) });
  }));
  router.get('/curriculum/oversight', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await curriculum.oversight(req.platformContext!, req.query) });
  }));
  router.get('/curriculum/oversight/madrasas', asyncHandler(async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.json({ success: true, data: await curriculum.madrasaOversight(req.platformContext!, req.query) });
  }));
  router.post('/curriculum', asyncHandler(async (req, res) => {
    res.status(201).json({ success: true, data: await curriculum.save(req.platformContext!, req.body) });
  }));
  router.post('/curriculum/:id/edit', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await curriculum.edit(
      req.platformContext!, req.params.id, curriculumWriteBody(req.body),
    ) });
  }));
  router.post('/curriculum/:id/transition', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await curriculum.transition(
      req.platformContext!, req.params.id, curriculumWriteBody(req.body),
    ) });
  }));
  router.post('/curriculum/:id/assign', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await curriculum.assign(req.platformContext!, req.params.id, req.body) });
  }));
  router.get('/curriculum/:id/assignment-preview', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await curriculum.assignmentPreview(
      req.platformContext!, req.params.id, req.query.organizationId,
    ) });
  }));
  router.post('/curriculum/:id/clone', asyncHandler(async (req, res) => {
    res.status(201).json({ success: true, data: await curriculum.clone(req.platformContext!, req.params.id, req.body) });
  }));
  router.post('/curriculum/:id/topics', asyncHandler(async (req, res) => {
    res.status(201).json({ success: true, data: await curriculum.addTopic(
      req.platformContext!, req.params.id, curriculumWriteBody(req.body),
    ) });
  }));
  router.post('/curriculum/:id/lessons', asyncHandler(async (req, res) => {
    res.status(201).json({ success: true, data: await curriculum.saveLesson(
      req.platformContext!, req.params.id, curriculumWriteBody(req.body),
    ) });
  }));
  router.post('/curriculum/:id/lessons/:lessonId', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await curriculum.saveLesson(
      req.platformContext!, req.params.id, curriculumWriteBody(req.body), req.params.lessonId,
    ) });
  }));
  router.post('/curriculum/:id/lessons/:lessonId/delete', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await curriculum.deleteLesson(
      req.platformContext!, req.params.id, req.params.lessonId,
      curriculumWriteBody(req.body).expectedUpdatedAt,
    ) });
  }));
  router.post('/curriculum/:id/topics/:topicId', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await curriculum.addTopic(
      req.platformContext!, req.params.id, curriculumWriteBody(req.body), req.params.topicId,
    ) });
  }));
  router.post('/curriculum/:id/topics/:topicId/delete', asyncHandler(async (req, res) => {
    res.json({ success: true, data: await curriculum.deleteTopic(
      req.platformContext!, req.params.id, req.params.topicId,
      curriculumWriteBody(req.body).expectedUpdatedAt,
    ) });
  }));
  router.post("/change-password", asyncHandler(async (req, res) => {
    if (!login) throw new HttpError(503, "Password changes are not configured");
    await login.consumeLimit(req.platformContext!.accountId, req.ip ?? req.socket.remoteAddress ?? "unknown");
    await changePlatformPassword(db, req.platformContext!, req.body);
    res.json({ success: true, data: { message: "Password changed. Sign in again on all devices." } });
  }));
  router.get("/health", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.health(req.platformContext!, health) });
  }));
  router.get("/overview", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.overview(req.platformContext!) });
  }));
  router.get("/madrasas", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.madrasaDirectory(req.platformContext!, req.query) });
  }));
  router.get('/madrasas/pdf', asyncHandler(async (req, res) => {
    const data = await service.madrasaDirectory(req.platformContext!, { ...req.query, export: 'true' });
    const rows = data.items.map(row => {
      const location = row.location && typeof row.location === 'object' && !Array.isArray(row.location) ? row.location : {};
      return [row.name, row.code, Object.entries(location).filter(([, value]) => value).map(([key, value]) => `${key}: ${value}`).join('\n'),
        row.locations.join('; '), row.admins.join('; '), String(row.students ?? '-'), String(row.teachers ?? '-'), row.status];
    });
    const pdf = await tabularReportPdf('Madrasa directory', `${data.total} records | Current directory filters | ${new Date().toISOString().slice(0, 10)}`,
      ['Madrasa', 'Afaq code', 'Location', 'Branches', 'Assigned admins', 'Learners', 'Teachers', 'Status'], rows);
    res.setHeader('Cache-Control', 'no-store');
    res.json({ success: true, data: { fileName: 'afaq-madrasas.pdf', base64: pdf.toString('base64') } });
  }));
  router.get("/staff-directory", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.staffDirectory(req.platformContext!, req.query) });
  }));
  router.get("/tenant-applications", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.listApplications(req.platformContext!, req.query) });
  }));
  router.get('/location-suggestions', asyncHandler(async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.json({ success: true, data: await service.suggestLocations(req.platformContext!, req.query) });
  }));
  router.get("/provisioning-queue", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.listProvisioningQueue(req.platformContext!, req.query) });
  }));
  router.post("/tenant-applications", asyncHandler(async (req, res) => {
    res.status(201).json({ success: true, data: await service.createApplication(req.platformContext!, req.body) });
  }));
  router.post("/tenant-applications/:id/review", asyncHandler(async (req, res) => {
    const id = z.string().min(1).max(30).parse(req.params.id);
    res.json({ success: true, data: await service.reviewApplication(req.platformContext!, id, req.body) });
  }));
  router.get("/tenant-applications/:id/provisioning-preflight", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.provisioningPreflight(req.platformContext!, req.params.id) });
  }));
  router.get("/tenant-applications/:id/onboarding-progress", asyncHandler(async (req, res) => {
    const data = await service.onboardingProgress(req.platformContext!, req.params.id);
    const account = await db.platformAccount.findUnique({ where: { id: req.platformContext!.accountId }, select: { role: true, status: true } });
    res.json({ success: true, data: { ...data, deliveryConfigured: Boolean(delivery),
      canSendInvitation: Boolean(delivery) && account?.role === 'IT_SECURITY' && account.status === 'ACTIVE'
        && ['INVITATION_PENDING', 'INVITATION_EXPIRED', 'ACCEPTANCE_PENDING'].includes(data.stage),
    } });
  }));
  router.post('/tenant-applications/:id/send-invitation', asyncHandler(async (req, res) => {
    z.object({}).strict().parse(req.body);
    if (!delivery) throw new HttpError(503, 'Invitation email is not configured');
    const id = z.string().min(1).max(30).parse(req.params.id);
    await delivery.consumeLimit(`send:${id}`, req.ip ?? req.socket.remoteAddress ?? 'unknown');
    try {
      const invitation = await issueSchoolAdminInvitation(db, req.platformContext!, id);
      const status = await delivery.send(invitation);
      await db.platformAuditEvent.create({ data: {
        actorId: req.platformContext!.accountId, actorRole: 'IT_SECURITY',
        entityType: 'TenantApplication', entityId: id, action: 'tenant.admin.invitation.delivery',
        metadata: { status, invitationId: invitation.invitationId },
      } });
      res.json({ success: true, data: { status, expiresAt: invitation.expiresAt } });
    } catch (error) {
      if (error instanceof HttpError) throw error;
      // Provider/DB errors can contain the secret message: never pass them to logs.
      throw new HttpError(503, 'Invitation delivery could not be confirmed. Check before resending');
    }
  }));
  router.post("/tenant-applications/:id/provision", asyncHandler(async (req, res) => {
    z.object({}).strict().parse(req.body);
    const data = await service.provisionPendingSchool(req.platformContext!, req.params.id);
    res.status(data.created ? 201 : 200).json({ success: true, data });
  }));
  router.post("/tenant-applications/:id/technical-review", asyncHandler(async (req, res) => {
    res.status(201).json({ success: true, data: await recordTechnicalReview(
      db, req.platformContext!, req.params.id, req.body,
    ) });
  }));
  router.post("/tenant-applications/:id/technical-review/withdraw", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await withdrawTechnicalReview(
      db, req.platformContext!, req.params.id, req.body,
    ) });
  }));
  router.post("/tenant-applications/:id/activate", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await activateSchool(
      db, req.platformContext!, req.params.id, req.body,
    ) });
  }));
  router.get("/audit-events", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.listAuditEvents(req.platformContext!, req.query) });
  }));
  router.get("/sessions", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.listOwnSessions(req.platformContext!, req.query) });
  }));
  router.get("/accounts", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.listAccounts(req.platformContext!, req.query) });
  }));
  router.post("/accounts/:id/disable", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.disableItAccount(req.platformContext!, req.params.id, req.body) });
  }));
  router.post("/accounts/:id/restore", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.restoreItAccount(req.platformContext!, req.params.id, req.body) });
  }));
  router.get("/accounts/:id/access-history", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.accountAccessHistory(req.platformContext!, req.params.id, req.query) });
  }));
  router.post("/sessions/:id/revoke", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.revokeOwnSession(req.platformContext!, req.params.id) });
  }));
  router.post("/logout", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.logout(req.platformContext!) });
  }));
  router.post("/logout-all", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.logout(req.platformContext!, true) });
  }));
  return router;
}
