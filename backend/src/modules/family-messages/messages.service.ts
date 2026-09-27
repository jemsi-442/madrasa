import { Prisma } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { conversationInput, inboxQuery, messageInput } from "./messages.schemas";

type DB = Prisma.TransactionClient;
type Pair = {
  student: { id: bigint; fullName: string; admissionNo: string; currentClass: { name: string } | null };
  parent: { id: bigint; fullName: string };
  teacher: { id: bigint; fullName: string };
};
const messageFields = { id: true, senderId: true, body: true, createdAt: true } satisfies Prisma.FamilyMessageSelect;
const pageSize = 20;
const meta = (page: number, total: number) => ({ page, pageSize, totalItems: total, totalPages: Math.ceil(total / pageSize) });

// Rebuild eligible pairs from live school relationships, never from a cached membership list.
async function pairs(db: DB, actor: AuthenticatedUser, studentId?: string): Promise<Pair[]> {
  const orgId = BigInt(actor.orgId), userId = BigInt(actor.userId);
  if (!["PARENT", "TEACHER"].includes(actor.role)) throw new HttpError(403, "Parent or teacher account required");
  const account = await db.user.findFirst({ where: { id: userId, orgId, role: actor.role, status: "ACTIVE",
    organization: { status: { in: ["ACTIVE", "TRIAL"] } } }, select: { branchId: true } });
  if (!account) throw new HttpError(403, "This account is no longer available");
  const linked: Prisma.StudentGuardianWhereInput = { orgId, guardian: { orgId,
    ...(actor.role === "PARENT" ? { userId } : {}), user: { orgId, role: "PARENT", status: "ACTIVE" } } };
  const students = await db.student.findMany({ where: { orgId, status: "ACTIVE",
    ...(studentId ? { id: BigInt(studentId) } : {}), guardians: { some: linked },
    currentClass: { is: { orgId, ...(actor.role === "TEACHER" ? { teacherId: userId,
      ...(account.branchId ? { branchId: account.branchId } : {}) } : {}) } } },
    orderBy: [{ fullName: "asc" }, { id: "asc" }],
    select: { id: true, fullName: true, admissionNo: true,
      currentClass: { select: { name: true, branchId: true,
        teacher: { select: { id: true, orgId: true, fullName: true, role: true, status: true, branchId: true } } } },
      guardians: { where: linked, select: { guardian: { select: { user: { select: { id: true, fullName: true } } } } } },
    } });
  const result: Pair[] = [];
  for (const student of students) {
    const teacher = student.currentClass?.teacher;
    if (!teacher || teacher.orgId !== orgId || teacher.role !== "TEACHER" || teacher.status !== "ACTIVE" ||
      (teacher.branchId !== null && teacher.branchId !== student.currentClass!.branchId)) continue;
    for (const link of student.guardians) {
      const parent = link.guardian.user;
      if (!parent) continue;
      result.push({ student: { id: student.id, fullName: student.fullName, admissionNo: student.admissionNo,
        currentClass: { name: student.currentClass!.name } }, parent,
        teacher: { id: teacher.id, fullName: teacher.fullName } });
    }
  }
  return result;
}

const pairWhere = (pair: Pair) => ({ studentId: pair.student.id, parentId: pair.parent.id, teacherId: pair.teacher.id });
const counterpart = (pair: Pair, actor: AuthenticatedUser) => actor.role === "PARENT" ? pair.teacher : pair.parent;
const samePair = (pair: Pair, thread: { studentId: bigint; parentId: bigint; teacherId: bigint }) =>
  pair.student.id === thread.studentId && pair.parent.id === thread.parentId && pair.teacher.id === thread.teacherId;
const summary = (pair: Pair, actor: AuthenticatedUser) => ({ student: pair.student, contact: counterpart(pair, actor) });

export async function messageContacts(actor: AuthenticatedUser, query: z.infer<typeof inboxQuery>) {
  const search = query.search.toLocaleLowerCase();
  const available = (await pairs(prisma, actor)).filter(pair =>
    `${pair.student.fullName} ${pair.student.admissionNo} ${counterpart(pair, actor).fullName}`.toLocaleLowerCase().includes(search));
  return { items: available.slice((query.page - 1) * pageSize, query.page * pageSize).map(pair => summary(pair, actor)), meta: meta(query.page, available.length) };
}

