import type { NextFunction, Request, Response } from "express";

import { HttpError } from "../errors/http-error";

export const requireTenantContext = (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  if (!req.authUser?.orgId) {
    return next(new HttpError(401, "Tenant context is missing from the authenticated user"));
  }

  return next();
};

