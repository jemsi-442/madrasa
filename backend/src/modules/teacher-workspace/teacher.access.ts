import { Prisma } from "@prisma/client";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";

export const classScope = (actor: AuthenticatedUser): Prisma.ClassWhereInput => ({
  orgId: BigInt(actor.orgId),
  ...(actor.branchId ? { branchId: BigInt(actor.branchId) } : {}),
  ...(actor.role === "TEACHER" ? { teacherId: BigInt(actor.userId) } : {}),
});
export const studentScope = (actor: AuthenticatedUser): Prisma.StudentWhereInput => ({
  orgId: BigInt(actor.orgId), status: "ACTIVE",
  currentClass: { is: classScope(actor) },
});

export async function assignedClass(tx: Prisma.TransactionClient, actor: AuthenticatedUser, id: string) {
  if (!["TEACHER", "ADMIN"].includes(actor.role)) throw new HttpError(403, "Not permitted");
  const item = await tx.class.findFirst({ where: { ...classScope(actor), id: BigInt(id) } });
  if (!item) throw new HttpError(404, "Class not found");
  return item;
}

export async function assignedStudent(
  tx: Prisma.TransactionClient, actor: AuthenticatedUser, id: string, lock = false,
) {
  if (actor.role !== "TEACHER") throw new HttpError(403, "Not permitted");
  if (lock) await tx.$queryRaw`SELECT id FROM students WHERE org_id = ${BigInt(actor.orgId)}
    AND id = ${BigInt(id)} FOR UPDATE`;
  const student = await tx.student.findFirst({
    where: { ...studentScope(actor), id: BigInt(id) },
    select: { id: true, classId: true, fullName: true, admissionNo: true, joinedOn: true,
      currentClass: { select: { id: true, name: true, branch: { select: { name: true } } } } },
  });
  if (!student) throw new HttpError(404, "Student not found in your assigned classes");
  if (lock) {
    await tx.$queryRaw`SELECT id FROM classes WHERE org_id = ${BigInt(actor.orgId)}
      AND id = ${student.classId} FOR UPDATE`;
    await assignedClass(tx, actor, String(student.classId));
  }
  return student;
}
