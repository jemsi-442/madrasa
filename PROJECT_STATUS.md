# MODERN ISLAMIC FOUNDATION Project Status

Last updated: `2026-09-25`

## 1. Current State

The backend remains in place. The React client has been retired in favor of Flutter for web, Android, and iOS. This is an active frontend migration, **not a release candidate**: the first Flutter app has authentication and selected read-only role views, but many former React workflows still need rebuilding.

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
  - own study, course access, progress, invoices, and notices only

Important note:

- preview access for `ADMIN` is treated as an elevated oversight capability, not a collapse of role boundaries
- the formal source of truth for access rules now lives in [RBAC_MATRIX.md](RBAC_MATRIX.md)
- the `LEARNER` role now has phase-1 code foundation and rollout guidance in [RBAC_MATRIX.md](RBAC_MATRIX.md)
- the proposed LMS, media, and content-protection architecture now lives in [LMS_CONTENT_BLUEPRINT.md](LMS_CONTENT_BLUEPRINT.md)
- LMS blueprint now also defines subject ownership, teacher authoring, and admin publishing workflow

## 3. Flutter Frontend Status

Current stack: Flutter / Dart for web, Android and iOS. The Flutter app includes a responsive photo-led public home, split-panel sign-in and direct learner registration, dedicated contact/parent-access/sign-in-help pages, in-memory auth/refresh, responsive role navigation and read-only data views for accountant, teacher, parent and learner, plus the admin read/write workflows listed below. Backend roles determine access; there is no role selection on the login page.

The following React-era UI work is **not** available in Flutter yet: the office inquiry inbox, automated account recovery, student and guardian editing, attendance marking, hifdh entry, invoice/payment/expense actions, detailed parent-child views, course studio, learner lesson media, and complete learner payment flows. Corresponding backend endpoints may exist; this list concerns the client.

The first reference-design dashboard stage adds a fixed/collapsible navy sidebar, gold navigation, page search, soft-color metric cards, and data-backed charts. Admin Students and Classes now include creation forms; Admin Attendance now supports daily registers, audited corrections, check-in times and saved-history review. Teacher class views still respect teacher-scoped API results. A separate fundraising module now backs the Donations page. Full reference parity is not yet complete; see the expansion milestones below.

Flutter verification: `flutter analyze`, `flutter test`, and `flutter build web --release`. iOS builds require macOS/Xcode and have not been run here. Device builds and full API integration still need verification.

## 4. Automation

The repository CI and local release gate now run Flutter analyze, tests, and web build instead of React/Vite/Playwright. Backend typecheck, build, tests, and smoke coverage remain separate. Removed Playwright tests must be replaced with Flutter widget/integration coverage as workflows are ported.

## 5. Next Milestones

1. Finish the supplied ADMIN reference screens first: detailed curriculum/Qur'an,
   reports, communications, settings and supporting APIs.
2. Refine the remaining admin create/edit/export workflows and first-run states
   with role, tenant, ownership and financial audit checks.
3. Redesign other role workspaces only after their reference images are supplied;
   retain their current access boundaries in the meantime.
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
