# MODERN ISLAMIC FOUNDATION Project Status

Last updated: `2026-10-16`

## Unified Madrasa Lifecycle (2026-10-16)

Applications is no longer a separate sidebar item or tab. Existing office
shortcuts route to Madrasas. The directory merges unprovisioned requests with
organizations, pending-first with bounded pagination; provisioned requests are
excluded to avoid duplicate school rows. Awaiting approval, awaiting setup and
declined states are searchable/filterable alongside created madrasa statuses.
Manage exposes independent approve/decline, onboarding review and office history.
The original server-side independent-review, IT setup and activation controls
remain in force. Summary cards count created organizations (labelled explicitly);
pending records have unknown learner/teacher counts rather than invented zeros.

## Madrasa Reference Layout Correction (2026-10-16)

The directory now follows the supplied hierarchy: separate Export list/Add
Madrasa actions, four global summary cards, a wide search row, status/location
filters, full-width desktop table, numbered rows and status badges. Locations
come from recorded branch locations, not invented region data. Assigned admins
counts active ADMIN accounts, not an assumption of one admin per madrasa.
CSV export includes all matching records up to 5000, rejects larger exports
instead of truncating, and escapes spreadsheet formulas. Manage opens an inline
madrasa section with linked onboarding review; Add Madrasa opens the existing
application form. No permission to edit classroom records is added.

## Institution Workspace: Users & Permissions (2026-10-16)

Super Admin has a read-only staff directory at `GET /api/platform/staff-directory`.
The new `tenant.staff-directory.read` grant excludes IT and school roles. Queries
allow only ADMIN, TEACHER and ACCOUNTANT, with bounded pagination, name/school
search and status filters. Responses expose names, roles and school scope only;
no contact details, credentials, parent accounts or child records are selected.
The responsive Users & Permissions page provides account review, role summaries,
and links to existing company-account and admin-onboarding workflows. It does
not grant permission-editing or staff invitation powers to Super Admin.
Backend directory tests (11), Flutter staff/login tests (12), typecheck and
Flutter analysis pass. The remaining institution modules are not yet complete.

## Institution Workspace: Madrasa Directory (2026-10-16)

Super Admin now has a separate Madrasas directory backed by `GET /api/platform/madrasas`.
It supports name/code search, status filtering, 25-row pagination, aggregate
registered learner and active teacher counts, and active administrator names.
The explicit `tenant.directory.read` permission belongs only to Super Admin;
IT and school roles cannot read it. No individual learner data or credentials
are returned. Mobile uses a list; desktop uses a table with read-only details.
Adding a madrasa links to the existing independent application/approval flow,
not a shortcut around IT setup and activation checks.

This is the first working institution page, not completion of the eight-page
proposal. Institution-wide permissions, curriculum, learning oversight, donor
funds, reports and communications remain subsequent work; SMS is not enabled.
Five backend directory tests and eleven Flutter directory/login tests pass;
backend typecheck and Flutter analysis pass.

## Platform Workspace Redesign (2026-10-15)

Refresh presentation: school headers and platform overview/register pages now
reuse WorkspaceRefreshButton with the same rounded refresh icon. Platform busy
states show a labelled spinner and disable repeat requests. Existing session,
filter and stale-record safeguards remain unchanged. All 39 targeted shared UI,
overview, list-refresh and platform layout tests passed.

Desktop sidebar parity: school and platform shells now use WorkspaceDesktopSidebar
with identical 250px expanded / 84px collapsed widths and a shared 1000px desktop
breakpoint. Platform header toggle padding matches school headers; native mobile
platform layouts keep their drawer even on tablets. All 67 scoped navigation/layout
tests and 12 shared-component tests passed, including explicit rail width checks.
Flutter analyzer reported no issues.

Sidebar controls: WorkspaceSidebarToggle now supplies open, close, expand and
collapse icons to school and platform shells. Super Admin/IT desktop sidebars
can collapse to an 84px rail; all mobile drawers have an explicit close button.
Platform collapse state survives page changes. Navigation permissions and busy
guards are unchanged. 113 targeted layout/navigation/keyboard tests and five
additional per-school-role drawer close tests passed; analyzer reported no issues.

Typography style: replaced the interface's Noto Sans Display family with bundled
Lato (400/500/600/700), including its license. Body text uses Medium and sidebar
menus Semibold; existing headline Bold weights now have a matching face. Explicit
navigation/public font overrides use the shared family token. Seventy-four targeted
tests passed, analyzer is clean, and the office render was visually inspected with
the real Lato assets. Decorative serif text and legacy media font assets are retained.

Readability update: shared body text is 16px, secondary text 14px and labels 15px.
Navigation, office metadata, metric labels, status badges, notices and tables
consume the shared sizes. System text scaling stays enabled; action tiles give
large text more room by omitting their decorative leading icon. All 43 targeted
design-system, platform, finance and dashboard layout tests passed.

Shared feedback and actions: finance/teacher notices and public form errors now
delegate to AfaqNotice; form errors retain live-region semantics. Finance and IT
quick actions use AfaqActionTile with disabled-state handling. Teacher tags use
the shared status badge. Removed the unreachable legacy office overview/panels;
Super Admin uses only PlatformOfficeDashboard. Role-specific permissions and
destinations remain unchanged.

Full-suite regression fixes: PublicBrand falls back to its mark in constrained
headers instead of overflowing. RecordTable has shared-token row-height fallbacks
when embedded outside the app theme. Mobile registration tests now assert the
existing family-registration route rather than the superseded Parent access page.

Verification: all 721 Flutter tests passed; analyzer reported no issues. The
office screenshot test also passed with buildAfaqTheme and its rendered image
was inspected. Web release build succeeded and preview port 8087 returned HTTP
200. Demo API port 4087 was offline; no database was recreated or credentials
changed. Physical Android testing was not performed in this pass.

Shared tables: RecordTable now inherits global DataTableTheme styling and uses
shared table tokens for header color, dimensions and spacing. Each table owns
an independent horizontal controller with a visible bottom scrollbar. Tests
cover theme inheritance, narrow-screen access to actions and disposal. All 42
targeted design-system, academic, finance, dashboard and teacher tests passed;
Flutter analyze reported no issues. No role permissions or data sources changed.

