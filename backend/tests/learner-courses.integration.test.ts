import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { prisma } from "../src/shared/db/prisma";
import { env } from "../src/config/env";
import { api } from "./helpers/api-client";

describe("learner course browsing and completion", () => {
  let orgId: bigint, otherOrg: bigint, learner: bigint, peer: bigint, student: bigint, peerStudent: bigint;
  let free: bigint, paid: bigint, hidden: bigint, foreign: bigint, draft: bigint, school: bigint;
  let first: bigint, next: bigint, preview: bigint, paidLesson: bigint, draftLesson: bigint, asset: bigint, pendingAsset: bigint;
  let teacher: bigint;
  const token = (user = learner, role = "LEARNER") => jwt.sign({ sub: String(user), orgId: String(orgId), role, type: "access" }, env.JWT_SECRET, { expiresIn: "10m" });
  const get = (path: string, user = learner) => api.get(`/api/learner${path}`).set("Authorization", `Bearer ${token(user)}`);
  const post = (path: string, body: object, user = learner) => api.post(`/api/learner${path}`).set("Authorization", `Bearer ${token(user)}`).send(body);
  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Course browser test", code: randomUUID() } })).id;
    otherOrg = (await prisma.organization.create({ data: { name: "Foreign courses", code: randomUUID() } })).id;
    const branch = await prisma.branch.create({ data: { orgId, name: "Main" } });
    teacher = (await prisma.user.create({ data: { orgId, role: "TEACHER", fullName: "Teacher", passwordHash: "not-a-login" } })).id;
    for (const own of [true, false]) {
      const user = await prisma.user.create({ data: { orgId, role: "LEARNER", fullName: own ? "Learner" : "Peer", passwordHash: "not-a-login" } });
      const row = await prisma.student.create({ data: { orgId, branchId: branch.id, learnerUserId: user.id, fullName: user.fullName,
        admissionNo: randomUUID(), programCategory: "COURSE_STUDENT" } });
      if (own) { learner = user.id; student = row.id; } else { peer = user.id; peerStudent = row.id; }
    }
    const subject = await prisma.subject.create({ data: { orgId, name: "Quran", code: "QURAN" } });
    const otherSubject = await prisma.subject.create({ data: { orgId: otherOrg, name: "Foreign", code: "PRIVATE" } });
    for (const kind of ["free", "paid", "hidden", "foreign", "draft", "school"] as const) {
      const course = await prisma.course.create({ data: { orgId: kind === "foreign" ? otherOrg : orgId,
        subjectId: kind === "foreign" ? otherSubject.id : subject.id, createdByUserId: teacher, primaryInstructorUserId: teacher,
        slug: kind, title: kind, summary: `${kind} summary`, description: "Learn at your own pace.",
        visibility: kind === "paid" ? "PAID" : kind === "hidden" ? "UNLISTED" : "FREE",
        programCategory: kind === "school" ? "MADRASA_CHILD" : "COURSE_STUDENT",
        publicationStatus: kind === "draft" ? "DRAFT" : "PUBLISHED" } });
      if (kind === "free") free = course.id; if (kind === "paid") paid = course.id; if (kind === "hidden") hidden = course.id;
      if (kind === "foreign") foreign = course.id; if (kind === "draft") draft = course.id; if (kind === "school") school = course.id;
    }
    for (const courseId of [free, paid]) {
      const module = await prisma.courseModule.create({ data: { orgId, courseId, title: "Getting started", position: 1 } });
      for (let position = 1; position <= 4; position++) {
        const lesson = await prisma.courseLesson.create({ data: { orgId, courseId, moduleId: module.id,
          title: `Lesson ${position}`, slug: `lesson-${position}`, position, contentText: `Lesson ${position} reading content`,
          publicationStatus: position === 3 ? "DRAFT" : "PUBLISHED",
          visibility: position === 4 ? "UNLISTED" : courseId === paid ? position === 1 ? "PREVIEW" : "PAID" : "FREE" } });
        if (courseId === free && position === 1) first = lesson.id;
        if (courseId === free && position === 2) next = lesson.id;
        if (courseId === free && position === 3) draftLesson = lesson.id;
        if (courseId === paid && position === 1) preview = lesson.id;
        if (courseId === paid && position === 2) paidLesson = lesson.id;
      }
      const privateModule = await prisma.courseModule.create({ data: { orgId, courseId, title: "PRIVATE DRAFT MODULE", position: 2 } });
      await prisma.courseLesson.create({ data: { orgId, courseId, moduleId: privateModule.id, title: "PRIVATE DRAFT", slug: "private-draft", position: 1 } });
    }
    await prisma.courseLessonProgress.createMany({ data: [
      { orgId, courseId: free, lessonId: first, studentId: student, learnerUserId: learner, progressPercent: 100, watchSeconds: 240, completedAt: new Date() },
      { orgId, courseId: free, lessonId: next, studentId: peerStudent, learnerUserId: peer, progressPercent: 100, completedAt: new Date() },
    ] });
    asset = (await prisma.mediaAsset.create({ data: { orgId, courseId: paid, lessonId: paidLesson, assetType: "PDF", visibility: "PAID",
      title: "Revision notes", storageKey: "https://example.test/private-notes.pdf", downloadAllowed: false } })).id;
    pendingAsset = (await prisma.mediaAsset.create({ data: { orgId, courseId: free, lessonId: first, assetType: "PDF", visibility: "FREE",
      title: "Coming soon", storageKey: "not-connected" } })).id;
  });
  afterAll(async () => {
    const where = { orgId: { in: [orgId, otherOrg].filter(Boolean) } };
    await prisma.courseLessonProgress.deleteMany({ where }); await prisma.courseAccessGrant.deleteMany({ where });
    await prisma.mediaAsset.deleteMany({ where }); await prisma.courseLesson.deleteMany({ where }); await prisma.courseModule.deleteMany({ where });
    await prisma.course.deleteMany({ where }); await prisma.subject.deleteMany({ where }); await prisma.auditLog.deleteMany({ where });
    await prisma.student.deleteMany({ where }); await prisma.user.deleteMany({ where }); await prisma.branch.deleteMany({ where });
    await prisma.organization.deleteMany({ where: { id: where.orgId } });
  });
  it("lists only published matching courses, with visible lesson counts and own resume target", async () => {
    const response = await get("/courses"); expect(response.status).toBe(200); expect(response.headers["cache-control"]).toBe("no-store");
    expect(response.body.data.map((c: { title: string }) => c.title).sort()).toEqual(["free", "paid"]);
    const course = response.body.data.find((c: { id: string }) => c.id === String(free));
    expect(course.stats).toEqual({ modules: 1, lessons: 2 });
    expect(course.progress).toEqual({ completedLessons: 1, totalLessons: 2, progressPercent: 50 });
    expect(course.resumeLesson.id).toBe(String(next));
    const peerCourse = (await get("/courses", peer)).body.data.find((c: { id: string }) => c.id === String(free));
    expect(peerCourse.resumeLesson.id).toBe(String(first));
    for (const id of [hidden, foreign, draft, school]) expect((await get(`/courses/${id}`)).status).toBe(404);
  });
  it("exposes published curriculum metadata but no inaccessible lesson content", async () => {
    const response = await get(`/courses/${paid}`); expect(response.status).toBe(200);
    expect(response.body.data.course.modules).toHaveLength(1);
    expect(response.body.data.course.modules[0].lessons.map((l: { accessState: string }) => l.accessState)).toEqual(["PREVIEW", "PAYWALL"]);
    expect(JSON.stringify(response.body)).not.toMatch(/PRIVATE DRAFT|reading content|private-notes/);
    expect((await get(`/lessons/${preview}`)).status).toBe(200);
    expect((await get(`/lessons/${paidLesson}`)).status).toBe(403);
    expect((await get(`/lessons/${draftLesson}`)).status).toBe(404);
    expect((await post(`/lessons/${paidLesson}/progress`, { progressPercent: 100, markCompleted: true })).status).toBe(403);
  });
  it("validates IDs and progress inputs, and completion preserves prior watch time", async () => {
    for (const id of ["invalid", "-1", "0", "1d", "9223372036854775808", "99999999999999999999999"]) {
      expect((await get(`/courses/${id}`)).status).toBe(422);
      expect((await get(`/lessons/${id}`)).status).toBe(422);
    }
    expect((await post(`/lessons/${first}/progress`, { progressPercent: 101 })).status).toBe(422);
    expect((await post(`/lessons/${first}/progress`, { progressPercent: 100, studentId: String(peerStudent) })).status).toBe(422);
    const completed = await post(`/lessons/${first}/progress`, { progressPercent: 100, markCompleted: true });
    expect(completed.status).toBe(200); expect(completed.body.data.watchSeconds).toBe(240);
    const audit = await prisma.auditLog.findFirstOrThrow({
      where: { orgId, actorUserId: learner, action: "LEARNER_LESSON_PROGRESS_UPDATE", entityId: String(first) },
      orderBy: { id: "desc" },
    });
    expect(audit.metadata).toMatchObject({ watchSeconds: 240, completed: true });
    expect((await post(`/lessons/${next}/progress`, { progressPercent: 100, markCompleted: true })).status).toBe(200);
    const course = (await get("/courses")).body.data.find((c: { id: string }) => c.id === String(free));
    expect(course.progress.progressPercent).toBe(100); expect(course.resumeLesson).toBeNull();
    expect((await get(`/courses/${free}`)).body.data.course.progress.completedLessons).toBe(2);
  });
  it("requires valid grants for paid resources and rechecks signed delivery after revocation", async () => {
    expect((await get(`/assets/${asset}/open`)).status).toBe(403);
    await prisma.courseAccessGrant.create({ data: { orgId, courseId: paid, studentId: student, learnerUserId: learner,
      grantedByUserId: teacher, endsAt: new Date("2000-01-01") } });
    expect((await get(`/lessons/${paidLesson}`)).status).toBe(403);
    await prisma.courseAccessGrant.updateMany({ where: { orgId }, data: { endsAt: null } });
    const lesson = await get(`/lessons/${paidLesson}`); expect(lesson.status).toBe(200);
    expect(JSON.stringify(lesson.body)).not.toContain("private-notes.pdf");
    const opened = await get(`/assets/${asset}/open`); expect(opened.status).toBe(200);
    expect(opened.body.data.delivery.downloadUrl).toBeNull();
    const delivery = new URL(opened.body.data.delivery.inlineUrl);
    expect((await api.get(delivery.pathname + delivery.search)).status).toBe(302);
    expect((await get(`/lessons/${paidLesson}`, peer)).status).toBe(403);
    await prisma.courseAccessGrant.deleteMany({ where: { orgId } });
    expect((await api.get(delivery.pathname + delivery.search)).status).toBe(403);
    expect((await get(`/assets/${pendingAsset}/open`)).body.data.delivery.status).toBe("PENDING_SOURCE");
  });
  it("uses signed delivery for embedded players and rejects unsafe provider sources", async () => {
    const embedded = await prisma.mediaAsset.create({ data: { orgId, courseId: free, lessonId: first,
      assetType: "VIDEO", storageProvider: "YOUTUBE", visibility: "FREE",
      title: "Embedded lesson", storageKey: "https://youtu.be/abcdefghijk" } });
    const opened = await get(`/assets/${embedded.id}/open`);
    expect(opened.status).toBe(200);
    expect(opened.body.data.delivery.playerKind).toBe("EMBED");
    expect(opened.body.data.delivery.inlineUrl).not.toContain("youtube");
    const url = new URL(opened.body.data.delivery.inlineUrl);
    const delivered = await api.get(url.pathname + url.search);
    expect(delivered.status).toBe(302);
    expect(delivered.headers["cache-control"]).toBe("no-store");
    expect(delivered.headers["cross-origin-resource-policy"]).toBe("cross-origin");
    expect(delivered.headers.location).toBe("https://www.youtube-nocookie.com/embed/abcdefghijk");
    await prisma.mediaAsset.update({ where: { id: embedded.id }, data: { visibility: "LOCKED" } });
    expect((await api.get(url.pathname + url.search)).status).toBe(403);
    await prisma.mediaAsset.update({ where: { id: embedded.id }, data: {
      visibility: "FREE", storageKey: "https://evil.test/?v=abcdefghijk" } });
    expect((await get(`/assets/${embedded.id}/open`)).body.data.delivery.status).toBe("PENDING_SOURCE");
    expect((await api.get(url.pathname + url.search)).status).toBe(409);
    const detail = (await get(`/lessons/${first}`)).body.data.lesson;
    expect(detail.assets.find((a: { id: string }) => a.id === String(embedded.id)).sourceReady).toBe(false);
  });
  it("authorizes image, PDF and text attachments through the same revocable signed route", async () => {
    for (const [mimeType, playerKind] of [["image/png", "IMAGE"], ["application/pdf", "PDF"], ["text/plain", "TEXT"], ["application/zip", "EXTERNAL"]] as const) {
      const attachment = await prisma.mediaAsset.create({ data: { orgId, courseId: free, lessonId: first,
        assetType: "ATTACHMENT", visibility: "FREE", title: "Lesson attachment", mimeType,
        storageKey: "https://media.example.test/private-resource", downloadAllowed: false } });
      const opened = await get(`/assets/${attachment.id}/open`);
      expect(opened.status).toBe(200);
      expect(opened.body.data.delivery.playerKind).toBe(playerKind);
      expect(opened.body.data.delivery.downloadUrl).toBeNull();
      const url = new URL(opened.body.data.delivery.inlineUrl);
      expect((await api.get(url.pathname + url.search)).status).toBe(302);
      await prisma.mediaAsset.update({ where: { id: attachment.id }, data: { visibility: "LOCKED" } });
      expect((await api.get(url.pathname + url.search)).status).toBe(403);
      expect((await get(`/assets/${attachment.id}/open`)).status).toBe(403);
    }
  });
  it("does not write another linked student's old progress after account relinking", async () => {
    await prisma.student.update({ where: { id: student }, data: { learnerUserId: null } });
    await prisma.student.update({ where: { id: peerStudent }, data: { learnerUserId: learner } });
    expect((await post(`/lessons/${first}/progress`, { progressPercent: 50 })).status).toBe(409);
    const old = await prisma.courseLessonProgress.findUniqueOrThrow({ where: { lessonId_learnerUserId: { lessonId: first, learnerUserId: learner } } });
    expect(old.studentId).toBe(student); expect(old.progressPercent).toBe(100);
    await prisma.student.update({ where: { id: peerStudent }, data: { learnerUserId: peer } });
    await prisma.student.update({ where: { id: student }, data: { learnerUserId: learner } });
  });
  it("rejects unauthorized roles and disabled or unlinked learners", async () => {
    expect((await api.get("/api/learner/courses")).status).toBe(401);
    expect((await api.get("/api/learner/courses").set("Authorization", `Bearer ${token(learner, "PARENT")}`)).status).toBe(403);
    await prisma.user.update({ where: { id: learner }, data: { status: "DISABLED" } });
    expect((await get("/courses")).status).toBe(404);
    await prisma.user.update({ where: { id: learner }, data: { status: "ACTIVE" } });
    await prisma.student.update({ where: { id: student }, data: { learnerUserId: null } });
    expect((await get(`/lessons/${first}`)).status).toBe(404);
  });
});