export async function messageInbox(actor: AuthenticatedUser, query: z.infer<typeof inboxQuery>) {
  const search = query.search.toLocaleLowerCase();
  const available = (await pairs(prisma, actor)).filter(pair =>
    `${pair.student.fullName} ${counterpart(pair, actor).fullName}`.toLocaleLowerCase().includes(search));
  if (!available.length) return { items: [], meta: meta(query.page, 0) };
  const orgId = BigInt(actor.orgId), where = { orgId, OR: available.map(pairWhere) };
  const total = await prisma.familyConversation.count({ where });
  const threads = await prisma.familyConversation.findMany({ where,
    orderBy: [{ updatedAt: "desc" }, { id: "desc" }], skip: (query.page - 1) * pageSize, take: pageSize,
    include: { messages: { orderBy: { id: "desc" }, take: 1, select: messageFields } } });
  const items = [];
  for (const thread of threads) {
    const pair = available.find(pair => samePair(pair, thread))!;
    const readThrough = actor.role === "PARENT" ? thread.parentReadThrough : thread.teacherReadThrough;
    const unread = await prisma.familyMessage.count({ where: { orgId, conversationId: thread.id,
      id: { gt: readThrough }, senderId: { not: BigInt(actor.userId) } } });
    items.push({ id: thread.id, ...summary(pair, actor), updatedAt: thread.updatedAt, unread, latestMessage: thread.messages[0] ?? null });
  }
  return { items, meta: meta(query.page, total) };
}

async function authorisedThread(db: DB, actor: AuthenticatedUser, id: string) {
  const thread = await db.familyConversation.findFirst({ where: { id: BigInt(id), orgId: BigInt(actor.orgId),
    ...(actor.role === "PARENT" ? { parentId: BigInt(actor.userId) } : { teacherId: BigInt(actor.userId) }) } });
  if (!thread) throw new HttpError(404, "Conversation is not available");
  const pair = (await pairs(db, actor, String(thread.studentId))).find(pair => samePair(pair, thread));
  if (!pair) throw new HttpError(404, "Conversation is not available. School assignments or guardian links may have changed.");
  return { thread, pair };
}

export async function conversationHistory(actor: AuthenticatedUser, id: string, before?: string) {
  const { thread, pair } = await authorisedThread(prisma, actor, id);
  const rows = await prisma.familyMessage.findMany({ where: { orgId: BigInt(actor.orgId), conversationId: thread.id,
    ...(before ? { id: { lt: BigInt(before) } } : {}) }, orderBy: { id: "desc" }, take: 31, select: messageFields });
  const hasOlder = rows.length > 30, messages = rows.slice(0, 30).reverse();
  return { id: thread.id, ...summary(pair, actor), messages, hasOlder, nextBefore: messages[0]?.id ?? null,
    readThrough: actor.role === "PARENT" ? thread.parentReadThrough : thread.teacherReadThrough,
    otherReadThrough: actor.role === "PARENT" ? thread.teacherReadThrough : thread.parentReadThrough };
}

// Serialize with school/class writers, then lock all relationship rows before checking access.
async function lockPair(tx: DB, orgId: bigint, studentId: bigint) {
  await tx.$queryRaw`SELECT id FROM organizations WHERE id = ${orgId} FOR UPDATE`;
  await tx.$queryRaw`SELECT id FROM students WHERE id = ${studentId} AND org_id = ${orgId} FOR UPDATE`;
  const student = await tx.student.findFirst({ where: { orgId, id: studentId }, select: { classId: true } });
  if (student?.classId) await tx.$queryRaw`SELECT id FROM classes WHERE id = ${student.classId} AND org_id = ${orgId} FOR UPDATE`;
  await tx.$queryRaw`SELECT u.id FROM users u WHERE u.org_id = ${orgId} AND
    (u.id IN (SELECT g.user_id FROM guardians g JOIN student_guardians sg ON sg.guardian_id = g.id
      WHERE sg.student_id = ${studentId} AND sg.org_id = ${orgId} AND g.org_id = ${orgId})
    OR u.id IN (SELECT c.teacher_id FROM classes c JOIN students s ON s.class_id = c.id
      WHERE s.id = ${studentId} AND s.org_id = ${orgId} AND c.org_id = ${orgId})) ORDER BY u.id FOR UPDATE`;
  await tx.$queryRaw`SELECT g.id FROM guardians g JOIN student_guardians sg ON sg.guardian_id = g.id
    WHERE sg.student_id = ${studentId} AND sg.org_id = ${orgId} AND g.org_id = ${orgId} FOR UPDATE`;
  await tx.$queryRaw`SELECT id FROM student_guardians WHERE student_id = ${studentId} AND org_id = ${orgId} FOR UPDATE`;
}

