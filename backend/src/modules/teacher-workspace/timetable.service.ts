import { Prisma } from "@prisma/client";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import { jsonRecord } from "../../shared/utils/json-record";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { assignedClass } from "./teacher.access";
import type { TimetableInput } from "./teacher.schemas";

export async function getTimetable(actor: AuthenticatedUser, classId: string) {
  await assignedClass(prisma, actor, classId);
  return jsonRecord(await prisma.classTimetableSlot.findMany({
    where: { orgId: BigInt(actor.orgId), classId: BigInt(classId) },
    orderBy: [{ validFrom: "desc" }, { weekday: "asc" }, { startsAt: "asc" }],
    take: 300,
  }));
}

// Two weekly entries only collide when their common date range contains that weekday.
export function sharesTeachingDay(from: Date, until: Date, weekday: number) {
  const offset = (weekday - (from.getUTCDay() || 7) + 7) % 7;
  return from.getTime() + offset * 86400000 <= until.getTime();
}

export async function createTimetable(actor: AuthenticatedUser, classId: string, input: TimetableInput) {
  if (actor.role !== "ADMIN") throw new HttpError(403, "Only the school office can change the timetable");
  return prisma.$transaction(async tx => {
    const orgId = BigInt(actor.orgId);
    // Serialize timetable writes in this school so concurrent requests cannot double-book.
    await tx.$queryRaw`SELECT id FROM organizations WHERE id = ${orgId} FOR UPDATE`;
    const group = await assignedClass(tx, actor, classId);
    const validFrom = new Date(input.validFrom), validUntil = new Date(input.validUntil);
    if (!sharesTeachingDay(validFrom, validUntil, input.weekday))
      throw new HttpError(422, "The chosen teaching period does not contain this weekday");
    const candidates = await tx.classTimetableSlot.findMany({ where: {
      orgId, cancelledAt: null, weekday: input.weekday,
      startsAt: { lt: input.endsAt }, endsAt: { gt: input.startsAt },
      validFrom: { lte: validUntil }, validUntil: { gte: validFrom },
      OR: [{ classId: group.id }, ...(group.teacherId ? [{ schoolClass: { teacherId: group.teacherId } }] : [])],
    } });
    if (candidates.some(slot => sharesTeachingDay(
      new Date(Math.max(validFrom.getTime(), slot.validFrom.getTime())),
      new Date(Math.min(validUntil.getTime(), slot.validUntil.getTime())), input.weekday,
    ))) throw new HttpError(409, "This class or its teacher already has a lesson at that time");
    const saved = await tx.classTimetableSlot.create({ data: {
      ...input, orgId, classId: group.id, createdById: BigInt(actor.userId),
      validFrom, validUntil, room: input.room || null, focus: input.focus || null,
    } });
    await tx.auditLog.create({ data: { orgId, actorUserId: BigInt(actor.userId),
      action: "class.timetable.created", entityType: "ClassTimetableSlot", entityId: String(saved.id),
      metadata: { classId, ...input } } });
    return jsonRecord(saved);
  }, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted });
}

export async function cancelTimetable(actor: AuthenticatedUser, classId: string, id: string, reason: string) {
  if (actor.role !== "ADMIN") throw new HttpError(403, "Only the school office can change the timetable");
  return prisma.$transaction(async tx => {
    const group = await assignedClass(tx, actor, classId);
    const orgId = BigInt(actor.orgId);
    const slot = await tx.classTimetableSlot.findFirst({ where: { orgId, classId: group.id, id: BigInt(id) } });
    if (!slot) throw new HttpError(404, "Timetable entry not found");
    const changed = await tx.classTimetableSlot.updateMany({ where: { id: slot.id, cancelledAt: null },
      data: { cancelledAt: new Date() } });
    if (changed.count) await tx.auditLog.create({ data: { orgId, actorUserId: BigInt(actor.userId),
      action: "class.timetable.cancelled", entityType: "ClassTimetableSlot", entityId: id,
      metadata: { classId, reason } } });
    return { cancelled: true };
  });
}
