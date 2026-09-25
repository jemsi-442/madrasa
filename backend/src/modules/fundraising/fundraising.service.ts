import { createHash } from "node:crypto";
import { Prisma } from "@prisma/client";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import type { CampaignInput, DirectoryQuery, DonationInput, DonorInput, PledgeInput } from "./fundraising.schemas";

const tenant = (actor: AuthenticatedUser) => {
  if (actor.role !== "ADMIN") throw new HttpError(403, "Administration access required");
  return BigInt(actor.orgId);
};
const pagination = (q: DirectoryQuery) => ({ skip: (q.page - 1) * q.pageSize, take: q.pageSize });
const meta = (q: DirectoryQuery, count: number) => ({
  page: q.page, pageSize: q.pageSize, totalItems: count, totalPages: Math.ceil(count / q.pageSize),
});
const names = {
  donor: { select: { id: true, fullName: true } },
  campaign: { select: { id: true, title: true } },
} satisfies Prisma.DonationInclude;
const audit = (tx: Prisma.TransactionClient, actor: AuthenticatedUser, action: string, entityType: string, id: bigint) =>
  tx.auditLog.create({ data: {
    orgId: BigInt(actor.orgId), actorUserId: BigInt(actor.userId), action, entityType, entityId: id.toString(),
  } });

async function validateLinks(tx: Prisma.TransactionClient, orgId: bigint, donorId: bigint, campaignId: bigint) {
  const donor = await tx.donor.findFirst({ where: { id: donorId, orgId }, select: { id: true } });
  const campaign = await tx.fundraisingCampaign.findFirst({ where: { id: campaignId, orgId }, select: { id: true, status: true } });
  if (!donor || !campaign) throw new HttpError(404, "Donor or campaign not found");
  if (campaign.status !== "ACTIVE") throw new HttpError(409, "This campaign is closed");
}

export async function createDonor(actor: AuthenticatedUser, input: DonorInput) {
  const orgId = tenant(actor);
  return prisma.$transaction(async (tx) => {
    const row = await tx.donor.create({ data: { orgId, fullName: input.fullName, email: input.email ?? null, phone: input.phone ?? null } });
    await audit(tx, actor, "donor.created", "Donor", row.id);
    return row;
  });
}

export async function createCampaign(actor: AuthenticatedUser, input: CampaignInput) {
  const orgId = tenant(actor);
  return prisma.$transaction(async (tx) => {
    const row = await tx.fundraisingCampaign.create({ data: {
      orgId, title: input.title, description: input.description ?? null, goalAmount: input.goalAmount,
    } });
    await audit(tx, actor, "campaign.created", "FundraisingCampaign", row.id);
    return row;
  });
}

export async function createPledge(actor: AuthenticatedUser, input: PledgeInput) {
  const orgId = tenant(actor);
  return prisma.$transaction(async (tx) => {
    const donorId = BigInt(input.donorId), campaignId = BigInt(input.campaignId);
    await validateLinks(tx, orgId, donorId, campaignId);
    const row = await tx.donationPledge.create({ data: {
      orgId, donorId, campaignId, amount: input.amount, dueOn: new Date(input.dueOn),
    } });
    await audit(tx, actor, "pledge.created", "DonationPledge", row.id);
    return row;
  });
}

export async function recordDonation(actor: AuthenticatedUser, input: DonationInput) {
  const orgId = tenant(actor);
  // An explicit field order gives retries a stable fingerprint, independent of JSON key order.
  const inputHash = createHash("sha256").update(JSON.stringify([
    input.donorId, input.campaignId, input.pledgeId ?? null,
    new Prisma.Decimal(input.amount).toFixed(2), input.method, input.reference ?? null,
    new Date(input.receivedAt).toISOString(),
  ])).digest("hex");
  const previous = async () => {
    const row = await prisma.donation.findUnique({
      where: { orgId_idempotencyKey: { orgId, idempotencyKey: input.idempotencyKey } }, include: names,
    });
    if (row && row.inputHash !== inputHash) throw new HttpError(409, "This submission was already used for a different donation");
    return row;
  };
  const existing = await previous();
  if (existing) return existing;
  try {
    return await prisma.$transaction(async (tx) => {
      const donorId = BigInt(input.donorId), campaignId = BigInt(input.campaignId);
      await validateLinks(tx, orgId, donorId, campaignId);
      const pledgeId = input.pledgeId ? BigInt(input.pledgeId) : null;
      if (pledgeId && !await tx.donationPledge.findFirst({ where: { orgId, id: pledgeId, donorId, campaignId } })) {
        throw new HttpError(404, "Matching pledge not found");
      }
      const row = await tx.donation.create({ data: {
        orgId, donorId, campaignId, pledgeId, amount: input.amount, method: input.method,
        reference: input.reference ?? null, receivedAt: new Date(input.receivedAt),
        recordedById: BigInt(actor.userId), idempotencyKey: input.idempotencyKey, inputHash,
      }, include: names });
      await audit(tx, actor, "donation.received", "Donation", row.id);
      return row;
    });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      const retried = await previous();
      if (retried) return retried;
    }
    throw error;
  }
}

