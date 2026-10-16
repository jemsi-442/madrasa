import { z } from "zod";

const label = z.string().trim().min(1).max(150).refine(
  value => !/[\r\n\x00-\x1f\x7f]/.test(value), "Invalid label",
);
const base = z.object({
  recipient: z.string().trim().email().max(150),
  fullName: label,
  schoolName: label,
  loginUrl: z.string().url().refine(value => {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password && !url.search;
  }, "Use a trusted HTTPS login URL without credentials or query parameters"),
});

// Strict payloads prevent accidentally including passwords, receipts or child records.
const notification = z.discriminatedUnion("kind", [
  base.extend({ kind: z.literal("FAMILY_APPROVED"),
    familyLoginId: z.string().regex(/^[A-Z]{2,8}\/FAM\/\d{2}\/\d{3,}$/) }).strict(),
  base.extend({ kind: z.literal("PASSWORD_CHANGED") }).strict(),
]);

export type FamilyEmailInput = z.input<typeof notification>;
export type EmailDraft = { to: string; subject: string; text: string; html: string };

const escapeHtml = (value: string) => value.replace(/[&<>"']/g, character => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
})[character]!);

export function buildFamilyEmail(raw: FamilyEmailInput): EmailDraft {
  const input = notification.parse(raw);
  const approved = input.kind === "FAMILY_APPROVED";
  const subject = approved ? "Afaq | Your family account is ready" : "Afaq | Your password was changed";
  const paragraphs = [
    `Assalamu alaikum ${input.fullName},`,
    approved
      ? `Your family account at ${input.schoolName} has been approved. Your family sign-in number is ${input.familyLoginId}.`
      : `The password for your account at ${input.schoolName} was changed. Previous sessions have been signed out.`,
    approved
      ? "Sign in using your family number and the password you chose. Your school office manages which children are linked to your account."
      : "If you did not request this change, contact your school office immediately using its known contact details.",
    "Never share your password. Afaq will not ask you to send it by email.",
  ];
  return {
    to: input.recipient, subject,
    text: `${paragraphs.join("\n\n")}\n\nSign in: ${input.loginUrl}\n\nAfaq | Family access`,
    html: `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>${escapeHtml(subject)}</title></head><body style="margin:0;background:#f6f4ef;color:#102e42;font-family:Georgia,serif"><main style="max-width:580px;margin:24px auto;padding:32px;background:#fff;border-top:6px solid #b48b30"><h1>Afaq</h1><h2>${approved ? "Your family account is ready" : "Password changed"}</h2>${paragraphs.map(p => `<p style="line-height:1.7">${escapeHtml(p)}</p>`).join("")}<p><a style="color:#102e42" href="${escapeHtml(input.loginUrl)}">Sign in to Afaq</a></p><hr><p>Family access &middot; Afaq</p></main></body></html>`,
  };
}