Shared metrics: TeacherMetric and platform office metrics now delegate to the
existing DashboardMetric used by school dashboards. Its card surface uses the
shared panel decoration. Values, labels, notes and role-specific data sources
are unchanged. Fifty targeted design-system, teacher, dashboard, finance and
platform layout tests passed after correcting the extraction compile error.

Shared badges: FinanceStatus, StatusPill, platform account and application statuses
now use AfaqStatusBadge. Styling is shared while status semantics remain local.
The badge supports optional icons and wrapping labels, including enlarged text.
Forty-eight targeted design-system, finance, academic and platform tests passed;
Flutter analyze reported no issues.

Shared-shell migration: platform navigation now reuses WorkspaceSidebar, the
same component used by school workspaces, with role-specific destinations and
a busy/disabled guard. WorkspaceHeaderSurface supplies the common header border,
surface and minimum height to both school and platform headers. Short screens
hide the decorative sidebar footer to preserve scrollable navigation. Forty-five
targeted regression tests passed and Flutter analyze reported no issues.

Shared design-system foundation: design_tokens.dart owns common colors, fonts,
panel/control radii and panel decoration. design_theme.dart now owns the root
Material theme and global button/input styling. adminTheme is a compatibility
delegate. Foundation palette aliases, SurfacePanel, office panels, platform shell
colors and selected teacher/finance primitives consume these shared definitions.
Role permissions/navigation are unchanged. Shared primitives are centralized;
page-specific charts, media layouts and mobile navigation remain specialized.

The office home now loads the five newest requests from the protected application
register API. Names, requested codes and decision labels replace the static
register description. A list failure is distinct from an empty register and does
not discard successfully loaded overview counts. Session-version checks prevent
late responses from being rendered after account/session replacement. Office
activity still opens the existing history page rather than streaming on home.

Reference-layout rebuild: Super Admin now uses a dedicated office dashboard,
not the old vertically stacked overview. It has a compact sans-serif welcome,
six horizontal metrics, a three-column overview row, a second three-column
work row and a mission banner. The shell uses a navy background, uppercase
AFAQ book mark and cool-white surfaces. Regional data explicitly remains
unconnected; no school counts, student charts or donation totals are fabricated.
Office history and request lists open the existing protected pages rather than
pretending to stream records on the home page. Desktop visual capture is
available via office_visual_capture_test.dart with CAPTURE_OFFICE=true.

Application cards now separate the school name, decision badge, requested code
and proposed school administrator. Badges use text and icons as well as color;
unknown statuses are explicitly unavailable. Code/email fields are selectable.
Decision actions and independent-review authorization are unchanged. Seventeen
targeted existing layout/application tests passed; Flutter analyze is clean.

Quick actions now use bordered, full-card interactive tiles in three desktop
columns, two medium-width columns or one mobile column. Hover and keyboard focus
have visible states. Targeted overview/layout tests verify tap and Enter-key
navigation at 390/1440px and blocked navigation while loading; all 15 passed.

Reference-inspired office overview: metric icons now have soft circular accents;
an application-status breakdown and next-step panel sit side by side on wide
screens and stack on mobile. All chart values come from the overview snapshot.
Missing/partial data and an empty application set have explicit states, not fake
percentages. Quick actions and an Afaq mission panel complete the page. No
student, donation, regional or security data was added to the office overview.

Follow-up: task pages now include role-specific guidance for applications,
company accounts, office/security history, service health and personal sessions.
The application workflow is explanatory, not a claim of completed onboarding.
The sidebar omits its decorative footer on short screens so landscape navigation
remains scrollable. Twenty-four targeted task/layout regression tests passed,
including enlarged text at 320px and reaching sessions in a 740x320 drawer;
Flutter analyze reported no issues.

Authenticated platform accounts now enter an Afaq-branded overview with a
responsive sidebar (desktop/tablet) or navigation drawer (mobile), instead of
the old welcome banner and chip-based console navigation.

- Super Admin: Overview, Madrassa applications, Company accounts, Office history.
- IT: Overview, System health, Audit trail, Madrassa setup, My sessions.
- Office overview uses real application/onboarding totals and links to filtered
  pending reviews and approved onboarding. Failed loads show unavailable values,
  not invented zero counts. IT health retains snapshot freshness checks.
- IT provisioning opens inline as a workspace page, not a nested modal window.
- Existing task forms, permission checks and session-expiry protections remain;
  this is a shell/home/navigation redesign, not a rewrite of every task form.

Verification: all 116 platform Flutter tests passed and Flutter analyze reported
no issues. Layout tests cover both roles at 320, 800 and 1440 pixels, including
role-specific navigation and overview failure states. The browser test script
now includes these workspace layout tests. Physical Android-device verification
has not been performed for this redesign.
The nine targeted Chromium workspace/overview tests also passed with mocked API
responses, and the release web build succeeded with the isolated local API at
port 4087. The loopback preview is served at port 8087; this is not a production
deployment.

## Family Onboarding Update (2026-10-09)

Email preparation now includes Afaq-branded HTML/plain-text drafts for family
approval and school-account password changes, plus a synthetic-data CLI preview.
The strict payloads reject extra fields such as passwords, receipts and child
records. Twelve template tests and backend typechecking passed. This is a
preview-only foundation: no provider, queue or automatic delivery is connected.
An offline capture CLI now saves synthetic drafts in private files, with atomic
publication and duplicate/conflict handling. It defaults to disabled, refuses
production capture and only accepts `.test` email addresses and login hosts.
All 19 email template/sandbox tests and backend typechecking passed. The planned
`afaq.africa` domain has not been configured or treated as a verified sender.
The agreed production layout is now captured in `backend/.env.production.example`:
apex web, `api.afaq.africa`, `noreply@afaq.africa` and planned support mailbox.
Email remains disabled, production secrets are empty, and local settings are
unchanged. This prepares deployment configuration without claiming live hosting.
An IT-only operational CLI, `npm run deployment:check -- --env-file <file>`, now
checks the planned production configuration offline and prints redacted results.
It makes no service connections and distinguishes automated blockers from manual
DNS/TLS, backup, access-control, email and payment acceptance checks. Passing
configuration checks is explicitly not a verified deployment.

