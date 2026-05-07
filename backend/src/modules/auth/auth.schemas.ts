import { z } from "zod";

export const loginSchema = z.object({
  login: z.string().min(1, "login is required"),
  password: z.string().min(8, "password must be at least 8 characters"),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, "refreshToken is required"),
});

export type LoginInput = z.infer<typeof loginSchema>;
export type RefreshTokenInput = z.infer<typeof refreshTokenSchema>;
