// Persistent, loopback-only company demo. Never imports dotenv or uses DATABASE_URL.
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { randomBytes } from "node:crypto";
import { chmod, mkdir, readFile, readdir, stat, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";
import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";
import { loadDemoState, lockDemo, saveDemoState } from './local-demo-storage';

const root = resolve(__dirname, "..");
type DemoCredential = { email: string; role: string; password: string };
const demoEmails = new Set([
  "superadmin@afaq.test",
  "reviewer@afaq.test",
  "it@afaq.test",
  "schooladmin@afaq.test",
  "parent@afaq.test",
]);

function parseDemoCredentials(value: unknown): DemoCredential[] {
  if (!Array.isArray(value) || value.length !== demoEmails.size) {
    throw new Error("Invalid private platform demo credentials file.");
  }
  const rows = value as DemoCredential[];
  if (rows.some(row => !row || !demoEmails.has(row.email) || typeof row.role !== "string" || typeof row.password !== "string" || row.password.length < 12 || row.password.length > 72)
    || new Set(rows.map(row => row.email)).size !== demoEmails.size) {
    throw new Error("Invalid private platform demo credentials file.");
  }
  return rows;
}

async function freePort() {
  const server = createServer();
  await new Promise<void>((ok, fail) => { server.once("error", fail); server.listen(0, "127.0.0.1", ok); });
  const port = (server.address() as { port: number }).port;
  await new Promise<void>((ok) => server.close(() => ok()));
  return port;
}

async function main() {
  if (process.argv[2] !== "--start" || process.env.NODE_ENV === "production") {
    throw new Error("Use --start for a local demo, never production.");
  }
  if (process.argv.length > 3) throw new Error('Persistent demo startup does not rotate passwords or reset data. Use --start only.');
  const directory = join(homedir(), '.afaq', 'platform-demo', 'runtime');
  const unlock = await lockDemo(directory);
  try { await runDemo(directory); } finally { await unlock(); }
}

async function runDemo(directory: string) {
  const probe = createServer();
  await new Promise<void>((ok, fail) => { probe.once('error', fail); probe.listen(4087, '127.0.0.1', ok); });
  await new Promise<void>(ok => probe.close(() => ok()));
  const { state, fresh } = await loadDemoState(directory);
  const credentialDirectory = join(homedir(), ".afaq", "platform-demo");
  const persistentCredentialFile = join(credentialDirectory, "credentials.json");
  await mkdir(credentialDirectory, { recursive: true, mode: 0o700 });
  await chmod(credentialDirectory, 0o700);

  let previousCredentials: DemoCredential[] = [];
  if (fresh) {
    try {
      previousCredentials = parseDemoCredentials(JSON.parse(await readFile(persistentCredentialFile, "utf8")));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      const previousRuns = await readdir(tmpdir(), { withFileTypes: true });
      const previousFiles = await Promise.all(previousRuns
        .filter(entry => entry.isDirectory() && entry.name.startsWith("afaq-local-demo-"))
        .map(async entry => {
          const file = join(tmpdir(), entry.name, "credentials.json");
          try { return { file, mtime: (await stat(file)).mtimeMs }; } catch { return undefined; }
        }));
      const latestFile = previousFiles.filter((entry): entry is { file: string; mtime: number } => entry !== undefined)
        .sort((a, b) => b.mtime - a.mtime)[0];
      if (latestFile) {
        previousCredentials = parseDemoCredentials(JSON.parse(await readFile(latestFile.file, "utf8")));
      }
    }
  }
  const mysqlPort = await freePort();
  let redisPort = await freePort();
  while (redisPort === mysqlPort) redisPort = await freePort();
  const { password, encryptionKey, signingKey } = state;
  const dbUrl = `mysql://root:${password}@127.0.0.1:${mysqlPort}/afaq_local_demo`;
  const redisUrl = `redis://127.0.0.1:${redisPort}`;
  const children: ChildProcess[] = [];
  const childEnv = {
    ...process.env, NODE_ENV: "development", DOTENV_CONFIG_PATH: "/dev/null",
    DATABASE_URL: dbUrl, FRESH_DATABASE_URL: dbUrl, REDIS_URL: redisUrl,
    JWT_SECRET: state.jwtSecret, JWT_REFRESH_SECRET: state.refreshSecret,
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
    try { run("redis-cli", ["-s", redisSocket, "shutdown", "save"]); } catch { /* Not started. */ }
    try { run("mariadb", ["--no-defaults", "--skip-ssl", `--socket=${socket}`, "-uroot", "-e", "SHUTDOWN"], { ...childEnv, MYSQL_PWD: password } as typeof childEnv); } catch { /* Not started. */ }
    for (const child of children) if (child.exitCode === null) child.kill("SIGTERM");
    await Promise.all(children.map(child => child.exitCode !== null || child.signalCode !== null
      ? Promise.resolve() : new Promise<void>(done => child.once('exit', () => done()))));
  };
  try {
    const data = join(directory, "data");
    if (fresh) run("mariadb-install-db", ["--no-defaults", `--datadir=${data}`, "--auth-root-authentication-method=normal", "--skip-test-db"]);
    const initFile = join(directory, "init.sql");
    if (fresh) await writeFile(initFile, `ALTER USER 'root'@'localhost' IDENTIFIED BY '${password}';\nCREATE DATABASE afaq_local_demo;\n`, { mode: 0o600 });
    const mysql = start("mariadbd", ["--no-defaults", `--datadir=${data}`, `--socket=${socket}`, `--pid-file=${join(directory, "mysql.pid")}`, ...(fresh ? [`--init-file=${initFile}`] : []), "--bind-address=127.0.0.1", `--port=${mysqlPort}`, ...(process.getuid?.() === 0 ? ["--user=root"] : [])]);
    await ready(() => run("mariadb", ["--no-defaults", "--skip-ssl", `--socket=${socket}`, "-uroot", "-e", "SELECT 1"], { ...childEnv, MYSQL_PWD: password } as typeof childEnv), mysql);
    const redis = start("redis-server", ["--bind", "127.0.0.1", "--port", `${redisPort}`, "--unixsocket", redisSocket, "--unixsocketperm", "700", "--save", "", "--appendonly", "yes", "--dir", directory]);
    await ready(() => run("redis-cli", ["-s", redisSocket, "ping"]), redis);
    if (fresh) {
    console.log("Installing schema once into the persistent local demo database...");
    run(join(root, "node_modules/.bin/tsx"), ["scripts/install-empty-database.ts", "--confirm-empty-database"]);
    db = new PrismaClient({ datasourceUrl: dbUrl, log: [] });
    const credentials: DemoCredential[] = [];
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
    await writeFile(persistentCredentialFile, JSON.stringify(credentials, null, 2), { mode: 0o600 });
    await chmod(persistentCredentialFile, 0o600);
    await saveDemoState(directory, { ...state, initialized: true });
    }
    const api = start(join(root, "node_modules/.bin/tsx"), ["scripts/local-demo-api.ts"]);
    await ready(() => run("curl", ["--fail", "--silent", "--max-time", "2", "http://127.0.0.1:4087/api/health"]), api);
    console.log(`Demo API: http://127.0.0.1:4087\nPrivate demo credentials: ${persistentCredentialFile}\nPersistent demo data: ${directory}\nFrameworks, assignments and accounts are preserved across restarts. Stop with Ctrl+C.`);
    await new Promise<void>((ok) => {
      process.once("SIGINT", ok);
      process.once("SIGTERM", ok);
    });
  } finally { await cleanup(); }
}
main().then(() => process.exit(0)).catch(() => {
  console.error("Local demo could not start. Check ports, runtime/running.lock and private state.json. Data was NOT reset. If initialization was interrupted, preserve the runtime directory for recovery.");
  process.exit(1);
});
