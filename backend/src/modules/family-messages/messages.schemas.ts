import { z } from "zod";

export const messageId = z.string().regex(/^[1-9]\d{0,18}$/).refine(value => BigInt(value) <= 9223372036854775807n);
export const inboxQuery = z.object({
  page: z.coerce.number().int().min(1).max(100000).default(1),
  search: z.string().trim().max(100).default(""),
}).strict();
export const historyQuery = z.object({ before: messageId.optional() }).strict();
export const conversationInput = z.object({ studentId: messageId, contactId: messageId }).strict();
export const messageInput = z.object({ clientId: z.string().uuid(), body: z.string().trim().min(1).max(2000) }).strict();
export const readInput = z.object({ throughId: messageId }).strict();