A standalone TLS-only SMTP adapter and an explicit-file SMTP check CLI now exist.
They are not called by registration/password flows and no provider connection or
real send was performed. Connection checks require an explicit `--connect` flag;
configuration checks are offline. SMTP acceptance is not presented as delivery.
Fifty-four targeted tests and TypeScript checks passed. The npm audit still
reports 15 dependency issues, including one critical, outside Nodemailer; these
remain a production-readiness risk requiring a separate tested remediation.

### Dependency Remediation (2026-10-09)

The subsequent dependency remediation supersedes the 15-issue audit above:
`npm install` now reports zero known vulnerabilities. Express, Morgan, Vitest,
tsx and affected transitive dependencies were updated within their major lines.
Prisma/client remain 6.19.3; a scoped `@prisma/config` override pins `deepmerge-ts`
8.0.2 to address its advisory without upgrading the database tooling to Prisma 8.
The override requires continued compatibility checks on future Prisma upgrades.
Added regressions verify proxy trust handling and actual Prisma config loading.
CI now blocks high/critical dependency advisories. A clean npm audit is not a
claim of complete application security or a verified production deployment.
Verification after the updates: 115 targeted unit/HTTP tests and 20 isolated
family integration tests passed; all 31 migrations were replayed on a disposable
database, including the non-empty install guard and idempotent deploy check.
Prisma generation, backend typecheck and build passed. The real database was not
modified and existing deployed processes have not been rebuilt/restarted here.

### Local Runtime Verification (2026-10-09)

The previous disposable demo was no longer running and its temporary files were
absent. A new isolated demo was started with synthetic accounts and the patched
dependencies; no existing database was restored, reseeded or modified. The local
web preview responds on 8087 and API health on 4087. All five demo accounts passed
login, authorized reads, denied company/school cross-scope access and logout.
`smoke:demo` makes those checks repeatable without printing credentials or tokens.
The new demo uses new temporary credentials; production has not been deployed.

Public parent registration now creates a pending, school-scoped request, not an
authenticated account. School admins review requests in Family accounts, verify
identity and the applicant's private receipt, then atomically link an available
guardian and issue a family login number. One family account can access multiple
verified children. Duplicate submissions cannot replace a pending password;
approval/rejection removes the application's password hash. Office-rejected
requests can be resubmitted after clarification.

School and company accounts now have current-password-verified password changes
with session invalidation. School admins can reset a verified parent's password
within their scope, but cannot reset company or school-admin passwords through
that workflow. Forgot password remains an office-assisted request. Automated
email and production deployment are not complete: no email service is configured,
and the real `mms` database has not been migrated. The private demo was backed up
and upgraded independently. See backend/DEVELOPMENT.md for deployment boundaries.

Verification for this update: 113 selected Flutter VM tests, four Chromium
onboarding tests, 59 backend regression tests and 20 isolated MariaDB integration
tests passed. The isolated installer verified all 31 migrations, refusal to
overwrite a non-empty database and an idempotent migration deployment. These are
targeted suites, not a claim that every repository test was run. Backend
typechecking, a release web build and an Android debug APK build passed. The APK
has not been installed or exercised on a physical phone in this update.

The local preview uses web port 8087 and the isolated API on port 4087. Parent
requests begin at `/#/parent-access`; school admins review them under
`Family accounts > Registration requests`. Existing demo passwords were not
changed. Do not deploy the new API against the real database before the documented
backup, migration and coordinated API-worker replacement steps.

## 1. Current State

The backend remains in place. The React client has been retired in favor of Flutter for web, Android, and iOS. This is an active frontend migration, **not a release candidate**: the first Flutter app has authentication and selected read-only role views, but many former React workflows still need rebuilding.

## Native Mobile Entry and Navigation (2026-10-01)

Installed Android/iOS builds now start with a dedicated welcome screen, not
the public website homepage. Login, learner registration and office help share
a mobile app bar, back navigation and keyboard-aware forms without website
chrome. Terms and privacy stay inside the app with their existing
publication-pending notices. No policies or account-linking powers are invented.

Authenticated mobile workspaces keep role-specific bottom navigation and a
drawer, including on wide tablets, and omit the website copyright footer.
Safe areas protect content in landscape. Web, including phone browsers, keeps
the existing homepage, public header/footer and responsive desktop workspace.

Platform selection affects presentation only. Authentication endpoints,
server-assigned roles and backend access controls are unchanged. Native tokens
remain in memory; secure persistent sign-in and offline sync are not implemented.
A full native restart therefore still requires sign-in. iOS device builds and
physical-device native media playback are not verified in this stage.

Verification: clean Flutter analyzer, all 259 Flutter tests, Android arm64 debug
APK and release web build. The 25 new mobile tests cover platform selection,
zero-size startup/recovery, phone/tablet layouts, 2x text, keyboard clearance,
back navigation, role-scoped login/logout and learner-only registration.
Welcome/login previews were inspected with bundled fonts/icons. Auth/navigation
tests use mocked API responses; the running physical phone session was not
restarted or reinstalled. Uppercase R in flutter run loads the new entry flow.

## Android Homepage Layout Fix (2026-10-01)

The user's Infinix X6525 (Android 13) log confirms successful APK build,
installation and Flutter startup after completing SDK/NDK setup. It also exposed
a homepage layout assertion: zero available feature-strip width produced a
negative card width of -10. A regression test reproduced that exact failure
before the fix. The strip now handles zero width and uses a single column for
narrow constraints, preserving two/four columns at normal phone/desktop widths.

Verification: Flutter analyzer and all 234 tests pass, including 16 new cases
covering tiny widths, collapsed-width recovery, column breakpoints and full-page
phone/desktop resizing with working login navigation. The updated Android arm64
debug APK also builds successfully with API_BASE_URL=http://127.0.0.1:4000.
This is not verification of live native media playback; the running device
session was left untouched. Hot restart it with uppercase R to load the fix.

## Latest Learner Portal Stage (2026-10-01)

Lesson video/audio, images, PDFs and plain text now open inside the portal.
The lesson flow no longer offers external browser navigation. PDFs have page
and zoom controls; images support zoom/pan. Supported Android/iOS media uses
native video/audio controls and restricted provider WebViews. Other unsupported
formats show an in-app explanation rather than leaving the lesson.

