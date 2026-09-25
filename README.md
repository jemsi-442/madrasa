# MODERN ISLAMIC FOUNDATION

MODERN ISLAMIC FOUNDATION is a cross-platform school and online-learning system. The Express API remains the source of truth; a Flutter client now targets web, Android, and iOS.

This repository follows the technical direction defined in [madrasa_management_system_technical_documentation_tanzania_2026.md](madrasa_management_system_technical_documentation_tanzania_2026.md).

## Stack

- Backend: Node.js, Express, TypeScript
- Frontend: Flutter, Dart
- Database: MariaDB
- ORM: Prisma
- Cache / Queues: Redis, BullMQ
- Payments: Snippe

## Repository Layout

```text
backend/   Express API, Prisma schema, scripts, modules
frontend/  Flutter client for web, Android, and iOS
scripts/   Local helper scripts
```

## Current Backend Scope

Implemented backend modules include:

- Authentication and refresh token rotation
- Organizations and users
- Students and guardians
- Classes and enrollments
- Attendance
- Finance core
- Snippe payments and webhooks
- Parent portal APIs
- Announcements
- Hifdh progress
- LMS subject and course authoring foundation
- Reporting and exports

## RBAC Direction

The system follows five roles with controlled separation of access:

- `ADMIN`
  - full platform oversight
  - admissions, students, guardians, classes, reporting, and preview access
- `ACCOUNTANT`
  - finance dashboards, invoices, payments, receipts, expenses, and finance-related inquiries
  - no general student-governance or parent/teacher workspace authority
- `TEACHER`
  - own teaching home, class readiness, attendance, roster, hifdh, and teacher-scoped student/class access
  - no finance authority and no operations-wide dashboard authority
- `PARENT`
  - own family home and linked children
  - no staff workspace or finance-office authority
- `LEARNER`
  - own courses, progress, billing, and learning notices
  - no staff or other learner data

Important architectural rule:

- sidebar visibility is not treated as security
- route guards and backend role checks must enforce access independently

The formal access reference for routes, pages, and backend areas is maintained in:

- [RBAC Matrix](RBAC_MATRIX.md)

Future role direction:

- the `LEARNER` role now has phase-1 foundation in code for self-service older students or course learners
- the next learner route and API expansion is documented in the same RBAC matrix
- LMS authoring now follows `admin creates subject/course shell -> admin assigns teacher -> teacher authors inside assigned course`
- LMS authoring foundation now includes `modules -> lessons -> media assets` under assigned courses
- paid learner access now has backend grant foundation so `PAID` lessons can open only after explicit access is given
- learner course pricing and access-request flow now lets learners request paid-course access before office approval/grant
- paid learner access now also creates dedicated course invoices, lets learners initiate payment, and auto-grants course access after payment confirmation
- admin grant now marks matching learner access requests as approved automatically
- office can now move course access requests into `REVIEWING` or `REJECTED` before final grant
- office can now save internal notes on course access requests during review
- learner media access checks entitlement and uses short-lived signed links with audit logs; current redirects can still reveal upstream URLs and are not DRM
- the proposed online learning, media protection, and free-vs-paid content architecture is documented in [LMS_CONTENT_BLUEPRINT.md](LMS_CONTENT_BLUEPRINT.md)

## Flutter Frontend

The React client has been retired. Flutter is now the only application frontend, with web, Android, and iOS targets. The initial Flutter migration includes a public entry page, sign-in, role-specific navigation, and read-only views for selected existing API data.

This is a **migration foundation, not feature parity**. Former React features such as admissions forms, student editing, attendance marking, finance operations, course authoring, media lessons, and complete parent/learner workflows are not yet ported. Do not treat a successful Flutter build as proof those workflows are available. Backend RBAC and tenant/ownership checks remain mandatory regardless of what Flutter shows.

## Local Development

### Backend

1. Prepare env:

```bash
cp backend/.env.example backend/.env
```

2. Start Redis:

```bash
docker compose up -d
```

3. Run migrations:

```bash
cd backend
npm install
npm run prisma:migrate:deploy
```

4. Seed admin:

```bash
npm run seed:admin
```

For integration tests and smoke flows, seed test roles on a disposable local database:

```bash
npm run seed:e2e-roles
```

5. Start backend:

```bash
npm run dev
```

Backend health check:

```bash
curl http://127.0.0.1:4000/api/health
```

Backend verification:

```bash
npm run smoke:core
npm run smoke:write
npm run smoke:public-inquiry
npm test
```

Smoke and integration tests create records; use a disposable database.

After the backend steps above, return to the repository root and run the full local release gate:

```bash
cd ..
bash scripts/release-gate.sh
```

If the backend server is already running and you also want smoke coverage:

```bash
RUN_SMOKE=1 bash scripts/release-gate.sh
```

Set `WEB_API_BASE_URL=https://your-api.example` when building a deployable web artifact; the default URL is a non-production placeholder.

Default seeded admin:

- email: `admin@example.com`
- password: `ChangeMe123!`

Change the example password before using any shared environment.

### Flutter Frontend

Install Flutter 3.38.5 or compatible stable SDK, then:

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

For the Android emulator, the default API URL is `http://10.0.2.2:4000`. For a physical Android/iOS device, supply a reachable HTTPS API URL with `--dart-define=API_BASE_URL=https://your-api.example`. Local sessions are held only in memory, so users sign in again after a restart.

Verification:

```bash
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example
```

See [Flutter frontend guide](frontend/README.md) for platform notes.

## Core API Areas

- `/api/auth`
- `/api/organizations`
- `/api/users`
- `/api/students`
- `/api/guardians`
- `/api/classes`
- `/api/enrollments`
- `/api/attendance`
- `/api/hifdh-progress`
- `/api/subjects`
- `/api/courses`
- `/api/teaching/courses`
- `/api/courses/:id/modules`
- `/api/courses/modules/:moduleId/lessons`
- `/api/courses/lessons/:lessonId/assets`
- `/api/learner/courses`
- `/api/learner/courses/:courseId`
- `/api/learner/lessons/:lessonId`
- `/api/learner/assets/:assetId/open`
- `/api/courses/:id/access-requests`
- `/api/invoices`
- `/api/payments`
- `/api/parent-portal`
- `/api/reports`

## Production Notes

- All business queries must remain tenant-scoped by `org_id`
- Teacher and parent access must remain branch and ownership scoped
- Payment webhooks must remain idempotent
- Finance and user-management actions must remain auditable
- GitHub Actions CI now validates backend and frontend checks from `.github/workflows/ci.yml`

## Related Docs

- [Technical Documentation](madrasa_management_system_technical_documentation_tanzania_2026.md)
- [RBAC Matrix](RBAC_MATRIX.md)
- [Backend Development Guide](backend/DEVELOPMENT.md)
- [Flutter Frontend Guide](frontend/README.md)
- [Project Status](PROJECT_STATUS.md)
- [Backend Migration Plan](backend_foundation_migration_plan.md)
