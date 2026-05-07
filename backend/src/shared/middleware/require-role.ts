import type { NextFunction, Request, Response } from "express";

import type { AuthenticatedUser } from "./authenticate";
import { HttpError } from "../errors/http-error";

export const requireRole =
  (...roles: AuthenticatedUser["role"][]) =>
  (req: Request, _res: Response, next: NextFunction) => {
    if (!req.authUser) {
      return next(new HttpError(401, "Authentication is required"));
    }

    if (!roles.includes(req.authUser.role)) {
      return next(new HttpError(403, "You do not have permission to access this resource"));
    }

    return next();
  };

