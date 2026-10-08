import "dotenv/config";
import { randomBytes } from "node:crypto";
import { createInterface } from "node:readline/promises";
import { Writable } from "node:stream";
import { PrismaClient } from "@prisma/client";
import { bootstrapPlatformReviewer } from "../src/modules/platform/platform.bootstrap";
import { base32Secret, validMfaKey } from "../src/modules/platform/platform.mfa";

async function main() {
  if (!process.stdin.isTTY || !process.stdout.isTTY || process.env.ALLOW_PLATFORM_BOOTSTRAP !== "true") {
    throw new Error("Use a private interactive terminal with ALLOW_PLATFORM_BOOTSTRAP=true");
  }
  const key = process.env.PLATFORM_MFA_ENCRYPTION_KEY ?? "";
  const signingKey = process.env.PLATFORM_JWT_SECRET ?? "";
  const schoolKeys = [process.env.JWT_SECRET, process.env.JWT_REFRESH_SECRET];
  if (!validMfaKey(key) || signingKey.length < 32 || key === signingKey || schoolKeys.includes(key) || schoolKeys.includes(signingKey)) {
    throw new Error("Configure distinct platform signing and MFA encryption keys first");
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
    const mfaSecret = randomBytes(20);
    console.log("Add a time-based account to your authenticator (6 digits, SHA1, 30 seconds).");
    console.log("Private setup key (do not share, screenshot or save in project files):", base32Secret(mfaSecret));
    const code = await ask("Authenticator code to confirm setup: ", true);
    await bootstrapPlatformReviewer(db, { fullName, email, password, code }, mfaSecret, key);
    console.log("Reviewer created. Wait for the next authenticator code before login. Remove ALLOW_PLATFORM_BOOTSTRAP afterwards.");
  } finally { rl.close(); await db.$disconnect(); }
}

main().catch(() => {
  // Prisma errors may contain query parameters; never print credentials on failure.
  console.error("Bootstrap did not complete. Check configuration, migrations, unique email, password/code and reviewer limit. No overwrite is performed.");
  process.exitCode = 1;
});
