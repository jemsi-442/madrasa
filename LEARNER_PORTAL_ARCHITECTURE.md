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

## Implemented: Web Lesson Playback (2026-10-01)

Video and audio lesson assets now offer Play in app on the web portal. Native
browser controls provide play/pause, seeking, volume and supported fullscreen
controls without autoplay. YouTube/Vimeo sources use a sandboxed embedded player.
PDFs and other attachments retain their existing external viewer flow; Android
and iOS retain Open in browser until a native player is implemented.

Every player open/reload obtains fresh authorization. Inline sources must match
the configured API origin and the selected asset's signed delivery route. Direct
media and embeds both pass through live entitlement checks on that route, with
no-store responses. Provider URLs are parsed by host and video ID; arbitrary
HTML, credentials, misleading hosts and malformed provider URLs are rejected.
YouTube links become privacy-enhanced embed URLs; Vimeo unlisted hashes survive
normalization. Provider query parameters cannot enable automatic playback.

Retry removes the old player before requesting a new link. Closing/disposal
pauses direct media, clears its source and unloads iframes. Errors, slow loads,
expired links and blocked external launches have explicit recovery actions.
Playback never submits completion or watch-time estimates automatically. The
existing Mark complete action remains the learner's explicit choice.

Limitations: a signed redirect can expose its upstream URL and cannot revoke
already downloaded/buffered content. The download control hint is not DRM.
Provider embedding restrictions, codecs and source availability still apply.
Inline players need a current backend deployment because embedded sources now
use signed redirects too. No schema migration or new package is required.

Verification: backend build and 106 tests; clean Flutter analyzer, all 205
Flutter tests and release web build. Chromium checks use generated local video/audio, real signed
redirection and database access revocation. They verify playback, teardown,
mobile layout, explicit completion and refresh. The iframe is tested using a
mock provider response after checking its real signed redirect; live YouTube/
Vimeo playback and Android/iOS builds were not tested. Temporary fixtures are
removed after the browser run.

Implementation references: [Flutter HTML platform views](https://api.flutter.dev/flutter/widgets/HtmlElementView/HtmlElementView.fromTagName.html),
[HTML video controls](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/video),
[iframe restrictions](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/iframe)
and [YouTube embedding](https://developers.google.com/youtube/player_parameters).

## Implemented: In-App Lesson Resources (2026-10-01)

This stage supersedes the external-resource and native-player limitations above.
Lesson resources have one action: Play in app for audio/video, View in app for
documents/images. There is no external browser fallback in the lesson flow.

- Web audio/video retains native browser controls and sandboxed provider embeds.
- Android/iOS uses video_player for direct audio/video and webview_flutter for
  provider embeds. Top-level navigation is restricted to the signed delivery
  route and canonical provider players; unsupported desktop playback stays in
  the app with an explanation. Controllers are disposed on close/reload.
- PDFs render with pdfrx, with page navigation, scrolling and zoom. Internal PDF
  destinations work; external document links never launch another app or tab.
- Raster image attachments support zoom, pan and reset. Plain-text attachments
  render selectable text, never HTML, with a 1 MiB text limit and load timeout.
- Images/PDF/text are recognized from attachment MIME metadata, falling back to
  extensions only when metadata is absent or generic. No schema migration.
  SVG, HTML, ZIP and unsupported Office documents show an in-app explanation
  instead of executing content or launching a browser.
- Every open/reload still requires fresh authorization and an exact signed API
  delivery URL. Revocation blocks new delivery; already loaded content is not
  DRM-protected and cannot be recalled. Playback does not auto-complete lessons.

Hosting requirements: serve direct playable media rather than a sharing page.
Use HTTPS in production, correct MIME types, byte-range support for seeking,
and allow the portal origin through CORS for PDFs, images and text, including
the final storage/CDN response after redirects. Hosting/CORS failures stay in
the viewer with retry instructions. Bundle the pdfrx web assets in deployment.
Package versions are locked to the project's Flutter 3.38.5 toolchain.

Verification: backend build and 118 tests; Flutter analyzer, 218 tests and
release web build. Chromium checks real video/audio playback, a generated
two-page PDF (navigation/zoom), image/text rendering, unsupported attachments,
no external tabs, revoked access, disposal, mobile PDF/video, completion and
session refresh. Screenshots were inspected and temporary fixtures removed.
Native controls/late initialization/disposal are covered with a fake platform.
No device/emulator is available; Android debug build was attempted but blocked
by the unaccepted/missing NDK 28.2.13676358 SDK component. iOS and live provider
playback remain unverified; embedded-provider content is mocked in browser tests.

### Large-Video Upload Integration Boundary

Large/resumable uploads, transcoding and adaptive streaming are NOT implemented.
A provider/API has not been selected. The intended integration is:

1. Authorized staff request a scoped upload session from the backend.
2. The app uploads directly to the provider using resumable/multipart upload,
   showing progress, cancellation and retry without proxying large files through
   Express or putting provider credentials in Flutter.
3. Verified, idempotent provider webhooks mark processing/ready/failed status.
4. Authorized delivery issues short-lived provider playback access; the viewer
   consumes the provider's supported stream/SDK inside the lesson.

The current player accepts direct browser/device-supported media and approved
YouTube/Vimeo embeds. Do not assume HLS/DASH plays in every browser: add the
chosen provider SDK or adaptive-streaming adapter and test it when that API is
integrated. Upload limits, expiry, CORS, permissions and billing need provider
configuration, not a larger Express JSON body limit.

## Remaining Reference Areas

- Lesson media: device verification, large/resumable uploads, provider-specific
  adaptive streaming, player-driven progress, favorites and recommendations remain.
  Supported lesson resources now use in-app viewers; unsupported formats do not
  launch externally.
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
