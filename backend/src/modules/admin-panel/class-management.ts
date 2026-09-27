import crypto from "node:crypto";
import { Prisma } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { jsonRecord } from "../../shared/utils/json-record";

const change = {
  revision: z.string().regex(/^[a-f0-9]{64}$/),
  reason: z.string().trim().min(3).max(500),
};
export const classEditSchema = z.object({
  ...change,
  name: z.string().trim().min(2).max(100),
  level: z.string().trim().min(2).max(100),
  academicYear: z.string().trim().min(4).max(20),
  teacherId: z.string().regex(/^[1-9]\d*$/).nullable(),
  capacity: z.number().int().positive().max(2147483647).nullable(),
}).strict();
export const classRemoveSchema = z.object(change).strict();

// Include cancelled/history records and SetNull relations: none may be lost.
export const classDependencies = {
  currentStudents: true, enrollments: true, attendance: true, feeStructures: true,
  timetable: true, quranSessions: true, supportNotes: true, assessments: true,
} as const;
const fields = Prisma.validator<Prisma.ClassSelect>()({
  id: true, branchId: true, name: true, level: true, academicYear: true,
  teacherId: true, capacity: true, updatedAt: true,
  teacher: { select: { id: true, fullName: true } },
  _count: { select: classDependencies },
});
type ClassRecord = Prisma.ClassGetPayload<{ select: typeof fields }>;
const revision = (record: ClassRecord) => crypto.createHash("sha256")
  .update(JSON.stringify(jsonRecord(record))).digest("hex");
const hasRecords = (record: ClassRecord) => Object.values(record._count).some(count => count > 0);
const response = (record: ClassRecord) => ({ ...record, revision: revision(record), canRemove: !hasRecords(record) });
const scope = (actor: AuthenticatedUser, id: string): Prisma.ClassWhereInput => {
  if (actor.role !== "ADMIN") throw new HttpError(403, "Administration access required");
  return { id: BigInt(id), orgId: BigInt(actor.orgId),
    ...(actor.branchId ? { branchId: BigInt(actor.branchId) } : {}) };
};

export async function classManagementRecord(actor: AuthenticatedUser, id: string) {
  const record = await prisma.class.findFirst({ where: scope(actor, id), select: fields });
  if (!record) throw new HttpError(404, "Class not found");
  const teacherOptions = await prisma.user.findMany({ where: {
    orgId: BigInt(actor.orgId), role: "TEACHER", status: "ACTIVE",
    OR: [{ branchId: record.branchId }, { branchId: null }],
  }, select: { id: true, fullName: true }, orderBy: [{ fullName: "asc" }, { id: "asc" }] });
  const history = await prisma.auditLog.findMany({
    where: { orgId: BigInt(actor.orgId), entityType: "Class", entityId: id,
      action: { startsWith: "class.admin_" } },
    orderBy: [{ createdAt: "desc" }, { id: "desc" }], take: 20,
    select: { action: true, createdAt: true, metadata: true, actorUser: { select: { fullName: true } } },
  });
  return { ...response(record), teacherOptions, history };
}

export async function manageClass(
  actor: AuthenticatedUser, id: string, action: "edit" | "remove",
  input: z.infer<typeof classEditSchema> | z.infer<typeof classRemoveSchema>,
) {
  const where = scope(actor, id), orgId = BigInt(actor.orgId);
  try {
    return await prisma.$transaction(async tx => {
      // Share the timetable writer's school lock before taking the class lock.
      await tx.$queryRaw`SELECT id FROM organizations WHERE id = ${orgId} FOR UPDATE`;
      await tx.$queryRaw`SELECT id FROM classes WHERE id = ${BigInt(id)} AND org_id = ${orgId} FOR UPDATE`;
      const before = await tx.class.findFirst({ where, select: fields });
      if (!before) throw new HttpError(404, "Class not found");
      if (revision(before) !== input.revision)
        throw new HttpError(409, "This class has changed. Close the form and open it again.");
      if (action === "remove") {
        classRemoveSchema.parse(input);
        if (hasRecords(before))
          throw new HttpError(409, "This class has linked records and cannot be removed. Its history must be kept.");
        await tx.class.delete({ where: { id: before.id } });
        await tx.auditLog.create({ data: { orgId, actorUserId: BigInt(actor.userId),
          action: "class.admin_remove", entityType: "Class", entityId: id,
          metadata: jsonRecord({ reason: input.reason, before, after: null }) as Prisma.InputJsonValue } });
        return { id, removed: true };
      }
      const details = classEditSchema.parse(input);
      if (details.academicYear !== before.academicYear && hasRecords(before))
        throw new HttpError(409, "The academic year cannot change after records are linked. Create a new class for the new year.");
      if (details.capacity !== null && details.capacity < before._count.currentStudents)
        throw new HttpError(409, "Capacity cannot be lower than the number of assigned students.");
      const teacherId = details.teacherId ? BigInt(details.teacherId) : null;
      if (teacherId !== before.teacherId) {
        const today = new Date(new Date(Date.now() + 3 * 3600000).toISOString().slice(0, 10));
        if (await tx.classTimetableSlot.count({ where: { classId: before.id, orgId,
          cancelledAt: null, validUntil: { gte: today } } }))
          throw new HttpError(409, "Cancel this class's current and future timetable entries before changing its teacher, then rebuild the timetable.");
        if (teacherId) {
          await tx.$queryRaw`SELECT id FROM users WHERE id = ${teacherId} AND org_id = ${orgId} FOR UPDATE`;
          const teacher = await tx.user.findFirst({ where: { id: teacherId, orgId,
            role: "TEACHER", status: "ACTIVE", OR: [{ branchId: before.branchId }, { branchId: null }] }, select: { id: true } });
          if (!teacher) throw new HttpError(422, "Choose an active teacher from this class's branch or the school-wide staff.");
        }
      }
      const after = await tx.class.update({ where: { id: before.id }, data: {
        name: details.name, level: details.level, academicYear: details.academicYear,
        capacity: details.capacity, teacherId,
      }, select: fields });
      await tx.auditLog.create({ data: { orgId, actorUserId: BigInt(actor.userId),
        action: "class.admin_edit", entityType: "Class", entityId: id,
        metadata: jsonRecord({ reason: input.reason, before, after }) as Prisma.InputJsonValue } });
      return response(after);
    }, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && ["P2003", "P2034"].includes(error.code))
      throw new HttpError(409, "The class has linked records or another change is in progress. Reopen the record before trying again.");
    throw error;
  }
}
