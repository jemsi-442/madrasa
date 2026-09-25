import crypto from "node:crypto";

import bcrypt from "bcryptjs";
import type { NextFunction, Request, Response } from "express";
import Redis from "ioredis";
import { z } from "zod";

import { env } from "../../config/env";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import { buildSessionResponse } from "./auth.service";

const registrationPassword = z.string().min(8).max(72).refine(
  (value) => Buffer.byteLength(value, "utf8") <= 72,
  "Password is too long",
);

export const registrationSchema = z.object({
  fullName: z.string().trim().min(2).max(150),
  email: z.string().trim().toLowerCase().email().max(150),
  password: registrationPassword,
  confirmPassword: registrationPassword,
}).strict().refine((input) => input.password === input.confirmPassword, {
  path: ["confirmPassword"],
  message: "Passwords do not match",
});

export const registrationLimitKey = (ip: string) =>
  `auth:registration:${crypto.createHmac("sha256", env.JWT_SECRET).update(ip).digest("hex")}`;

export const limitRegistration = async (req: Request, res: Response, next: NextFunction) => {
  const redis = new Redis(env.REDIS_URL, {
    lazyConnect: true,
    connectTimeout: 2000,
    maxRetriesPerRequest: 0,
    retryStrategy: () => null,
    enableOfflineQueue: false,
  });
  redis.on("error", () => {});

  try {
    await redis.connect();
    const attempts = Number(await redis.eval(
      "local count = redis.call('INCR', KEYS[1]); if count == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end; return count",
      1,
      registrationLimitKey(req.ip ?? req.socket.remoteAddress ?? "unknown"),
      900,
    ));
    if (attempts > 20) {
      res.setHeader("Retry-After", "900");
      throw new HttpError(429, "Please wait before trying to register again");
    }
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(503, "Registration is temporarily unavailable");
  } finally {
    redis.disconnect();
  }
  next();
};

export const registerLearnerHandler = async (req: Request, res: Response) => {
  const input = registrationSchema.parse(req.body);
  const organization = await prisma.organization.findFirst({
    where: { code: env.PUBLIC_SITE_ORG_CODE, status: "ACTIVE" },
    select: {
      id: true,
      branches: { orderBy: [{ isMain: "desc" }, { id: "asc" }], take: 1, select: { id: true } },
    },
  });
  const branch = organization?.branches[0];
  if (!organization || !branch) {
    throw new HttpError(503, "Registration is temporarily unavailable");
  }

  // Login currently accepts an email without an organization selector.
  const existing = await prisma.user.findFirst({ where: { email: input.email }, select: { id: true } });
  if (existing) throw new HttpError(409, "An account already uses this email address");

  const passwordHash = await bcrypt.hash(input.password, 12);
  const session = await prisma.$transaction(async (tx) => {
    const user = await tx.user.create({
      data: {
        orgId: organization.id,
        branchId: branch.id,
        fullName: input.fullName,
        email: input.email,
        passwordHash,
        role: "LEARNER",
        status: "ACTIVE",
        lastLoginAt: new Date(),
      },
    });
    await tx.student.create({
      data: {
        orgId: organization.id,
        branchId: branch.id,
        admissionNo: `LRN-${crypto.randomUUID().toUpperCase()}`,
        fullName: input.fullName,
        programCategory: "COURSE_STUDENT",
        learnerUserId: user.id,
        status: "ACTIVE",
        joinedOn: new Date(),
      },
    });
    const result = await buildSessionResponse(user);
    await tx.refreshToken.create({
      data: {
        orgId: organization.id,
        userId: user.id,
        tokenHash: result.refreshTokenHash,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });
    await tx.auditLog.create({
      data: {
        orgId: organization.id,
        actorUserId: user.id,
        action: "auth.learner_registered",
        entityType: "user",
        entityId: user.id.toString(),
        ipAddress: req.ip ?? null,
      },
    });
    return {
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      expiresIn: result.expiresIn,
      user: result.user,
    };
  });

  res.status(201).json({ success: true, message: "Account created", data: session });
};
