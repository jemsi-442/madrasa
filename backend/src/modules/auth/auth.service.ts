import crypto from "node:crypto";

import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";

import { env } from "../../config/env";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { LoginInput, RefreshTokenInput } from "./auth.schemas";

const ACCESS_TOKEN_TTL_SECONDS = 15 * 60;
const REFRESH_TOKEN_TTL_SECONDS = 7 * 24 * 60 * 60;

const hashRefreshToken = (refreshToken: string) =>
  crypto.createHash("sha256").update(refreshToken).digest("hex");

type SessionUser = {
  id: bigint;
  fullName: string;
  role: "ADMIN" | "ACCOUNTANT" | "TEACHER" | "PARENT";
  orgId: bigint;
  branchId: bigint | null;
};

type RefreshTokenPayload = {
  sub: string;
  type: "refresh";
  iat: number;
  exp: number;
};

const toUserResponse = (user: SessionUser) => ({
  id: user.id.toString(),
  fullName: user.fullName,
  role: user.role,
  orgId: user.orgId.toString(),
  branchId: user.branchId?.toString() ?? null,
});

const buildAccessToken = (user: SessionUser) =>
  jwt.sign(
    {
      orgId: user.orgId.toString(),
      role: user.role,
      branchId: user.branchId?.toString() ?? null,
      type: "access",
    },
    env.JWT_SECRET,
    {
      subject: user.id.toString(),
      expiresIn: ACCESS_TOKEN_TTL_SECONDS,
    },
  );

const buildRefreshToken = (userId: bigint) =>
  jwt.sign(
    {
      type: "refresh",
    },
    env.JWT_REFRESH_SECRET,
    {
      subject: userId.toString(),
      expiresIn: REFRESH_TOKEN_TTL_SECONDS,
    },
  );

const buildSessionResponse = async (user: SessionUser) => {
  const accessToken = buildAccessToken(user);
  const refreshToken = buildRefreshToken(user.id);
  const refreshTokenHash = hashRefreshToken(refreshToken);

  return {
    accessToken,
    refreshToken,
    refreshTokenHash,
    expiresIn: ACCESS_TOKEN_TTL_SECONDS,
    user: toUserResponse(user),
  };
};

const decodeRefreshToken = (token: string) => {
  let payload: RefreshTokenPayload;

  try {
    payload = jwt.verify(token, env.JWT_REFRESH_SECRET) as RefreshTokenPayload;
  } catch {
    throw new HttpError(401, "Invalid refresh token");
  }

  if (payload.type !== "refresh" || !payload.sub) {
    throw new HttpError(401, "Invalid refresh token");
  }

  return payload;
};

const loadActiveUser = async (userId: bigint) => {
  const user = await prisma.user.findFirst({
    where: {
      id: userId,
      status: "ACTIVE",
    },
    select: {
      id: true,
      fullName: true,
      role: true,
      orgId: true,
      branchId: true,
    },
  });

  if (!user) {
    throw new HttpError(401, "User account is not active");
  }

  return user;
};

const revokeAllUserRefreshTokens = async (userId: bigint) => {
  await prisma.refreshToken.updateMany({
    where: {
      userId,
      revokedAt: null,
    },
    data: {
      revokedAt: new Date(),
    },
  });
};

