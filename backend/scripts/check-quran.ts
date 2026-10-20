import { readFile } from "node:fs/promises";
import { parse } from "dotenv";
import { z } from "zod";
import { QuranContentClient } from "../src/modules/teacher-workspace/quran-content";

const settings = z.object({
  QF_ENABLED: z.literal("true"),
  QF_ENV: z.enum(["prelive", "production"]).default("prelive"),
  QF_CLIENT_ID: z.string().trim().min(1),
  QF_CLIENT_SECRET: z.string().trim().min(1),
});

async function main() {
  const args = process.argv.slice(2);
  if ((args.length !== 2 && args.length !== 3) || args[0] !== "--env-file" ||
      !args[1] || (args.length === 3 && args[2] !== "--connect")) {
    console.error("Usage: npm run quran:check -- --env-file <private-file> [--connect]");
    process.exitCode = 2;
    return;
  }
  // Parse only the explicitly selected file; do not load app/database configuration.
  const config = settings.parse(parse(await readFile(args[1], "utf8")));
  console.log(`Quran configuration valid (${config.QF_ENV}).`);
  if (!args.includes("--connect")) {
    console.log("No connection made. Credentials and content access remain unverified.");
    return;
  }
  const client = new QuranContentClient({
    enabled: true, environment: config.QF_ENV,
    clientId: config.QF_CLIENT_ID, clientSecret: config.QF_CLIENT_SECRET,
  });
  try {
    const chapters = await client.chapters();
    if (!chapters.chapters.some(chapter => chapter.id === 1)) {
      throw new Error("Missing required chapter");
    }
    await client.verses(1, { page: 1, per_page: 1 });
    console.log("Connection verified: chapter metadata and one validated verse retrieved.");
    console.log(config.QF_ENV === "prelive"
      ? "Pre-live is limited to surahs 1-2. Full Quran access is not verified."
      : "Production sample verified. This does not verify every surah, audio or translations.");
  } catch {
    console.error("Quran connection check failed. Check credentials, provider access and network privately. Details redacted.");
    process.exitCode = 1;
  }
}

main().catch(() => {
  console.error("Quran configuration check failed. Check the private file and QF settings. Values redacted.");
  process.exitCode = 2;
});
