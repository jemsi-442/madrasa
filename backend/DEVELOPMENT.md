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
## Git Repositories in This Checkout

This checkout currently contains two independent Git repositories: the project
root and backend/.git. A commit at the project root does not update the backend
repository shown separately by VS Code. Neither repository has been removed or
had its history rewritten.

After each backend step, inspect both `git status --short` (project root) and
`git -C backend status --short`. Commit the intended backend source changes in
the backend repository as well as the project-level changes in the root.
Commits are local; pushing to a remote is a separate, explicitly requested step.

The backend repository now ignores dist/, node_modules/, coverage/ and local
.env files. They remain on disk; reinstall/build with npm ci, npm run
prisma:generate and npm run build after a fresh clone. The .env.example template
is tracked. The older backend commit included .env: ignoring it now does not
erase historical copies. Rotate credentials if that history was ever shared;
any history rewrite needs a separately agreed procedure.

## Afaq Platform Governance: Foundation (7 October 2026)

Status: backend foundation, password/MFA login and guarded HTTP routes are in
source, not deployed. No platform accounts have been created by the development
work. Existing school ADMIN accounts do not become Super Admins. The platform
console UI is available in source at the Flutter route `/platform` (normally
`/#/platform` on the existing web host). It is separate from the school login,
uses memory-only bearer tokens, and requires reauthentication on refresh/expiry.
Super Admin sees application intake/review, audit and system health; IT sees
audit and system health. It does not activate approved schools.
The UI has not yet been verified against a migrated staging database.

Implemented source:

- Separate `PlatformAccount`, `TenantApplication` and `PlatformAuditEvent`
  tables in additive migration `202610071200_add_platform_governance_foundation`.
  Platform accounts default to DISABLED; school users and roles are unchanged.
- SUPER_ADMIN permissions for application intake, review and platform audit.
  IT_SECURITY may read platform audit and operational health. IT cannot read application contact
  information, approve schools, or perform school academic/financial operations.
- Internal `PlatformGovernanceService`: normalized intake, bounded listings,
  REQUESTED -> APPROVED or REJECTED transitions and transactional audit writes.
  Approval requires a different active Super Admin from the requester. There is
  no single-admin bypass. A decision cannot be overwritten or self-approved.
- Platform token verifier: separate issuer/audience, HS256 allowlist,
  `platform_access` token type, maximum 15-minute lifetime and current database
  role/status checks. A token must reference a matching, non-revoked database
  session with a recent MFA verification, matching issuance time and sufficient
  expiry. Login issues tokens only after password and authenticator verification.
- Separate `PlatformSession` table in migration
  `202610071300_add_platform_sessions`; logout and logout-all revoke only the
  authenticated operator's sessions and record revocation in the same transaction.
  Revocation blocks subsequent requests; requests already in flight can finish.
- MFA fields in migration `202610071400_add_platform_mfa`. Authenticator secrets
  are encrypted with AES-256-GCM and bound to their account ID. Accepted TOTP
  steps are consumed conditionally in the same transaction as session issuance
  and login audit, preventing concurrent replay of the same code.

Guarded endpoints under `/api/platform`:

| Method | Path | Access |
| --- | --- | --- |
| POST | /login | Password + six-digit authenticator code; rate limited |
| GET | /me | Active platform session; minimal account profile |
| GET, POST | /tenant-applications | Super Admin only |
| POST | /tenant-applications/:id/review | Different Super Admin from requester |
| GET | /audit-events | Super Admin or IT/Security |
| GET | /health | Super Admin or IT/Security; real database and Redis checks |
| POST | /logout | Revoke current session |
| POST | /logout-all | Revoke all sessions of the signed-in operator |
| GET | /sessions | Paginated active sessions of the signed-in operator only |
| POST | /sessions/:id/revoke | Revoke an owned session with transactional audit |

Routes fail closed with 503 when `PLATFORM_JWT_SECRET` is empty, shorter than
32 characters, or reused from either school JWT secret. Protected requests
require a Bearer header; cookies and query-string tokens are not accepted.
Responses are marked `Cache-Control: no-store`. No public platform registration
route exists. Keep platform keys empty until migrations and authentication are
tested in staging; do not insert sessions manually to bypass MFA.

### Company Account Directory

