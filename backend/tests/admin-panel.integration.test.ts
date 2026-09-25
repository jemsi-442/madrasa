import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { env } from "../src/config/env";
import { prisma } from "../src/shared/db/prisma";
import { api } from "./helpers/api-client";
import { recentMonths } from "../src/modules/fundraising/fundraising.service";

describe("admin panel and fundraising", () => {
  let orgId: bigint, otherOrgId: bigint, userId: bigint;
  let donorId: string, campaignId: string, otherDonorId: string;
  const token = (role = "ADMIN", org = orgId) => jwt.sign({
    sub: userId.toString(), orgId: org.toString(), role, type: "access",
  }, env.JWT_SECRET, { expiresIn: "5m" });
  const get = (path: string) => api.get(`/api${path}`).set("Authorization", `Bearer ${token()}`);
  const post = (path: string, body: object) => api.post(`/api${path}`).set("Authorization", `Bearer ${token()}`).send(body);
  const donation = (overrides = {}) => ({ donorId, campaignId, amount: "1200.50", method: "CASH",
    receivedAt: new Date().toISOString(), idempotencyKey: randomUUID(), ...overrides });

  beforeAll(async () => {
    orgId = (await prisma.organization.create({ data: { name: "Admin panel test", code: `AP-${randomUUID()}` } })).id;
    otherOrgId = (await prisma.organization.create({ data: { name: "Other tenant", code: `AP-${randomUUID()}` } })).id;
    userId = (await prisma.user.create({ data: { orgId, fullName: "Test Administrator", passwordHash: "not-a-login", role: "ADMIN" } })).id;
    otherDonorId = (await prisma.donor.create({ data: { orgId: otherOrgId, fullName: "Private donor" } })).id.toString();
    const donor = await post("/fundraising/donors", { fullName: "Foundation Supporter" });
    expect(donor.status).toBe(201);
    donorId = donor.body.data.id;
    const campaign = await post("/fundraising/campaigns", { title: "Learning resources", goalAmount: "100000.00" });
    expect(campaign.status).toBe(201);
    campaignId = campaign.body.data.id;
  });

  afterAll(async () => {
    vi.restoreAllMocks();
    const where = { orgId: { in: [orgId, otherOrgId].filter(Boolean) } };
    await prisma.donation.deleteMany({ where });
    await prisma.donationPledge.deleteMany({ where });
    await prisma.fundraisingCampaign.deleteMany({ where });
    await prisma.donor.deleteMany({ where });
    await prisma.foundationEvent.deleteMany({ where });
    await prisma.auditLog.deleteMany({ where });
    await prisma.user.deleteMany({ where });
    await prisma.organization.deleteMany({ where: { id: where.orgId } });
  });

  it("requires authentication and denies all non-admin roles", async () => {
    expect((await api.get("/api/fundraising/overview")).status).toBe(401);
    for (const role of ["TEACHER", "ACCOUNTANT", "PARENT", "LEARNER"]) {
      for (const path of ["/fundraising/overview", "/admin/overview", "/admin/teachers", "/admin/subjects"]) {
        expect((await api.get(`/api${path}`).set("Authorization", `Bearer ${token(role)}`)).status).toBe(403);
      }
      expect((await api.post("/api/fundraising/donations").set("Authorization", `Bearer ${token(role)}`).send(donation())).status).toBe(403);
    }
  });

  it("isolates tenants at the service and database layers", async () => {
    expect((await post("/fundraising/donations", donation({ donorId: otherDonorId }))).status).toBe(404);
    const listed = await get("/fundraising/donors");
    expect(listed.body.data.items.map((r: { id: string }) => r.id)).not.toContain(otherDonorId);
    await expect(prisma.donation.create({ data: {
      orgId, donorId: BigInt(otherDonorId), campaignId: BigInt(campaignId), amount: "1", method: "CASH",
      receivedAt: new Date(), recordedById: userId, idempotencyKey: randomUUID(), inputHash: "a".repeat(64),
    } })).rejects.toThrow();
  });

  it("keeps pledges separate from income, counts decimal receipts once and reverses voids", async () => {
    const pledge = await post("/fundraising/pledges", { donorId, campaignId, amount: "2000.00", dueOn: new Date().toISOString().slice(0, 10) });
    expect(pledge.status).toBe(201);
    const input = donation({ pledgeId: pledge.body.data.id });
    const created = await post("/fundraising/donations", input);
    expect(created.status).toBe(201);
    expect((await post("/fundraising/donations", input)).body.data.id).toBe(created.body.data.id);
    expect((await post("/fundraising/donations", { ...input, amount: "1300" })).status).toBe(409);
    const overview = (await get("/fundraising/overview")).body.data;
    expect(Number(overview.collectedAmount)).toBe(1200.50);
    expect(Number(overview.monthlyPledges)).toBe(2000);
    expect(Number(overview.pendingAmount)).toBe(799.50);
    expect(overview.trend).toHaveLength(6);
    expect((await get(`/fundraising/donations/${created.body.data.id}/receipt`)).body.data.receiptNumber).toMatch(/^DON-/);
    expect((await api.get(`/api/fundraising/donations/${created.body.data.id}/receipt`).set("Authorization", `Bearer ${token("ADMIN", otherOrgId)}`)).status).toBe(404);
    expect((await post(`/fundraising/donations/${created.body.data.id}/void`, { reason: "Duplicate bank record" })).status).toBe(200);
    expect((await post(`/fundraising/donations/${created.body.data.id}/void`, { reason: "Duplicate bank record" })).status).toBe(409);
    const after = (await get("/fundraising/overview")).body.data;
    expect(Number(after.collectedAmount)).toBe(0);
    expect(Number(after.pendingAmount)).toBe(2000);
    expect(await prisma.auditLog.count({ where: { orgId, action: "donation.received" } })).toBe(1);
    expect(await prisma.auditLog.count({ where: { orgId, action: "donation.voided" } })).toBe(1);
  });

  it("rejects invalid money, future receipts, missing references and forged fields", async () => {
    for (const values of [{ amount: "0" }, { amount: "-10" }, { amount: "2.123" }, { amount: "10000000000" },
      { method: "BANK" }, { currency: "USD" }, { orgId: otherOrgId.toString() }, { receivedAt: "2099-01-01T00:00:00Z" }]) {
      expect((await post("/fundraising/donations", donation(values))).status).toBe(422);
    }
    expect((await get("/fundraising/donations?pageSize=1000")).status).toBe(422);
  });

  it("returns stable directory metadata and safe teacher fields", async () => {
    const teachers = (await get("/admin/teachers?pageSize=1&search=nobody")).body.data;
    expect(teachers.items).toEqual([]);
    expect(teachers.meta.totalItems).toBe(0);
    expect(teachers.summary.total).toBe(0);
    const donors = (await get("/fundraising/donors?pageSize=1&search=Supporter")).body.data;
    expect(donors.meta.totalItems).toBe(1);
    expect(donors.items[0].totalGiven).toBe("0.00");
    expect((await get("/admin/subjects")).body.data.summary.total).toBe(0);
    expect((await get("/admin/students/summary")).body.data).toMatchObject({ total: 0, male: 0, female: 0, newAdmissions: 0 });
    expect((await get("/admin/guardians?search=missing")).body.data.items).toEqual([]);
  });

  it("stores upcoming events and excludes cancelled ones", async () => {
    const input = { title: "Staff meeting", location: "Main hall", startsAt: "2090-01-01T09:00:00Z", endsAt: "2090-01-01T10:00:00Z" };
    expect((await post("/admin/events", { ...input, endsAt: input.startsAt })).status).toBe(422);
    const event = await post("/admin/events", input);
    expect(event.status).toBe(201);
    const overview = (await get("/admin/overview")).body.data;
    expect(overview.academic.events.map((r: { id: string }) => r.id)).toContain(event.body.data.id);
    expect(overview.academic.admissions).toHaveLength(6);
    expect((await post(`/admin/events/${event.body.data.id}/cancel`, {})).status).toBe(200);
    expect((await get("/admin/overview")).body.data.academic.events).toEqual([]);
  });

  it("deduplicates simultaneous submissions and enforces positive amounts in the database", async () => {
    const input = donation();
    const replies = await Promise.all([
      post("/fundraising/donations", input), post("/fundraising/donations", input),
    ]);
    expect(replies.every((r) => r.status === 201)).toBe(true);
    expect(replies[0]!.body.data.id).toBe(replies[1]!.body.data.id);
    expect(await prisma.donation.count({ where: { orgId, idempotencyKey: input.idempotencyKey } })).toBe(1);
    await expect(prisma.donation.create({ data: {
      orgId, donorId: BigInt(donorId), campaignId: BigInt(campaignId), amount: "-1", method: "CASH",
      receivedAt: new Date(), recordedById: userId, idempotencyKey: randomUUID(), inputHash: "b".repeat(64),
    } })).rejects.toThrow();
  });

  it("handles year rollover when building six-month periods", () => {
    const periods = recentMonths(new Date("2026-01-04T12:00:00Z"));
    expect(periods[0]!.from.toISOString()).toBe("2025-08-01T00:00:00.000Z");
    expect(periods[5]!.to.toISOString()).toBe("2026-02-01T00:00:00.000Z");
  });
});