Fresh signed authorization and live access checks remain; playback never
auto-completes lessons. Large-video uploads, transcoding, adaptive streaming
integration and DRM are NOT implemented. A provider/API must be selected first;
the integration boundary is documented in LEARNER_PORTAL_ARCHITECTURE.md.

Backend build and 118 tests pass. Flutter analyzer, 218 tests and release web
build pass. Chromium verifies actual PDF/image/text/video/audio, no new tabs,
mobile PDF/video, revocation, disposal and completion/session refresh. Native
controls use fake-platform tests; live provider embeds use mocked content.
The initial Android build's missing/unaccepted NDK blocker has since been
resolved (see the Android follow-up above). Actual Android/iOS media playback
remains unverified.

## Previous Courses Stage (2026-09-30)

My courses now has subject cards, search/subject/access filters, grid/list modes,
published curriculum, Continue learning, a lesson reader and saved completion.
Resources open in a browser/device viewer after fresh access authorization.
Paid/locked lessons and private/draft content retain backend access boundaries.
Completion preserves watch time and updates course progress, independently of
teacher assessment and Qur'an records. Native inline playback is not included.

Verification: backend build and 88 integration tests; clean Flutter analyzer,
183 tests and release web build; Chromium desktop/mobile course reading,
resource opening, persisted completion and reload retaining login/page.
Isolated browser fixtures were removed. Assignments, learner messaging, events,
settings, favorites and embedded media players remain future stages.
See [LEARNER_PORTAL_ARCHITECTURE.md](LEARNER_PORTAL_ARCHITECTURE.md).

## Previous School Records Stage (2026-09-28)

The learner home now includes live self-owned school records. Five new pages
provide Classes (week/list timetable), Attendance (calendar/log), Qur'an Progress
(Surah/Juz and history), Academic Progress (published marks) and Reports
(preview/authenticated web PDF). Existing course, progress, billing and update
routes are preserved. No learner can select another student's ID or view
parent-teacher conversations, draft marks or retracted reports.

Verification: backend build and 82 tests; Flutter analyzer, 170 tests and release
web build; Chromium desktop/mobile navigation, PDF download and reload retaining
both login and the selected section. This is a tested stage, not full reference
parity: assignments, learner messaging, events, richer subject/lesson UI and
settings remain. See [LEARNER_PORTAL_ARCHITECTURE.md](LEARNER_PORTAL_ARCHITECTURE.md).

## 2. Backend Status

Backend stack:

- Node.js
- Express
- TypeScript
- Prisma
- MariaDB
- Redis / BullMQ

Implemented backend areas:

- auth, refresh rotation, logout, logout-all
- public online learner signup with fixed LEARNER permissions, an independent student profile, atomic session creation, and registration rate limiting
- organizations and users
- students and guardians
- classes and enrollments
- attendance
- finance core
- payments, reconcile flow, receipts, Snippe integration
- parent portal APIs
- announcements
- hifdh progress
- LMS subjects, courses, lessons, learner access grants, and course billing foundation
- public inquiry submission and office inbox
- reports and exports

Verification available:

- `npm run typecheck`
- `npm run build`
- `npm run smoke:core`
- `npm run smoke:write`
- `npm run smoke:public-inquiry`
- `npm test`

Automated backend integration coverage currently includes:

- auth login / refresh / logout
- expired-token handling
- protected reports access
- role-boundary checks for admin, accountant, teacher, and parent access
- learner self-service signup, password confirmation, duplicate email and rate-limit checks
- learner self-service access checks
- LMS authoring role boundaries for subject and course management
- paid lesson/media access, branch-scoped inquiries, and payment confirmation checks

## 2.1 RBAC Status

Current RBAC direction is now explicitly enforced at multiple layers:

- Flutter role-based navigation (for usability, not authorization)
- backend route-level `requireRole(...)`
- service-level teacher ownership checks on sensitive records

Current intended role shape:

- `ADMIN`
  - system oversight, admissions, student governance, finance oversight, user oversight, preview capability
- `ACCOUNTANT`
  - finance home, finance workspace, payments, receipts, expenses, finance reporting, public inquiry finance follow-up
- `TEACHER`
  - teaching home, class readiness, attendance, roster, hifdh, teacher-scoped student/class access
- `PARENT`
  - family home, own child attendance, own finance, own receipts, own hifdh, parent-facing updates
- `LEARNER`
  - own study, courses, school timetable, attendance, Qur'an records, published assessments/reports, invoices and learner-visible notices only

Important note:

- preview access for `ADMIN` is treated as an elevated oversight capability, not a collapse of role boundaries
- the formal source of truth for access rules now lives in [RBAC_MATRIX.md](RBAC_MATRIX.md)
- the `LEARNER` role now has phase-1 code foundation and rollout guidance in [RBAC_MATRIX.md](RBAC_MATRIX.md)
- the proposed LMS, media, and content-protection architecture now lives in [LMS_CONTENT_BLUEPRINT.md](LMS_CONTENT_BLUEPRINT.md)
- LMS blueprint now also defines subject ownership, teacher authoring, and admin publishing workflow

## 3. Flutter Frontend Status

Current stack: Flutter / Dart for web, Android and iOS. The Flutter app includes a responsive photo-led public home, split-panel sign-in and direct learner registration, dedicated contact/parent-access/sign-in-help pages, in-memory auth/refresh, responsive role navigation and read-only data views for accountant, parent and learner, plus the admin and teacher read/write workflows listed below. Backend roles determine access; there is no role selection on the login page.

The following React-era UI work is **not** available in Flutter yet: the office inquiry inbox, automated account recovery, student and guardian editing, legacy hifdh score entry, invoice/payment/expense actions, detailed parent-child views, course studio, learner lesson media, and complete learner payment flows. Corresponding backend endpoints may exist; this list concerns the client.

The first reference-design dashboard stage adds a fixed/collapsible navy sidebar, gold navigation, page search, soft-color metric cards, and data-backed charts. Admin Students and Classes now include creation forms; Admin Attendance now supports daily registers, audited corrections, check-in times and saved-history review. The teacher workspace now includes scoped classes/students, support follow-ups, exact Qur'an recording and daily attendance. A separate fundraising module now backs the Donations page. Full reference parity is not yet complete; see the expansion milestones below.