Super Admin can open Governance overview (`GET /api/platform/overview`) to read
application counts by status, requests awaiting that administrator's independent
review (excluding their own), and company account counts by role/status. These
are platform aggregates only, not school records or activated-tenant counts.
IT Security cannot access this endpoint. A failed refresh clears the displayed
snapshot. The `onboarding` summary separately counts approved applications with
no linked school (`awaitingSetup`) and approved applications linked to a school
marked PENDING_ACTIVATION (`pendingActivation`). These counts are not activation
readiness checks and do not imply invitation delivery or administrator acceptance.
**View approved onboarding** opens the approved application list at page one,
clearing the previous application scope. A count-query failure rejects the whole
snapshot rather than presenting invented zeros. Counts are timestamped, not live.

Review pending applications opens the application list with `scope=reviewable`
and `status=REQUESTED`. The backend derives the reviewer from the authenticated
platform account and excludes their own requests. `scope=mine` selects that
account's requests; omitting scope lists all applications. Exact status filters
accept REQUESTED, APPROVED or REJECTED. Combining reviewable with a completed
status is rejected. Filters reset pagination and do not change approval rules
or grant IT access to school onboarding contacts.

Application details in the console expose the request ID, requester account ID,
reviewer account ID and UTC timestamps already returned by the application API.
Decision reasons remain visible. Approved requests explicitly indicate that
provisioning has not occurred; rejected requests are closed, not deleted schools.
Confirmation shows the nominated admin email and requested code, and warns that
the decision cannot be edited. This adds no permission or database mutation.
After a successful create/review response the UI confirms the saved outcome
separately from list refresh. Refresh failures must not imply the decision failed.
If the write response is unavailable, the UI reports uncertainty and instructs
the operator to refresh before retrying; it never automatically repeats a write.
Old application cards and overview counts are cleared when submitting a change.
IT disable/restore actions also distinguish a confirmed save from a subsequent
list refresh failure. Unknown write outcomes clear actionable stale cards and
direct the reviewer to refresh Company accounts and inspect Access history.
Refresh performs reads only, never an automatic retry of the access mutation.
Main application, audit, company-account and session lists clear their previous
snapshot when a read starts. A failed read shows an error, not stale records or
the successful-empty message. An explicit successful retry can show an empty
list; duplicate refresh clicks during loading do not issue additional requests.
Restoration does not change the password; it requires a fresh password/MFA login.
Platform confirmation dialogs are bound to the local authenticated session
generation that opened them. Expiry dismisses those dialogs and removes loaded
records. A confirmation from an earlier session cannot submit after re-login,
even to the same account. This complements, not replaces, backend token/session
checks; already submitted requests may still finish.

`GET /api/platform/accounts` is a Super Admin-only directory of
platform identities, with bounded `page` and `pageSize`. The Company accounts
API also accepts exact `role` (SUPER_ADMIN/IT_SECURITY) and `status`
(ACTIVE/DISABLED) filters. Filters never grant IT directory access. The console
resets pagination when filters change and can clear both filters together.
The Company accounts
console tab shows name, email, role, status, creation time and account ID.
It does not query school users. IT Security is denied by the backend, not just
hidden navigation. Password hashes, MFA secrets, replay counters and sessions
are excluded by an explicit database projection. Unknown query fields fail
validation. No invitation, role change or deletion is enabled.

`POST /api/platform/accounts/:id/disable` allows Super Admin to disable only an
active IT_SECURITY account with a required 10-500 character reason. The console
requires confirmation. Self-disable and Super Admin targets are rejected.
Conditional status update, session revocation and audit insertion commit in one
transaction; audit failure rolls everything back. Already-disabled or concurrent
losing requests return 409 without another audit event. Authentication checks
account status, so disabled accounts cannot log in or reuse old tokens. Requests
already in flight may finish. No school users or tenant data are changed.
The reason is stored in the restricted audit record but omitted from the shared
audit API; do not enter secrets. Account status and revoked-session count are
exposed as safe metadata.

`POST /api/platform/accounts/:id/restore` requires a different active Super Admin
from the one recorded on the latest suspension, plus a 10-500 character reason.
It also requires `suspensionEventId` matching the latest suspension. The console
loads and displays that event before confirmation. If the account is restored
and suspended again while a reviewer is reading, the old approval is rejected
with 409 rather than applied to the new suspension. Reopen the review to read
the new event. A failed history fetch must not open a blind approval form.
Only disabled IT accounts with an enrolled MFA secret and a recorded suspension
are eligible. This cannot activate a newly provisioned, un-enrolled account.
The serializable transaction conditionally restores status, revokes remaining
sessions and records the suspension event reference in audit. Audit failure
rolls back restoration. Old tokens remain revoked; a fresh password/MFA login
is required. Credentials, MFA replay protection and roles are not reset.
The UI's Review restoration action explains these restrictions. It is a human
review attestation, not an automated assertion that an incident is resolved.

