// Disposable, loopback-only company demo. Never imports dotenv or uses DATABASE_URL.
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { randomBytes } from "node:crypto";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";
import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";

const root = resolve(__dirname, "..");
async function freePort() {
  const server = createServer();
  await new Promise<void>((ok, fail) => { server.once("error", fail); server.listen(0, "127.0.0.1", ok); });
  const port = (server.address() as { port: number }).port;
  await new Promise<void>((ok) => server.close(() => ok()));
  return port;
}

async function main() {
  if (process.argv[2] !== "--start" || process.env.NODE_ENV === "production") {
    throw new Error("Use --start for a disposable local demo, never production.");
  }
  let previousCredentials: Array<{ email: string; password: string }> = [];
  if (process.argv[3] === "--reuse-demo-passwords") {
    const file = resolve(process.argv[4] ?? "");
    if (!file.startsWith(join(tmpdir(), "afaq-local-demo-")) || !file.endsWith("/credentials.json")) throw new Error("Only a previous private demo credentials file is allowed.");
    previousCredentials = JSON.parse(await readFile(file, "utf8"));
    if (!Array.isArray(previousCredentials) || previousCredentials.some(row => typeof row.email !== 'string' || typeof row.password !== 'string' || row.password.length < 12 || row.password.length > 72)) throw new Error("Invalid demo credentials file.");
  }
  const directory = await mkdtemp(join(tmpdir(), "afaq-local-demo-"));
  const mysqlPort = await freePort();
  let redisPort = await freePort();
  while (redisPort === mysqlPort) redisPort = await freePort();
  const password = randomBytes(32).toString("hex");
  const encryptionKey = randomBytes(32).toString("hex");
  const signingKey = randomBytes(32).toString("hex");
  const dbUrl = `mysql://root:${password}@127.0.0.1:${mysqlPort}/afaq_local_demo`;
  const redisUrl = `redis://127.0.0.1:${redisPort}`;
  const children: ChildProcess[] = [];
  const childEnv = {
    ...process.env, NODE_ENV: "development", DOTENV_CONFIG_PATH: "/dev/null",
    DATABASE_URL: dbUrl, FRESH_DATABASE_URL: dbUrl, REDIS_URL: redisUrl,
    JWT_SECRET: randomBytes(32).toString("hex"), JWT_REFRESH_SECRET: randomBytes(32).toString("hex"),
    PLATFORM_JWT_SECRET: signingKey, PLATFORM_MFA_ENCRYPTION_KEY: encryptionKey,
    APP_BASE_URL: "http://127.0.0.1:4087", WEB_APP_ORIGINS: "http://127.0.0.1:8087",
    PUBLIC_SITE_ORG_CODE: "demo-madrasa", SNIPPE_MOCK_MODE: "true",
    SNIPPE_API_KEY: "", SNIPPE_WEBHOOK_SECRET: "",
  };
  function run(command: string, args: string[], env = childEnv) {
    const result = spawnSync(command, args, { cwd: root, env, encoding: "utf8", timeout: 180_000 });
    if (result.status !== 0) throw new Error(`Local demo command failed: ${command}. No existing database was modified.`);
  }
  function start(command: string, args: string[]) {
    const child = spawn(command, args, { cwd: root, env: childEnv, stdio: "ignore" });
    child.on("error", () => {});
    children.push(child);
    return child;
  }
  async function ready(check: () => void, child: ChildProcess) {
    for (let i = 0; i < 100; i++) {
      if (child.exitCode !== null) throw new Error("Local demo service stopped.");
      try { check(); return; } catch { await new Promise((ok) => setTimeout(ok, 200)); }
    }
    throw new Error("Local demo service not ready.");
  }
  const socket = join(directory, "mysql.sock");
  const redisSocket = join(directory, "redis.sock");
  let db: PrismaClient | undefined;
  const cleanup = async () => {
    await db?.$disconnect();
    try { run("redis-cli", ["-s", redisSocket, "shutdown", "nosave"]); } catch { /* Not started. */ }
    try { run("mariadb", ["--no-defaults", `--socket=${socket}`, "-uroot", "-e", "SHUTDOWN"], { ...childEnv, MYSQL_PWD: password } as typeof childEnv); } catch { /* Not started. */ }
    for (const child of children) if (child.exitCode === null) child.kill("SIGTERM");
  };
  try {
    const data = join(directory, "data");
    run("mariadb-install-db", ["--no-defaults", `--datadir=${data}`, "--auth-root-authentication-method=normal", "--skip-test-db"]);
    const initFile = join(directory, "init.sql");
    await writeFile(initFile, `ALTER USER 'root'@'localhost' IDENTIFIED BY '${password}';\nCREATE DATABASE afaq_local_demo;\n`, { mode: 0o600 });
    const mysql = start("mariadbd", ["--no-defaults", `--datadir=${data}`, `--socket=${socket}`, `--pid-file=${join(directory, "mysql.pid")}`, `--init-file=${initFile}`, "--bind-address=127.0.0.1", `--port=${mysqlPort}`, ...(process.getuid?.() === 0 ? ["--user=root"] : [])]);
    await ready(() => run("mariadb", ["--no-defaults", `--socket=${socket}`, "-uroot", "-e", "SELECT 1"], { ...childEnv, MYSQL_PWD: password } as typeof childEnv), mysql);
    const redis = start("redis-server", ["--bind", "127.0.0.1", "--port", `${redisPort}`, "--unixsocket", redisSocket, "--unixsocketperm", "700", "--save", "", "--appendonly", "no", "--dir", directory]);
    await ready(() => run("redis-cli", ["-s", redisSocket, "ping"]), redis);
    console.log("Installing schema into a new isolated demo database...");
    run(join(root, "node_modules/.bin/tsx"), ["scripts/install-empty-database.ts", "--confirm-empty-database"]);
    db = new PrismaClient({ datasourceUrl: dbUrl, log: [] });
    const credentials = [];
    for (const [name, email, role] of [
      ["Demo Super Admin", "superadmin@afaq.test", "SUPER_ADMIN"],
      ["Demo Office Reviewer", "reviewer@afaq.test", "SUPER_ADMIN"],
      ["Demo IT Officer", "it@afaq.test", "IT_SECURITY"],
    ] as const) {
      const id = randomBytes(15).toString("hex");
      const accountPassword = previousCredentials.find(row => row.email === email)?.password ?? `Afaq!${randomBytes(15).toString("base64url")}`;
      await db.$transaction(async (tx) => {
        await tx.platformAccount.create({ data: { id, email, fullName: name, role, status: "ACTIVE", passwordHash: await bcrypt.hash(accountPassword, 12) } });
        await tx.platformAuditEvent.create({ data: { actorId: id, actorRole: role, action: "platform.account.demo-created", entityType: "PlatformAccount", entityId: id } });
      });
      credentials.push({ email, role, password: accountPassword });
    }
    const org = await db.organization.create({ data: { name: "Afaq Demo Madrasa", code: "demo-madrasa" } });
    const branch = await db.branch.create({ data: { orgId: org.id, name: "Demo Campus", isMain: true } });
    for (const [fullName, email, role] of [
      ["Demo School Admin", "schooladmin@afaq.test", "ADMIN"],
      ["Demo Family Parent", "parent@afaq.test", "PARENT"],
    ] as const) {
      const accountPassword = previousCredentials.find(row => row.email === email)?.password ?? `Afaq!${randomBytes(15).toString("base64url")}`;
      const user = await db.user.create({ data: {
        orgId: org.id, branchId: branch.id, fullName, email, role,
        passwordHash: await bcrypt.hash(accountPassword, 12),
      } });
      if (role === "PARENT") {
        const guardian = await db.guardian.create({ data: { orgId: org.id, userId: user.id, fullName, email, phone: "255700000100" } });
        for (const [index, name] of ["Ahmad Demo", "Ayesha Demo"].entries()) {
          const student = await db.student.create({ data: {
            orgId: org.id, branchId: branch.id, fullName: name,
            admissionNo: `DEMO-CHILD-${index + 1}`, primaryGuardianId: guardian.id,
          } });
          await db.studentGuardian.create({ data: { orgId: org.id, studentId: student.id, guardianId: guardian.id, isPrimary: true } });
        }
      }
      credentials.push({ email, role, password: accountPassword });
    }
    const pendingGuardian = await db.guardian.create({ data: {
      orgId: org.id, fullName: "Salma Demo", phone: "255700000200",
    } });
    const pendingChild = await db.student.create({ data: {
      orgId: org.id, branchId: branch.id, fullName: "Yusuf Demo", admissionNo: "DEMO-PENDING-CHILD",
      primaryGuardianId: pendingGuardian.id,
    } });
    await db.studentGuardian.create({ data: { orgId: org.id, studentId: pendingChild.id, guardianId: pendingGuardian.id, isPrimary: true } });
    const credentialFile = join(directory, "credentials.json");
    await writeFile(credentialFile, JSON.stringify(credentials, null, 2), { mode: 0o600 });
    const api = start(join(root, "node_modules/.bin/tsx"), ["scripts/local-demo-api.ts"]);
    await ready(() => run("curl", ["--fail", "--silent", "--max-time", "2", "http://127.0.0.1:4087/api/health"]), api);
    console.log(`Demo API: http://127.0.0.1:4087\nPrivate demo credentials: ${credentialFile}\nLocal-only disposable accounts; no school data was copied. Stop with Ctrl+C.`);
    await new Promise<void>((ok) => {
      process.once("SIGINT", ok);
      process.once("SIGTERM", ok);
    });
  } finally { await cleanup(); }
}
main().then(() => process.exit(0)).catch(() => {
  console.error("Local demo stopped or could not start. Check local ports and service availability. Existing databases and credentials were not modified.");
  process.exit(1);
});