Flutter verification: `flutter analyze`, `flutter test`, and `flutter build web --release`. iOS builds require macOS/Xcode and have not been run here. Device builds and full API integration still need verification.

## 4. Automation

The repository CI and local release gate now run Flutter analyze, tests, and web build instead of React/Vite/Playwright. Backend typecheck, build, tests, and smoke coverage remain separate. Removed Playwright tests must be replaced with Flutter widget/integration coverage as workflows are ported.

## 5. Next Milestones

1. Finish the supplied ADMIN reference screens first: detailed curriculum/Qur'an,
   reports, communications, settings and supporting APIs.
2. Refine the remaining admin create/edit/export workflows and first-run states
   with role, tenant, ownership and financial audit checks.
3. Continue the supplied TEACHER references with school curriculum, assessments,
   report publication, private parent messaging and durable offline sync. See
   TEACHER_WORKSPACE_ARCHITECTURE.md for the data and access contracts.
4. Add Flutter integration tests against a seeded backend on web and Android;
   verify iOS on macOS.
5. Configure production HTTPS API, CORS, platform signing and deployment before release.

## Admin reference implementation: backend expansion (2026-09-25)

- Design contract: ADMIN_PANEL_ARCHITECTURE.md maps every supplied admin screen to
  its domain, missing entities and delivery requirements. Other role layouts are
  not included in this reference redesign.
- Added tenant-scoped admin overview, six-month admissions, teacher assignments,
  subject directory, student demographics, guardian lookup and scheduled events.
- Added normalized donors, campaigns, pledges and donation ledger with decimal TZS
  amounts, idempotent posting, auditable voids, receipt data and paginated lists.
  Pledges do not count as income. Aggregate totals exclude voided entries.
- Two additive migrations preserve existing data. MariaDB check constraints and
  composite tenant foreign keys enforce the new financial/event invariants.
- Remaining: detailed academic curriculum/class coverage, passage-level Qur'an
  completion, report jobs/exports, communications
  provider outbox, notification/search integration and offline conflict handling.
  These are designed but not presented as finished features.

## Admin reference implementation: Flutter workflows (2026-09-25)

- Rebuilt the overview around six real metric cards, admissions bars, assessment
  coverage, recent activity, donation trends, quick navigation and scheduled events.
- Added independent Teachers and Subjects pages with search, pagination, account/
  subject creation and actual teaching/course assignments.
- Added Donations with donor/campaign/pledge forms, received-payment entry,
  partial pledge collections, receipt preview, void confirmation, charts and
  separately paginated fundraising directories.
- Added student admission (new or existing guardian) and class creation forms.
  Student demographic cards use full-tenant counts, not only the current page.
- Kept admin-specific navy/gold styling separate from other roles. Responsive
  cards/tables, fixed navigation and mobile branding follow the reference direction.
- No fake growth percentages, teacher ratings/leave, provider delivery badges or
  offline sync states. The full set of supplied reference screens is still in progress.
- Browser preview uses the local API and the rebuilt Flutter web app at
  http://127.0.0.1:8080. Migrations were applied without resetting existing records.

Verification for this admin stage:
- Backend typecheck and build passed; 16 integration tests passed using
  `npx vitest run --testTimeout=30000` (the default 5-second auth test timeout
  was too short under local concurrent build load).
- All 47 Flutter tests passed; Flutter analyze reported no issues.
- Chromium checks returned HTTP 200 for overview, teachers, subjects, donations,
  students and classes; desktop and mobile layouts were inspected with no
  JavaScript errors. Test browser sessions were logged out afterward.
- All 18 migrations are applied. Native Android/iOS builds are not verified here.
- Final release web build passed with `--no-wasm-dry-run`; the local browser
  preview was rebuilt after the final session-isolation change.

## Admin Attendance Register (2026-09-25)

- Added an explicit ADMIN/assigned-TEACHER register API; non-academic roles remain
  blocked. The legacy bulk-mark API remains TEACHER-only.
- Applied migration 19 without resetting existing data: optional local check-in
  time, optimistic row versions and database validation checks.
- Added atomic partial saves, correction explanations, actor/before/after audit
  history, stale-write detection and recoverable MariaDB concurrency conflicts.
- Saved historical rows remain in the original class after a student transfer.
  Unmarked students are distinct from absentees. Past unrecorded memberships
  are not reconstructed; check-in uses Africa/Dar_es_Salaam school time.
- Flutter admin Attendance now has date/class filters, four daily status cards,
  a searchable/paged register, seven-day line chart, saved-status ring chart,
  selected-student bulk editing, check-in/notes and a history dialog.
- Failed saves retain form entries; stale forms require reload and unsaved changes
  require discard confirmation. No offline/synced claims or fabricated attendance.

Verification:
- Backend typecheck/build and all 24 tests passed.
- Flutter analyze passed and all 56 widget/unit tests passed, including nine new
  attendance tests at 320, 768 and 1440 widths.
- Release web build passed; native Android/iOS builds remain unverified.
- Chromium end-to-end check passed using an isolated temporary school: sign-in,
  class selection, attendance correction, saved version/check-in verification in
  the database, history and desktop/mobile editor inspection. No browser runtime
  errors; the test session and all its fixtures were removed afterward.

## Teacher Reference Workspace: First Working Slice (2026-09-25)

- Added separate Dashboard, My Classes, My Students, Qur'an Tracking and
  Attendance screens using the supplied teacher layout direction. Existing
  teacher online courses and notices remain accessible.
- Applied additive migration 20: date-bounded weekly timetables, exact Qur'an
  learning sessions and student support follow-ups, with tenant-composite keys.
- Admin manages timetable entries from the Classes page. Current scheduled
  lessons appear on the teacher dashboard and weekly class schedule; overlapping
  class/teacher bookings are rejected transactionally.
- Teachers see only their current assigned classes/students and account branch.
  New workspace and attendance APIs recheck the active account and school.
- Students have search/class/support filters and individual learning profiles.
  Follow-ups can be added and completed without erasing their history.