The Super Admin-only `GET /api/platform/accounts/:id/access-history` endpoint
returns bounded suspension/restoration history for a platform account. The
Company accounts screen pages through changes in groups of 20 with actor account
ID, UTC timestamp and the recorded reason. Older/Newer controls, retry and empty
states do not display stale records after a failed request. The dialog closes
at session expiry. Offset pagination can shift with concurrent activity; this
is not a complete history export or a fixed forensic snapshot.
Only the explicitly selected reason (at most 500 characters) and safe status/count
metadata are exposed. Arbitrary audit metadata is never returned. The regular
audit endpoint still omits reasons, including for IT Security. Reasons are
operator-entered statements, not verified incident findings.

### Approved Application Setup Preflight

`GET /api/platform/tenant-applications/:id/provisioning-preflight` is a read-only
handoff check for active Super Admin and IT/Security accounts. Only APPROVED
applications are eligible; missing and unapproved IDs both return 404. IT does
not gain access to the application directory, applicant email, decision reasons,
or school content. The response checks a recorded independent review and whether
the requested organization code is currently unused, exposing no existing school
details. Database errors fail the request instead of reporting success.

Super Admin can open **Check setup readiness** from an approved application in
the console. The result is a timestamped snapshot, not a reservation or permission
to create a school. `provisioningEnabled` remains false even when checks pass.
No organization, user, invitation or activation is written by this GET endpoint.
`alreadyProvisioned` indicates a linked school; an occupied code must not be
interpreted as permission to attach some other existing school.

### Pending School Creation

`POST /api/platform/tenant-applications/:id/provision` accepts an empty JSON object
and is restricted to IT_SECURITY. Super Admin reviews applications but cannot
execute this operation. It uses only approved application details and requires a
recorded reviewer different from the requester. No caller-selected school code,
organization ID, credentials or activation status is accepted.

Migration `202610081200_add_pending_school_provisioning` adds
`PENDING_ACTIVATION` and a unique application-to-organization link. A serializable
transaction creates the school with that explicit inactive status, records the
link and timestamp, and appends `tenant.school.provisioned`. Audit failure rolls
back all writes. The application ID provides retry identity: a repeat returns the
linked school without rewriting its status or duplicating audit. Concurrent or
code-uniqueness conflicts return 409; retry the same application after refreshing,
never adopt an existing school by matching its code. The response uses a string
organization ID and returns 201 on creation or 200 on replay.

Existing organization statuses/defaults are unchanged. The school login, refresh
and active-account checks allow only ACTIVE/TRIAL, not PENDING_ACTIVATION. No
school admin, password or invitation is created at this stage. First-admin
invitation/acceptance and guarded activation are still pending;
end-to-end automatic provisioning remains disabled in the preflight response.
Apply the migration only through a reviewed deployment; development tests use
disposable databases, not the live school database.

Verified with 27 migrations on isolated MariaDB: fresh-install and upgrade-baseline
runs each pass 11 integration tests, including concurrent provisioning, retry
identity, no admin creation, and injected audit-failure rollback. This is backend
integration coverage, not a production deployment or browser onboarding test.

IT now opens **Madrassa setup** in the platform console. Its bounded, read-only
`GET /api/platform/provisioning-queue` returns only approved application names,
codes, review dates and linked school IDs/statuses, not admin contacts or decision
reasons. Super Admin retains the review directory rather than the execution queue.
IT runs preflight then explicitly confirms **Create inactive madrassa**. Cancel
sends no write. Linked schools have no creation action. Confirmed writes and
unconfirmed network failures have different messages; after either, the operator
refreshes the queue rather than automatically resubmitting. Session-bound dialogs
and callback checks prevent stale confirmations after logout/relogin. School
creation remains separate from first-admin invitation and activation.

The queue accepts optional `q` (trimmed, at most 100 characters) to search school
name or code only. Approval and IT permission filters always apply, and SQL LIKE
wildcards are treated as literal text. The UI submits search explicitly, resets
to page one for a new query, retains the applied query during refresh/pagination,
and offers **Clear search**. Empty results do not reveal unapproved applications
or nominated administrator emails.

The optional `setup=pending|created` filter separates approved applications with
no linked school from those already linked to a school. **All approved** removes
this filter; **Awaiting setup** and **Created madrassas** reset pagination to page
one and retain the applied search. Refresh retains both filters, while **Clear
search** clears only the text query. Created is not the same as active: each row
still shows its actual school status, and linked schools cannot be created again.

