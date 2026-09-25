# MMS Backend Development Setup

## 1. Purpose

This guide starts the local development infrastructure for MMS backend.

Services provided:
- Host MariaDB on `127.0.0.1:3306`
- Redis on `127.0.0.1:6379`

The defaults match [`.env.example`](./.env.example).

---

## 2. Start Infrastructure

From the repository root:

Start Redis:

```bash
docker compose up -d
```

If your machine does not have the Docker Compose plugin, use the fallback script:

```bash
bash scripts/dev-infra-up.sh
```

Check status:

```bash
docker compose ps
```

Stop services:

```bash
docker compose down
```

Fallback:

```bash
bash scripts/dev-infra-down.sh
```

Only on a disposable local setup, `docker compose down -v` also deletes the Redis volume.

---

## 3. Prepare Backend Env

Create the backend env file:

```bash
cp backend/.env.example backend/.env
```

Current defaults:
- database name: `mms`
- database user: `mms_user`
- database password: `mms_password`
- database port: `3306`
- redis URL: `redis://127.0.0.1:6379`

---

## 4. Apply Migrations

From `backend/`:

```bash
npm run prisma:migrate:deploy
```

Regenerate the Prisma client after schema changes:

```bash
npm run prisma:generate
```

---

## 5. Seed First Admin

From `backend/`:

```bash
npm run seed:admin
```

Default seeded values come from `.env`:
- organization: `Demo Madrasa`
- branch: `Main Campus`
- admin email: `admin@example.com`
- admin password: `ChangeMe123!`

Change these values before seeding any shared environment. Never use the example passwords in production.

For local integration tests only, seed accountant, teacher, parent, and learner accounts on a disposable database:

```bash
npm run seed:e2e-roles
```

Do not run the E2E role seed on a shared or production database: it updates matching test users and passwords.
If a test email or phone belongs to another account, the seed stops; choose unused `E2E_*_EMAIL` and `E2E_*_PHONE` values instead.

---

## 6. Start Backend

From `backend/`:

```bash
npm run dev
```

Health check:

```bash
curl http://127.0.0.1:4000/api/health
```

Core smoke:

```bash
npm run smoke:core
```

Write smoke:

```bash
npm run smoke:write
```

Public inquiry smoke:

```bash
npm run smoke:public-inquiry
```

`smoke:write` creates timestamped QA records for guardian, student, fee structure, invoice, payment request, expense, and announcement.
`smoke:public-inquiry` submits a public admissions inquiry, verifies it appears in the secure inbox, and marks it as contacted.
Run write smoke and integration tests only against a disposable development database; they create records.

Optional overrides:
- `BASE_URL`
- `SMOKE_ADMIN_LOGIN`
- `SMOKE_ADMIN_PASSWORD`

Automated API tests:

```bash
npm test
```

This integration suite verifies authentication, role and branch boundaries, learner/course access, paid-course billing, signed media links, public inquiries, webhook safety, and reporting.

Optional test credential overrides include `TEST_ADMIN_LOGIN`, `TEST_ADMIN_PASSWORD`, and matching `TEST_ACCOUNTANT_*`, `TEST_TEACHER_*`, `TEST_PARENT_*`, and `TEST_LEARNER_*` variables. A local `SNIPPE_WEBHOOK_SECRET` is needed for signed webhook tests.

---

## 7. Recommended First Run Order

1. Start MariaDB host service and confirm `mms` exists on `127.0.0.1:3306`
2. `cp backend/.env.example backend/.env`
3. `docker compose up -d`
4. `cd backend`
5. `npm run prisma:migrate:deploy`
6. `npm run prisma:generate`
7. `npm run seed:admin`
8. `npm run seed:e2e-roles` (disposable local database only)
9. `npm run dev`
## Browser Sessions

Flutter web uses `/api/auth/browser/login|register|refresh|logout`.
The refresh credential is a host-only HttpOnly, SameSite=Lax session cookie,
restricted to `/api/auth/browser`; production also requires Secure/HTTPS.
Access tokens remain in memory. Native token-based auth endpoints are unchanged.

Set `WEB_APP_ORIGINS` to the exact frontend origins (comma-separated, no wildcard
or trailing slash), for example `https://school.example,https://app.school.example`.
The `APP_BASE_URL` origin is also allowed. Development additionally allows HTTP
or HTTPS loopback origins. Cookie endpoints require an allowed Origin plus
`X-MIF-Browser: 1`; responses are not cacheable.

Deploy frontend and API on the same site (prefer a same-origin API proxy) so
SameSite cookies work. Locally use the same host on both ports: Flutter normalizes
localhost/127.0.0.1 API configuration to the host used in the browser.

No database migration is required. Refresh rechecks the active account and
school; logout revokes the server token and clears the cookie. Browser registration
still creates only a LEARNER. Session restoration does not restore unsaved forms.

Cookie behavior: [MDN Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie).
## Admin Student Record Management

The Students page uses these ADMIN-only routes:
- GET /api/admin/students/:id/record: current personal details, revision and latest
  20 recorded management changes (actor, reason and before/after values).
- POST /api/admin/students/:id/edit: revision, reason, fullName, admissionNo,
  gender (male/female/null), dob and joinedOn (YYYY-MM-DD/null), notes (string/null).
- POST /api/admin/students/:id/archive: revision and reason; ACTIVE school pupils
  become INACTIVE, with leftOn set to the current Tanzania date.
- POST /api/admin/students/:id/restore: revision and reason; INACTIVE school pupils
  become ACTIVE and leftOn is cleared.

These routes recheck the active admin, school and current branch, reject stale
revisions with 409, and save changes plus audit history in one locked transaction.
Archiving never deletes attendance, learning, guardian or financial history.
Existing class links remain; check class placement when restoring a pupil.
Online learner accounts cannot be archived/restored through these endpoints.
Editing a learner profile does not rename or disable its separate login account.

No schema migration is required. The existing registration, class-placement and
guardian-link workflows remain separate. These endpoints do not replace every
legacy student mutation or constitute full CRUD for classes, staff or finance.
