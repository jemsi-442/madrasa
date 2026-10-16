import { createHash } from "node:crypto";
import { link, lstat, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { isAbsolute, join } from "node:path";
import { z } from "zod";
import { buildFamilyEmail, type FamilyEmailInput } from "./family-email";

const schema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  EMAIL_MODE: z.enum(["disabled", "capture"]).default("disabled"),
  EMAIL_CAPTURE_DIR: z.string().optional(),
  EMAIL_FROM: z.string().email().default("noreply@example.test"),
  EMAIL_LOGIN_URL: z.string().url().default("https://example.test/#/login"),
}).superRefine((value, ctx) => {
  if (value.EMAIL_MODE !== "capture") return;
  if (value.NODE_ENV === "production") ctx.addIssue({ code: "custom", message: "Email capture is forbidden in production" });
  if (!value.EMAIL_CAPTURE_DIR || !isAbsolute(value.EMAIL_CAPTURE_DIR)) {
    ctx.addIssue({ code: "custom", message: "Email capture requires an absolute private directory" });
  }
  const url = new URL(value.EMAIL_LOGIN_URL);
  if (!url.hostname.endsWith(".test") || url.protocol !== "https:" || url.username || url.password || url.search) {
    ctx.addIssue({ code: "custom", message: "Capture login URL must use HTTPS and a .test host without credentials or query parameters" });
  }
  if (!value.EMAIL_FROM.endsWith(".test")) ctx.addIssue({ code: "custom", message: "Capture sender must use a .test domain" });
});

export function emailSandboxConfig(environment: Record<string, string | undefined>) {
  const result = schema.safeParse(environment);
  // Never echo configuration values (which may have been entered incorrectly as secrets).
  if (!result.success) throw new Error("Invalid email sandbox configuration; see DEVELOPMENT.md");
  return result.data;
}

type SandboxConfig = ReturnType<typeof emailSandboxConfig>;
export type CaptureResult = { status: "DISABLED" } | { status: "CAPTURED"; path: string; duplicate: boolean };

export async function captureFamilyEmail(config: SandboxConfig, key: string,
  input: FamilyEmailInput): Promise<CaptureResult> {
  // Revalidate at the I/O boundary even when callers construct their own config object.
  const settings = emailSandboxConfig(config);
  if (settings.EMAIL_MODE === "disabled") return { status: "DISABLED" };
  if (!/^[a-zA-Z0-9_-]{1,100}$/.test(key)) throw new Error("Invalid capture key");
  const draft = buildFamilyEmail({ ...input, loginUrl: settings.EMAIL_LOGIN_URL });
  if (!draft.to.endsWith(".test")) throw new Error("Capture accepts synthetic .test recipients only");
  const directory = settings.EMAIL_CAPTURE_DIR!;
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const info = await lstat(directory);
  if (!info.isDirectory() || info.isSymbolicLink() || (info.mode & 0o077) !== 0 ||
      (process.getuid && info.uid !== process.getuid())) {
    throw new Error("Capture directory must be private and owned by the current user");
  }
  const payload = JSON.stringify({ status: "CAPTURED", sent: false, from: settings.EMAIL_FROM, ...draft }, null, 2);
  const path = join(directory, `${createHash("sha256").update(key).digest("hex")}.json`);
  const temporary = await mkdtemp(join(directory, ".pending-"));
  try {
    const file = join(temporary, "message.json");
    await writeFile(file, payload, { mode: 0o600, flag: "wx" });
    try {
      // Publish a complete file atomically without overwriting an existing capture.
      await link(file, path);
      return { status: "CAPTURED", path, duplicate: false };
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
      const existing = await lstat(path);
      if (!existing.isFile() || existing.isSymbolicLink() || (existing.mode & 0o077) !== 0 ||
          await readFile(path, "utf8") !== payload) throw new Error("Capture key conflict; use a new key");
      return { status: "CAPTURED", path, duplicate: true };
    }
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}
