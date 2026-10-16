import nodemailer from "nodemailer";
import { z } from "zod";
import { buildFamilyEmail, type FamilyEmailInput } from "./family-email";

const schema = z.object({
  EMAIL_MODE: z.literal("smtp"),
  EMAIL_FROM: z.string().email().max(150),
  EMAIL_SENDER_VERIFIED: z.literal("true"),
  EMAIL_LOGIN_URL: z.string().url().refine(value => {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password && !url.search;
  }),
  SMTP_HOST: z.string().min(1).max(253).regex(/^(?=.{1,253}$)[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?$/),
  SMTP_PORT: z.enum(["465", "587"]),
  SMTP_USER: z.string().min(1).max(500),
  SMTP_PASSWORD: z.string().min(1).max(2000),
});

export function smtpEmailConfig(environment: Record<string, string | undefined>) {
  const result = schema.safeParse(environment);
  if (!result.success) throw new Error("SMTP is not configured or sender verification has not been confirmed");
  return result.data;
}

export type SmtpResult = { status: "SMTP_ACCEPTED" | "REJECTED" | "UNKNOWN"; messageId: string };
export type RecipientVerification = { address: string; verifiedAt: Date };

export function createSmtpEmail(environment: Record<string, string | undefined>) {
  const config = smtpEmailConfig(environment);
  const transport = nodemailer.createTransport({
    host: config.SMTP_HOST, port: Number(config.SMTP_PORT), secure: config.SMTP_PORT === "465",
    requireTLS: true, opportunisticTLS: false,
    tls: { rejectUnauthorized: true, minVersion: "TLSv1.2" },
    auth: { user: config.SMTP_USER, pass: config.SMTP_PASSWORD },
    connectionTimeout: 10_000, greetingTimeout: 10_000, socketTimeout: 30_000, dnsTimeout: 10_000,
    disableFileAccess: true, disableUrlAccess: true, logger: false, debug: false,
  });

  return {
    async verify(): Promise<{ status: "SMTP_CONNECTION_VERIFIED" | "FAILED" }> {
      try {
        await transport.verify();
        return { status: "SMTP_CONNECTION_VERIFIED" };
      } catch {
        return { status: "FAILED" };
      }
    },
    async send(notificationId: string, input: FamilyEmailInput,
      verified: RecipientVerification): Promise<SmtpResult> {
      const id = z.string().uuid().parse(notificationId);
      const draft = buildFamilyEmail({ ...input, loginUrl: config.EMAIL_LOGIN_URL });
      // The caller must load this proof from trusted storage, never from a request body.
      if (verified.address !== draft.to || !(verified.verifiedAt instanceof Date) ||
          !Number.isFinite(verified.verifiedAt.getTime()) || verified.verifiedAt.getTime() > Date.now()) {
        throw new Error("Recipient ownership must be verified before sending account information");
      }
      const messageId = `<${id}@${config.EMAIL_FROM.split("@")[1]}>`;
      try {
        const result = await transport.sendMail({
          from: { name: "Afaq", address: config.EMAIL_FROM }, to: draft.to,
          subject: draft.subject, text: draft.text, html: draft.html, messageId,
          disableFileAccess: true, disableUrlAccess: true,
        });
        if (result.accepted.some(address => typeof address === "string" && address.toLowerCase() === draft.to.toLowerCase())) {
          return { status: "SMTP_ACCEPTED", messageId };
        }
        if (result.rejected.some(address => typeof address === "string" && address.toLowerCase() === draft.to.toLowerCase())) {
          return { status: "REJECTED", messageId };
        }
        return { status: "UNKNOWN", messageId };
      } catch {
        // A timeout can occur after acceptance. Do not blindly retry or leak provider errors.
        return { status: "UNKNOWN", messageId };
      }
    },
    close() { transport.close(); },
  };
}
