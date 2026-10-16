import { describe, expect, it } from "vitest";
import { buildFamilyEmail, type FamilyEmailInput } from "../src/shared/notifications/family-email";

const input = { kind: "FAMILY_APPROVED" as const, recipient: "parent@example.test",
  fullName: "Parent", schoolName: "Afaq School", loginUrl: "https://example.test/#/login",
  familyLoginId: "DSM/FAM/26/001" };

describe("family email drafts", () => {
  it("provides branded text and HTML without inventing a password", () => {
    const draft = buildFamilyEmail(input);
    expect(draft.subject).toContain("Afaq");
    expect(draft.text).toContain(input.familyLoginId);
    expect(draft.text).toContain("password you chose");
    expect(draft.html).toContain('href="https://example.test/#/login"');
  });
  it("escapes untrusted names in HTML", () => {
    const draft = buildFamilyEmail({ ...input, fullName: '<img src=x onerror="alert(1)">' });
    expect(draft.html).not.toContain("<img");
    expect(draft.html).toContain("&lt;img");
  });
  it.each(["password", "receipt", "children", "passwordHash"])("rejects extra private field %s", key => {
    expect(() => buildFamilyEmail({ ...input, [key]: "secret" })).toThrow();
  });
  it.each(["http://example.test", "javascript:alert(1)", "https://user:secret@example.test", "https://example.test/?token=secret"])("rejects unsafe URL %s", loginUrl => {
    expect(() => buildFamilyEmail({ ...input, loginUrl })).toThrow();
  });
  it("rejects header controls and invalid family numbers", () => {
    expect(() => buildFamilyEmail({ ...input, recipient: "a@example.test\r\nBcc: b@example.test" })).toThrow();
    expect(() => buildFamilyEmail({ ...input, familyLoginId: "123" })).toThrow();
  });
  it("builds a password notice without account identifiers", () => {
    const { familyLoginId: _, ...common } = input;
    const draft = buildFamilyEmail({ ...common, kind: "PASSWORD_CHANGED" });
    expect(draft.text).toContain("Previous sessions have been signed out");
    expect(draft.text).not.toContain("DSM/FAM");
    expect(() => buildFamilyEmail({ ...input, kind: "UNKNOWN" } as unknown as FamilyEmailInput)).toThrow();
  });
});
