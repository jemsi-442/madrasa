import { z } from "zod";

export const recordId = z.string().regex(/^[1-9]\d{0,18}$/);
const money = z.string().regex(/^\d{1,10}(\.\d{1,2})?$/)
  .refine((value) => Number(value) > 0, "Amount must be greater than zero");
export const directoryQuerySchema = z.object({
  page: z.coerce.number().int().min(1).max(100000).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(10),
  search: z.string().trim().max(100).default(""),
});
export const donorSchema = z.object({
  fullName: z.string().trim().min(2).max(150),
  email: z.string().trim().email().max(150).optional(),
  phone: z.string().trim().min(8).max(30).optional(),
}).strict();
export const campaignSchema = z.object({
  title: z.string().trim().min(2).max(150),
  description: z.string().trim().max(1000).optional(),
  goalAmount: money,
}).strict();
export const pledgeSchema = z.object({
  donorId: recordId,
  campaignId: recordId,
  amount: money,
  dueOn: z.string().date(),
}).strict();
export const donationSchema = z.object({
  donorId: recordId,
  campaignId: recordId,
  pledgeId: recordId.optional(),
  amount: money,
  method: z.enum(["CASH", "BANK", "MOBILE_MONEY"]),
  reference: z.string().trim().min(1).max(100).optional(),
  receivedAt: z.string().datetime({ offset: true })
    .refine((value) => Date.parse(value) <= Date.now(), "Receipt date cannot be in the future"),
  idempotencyKey: z.string().uuid(),
}).strict().refine((input) => input.method === "CASH" || Boolean(input.reference), {
  path: ["reference"], message: "Bank and mobile money entries need a reference",
});
export const voidDonationSchema = z.object({
  reason: z.string().trim().min(5).max(500),
}).strict();
export type DirectoryQuery = z.infer<typeof directoryQuerySchema>;
export type DonorInput = z.infer<typeof donorSchema>;
export type CampaignInput = z.infer<typeof campaignSchema>;
export type PledgeInput = z.infer<typeof pledgeSchema>;
export type DonationInput = z.infer<typeof donationSchema>;
