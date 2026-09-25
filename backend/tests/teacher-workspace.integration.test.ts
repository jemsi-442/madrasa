import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/shared/db/prisma";
import { env } from "../src/config/env";
import { api } from "./helpers/api-client";
import catalog from "../src/modules/teacher-workspace/quran-catalog.json";
import { sharesTeachingDay } from "../src/modules/teacher-workspace/timetable.service";

describe("teacher workspace", () => {
  let orgId: bigint, otherOrg: bigint, admin: bigint, teacher: bigint, otherTeacher: bigint;
  let classId: bigint, secondClass: bigint, outsideClass: bigint, privateClass: bigint;
  let student: bigint, outsideStudent: bigint, privateStudent: bigint, branchStudent: bigint;
  const token = (role = "TEACHER", id = teacher) => jwt.sign({
    sub: String(role === "ADMIN" ? admin : id), orgId: String(orgId), role, type: "access",
  }, env.JWT_SECRET, { expiresIn: "10m" });
  const get = (path: string, role = "TEACHER") =>
    api.get(path).set("Authorization", `Bearer ${token(role)}`);
  const post = (path: string, body: object, role = "TEACHER") =>
    api.post(path).set("Authorization", `Bearer ${token(role)}`).send(body);
  const input = (extra = {}) => ({
    clientId: randomUUID(), classId: String(classId), studentId: String(student),
    surahId: 67, ayahFrom: 1, ayahTo: 10, activity: "MEMORIZATION",
    observation: "INDEPENDENT", learnedOn: "2026-09-01", ...extra,
  });
  const progress = () => get(`/api/teacher-workspace/quran?studentId=${student}&surahId=67`);
  const save = (data: object) => post("/api/teacher-workspace/quran/sessions", data);
  const slot = (extra = {}) => ({
    weekday: 1, startsAt: "08:00", endsAt: "08:45", validFrom: "2026-09-01",
    validUntil: "2026-12-31", subject: "Quran", room: "Room 01", ...extra,
  });
  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Teacher test", code: randomUUID() } })).id;
    otherOrg = (await prisma.organization.create({ data: { name: "Private school", code: randomUUID() } })).id;
    const branch = await prisma.branch.create({ data: { orgId, name: "Main" } });
    const otherBranch = await prisma.branch.create({ data: { orgId, name: "Other campus" } });
    const privateBranch = await prisma.branch.create({ data: { orgId: otherOrg, name: "Private" } });
    admin = (await prisma.user.create({ data: { orgId, fullName: "Office", passwordHash: "not-a-login", role: "ADMIN" } })).id;
    teacher = (await prisma.user.create({ data: { orgId, branchId: branch.id, fullName: "Teacher One", passwordHash: "not-a-login", role: "TEACHER" } })).id;
    otherTeacher = (await prisma.user.create({ data: { orgId, fullName: "Teacher Two", passwordHash: "not-a-login", role: "TEACHER" } })).id;
    for (const [index, name] of ["Assigned", "Second assigned", "Outside", "Private", "Other campus"].entries()) {
      const privateSchool = index === 3;
      const group = await prisma.class.create({ data: {
        orgId: privateSchool ? otherOrg : orgId,
        branchId: privateSchool ? privateBranch.id : index === 4 ? otherBranch.id : branch.id,
        name, level: "One", academicYear: "2026",
        ...(privateSchool ? {} : { teacherId: index === 2 ? otherTeacher : teacher }),
      } });
      const child = await prisma.student.create({ data: {
        orgId: group.orgId, branchId: group.branchId, classId: group.id, admissionNo: `REG-${index}`,
        fullName: `Student ${name}`, joinedOn: new Date("2026-01-01"),
      } });
      if (index === 0) { classId = group.id; student = child.id; }
      if (index === 1) secondClass = group.id;
      if (index === 2) { outsideClass = group.id; outsideStudent = child.id; }
      if (index === 3) { privateClass = group.id; privateStudent = child.id; }
      if (index === 4) branchStudent = child.id;
    }
  });
  afterAll(async () => {
    const where = { orgId: { in: [orgId, otherOrg].filter(Boolean) } };
    await prisma.quranSession.deleteMany({ where });
    await prisma.studentSupportNote.deleteMany({ where });
    await prisma.classTimetableSlot.deleteMany({ where });
    await prisma.auditLog.deleteMany({ where });
    await prisma.student.deleteMany({ where });
    await prisma.class.deleteMany({ where });
    await prisma.user.deleteMany({ where });
    await prisma.branch.deleteMany({ where });
    await prisma.organization.deleteMany({ where: { id: where.orgId } });
  });

  it("has a complete, non-overlapping canonical catalogue", () => {
    expect(catalog.chapters.map(c => c.id)).toEqual(Array.from({ length: 114 }, (_, i) => i + 1));
    expect(catalog.juzs.map(j => j.number)).toEqual(Array.from({ length: 30 }, (_, i) => i + 1));
    const seen = new Set<string>();
    for (const juz of catalog.juzs) for (const range of juz.ranges) {
      expect(range.from).toBeGreaterThanOrEqual(1);
      expect(range.to).toBeLessThanOrEqual(catalog.chapters[range.surahId - 1]!.ayahCount);
      for (let ayah = range.from; ayah <= range.to; ayah++) {
        const key = `${range.surahId}:${ayah}`;
        expect(seen.has(key)).toBe(false);
        seen.add(key);
      }
    }
    expect(seen.size).toBe(6236);
    expect(catalog.chapters.reduce((sum, c) => sum + c.ayahCount, 0)).toBe(seen.size);
  });
  it("scopes directories and every student endpoint to current assignments and branch", async () => {
    expect((await api.get("/api/teacher-workspace/overview")).status).toBe(401);
    for (const role of ["ADMIN", "PARENT", "ACCOUNTANT", "LEARNER"])
      expect((await get("/api/teacher-workspace/overview", role)).status).toBe(403);
    const classes = (await get("/api/teacher-workspace/classes")).body.data;
    expect(classes.map((c: { id: string }) => c.id).sort()).toEqual([String(classId), String(secondClass)].sort());
    expect((await get("/api/teacher-workspace/students?pageSize=1")).body.data.meta).toMatchObject({ totalItems: 2, totalPages: 2 });
    for (const id of [outsideStudent, privateStudent, branchStudent]) {
      expect((await get(`/api/teacher-workspace/students/${id}`)).status).toBe(404);
      expect((await get(`/api/teacher-workspace/quran?studentId=${id}&surahId=67`)).status).toBe(404);
      expect((await save(input({ studentId: String(id) }))).status).toBe(404);
      expect((await post("/api/teacher-workspace/support", {
        clientId: randomUUID(), studentId: String(id), classId: String(classId), note: "Need reading practice",
      })).status).toBe(404);
    }
    expect((await get("/api/teacher-workspace/students?search=Second")).body.data.items).toHaveLength(1);
  });
  it("validates dates and canonical passages without writing bad records", async () => {
    for (const extra of [{ ayahTo: 31 }, { ayahFrom: 0 }, { ayahFrom: 12, ayahTo: 10 },
      { learnedOn: "2026-02-31" }, { learnedOn: "2099-01-01" }, { learnedOn: "2025-12-31" },
      { surahId: 115 }, { teacherId: String(otherTeacher) }, { orgId: String(otherOrg) }])
      expect((await save(input(extra))).status).toBe(422);
    expect((await save(input({ classId: String(outsideClass) }))).status).toBe(409);
    expect(await prisma.quranSession.count({ where: { orgId } })).toBe(0);
  });
  it("distinguishes practice from mastery and counts overlapping ayahs once", async () => {
    await save(input({ activity: "READING" }));
    await save(input({ observation: "NEEDS_PRACTICE" }));
    await save(input({ activity: "REVISION" }));
    expect((await progress()).body.data.memorisedAyahs).toEqual([]);
    await save(input({ ayahFrom: 1, ayahTo: 5 }));
    await save(input({ ayahFrom: 4, ayahTo: 8 }));
    expect((await progress()).body.data.memorisedAyahs).toEqual([1, 2, 3, 4, 5, 6, 7, 8]);
  });
  it("retries the same operation once, including concurrent saves, and rejects changed payloads", async () => {
    const data = input({ ayahFrom: 11, ayahTo: 15 });
    const results = await Promise.all([save(data), save(data)]);
    expect(results.map(r => r.status)).toEqual([200, 200]);
    expect(results[0]!.body.data.id).toBe(results[1]!.body.data.id);
    expect((await save({ ...data, ayahTo: 16 })).status).toBe(409);
    expect(await prisma.auditLog.count({ where: { orgId, action: "quran.session.recorded", entityId: results[0]!.body.data.id } })).toBe(1);
    const id = results[0]!.body.data.id;
    expect((await post(`/api/teacher-workspace/quran/sessions/${id}/void`, { reason: "Incorrect learner passage" })).status).toBe(200);
    expect((await progress()).body.data.memorisedAyahs).not.toContain(11);
    expect(await prisma.quranSession.findUnique({ where: { id: BigInt(id) } })).toMatchObject({ voidReason: "Incorrect learner passage" });
  });
  it("keeps follow-ups retryable, scoped, resolvable and reflected in the dashboard", async () => {
    const data = { clientId: randomUUID(), studentId: String(student), classId: String(classId), note: "Practise reading at home" };
    const first = await post("/api/teacher-workspace/support", data);
    expect(first.status).toBe(200);
    expect((await post("/api/teacher-workspace/support", data)).body.data.id).toBe(first.body.data.id);
    expect((await get("/api/teacher-workspace/overview")).body.data.followUpCount).toBe(1);
    expect((await get("/api/teacher-workspace/students?support=open")).body.data.items).toHaveLength(1);
    const path = `/api/teacher-workspace/support/${first.body.data.id}/resolve`;
    expect((await api.post(path).set("Authorization", `Bearer ${token("TEACHER", otherTeacher)}`).send({})).status).toBe(404);
    expect((await post(path, {})).status).toBe(200);
    expect((await post(path, {})).status).toBe(200);
    expect((await get("/api/teacher-workspace/overview")).body.data.followUpCount).toBe(0);
  });
  it("revokes access immediately after transfer or account disabling", async () => {
    await prisma.student.update({ where: { id: student }, data: { classId: outsideClass } });
    expect((await progress()).status).toBe(404);
    expect((await save(input())).status).toBe(404);
    await prisma.student.update({ where: { id: student }, data: { classId } });
    await prisma.user.update({ where: { id: teacher }, data: { status: "DISABLED" } });
    expect((await get("/api/teacher-workspace/classes")).status).toBe(403);
    await prisma.user.update({ where: { id: teacher }, data: { status: "ACTIVE" } });
  });
  it("allows only admin schedule changes and rejects overlapping teacher bookings atomically", async () => {
    const path = `/api/class-timetable/${classId}/timetable`;
    expect((await post(path, slot())).status).toBe(403);
    expect((await get(`/api/class-timetable/${outsideClass}/timetable`)).status).toBe(404);
    expect((await post(`/api/class-timetable/${privateClass}/timetable`, slot(), "ADMIN")).status).toBe(404);
    const saves = await Promise.all([post(path, slot(), "ADMIN"), post(path, slot(), "ADMIN")]);
    expect(saves.map(r => r.status).sort()).toEqual([200, 409]);
    expect((await post(`/api/class-timetable/${secondClass}/timetable`, slot({ startsAt: "08:20" }), "ADMIN")).status).toBe(409);
    expect((await post(path, slot({ startsAt: "08:45", endsAt: "09:30" }), "ADMIN")).status).toBe(200);
    expect((await post(path, slot({ endsAt: "07:00" }), "ADMIN")).status).toBe(422);
    const id = saves.find(r => r.status === 200)!.body.data.id;
    expect((await post(`${path}/${id}/cancel`, { reason: "New teaching schedule" }, "ADMIN")).status).toBe(200);
    expect((await post(path, slot(), "ADMIN")).status).toBe(200);
    expect(sharesTeachingDay(new Date("2026-09-01"), new Date("2026-09-02"), 1)).toBe(false);
  });
});