### First Admin Invitation Foundation

Migration `202610081300_add_school_admin_invitations` and internal lifecycle
functions in `platform.school-invitation.ts` support one current invitation per
approved, provisioned inactive school. Only active IT may issue it; the email
comes from the approved application, not caller input. The token contains 32
cryptographically random bytes, expires after 24 hours, and is persisted only as
a SHA-256 hash. Reissuing replaces the token and invalidates the earlier one.
Issuance and a token-free platform audit event commit together.

Acceptance requires the token, full name and a password of at least 12 characters
and at most 72 UTF-8 bytes. Serializable acceptance creates exactly one DISABLED
school ADMIN with a bcrypt hash and stores an acceptance timestamp/user receipt
atomically. Expired, consumed or replaced tokens cannot be used. The email,
organization, role and status cannot be supplied by the accepting client.
The school stays PENDING_ACTIVATION; no access/refresh token is issued. Activation
is a separate internal review workflow described below. Acceptance is attributed through its
invitation receipt, not falsely logged as an action performed by the issuing IT.

No email delivery service is connected. The acceptance HTTP boundary described
below is wired but disabled; there is still no acceptance UI or issuing endpoint.
The plaintext token return is for a future trusted delivery adapter
only: never return it to IT, put it in audit/logs, or add a public route without
delivery, rate limiting, safe link handling and review. No real invitation has
been sent. Tested on isolated MariaDB with 28 migrations: expiry, rotation,
concurrent acceptance, password hashing and rollback on issuance/acceptance
failure. Public invitation acceptance and browser end-to-end tests remain pending.

### Invitation Acceptance Boundary

`POST /api/school-invitations/accept` is mounted **disabled by default** and
returns 503 without calling the database or rate limiter. The current composition
root supplies no enabling options. The company has confirmed that it does not yet
have an email delivery service; do not enable acceptance or expose issue tokens as
a substitute. No SMTP/API credentials or provider have been assumed or added.

The router factory can be enabled explicitly in isolated tests with a mandatory
limiter. It consumes limits before validation/database work: 10 attempts per token
and 30 per IP per 15 minutes, counted atomically in Redis. Keys contain HMACs, not
raw tokens or IPs; weak/missing secrets, Redis failures and invalid limiter replies
fail closed. Redis connect/command timeouts are bounded. A 429 includes
Retry-After: 900. Configure trusted proxy handling deliberately before deployment;
never trust arbitrary client-supplied forwarding headers for rate-limit identity.

Acceptance takes token, fullName and password in a POST body, never a URL query
or path. Future browser invitation links must keep the token out of server access
logs (for example a fragment handled by the client). Responses are no-store and
no-referrer, validation/database errors are sanitized, and success returns only
PENDING_ACTIVATION with no identity, cookie or access/refresh tokens. Database
errors containing invitation secrets are not passed to the generic error logger.
Email delivery and browser end-to-end testing remain pending. The frontend now
has a testing-stage acceptance page at `/school-invitation`, separate from school
and platform session screens. It accepts a manually entered invitation code in
the form, never parses one from URL queries, and submits only token/fullName/
password in the POST body with no bearer authorization added. No credential is
persisted by this page. Passwords are cleared after each completed attempt and
all fields are cleared on confirmed acceptance. Success displays waiting for
activation; it never signs the user in. Duplicate clicks are blocked while a
request is pending, and requests have a 25-second timeout with no automatic retry.
The deployment-disabled notice remains visible and the API still returns 503:
the page does not enable acceptance or send invitations. Widget/client tests use
mock responses at mobile and desktop widths, not a live invitation workflow.

### Activation Review Foundation

`activateSchool` in `platform.activation.ts` is internal only; there is no public
or platform HTTP activation endpoint yet. It requires an active Super Admin
other than the original requester, independent application approval, a linked
PENDING_ACTIVATION school with a recorded provisioning timestamp, and the exact accepted invitation receipt. The accepted
user must belong to that school, match the nominated email and have ADMIN role.
The caller cannot choose a school/user ID to activate.

All five review attestations (tenant isolation, access controls, audit trail,
backup/recovery and support escalation) and an evidence reference are mandatory.
These are operator-entered attestations, not automated proof that those checks
passed. Do not supply production attestations without actually performing the
review. The reference should identify an internal review record, never secrets.

