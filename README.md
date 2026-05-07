# Madrasa Management System (MMS)

MMS is a multi-tenant SaaS platform for madrasas in Tanzania. It manages student registration, classes, attendance, hifdh tracking, invoicing, mobile money payments, reporting, and parent access.

This repository follows the technical direction defined in [madrasa_management_system_technical_documentation_tanzania_2026.md](/home/jaykali/madrasa/madrasa_management_system_technical_documentation_tanzania_2026.md:1).

## Stack

- Backend: Node.js, Express, TypeScript
- Frontend: React, TypeScript, Vite
- Database: MariaDB
- ORM: Prisma
- Cache / Queues: Redis, BullMQ
- Payments: Snippe

## Repository Layout

```text
backend/   Express API, Prisma schema, scripts, modules
frontend/  React web client for admin, teacher, accountant, and parent flows
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

## Frontend Direction

The frontend is intended to be the real production web client, not a prototype embedded in the backend.

Current primary surfaces:

- Admin dashboard
- Accountant finance workspace
- Teacher attendance and hifdh workspace
- Parent portal

Current frontend capabilities also include:

- Student and guardian management
- Class detail views for roster and attendance context
- Attendance marking and hifdh entry
- Invoice, payment, and expense workflows
- Report summaries and CSV exports

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

### Frontend

1. Prepare env:

```bash
cp frontend/.env.example frontend/.env
```

2. Install dependencies:

```bash
cd frontend
npm install
```

3. Start app:

```bash
npm run dev
```

By default the frontend expects the backend API at `http://127.0.0.1:4000`.

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
