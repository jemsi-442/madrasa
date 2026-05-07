# MMS Backend Foundation and Migration Plan

## 1. Purpose

This document defines the recommended order for turning the current technical documentation and Prisma schema into a production-grade backend foundation.

It focuses on:
- project scaffolding
- database migration sequencing
- implementation order
- operational safeguards

---

## 2. Engineering Principles

- Build the system in layers, not all at once
- Freeze core data contracts before feature expansion
- Keep migrations small, reviewable, and reversible
- Prefer vertical slices after the database foundation is stable
- Treat payments, auth, and tenancy as first-class architecture concerns

---

## 3. Current State

Current repository state:
- technical documentation exists
- initial Prisma schema exists in `backend/prisma/schema.prisma`
- no backend scaffold yet
- no package manager setup yet
- no migration history yet

This means we are still at the correct stage to establish clean conventions before code begins to spread.

---

## 4. Recommended Backend Foundation

### 4.1 Runtime and Core Stack

- Node.js
- TypeScript
- Express
- Prisma
- MariaDB
- Redis
- BullMQ
- Zod
- JWT access and refresh token strategy

### 4.2 Suggested Initial Backend Structure

```text
backend/
  src/
    app/
    config/
    modules/
      auth/
      organizations/
      users/
      students/
      attendance/
      finance/
      payments/
    shared/
      db/
      errors/
      middleware/
      utils/
    jobs/
    routes/
  prisma/
    schema.prisma
    migrations/
  tests/
```

---

## 5. Migration Strategy

### 5.1 Rule of Thumb

Do not generate one giant first migration containing the entire product if the team plans to iterate actively. Instead, create controlled migration batches aligned with domain foundations.

### 5.2 Recommended Migration Waves

#### Wave 1: Tenant and Auth Foundation

Tables:
- `organizations`
- `branches`
- `users`
- `refresh_tokens`

Why first:
- everything depends on tenancy
- auth and ownership boundaries must exist before business data
- most middleware and API guards depend on these tables

Deliverables:
- tenant-safe user model
- login and refresh token persistence
- branch-aware identity model

#### Wave 2: Student Domain Foundation

Tables:
- `guardians`
- `students`
- `student_guardians`
- `classes`
- `subjects`
- `enrollments`

Why second:
- student lifecycle is the operational center of the system
- finance and attendance both depend on student and class structure

Deliverables:
- student registration model
- parent linking model
- class and enrollment foundation

#### Wave 3: Daily Operations Foundation

Tables:
- `attendance_records`
- `announcements`
- `hifdh_progress`

Why third:
- these features depend on students, users, and classes already existing
- they are lower risk than finance and can be validated early

Deliverables:
- teacher workflows
- communication workflows
- academic and hifdh tracking foundation

#### Wave 4: Finance Foundation

Tables:
- `fee_structures`
- `invoices`
- `expenses`

Why fourth:
- billing needs stable student and branch relationships
- finance should be introduced after the student model is trustworthy

Deliverables:
- invoice generation model
- outstanding balance tracking
- expense bookkeeping

#### Wave 5: Payment Integration Foundation

Tables:
- `payments`
- `payment_webhooks`
- `audit_logs`

Why fifth:
- payment integration should rest on a stable invoice model
- webhook logging and auditability must exist before external payment traffic is enabled

Deliverables:
- Snippe reference storage
- webhook event persistence
- finance audit trail

---

## 6. Recommended Implementation Order

After Wave 1 migrations:
1. tenant resolution middleware
2. auth module
3. role guard middleware
4. user management basics

After Wave 2 migrations:
1. student create flow
2. guardian linking flow
3. class assignment flow
4. student listing and filtering

After Wave 3 migrations:
1. attendance bulk mark endpoint
2. attendance reporting endpoint
3. announcement publishing
4. hifdh progress entry

After Wave 4 migrations:
1. fee structure CRUD
2. invoice generation
3. invoice listing and detail
4. outstanding balances report

After Wave 5 migrations:
1. Snippe payment initiation service
2. webhook verification endpoint
3. payment reconciliation job
4. receipt and notification jobs

---

## 7. Initial Backend Milestones

### Milestone A: Foundation Build

Scope:
- backend scaffold
- TypeScript config
- Express app
- Prisma client setup
- environment validation
- Wave 1 migration

Success criteria:
- app boots
- database connects
- users and organizations can be persisted
- auth module can be started on stable tables

### Milestone B: Core School Operations

Scope:
- Wave 2 and Wave 3 migrations
- students
- guardians
- classes
- attendance
- hifdh

Success criteria:
- student can be registered
- linked guardian can be assigned
- teacher can mark attendance
- admin can view student and class records

### Milestone C: Finance Core

Scope:
- Wave 4 migration
- fee structures
- invoices
- expense tracking

Success criteria:
- invoice can be generated for a student
- outstanding balance can be calculated
- finance reports can summarize billed vs paid

### Milestone D: Snippe Integration

Scope:
- Wave 5 migration
- Snippe payment initiation
- webhook handler
- reconciliation
- audit logging

Success criteria:
- invoice payment request can be sent to Snippe
- webhook can be verified from raw body
- completed payment updates invoice correctly
- duplicate events do not duplicate payment application

---

## 8. Package and Tooling Setup Plan

Recommended first setup tasks:

1. Create backend package manifest
2. Add TypeScript and Express runtime dependencies
3. Add Prisma and Prisma client
4. Add linting and formatting tools
5. Add test runner
6. Add environment validation
7. Add Prisma scripts

Recommended script set:

```json
{
  "dev": "tsx watch src/server.ts",
  "build": "tsc -p tsconfig.json",
  "start": "node dist/server.js",
  "prisma:generate": "prisma generate",
  "prisma:migrate:dev": "prisma migrate dev",
  "prisma:migrate:deploy": "prisma migrate deploy",
  "prisma:studio": "prisma studio"
}
```

These are conventions only. Final commands may vary depending on whether the team uses `tsx`, `ts-node`, or another runtime.

---

## 9. Migration Naming Convention

Recommended migration names:

1. `init_tenant_and_auth`
2. `add_student_domain`
3. `add_operations_modules`
4. `add_finance_core`
5. `add_payments_and_audit`

Why this matters:
- migration history remains understandable
- rollbacks and debugging become easier
- onboarding future developers becomes much faster

---

## 10. Operational Safeguards

### 10.1 Database Safety

- never edit an applied migration manually in shared environments
- do not use `db push` for production deployment
- production should use reviewed migrations only
- add database backups before finance and payment go live

### 10.2 Payment Safety

- never enable Snippe live credentials before webhook persistence exists
- verify raw-body signature handling before public rollout
- treat reconciliation as mandatory, not optional

### 10.3 Multi-Tenancy Safety

- every service must apply `org_id` filtering
- do not rely only on controller-level checks
- add tenant-aware repository patterns early

---

## 11. Open Decisions Before Coding Too Far

- whether backend lives under `backend/` or repo root
- whether Prisma directory lives at root or under backend
- whether user login supports both phone and email from day one
- whether parent users are created automatically when guardians are created
- whether branch-level permissions are needed in MVP

These should be settled before wide API implementation starts.

---

## 12. Immediate Next Actions

Recommended next execution sequence:

1. scaffold backend project structure
2. move or confirm Prisma location
3. create package manifest and TypeScript config
4. create environment template
5. generate Wave 1 migration
6. implement auth and tenant middleware

If we want to move like a disciplined engineering team, this is the right next step: scaffold the backend and prepare Wave 1 migration instead of jumping directly into random endpoints.