A serializable transaction changes only the pending school and accepted disabled
admin to ACTIVE, then records `tenant.school.activated` with the review evidence.
An audit failure rolls back both changes. A completed, audited activation can be
replayed without duplicate audit or writes only while both school and admin
remain ACTIVE. An existing activation audit with inconsistent current access
requires review, including a school incorrectly returned to PENDING_ACTIVATION.
A suspended school or subsequently
disabled administrator cannot be re-enabled through onboarding replay. This is
not a general school-unsuspension or account-restoration tool. No login tokens are
issued by activation. Delivery, public acceptance, activation review UI and
end-to-end browser verification remain required before deployment.

### Onboarding Progress View

Super Admin's approved application cards and the IT setup queue offer read-only
**Onboarding progress**. The protected
`GET /api/platform/tenant-applications/:id/onboarding-progress` checks current
approval, linked school, invitation receipt, first-admin state and activation
audit. It reports provisioning pending, invitation pending/expired, acceptance
pending, activation review pending, active, or review required. Missing and
unapproved records return the same 404. Both company roles may read approved
handoffs; school roles cannot access them.

The response contains milestones and UTC timestamps, never invitation tokens,
hashes, nominated email, passwords or school content. "Invitation record created"
does not claim email was sent; delivery remains unconfigured. An ACTIVE school is
shown as fully active only with matching accepted active ADMIN and an activation
audit. Suspension, a subsequently disabled first admin, mismatched acceptance or
missing approval/provisioning evidence requires review instead. Historic completed
milestones do not override the current status. Dialogs remain session-bound and
no progress-view action writes or activates anything.

Both company views offer **Refresh progress** without reopening the view. Refresh
hides the previous snapshot immediately and blocks duplicate requests while
loading. A failed refresh shows a retry message rather than stale readiness;
responses arriving after session change or after closing the view are ignored.

For Super Admin only, the same response includes `activationReview`: seven
read-only prerequisite checks and five outstanding manual evidence reviews.
The current requester cannot pass readiness even when another reviewer approved
the application. Missing provisioning evidence, unmatched acceptance, changed
access or a previous activation prevents readiness. IT responses omit this
section entirely. `activationEnabled` remains false, including when recorded
prerequisites pass; this is not an activation authorization or a substitute for
operator evidence. No activation POST endpoint has been added.

### Self-Service Session Controls

The console's My sessions view shows current/other active sessions, session ID,
sign-in time and expiry (UTC). API listings are bounded and filter by the
authenticated account, current role, unrevoked state, expiry and recent MFA.
No client-selected account ID is accepted. No tokens, MFA secrets, IP addresses
or guessed device/location labels are exposed. This is not a device inventory.

Revocation requires UI confirmation and server-side ownership checking even for
Super Admin. Missing and foreign session IDs both return 404. An owned session
already revoked returns zero changes without a duplicate audit event. Revocation
and its audit commit together; an audit failure fails the transaction. Revoking
the current session returns the console to sign-in after server confirmation.
Requests already in flight may finish. Existing logout/logout-all remain available.

The sign-out-all menu requires explicit confirmation explaining that only the
current company account's platform sessions are affected, including this session.
School accounts and other company accounts are unaffected. Cancel sends no write.
The confirmation is bound to the session that opened it: expiry dismisses it,
and logging in again invalidates it even for the same account. Ordinary single
session sign-out remains a direct action.

The console's sign-out menu clears local credentials and loaded governance data
after the revocation attempt, including network errors or server failures. Requests
have a 25-second timeout. If server revocation is not confirmed, the sign-in screen
explicitly says only local sign-out is complete and directs the operator to sign
in again and review My sessions. It does not claim other sessions were revoked,
retry the write automatically, or revoke a newer login that replaced the session
while the request was pending. Other server sessions can remain active until
revoked or expired. Late responses from an older session cannot return protected
data or clear the newer session; responses arriving after local expiry are rejected.

### Audit Filters and Details

The audit endpoint accepts bounded `page`/`pageSize`, exact `action`, `actorRole`
(SUPER_ADMIN or IT_SECURITY), exact `actorId`, and inclusive UTC ISO `from`/`to`
timestamps. Invalid/reversed ranges and unknown query parameters return 422.
Optional `applicationId` restricts results to that exact TenantApplication entity,
without requiring or exposing its school contents or nominated admin contacts.
Missing application IDs return an empty event list, not an application lookup.
Ordering remains newest first, with event ID as the tie-breaker. These filters
never grant tenant-data access or enable free-text searches of sensitive payloads.

