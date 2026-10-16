import "dotenv/config";
import { captureFamilyEmail, emailSandboxConfig } from "../src/shared/notifications/email-sandbox";

async function main() {
  const kind = process.argv[2];
  if (kind !== "approved" && kind !== "password-changed") {
    throw new Error("Usage: npm run email:capture -- approved|password-changed");
  }
  const config = emailSandboxConfig(process.env);
  const common = { recipient: "parent@example.test", fullName: "Demo Parent",
    schoolName: "Demo Madrasa", loginUrl: config.EMAIL_LOGIN_URL };
  const result = await captureFamilyEmail(config, `demo-${kind}`, kind === "approved"
    ? { ...common, kind: "FAMILY_APPROVED", familyLoginId: "DSM/FAM/26/001" }
    : { ...common, kind: "PASSWORD_CHANGED" });
  console.log(result.status === "DISABLED" ? "Email disabled. Nothing saved or sent."
    : `CAPTURED ONLY (not sent)${result.duplicate ? " - existing preview" : ""}: ${result.path}`);
}

main().catch(() => {
  console.error("Email capture failed. Check the command and sandbox settings in DEVELOPMENT.md. No email was sent.");
  process.exitCode = 1;
});
