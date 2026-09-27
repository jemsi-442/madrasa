import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/shared/db/prisma";
import { env } from "../src/config/env";
import { api } from "./helpers/api-client";
import type { LearningReport } from "../src/modules/student-reports/student-reports.service";

describe("learner self-service workspace", () => {
  let orgId: bigint, otherOrg: bigint, branchId: bigint, teacher: bigint, learner: bigint, independent: bigint;
  let student: bigint, peer: bigint, classId: bigint, releaseId: bigint, reportId: bigint, peerRelease: bigint;
  let assessmentId: bigint, assessmentRelease: bigint;
  const token = (user = learner, role = "LEARNER", org = orgId) => jwt.sign({ sub: String(user), orgId: String(org), role, type: "access" }, env.JWT_SECRET, { expiresIn: "10m" });
  const get = (path: string, user = learner) => api.get(`/api/learner/workspace/${path}`).set("Authorization", `Bearer ${token(user)}`);
  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Learner Test School", code: randomUUID() } })).id;
    otherOrg = (await prisma.organization.create({ data: { name: "Other School", code: randomUUID() } })).id;
    branchId = (await prisma.branch.create({ data: { orgId, name: "Main" } })).id;
    teacher = (await prisma.user.create({ data: { orgId, role: "TEACHER", fullName: "Teacher", phone: "PRIVATE CONTACT", passwordHash: "not-a-login" } })).id;
    learner = (await prisma.user.create({ data: { orgId, role: "LEARNER", fullName: "Ahmad", passwordHash: "not-a-login" } })).id;
    independent = (await prisma.user.create({ data: { orgId, role: "LEARNER", fullName: "Independent", passwordHash: "not-a-login" } })).id;
    classId = (await prisma.class.create({ data: { orgId, branchId, teacherId: teacher, name: "Year 2", level: "Primary", academicYear: "2026" } })).id;
    student = (await prisma.student.create({ data: { orgId, branchId, classId, learnerUserId: learner, fullName: "Ahmad", admissionNo: "SELF", notes: "PRIVATE STUDENT NOTE" } })).id;
    peer = (await prisma.student.create({ data: { orgId, branchId, classId, fullName: "SECRET PEER", admissionNo: "PEER" } })).id;
    await prisma.student.create({ data: { orgId, branchId, learnerUserId: independent, fullName: "Independent", admissionNo: "ONLINE" } });
    for (const [i, status] of (["PRESENT", "LATE", "ABSENT", "EXCUSED"] as const).entries())
      await prisma.attendanceRecord.create({ data: { orgId, branchId, classId, studentId: student, markedById: teacher, date: new Date(`2026-09-0${i + 1}`), status } });
    await prisma.attendanceRecord.create({ data: { orgId, branchId, classId, studentId: peer, markedById: teacher, date: new Date("2026-09-01"), status: "PRESENT", reason: "SECRET PEER REASON" } });
    for (const [from, to, activity, observation, voided] of [
      [1, 5, "MEMORIZATION", "INDEPENDENT", false], [3, 8, "MEMORIZATION", "INDEPENDENT", false],
      [9, 20, "READING", "INDEPENDENT", false], [9, 20, "MEMORIZATION", "NEEDS_PRACTICE", false],
      [21, 30, "MEMORIZATION", "INDEPENDENT", true],
    ] as const) await prisma.quranSession.create({ data: { orgId, classId, studentId: student, teacherId: teacher,
      clientId: randomUUID(), requestHash: "a".repeat(64), surahId: 67, ayahFrom: from, ayahTo: to, activity, observation,
      learnedOn: new Date("2026-09-01"), note: "PRIVATE TEACHER NOTE", voidedAt: voided ? new Date() : null } });
    for (const [subject, weekday, from, until, cancelled] of [
      ["Quran", 1, "2026-09-01", "2026-09-30", false],
      ["Arabic", 3, "2026-09-23", "2026-09-23", false],
      ["Not yet valid", 1, "2026-09-22", "2026-10-30", false],
      ["Cancelled", 2, "2026-09-01", "2026-09-30", true],
    ] as const) await prisma.classTimetableSlot.create({ data: { orgId, classId, createdById: teacher,
      subject, weekday, startsAt: "08:00", endsAt: "08:40", validFrom: new Date(from), validUntil: new Date(until), cancelledAt: cancelled ? new Date() : null } });
    const subjectId = (await prisma.subject.create({ data: { orgId, name: "Fiqh", code: "FIQH" } })).id;
    assessmentId = (await prisma.assessment.create({ data: { orgId, classId, subjectId, createdById: teacher,
      clientId: randomUUID(), title: "Wudu", assessedOn: new Date("2026-09-10"), maxScore: 10, status: "PUBLISHED" } })).id;
    await prisma.assessmentResult.createMany({ data: [student, peer].map(studentId => ({ orgId, assessmentId, studentId, score: 8 })) });
    assessmentRelease = (await prisma.assessmentRelease.create({ data: { orgId, assessmentId, revision: 1, publishedById: teacher,
      snapshot: { title: "Wudu", assessedOn: "2026-09-10", subject: { id: String(subjectId), name: "Fiqh" }, class: { id: String(classId), name: "Year 2" },
        maxScore: 10, teacher: "Teacher", results: [{ studentId: String(student), score: 8, feedback: "Good sequence" },
          { studentId: String(peer), score: 9, feedback: "SECRET PEER FEEDBACK" }] } } })).id;
    const period = await prisma.reportingPeriod.create({ data: { orgId, createdById: teacher, clientId: randomUUID(), name: "September", startsOn: new Date("2026-09-01"), endsOn: new Date("2026-09-20") } });
    for (const studentId of [student, peer]) {
      const snapshot: LearningReport = { school: "Learner Test School", period: { name: "September", startsOn: "2026-09-01", endsOn: "2026-09-20" },
        student: { id: String(studentId), fullName: studentId === student ? "Ahmad" : "SECRET PEER", admissionNo: "TEST" },
        className: "Year 2", teacher: "Teacher", feedback: "Keep revising", policy: "Published records only", assessments: [],
        attendance: { present: 1, late: 1, absent: 1, excused: 1, recorded: 4, rate: 66.67 },
        quran: { sessions: 4, memorisedAyahs: 8, reading: 1, revision: 0, tajweed: 0 } };
      const report = await prisma.studentReport.create({ data: { orgId, periodId: period.id, classId, studentId,
        preparedById: teacher, status: "PUBLISHED", draft: JSON.parse(JSON.stringify(snapshot)) } });
      const release = await prisma.reportRelease.create({ data: { orgId, reportId: report.id, revision: 1, publishedById: teacher, snapshot: report.draft! } });
      if (studentId === student) { reportId = report.id; releaseId = release.id; } else peerRelease = release.id;
    }
    await prisma.reportAssessmentSource.create({ data: { orgId, reportReleaseId: releaseId, assessmentReleaseId: assessmentRelease } });
  });
  afterAll(async () => {
    const where = { orgId: { in: [orgId, otherOrg].filter(Boolean) } };
    await prisma.reportAssessmentSource.deleteMany({ where }); await prisma.reportRelease.deleteMany({ where });
    await prisma.studentReport.deleteMany({ where }); await prisma.reportingPeriod.deleteMany({ where });
    await prisma.assessmentRelease.deleteMany({ where }); await prisma.assessmentResult.deleteMany({ where });
    await prisma.assessment.deleteMany({ where }); await prisma.subject.deleteMany({ where });
    await prisma.classTimetableSlot.deleteMany({ where }); await prisma.quranSession.deleteMany({ where });
    await prisma.attendanceRecord.deleteMany({ where }); await prisma.student.deleteMany({ where });
    await prisma.class.deleteMany({ where }); await prisma.user.deleteMany({ where });
    await prisma.branch.deleteMany({ where }); await prisma.organization.deleteMany({ where: { id: where.orgId } });
  });
  it("requires a live linked learner and rejects scope overrides", async () => {
    expect((await api.get("/api/learner/workspace/overview")).status).toBe(401);
    for (const role of ["ADMIN", "TEACHER", "PARENT"]) expect((await api.get("/api/learner/workspace/overview").set("Authorization", `Bearer ${token(learner, role)}`)).status).toBe(403);
    for (const area of ["overview", "classes", "attendance", "quran", "academic?year=2026", "reports"])
      expect((await get(`${area}${area.includes("?") ? "&" : "?"}studentId=${peer}`)).status).toBe(422);
    expect((await api.get("/api/learner/workspace/overview").set("Authorization", `Bearer ${token(learner, "LEARNER", otherOrg)}`)).status).toBe(403);
    await prisma.user.update({ where: { id: learner }, data: { status: "DISABLED" } });
    expect((await get("overview")).status).toBe(403);
    await prisma.user.update({ where: { id: learner }, data: { status: "ACTIVE" } });
    await prisma.organization.update({ where: { id: orgId }, data: { status: "SUSPENDED" } });
    expect((await get("overview")).status).toBe(403);
    await prisma.organization.update({ where: { id: orgId }, data: { status: "ACTIVE" } });
    await prisma.student.update({ where: { id: student }, data: { learnerUserId: null } });
    expect((await get("overview")).status).toBe(404);
    await prisma.student.update({ where: { id: student }, data: { learnerUserId: learner } });
  });
  it("preserves independent learner access and honest empty states", async () => {
    const response = await get("overview", independent);
    expect(response.status).toBe(200); expect(response.headers["cache-control"]).toBe("no-store");
    expect(response.body.data.student.currentClass).toBeNull();
    expect(response.body.data.attendance.rate).toBeNull(); expect(response.body.data.academics.average).toBeNull();
    expect(response.body.data.sessions).toEqual([]); expect(response.body.data.latestReport).toBeNull();
    expect((await api.get("/api/learner/courses").set("Authorization", `Bearer ${token(independent)}`)).status).toBe(200);
  });
  it("returns only actual own attendance, counts late as present and validates dates", async () => {
    const response = await get("attendance?month=2026-09");
    expect(response.status).toBe(200);
    expect(response.body.data.summary).toEqual({ PRESENT: 1, LATE: 1, ABSENT: 1, EXCUSED: 1, markedDays: 4, rate: 67 });
    expect(response.body.data.records).toHaveLength(4); expect(JSON.stringify(response.body)).not.toContain("SECRET PEER");
    expect((await get("attendance?month=2026-10")).body.data.summary.rate).toBeNull();
    expect((await get("attendance?month=2026-13")).status).toBe(422);
    expect((await get("classes?date=2026-02-30")).status).toBe(422);
  });
  it("shows only valid dated timetable occurrences and follows class reassignment", async () => {
    const data = (await get("classes?date=2026-09-24")).body.data;
    expect(data.weekStart).toBe("2026-09-21");
    expect(data.sessions.map((s: { subject: string }) => s.subject)).toEqual(["Quran", "Arabic"]);
    expect(data.sessions.map((s: { date: string }) => s.date)).toEqual(["2026-09-21", "2026-09-23"]);
    await prisma.student.update({ where: { id: student }, data: { classId: null } });
    expect((await get("classes?date=2026-09-24")).body.data.sessions).toEqual([]);
    await prisma.student.update({ where: { id: student }, data: { classId } });
  });
  it("deduplicates confirmed ayahs without exposing internal notes", async () => {
    const response = await get("quran");
    expect(response.status).toBe(200); expect(response.body.data.memorisedAyahs).toBe(8);
    expect(response.body.data.totalAyahs).toBe(6236); expect(response.body.data.meta.totalItems).toBe(4);
    expect(response.body.data.juzs[28].memorisedAyahs).toBe(8);
    expect(JSON.stringify(response.body)).not.toMatch(/PRIVATE|SECRET/);
    expect((await get("quran?page=2")).body.data.sessions).toEqual([]);
    expect((await get("quran?page=0")).status).toBe(422);
  });
  it("returns only own published marks and authenticated own PDFs", async () => {
    const marks = await get("academic?year=2026");
    expect(marks.status).toBe(200); expect(marks.body.data.average).toBe(80);
    expect(marks.body.data.records).toHaveLength(1); expect(JSON.stringify(marks.body)).not.toMatch(/SECRET|PRIVATE/);
    expect((await get("academic?year=2025")).body.data.average).toBeNull();
    const reports = await get("reports");
    expect(reports.body.data.items).toHaveLength(1); expect(JSON.stringify(reports.body)).not.toContain("SECRET");
    const pdf = await get(`reports/${releaseId}/pdf`);
    expect(pdf.status).toBe(200); expect(Buffer.from(pdf.body.data.base64, "base64").subarray(0, 5).toString()).toBe("%PDF-");
    expect((await get(`reports/${peerRelease}/pdf`)).status).toBe(404);
    expect((await get(`reports/${releaseId}/pdf`, independent)).status).toBe(404);
    expect((await get("reports/9999999999999999999999/pdf")).status).toBe(422);
    await prisma.studentReport.update({ where: { id: reportId }, data: { status: "SUBMITTED" } });
    expect((await get("reports")).body.data.items).toEqual([]);
    expect((await get(`reports/${releaseId}/pdf`)).status).toBe(404);
    await prisma.studentReport.update({ where: { id: reportId }, data: { status: "PUBLISHED" } });
    await prisma.assessmentRelease.update({ where: { id: assessmentRelease }, data: { retractedAt: new Date() } });
    expect((await get("academic?year=2026")).body.data.records).toEqual([]);
    expect((await get("reports")).body.data.items).toEqual([]);
    expect((await get(`reports/${releaseId}/pdf`)).status).toBe(404);
    await prisma.assessmentRelease.update({ where: { id: assessmentRelease }, data: { retractedAt: null } });
    await prisma.assessment.update({ where: { id: assessmentId }, data: { status: "DRAFT" } });
    expect((await get("academic?year=2026")).body.data.records).toEqual([]);
    expect((await get("reports")).body.data.items).toEqual([]);
  });
});
