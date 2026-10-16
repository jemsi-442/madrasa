import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { mkdtemp, rm, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";
import { randomBytes } from "node:crypto";

const root = resolve(__dirname, "..");
async function main() {
const directory = await mkdtemp(join(tmpdir(), "afaq-platform-staging-"));
const socket = join(directory, "mysql.sock");
const redisSocket = join(directory, "redis.sock");
const children: ChildProcess[] = [];
const env = { ...process.env, NODE_ENV: "test" };

async function port(): Promise<number> {
  const server = createServer();
  await new Promise<void>((ok, fail) => { server.once("error", fail); server.listen(0, "127.0.0.1", ok); });
  const value = (server.address() as { port: number }).port;
  await new Promise<void>((ok) => server.close(() => ok()));
  return value;
}
function run(command: string, args: string[], customEnv = env) {
  const result = spawnSync(command, args, { cwd: root, env: customEnv, encoding: "utf8", timeout: 180_000 });
  if (result.status !== 0) throw new Error(`${command} failed: ${result.stderr || result.stdout || result.error?.message}`);
  return result.stdout;
}
function start(command: string, args: string[]) {
  const child = spawn(command, args, { cwd: root, env, stdio: "ignore" });
  child.on("error", () => {});
  children.push(child);
  return child;
}
async function ready(check: () => void, child: ChildProcess) {
  for (let attempt = 0; attempt < 100; attempt++) {
    if (child.exitCode !== null) throw new Error("Isolated staging service exited before readiness");
    try { check(); return; } catch { await new Promise((ok) => setTimeout(ok, 200)); }
  }
  throw new Error("Isolated staging service did not become ready");
}

try {
  const mysqlPort = await port();
  let redisPort = await port();
  while (redisPort === mysqlPort) redisPort = await port();
  const data = join(directory, "data");
  run("mariadb-install-db", ["--no-defaults", `--datadir=${data}`, "--auth-root-authentication-method=normal", "--skip-test-db"]);
  const mysql = start("mariadbd", ["--no-defaults", `--datadir=${data}`, `--socket=${socket}`, `--pid-file=${join(directory, "mysql.pid")}`,
    "--bind-address=127.0.0.1", `--port=${mysqlPort}`, ...(process.getuid?.() === 0 ? ["--user=root"] : [])]);
  const sql = (statement: string) => run("mariadb", ["--no-defaults", `--socket=${socket}`, "-u", "root", "-e", statement]);
  await ready(() => { sql("SELECT 1"); }, mysql);
  const name = `afaq_platform_staging_${randomBytes(6).toString("hex")}`;
  sql(`CREATE DATABASE ${name}`);
  const redis = start("redis-server", ["--bind", "127.0.0.1", "--port", `${redisPort}`, "--unixsocket", redisSocket, "--unixsocketperm", "700",
    "--save", "", "--appendonly", "no", "--dir", directory]);
  await ready(() => { run("redis-cli", ["-s", redisSocket, "ping"]); }, redis);
  const testEnv = {
    ...env, DATABASE_URL: `mysql://root@127.0.0.1:${mysqlPort}/${name}`,
    REDIS_URL: `redis://127.0.0.1:${redisPort}`, PLATFORM_STAGING_RUN: "isolated",
    JWT_SECRET: randomBytes(32).toString("hex"), JWT_REFRESH_SECRET: randomBytes(32).toString("hex"),
    PLATFORM_JWT_SECRET: randomBytes(32).toString("hex"),
  };
  const prisma = join(root, "node_modules/.bin/prisma");
  if (process.argv.includes("--upgrade-baseline")) {
    console.log("Testing governance upgrade from a schema-derived pre-platform baseline (not historical replay).");
    const source = await readFile(join(root, "prisma/schema.prisma"), "utf8");
    const baseline = source.replace(/^(?:model|enum) (?:PlatformAccount|PlatformSession|PlatformAuditEvent|TenantApplication|PlatformRole|TenantApplicationStatus|SchoolAdminInvitation) \{[^]*?^\}/gm, "")
      .replace(/^\s*onboardingApplication TenantApplication\?\s*$/m, "")
      .replace(/^\s*onboardingInvitation SchoolAdminInvitation\?\s*$/m, "")
      .replace(/^\s*PENDING_ACTIVATION\s*$/m, "");
    const schemaPath = join(directory, "baseline.prisma");
    const sqlPath = join(directory, "baseline.sql");
    await writeFile(schemaPath, baseline);
    await writeFile(sqlPath, run(prisma, ["migrate", "diff", "--from-empty", "--to-schema-datamodel", schemaPath, "--script"], testEnv));
    run(prisma, ["db", "execute", "--schema", "prisma/schema.prisma", "--file", sqlPath], testEnv);
    for (const migration of ["202610071200_add_platform_governance_foundation", "202610071300_add_platform_sessions", "202610071400_add_platform_mfa", "202610081200_add_pending_school_provisioning", "202610081300_add_school_admin_invitations", "202610091200_password_company_sessions"]) {
      run(prisma, ["db", "execute", "--schema", "prisma/schema.prisma", "--file", join(root, "prisma/migrations", migration, "migration.sql")], testEnv);
    }
  } else if (process.argv.includes("--fresh-install")) {
    console.log("Testing guarded fresh installation using unchanged historical migrations.");
    const installerEnv = { ...testEnv, FRESH_DATABASE_URL: testEnv.DATABASE_URL };
    for (const denied of [
      { args: [], env: installerEnv },
      { args: ["--confirm-empty-database"], env: { ...installerEnv, FRESH_DATABASE_URL: "" } },
    ]) {
      const result = spawnSync(join(root, "node_modules/.bin/tsx"), ["scripts/install-empty-database.ts", ...denied.args], {
        cwd: root, env: denied.env, encoding: "utf8", timeout: 30_000,
      });
      if (result.status === 0 || !result.stderr.includes("required")) throw new Error("Installer explicit-target/confirmation guard failed");
    }
    console.log("Verified: installer requires explicit target and confirmation.");
    console.log(run(join(root, "node_modules/.bin/tsx"), ["scripts/install-empty-database.ts", "--confirm-empty-database"], installerEnv));
    const refused = spawnSync(join(root, "node_modules/.bin/tsx"), ["scripts/install-empty-database.ts", "--confirm-empty-database"], {
      cwd: root, env: installerEnv, encoding: "utf8", timeout: 30_000,
    });
    if (refused.status === 0 || !refused.stderr.includes("not empty")) throw new Error("Installer did not safely reject an already initialized database");
    console.log("Verified: second installation refuses a non-empty database.");
    console.log(run(prisma, ["migrate", "status"], testEnv));
    console.log(run(prisma, ["migrate", "deploy"], testEnv));
  } else {
    console.log("Applying complete migration history to disposable MariaDB...");
    console.log(run(prisma, ["migrate", "deploy"], testEnv));
  }
  const testFile = process.argv.includes("--family-registration")
    ? "tests/family-registration.integration.test.ts"
    : "tests/platform-staging.integration.test.ts";
  // Family rollback tests install a database-wide failure trigger temporarily.
  console.log(run(join(root, "node_modules/.bin/vitest"), ["run", "--no-file-parallelism", testFile,
    ...(process.argv.includes("--family-registration") ? ["tests/family-onboarding.integration.test.ts"] : [])], testEnv));
} finally {
  // Some environments disallow kill(2) even for owned children; use private sockets first.
  try { run("redis-cli", ["-s", redisSocket, "shutdown", "nosave"]); } catch { /* Service may not have started. */ }
  try { run("mariadb", ["--no-defaults", `--socket=${socket}`, "-u", "root", "-e", "SHUTDOWN"]); } catch { /* Service may not have started. */ }
  for (const child of children.reverse()) {
    if (child.exitCode !== null || child.signalCode !== null || !child.pid) continue;
    await new Promise<void>((ok) => {
      const timeout = setTimeout(() => { child.kill("SIGKILL"); ok(); }, 5000);
      child.once("exit", () => { clearTimeout(timeout); ok(); });
      child.kill("SIGTERM");
    });
  }
  await rm(directory, { recursive: true, force: true });
}
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : "Staging run failed");
  process.exitCode = 1;
});
