import { z } from "zod";
import { directoryQuerySchema } from "../fundraising/fundraising.schemas";

export const teacherDirectorySchema = directoryQuerySchema.extend({
  status: z.enum(["ACTIVE", "DISABLED"]).optional(),
});
export const eventSchema = z.object({
  title: z.string().trim().min(2).max(150),
  location: z.string().trim().min(2).max(200),
  startsAt: z.string().datetime({ offset: true }),
  endsAt: z.string().datetime({ offset: true }),
}).strict().refine((value) => Date.parse(value.endsAt) > Date.parse(value.startsAt), {
  path: ["endsAt"], message: "End time must be after the start time",
});
export type TeacherDirectoryQuery = z.infer<typeof teacherDirectorySchema>;
export type EventInput = z.infer<typeof eventSchema>;
