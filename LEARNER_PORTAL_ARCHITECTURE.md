# Learner Portal

## Implemented: School Records (2026-09-28)

The student reference screens guide layout, not data. The existing MIF brand,
navy/gold chrome, typography and responsive Flutter design system are retained.
No reference names, scores, ranks, progress claims or private conversations are
seeded into live accounts.

`LearnerPortalPage` adds a data-backed home and five self-only areas:

| Page | Live data and actions |
| --- | --- |
| Home | Current class, monthly attendance, distinct memorised ayahs, published assessment average, today's timetable, announcements and latest report preview/PDF |
| Classes | Previous/current/next week, week/list modes, dated class slots, honest unassigned/empty states |
| Attendance | Month navigation, calendar, actual status/arrival/note records, rate explanation; no learner write access |
| Qur'an Progress | Surah/Juz switches, independently memorised ayahs, latest session and paginated learning history |
| Academic Progress | Year filter, own published assessment marks/feedback and subject averages; no fabricated term grade/rank |
| Reports | Own released report cards/history, preview and authenticated web PDF download |

The five existing learner section paths and indices remain unchanged. New
sections are appended, so remembered routes and existing course/progress/billing
links continue working. School record pages are dedicated pages, not generic
staff views. A refresh restores the selected section using the existing browser
session mechanism. Filter choices are in-memory and reset on a browser reload.

`ParentAcademics.learner` and `ParentReports.learner` reuse presentation only:
they call separate self-scoped learner APIs, never guardian endpoints or an
arbitrary child ID. The attendance calendar is shared presentation as well.
Published report preview/download follows the existing platform implementation;
native PDF download is not implemented, and its button remains disabled.

## Authorization and Meaning

The backend contract is in
`backend/src/modules/learner/WORKSPACE.md`. Every new endpoint checks the live
account, organization and active student ownership. Explicit student/parent ID
query overrides are rejected. Returned records omit internal student/Qur'an
notes, teacher contact information and other learners' assessment results.

Unmarked attendance dates are not treated as absent or school holidays. Late
counts as attended; excused is excluded. The dashboard/calendar use a rounded
whole-number attendance rate; report PDFs retain the existing two-decimal rate.
Qur'an memorisation is deduplicated across valid independent sessions. Reading,
revision, tajweed review and attempts needing practice are not memorised ayahs.

Assessments are visible only after publication, projected to the learner's own
result. Reports and their PDFs disappear when the report or a source assessment
is retracted. Report history is an immutable publication snapshot, not a live
gradebook. School dates use Africa/Dar_es_Salaam (+03:00).

## Implemented: Courses and Lesson Reader (2026-09-30)

`LearnerCoursesPage` replaces the generic course list at its existing route.
Published courses have searchable subject/instructor/title cards, subject and
access filters, grid/list modes and personal lesson completion counts. Curriculum
dialogs show published modules and lessons; Continue learning finds the first
accessible incomplete lesson. Draft/unlisted lessons are excluded from counts
and curriculum. Restricted lessons remain disabled, with server-side access
checks on each read, progress update and resource request.

`LearnerLessonReader` displays reading text and lesson resources. Mark complete
saves the signed-in learner's progress, prevents duplicate in-flight submissions,
preserves prior watch time and refreshes curriculum/cards after closing. Failed
saves remain retryable and do not display false completion. Completion is
self-reported study progress, not teacher assessment or Qur'an memorisation.

Resource opening requests fresh delivery authorization, then requires a user
click to launch the browser/device viewer. Missing sources, locked assets,
expired links and failed launches have explicit states. Script/credential URLs
are rejected. Signed delivery rechecks live access, including revoked grants.
External viewers can expose the source URL; this is not DRM or an inline player.
No learner or organization identifiers are accepted from completion forms.

Verification: backend build and all 88 integration tests pass; Flutter analyzer
is clean and all 183 tests pass (13 new course/reader checks, including 320px,
390px and desktop layouts). Release web build succeeds. Chromium verification
uses isolated temporary records to check course/curriculum navigation, real
signed-resource redirection to a local test viewer, persisted completion and
session/page retention after reload. Desktop/mobile screenshots were inspected;
no browser JavaScript errors were reported. Fixtures were removed afterward.

## Remaining Reference Areas

- Lesson media: embedded playback, player-driven progress, favorites and
  recommendations remain. Resource opening currently uses an external viewer.
- Assignments: needs class/course task allocation, deadlines, submissions,
  teacher review and attachment permissions before showing task actions.
- Learner Messages: needs an explicit learner-teacher communication policy and
  separate participant scoping. Existing parent-teacher conversations stay private.
- Events: requires real scheduling/registration data, not example calendars.
- More & Settings: profile/password/preferences/resource/export/account lifecycle
  need supported APIs, privacy review and confirmations. No fake toggles, live-chat
  status or destructive account button is rendered.
- No new self-marking attendance, self-grading, arbitrary child access, class
  ranks, invented trends or video-call links are introduced.

## School Records Verification (2026-09-28)

- Backend build and all 82 integration tests pass, including six new learner
  scope/records/publication tests and parent regression coverage.
- Flutter analyzer is clean; all 170 widget/unit tests pass, including 20 new
  navigation, mobile/desktop, filtering, empty-state, retry and preview checks.
- Release web build succeeds. Chromium verification with isolated fixtures
  covers home, all five new pages, refresh preserving each selected page/session,
  own PDF preview/download, existing courses/progress/billing, and 390px mobile.
- Browser test fixtures are removed afterward. Desktop/mobile screenshots and
  a text-extracted downloaded PDF were inspected. No JS errors were reported.
- Android/iOS device builds and production deployment were not tested here.
