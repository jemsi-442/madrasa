import crypto from "node:crypto";
import { Prisma } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { jsonRecord } from "../../shared/utils/json-record";

const day = z.string().date();
const change = {
  revision: z.string().regex(/^[a-f0-9]{64}$/),
  reason: z.string().trim().min(3).max(500),
};
export const studentEditSchema = z.object({
  ...change,
  fullName: z.string().trim().min(2).max(150),
  admissionNo: z.string().trim().min(2).max(50),
  gender: z.enum(["male", "female"]).nullable(),
  dob: day.nullable(),
  joinedOn: day.nullable(),
  notes: z.string().trim().max(5000).nullable(),
}).strict().superRefine((value, ctx) => {
  const today = new Date(Date.now() + 3 * 3600000).toISOString().slice(0, 10);
  if (value.dob && (value.dob > today || (value.joinedOn && value.dob > value.joinedOn))) {
    ctx.addIssue({ code: "custom", path: ["dob"], message: "Check the date of birth" });
  }
  if (value.joinedOn && value.joinedOn > today) {
    ctx.addIssue({ code: "custom", path: ["joinedOn"], message: "Joining date cannot be in the future" });
  }
});
export const studentLifecycleSchema = z.object(change).strict();
type RecordInput = z.infer<typeof studentEditSchema> | z.infer<typeof studentLifecycleSchema>;

const fields = Prisma.validator<Prisma.StudentSelect>()({
  id: true, fullName: true, admissionNo: true, gender: true, dob: true,
  joinedOn: true, leftOn: true, notes: true, status: true, classId: true,
  branchId: true, programCategory: true, updatedAt: true,
});
type StudentRecord = Prisma.StudentGetPayload<{ select: typeof fields }>;
const revision = (record: StudentRecord) => crypto.createHash("sha256")
  .update(JSON.stringify(jsonRecord(record))).digest("hex");
const scope = (actor: AuthenticatedUser, id: string): Prisma.StudentWhereInput => {
  if (actor.role !== "ADMIN") throw new HttpError(403, "Administration access required");
  return { id: BigInt(id), orgId: BigInt(actor.orgId),
    ...(actor.branchId ? { branchId: BigInt(actor.branchId) } : {}) };
};

export const studentManagementRecord = async (actor: AuthenticatedUser, id: string) => {
  const record = await prisma.student.findFirst({ where: scope(actor, id), select: fields });
  if (!record) throw new HttpError(404, "Student not found");
  const history = await prisma.auditLog.findMany({
    where: { orgId: BigInt(actor.orgId), entityType: "Student", entityId: id,
      action: { startsWith: "student.admin_" } },
    orderBy: [{ createdAt: "desc" }, { id: "desc" }], take: 20,
    select: { action: true, createdAt: true, metadata: true, actorUser: { select: { fullName: true } } },
  });
  return { ...record, revision: revision(record), history };
};

export const manageStudent = async (
  actor: AuthenticatedUser, id: string, action: "edit" | "archive" | "restore", input: RecordInput,
) => {
  const where = scope(actor, id), orgId = BigInt(actor.orgId);
  try {
    return await prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM students WHERE id = ${BigInt(id)} AND org_id = ${orgId} FOR UPDATE`;
      const before = await tx.student.findFirst({ where, select: fields });
      if (!before) throw new HttpError(404, "Student not found");
      if (revision(before) !== input.revision) {
        throw new HttpError(409, "This student record has changed. Close the form and open it again.");
      }
      let data: Prisma.StudentUncheckedUpdateInput;
      if (action === "edit") {
        const details = studentEditSchema.parse(input);
        data = { fullName: details.fullName, admissionNo: details.admissionNo,
          gender: details.gender, dob: details.dob ? new Date(details.dob) : null,
          joinedOn: details.joinedOn ? new Date(details.joinedOn) : null, notes: details.notes };
      } else {
        if (before.programCategory !== "MADRASA_CHILD") {
          throw new HttpError(409, "Online learner access must be managed with the learner account.");
        }
        if (before.status !== (action === "archive" ? "ACTIVE" : "INACTIVE")) {
          throw new HttpError(409, "This student's status has changed. Open their record again.");
        }
        data = action === "archive"
          ? { status: "INACTIVE", leftOn: new Date(new Date(Date.now() + 3 * 3600000).toISOString().slice(0, 10)) }
          : { status: "ACTIVE", leftOn: null };
      }
      const after = await tx.student.update({ where: { id: before.id }, data, select: fields });
      await tx.auditLog.create({ data: { orgId, actorUserId: BigInt(actor.userId),
        action: `student.admin_${action}`, entityType: "Student", entityId: id,
        metadata: jsonRecord({ reason: input.reason, before, after }) as Prisma.InputJsonValue } });
      return { ...after, revision: revision(after) };
    });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      throw new HttpError(409, "This admission number already belongs to another student.");
    }
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2034") {
      throw new HttpError(409, "Another change is being saved. Open the record again.");
    }
    throw error;
  }
};
