import { z } from "zod";

// Keep the original password, including spaces; bcrypt supports at most 72 bytes.
export const newSchoolPassword = z.string().min(8, "Use at least 8 characters").max(72)
  .refine(value => Buffer.byteLength(value, "utf8") <= 72, "Password must not exceed 72 UTF-8 bytes");
export const loginPassword = z.string().min(1).max(72)
  .refine(value => Buffer.byteLength(value, "utf8") <= 72, "Password must not exceed 72 UTF-8 bytes");
