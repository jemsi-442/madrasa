import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { beforeAll, afterAll, describe, expect, it } from "vitest";
import { prisma } from "../src/shared/db/prisma";
import { env } from "../src/config/env";
import { api } from "./helpers/api-client";

describe("private family messaging", () => {
  let orgId: bigint, foreignOrg: bigint, branchId: bigint, otherBranch: bigint;
  let parent: bigint, parent2: bigint, teacher: bigint, teacher2: bigint, foreignParent: bigint;
  let guardian: bigint, student: bigint, otherStudent: bigint, classId: bigint;
  let thread: string, secondThread: string;
  const token = (id: bigint, role = id === teacher || id === teacher2 ? "TEACHER" : "PARENT", org = orgId) =>
    jwt.sign({ sub: String(id), orgId: String(org), role, type: "access" }, env.JWT_SECRET, { expiresIn: "10m" });
  const get = (path: string, id = parent, role?: string, org = orgId) => api.get(`/api/family-messages/${path}`).set("Authorization", `Bearer ${token(id, role, org)}`);
  const post = (path: string, body: unknown, id = parent, role?: string) => api.post(`/api/family-messages/${path}`).set("Authorization", `Bearer ${token(id, role)}`).send(body);
  const open = (id = parent, child = student, contact = teacher) => post("conversations", { studentId: String(child), contactId: String(contact) }, id);
  const send = (body: string, id = parent, conversation = thread, clientId = randomUUID()) =>
    post(`conversations/${conversation}/messages`, { body, clientId }, id);

  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Messaging test", code: randomUUID() } })).id;
    foreignOrg = (await prisma.organization.create({ data: { name: "Other messaging school", code: randomUUID() } })).id;
    branchId = (await prisma.branch.create({ data: { orgId, name: "Main" } })).id;
    otherBranch = (await prisma.branch.create({ data: { orgId, name: "Other" } })).id;
    for (const [index, role] of (["PARENT", "PARENT", "TEACHER", "TEACHER", "PARENT"] as const).entries()) {
      const user = await prisma.user.create({ data: { orgId: index === 4 ? foreignOrg : orgId,
        fullName: `Message user ${index}`, role, passwordHash: "not-a-login", phone: `PRIVATE-CONTACT-${index}` } });
      if (index === 0) parent = user.id;
      if (index === 1) parent2 = user.id;
      if (index === 2) teacher = user.id;
      if (index === 3) teacher2 = user.id;
      if (index === 4) foreignParent = user.id;
    }
    classId = (await prisma.class.create({ data: { orgId, branchId, teacherId: teacher, name: "Level 1A", level: "Primary", academicYear: "2026" } })).id;
    student = (await prisma.student.create({ data: { orgId, branchId, classId, admissionNo: "MSG-1", fullName: "Amina Example", notes: "INTERNAL-CHILD-NOTE" } })).id;
    otherStudent = (await prisma.student.create({ data: { orgId, branchId, classId, admissionNo: "MSG-2", fullName: "Other child" } })).id;
    for (const id of [parent, parent2]) {
      const row = await prisma.guardian.create({ data: { orgId, userId: id, fullName: `Guardian ${id}`, phone: "PRIVATE-GUARDIAN-PHONE" } });
      await prisma.studentGuardian.create({ data: { orgId, guardianId: row.id, studentId: student } });
      if (id === parent) guardian = row.id;
    }
  });
  afterAll(async () => {
    const where = { orgId: { in: [orgId, foreignOrg].filter(Boolean) } };
    await prisma.familyMessage.deleteMany({ where });
    await prisma.familyConversation.deleteMany({ where });
    await prisma.auditLog.deleteMany({ where });
    await prisma.studentGuardian.deleteMany({ where });
    await prisma.student.deleteMany({ where });
    await prisma.guardian.deleteMany({ where });
    await prisma.class.deleteMany({ where });
    await prisma.user.deleteMany({ where });
    await prisma.branch.deleteMany({ where });
    await prisma.organization.deleteMany({ where: { id: where.orgId } });
  });

  it("lists only verified contacts; denies role spoofing, unlinked children and guessed recipients", async () => {
    expect((await api.get("/api/family-messages/contacts")).status).toBe(401);
    for (const role of ["ADMIN", "ACCOUNTANT", "LEARNER", "TEACHER"]) expect((await get("contacts", parent, role)).status).toBe(403);
    const contacts = await get("contacts");
    expect(contacts.status).toBe(200);
    expect(contacts.headers["cache-control"]).toBe("no-store");
    expect(contacts.body.data.items).toHaveLength(1);
    expect(contacts.body.data.items[0].contact.id).toBe(String(teacher));
    expect(JSON.stringify(contacts.body)).not.toContain("PRIVATE");
    expect(JSON.stringify(contacts.body)).not.toContain("INTERNAL");
    expect((await get("contacts", teacher)).body.data.items).toHaveLength(2);
    expect((await get("contacts", teacher2)).body.data.items).toEqual([]);
    expect((await open(parent, otherStudent)).status).toBe(404);
    expect((await open(parent, student, teacher2)).status).toBe(404);
    expect((await open(parent, student, foreignParent)).status).toBe(404);
    expect((await get("contacts?parentUserId=1")).status).toBe(422);
    expect((await get("contacts?page=0")).status).toBe(422);
    expect((await get("contacts?search=not-matching")).body.data.items).toEqual([]);
  });

  it("reuses one child-parent-teacher conversation, but keeps different guardians private", async () => {
    const response = await open();
    expect(response.status).toBe(200);
    thread = response.body.data.id;
    expect((await open()).body.data.id).toBe(thread);
    expect((await open(teacher, student, parent)).body.data.id).toBe(thread);
    const second = await open(parent2);
    expect(second.status).toBe(200);
    secondThread = second.body.data.id;
    expect(secondThread).not.toBe(thread);
    expect((await get(`conversations/${thread}`, parent2)).status).toBe(404);
    expect((await get(`conversations/${thread}`, teacher2)).status).toBe(404);
    expect((await get(`conversations/${thread}`, foreignParent, "PARENT", foreignOrg)).status).toBe(404);
    expect((await send("Not my conversation", parent2)).status).toBe(404);
    expect((await post(`conversations/${thread}/read`, { throughId: "1" }, parent2)).status).toBe(404);
    expect((await get("conversations", parent2)).body.data.items.map((c: { id: string }) => c.id)).toEqual([secondThread]);
  });

  it("validates messages, persists both directions and makes uncertain/concurrent retries idempotent", async () => {
    for (const body of ["", "   ", "x".repeat(2001)]) expect((await send(body)).status).toBe(422);
    expect((await post(`conversations/${thread}/messages`, { body: "Hello", clientId: randomUUID(), senderId: String(teacher) })).status).toBe(422);
    const clientId = randomUUID();
    const response = await send(" Assalamu alaikum ", parent, thread, clientId);
    expect(response.status).toBe(200);
    expect(response.body.data.message.body).toBe("Assalamu alaikum");
    const repeated = await Promise.all([send("Assalamu alaikum", parent, thread, clientId), send("Assalamu alaikum", parent, thread, clientId)]);
    for (const r of repeated) expect(r.body.data.message.id).toBe(response.body.data.message.id);
    expect((await send("Different body", parent, thread, clientId)).status).toBe(409);
    expect(await prisma.familyMessage.count({ where: { orgId, senderId: parent, clientId } })).toBe(1);
    expect((await send("Wa alaikum salaam", teacher)).status).toBe(200);
    const history = await get(`conversations/${thread}`);
    expect(history.body.data.messages.map((m: { body: string }) => m.body)).toEqual(["Assalamu alaikum", "Wa alaikum salaam"]);
    const audit = await prisma.auditLog.findMany({ where: { orgId, entityType: "FamilyConversation", entityId: thread } });
    expect(audit).toHaveLength(2);
    expect(JSON.stringify(audit.map(a => a.metadata))).not.toContain("Assalamu");
  });

  it("acknowledges only displayed message IDs, never future messages, and never moves read state backward", async () => {
    const history = (await get(`conversations/${thread}`, teacher)).body.data;
    const first = history.messages[0].id, last = history.messages[1].id;
    expect((await get("conversations", teacher)).body.data.items.find((t: { id: string }) => t.id === thread).unread).toBe(1);
    expect((await post(`conversations/${thread}/read`, { throughId: last }, teacher)).body.data.readThrough).toBe(last);
    expect((await post(`conversations/${thread}/read`, { throughId: first }, teacher)).body.data.readThrough).toBe(last);
    expect((await get("conversations", teacher)).body.data.items.find((t: { id: string }) => t.id === thread).unread).toBe(0);
    expect((await post(`conversations/${thread}/read`, { throughId: "999999999" }, teacher)).status).toBe(422);
    const other = await send("Separate guardian", parent2, secondThread);
    expect((await post(`conversations/${thread}/read`, { throughId: other.body.data.message.id }, teacher)).status).toBe(422);
    await send("A later message");
    expect((await get("conversations", teacher)).body.data.items.find((t: { id: string }) => t.id === thread).unread).toBe(1);
  });

  it("paginates history with stable message cursors and does not expose another conversation", async () => {
    await prisma.familyMessage.createMany({ data: Array.from({ length: 35 }, (_, i) => ({ orgId, conversationId: BigInt(thread), senderId: parent, clientId: randomUUID(), body: `History ${i}` })) });
    const latest = (await get(`conversations/${thread}`)).body.data;
    expect(latest.messages).toHaveLength(30);
    expect(latest.hasOlder).toBe(true);
    const older = (await get(`conversations/${thread}?before=${latest.nextBefore}`)).body.data;
    expect(older.messages.length).toBeGreaterThan(0);
    expect(older.messages.every((m: { id: string }) => BigInt(m.id) < BigInt(latest.nextBefore))).toBe(true);
    expect(new Set([...latest.messages, ...older.messages].map(m => m.id)).size).toBe(38);
    expect((await get(`conversations/${thread}?before=0`)).status).toBe(422);
    expect((await get("conversations/9999999999999999999999999")).status).toBe(422);
  });

  it("immediately revokes access when assignments, branch scope, status or guardian links change", async () => {
    await prisma.class.update({ where: { id: classId }, data: { teacherId: teacher2 } });
    expect((await get(`conversations/${thread}`)).status).toBe(404);
    expect((await send("Old assignment", teacher)).status).toBe(404);
    expect((await get(`conversations/${thread}`, teacher2)).status).toBe(404);
    expect((await get("conversations")).body.data.items).toEqual([]);
    await prisma.class.update({ where: { id: classId }, data: { teacherId: teacher } });
    await prisma.user.update({ where: { id: teacher }, data: { branchId: otherBranch } });
    expect((await get(`conversations/${thread}`, teacher)).status).toBe(404);
    expect((await get("contacts")).body.data.items).toEqual([]);
    await prisma.user.update({ where: { id: teacher }, data: { branchId: null, status: "DISABLED" } });
    expect((await get(`conversations/${thread}`, teacher)).status).toBe(403);
    expect((await get(`conversations/${thread}`)).status).toBe(404);
    await prisma.user.update({ where: { id: teacher }, data: { status: "ACTIVE" } });
    await prisma.student.update({ where: { id: student }, data: { status: "INACTIVE" } });
    expect((await send("Archived student")).status).toBe(404);
    await prisma.student.update({ where: { id: student }, data: { status: "ACTIVE" } });
    await prisma.studentGuardian.deleteMany({ where: { orgId, studentId: student, guardianId: guardian } });
    expect((await get(`conversations/${thread}`, teacher)).status).toBe(404);
    expect((await send("Unlinked parent")).status).toBe(404);
    expect((await get("contacts")).body.data.items).toEqual([]);
    await prisma.studentGuardian.create({ data: { orgId, studentId: student, guardianId: guardian } });
    expect((await get(`conversations/${thread}`)).status).toBe(200);
  });

  it("rejects suspended school accounts and tenant-mismatched foreign keys", async () => {
    await prisma.organization.update({ where: { id: orgId }, data: { status: "SUSPENDED" } });
    expect((await get("conversations")).status).toBe(403);
    expect((await send("Suspended")).status).toBe(403);
    await prisma.organization.update({ where: { id: orgId }, data: { status: "ACTIVE" } });
    await expect(prisma.familyConversation.create({ data: { orgId, studentId: student, parentId: foreignParent, teacherId: teacher } })).rejects.toMatchObject({ code: "P2003" });
  });
});
