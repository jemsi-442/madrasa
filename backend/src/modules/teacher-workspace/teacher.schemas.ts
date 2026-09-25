import { z } from "zod";
import catalog from "./quran-catalog.json";

export const recordId = z.string().regex(/^[1-9]\d{0,17}$/);
export const schoolDay = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(value => {
  const date = new Date(value);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}, "Choose a valid date");
export const directoryQuery = z.object({
  classId: recordId.optional(),
  search: z.string().trim().max(100).default(""),
  support: z.enum(["all", "open"]).default("all"),
  page: z.coerce.number().int().min(1).max(100000).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(10),
}).strict();
export const sessionQuery = z.object({
  studentId: recordId,
  surahId: z.coerce.number().int().min(1).max(114),
  page: z.coerce.number().int().min(1).max(100000).default(1),
}).strict();
export const sessionInput = z.object({
  clientId: z.string().uuid(),
  studentId: recordId,
  classId: recordId,
  surahId: z.number().int().min(1).max(114),
  ayahFrom: z.number().int().min(1),
  ayahTo: z.number().int().min(1),
  activity: z.enum(["READING", "MEMORIZATION", "REVISION", "TAJWEED"]),
  observation: z.enum(["INDEPENDENT", "WITH_SUPPORT", "NEEDS_PRACTICE"]),
  learnedOn: schoolDay,
  note: z.string().trim().max(1000).default(""),
}).strict().refine(input => input.ayahFrom <= input.ayahTo &&
  input.ayahTo <= (catalog.chapters[input.surahId - 1]?.ayahCount ?? 0),
{ message: "Select ayahs within this surah", path: ["ayahTo"] });
export const voidInput = z.object({ reason: z.string().trim().min(5).max(255) }).strict();
export const supportInput = z.object({
  studentId: recordId, classId: recordId, clientId: z.string().uuid(),
  note: z.string().trim().min(5).max(500),
}).strict();
const time = z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/);
export const timetableInput = z.object({
  weekday: z.number().int().min(1).max(7),
  startsAt: time, endsAt: time,
  validFrom: schoolDay, validUntil: schoolDay,
  subject: z.string().trim().min(2).max(100),
  focus: z.string().trim().max(255).default(""),
  room: z.string().trim().max(100).default(""),
}).strict().refine(input => input.startsAt < input.endsAt, {
  message: "The lesson must end after it starts", path: ["endsAt"],
}).refine(input => input.validFrom <= input.validUntil &&
  new Date(input.validUntil).getTime() - new Date(input.validFrom).getTime() <= 370 * 86400000,
{ message: "Choose a teaching period of no more than one year", path: ["validUntil"] });

export type DirectoryQuery = z.infer<typeof directoryQuery>;
export type SessionQuery = z.infer<typeof sessionQuery>;
export type SessionInput = z.infer<typeof sessionInput>;
export type SupportInput = z.infer<typeof supportInput>;
export type TimetableInput = z.infer<typeof timetableInput>;
