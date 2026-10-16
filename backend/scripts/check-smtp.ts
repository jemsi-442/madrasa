import { readFile } from "node:fs/promises";
import { parse } from "dotenv";
import { createSmtpEmail, smtpEmailConfig } from "../src/shared/notifications/smtp-email";

async function main() {
  const args = process.argv.slice(2);
  if ((args.length !== 2 && args.length !== 3) || args[0] !== "--env-file" ||
      !args[1] || (args.length === 3 && args[2] !== "--connect")) {
    console.error("Usage: npm run email:check-smtp -- --env-file <private-file> [--connect]");
    process.exitCode = 2;
    return;
  }
  const config = smtpEmailConfig(parse(await readFile(args[1], "utf8")));
  if (!args.includes("--connect")) {
    console.log("SMTP configuration valid. No connection made; domain and delivery remain unverified.");
    return;
  }
  const smtp = createSmtpEmail(config);
  try {
    const result = await smtp.verify();
    console.log(result.status === "SMTP_CONNECTION_VERIFIED"
      ? "SMTP connection/authentication verified. No email sent; sender authorization and inbox delivery are not verified."
      : "SMTP verification failed. Check host, credentials and TLS privately. No email sent.");
    process.exitCode = result.status === "SMTP_CONNECTION_VERIFIED" ? 0 : 1;
  } finally { smtp.close(); }
}

main().catch(() => {
  console.error("SMTP configuration check failed. Check the selected private file and required settings. Values are redacted.");
  process.exitCode = 2;
});