The console offers event, role and time-period filters, resets pagination when
filters change, and expands event/account/entity identifiers for investigation.
**View application history** opens a scoped audit from a Super Admin application
card or a TenantApplication audit event visible to either company role. The
scope remains active when event/role/period filters change; **Show all application
and platform events** clears the scope and filters. New event options include
inactive school creation, invitation recording and school activation. Invitation
recording is not proof of email delivery. Opening history is read-only.
A failed-login event's account ID identifies the target, not a verified attacker.
This is not a complete threat feed: unknown-account and throttled requests do
not currently create platform audit rows.

API responses now allowlist only approved status/previousStatus values and
nonnegative integer counts from metadata. Other fields, including unexpected
future nested payloads, are removed before either platform role receives them.
This does not delete or rewrite stored audit records. There is no audit-edit or
audit-delete API. Offset pagination can shift during concurrent writes; this
view is not a forensic snapshot/export.

### Platform Operational Health Checks

`GET /api/platform/health` requires a live platform session and the health-read
permission. It performs database `SELECT 1` and Redis `PING`, returning only
overall healthy/degraded status, UTC check time, per-service availability and
successful-probe latency. Raw exceptions, URLs, credentials, versions and school
data are not returned. A completed degraded snapshot uses HTTP 200 with
`data.status=degraded`; authentication or infrastructure errors can still prevent
the endpoint from returning any snapshot.

Probes have a three-second response deadline, short database transaction/Redis
timeouts, single-flight request sharing and a five-second process-local cache.
The response deadline is not general-purpose cancellation of an underlying
database connection attempt. There is no background polling or persistent health
history. UI Refresh clears the prior snapshot before a new request so failures
cannot leave an old green result displayed as current.

Unavailable services show contextual, read-only operator guidance: database
connectivity checks and verification of uncertain writes, or Redis connectivity
checks without bypassing login protections. Operators are directed to record
the check time/service in their approved incident channel without credentials
or school records, escalate and explicitly refresh to verify recovery. Guidance
is hidden when no failed service is reported or the snapshot is cleared. This
does not create incidents, restart infrastructure or add operational permissions.

This is an operator connectivity view, not a public readiness probe, uptime SLA,
threat detector or backup verifier. Authentication itself needs the database;
if authentication, the database or the API is down, use independent infrastructure
monitoring. Health reads do not write an audit row on every refresh. No platform
permissions or tenant-data access have been expanded by these probes.

### Login and Controlled Bootstrap

Login JSON: `email`, `password`, `code` (six digits, kept as a string). The
response contains a 15-minute access token and minimal profile, not a refresh
token. Reauthenticate after expiry. Future browser UI must keep the bearer token
in memory, not localStorage; production requires HTTPS at the trusted ingress.

