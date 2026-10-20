import { execFile } from "node:child_process";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";
import { expect, it } from "vitest";

const execute = promisify(execFile);
const script = resolve("scripts/check-quran.ts");
async function check(contents: string, extra: string[] = []) {
  const folder = await mkdtemp(join(tmpdir(), "afaq-quran-check-"));
  const file = join(folder, "private.env");
  try {
    await writeFile(file, contents, { mode: 0o600 });
    try {
      const result = await execute(process.execPath,
        ["--import", "tsx", script, "--env-file", file, ...extra],
        { timeout: 10000 });
      return { code: 0, output: result.stdout + result.stderr };
    } catch (error) {
      const result = error as { code: number; stdout: string; stderr: string };
      return { code: result.code, output: result.stdout + result.stderr };
    }
  } finally {
    await rm(folder, { recursive: true, force: true });
  }
}
const valid = "QF_ENABLED=true\nQF_CLIENT_ID=synthetic-client\nQF_CLIENT_SECRET=synthetic-secret\n";

it("checks a private file without contacting the provider or exposing secrets", async () => {
  const result = await check(valid);
  expect(result.code).toBe(0);
  expect(result.output).toContain("No connection made");
  expect(result.output).toContain("prelive");
  expect(result.output).not.toMatch(/synthetic-client|synthetic-secret/);
});
it.each([
  "", valid.replace("true", "false"), valid + "QF_ENV=unknown\n",
  valid.replace("QF_CLIENT_SECRET=synthetic-secret", ""),
])("fails safely on invalid settings", async contents => {
  const result = await check(contents);
  expect(result.code).toBe(2);
  expect(result.output).toContain("Values redacted");
  expect(result.output).not.toMatch(/synthetic-client|synthetic-secret/);
});
it("rejects unrecognised options rather than connecting", async () => {
  const result = await check(valid, ["--unexpected"]);
  expect(result.code).toBe(2);
  expect(result.output).toContain("Usage:");
});
