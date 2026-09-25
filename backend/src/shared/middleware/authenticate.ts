import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";

import { env } from "../../config/env";
import { HttpError } from "../errors/http-error";

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

export const authenticate = (req: Request, _res: Response, next: NextFunction) => {
  try {
    const token = extractBearerToken(req.headers.authorization);
    const payload = jwt.verify(token, env.JWT_SECRET) as AccessTokenPayload;

    if (payload.type !== "access") {
      throw new HttpError(401, "Invalid access token");
    }

    req.authUser = {
      userId: payload.sub,
      orgId: payload.orgId,
      role: payload.role,
      branchId: payload.branchId ?? null,
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
