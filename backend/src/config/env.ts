import "dotenv/config";

import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  APP_NAME: z.string().min(1).default("mms-backend"),
  PORT: z.coerce.number().int().min(1).max(65535).default(4000),
  TZ: z.string().min(1).default("Africa/Dar_es_Salaam"),
  APP_BASE_URL: z.string().url().default("http://127.0.0.1:4000"),
  PUBLIC_SITE_ORG_CODE: z.string().min(1).default("demo-madrasa"),
  DATABASE_URL: z.string().min(1, "DATABASE_URL is required"),
  REDIS_URL: z.string().min(1, "REDIS_URL is required"),
  JWT_SECRET: z.string().min(1, "JWT_SECRET is required"),
  JWT_REFRESH_SECRET: z.string().min(1, "JWT_REFRESH_SECRET is required"),
  SNIPPE_BASE_URL: z.string().url().default("https://api.snippe.sh"),
  SNIPPE_API_KEY: z.string().optional(),
  SNIPPE_WEBHOOK_SECRET: z.string().optional(),
  SNIPPE_MOCK_MODE: z
    .enum(["true", "false"])
    .transform((value) => value === "true")
    .default("false"),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error("Invalid environment configuration", parsed.error.flatten().fieldErrors);
  throw new Error("Environment validation failed");
}

export const env = parsed.data;
