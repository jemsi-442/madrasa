import { describe, expect, it } from "vitest";
import { createUserSchema } from "../src/modules/users/users.schemas";
import { loginSchema } from "../src/modules/auth/auth.schemas";

const input = { fullName: " Demo Teacher ", email: " Teacher@Example.Test ", password: "Password123!", role: "TEACHER" };
describe("school account input consistency", () => {
  it("normalizes contact fields without changing the password", () => {
    const password = "  Secret123!  ";
    expect(createUserSchema.parse({ ...input, phone: " 255700000000 ", password })).toMatchObject({
      fullName: "Demo Teacher", email: "teacher@example.test", phone: "255700000000", password,
    });
  });
  for (const password of ["a".repeat(72), "\u00e9".repeat(36), " secret "]) {
    it(`accepts the same password for creation and login (${Buffer.byteLength(password)} bytes)`, () => {
      expect(createUserSchema.parse({ ...input, password }).password).toBe(password);
      expect(loginSchema.parse({ login: "teacher@example.test", password }).password).toBe(password);
    });
  }
  for (const password of ["a".repeat(73), "\u00e9".repeat(37)]) {
    it(`rejects oversize passwords at both boundaries (${Buffer.byteLength(password)} bytes)`, () => {
      expect(createUserSchema.safeParse({ ...input, password }).success).toBe(false);
      expect(loginSchema.safeParse({ login: "teacher@example.test", password }).success).toBe(false);
    });
  }
  it("lets short nonempty login passwords reach the generic credential check", () => {
    expect(loginSchema.safeParse({ login: "teacher@example.test", password: "wrong" }).success).toBe(true);
    expect(createUserSchema.safeParse({ ...input, password: "wrong" }).success).toBe(false);
  });
  it("rejects extra authority fields and database-length overflow", () => {
    for (const extra of [{ orgId: "99" }, { status: "ACTIVE" }, { familyLoginId: "DSM/FAM/26/001" },
      { fullName: "a".repeat(151) }, { phone: "1".repeat(31) }]) {
      expect(createUserSchema.safeParse({ ...input, ...extra }).success).toBe(false);
    }
  });
});
