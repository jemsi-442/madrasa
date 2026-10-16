import bcrypt from "bcryptjs";
import { randomBytes, createHash, timingSafeEqual } from "node:crypto";
import { Prisma } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../../shared/db/prisma";
import { env } from "../../config/env";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { newSchoolPassword } from "../auth/password.schemas";
import { availableFamilyGuardian } from "./family-guardians";
import { familyRegistrationSchema, familyUserIdSchema } from "./family-registration";

export const familyApplicationSchema = z.object({
  fullName: z.string().trim().min(2).max(150),
  email: z.string().trim().toLowerCase().email().max(150),
  phone: z.string().trim().min(8).max(30),
  childReference: z.string().trim().min(2).max(500),
  password: newSchoolPassword,
  confirmPassword: newSchoolPassword,
}).strict().refine(v => v.password === v.confirmPassword, { path: ["confirmPassword"], message: "Passwords do not match" });

export async function submitFamilyApplication(raw: unknown) {
  const input = familyApplicationSchema.parse(raw);
  const org = await prisma.organization.findFirst({ where: { code: env.PUBLIC_SITE_ORG_CODE, status: "ACTIVE" },
    select: { id: true, branches: { orderBy: [{ isMain: "desc" }, { id: "asc" }], take: 1, select: { id: true } } } });
  if (!org?.branches[0]) throw new HttpError(503, "Registration is temporarily unavailable");
  // Always hash, including duplicate submissions; never expose account existence publicly.
  const passwordHash = await bcrypt.hash(input.password, 12);
  const receipt = randomBytes(16).toString("hex");
  const existing = await prisma.user.findFirst({ where: { OR: [{ email: input.email }, { phone: input.phone }] }, select: { id: true } });
  const company = await prisma.platformAccount.findUnique({ where: { email: input.email }, select: { id: true } });
  if (!existing && !company) {
    try {
      await prisma.familyApplication.create({ data: {
        orgId: org.id, branchId: org.branches[0].id, fullName: input.fullName,
        email: input.email, phone: input.phone, childReference: input.childReference, passwordHash,
        receiptHash: createHash("sha256").update(receipt).digest("hex"),
      } });
    } catch (error) {
      if (!(error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002")) throw error;
      // Only an office-closed request may be resubmitted; pending/approved requests
      // cannot have their password or receipt replaced by an anonymous caller.
      await prisma.familyApplication.updateMany({ where: { orgId: org.id, email: input.email, status: "REJECTED" }, data: {
        fullName: input.fullName, phone: input.phone, childReference: input.childReference, passwordHash,
        receiptHash: createHash("sha256").update(receipt).digest("hex"), status: "PENDING", userId: null,
        reviewedBy: null, reviewedAt: null, createdAt: new Date(),
      } });
    }
  }
  return { receipt, message: "Your request has been received. Contact your school office for verification and sign-in details. No email has been sent." };
}

const applicationScope = (actor: AuthenticatedUser) => ({ orgId: BigInt(actor.orgId),
  ...(actor.branchId ? { branchId: BigInt(actor.branchId) } : {}) });

export async function listFamilyApplications(actor: AuthenticatedUser, raw: unknown) {
  const query = z.object({ page: z.coerce.number().int().min(1).max(100000).default(1),
    status: z.enum(["PENDING", "APPROVED", "REJECTED"]).default("PENDING") }).strict().parse(raw);
  const where = { ...applicationScope(actor), status: query.status };
  const rows = await prisma.familyApplication.findMany({ where, take: 20, skip: (query.page - 1) * 20,
    orderBy: [{ createdAt: "asc" }, { id: "asc" }],
    select: { id: true, fullName: true, email: true, phone: true, childReference: true, status: true, createdAt: true, userId: true } });
  return { items: rows.map(r => ({ ...r, userId: r.userId?.toString() ?? null })),
    meta: { page: query.page, pageSize: 20, totalItems: await prisma.familyApplication.count({ where }) } };
}

export const reviewFamilySchema = z.discriminatedUnion("decision", [
  z.object({ decision: z.literal("APPROVE"), guardianId: familyUserIdSchema,
    receipt: z.string().trim().toLowerCase().regex(/^[a-f0-9]{32}$/),
    regionCode: familyRegistrationSchema.shape.regionCode, verified: z.literal(true) }).strict(),
  z.object({ decision: z.literal("REJECT"), verified: z.literal(true) }).strict(),
]);

export async function reviewFamilyApplication(actor: AuthenticatedUser, id: string, raw: unknown) {
  const input = reviewFamilySchema.parse(raw);
  const applicationId = z.string().uuid().parse(id);
  try {
    return await prisma.$transaction(async tx => {
      const admin = await tx.user.findFirst({ where: { id: BigInt(actor.userId), orgId: BigInt(actor.orgId), role: "ADMIN", status: "ACTIVE",
        organization: { status: { in: ["ACTIVE", "TRIAL"] } } }, select: { id: true, branchId: true } });
      if (!admin) throw new HttpError(403, "Access denied");
      const scope = applicationScope({ ...actor, branchId: admin.branchId?.toString() ?? null });
      const application = await tx.familyApplication.findFirst({ where: { id: applicationId, ...scope } });
      if (!application) throw new HttpError(404, "Application not found");
      if (application.status !== "PENDING") throw new HttpError(409, "This application has already been reviewed. Refresh the list.");
      let userId: bigint | null = null;
      let familyLoginId: string | null = null;
      if (input.decision === "APPROVE") {
        const receiptHash = createHash("sha256").update(input.receipt).digest();
        const storedReceipt = Buffer.from(application.receiptHash, "hex");
        if (storedReceipt.length !== receiptHash.length || !timingSafeEqual(storedReceipt, receiptHash)) {
          throw new HttpError(409, "Request receipt does not match. Verify the applicant's original request; do not approve by name alone.");
        }
        if (!application.passwordHash) throw new HttpError(409, "Application is not available for approval");
        const guardian = await tx.guardian.findFirst({ where: { id: BigInt(input.guardianId),
          ...availableFamilyGuardian(application.orgId, admin.branchId) } });
        if (!guardian) throw new HttpError(409, "Guardian is not available in your school or branch");
        if (await tx.user.findFirst({ where: { OR: [{ email: application.email }, { phone: application.phone }] }, select: { id: true } })
          || await tx.platformAccount.findUnique({ where: { email: application.email }, select: { id: true } })) {
          throw new HttpError(409, "An account already uses these contact details. Resolve the existing account instead.");
        }
        const year = Number(new Intl.DateTimeFormat("en", { year: "numeric", timeZone: "Africa/Dar_es_Salaam" }).format(new Date()));
        if (year > 2099) throw new HttpError(409, "Registration year is unsupported");
        const counter = await tx.familyRegistrationCounter.upsert({ where: { regionCode_year: { regionCode: input.regionCode, year } },
          create: { regionCode: input.regionCode, year, sequence: 1 }, update: { sequence: { increment: 1 } } });
        familyLoginId = `${input.regionCode}/FAM/${String(year).slice(-2)}/${String(counter.sequence).padStart(3, "0")}`;
        const user = await tx.user.create({ data: { orgId: application.orgId, branchId: admin.branchId,
          fullName: application.fullName, email: application.email, phone: application.phone, passwordHash: application.passwordHash,
          role: "PARENT", familyLoginId } });
        userId = user.id;
        const linked = await tx.guardian.updateMany({ where: { id: guardian.id, ...availableFamilyGuardian(application.orgId, admin.branchId) }, data: { userId } });
        if (linked.count !== 1) throw new HttpError(409, "Guardian changed. Refresh and verify again.");
      }
      const updated = await tx.familyApplication.updateMany({ where: { id: applicationId, status: "PENDING" }, data: {
        status: input.decision === "APPROVE" ? "APPROVED" : "REJECTED", passwordHash: null, userId,
        reviewedBy: admin.id, reviewedAt: new Date(),
      } });
      if (updated.count !== 1) throw new HttpError(409, "Application changed. Refresh the list.");
      await tx.auditLog.create({ data: { orgId: application.orgId, actorUserId: admin.id,
        action: input.decision === "APPROVE" ? "family.application.approved" : "family.application.rejected",
        entityType: "FamilyApplication", entityId: applicationId, metadata: { userId: userId?.toString() ?? null, familyLoginId } } });
      return { userId: userId?.toString() ?? null, familyLoginId, delivery: "MANUAL" };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  } catch (error) {
    if ((error instanceof Prisma.PrismaClientKnownRequestError && ["P2002", "P2034"].includes(error.code)) ||
      (error instanceof Prisma.PrismaClientUnknownRequestError && /MysqlError \{ code: 1020,/.test(error.message))) {
      throw new HttpError(409, "Application changed during review. Refresh and try again.");
    }
    throw error;
  }
}
