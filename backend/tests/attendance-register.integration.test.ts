import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { env } from "../src/config/env";
import { prisma } from "../src/shared/db/prisma";
import { api } from "./helpers/api-client";
import { schoolDate } from "../src/modules/attendance/register.service";

describe("daily attendance register", () => {
  let orgId: bigint, otherOrg: bigint, adminId: bigint, teacherId: bigint;
  let classId: bigint, otherClass: bigint, privateClass: bigint;
  let first: bigint, second: bigint, outsider: bigint;
  const token = (role = "ADMIN") => jwt.sign({
    sub: (role === "TEACHER" ? teacherId : adminId).toString(), orgId: orgId.toString(),
    role, type: "access",
  }, env.JWT_SECRET, { expiresIn: "10m" });
  const read = (date: string, group = classId, role = "ADMIN", history = false) =>
    api.get(`/api/attendance/register${history ? "/history" : ""}?classId=${group}&date=${date}`)
      .set("Authorization", `Bearer ${token(role)}`);
  const save = (date: string, records: object[], extra = {}, role = "ADMIN") =>
    api.post("/api/attendance/register").set("Authorization", `Bearer ${token(role)}`)
      .send({ classId: String(classId), date, records, ...extra });
  const mark = (id = first, values = {}) => ({
    studentId: String(id), version: 0, status: "PRESENT", checkInTime: "07:45", ...values,
  });

  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Attendance test", code: randomUUID() } })).id;
    otherOrg = (await prisma.organization.create({ data: { name: "Private school", code: randomUUID() } })).id;
    const branch = await prisma.branch.create({ data: { orgId, name: "Main" } });
    const privateBranch = await prisma.branch.create({ data: { orgId: otherOrg, name: "Private" } });
    adminId = (await prisma.user.create({ data: { orgId, fullName: "Office Admin", role: "ADMIN", passwordHash: "not-a-login" } })).id;
    teacherId = (await prisma.user.create({ data: { orgId, fullName: "Assigned Teacher", role: "TEACHER", passwordHash: "not-a-login" } })).id;
    classId = (await prisma.class.create({ data: { orgId, branchId: branch.id, name: "One", level: "One", academicYear: "2026", teacherId } })).id;
    otherClass = (await prisma.class.create({ data: { orgId, branchId: branch.id, name: "Two", level: "Two", academicYear: "2026" } })).id;
    privateClass = (await prisma.class.create({ data: { orgId: otherOrg, branchId: privateBranch.id, name: "Private", level: "One", academicYear: "2026" } })).id;
    for (const [index, name] of ["Amina", "Bilal", "Outside"].entries()) {
      const student = await prisma.student.create({ data: {
        orgId, branchId: branch.id, admissionNo: `REG-${index}`, fullName: name,
        classId: index === 2 ? otherClass : classId,
      } });
      if (index === 0) first = student.id;
      if (index === 1) second = student.id;
      if (index === 2) outsider = student.id;
    }
  });
  afterAll(async () => {
    const where = { orgId: { in: [orgId, otherOrg].filter(Boolean) } };
    await prisma.attendanceRecord.deleteMany({ where });
    await prisma.auditLog.deleteMany({ where });
    await prisma.student.deleteMany({ where });
    await prisma.class.deleteMany({ where });
    await prisma.user.deleteMany({ where });
    await prisma.branch.deleteMany({ where });
    await prisma.organization.deleteMany({ where: { id: where.orgId } });
  });

  it("restricts roles, tenant access and assigned teacher classes", async () => {
    expect((await api.get("/api/attendance/register")).status).toBe(401);
    for (const role of ["PARENT", "ACCOUNTANT", "LEARNER"]) {
      expect((await read("2026-01-01", classId, role)).status).toBe(403);
      expect((await save("2026-01-01", [mark()], {}, role)).status).toBe(403);
    }
    expect((await read("2026-01-01", privateClass)).status).toBe(404);
    expect((await read("2026-01-01", otherClass, "TEACHER")).status).toBe(404);
    expect((await save("2026-01-01", [mark()], { classId: String(otherClass) }, "TEACHER")).status).toBe(404);
    expect((await read("2026-01-01", classId, "TEACHER")).status).toBe(200);
  });
  it("returns unmarked students and counts only saved attendance", async () => {
    let data = (await read("2026-01-02")).body.data;
    expect(data.items).toHaveLength(2);
    expect(data.summary).toMatchObject({ total: 0, unmarked: 2, absent: 0 });
    expect(data.timeline).toHaveLength(7);
    expect((await save("2026-01-02", [mark()])).status).toBe(200);
    data = (await read("2026-01-02")).body.data;
    expect(data.summary).toMatchObject({ present: 1, unmarked: 1, total: 1 });
    expect(data.items[0].attendance).toMatchObject({ version: 1, checkInTime: "07:45" });
  });
  it("requires correction reasons, audits before/after and blocks stale edits", async () => {
    await save("2026-01-03", [mark()]);
    const correction = mark(first, { version: 1, status: "LATE", checkInTime: "08:30" });
    expect((await save("2026-01-03", [correction])).status).toBe(422);
    expect((await save("2026-01-03", [correction], { correctionReason: "Arrival time confirmed" })).status).toBe(200);
    expect((await save("2026-01-03", [correction], { correctionReason: "Older form submitted" })).status).toBe(409);
    const history = (await read("2026-01-03", classId, "ADMIN", true)).body.data;
    expect(history).toHaveLength(2);
    expect(history[0].metadata).toMatchObject({ correctionReason: "Arrival time confirmed",
      changes: [{ before: { status: "PRESENT", version: 1 }, after: { status: "LATE", version: 2 } }] });
    expect((await save("2026-01-03", [mark(first, { version: 2, status: "LATE", checkInTime: "08:30" })])).body.data.saved).toBe(0);
  });
  it("rolls back the entire save on a bad student and rejects invalid input", async () => {
    expect((await save("2026-01-04", [mark(), mark(outsider)])).status).toBe(409);
    expect((await read("2026-01-04")).body.data.summary.total).toBe(0);
    for (const rows of [[mark(), mark()], [mark(first, { checkInTime: "25:00" })],
      [mark(first, { status: "ABSENT" })], [mark(first, { version: -1 })],
      [mark(first, { orgId: String(otherOrg) })]]) {
      expect((await save("2026-01-04", rows)).status).toBe(422);
    }
    expect((await save("2099-01-01", [mark()])).status).toBe(422);
    expect((await read("2026-02-31")).status).toBe(422);
  });
  it("keeps transferred students in historical registers without moving records", async () => {
    await save("2026-01-05", [mark(second)]);
    await prisma.student.update({ where: { id: second }, data: { classId: otherClass } });
    const roster = (await read("2026-01-05")).body.data.items;
    expect(roster.find((s: { id: string }) => s.id === String(second))).toMatchObject({ current: false, editable: true });
    expect((await save("2026-01-05", [mark(second, { version: 1, reason: "Confirmed" })],
      { correctionReason: "Office verified old register" })).status).toBe(200);
    expect((await save("2026-01-05", [mark(second)], { classId: String(otherClass) })).status).toBe(409);
    await prisma.student.update({ where: { id: second }, data: { classId } });
  });
  it("allows only one simultaneous creation and one simultaneous correction", async () => {
    const creations = await Promise.all([save("2026-01-06", [mark()]), save("2026-01-06", [mark()])]);
    expect(creations.map(r => r.status).sort()).toEqual([200, 409]);
    const changes = await Promise.all([
      save("2026-01-06", [mark(first, { version: 1, reason: "First edit" })], { correctionReason: "Office correction" }),
      save("2026-01-06", [mark(first, { version: 1, reason: "Second edit" })], { correctionReason: "Teacher correction" }),
    ]);
    expect(changes.map(r => r.status).sort()).toEqual([200, 409]);
  });
  it("legacy teacher writes invalidate an admin's old register version", async () => {
    await save("2026-01-07", [mark()]);
    const legacy = await api.post("/api/attendance/bulk-mark").set("Authorization", `Bearer ${token("TEACHER")}`)
      .send({ classId: String(classId), date: "2026-01-07", records: [{ studentId: String(first), status: "ABSENT" }] });
    expect(legacy.status).toBe(200);
    expect(legacy.body.data[0]).toMatchObject({ version: 2, checkInTime: null, status: "ABSENT" });
    expect((await save("2026-01-07", [mark(first, { version: 1 })], { correctionReason: "Stale register" })).status).toBe(409);
    expect((await read("2026-01-07", classId, "ADMIN", true)).body.data).toHaveLength(2);
  });
  it("uses the Tanzania school day at midnight rollover", () => {
    expect(schoolDate(new Date("2026-09-25T21:01:00Z"))).toBe("2026-09-26");
    expect(schoolDate(new Date("2026-09-25T20:59:00Z"))).toBe("2026-09-25");
  });
});