export async function voidDonation(actor: AuthenticatedUser, id: string, reason: string) {
  const orgId = tenant(actor);
  return prisma.$transaction(async (tx) => {
    const row = await tx.donation.findFirst({ where: { id: BigInt(id), orgId } });
    if (!row) throw new HttpError(404, "Donation not found");
    const changed = await tx.donation.updateMany({ where: { id: row.id, orgId, status: "RECEIVED" }, data: {
      status: "VOIDED", voidedAt: new Date(), voidedById: BigInt(actor.userId), voidReason: reason,
    } });
    if (!changed.count) throw new HttpError(409, "This donation has already been voided");
    await audit(tx, actor, "donation.voided", "Donation", row.id);
    return tx.donation.findUniqueOrThrow({ where: { id: row.id }, include: names });
  });
}

export async function listDonors(actor: AuthenticatedUser, query: DirectoryQuery) {
  const orgId = tenant(actor);
  const where: Prisma.DonorWhereInput = { orgId, ...(query.search ? { OR: [
    { fullName: { contains: query.search } }, { email: { contains: query.search } }, { phone: { contains: query.search } },
  ] } : {}) };
  return prisma.$transaction(async (tx) => {
    const total = await tx.donor.count({ where });
    const rows = await tx.donor.findMany({ where, ...pagination(query), orderBy: [{ fullName: "asc" }, { id: "asc" }] });
    const totals = await tx.donation.groupBy({ by: ["donorId"], where: {
      orgId, donorId: { in: rows.map((row) => row.id) }, status: "RECEIVED",
    }, _sum: { amount: true }, _max: { receivedAt: true } });
    return { items: rows.map((row) => {
      const total = totals.find((item) => item.donorId === row.id);
      return { ...row, totalGiven: total?._sum.amount ?? "0.00", lastDonationAt: total?._max.receivedAt ?? null };
    }), meta: meta(query, total) };
  });
}

export async function listCampaigns(actor: AuthenticatedUser, query: DirectoryQuery) {
  const orgId = tenant(actor), where = { orgId, title: { contains: query.search } };
  return prisma.$transaction(async (tx) => {
    const total = await tx.fundraisingCampaign.count({ where });
    const rows = await tx.fundraisingCampaign.findMany({ where, ...pagination(query), orderBy: [{ createdAt: "desc" }, { id: "desc" }] });
    const totals = await tx.donation.groupBy({ by: ["campaignId"], where: { orgId, campaignId: { in: rows.map((row) => row.id) }, status: "RECEIVED" }, _sum: { amount: true } });
    return { items: rows.map((row) => {
      const collected = totals.find((item) => item.campaignId === row.id)?._sum.amount ?? new Prisma.Decimal(0);
      return { ...row, collectedAmount: collected, progressPercent: collected.div(row.goalAmount).mul(100).toFixed(1) };
    }), meta: meta(query, total) };
  });
}

export async function listDonations(actor: AuthenticatedUser, query: DirectoryQuery) {
  const orgId = tenant(actor);
  const where: Prisma.DonationWhereInput = { orgId, ...(query.search ? { OR: [
    { donor: { fullName: { contains: query.search } } }, { reference: { contains: query.search } },
    { campaign: { title: { contains: query.search } } },
  ] } : {}) };
  const [total, items] = await prisma.$transaction([
    prisma.donation.count({ where }),
    prisma.donation.findMany({ where, ...pagination(query), include: names, orderBy: [{ receivedAt: "desc" }, { id: "desc" }] }),
  ]);
  return { items, meta: meta(query, total) };
}

