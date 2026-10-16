import { readFileSync } from "node:fs";
import { parse } from "dotenv";
import { describe, expect, it } from "vitest";
import { productionPreflight } from "../src/config/production-preflight";

const config = {
  NODE_ENV: "production", APP_BASE_URL: "https://api.afaq.africa", WEB_APP_ORIGINS: "https://afaq.africa",
  PUBLIC_SITE_ORG_CODE: "afaq-main", JWT_SECRET: "synthetic-access-0123456789-abcdefghijk",
  JWT_REFRESH_SECRET: "synthetic-refresh-0123456789-abcdefghijk", PLATFORM_JWT_SECRET: "synthetic-platform-0123456789-abcdefghijk",
  ALLOW_PLATFORM_BOOTSTRAP: "false", DATABASE_URL: "mysql://account:private-password@database.internal/afaq",
  REDIS_URL: "redis://cache.internal:6379", SNIPPE_MOCK_MODE: "false", EMAIL_MODE: "disabled",
  EMAIL_FROM: "noreply@afaq.africa", EMAIL_LOGIN_URL: "https://afaq.africa/#/login", EMAIL_SUPPORT_ADDRESS: "support@afaq.africa",
};
describe("offline production preflight", () => {
  it("passes configured targets but never certifies deployment", () => {
    const report = productionPreflight(config);
    expect(report.configurationPassed).toBe(true);
    expect(report.deploymentVerified).toBe(false);
    expect(report.checks.filter(c => c.status === "MANUAL")).toHaveLength(6);
  });
  it("blocks the checked-in template until real configuration is supplied", () => {
    const template = parse(readFileSync(".env.production.example"));
    expect(productionPreflight(template).configurationPassed).toBe(false);
  });
  it.each([
    { NODE_ENV: "development" }, { APP_BASE_URL: "http://api.afaq.africa" },
    { WEB_APP_ORIGINS: "*" }, { WEB_APP_ORIGINS: "https://afaq.africa,https://attacker.test" },
    { PUBLIC_SITE_ORG_CODE: "demo-madrasa" }, { JWT_SECRET: "change-me" },
    { JWT_SECRET: "a".repeat(64) }, { JWT_REFRESH_SECRET: config.JWT_SECRET },
    { ALLOW_PLATFORM_BOOTSTRAP: "true" }, { DATABASE_URL: "mysql://user:pass@host" },
    { REDIS_URL: "https://cache.internal" }, { SNIPPE_MOCK_MODE: "true" },
    { EMAIL_MODE: "capture" }, { EMAIL_MODE: "smtp" }, { EMAIL_LOGIN_URL: "https://attacker.test/login" },
  ])("blocks unsafe/missing configuration %o", override => {
    expect(productionPreflight({ ...config, ...override }).configurationPassed).toBe(false);
  });
  it("does not expose credentials or malformed input in its report", () => {
    const secret = "never-print-this-value";
    const report = JSON.stringify(productionPreflight({ ...config, DATABASE_URL: secret, JWT_SECRET: secret }));
    expect(report).not.toContain(secret);
    expect(report).not.toContain("private-password");
    expect(report).not.toContain(config.JWT_REFRESH_SECRET);
  });
});