async function write<T>(operation: (tx: DB) => Promise<T>) {
  try { return await prisma.$transaction(operation, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted }); }
  catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && ["P2002", "P2003", "P2034"].includes(error.code))
      throw new HttpError(409, "Another update is in progress. Retry the same message or reload the conversation.");
    throw error;
  }
}

export async function openConversation(actor: AuthenticatedUser, input: z.infer<typeof conversationInput>) {
  return write(async tx => {
    const orgId = BigInt(actor.orgId);
    await lockPair(tx, orgId, BigInt(input.studentId));
    const pair = (await pairs(tx, actor, input.studentId)).find(pair => String(counterpart(pair, actor).id) === input.contactId);
    if (!pair) throw new HttpError(404, "This contact is not available for your student");
    const thread = await tx.familyConversation.upsert({ where: { orgId_studentId_parentId_teacherId: { orgId, ...pairWhere(pair) } },
      create: { orgId, ...pairWhere(pair) }, update: {} });
    return { id: thread.id, ...summary(pair, actor) };
  });
}

async function lockedThread(tx: DB, actor: AuthenticatedUser, id: string) {
  const row = await tx.familyConversation.findFirst({ where: { orgId: BigInt(actor.orgId), id: BigInt(id),
    ...(actor.role === "PARENT" ? { parentId: BigInt(actor.userId) } : { teacherId: BigInt(actor.userId) }) }, select: { studentId: true } });
  if (!row) throw new HttpError(404, "Conversation is not available");
  await lockPair(tx, BigInt(actor.orgId), row.studentId);
  await tx.$queryRaw`SELECT id FROM family_conversations WHERE id = ${BigInt(id)} AND org_id = ${BigInt(actor.orgId)} FOR UPDATE`;
  return authorisedThread(tx, actor, id);
}

export async function sendFamilyMessage(actor: AuthenticatedUser, id: string, input: z.infer<typeof messageInput>) {
  return write(async tx => {
    const { thread } = await lockedThread(tx, actor, id);
    const orgId = BigInt(actor.orgId), senderId = BigInt(actor.userId);
    const saved = await tx.familyMessage.findUnique({ where: { orgId_senderId_clientId: { orgId, senderId, clientId: input.clientId } } });
    if (saved) {
      if (saved.conversationId !== thread.id || saved.body !== input.body) throw new HttpError(409, "This send was already used for different message details");
      return { message: { id: saved.id, senderId, body: saved.body, createdAt: saved.createdAt } };
    }
    const message = await tx.familyMessage.create({ data: { orgId, conversationId: thread.id, senderId, ...input }, select: messageFields });
    await tx.familyConversation.update({ where: { id: thread.id }, data: { updatedAt: message.createdAt } });
    await tx.auditLog.create({ data: { orgId, actorUserId: senderId, action: "family.message.sent", entityType: "FamilyConversation", entityId: id,
      metadata: { messageId: String(message.id), studentId: String(thread.studentId) } } });
    return { message };
  });
}

export async function markFamilyRead(actor: AuthenticatedUser, id: string, throughId: string) {
  return write(async tx => {
    const { thread } = await lockedThread(tx, actor, id), through = BigInt(throughId);
    const message = await tx.familyMessage.findFirst({ where: { id: through, orgId: BigInt(actor.orgId), conversationId: thread.id }, select: { id: true } });
    if (!message) throw new HttpError(422, "Read marker must refer to a message in this conversation");
    const field = actor.role === "PARENT" ? "parentReadThrough" : "teacherReadThrough";
    const next = through > thread[field] ? through : thread[field];
    await tx.familyConversation.update({ where: { id: thread.id }, data: { [field]: next } });
    return { readThrough: next };
  });
}
