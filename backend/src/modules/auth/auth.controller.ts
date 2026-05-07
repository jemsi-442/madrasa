import type { Request, Response } from "express";

import { loginSchema, refreshTokenSchema } from "./auth.schemas";
import { login, logout, logoutAll, refreshSession } from "./auth.service";

export const loginHandler = async (req: Request, res: Response) => {
  const input = loginSchema.parse(req.body);
  const result = await login(input);

  res.status(200).json({
    success: true,
    message: "Login successful",
    data: result,
  });
};

export const refreshHandler = async (req: Request, res: Response) => {
  const input = refreshTokenSchema.parse(req.body);
  const result = await refreshSession(input);

  res.status(200).json({
    success: true,
    message: "Session refreshed successfully",
    data: result,
  });
};

export const logoutHandler = async (req: Request, res: Response) => {
  const input = refreshTokenSchema.parse(req.body);
  await logout(input);

  res.status(200).json({
    success: true,
    message: "Session logged out successfully",
  });
};

export const logoutAllHandler = async (req: Request, res: Response) => {
  await logoutAll(req.authUser!.userId);

  res.status(200).json({
    success: true,
    message: "All sessions logged out successfully",
  });
};

export const meHandler = async (req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    message: "Authenticated user context loaded",
    data: req.authUser,
  });
};
