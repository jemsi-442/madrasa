import { Prisma, type PrismaClient } from "@prisma/client";
import { z } from "zod";
import { HttpError } from "../../shared/errors/http-error";

export const familyRegistrationSchema = z.object({
  regionCode: z.string().trim().toUpperCase().regex(/^[A-Z]{2,8}$/),
}).strict();
export const familyUserIdSchema = z.string().regex(/^[1-9]\d*$/);

// A family identity belongs to the parent account, never to a child's course.
export async function issueFamilyRegistration(db: PrismaClient,
  actor: { userId: string; orgId: string }, userId: string, regionCode: string,
  now = new Date()) {
  const region = familyRegistrationSchema.parse({ regionCode }).regionCode;
  const targetId = BigInt(familyUserIdSchema.parse(userId));
  const year = Number(new Intl.DateTimeFormat("en", { year: "numeric", timeZone: "Africa/Dar_es_Salaam" }).format(now));
  if (year < 2000 || year > 2099) throw new HttpError(409, "Registration year is unsupported");
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      return await db.$transaction(async (tx) => {
        const admin = await tx.user.findFirst({
          where: { id: BigInt(actor.userId), orgId: BigInt(actor.orgId), role: "ADMIN", status: "ACTIVE",
            organization: { status: { in: ["ACTIVE", "TRIAL"] } } },
          select: { id: true, branchId: true },
        });
        if (!admin) throw new HttpError(403, "Access denied");
        const parent = await tx.user.findFirst({
          where: { id: targetId, orgId: BigInt(actor.orgId), role: "PARENT", status: "ACTIVE",
            ...(admin.branchId ? { branchId: admin.branchId } : {}),
            guardianProfile: { is: { orgId: BigInt(actor.orgId) } } },
          select: { id: true, familyLoginId: true },
        });
        if (!parent) throw new HttpError(404, "Parent account not found");
        if (parent.familyLoginId) return { userId, familyLoginId: parent.familyLoginId };
        const counter = await tx.familyRegistrationCounter.upsert({
          where: { regionCode_year: { regionCode: region, year } },
          create: { regionCode: region, year, sequence: 1 }, update: { sequence: { increment: 1 } },
        });
        const familyLoginId = `${region}/FAM/${String(year).slice(-2)}/${String(counter.sequence).padStart(3, "0")}`;
        await tx.user.update({ where: { id: parent.id }, data: { familyLoginId } });
        await tx.auditLog.create({ data: {
          orgId: BigInt(actor.orgId), actorUserId: admin.id,
          action: "family.registration.issued", entityType: "User", entityId: userId,
          metadata: { familyLoginId },
        } });
        return { userId, familyLoginId };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      // MariaDB can surface a serialization conflict as error 1020 rather than P2034.
      const mariaDbChangedRecord = error instanceof Prisma.PrismaClientUnknownRequestError
        && /MysqlError \{ code: 1020,/.test(error.message);
      if (mariaDbChangedRecord || (error instanceof Prisma.PrismaClientKnownRequestError && ["P2002", "P2034"].includes(error.code))) {
        if (attempt < 2) continue;
        throw new HttpError(409, "Registration is busy. Please try again");
      }
      throw error;
    }
  }
  throw new HttpError(409, "Registration is busy. Please try again");
}
