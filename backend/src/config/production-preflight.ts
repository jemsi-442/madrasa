export type PreflightCheck = { id: string; status: "PASS" | "BLOCKED" | "MANUAL"; message: string };

// Offline configuration checks only. Never include environment values in results.
export function productionPreflight(environment: Record<string, string | undefined>) {
  const checks: PreflightCheck[] = [];
  const check = (id: string, valid: boolean, message: string) => {
    checks.push({ id, status: valid ? "PASS" : "BLOCKED", message });
  };
  check("production-mode", environment.NODE_ENV === "production", "NODE_ENV must be production.");
  check("api-origin", environment.APP_BASE_URL === "https://api.afaq.africa", "APP_BASE_URL must match the agreed Afaq HTTPS API origin.");
  const origins = (environment.WEB_APP_ORIGINS ?? "").split(",").map(s => s.trim()).filter(Boolean);
  check("web-origins", origins.includes("https://afaq.africa") && origins.every(
    origin => ["https://afaq.africa", "https://www.afaq.africa"].includes(origin)),
  "Browser origins must include the Afaq apex and contain only approved HTTPS origins.");
  check("school-code", /^[a-zA-Z0-9_-]+$/.test(environment.PUBLIC_SITE_ORG_CODE ?? "") &&
    !/^(demo|test|example)(-|$)/i.test(environment.PUBLIC_SITE_ORG_CODE ?? ""),
  "Set the intended real public school code; its existence requires a separate database check.");

  const secrets = ["JWT_SECRET", "JWT_REFRESH_SECRET", "PLATFORM_JWT_SECRET"] as const;
  const values = secrets.map(name => environment[name] ?? "");
  secrets.forEach((name, index) => check(`secret-${name.toLowerCase()}`,
    values[index]!.length >= 32 && !/(change[-_ ]?me|replace|example|placeholder)/i.test(values[index]!) &&
      new Set(values[index]).size >= 8,
    `${name} must be a generated secret of at least 32 characters, not a template value.`));
  check("independent-secrets", values.every(Boolean) && new Set(values).size === values.length,
    "School access, refresh and platform JWT secrets must be distinct.");
  check("bootstrap-disabled", environment.ALLOW_PLATFORM_BOOTSTRAP === "false", "Platform bootstrap must explicitly be disabled.");

  for (const [key, protocols] of [["DATABASE_URL", ["mysql:"]], ["REDIS_URL", ["redis:", "rediss:"]]] as const) {
    let valid = false;
    try {
      const url = new URL(environment[key] ?? "");
      valid = (protocols as readonly string[]).includes(url.protocol) && !!url.hostname &&
        (key !== "DATABASE_URL" || (!!url.username && !!url.password && url.pathname.length > 1)) &&
        !/(change[-_ ]?me|replace|example|mms_password)/i.test(environment[key] ?? "");
    } catch { /* Missing and malformed values produce the same redacted result. */ }
    check(key.toLowerCase(), valid, `${key} must be configured with a valid service URL, not a template value.`);
  }
  check("payments-not-mocked", environment.SNIPPE_MOCK_MODE === "false", "Payment mock mode must explicitly be disabled.");
  check("email-disabled", environment.EMAIL_MODE === "disabled", "Automatic email must remain disabled until durable delivery and verified recipients are integrated.");
  check("email-sender", environment.EMAIL_FROM === "noreply@afaq.africa", "Use the planned Afaq sender address; this does not verify the mailbox.");
  check("email-login", environment.EMAIL_LOGIN_URL === "https://afaq.africa/#/login", "Email login links must point to the agreed Afaq login page.");
  check("support-address", environment.EMAIL_SUPPORT_ADDRESS === "support@afaq.africa", "Reserve the planned Afaq support address; application integration remains pending.");

  for (const [id, message] of [
    ["domain-and-tls", "Verify domain ownership, DNS, HTTPS certificates and reverse-proxy routing for web and API."],
    ["backup-and-migrations", "Test a protected database backup and restore, review migrations and deploy all API workers together."],
    ["network-and-secrets", "Verify private database/Redis access, secret generation and storage, and any optional service keys without exposing them."],
    ["school-and-login", "Verify the school mapping, role boundaries, cross-school isolation and browser login/logout on the actual deployed origins."],
    ["email-provider", "Choose and verify the email provider/sender, implement durable delivery and recipient verification; automatic email is not ready."],
    ["payments", "Verify payment credentials and signed webhooks before enabling real payments."],
  ]) checks.push({ id: id!, status: "MANUAL", message: message! });

  return { configurationPassed: !checks.some(c => c.status === "BLOCKED"),
    deploymentVerified: false as const, checks };
}
