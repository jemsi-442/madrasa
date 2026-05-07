import type { NextFunction, Request, Response } from "express";
import { Prisma } from "@prisma/client";
import { ZodError } from "zod";

import { HttpError } from "../errors/http-error";

export const errorHandler = (
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
) => {
  if (err instanceof ZodError) {
    return res.status(422).json({
      success: false,
      message: "Validation failed",
      errors: err.flatten().fieldErrors,
    });
  }

  if (err instanceof HttpError) {
    return res.status(err.statusCode).json({
      success: false,
      message: err.message,
      errors: err.details ?? null,
    });
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === "P2002") {
      return res.status(409).json({
        success: false,
        message: "A record with the same unique value already exists",
      });
    }
  }

  if (err instanceof SyntaxError && "status" in err && err.status === 400) {
    return res.status(400).json({
      success: false,
      message: "Invalid JSON payload",
    });
  }

  console.error("Unhandled error", err);

  return res.status(500).json({
    success: false,
    message: "Internal server error",
  });
};