- Qur'an recording uses verified chapter/ayah bounds and juz filtering, a
  selectable ayah grid, separate activities and teacher observations. Only
  independently observed memorisation contributes to the unique-ayah count.
  Retries reuse the same operation ID; corrections retain the voided original.
- Unsaved Qur'an forms prompt before changing context, navigating, refreshing or
  signing out. Unconfirmed saves retain their exact details for retry.
- Teacher attendance reuses the versioned register and correction workflow.
  Late arrivals count as present in its saved-record summary and trend;
  unmarked students remain unmarked.
- No invented assessment/report metrics, notification counts, lesson completion
  percentages or offline/trusted-device badges.

Remaining teacher reference pages: Subjects & Lessons, Assessments, Monthly
Reports, Parent Communication and Offline Sync. These have design contracts in
TEACHER_WORKSPACE_ARCHITECTURE.md, not duplicated or pretend implementations.
Native Android/iOS builds and offline storage remain unverified/unimplemented.

Verification:
- Backend typecheck/build and all 32 tests passed, including eight teacher
  integration tests for tenant/branch isolation, revoked access, canonical ayah
  validation, retry safety, follow-ups and timetable conflicts.
- Flutter analyze reported no issues and all 67 widget/unit tests passed.
  Teacher layouts are covered at 320, 768 and 1672 widths, including failed-save
  retry, unsaved-change protection and asynchronous access-revocation handling.
- Release web build passed. Chromium verified teacher sign-in, class-filtered
  navigation, student profile, exact ayah selection/save and scoped attendance.
  The saved passage was checked in the database; desktop/mobile layouts were
  inspected with zero browser runtime errors. All isolated fixtures were removed.
## Browser Refresh Session Recovery (2026-09-25)

- Browser sign-in now uses a scoped HttpOnly refresh cookie, exact-origin
  credentialed CORS and an origin/header check on browser authentication routes.
  Access tokens remain in memory; passwords and refresh tokens are not placed
  in localStorage/sessionStorage. Native token authentication is unchanged.
- Startup waits for server-validated session recovery before rendering a public
  or signed-in page. A temporary connection failure offers retry, not a silent
  redirect home. Disabled users and suspended schools cannot restore sessions.
- The selected workspace page is remembered per account/role/tab and checked
  against the current role's navigation. Filters and unsaved forms are not saved.
- Browser Web Locks serialize cookie rotation across supported tabs. A shared
  sign-out marker prevents offline logout from restoring the session on reload;
  server logout revokes the refresh token and clears the cookie when reachable.
- Development normalizes localhost/127.0.0.1 API hosts to the browser hostname.
  Production requires same-site HTTPS and configured WEB_APP_ORIGINS (see
  backend/DEVELOPMENT.md). No database migration was required.

Verification:
- Browser-session backend tests passed; the pre-CRUD backend suite passed all
  38 tests. Flutter analyze passed and all 77 widget/unit tests passed.
- Release web build passed. Chromium verified teacher on localhost and admin on
  127.0.0.1: login, two reloads retaining the selected page, logout and reload
  staying signed out. Concurrent teacher tabs also restored successfully with
  one active rotating refresh session. No browser runtime errors.
## Admin CRUD: Student Records (2026-09-25)

- Students retains its existing add/view flow and now has a per-student Actions
  menu for personal-detail editing, change history, archiving and restoration.
  Read-only roles do not receive these mutation controls.
- Each edit loads the current record, prefills the form and allows optional
  details to be cleared. A reason is required. Failed saves retain entries;
  conflicting/stale records ask the user to close and reopen the form.
- Archiving is reversible: madrasa pupils become Inactive, leave the active
  teacher roster, and keep class/guardian links plus learning/payment history.
  They can be found under the Inactive filter and restored. No hard deletion.
- The new admin endpoints recheck active account/school and current branch.
  A locked transaction combines revision checking, changes and actor/reason/
  before/after audit history. Duplicate admission numbers and invalid dates are
  rejected. The history dialog shows the latest 20 management changes.
- Online learner login access is deliberately not changed by pupil archiving.
  Class placement and guardian management remain separate from personal editing.
  No schema migration was required.

Verification:
- Backend build and all 43 tests passed (serialized run; the earlier parallel
  run hit four 5-second timeouts under concurrent browser/compiler load).
- Flutter analyze passed and all 87 tests passed, including ten new cases for
  edit/clear, confirmation, archive/restore, failed saves, history, role visibility
  and layouts at 320, 768 and 1440 widths. Release web build passed.
- Chromium exercised the actual admin edit, archive, restore and history controls.
  The persisted name/status and all three audit events were checked in MariaDB;
  zero browser runtime errors and all isolated fixtures removed.

Scope still pending: complete lifecycle controls for classes/staff and other
admin modules; consistent audit/version protection for legacy mutation APIs.
This is the first working admin CRUD slice, not completion of all system CRUD.
## Git Repository Scope Correction (2026-09-25)

- This checkout has independent repositories at the project root and backend/.
  Earlier stage commits were present in the root but absent from the nested
  backend history, which explains VS Code's remaining M/U badges.
- Backend commit 24e394a synchronizes the previously root-committed source,
  migrations and tests, and stops tracking dist/, node_modules/ and .env.
  These files remain on disk and are now covered by backend/.gitignore.
- No Git directory was deleted, no history was rewritten and nothing was pushed.
  Future backend stages must check and commit both repositories.
- The old backend commit already contained .env. Removing it from tracking does
  not remove historical copies; credentials must be rotated if shared.
## Visible Student Removal (2026-09-25)

- Admin > Students > Actions now names the reversible action "Remove student",
  with a removal icon, a required reason and an explicit confirmation that this
  removes the pupil from active lists without permanently deleting history.
- Admin student lists default to Active, so a successfully removed pupil leaves
  the current list. Inactive/All filters still expose the retained record and
  Restore student remains available. Read-only lists keep their prior default.
- Permanent deletion has not been enabled; its policy is awaiting the user's
  choice. This change does not claim to implement hard deletion.
- Flutter analyze and 21 targeted management/academic-page tests passed,
  including a directory-level test for successful removal and active filtering.
  Release web build passed and the browser preview was rebuilt.