export async function listPledges(actor: AuthenticatedUser, query: DirectoryQuery) {
  const orgId = tenant(actor);
  const where = { orgId, donor: { fullName: { contains: query.search } } };
  return prisma.$transaction(async (tx) => {
    const total = await tx.donationPledge.count({ where });
    const rows = await tx.donationPledge.findMany({ where, ...pagination(query), include: names, orderBy: [{ dueOn: "asc" }, { id: "asc" }] });
    const sums = await tx.donation.groupBy({ by: ["pledgeId"], where: { orgId, pledgeId: { in: rows.map((r) => r.id) }, status: "RECEIVED" }, _sum: { amount: true } });
    return { items: rows.map((row) => {
      const received = sums.find((sum) => sum.pledgeId === row.id)?._sum.amount ?? new Prisma.Decimal(0);
      return { ...row, receivedAmount: received, outstandingAmount: Prisma.Decimal.max(row.amount.minus(received), 0) };
    }), meta: meta(query, total) };
  });
}

// UTC month boundaries are explicit in the response; no browser-dependent date math.
export function recentMonths(now = new Date()) {
  return Array.from({ length: 6 }, (_, index) => ({
    from: new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 5 + index, 1)),
    to: new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 4 + index, 1)),
  }));
}

export async function fundraisingOverview(actor: AuthenticatedUser) {
  const orgId = tenant(actor), months = recentMonths(), current = months[5]!;
  return prisma.$transaction(async (tx) => {
    const collected = await tx.donation.aggregate({ where: { orgId, status: "RECEIVED" }, _sum: { amount: true } });
    const donors = await tx.donor.count({ where: { orgId } });
    const pledged = await tx.donationPledge.aggregate({ where: { orgId, dueOn: { gte: current.from, lt: current.to } }, _sum: { amount: true } });
    const pending = await tx.$queryRaw<Array<{ total: Prisma.Decimal | null }>>`
      SELECT SUM(GREATEST(p.amount - COALESCE(d.received, 0), 0)) AS total
      FROM donation_pledges p
      LEFT JOIN (SELECT pledge_id, SUM(amount) AS received FROM donations
        WHERE org_id = ${orgId} AND status = 'RECEIVED' GROUP BY pledge_id) d ON d.pledge_id = p.id
      WHERE p.org_id = ${orgId}`;
    const trend = [];
    for (const month of months) {
      const sum = await tx.donation.aggregate({ where: { orgId, status: "RECEIVED", receivedAt: { gte: month.from, lt: month.to } }, _sum: { amount: true } });
      trend.push({ month: month.from.toISOString().slice(0, 7), amount: sum._sum.amount ?? "0.00" });
    }
    const byCampaign = await tx.donation.groupBy({ by: ["campaignId"], where: { orgId, status: "RECEIVED" }, _sum: { amount: true }, orderBy: { _sum: { amount: "desc" } }, take: 5 });
    const campaigns = await tx.fundraisingCampaign.findMany({ where: { orgId, id: { in: byCampaign.map((row) => row.campaignId) } }, select: { id: true, title: true } });
    const topTotal = byCampaign.reduce((sum, item) => sum.plus(item._sum.amount ?? 0), new Prisma.Decimal(0));
    return {
      currency: "TZS", timeZone: "UTC", collectedAmount: collected._sum.amount ?? "0.00", totalDonors: donors,
      monthlyPledges: pledged._sum.amount ?? "0.00", pendingAmount: pending[0]?.total ?? "0.00", trend,
      distribution: [
        ...byCampaign.map((row) => ({ name: campaigns.find((c) => c.id === row.campaignId)!.title, amount: row._sum.amount })),
        { name: "Other campaigns", amount: (collected._sum.amount ?? new Prisma.Decimal(0)).minus(topTotal) },
      ],
    };
  });
}

export async function donationReceipt(actor: AuthenticatedUser, id: string) {
  const orgId = tenant(actor);
  const row = await prisma.donation.findFirst({ where: { id: BigInt(id), orgId }, include: {
    ...names, organization: { select: { name: true } }, recordedBy: { select: { fullName: true } },
  } });
  if (!row) throw new HttpError(404, "Donation not found");
  const { inputHash: _hash, idempotencyKey: _key, ...receipt } = row;
  return { ...receipt, receiptNumber: `DON-${row.id.toString().padStart(8, "0")}` };
}
