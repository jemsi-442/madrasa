# Learner School Records

`/api/learner/workspace` is read-only. Authentication, tenant context, LEARNER
role, live account and active/trial school checks run before resolving the
active student linked by `learnerUserId`. No endpoint accepts a student ID.
All responses are `no-store`. Independent learners keep the existing courses,
lesson progress and billing APIs even when no school class is assigned.

- `overview`: own monthly attendance, confirmed memorisation, this calendar
  year's published assessment averages, today's class slots, latest released
  report and existing learner-visible announcements.
- `classes?date=YYYY-MM-DD`: Monday-Sunday occurrences for the current assigned
  class only. Each occurrence must be within the slot's validity dates;
  cancelled slots are excluded. This is not a historical enrolment timetable.
- `attendance?month=YYYY-MM`: actual records only. Late counts as attended,
  excused is excluded from the rate, no denominator yields null. Missing dates
  are neither absences nor assumed holidays. Learners cannot mark attendance.
- `quran?page=1`: non-voided sessions and distinct independently memorised
  ayahs, with catalog-based Surah/Juz totals. Reading, revision and practice
  are not treated as confirmed memorisation. Internal teacher notes are omitted.
- `academic?year=YYYY`: published, non-retracted assessment snapshots projected
  to this student's result only; no peer marks or class rank. Each normalized
  assessment contributes equally, not an invented term grade.
- `reports?page=1` and `reports/:releaseId/pdf`: own published report snapshots
  only. Retraction of a source assessment also hides the dependent report/PDF.
  PDF delivery uses the existing authenticated JSON download contract.

Shared read models are internal functions, not authorization entry points.
Parent routes still verify guardian links; learner routes resolve only self.
The student portal does not expose private parent-teacher conversations or
pretend assignments, chat, account deletion, preferences or events are implemented.
