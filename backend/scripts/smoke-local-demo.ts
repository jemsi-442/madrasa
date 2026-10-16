import { lstat, readFile, realpath } from "node:fs/promises";
import { resolve } from "node:path";
import { tmpdir } from "node:os";
import { z } from "zod";

const rows = z.array(z.object({ email: z.string().email(), password: z.string().min(12).max(72),
  role: z.enum(["SUPER_ADMIN", "IT_SECURITY", "ADMIN", "PARENT"]) }).strict()).length(5);
const expected = new Map([
  ["superadmin@afaq.test", "SUPER_ADMIN"], ["reviewer@afaq.test", "SUPER_ADMIN"],
  ["it@afaq.test", "IT_SECURITY"], ["schooladmin@afaq.test", "ADMIN"], ["parent@afaq.test", "PARENT"],
]);
const base = "http://127.0.0.1:4087/api";

async function main() {
  if (process.argv.length !== 4 || process.argv[2] !== "--confirm-local-demo") throw new Error("usage");
  const file = resolve(process.argv[3]!);
  if (!file.startsWith(`${tmpdir()}/afaq-local-demo-`) || !file.endsWith("/credentials.json") || await realpath(file) !== file) throw new Error("path");
  const info = await lstat(file);
  if (!info.isFile() || (info.mode & 0o077) !== 0 || (process.getuid && info.uid !== process.getuid())) throw new Error("permissions");
  const accounts = rows.parse(JSON.parse(await readFile(file, "utf8")));
  if (new Set(accounts.map(a => a.email)).size !== 5 || accounts.some(a => expected.get(a.email) !== a.role)) throw new Error("accounts");

  async function request(path: string, options: RequestInit = {}) {
    return fetch(`${base}${path}`, { ...options, redirect: "error", signal: AbortSignal.timeout(10_000) });
  }
  if (!(await request("/health")).ok) throw new Error("health");
  console.log("PASS: local demo health");
  for (const account of accounts) {
    const response = await request("/auth/login", { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ login: account.email, password: account.password }) });
    if (!response.ok) throw new Error("login");
    const session = z.object({ data: z.object({ accessToken: z.string().min(1),
      refreshToken: z.string().min(1).optional(), scope: z.string().optional(),
      user: z.object({ role: z.string() }),
    }) }).parse(await response.json()).data;
    const token = z.string().min(1).parse(session.accessToken);
    const platform = account.role === "SUPER_ADMIN" || account.role === "IT_SECURITY";
    try {
      if (session.user?.role !== account.role || (session.scope === "platform") !== platform) throw new Error("scope");
      const path = platform ? "/platform/me" : account.role === "ADMIN" ? "/users/family-applications" : "/parent-portal/students";
      if (!(await request(path, { headers: { Authorization: `Bearer ${token}` } })).ok) throw new Error("workspace");
      const deniedPath = platform ? "/users/family-applications" : "/platform/me";
      const denied = await request(deniedPath, { headers: { Authorization: `Bearer ${token}` } });
      if (![401, 403].includes(denied.status)) throw new Error("boundary");
      console.log(`PASS: ${account.role} login, workspace and cross-scope denial`);
    } finally {
      const logout = await request(platform ? "/platform/logout" : "/auth/logout", {
        method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        ...(platform ? {} : { body: JSON.stringify({ refreshToken: session.refreshToken }) }),
      });
      if (!logout.ok) throw new Error("logout");
    }
  }
  console.log("PASS: all five synthetic accounts; test sessions logged out. No passwords, school records or schema changed.");
}

main().catch(() => {
  console.error("Demo smoke check failed. Use --confirm-local-demo with its private credentials file and the running isolated demo on 4087. Credentials and response bodies are redacted.");
  process.exitCode = 1;
});