- Backend build passed; the nested backend worktree stayed clean afterward,
  confirming generated files no longer produce M/U entries there.
- Chromium verified the visible Remove menu item, confirmation, successful save,
  disappearance from the active list, retained inactive record and one audit
  event. Zero browser runtime errors; all temporary fixtures were removed.

## Admin CRUD: Class Records (2026-09-27)

- Admin > Classes now offers Edit class, Change history and Remove class.
  Read-only accounts retain View without mutation controls.
- Editing supports name, level, academic year, teacher assignment/unassignment
  and optional capacity. Campus is deliberately immutable in this flow.
- Academic year changes are blocked once records are linked. Capacity edits
  cannot go below the current assigned-student count. Changing a teacher requires
  cancelling current/future timetable entries first; new assignments must use
  active school-wide teachers or teachers in the class's branch.
- Removal follows the user's explicit policy: permanently delete only empty
  classes; block any class with students, enrollments, attendance, fee structures,
  timetable records, Quran sessions or support notes, including inactive,
  cancelled and historical records. The UI lists the blocking dependencies.
- Confirmation and a reason are required. Current-account/tenant/branch checks,
  optimistic revisions, transactional row locks and audit logs protect edits
  and removal. Deleted classes retain their before-state, reason and actor in
  the audit log. No schema migration or deletion of existing school data.
- Backend stage commits: root 074942c; nested backend df759ee.

Verification:
- Backend build passed; all 51 backend tests passed with one worker and a
  20-second test timeout. The first full run hit a 5-second browser-session
  timeout; that file and then the entire suite passed on repeat.
- Eight new backend tests cover scopes, invalid inputs, stale revisions,
  teacher/timetable guards, all child relations, retained audit history and
  permanent empty-class removal. A schema-coverage test requires future Class
  child relations to be included in the removal guard.
- Flutter analyze passed and 33 targeted widget tests passed, including 12 new
  class-management tests. Coverage includes failed-save retention, confirmation,
  protected records, directory refresh, read-only access and 320/768/1440 layouts.
- Release Flutter web build passed. Local preview runs on localhost:8080 and
  the development API on localhost:4000 while those processes remain running.
- Chromium automation did not complete the end-to-end class flow: Flutter's
  accessibility tree disappeared during navigation/menu interaction. Browser
  end-to-end verification is not claimed; API/widget coverage above passed.
  All isolated browser fixtures were cleaned up.

Remaining scope: CRUD/lifecycle controls for staff and other admin modules;
student permanent-deletion policy is separate and has not been changed.


## 2026-09-27 - Parent portal: scoped family workspace

- Added a dedicated parent workspace using the supplied navy/gold, white-card
  references while retaining the established MIF brand. Live pages: Dashboard,
  My Children/profile/current timetable, monthly Attendance, Qur'an Progress,
  School updates, invoice/payment history and Support.
- Child selection is shared across parent navigation. Child-specific requests
  show loading rather than stale records when switching children. Parent views
  cannot access the admin attendance/register routes or mutate student records.
- Parent API checks active account, tenant, role and current guardian-child
  links on every request. Cross-campus linked siblings are supported; unrelated
  and foreign-tenant children return 404. Responses disable caching. Student
  internal notes, raw teacher notes and private teacher contact details are not
  exposed by the new workspace.
- Attendance shows real marked dates, never fabricated school days or absences.
  Late counts as attended and excused is excluded from the rate denominator.
  Qur'an progress deduplicates overlapping independent memorisation ayahs,
  excludes voided sessions, and distinguishes reading/revision from memorisation.
- Add-child/profile corrections direct parents to verified school office contacts.
  This does not create a ticket or grant a guardian link automatically. Payments
  are read-only invoice/history views, not a newly implemented checkout.
- Backend stage commits: nested backend 8ba93e9; root 77811d4. No migration was
  required for this stage; existing relational data and indexes were reused.
- See PARENT_PORTAL_ARCHITECTURE.md for explicit next-stage models and contracts.

Verification:
- Backend TypeScript build and all 56 backend tests passed (one worker, 20-second
  timeout), including five new parent security/data-semantics integration tests.
- All 110 Flutter tests passed after updating the older navigation expectation:
  parents now have their own read-only Attendance page, not an admin register.
  Ten new parent tests cover 320/768/1440 layouts, child switching/loading,
  profile/timetable, office verification guidance, Qur'an pagination, calendar
  semantics, empty data and retry. Flutter analyze passed.
- Release web build passed. Chromium exercised real cookie login and authenticated
  reloads for dashboard and all six other parent sections, plus mobile attendance.
  Scoped API requests returned 200 and no JavaScript runtime errors were observed.
  This smoke test restores navigation preferences; button workflows are covered
  by widget tests, not claimed as a complete browser interaction suite.
- Desktop and mobile screenshots were inspected. Browser fixtures were isolated
  and removed. No real messages, report publication or payment writes were made.

Remaining parent scope: assessment/academic grades and published report/PDF
workflow, private teacher messaging, published parent events/booking, resources,
persisted notification/language/theme settings, account export/deactivation,
and reviewed parent support/absence/correction requests. These are not represented
as working features or filled with the screenshots' example data. Existing admin
and teacher follow-up scope remains separate.


## 2026-09-27 - Private family Messages

- Added parent Messages and teacher Parent Communication with a shared responsive
  inbox, private conversation, student context, contact search, pagination and
  manual refresh. Existing navigation preferences and page indices are preserved.
- New relational conversation/message tables scope every record to its tenant,
  linked guardian, student and current assigned class teacher. Every request
  rechecks current access; reassignment, unlinking or account suspension revokes
  access. Other guardians have separate conversations. Admin roles cannot read
  these private conversations through this API.
- Message sends use immutable client IDs for safe retries after lost responses.
  Draft text clears only after server confirmation; navigation asks before
  discarding an unsent or uncertain draft. Read receipts advance only through a
  validated message ID and do not mark later unseen messages read.
- Backend stage committed in root 03d4c25 and nested backend 536c2f4. Additive
  migration 202609272300_add_family_messages applied to the local development DB.
  No existing school records were removed or rewritten.

