import { z } from "zod";
import { loginPassword } from "./password.schemas";

export const loginSchema = z.object({
  login: z.string().min(1, "login is required"),
  password: loginPassword,
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, "refreshToken is required"),
});

export type LoginInput = z.infer<typeof loginSchema>;
export type RefreshTokenInput = z.infer<typeof refreshTokenSchema>;
