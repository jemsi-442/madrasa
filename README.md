# MODERN ISLAMIC FOUNDATION

MODERN ISLAMIC FOUNDATION is a cross-platform school and online-learning system. The Express API remains the source of truth; a Flutter client now targets web, Android, and iOS.

This repository follows the technical direction defined in [madrasa_management_system_technical_documentation_tanzania_2026.md](/home/jaykali/madrasa/madrasa_management_system_technical_documentation_tanzania_2026.md:1).

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
- Reporting and exports

## Flutter Frontend

The React client has been retired. Flutter is now the only application frontend, with web, Android, and iOS targets. The initial migration includes a public entry page, sign-in, role-specific navigation, and read-only views for selected existing API data.

This is a **migration foundation, not feature parity**. Admissions forms, student editing, attendance marking, finance operations, course authoring, media lessons, and complete parent/learner workflows are not yet ported. Backend RBAC and tenant/ownership checks remain mandatory regardless of what Flutter shows.

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

5. Start backend:

```bash
npm run dev
```

Backend health check:

```bash
curl http://127.0.0.1:4000/api/health
```

Default seeded admin:

- email: `admin@example.com`
- password: `ChangeMe123!`

### Flutter Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

See [Flutter frontend guide](frontend/README.md) for Android/iOS setup, verification, and current limitations.

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
- `/api/invoices`
- `/api/payments`
- `/api/parent-portal`
- `/api/reports`

## Production Notes

- All business queries must remain tenant-scoped by `org_id`
- Teacher and parent access must remain branch and ownership scoped
- Payment webhooks must remain idempotent
- Finance and user-management actions must remain auditable

## Related Docs

- [Technical Documentation](/home/jaykali/madrasa/madrasa_management_system_technical_documentation_tanzania_2026.md:1)
- [Backend Development Guide](/home/jaykali/madrasa/backend/DEVELOPMENT.md:1)
- [Backend Migration Plan](/home/jaykali/madrasa/backend_foundation_migration_plan.md:1)
