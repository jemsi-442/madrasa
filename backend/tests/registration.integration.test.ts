import crypto from "node:crypto";

import bcrypt from "bcryptjs";
import Redis from "ioredis";
import { describe, expect, it } from "vitest";

import { env } from "../src/config/env";
import { registrationLimitKey, registrationSchema } from "../src/modules/auth/registration";
import { prisma } from "../src/shared/db/prisma";
import { api, loginAsAdmin } from "./helpers/api-client";

describe("public learner registration", () => {
  it("requires matching passwords within bcrypt's byte limit", () => {
    const fields = { fullName: "Course Learner", email: "learner@example.test" };
    expect(registrationSchema.safeParse({ ...fields, password: "Password123!", confirmPassword: "Different123!" }).success).toBe(false);
    const tooLong = "\u00e9".repeat(40);
    expect(registrationSchema.safeParse({ ...fields, password: tooLong, confirmPassword: tooLong }).success).toBe(false);
  });

  it("creates an independent learner, rejects privilege injection and duplicates, and limits attempts", async () => {
    const email = `signup-${crypto.randomUUID()}@example.test`;
    const fields = {
      fullName: "Independent Learner",
      email,
      password: "Learning123!",
      confirmPassword: "Learning123!",
    };
    const redis = new Redis(env.REDIS_URL);
    const limitKeys = ["127.0.0.1", "::ffff:127.0.0.1", "::1"].map(registrationLimitKey);
    await redis.del(...limitKeys);

    try {
      const injected = await api.post("/api/auth/register").send({ ...fields, role: "ADMIN", orgId: "999", studentId: "1" });
      expect(injected.status).toBe(422);
      expect(await prisma.user.count({ where: { email } })).toBe(0);

      const registered = await api.post("/api/auth/register").send({ ...fields, email: `  ${email.toUpperCase()}  ` });
      expect(registered.status).toBe(201);
      expect(registered.body.data.user.role).toBe("LEARNER");
      expect(registered.body.data.user.passwordHash).toBeUndefined();

      const user = await prisma.user.findFirstOrThrow({ where: { email }, include: { learnerProfile: true } });
      expect(await bcrypt.compare(fields.password, user.passwordHash)).toBe(true);
      expect(user.learnerProfile?.programCategory).toBe("COURSE_STUDENT");
      expect(user.learnerProfile?.primaryGuardianId).toBeNull();
      expect(user.learnerProfile?.gender).toBeNull();
      expect(user.learnerProfile?.orgId).toBe(user.orgId);

      const token = registered.body.data.accessToken as string;
      expect((await api.get("/api/learner/me").set("Authorization", `Bearer ${token}`)).status).toBe(200);
      expect((await api.get("/api/learner/courses").set("Authorization", `Bearer ${token}`)).status).toBe(200);
      expect((await api.get("/api/users").set("Authorization", `Bearer ${token}`)).status).toBe(403);
      expect((await api.post("/api/auth/login").send({ login: email, password: fields.password })).status).toBe(200);
      expect((await api.post("/api/auth/register").send(fields)).status).toBe(409);
      expect(await prisma.user.count({ where: { email } })).toBe(1);

      const admin = await loginAsAdmin();
      const student = await api.get(`/api/students/${user.learnerProfile!.id}`).set("Authorization", `Bearer ${admin.body.data.accessToken as string}`);
      expect(student.status).toBe(200);
      expect(student.body.data.primaryGuardian).toBeNull();

      for (const key of limitKeys) await redis.set(key, 20, "EX", 900);
      const limited = await api.post("/api/auth/register").send(fields);
      expect(limited.status).toBe(429);
      expect(limited.headers["retry-after"]).toBe("900");
    } finally {
      await redis.del(...limitKeys);
      redis.disconnect();
      const user = await prisma.user.findFirst({ where: { email }, select: { id: true } });
      if (user) {
        await prisma.refreshToken.deleteMany({ where: { userId: user.id } });
        await prisma.auditLog.deleteMany({ where: { actorUserId: user.id } });
        await prisma.student.deleteMany({ where: { learnerUserId: user.id } });
        await prisma.user.delete({ where: { id: user.id } });
      }
    }
  }, 30_000);
});
