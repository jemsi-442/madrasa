import express from "express";
import jwt from "jsonwebtoken";
import request from "supertest";
import { beforeEach, expect, it, vi } from "vitest";
import { teacherWorkspaceRouter } from "../src/modules/teacher-workspace/teacher.routes";
import { QuranContentClient } from "../src/modules/teacher-workspace/quran-content";
import { errorHandler } from "../src/shared/middleware/error-handler";
import { learnerRouter } from "../src/modules/learner/learner.routes";

const db = vi.hoisted(() => ({ user: { findFirst: vi.fn() }, student: { findFirst: vi.fn() } }));
vi.mock("../src/shared/db/prisma", () => ({ prisma: db }));
vi.mock("../src/config/env", () => ({
  env: { JWT_SECRET: "synthetic-school-key", QF_ENABLED: false, QF_ENV: "prelive",
    QF_CLIENT_ID: "", QF_CLIENT_SECRET: "" },
}));
const app = express();
app.use("/api/teacher-workspace", teacherWorkspaceRouter);
app.use("/api/learner", learnerRouter);
app.use(errorHandler);
const paths = [
  "/api/teacher-workspace/quran/content/chapters",
  "/api/teacher-workspace/quran/content/chapters/1/verses?page=1&per_page=1",
];
function token(role = "TEACHER", ver = 0, type = "access") {
  return jwt.sign({ sub: "9", orgId: "8", role, ver, type }, "synthetic-school-key",
    { expiresIn: "5m" });
}
const chapters = vi.spyOn(QuranContentClient.prototype, "chapters");
const verses = vi.spyOn(QuranContentClient.prototype, "verses");
beforeEach(() => {
  vi.clearAllMocks();
  db.user.findFirst.mockResolvedValue({ authVersion: 0, branchId: null });
  db.student.findFirst.mockResolvedValue({ id: 1n, learnerUser: { id: 9n } });
  chapters.mockResolvedValue({
    provider: "Quran Foundation", environment: "prelive", limitedContent: true,
    chapters: [],
  });
  verses.mockResolvedValue({
    provider: "Quran Foundation", environment: "prelive", limitedContent: true,
    chapterId: 1, script: "text_uthmani", verses: [],
    pagination: { current_page: 1, per_page: 1, next_page: null,
      total_pages: 1, total_records: 1 },
  });
});
function providerNotCalled() {
  expect(chapters).not.toHaveBeenCalled();
  expect(verses).not.toHaveBeenCalled();
}
it("rejects anonymous requests before any database or provider access", async () => {
  for (const path of paths) expect((await request(app).get(path)).status).toBe(401);
  expect(db.user.findFirst).not.toHaveBeenCalled();
  providerNotCalled();
});
it.each(["ADMIN", "ACCOUNTANT", "PARENT", "LEARNER"])(
  "denies %s access to teacher Quran content", async role => {
    for (const path of paths) {
      expect((await request(app).get(path)
        .set("Authorization", `Bearer ${token(role)}`)).status).toBe(403);
    }
    providerNotCalled();
  });
it("rejects platform token types", async () => {
  for (const path of paths) {
    expect((await request(app).get(path)
      .set("Authorization", `Bearer ${token("SUPER_ADMIN", 0, "platform_access")}`)).status).toBe(401);
  }
  providerNotCalled();
});
it("blocks unavailable school accounts and checks the tenant and school status", async () => {
  db.user.findFirst.mockResolvedValue(null);
  for (const path of paths) {
    expect((await request(app).get(path)
      .set("Authorization", `Bearer ${token()}`)).status).toBe(403);
  }
  expect(db.user.findFirst).toHaveBeenCalledWith(expect.objectContaining({
    where: { id: 9n, orgId: 8n, role: "TEACHER", status: "ACTIVE",
      organization: { status: { in: ["ACTIVE", "TRIAL"] } } },
  }));
  providerNotCalled();
});
it("rejects revoked account token versions", async () => {
  for (const path of paths) {
    expect((await request(app).get(path)
      .set("Authorization", `Bearer ${token("TEACHER", 1)}`)).status).toBe(401);
  }
  providerNotCalled();
});
it("serves an active teacher without forwarding tenant or learner information", async () => {
  for (const path of paths) {
    const response = await request(app).get(path).set("Authorization", `Bearer ${token()}`);
    expect(response.status).toBe(200);
    expect(response.headers["cache-control"]).toBe("no-store");
  }
  expect(chapters).toHaveBeenCalledWith();
  expect(verses).toHaveBeenCalledWith("1", { page: "1", per_page: "1" });
});

const learnerPaths = paths.map(path => path.replace('/api/teacher-workspace', '/api/learner/workspace'));
it("allows a linked independent learner to read Quran without a class or a progress write", async () => {
  for (const path of learnerPaths) {
    const result = await request(app).get(path).set('Authorization', `Bearer ${token('LEARNER')}`);
    expect(result.status).toBe(200);
    expect(result.headers['cache-control']).toBe('no-store');
  }
  expect(db.student.findFirst).toHaveBeenCalledWith(expect.objectContaining({
    where: expect.objectContaining({ orgId: 8n, learnerUserId: 9n, status: 'ACTIVE' }),
  }));
  expect(chapters).toHaveBeenCalledWith();
  expect(verses).toHaveBeenCalledWith('1', { page: '1', per_page: '1' });
});
it("denies anonymous and non-learner access to learner Quran content", async () => {
  for (const path of learnerPaths) {
    expect((await request(app).get(path)).status).toBe(401);
    for (const role of ['TEACHER', 'ADMIN', 'PARENT', 'ACCOUNTANT']) {
      expect((await request(app).get(path).set('Authorization', `Bearer ${token(role)}`)).status).toBe(403);
    }
  }
  providerNotCalled();
});
it("blocks unlinked learners and inactive accounts before provider access", async () => {
  db.student.findFirst.mockResolvedValue(null);
  for (const path of learnerPaths) {
    expect((await request(app).get(path).set('Authorization', `Bearer ${token('LEARNER')}`)).status).toBe(404);
  }
  db.user.findFirst.mockResolvedValue(null);
  for (const path of learnerPaths) {
    expect((await request(app).get(path).set('Authorization', `Bearer ${token('LEARNER')}`)).status).toBe(403);
  }
  providerNotCalled();
});
