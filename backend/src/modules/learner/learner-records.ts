import { Prisma } from "@prisma/client";
import { prisma } from "../../shared/db/prisma";
import catalog from "../teacher-workspace/quran-catalog.json";

// Internal read models: callers must resolve and authorize the student first.
export function attendanceSummary(records: { status: string }[]) {
  const counts = { PRESENT: 0, LATE: 0, ABSENT: 0, EXCUSED: 0 };
  for (const row of records) counts[row.status as keyof typeof counts]++;
  const denominator = counts.PRESENT + counts.LATE + counts.ABSENT;
  return { ...counts, markedDays: records.length,
    rate: denominator ? Math.round((counts.PRESENT + counts.LATE) * 100 / denominator) : null };
}

export function memorised(records: { surahId: number; ayahFrom: number; ayahTo: number; activity: string; observation: string }[]) {
  const keys = new Set<string>();
  for (const row of records) {
    if (row.activity !== "MEMORIZATION" || row.observation !== "INDEPENDENT") continue;
    const chapter = catalog.chapters.find(c => c.id === row.surahId);
    if (!chapter) continue;
    for (let ayah = Math.max(1, row.ayahFrom); ayah <= Math.min(chapter.ayahCount, row.ayahTo); ayah++) keys.add(`${row.surahId}:${ayah}`);
  }
  return keys;
}

const sessionFields = Prisma.validator<Prisma.QuranSessionSelect>()({
  id: true, surahId: true, ayahFrom: true, ayahTo: true, learnedOn: true,
  activity: true, observation: true, teacher: { select: { fullName: true } },
});

export async function readQuran(orgId: bigint, studentId: bigint, page: number) {
  const where = { orgId, studentId, voidedAt: null };
  const ranges = await prisma.quranSession.findMany({ where: { ...where, activity: "MEMORIZATION", observation: "INDEPENDENT" },
    select: { surahId: true, ayahFrom: true, ayahTo: true, activity: true, observation: true } });
  const keys = memorised(ranges);
  const total = await prisma.quranSession.count({ where });
  const sessions = await prisma.quranSession.findMany({ where, orderBy: [{ learnedOn: "desc" }, { id: "desc" }],
    skip: (page - 1) * 20, take: 20, select: sessionFields });
  const latest = await prisma.quranSession.findFirst({ where, orderBy: [{ learnedOn: "desc" }, { id: "desc" }], select: sessionFields });
  const chapters = catalog.chapters.map(c => ({ ...c, memorisedAyahs: Array.from({ length: c.ayahCount }, (_, index) => index + 1).filter(ayah => keys.has(`${c.id}:${ayah}`)).length }));
  const juzs = catalog.juzs.map(j => {
    let complete = 0, total = 0;
    for (const range of j.ranges) for (let ayah = range.from; ayah <= range.to; ayah++) { total++; if (keys.has(`${range.surahId}:${ayah}`)) complete++; }
    return { number: j.number, memorisedAyahs: complete, totalAyahs: total };
  });
  const totalAyahs = catalog.chapters.reduce((sum, c) => sum + c.ayahCount, 0);
  return { memorisedAyahs: keys.size, totalAyahs, percent: Math.round(keys.size * 1000 / totalAyahs) / 10,
    chapters, juzs, latestSession: latest, sessions,
    meta: { page, totalPages: Math.ceil(total / 20), totalItems: total, pageSize: 20 } };
}
