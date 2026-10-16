import { afterEach, describe, expect, it } from "vitest";
import { chmod, lstat, mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { captureFamilyEmail, emailSandboxConfig } from "../src/shared/notifications/email-sandbox";

const folders: string[] = [];
const input = { kind: "FAMILY_APPROVED" as const, recipient: "parent@example.test", fullName: "Demo Parent",
  schoolName: "Demo Madrasa", loginUrl: "https://example.test/#/login", familyLoginId: "DSM/FAM/26/001" };
async function setup() {
  const directory = await mkdtemp(join(tmpdir(), "afaq-mail-test-"));
  folders.push(directory);
  return emailSandboxConfig({ NODE_ENV: "test", EMAIL_MODE: "capture", EMAIL_CAPTURE_DIR: directory });
}
afterEach(async () => { for (const folder of folders.splice(0)) await rm(folder, { recursive: true, force: true }); });

describe("offline email sandbox", () => {
  it("accepts planned production addresses only while delivery remains disabled", async () => {
    const config = emailSandboxConfig({ NODE_ENV: "production", EMAIL_MODE: "disabled",
      EMAIL_FROM: "noreply@afaq.africa", EMAIL_LOGIN_URL: "https://afaq.africa/#/login" });
    expect(await captureFamilyEmail(config, "production", input)).toEqual({ status: "DISABLED" });
    expect(() => emailSandboxConfig({ ...config, EMAIL_MODE: "capture", EMAIL_CAPTURE_DIR: "/tmp/mail" })).toThrow();
  });
  it("is disabled by default", async () => {
    expect(await captureFamilyEmail(emailSandboxConfig({}), "demo", input)).toEqual({ status: "DISABLED" });
  });
  it("refuses production capture and missing or relative directories", () => {
    for (const extra of [{ NODE_ENV: "production", EMAIL_CAPTURE_DIR: "/tmp/email" }, {}, { EMAIL_CAPTURE_DIR: "./email" }]) {
      expect(() => emailSandboxConfig({ EMAIL_MODE: "capture", ...extra })).toThrow();
    }
  });
  it("refuses live senders and URLs", () => {
    for (const extra of [{ EMAIL_FROM: "noreply@afaq.africa" }, { EMAIL_LOGIN_URL: "https://afaq.africa/#/login" }]) {
      expect(() => emailSandboxConfig({ EMAIL_MODE: "capture", EMAIL_CAPTURE_DIR: "/tmp/email", ...extra })).toThrow();
    }
  });
  it("writes private complete previews and deduplicates concurrent calls", async () => {
    const config = await setup();
    const results = await Promise.all([captureFamilyEmail(config, "same", input), captureFamilyEmail(config, "same", input)]);
    expect(results.filter(r => r.status === "CAPTURED" && !r.duplicate)).toHaveLength(1);
    const result = results[0]!;
    expect(result.status).toBe("CAPTURED");
    if (result.status !== "CAPTURED") throw new Error("Missing capture");
    expect((await lstat(result.path)).mode & 0o777).toBe(0o600);
    const body = JSON.parse(await readFile(result.path, "utf8"));
    expect(body.sent).toBe(false);
    expect(body.html).toContain("Afaq");
    expect(await readdir(config.EMAIL_CAPTURE_DIR!)).toHaveLength(1);
  });
  it("rejects key reuse for changed messages without overwriting", async () => {
    const config = await setup();
    await captureFamilyEmail(config, "same", input);
    await expect(captureFamilyEmail(config, "same", { ...input, fullName: "Different Parent" })).rejects.toThrow("conflict");
    expect(await readdir(config.EMAIL_CAPTURE_DIR!)).toHaveLength(1);
  });
  it("rejects real recipients and path traversal keys", async () => {
    const config = await setup();
    await expect(captureFamilyEmail(config, "demo", { ...input, recipient: "parent@afaq.africa" })).rejects.toThrow();
    await expect(captureFamilyEmail(config, "../secret", input)).rejects.toThrow();
    expect(await readdir(config.EMAIL_CAPTURE_DIR!)).toHaveLength(0);
  });
  it("refuses a publicly readable directory", async () => {
    const config = await setup();
    await chmod(config.EMAIL_CAPTURE_DIR!, 0o755);
    await expect(captureFamilyEmail(config, "demo", input)).rejects.toThrow("private");
  });
});
