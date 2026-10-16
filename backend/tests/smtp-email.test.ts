import { beforeEach, describe, expect, it, vi } from "vitest";
const mock = vi.hoisted(() => ({ sendMail: vi.fn(), verify: vi.fn(), close: vi.fn(), createTransport: vi.fn() }));
vi.mock("nodemailer", () => ({ default: { createTransport: mock.createTransport } }));
import { createSmtpEmail, smtpEmailConfig } from "../src/shared/notifications/smtp-email";

const config = { EMAIL_MODE: "smtp", EMAIL_FROM: "noreply@afaq.africa", EMAIL_SENDER_VERIFIED: "true",
  EMAIL_LOGIN_URL: "https://afaq.africa/#/login", SMTP_HOST: "smtp.example.test", SMTP_PORT: "587",
  SMTP_USER: "test-user", SMTP_PASSWORD: "test-secret" };
const input = { kind: "FAMILY_APPROVED" as const, recipient: "parent@example.test", fullName: "Demo Parent",
  schoolName: "Demo Madrasa", loginUrl: "https://ignored.test", familyLoginId: "DSM/FAM/26/001" };
const id = "cf890241-c326-43f0-a53e-47b2b1b2d106";
const proof = { address: input.recipient, verifiedAt: new Date("2020-01-01") };
beforeEach(() => {
  vi.resetAllMocks();
  mock.createTransport.mockReturnValue(mock);
});

describe("SMTP adapter without network", () => {
  it.each([{ EMAIL_MODE: "disabled" }, { EMAIL_SENDER_VERIFIED: "false" }, { SMTP_PORT: "25" },
    { SMTP_PASSWORD: "" }, { EMAIL_LOGIN_URL: "http://afaq.africa" }])("rejects incomplete or insecure settings %o", extra => {
    expect(() => createSmtpEmail({ ...config, ...extra })).toThrow();
    expect(mock.createTransport).not.toHaveBeenCalled();
  });
  it("validates settings without opening a transport", () => {
    expect(smtpEmailConfig(config).SMTP_PORT).toBe("587");
    expect(mock.createTransport).not.toHaveBeenCalled();
  });
  it.each(["465", "587"])("enforces TLS and disables resource fetching on port %s", port => {
    createSmtpEmail({ ...config, SMTP_PORT: port });
    expect(mock.createTransport).toHaveBeenCalledWith(expect.objectContaining({
      secure: port === "465", requireTLS: true, disableFileAccess: true, disableUrlAccess: true,
      tls: { rejectUnauthorized: true, minVersion: "TLSv1.2" }, logger: false, debug: false,
    }));
  });
  it("does not confuse acceptance with inbox delivery and uses configured login URL", async () => {
    mock.sendMail.mockResolvedValue({ accepted: [input.recipient], rejected: [] });
    const smtp = createSmtpEmail(config);
    expect(await smtp.send(id, input, proof)).toEqual({ status: "SMTP_ACCEPTED", messageId: `<${id}@afaq.africa>` });
    const message = mock.sendMail.mock.calls[0]![0];
    expect(message.text).toContain(config.EMAIL_LOGIN_URL);
    expect(message.text).not.toContain("ignored.test");
    expect(message).not.toHaveProperty("attachments");
    expect(message).not.toHaveProperty("raw");
    smtp.close();
    expect(mock.close).toHaveBeenCalledOnce();
  });
  it.each([{ address: "other@example.test", verifiedAt: proof.verifiedAt },
    { address: input.recipient, verifiedAt: new Date("invalid") },
    { address: input.recipient, verifiedAt: new Date("2999-01-01") }])("requires matching trusted verification %o", async verified => {
    await expect(createSmtpEmail(config).send(id, input, verified)).rejects.toThrow();
    expect(mock.sendMail).not.toHaveBeenCalled();
  });
  it("rejects extra sensitive fields before transport", async () => {
    await expect(createSmtpEmail(config).send(id, { ...input, password: "secret" } as typeof input, proof)).rejects.toThrow();
    expect(mock.sendMail).not.toHaveBeenCalled();
  });
  it("returns unknown on provider failure without leaking messages or retrying", async () => {
    mock.sendMail.mockRejectedValue(new Error("password=test-secret recipient=parent@example.test"));
    const result = await createSmtpEmail(config).send(id, input, proof);
    expect(result.status).toBe("UNKNOWN");
    expect(JSON.stringify(result)).not.toContain("test-secret");
    expect(mock.sendMail).toHaveBeenCalledOnce();
  });
  it("reports recipient rejection", async () => {
    mock.sendMail.mockResolvedValue({ accepted: [], rejected: [input.recipient] });
    expect((await createSmtpEmail(config).send(id, input, proof)).status).toBe("REJECTED");
  });
  it("verifies connection without sending mail and redacts errors", async () => {
    const smtp = createSmtpEmail(config);
    mock.verify.mockResolvedValue(true);
    expect(await smtp.verify()).toEqual({ status: "SMTP_CONNECTION_VERIFIED" });
    mock.verify.mockRejectedValue(new Error("test-secret"));
    expect(await smtp.verify()).toEqual({ status: "FAILED" });
    expect(mock.sendMail).not.toHaveBeenCalled();
  });
});
