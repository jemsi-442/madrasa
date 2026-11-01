import { readFile } from "node:fs/promises";
import { parse } from "dotenv";
import { createSmtpEmail, smtpEmailConfig } from "../src/shared/notifications/smtp-email";
import { invitationMessage } from "../src/modules/platform/platform.invitation-delivery";

async function main() {
  const args = process.argv.slice(2);
  const flags = args.slice(2);
  if (args.length < 2 || args[0] !== "--env-file" || !args[1] ||
      flags.some(flag => !["--connect", "--invitations"].includes(flag)) ||
      new Set(flags).size !== flags.length) {
    console.error("Usage: npm run email:check-smtp -- --env-file <private-file> [--invitations] [--connect]");
    process.exitCode = 2;
    return;
  }
  const environment = parse(await readFile(args[1], "utf8"));
  const required = ["SMTP_HOST", "SMTP_USER", "SMTP_PASSWORD", "EMAIL_FROM", "EMAIL_LOGIN_URL"];
  if (flags.includes("--invitations")) required.push("SCHOOL_INVITATION_URL");
  const missing = required.filter(key => !environment[key]?.trim());
  if (missing.length) {
    console.error(`Missing settings: ${missing.join(", ")}. No connection made; values are redacted.`);
    process.exitCode = 2;
    return;
  }
  const config = smtpEmailConfig(environment);
  if (flags.includes("--invitations")) {
    invitationMessage({ token: "a".repeat(43), email: "check@example.test", expiresAt: new Date() }, environment.SCHOOL_INVITATION_URL!);
    console.log("Invitation page URL valid. No invitation created or sent.");
    console.log(environment.SCHOOL_INVITATIONS_ENABLED === "true"
      ? "Invitation sending is enabled in the selected configuration."
      : "Invitation sending remains disabled; enable only after configuration checks.");
  }
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
