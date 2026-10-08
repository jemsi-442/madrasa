import { Router } from "express";
import type { PrismaClient } from "@prisma/client";
import { z } from "zod";

import { HttpError } from "../../shared/errors/http-error";
import { asyncHandler } from "../../shared/utils/async-handler";
import { verifyPlatformAccess } from "./platform.authentication";
import { PlatformGovernanceService, type PlatformContext } from "./platform.service";
import { loginPlatform, type PlatformLoginOptions } from "./platform.login";
import type { PlatformHealthReader } from "./platform.health";

declare module "express-serve-static-core" {
  interface Request { platformContext?: PlatformContext }
}

export function createPlatformRouter(db: PrismaClient, secret: string, schoolSecrets: readonly string[], login?: PlatformLoginOptions, health?: PlatformHealthReader) {
  const router = Router();
  const service = new PlatformGovernanceService(db);
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
  router.get("/health", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.health(req.platformContext!, health) });
  }));
  router.get("/overview", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.overview(req.platformContext!) });
  }));
  router.get("/tenant-applications", asyncHandler(async (req, res) => {
    res.json({ success: true, data: await service.listApplications(req.platformContext!, req.query) });
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
    res.json({ success: true, data: await service.onboardingProgress(req.platformContext!, req.params.id) });
  }));
  router.post("/tenant-applications/:id/provision", asyncHandler(async (req, res) => {
    z.object({}).strict().parse(req.body);
    const data = await service.provisionPendingSchool(req.platformContext!, req.params.id);
    res.status(data.created ? 201 : 200).json({ success: true, data });
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
