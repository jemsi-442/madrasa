import { spawnSync } from "node:child_process";
import { resolve, join } from "node:path";
import { PrismaClient } from "@prisma/client";

async function main() {
  const url = process.env.FRESH_DATABASE_URL;
  if (!url || !process.argv.includes("--confirm-empty-database")) {
    throw new Error("Explicit FRESH_DATABASE_URL and --confirm-empty-database are required; DATABASE_URL is never used as fallback.");
  }
  const parsed = new URL(url);
  if (parsed.protocol !== "mysql:" || parsed.pathname.length < 2) throw new Error("Specify a MySQL database URL with a database name.");
  const root = resolve(__dirname, "..");
  const db = new PrismaClient({ datasourceUrl: url, log: [] });
  const run = (args: string[]) => {
    const result = spawnSync(join(root, "node_modules/.bin/prisma"), args, {
      cwd: root, env: { ...process.env, DATABASE_URL: url }, encoding: "utf8", timeout: 180_000,
    });
    if (result.status !== 0) {
      // Do not include captured CLI output: connection strings may contain credentials.
      throw new Error(`Prisma ${args.slice(0, 2).join(" ")} failed. Stop and inspect the target before retrying; no automatic repair was attempted.`);
    }
  };
  try {
    await db.$transaction(async (tx) => {
      const lock = await tx.$queryRaw<Array<{ acquired: bigint | number | null }>>`
        SELECT GET_LOCK(CONCAT('afaq-fresh:', LEFT(SHA2(DATABASE(), 256), 32)), 0) AS acquired`;
      if (Number(lock[0]?.acquired) !== 1) throw new Error("Another fresh installer is using this database.");
      try {
        const tables = await tx.$queryRaw<Array<{ count: bigint }>>`
          SELECT COUNT(*) AS count FROM information_schema.tables WHERE table_schema = DATABASE()`;
        if (Number(tables[0]?.count) !== 0) throw new Error("Refusing installation: target database is not empty. No changes made.");
        const routines = await tx.$queryRaw<Array<{ count: bigint }>>`
          SELECT COUNT(*) AS count FROM information_schema.routines WHERE routine_schema = DATABASE()`;
        if (Number(routines[0]?.count) !== 0) throw new Error("Refusing installation: target has existing routines.");
        for (const migration of ["202605071445_init_tenant_and_auth", "202605071620_add_student_domain"]) {
          console.log(`Applying prerequisite ${migration}`);
          run(["db", "execute", "--schema", "prisma/schema.prisma", "--file", join(root, "prisma/migrations", migration, "migration.sql")]);
          // Record only SQL that actually succeeded, using the unchanged migration checksum.
          run(["migrate", "resolve", "--applied", migration]);
        }
        console.log("Applying remaining historical migrations...");
        run(["migrate", "deploy"]);
      } finally {
        await tx.$queryRaw`SELECT RELEASE_LOCK(CONCAT('afaq-fresh:', LEFT(SHA2(DATABASE(), 256), 32)))`;
      }
    }, { timeout: 900_000, maxWait: 5000 });
    console.log("Fresh installation completed. Existing migration files were not rewritten.");
  } finally { await db.$disconnect(); }
}

main().catch((error: unknown) => {
  // Known operator messages only; raw database errors can include connection details.
  const message = error instanceof Error && !("code" in error) ? error.message : "Fresh installation failed. Inspect the target database before retrying.";
  console.error(message);
  process.exitCode = 1;
});
