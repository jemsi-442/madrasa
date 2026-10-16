import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";

import { env } from "../../config/env";
import { HttpError } from "../errors/http-error";
import { prisma } from "../db/prisma";

export type AuthenticatedUser = {
  userId: string;
  orgId: string;
  role: "ADMIN" | "ACCOUNTANT" | "TEACHER" | "PARENT" | "LEARNER";
  branchId?: string | null;
};

declare module "express-serve-static-core" {
  interface Request {
    authUser?: AuthenticatedUser;
  }
}

type AccessTokenPayload = {
  ver?: number;
  sub: string;
  orgId: string;
  role: AuthenticatedUser["role"];
  branchId?: string | null;
  type: "access";
};

const extractBearerToken = (authorizationHeader?: string) => {
  if (!authorizationHeader) {
    throw new HttpError(401, "Authorization header is required");
  }

  const [scheme, token] = authorizationHeader.split(" ");

  if (scheme !== "Bearer" || !token) {
    throw new HttpError(401, "Authorization header must use Bearer token format");
  }

  return token;
};

export const authenticate = async (req: Request, _res: Response, next: NextFunction) => {
  try {
    const token = extractBearerToken(req.headers.authorization);
    const payload = jwt.verify(token, env.JWT_SECRET) as AccessTokenPayload;

    if (payload.type !== "access") {
      throw new HttpError(401, "Invalid access token");
    }
    if (!/^\d+$/.test(payload.sub) || !/^\d+$/.test(payload.orgId)) throw new HttpError(401, "Invalid access token");
    const account = await prisma.user.findFirst({ where: { id: BigInt(payload.sub), orgId: BigInt(payload.orgId),
      role: payload.role, status: "ACTIVE", organization: { status: { in: ["ACTIVE", "TRIAL"] } } },
      select: { authVersion: true, branchId: true } });
    if (!account) throw new HttpError(403, "This account is no longer available");
    if (account.authVersion !== (payload.ver ?? 0)) throw new HttpError(401, "Please sign in again");

    req.authUser = {
      userId: payload.sub,
      orgId: payload.orgId,
      role: payload.role,
      branchId: account.branchId?.toString() ?? null,
    };

    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      return next(new HttpError(401, "Access token expired"));
    }

    if (error instanceof jwt.JsonWebTokenError) {
      return next(new HttpError(401, "Invalid access token"));
    }

    next(error);
  }
};
