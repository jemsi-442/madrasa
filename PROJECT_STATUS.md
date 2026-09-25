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

Current stack: Flutter / Dart for web, Android and iOS. The Flutter app includes a responsive photo-led public home, split-panel sign-in and direct learner registration, dedicated contact/parent-access/sign-in-help pages, in-memory auth/refresh, responsive role navigation and read-only data views for admin, accountant, teacher, parent and learner. Backend roles determine access; there is no role selection on the login page.

The following React-era UI work is **not** available in Flutter yet: child admissions and the office inquiry inbox, automated account recovery, student and guardian editing, attendance marking, hifdh entry, invoice/payment/expense actions, detailed parent-child views, course studio, learner lesson media, and complete learner payment flows. Corresponding backend endpoints may exist; this list concerns the client.

Flutter verification: `flutter analyze`, `flutter test`, and `flutter build web --release`. iOS builds require macOS/Xcode and have not been run here. Device builds and full API integration still need verification.

## 4. Automation

The repository CI and local release gate now run Flutter analyze, tests, and web build instead of React/Vite/Playwright. Backend typecheck, build, tests, and smoke coverage remain separate. Removed Playwright tests must be replaced with Flutter widget/integration coverage as workflows are ported.

## 5. Next Milestones

1. Port the parent portal and learner course/lesson experience with dedicated pages and tests.
2. Port staff write workflows, including attendance, registry, finance, and course studio, with role and ownership checks.
3. Add Flutter integration tests against a seeded backend on web and Android; verify iOS on macOS.
4. Configure production HTTPS API, CORS, platform signing, and deployment before release.
