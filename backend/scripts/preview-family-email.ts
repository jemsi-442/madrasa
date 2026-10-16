import { buildFamilyEmail } from "../src/shared/notifications/family-email";

const kind = process.argv[2];
if (kind !== "approved" && kind !== "password-changed") {
  console.error("Usage: npm run email:preview -- approved|password-changed [--html]");
  process.exitCode = 1;
} else {
  // Synthetic data only: this command never queries accounts or sends email.
  const common = { recipient: "parent@example.test", fullName: "Demo Parent",
    schoolName: "Demo Madrasa", loginUrl: "https://example.test/#/login" };
  const draft = buildFamilyEmail(kind === "approved"
    ? { ...common, kind: "FAMILY_APPROVED", familyLoginId: "DSM/FAM/26/001" }
    : { ...common, kind: "PASSWORD_CHANGED" });
  process.stdout.write(process.argv.includes("--html") ? draft.html : `${draft.subject}\n\n${draft.text}\n`);
}