TOTP uses SHA-1 and 30-second time steps, allowing one adjacent step for clock
drift. The implementation is checked against the SHA-1 vectors in
[RFC 6238 Appendix B](https://www.rfc-editor.org/rfc/rfc6238#appendix-B), including
times beyond 2038. Keep server clocks synchronized. These tests do not replace
a security review before production deployment.

Redis limits all attempts, including successful ones, to 10 per normalized
email and 30 per source IP per 15-minute window. Limit keys use HMAC rather than
plaintext email/IP. Redis failure blocks login with 503; exhausted limits return
429 and Retry-After. Do not reset the account limit on success. Configure trusted
proxy handling deliberately before deployment; never trust arbitrary forwarded
IP headers. Deployments sharing Redis must use the same platform keys and clocks.

`PLATFORM_MFA_ENCRYPTION_KEY` must be an independent random 32-byte key encoded
as 64 hex characters, distinct from all JWT secrets. Back it up securely outside
the repository: losing it prevents MFA login. Key rotation requires re-encrypting
existing secrets; do not simply replace the key. No automated MFA recovery,
password reset, key rotation or IT-account invitation exists in this phase.

After backup, staging migration tests and secure key configuration, an authorized
host operator can run the following in a private, non-recorded interactive terminal:

```bash
ALLOW_PLATFORM_BOOTSTRAP=true npm run platform:bootstrap
```

The command asks for name/email, a hidden password twice, then displays a private
authenticator setup key. Enter it into an authenticator and confirm the generated
code. The account is created only after confirmation, with an audit event. Do not
share or capture the setup key. Wait for the next authenticator code before login.
Repeat for a second trusted reviewer, then remove the bootstrap environment flag.
There are no default passwords and no generated keys are written to project files.

Bootstrap creates at most two SUPER_ADMIN accounts, counts disabled reviewers
toward that limit, refuses duplicate email rather than overwriting credentials,
and uses a serializable transaction to serialize competing setup attempts.
The CLI is a privileged host operation, not a remotely accessible API. An
unsuccessful setup must discard its displayed key before retrying. School user
tables are never modified. Staging must verify the limit under real MySQL
concurrency; the automated tests below use mocks.

The service accepts only a verified platform context, never school `authUser`.
Application approval is deliberately NOT school activation: it creates no
Organization, branch, user, invitation or enrollment. Rejected application codes
remain reserved in this first phase; reopening/releasing them needs an explicit
audited workflow. Code availability is rechecked at review and must be checked
again during future provisioning.

Audit records store actor, action, entity and status changes, not passwords,
tokens, school content or administrator email. No update/delete audit method is
exposed; database administrator tamper protection and external archival remain
deployment work. Account status/permissions are checked on every service call.

Validation from backend/:

```bash
npm run prisma:generate
npm run typecheck
npx vitest run tests/platform-governance.test.ts tests/platform-routes.test.ts tests/platform-login.test.ts tests/platform-login-limit.test.ts tests/platform-health.test.ts tests/platform-audit.test.ts tests/platform-sessions.test.ts
```

Tests use an isolated mocked Prisma client, not the school database. They verify
permission boundaries, token/session validation, logout, HTTP cross-domain
rejection, decision guards, audit-write failure propagation and compare-and-set
conflicts, RFC TOTP vectors, encrypted-secret tamper rejection, login replay
guards, bootstrap limits and limiter failure handling. HTTP tests require
permission to open an ephemeral local port.
An isolated real MariaDB/Redis upgrade test is now available. None of the
platform migrations has been applied to the running school database.

### Disposable Database Verification

Prerequisites: local `mariadbd`, `mariadb-install-db`, `mariadb`, `redis-server`
and `redis-cli`, plus installed backend dependencies and generated Prisma client.
The runner creates a private temporary data directory, dynamically allocated
loopback ports, a random database name and test secrets. It does not read an
existing database URL for its test connection or modify running school services.
Private-socket shutdown and temporary-directory cleanup run on normal completion
or caught errors. Do not run the underlying integration test against live data.

```bash
# Full historical migration replay (currently fails: see blocker below)
npm run test:platform:staging

# Test an existing-schema upgrade with the three governance migrations
npm run test:platform:staging -- --upgrade-baseline

# Test the safe empty-database installer and the complete migration history
npm run test:platform:staging -- --fresh-install
```

The upgrade mode derives a pre-platform baseline from the current Prisma schema
by removing only the platform models/enums. It creates that baseline in a fresh
disposable database, then applies the five actual governance/onboarding SQL migrations.
This is NOT a replay of historical migrations or a copy of production data.

Verified result: 15 real-service integration tests pass, covering concurrent
bootstrap limits, login/replay rejection, independent approval, audit/revocation,
concurrent decision exclusivity, live database/Redis health checks, Redis throttling and database rollback when an
injected audit trigger rejects a write. Both request creation and OTP/session
creation roll back on audit failure. Test-only OTP watermark resets avoid waiting
for an authenticator period; they are never used in application code.

The HTTP onboarding journey creates disposable requester, reviewer and IT
fixtures, then signs each in through the actual password/MFA login route. It
checks requester self-approval rejection, approved-only IT visibility, separation
of approval and provisioning, inactive creation/retry, sanitized read-only
progress, role-specific readiness, and logout token invalidation. These requests
use real MariaDB and Redis rather than mocks. No school admin or invitation is
created by provisioning, and the public acceptance route remains disabled.
This is HTTP-to-database coverage, not browser-to-backend end-to-end verification.

**Historical-order limitation:** direct full historical replay still fails at
`202605071410_add_parent_portal_tables` with MariaDB foreign-key error 1005/150.
That migration references tables created by later migrations. This predates the
governance changes. Do not rename already-applied migrations, disable foreign-key
checks, or mark a failed migration as applied on a live database as a shortcut.
The guarded fresh installer below provides a tested installation path without
rewriting that history. It does not fix shadow-database replay by `migrate dev`;
a separate reviewed rebaselining plan is still needed for that workflow.

### Safe Fresh Installation

For a new, already-created, empty database only, set `FRESH_DATABASE_URL` in the
operator's secure environment and run:

```bash
npm run db:install:fresh -- --confirm-empty-database
```

Do not put credentials in shell arguments/history or use the school database as
the target. `DATABASE_URL` is deliberately NOT a fallback. The installer checks
for any existing tables/views or stored routines and refuses a non-empty target,
including a database with failed or partially applied migrations. It performs
no reset, DROP, automatic retry, foreign-key disabling or deletion of school data.
An advisory database lock prevents two instances of this installer running
against the same target at once. Use a maintenance window and prevent other
writers; this lock cannot control unrelated SQL clients.

It executes the unchanged tenant/auth and student-domain SQL first, recording
each prerequisite with Prisma only after that SQL succeeds. It then runs normal
`migrate deploy` for the remaining migrations, including parent portal and platform
governance. All original file names, contents and checksums are preserved. This
is not a blanket `resolve --applied` shortcut for migrations that did not run.

Verified on disposable MariaDB: 28 migrations up to date, subsequent normal
`migrate deploy` reports no pending migrations, a repeat fresh installation is
refused, and all 15 real-service governance tests pass. The same 15 tests also
pass after upgrading a schema-derived pre-platform baseline (not a replay of
historical migrations). Activation regressions cover missing provisioning
timestamps, concurrent activation, audit-failure rollback and inconsistent
post-activation access, verifying blocked attempts do not change access or add
activation audit records. The runner additionally
checks that missing confirmation or missing explicit target is rejected.

MySQL DDL does not roll back as a unit. If installation fails halfway, stop and
inspect the new target; do not rerun with an override or mark failed SQL as
applied. The installer has intentionally no force/recovery option. Existing
deployments continue using their normal reviewed upgrade process, not this tool.
The live school database has not been migrated or modified during these tests.

The runner's tests are skipped by ordinary `npm test` unless the isolated-run
flag and an explicitly named disposable database are supplied. Existing tests
elsewhere may use school data; this runner executes only its dedicated test file.
Browser-to-backend staging smoke tests and recovery/key-rotation operations remain
pending. The frontend UI tests still use mocked responses.

### Platform Web UI Regression Checks

From the repository root, run `bash scripts/test-platform-web.sh`. Set
`FLUTTER_BIN` if Flutter is not on PATH and `CHROME_EXECUTABLE` if Chrome or
Chromium cannot be discovered automatically. Existing Flutter dependencies must
already be installed; the runner uses `--no-pub`.

Verified: 39 tests pass in headless Chromium, including sign-in through the form,
opening Super Admin onboarding readiness, failed refresh hiding stale results,
successful retry, IT queue search/setup filters/pagination, provisioning/progress
views, application-scoped audit navigation, onboarding overview navigation,
main-list refresh failure/retry handling, service-specific health guidance,
and session-bound dialogs.
The sign-in/onboarding flow is checked at 390px and 1280px widths. These are
browser-executed Flutter tests with mocked HTTP responses, not proof of live
MFA, delivery or browser-to-backend integration. They do not modify school data
or activate real accounts.

CI runs this browser suite after the standard Flutter tests. A separate
`platform-staging` matrix runs both fresh installation and schema-baseline
upgrade checks using disposable MariaDB and Redis, without deployment secrets.
The main backend CI job initializes its empty service database using the guarded
fresh installer rather than replaying migrations in the known-invalid historical
order. These workflow changes still require an actual GitHub Actions run to
verify the hosted runner environment.

For a local release gate with browser checks, set `RUN_PLATFORM_WEB=1` when
running `bash scripts/release-gate.sh`. This opt-in requires an installed browser;
it does not enable live API smoke tests or deploy anything. The release gate's
existing backend tests still need their normal test environment.

Next implementation gates, in order:

1. Use the tested guarded installer for new empty databases. Historical-order
   shadow-database replay remains a separate rebaselining task.
   Real-service governance fresh-install/upgrade/concurrency/rollback tests pass; complete
   browser staging smoke tests, recovery and key-rotation procedures before
   reviewed deployment with dedicated secrets.
2. End-to-end platform console and staging integration tests for the guarded routes. The
   isolated HTTP tests already check cross-domain token rejection; full database
   and browser-session coverage remain necessary before release.
3. IT provisioning of approved applications only, expiring first-admin invite,
   transactional activation and retry/idempotency handling. No school access
   before acceptance and activation checks.
4. Extend the implemented operational health/audit views with incident workflow,
   backup verification and approved, time-limited support access. No routine
   access to school content for IT.

Before deployment, back up and test migration on a disposable/staging database.
Do not manually activate platform accounts or expose the internal service as an
unauthenticated route to bypass these gates.
