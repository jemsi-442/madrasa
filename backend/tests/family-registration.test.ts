import { describe, expect, it, vi } from "vitest";
import { Prisma, type PrismaClient } from "@prisma/client";
import { familyRegistrationSchema, issueFamilyRegistration } from "../src/modules/users/family-registration";
import { normalizeLogin, schoolLoginIdentity } from "../src/modules/auth/login-identity";

function fixture() {
  const admin = { id: 1n, branchId: 3n };
  const parent = { id: 2n, familyLoginId: null as string | null };
  const tx = {
    user: { findFirst: vi.fn().mockImplementation(async ({ where }) => where.role === "ADMIN" ? admin : parent),
      update: vi.fn().mockResolvedValue({}) },
    familyRegistrationCounter: { upsert: vi.fn().mockResolvedValue({ sequence: 1 }) },
    auditLog: { create: vi.fn().mockResolvedValue({}) },
  };
  const transaction = vi.fn().mockImplementation(async (fn) => fn(tx));
  const db = { $transaction: transaction } as unknown as PrismaClient;
  const run = () => issueFamilyRegistration(db, { userId: "1", orgId: "10" }, "2", "dsm", new Date("2026-10-09T12:00:00Z"));
  return { tx, db, admin, parent, transaction, run };
}

describe("family registration foundation", () => {
  it("issues a separate identity without changing the password or child records", async () => {
    const f = fixture();
    expect(await f.run()).toEqual({ userId: "2", familyLoginId: "DSM/FAM/26/001" });
    expect(f.tx.user.update).toHaveBeenCalledWith({ where: { id: 2n }, data: { familyLoginId: "DSM/FAM/26/001" } });
    expect(f.transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: "Serializable" });
    expect(f.tx.auditLog.create).toHaveBeenCalledWith({ data: expect.objectContaining({ orgId: 10n, actorUserId: 1n, action: "family.registration.issued" }) });
  });
  it("checks current admin authority, school, branch and linked guardian", async () => {
    const f = fixture();
    await f.run();
    expect(f.tx.user.findFirst.mock.calls[0]![0].where).toMatchObject({ id: 1n, orgId: 10n, role: "ADMIN", status: "ACTIVE", organization: { status: { in: ["ACTIVE", "TRIAL"] } } });
    expect(f.tx.user.findFirst.mock.calls[1]![0].where).toMatchObject({ id: 2n, orgId: 10n, role: "PARENT", status: "ACTIVE", branchId: 3n, guardianProfile: { is: { orgId: 10n } } });
  });
  it("is idempotent even if a different region is supplied later", async () => {
    const f = fixture();
    f.parent.familyLoginId = "ARU/FAM/25/032";
    expect((await f.run()).familyLoginId).toBe("ARU/FAM/25/032");
    expect(f.tx.familyRegistrationCounter.upsert).not.toHaveBeenCalled();
    expect(f.tx.auditLog.create).not.toHaveBeenCalled();
  });
  it("refuses a revoked admin", async () => {
    const f = fixture();
    f.tx.user.findFirst.mockResolvedValue(null);
    await expect(f.run()).rejects.toMatchObject({ statusCode: 403 });
    expect(f.tx.familyRegistrationCounter.upsert).not.toHaveBeenCalled();
  });
  it("refuses an unavailable or unlinked parent without allocating a number", async () => {
    const f = fixture();
    f.tx.user.findFirst.mockResolvedValueOnce(f.admin).mockResolvedValueOnce(null);
    await expect(f.run()).rejects.toMatchObject({ statusCode: 404 });
    expect(f.tx.user.update).not.toHaveBeenCalled();
  });
  it("uses the local school year boundary and allows sequences above 999", async () => {
    const f = fixture();
    f.tx.familyRegistrationCounter.upsert.mockResolvedValue({ sequence: 1000 });
    expect(await issueFamilyRegistration(f.db, { userId: "1", orgId: "10" }, "2", "DSM", new Date("2026-12-31T22:00:00Z")))
      .toMatchObject({ familyLoginId: "DSM/FAM/27/1000" });
  });
  it("retries serialization conflicts but bounds retries", async () => {
    const f = fixture();
    const conflict = new Prisma.PrismaClientKnownRequestError("conflict", { code: "P2034", clientVersion: "6" });
    f.transaction.mockRejectedValueOnce(conflict);
    await expect(f.run()).resolves.toMatchObject({ familyLoginId: "DSM/FAM/26/001" });
    f.transaction.mockClear().mockRejectedValue(conflict);
    await expect(f.run()).rejects.toMatchObject({ statusCode: 409 });
    expect(f.transaction).toHaveBeenCalledTimes(3);
  });
  it("does not report success when audit persistence fails", async () => {
    const f = fixture();
    f.tx.auditLog.create.mockRejectedValue(new Error("audit unavailable"));
    await expect(f.run()).rejects.toThrow("audit unavailable");
  });
  it("retries MariaDB changed-record conflicts without masking unrelated errors", async () => {
    const f = fixture();
    f.transaction.mockRejectedValueOnce(new Prisma.PrismaClientUnknownRequestError(
      'MysqlError { code: 1020, message: "Record has changed since last read" }', { clientVersion: "6" }));
    await expect(f.run()).resolves.toMatchObject({ familyLoginId: "DSM/FAM/26/001" });
    expect(f.transaction).toHaveBeenCalledTimes(2);
    f.transaction.mockClear().mockRejectedValue(new Prisma.PrismaClientUnknownRequestError(
      'MysqlError { code: 9999, message: "other error" }', { clientVersion: "6" }));
    await expect(f.run()).rejects.toThrow("other error");
    expect(f.transaction).toHaveBeenCalledTimes(1);
  });
  it("rejects client-selected passwords, sequences and malformed regions", () => {
    for (const input of [{ regionCode: "DSM", password: "secret" }, { regionCode: "DSM", sequence: 1 }, { regionCode: "DSM/ADMIN" }]) {
      expect(familyRegistrationSchema.safeParse(input).success).toBe(false);
    }
  });
  it("shares identity normalization and only allows family aliases for parents", () => {
    expect(normalizeLogin(" A@Example.COM ")).toBe("a@example.com");
    expect(schoolLoginIdentity(" dsm/fam/26/001 ")).toEqual({ OR: [
      { email: "DSM/FAM/26/001" }, { phone: "DSM/FAM/26/001" },
      { familyLoginId: "DSM/FAM/26/001", role: "PARENT" },
    ] });
  });
});
