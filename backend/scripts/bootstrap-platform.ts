import "dotenv/config";
import { createInterface } from "node:readline/promises";
import { Writable } from "node:stream";
import { PrismaClient } from "@prisma/client";
import { bootstrapPasswordReviewer } from "../src/modules/platform/platform.bootstrap";

async function main() {
  if (!process.stdin.isTTY || !process.stdout.isTTY || process.env.ALLOW_PLATFORM_BOOTSTRAP !== "true") {
    throw new Error("Use a private interactive terminal with ALLOW_PLATFORM_BOOTSTRAP=true");
  }
  const signingKey = process.env.PLATFORM_JWT_SECRET ?? "";
  const schoolKeys = [process.env.JWT_SECRET, process.env.JWT_REFRESH_SECRET];
  if (signingKey.length < 32 || schoolKeys.includes(signingKey)) {
    throw new Error("Configure a distinct platform signing key first");
  }
  let hidden = false;
  const output = new Writable({ write(chunk, _encoding, done) { if (!hidden) process.stdout.write(chunk); done(); } });
  const rl = createInterface({ input: process.stdin, output, terminal: true });
  const db = new PrismaClient({ log: [] });
  const ask = async (prompt: string, secret = false) => {
    process.stdout.write(prompt);
    hidden = secret;
    try { return await rl.question(""); }
    finally { hidden = false; if (secret) process.stdout.write("\n"); }
  };
  try {
    console.log("Afaq: local bootstrap of up to two initial Super Admins. No school accounts will change.");
    if (await ask("Confirm authorized setup by typing CREATE: ") !== "CREATE") return;
    const fullName = await ask("Full name: ");
    const email = (await ask("Email: ")).trim().toLowerCase();
    const password = await ask("New password (12+ characters, input hidden): ", true);
    if (await ask("Confirm password: ", true) !== password) throw new Error("Passwords do not match");
    await bootstrapPasswordReviewer(db, { fullName, email, password });
    console.log("Reviewer created. Sign in through the common login page with email and password. Remove ALLOW_PLATFORM_BOOTSTRAP afterwards.");
  } finally { rl.close(); await db.$disconnect(); }
}

main().catch(() => {
  // Prisma errors may contain query parameters; never print credentials on failure.
  console.error("Bootstrap did not complete. Check configuration, migrations, unique email, password and reviewer limit. No overwrite is performed.");
  process.exitCode = 1;
});