const findStoredRefreshToken = async (refreshToken: string) => {
  const payload = decodeRefreshToken(refreshToken);
  const userId = BigInt(payload.sub);
  const tokenHash = hashRefreshToken(refreshToken);

  const exactToken = await prisma.refreshToken.findFirst({
    where: {
      userId,
      tokenHash,
      expiresAt: {
        gt: new Date(),
      },
    },
    include: {
      user: {
        select: {
          id: true,
          fullName: true,
          role: true,
          orgId: true,
          branchId: true,
          status: true,
        },
      },
    },
  });

  if (exactToken) {
    if (exactToken.user.status !== "ACTIVE") {
      throw new HttpError(401, "User account is not active");
    }

    return exactToken;
  }

  const legacyTokens = await prisma.refreshToken.findMany({
    where: {
      userId,
      expiresAt: {
        gt: new Date(),
      },
    },
    orderBy: [{ createdAt: "desc" }],
    include: {
      user: {
        select: {
          id: true,
          fullName: true,
          role: true,
          orgId: true,
          branchId: true,
          status: true,
        },
      },
    },
  });

  for (const tokenRecord of legacyTokens) {
    if (!tokenRecord.tokenHash.startsWith("$2")) {
      continue;
    }

    const matches = await bcrypt.compare(refreshToken, tokenRecord.tokenHash);

    if (!matches) continue;

    if (tokenRecord.user.status !== "ACTIVE") {
      throw new HttpError(401, "User account is not active");
    }

    return tokenRecord;
  }

  throw new HttpError(401, "Refresh token was not recognized");
};

const rotateRefreshToken = async (
  storedTokenId: bigint,
  user: SessionUser,
) => {
  const nextSession = await buildSessionResponse(user);
  const now = new Date();

  const createdToken = await prisma.$transaction(async (tx) => {
    const newToken = await tx.refreshToken.create({
      data: {
        orgId: user.orgId,
        userId: user.id,
        tokenHash: nextSession.refreshTokenHash,
        expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_SECONDS * 1000),
      },
    });

    await tx.refreshToken.update({
      where: { id: storedTokenId },
      data: {
        revokedAt: now,
        replacedById: newToken.id,
      },
    });

    await tx.user.update({
      where: { id: user.id },
      data: {
        lastLoginAt: now,
      },
    });

    return newToken;
  });

  return {
    ...nextSession,
    refreshTokenId: createdToken.id,
  };
};

export const login = async (input: LoginInput) => {
  const user = await prisma.user.findFirst({
    where: {
      OR: [{ email: input.login }, { phone: input.login }],
      status: "ACTIVE",
    },
    select: {
      id: true,
      fullName: true,
      email: true,
      phone: true,
      passwordHash: true,
      role: true,
      orgId: true,
      branchId: true,
    },
  });

  if (!user) {
    throw new HttpError(401, "Invalid credentials");
  }

  const passwordMatches = await bcrypt.compare(input.password, user.passwordHash);

  if (!passwordMatches) {
    throw new HttpError(401, "Invalid credentials");
  }

  const session = await buildSessionResponse(user);

  await prisma.$transaction([
    prisma.refreshToken.create({
      data: {
        orgId: user.orgId,
        userId: user.id,
        tokenHash: session.refreshTokenHash,
        expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_SECONDS * 1000),
      },
    }),
    prisma.user.update({
      where: { id: user.id },
      data: {
        lastLoginAt: new Date(),
      },
    }),
  ]);

  return {
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
    expiresIn: session.expiresIn,
    user: session.user,
  };
};

export const refreshSession = async (input: RefreshTokenInput) => {
  const storedToken = await findStoredRefreshToken(input.refreshToken);

  if (storedToken.revokedAt) {
    await revokeAllUserRefreshTokens(storedToken.userId);
    throw new HttpError(401, "Refresh token has already been revoked");
  }

  const user = await loadActiveUser(storedToken.userId);
  const nextSession = await rotateRefreshToken(storedToken.id, user);

  return {
    accessToken: nextSession.accessToken,
    refreshToken: nextSession.refreshToken,
    expiresIn: nextSession.expiresIn,
    user: nextSession.user,
  };
};

export const logout = async (input: RefreshTokenInput) => {
  const storedToken = await findStoredRefreshToken(input.refreshToken);

  if (storedToken.revokedAt) {
    return;
  }

  await prisma.refreshToken.update({
    where: { id: storedToken.id },
    data: {
      revokedAt: new Date(),
    },
  });
};

export const logoutAll = async (userId: string) => {
  await revokeAllUserRefreshTokens(BigInt(userId));
};