Verification:
- Backend build and all 63 backend tests passed, including seven new messaging
  tests for tenant/guardian isolation, revocation, pagination, read watermarks,
  concurrent idempotent sends, validation and composite foreign keys.
- All 122 Flutter tests passed, including 12 messaging tests for responsive
  layouts, draft retention, safe retries, permission errors and double-send
  prevention. Flutter analyze reports no issues; release web build passed.
- Chromium verified cookie login for parent and teacher, opening a real private
  thread, parent send, teacher read/reply and exactly one persisted record per
  send. No JavaScript runtime errors were observed. Flutter inbox selection
  required screenshot-based pointer coordinates in the automation; composer
  and Send interactions used accessibility locators.
- Desktop and 390px mobile screenshots inspected. All isolated browser fixtures,
  including the interrupted initial automation fixture, were removed.

Messages are text-only in-app communication, not SMS/WhatsApp, attachments,
realtime push or offline storage. Parents must refresh for new messages. Academic
grades/published reports/PDFs, events/booking, resources and persisted preferences
remain future stages; the screenshot example data is not fabricated as live data.


## 2026-09-28 - Reviewed assessments and parent Academic Progress

- Teacher Assessments supports class/subject selection, roster snapshots, draft
  scores, parent-facing feedback and submission for review. Blank scores remain
  unassessed, zero remains a valid score, and marks cannot exceed the maximum.
- Admin Assessment Review provides read-only review, return-for-correction,
  publication and reasoned retraction. Parents never see drafts or submitted
  marks. Every release retains an immutable snapshot; republication creates a
  new release. Retraction hides the previous release without deleting history.
- Parent Academic Progress supports child/year selection, per-subject averages,
  assessment history and approved feedback. Only the linked child's results are
  serialized, never peers' records. Averages explicitly use equally weighted
  normalized assessment percentages, not official term grades or class ranks.
- Added tenant-composite foreign keys and assessment dependency guards for class
  removal. Migration 202609280030_add_assessments was applied to the local DB;
  existing school records were not rewritten or removed.
- Creation retries reuse a client UUID. Result/state writes require the current
  revision; failed saves retain entries and drafts require explicit discard.
  Existing sidebar indices and remembered-page preferences were preserved.
- Backend commits: root 371e2b1, nested backend 8ced226.

Verification:
- TypeScript build and all 69 backend tests passed. Six new integration tests
  cover workflow permissions, roster validation, stale edits, blank/zero marks,
  guardian isolation, immutable publication/retraction, branch/account revocation
  and cross-tenant foreign keys. Class-removal relation coverage was extended.
- All 136 Flutter tests passed, including 14 new assessment tests for responsive
  320/768/1440 layouts, read-only review, save/create retry, draft retention,
  confirmation, double-submit prevention, pagination and child switching.
- Flutter analyze reports no issues; final release web build passed.
- Chromium verified teacher save/submit, submitted results hidden from parent,
  administrator publication, exactly one release and correct parent results
  after cookie-authenticated reload. Desktop/mobile screenshots inspected; no
  JavaScript errors observed. All isolated browser fixtures were removed.

Remaining: official reporting periods/report cards/PDF, weighted term grading,
class ranking, assessment rubric/class-subject assignment configuration and
assessment metadata correction/cancellation workflows. This stage implements
reviewed assessment results, not the complete Reports screenshot or full CRUD
for every admin module. Events/resources and remaining portal features retain
their previously documented scope.


## 2026-09-28 - Reviewed learning reports and protected PDFs

- ADMIN can create named monthly/term/year reporting periods, review teacher
  submissions, return them with a reason, publish and retract reports.
- Assigned TEACHER can prepare one report per learner/period, save parent-facing
  feedback, refresh source data and submit a private draft for review.
- Reports combine this child's published assessments, recorded attendance and
  independent Quran memorisation in the selected class/period. Missing records
  are not invented, and no weighted grade or class rank is claimed.
- Submitted reports require fresh source data before publication. Every release
  is an immutable snapshot. Retracted assessment sources withhold dependent
  reports from parent lists/downloads until corrected and republished.
- PARENT Reports includes child selection, report cards, history, preview and
  authenticated PDF downloads on web. Existing navigation indices/session
  restoration remain intact. Native clients can preview but not download files
  in this stage.
- PDFKit embeds bundled DejaVu fonts (license included). Ship backend/assets/fonts
  in production. Publication dates in PDF and parent screens use the school's
  Tanzania date, not a UTC date that can differ near midnight.
- Added ReportingPeriod, StudentReport, ReportRelease and ReportAssessmentSource
  with restrictive tenant-composite foreign keys and class-removal guards.
  Additive migration 202609280100_add_student_reports was applied locally; no
  existing school records were rewritten or removed.
- Backend stage commits: root 7476c0c, nested backend 7ed7113; publication-date
  correction is a separate follow-up commit, not an amend.

Verification:
- Backend build passed; all 76 backend tests passed. Seven new report integration
  tests cover private drafts, idempotency, stale/concurrent writes, changed source
  data, future/empty periods, publication/retraction, protected PDF, guardian and
  teacher revocation, tenant relations and history preservation.
- All 150 Flutter tests passed, including 14 new report tests for responsive
  320/768/1440 layouts, draft retention/discard, confirmation, read-only review,
  duplicate-save prevention, pagination and child switching.
- Flutter analyze reported no issues and the release web build passed.
- Chromium verified teacher save/submit, parent submission invisibility, admin
  publication, parent preview and an actual PDF download, then cookie-authenticated
  refresh retaining the Reports page. Desktop/mobile screenshots inspected, no
  JavaScript errors observed. Isolated browser fixtures were removed.
- Downloaded PDF text was inspected for scores, attendance and feedback. A
  UTC/school-date mismatch found during inspection was corrected and retested.
- Local preview uses port 8180; port 8080 was already occupied by another service
  and was not stopped or reconfigured.

Remaining: reporting periods are currently append-only; configurable grading,
ranks, curriculum completeness, batch actions, period corrections/archive,
full bidirectional Arabic PDF layout and native downloads are not implemented.
Events/resources, support workflows and other unfinished portal features remain
separate stages. This is a working Reports flow, not full CRUD for every module.
