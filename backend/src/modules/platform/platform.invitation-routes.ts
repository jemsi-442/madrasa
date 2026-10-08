import { Router } from "express";
import { Prisma, type PrismaClient } from "@prisma/client";
import { ZodError } from "zod";
import { acceptSchoolAdminInvitation } from "./platform.school-invitation";
import { HttpError } from "../../shared/errors/http-error";
import { asyncHandler } from "../../shared/utils/async-handler";

type InvitationAcceptanceOptions = {
  enabled: boolean;
  consumeLimit: (token: string, ip: string) => Promise<void>;
};

// Deliberately disabled unless a trusted composition root supplies delivery-ready options.
export function createSchoolInvitationRouter(db: PrismaClient, options?: InvitationAcceptanceOptions) {
  const router = Router();
  router.use((_req, res, next) => {
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("Referrer-Policy", "no-referrer");
    next();
  });
  router.post("/accept", asyncHandler(async (req, res) => {
    if (!options?.enabled) throw new HttpError(503, "Invitation acceptance is not available yet");
    try {
      const token = typeof req.body?.token === "string" && /^[A-Za-z0-9_-]{43}$/.test(req.body.token)
        ? req.body.token : "invalid-token";
      // All attempts consume the IP budget, even malformed or already-used tokens.
      await options.consumeLimit(token, req.ip ?? req.socket.remoteAddress ?? "unknown");
      if (Object.keys(req.query).length) throw new HttpError(422, "Submit invitation details in the request body only");
      const data = await acceptSchoolAdminInvitation(db, req.body);
      res.json({ success: true, data });
    } catch (error) {
      if (error instanceof ZodError) throw new HttpError(422, "Check the invitation details and password requirements");
      if (error instanceof HttpError) {
        if (error.statusCode === 429) res.setHeader("Retry-After", "900");
        throw error;
      }
      if (error instanceof Prisma.PrismaClientKnownRequestError && ["P2002", "P2034"].includes(error.code)) {
        throw new HttpError(409, "Invitation state changed. Refresh before trying again");
      }
      // Do not pass database/input errors containing invitation secrets to generic logs.
      throw new HttpError(503, "Acceptance could not be confirmed. Try again later or contact support");
    }
  }));
  return router;
}
