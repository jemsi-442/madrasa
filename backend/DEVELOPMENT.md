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

Current sign-in policy (9 October 2026): one `/login` page uses email/username
and password for school and company roles, with no MFA prompt. `/platform` is
now a compatibility alias to that same entry page, not a separate login.
`/api/auth/login` and `/api/auth/browser/login` resolve the identity once; they
reject cross-directory or multiple-school matches with a generic credential
error rather than guessing a role. Wrong/disabled company credentials never
fall back to a school account. Redis limits apply before identity lookup.
Company access tokens remain in memory and separately signed/authorized.
Browser company login also sets a host-only HttpOnly, SameSite=Lax cookie
restricted to `/api/auth/browser` (Secure in production). The origin-guarded
browser refresh endpoint restores the same verified company session after a
reload, without extending its original 15-minute lifetime. It checks account
status and server-side revocation; invalid company cookies never fall back to a
school session. Company login clears the school cookie and school login clears
the company cookie. Logout revokes the session and clears the cookie; expiry
returns to the common login page. Existing sessions must sign in once after
this update to receive the restoration cookie.
Migration `202610091200_password_company_sessions` makes the historic MFA
verification timestamp nullable; password-only sessions record null, not a fake
MFA success. Session freshness uses creation time for these sessions. Existing
school ADMIN accounts do not become Super Admins. Source changes and isolated
demo accounts are local only; the existing school database has not been upgraded.
Super Admin sees office intake/review, company account administration and office
decision history. IT alone sees technical audit, system health and setup checks.
The console does not activate approved schools.
The UI has not yet been verified against a migrated staging database.

Implemented source:

- Separate `PlatformAccount`, `TenantApplication` and `PlatformAuditEvent`
  tables in additive migration `202610071200_add_platform_governance_foundation`.
  Platform accounts default to DISABLED; school users and roles are unchanged.
- SUPER_ADMIN permissions for application intake, review and office history.
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
| GET | /audit-events | IT technical audit; Super Admin office-event allowlist only |
| GET | /health | IT/Security only; real database and Redis checks |
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
handoff check for active IT/Security accounts only (Super Admin receives 403). Only APPROVED
applications are eligible; missing and unapproved IDs both return 404. IT does
not gain access to the application directory, applicant email, decision reasons,
or school content. The response checks a recorded independent review and whether
the requested organization code is currently unused, exposing no existing school
details. Database errors fail the request instead of reporting success.

IT uses setup checks from the approved provisioning queue; Super Admin does not
see this technical action. The result is a timestamped snapshot, not a reservation or permission
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
checks current progress or refreshes the queue rather than automatically resubmitting. Session-bound dialogs
and callback checks prevent stale confirmations after logout/relogin. School
creation remains separate from first-admin invitation and activation.

Blocked setup guidance distinguishes responsibilities: a failed independent
approval check asks an independent Super Admin to review the office approval;
a school-code conflict asks IT to investigate application history without deleting
an existing school or creating a duplicate. If both fail, both responsibilities
are shown. Missing or inconclusive check details remain an IT verification task,
not a blanket escalation to Super Admin. This changes guidance only: failed
preflight still offers no creation confirmation and sends no creation request.

After creation, replay, rejection or an uncertain write result, the setup panel
retains the selected application's identity and offers **Check current progress**
and **View application history**. An already-provisioned preflight offers the
same read-only follow-up. Failed progress reads remain retryable without a new
creation request; private error details are not displayed. **Back to queue**
reloads the current page with its existing search/setup filters and removes the
old follow-up state. Creation must go through fresh preflight and confirmation
again; none of these follow-up links sends an invitation or activates a school.

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

Technical review is a separate internal `recordTechnicalReview` service, available
only to active IT_SECURITY accounts. It requires all five attestations (tenant
isolation, access controls, audit trail, backup/recovery and support escalation)
plus a private evidence reference. These are human attestations, not automated
proof. They must represent actual review, and the reference must never contain
secrets. The service records `tenant.technical-review.recorded` without changing
school or administrator access. Super Admin cannot submit this review.

The immutable audit receipt binds the sign-off to the exact reviewed application,
school, invitation and accepted administrator state using a SHA-256 fingerprint.
It is valid for less than 24 hours (an internal freshness policy), and the IT signer
must still be active with IT_SECURITY role at activation. Missing, stale, future,
foreign-application or mismatched-state receipts fail closed before access changes.
Only the latest IT receipt for that application (ordered by creation time, then
event ID) can authorize a first activation. A submitted older receipt is rejected
even if it has not expired; this matches the onboarding status view and prevents
bypassing a newer review. Recorded activation replays still perform no writes.
Office activation input is now only `invitationId`, `technicalReviewId` and
`approvalReason`; technical checklist/evidence fields are rejected. IT cannot
provide the final office approval. No sign-off or activation HTTP route is exposed.

`withdrawTechnicalReview` is also internal-only and requires an active IT account,
the latest review ID and a reason (10-500 characters). Any authorized IT operator
may withdraw the latest sign-off before activation, including another operator's
review. The immutable `tenant.technical-review.withdrawn` event is linked directly
to that `TechnicalReview` ID; it does not delete evidence or change school/admin
access. Repeating the same withdrawal returns `withdrawn: false` without another
audit write. Stale review IDs, non-pending schools and previously activated schools
are rejected. Serialization conflicts require an explicit refresh/review, not an
automatic write retry. This is not a school suspension or incident response API.

Activation and onboarding check for that withdrawal independently of timestamp
ordering. The withdrawn receipt cannot authorize activation again. A new IT
review is required; its separate receipt is unaffected by the previous withdrawal.
Super Admin sees only that preparation is waiting on IT. The withdrawal reason
and evidence remain outside office history and the progress response.

A serializable transaction changes only the pending school and accepted disabled
admin to ACTIVE, then records `tenant.school.activated` with the IT receipt ID and
office approval reason, not a copied technical checklist.
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
The open view checks snapshot age locally every 15 seconds. Once `checkedAt`
is at least one minute old, missing, invalid or in the future, progress and
readiness claims are hidden until a successful refresh returns a current check
time. This timer makes no network requests or writes and is disposed with the
view. It is a freshness warning, not a replacement for server-side authorization
or activation checks; clock skew can also require a refreshed, verified time.

For IT only, the same response includes `activationReview`: seven
read-only prerequisite checks and five outstanding manual evidence reviews.
The current requester cannot pass readiness even when another reviewer approved
the application. Missing provisioning evidence, unmatched acceptance, changed
access or a previous activation prevents readiness. Super Admin responses omit this
section entirely. `activationEnabled` remains false, including when recorded
prerequisites pass; this is not an activation authorization or a substitute for
operator evidence. No activation POST endpoint has been added.

When acceptance is complete and activation review is pending, the snapshot now
includes `nextResponsibility`: `IT_REVIEW` until a current matching IT receipt
exists, then `OFFICE_APPROVAL`. The latest receipt is checked against the exact
onboarding fingerprint, its 24-hour lifetime and the signer's current active IT
role. Super Admin receives only that next-step summary, not receipt details or
technical failure reasons. IT's `activationReview.signOffStatus` distinguishes
`MISSING`, `CURRENT`, `WITHDRAWN`, `EXPIRED`, `STATE_CHANGED`, `OPERATOR_UNAVAILABLE` and
`NOT_READY`. Fingerprints, evidence references and signer identity are never
returned. These are point-in-time read-only indicators; activation rechecks its
own authorization and receipt independently. A current IT review is not an
automated security certification or an enabled activation action.

The progress panel labels **Responsible next** for every stage. IT owns inactive
school setup, invitation preparation, technical preparation and investigation;
an independent office approver owns final business approval, never the original
requester. After activation, the madrassa administrator owns daily school work.
While email delivery is unconfigured (the current backend default), invitation
stages explicitly remain with IT and show a delivery-setup warning rather than
implying the administrator received an email. A configured delivery flag is not
proof of actual delivery. Unknown stages direct users to IT, with no repair or
activation controls. This guidance is read-only and reveals no technical evidence
to office users.

### Self-Service Session Controls

The IT console's My sessions view shows current/other active sessions, session ID,
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

Super Admin has no technical-audit permission. Its requests to this endpoint
always use an office-event allowlist: application requests/approvals/rejections,
school activation and company-account disable/restore decisions. Technical action,
actor ID or actor-role filters return 403 before reading events. Unknown future
events are excluded by default. The office UI hides health, sessions diagnostics,
technical setup, actor investigation and technical readiness checklists. Normal
sign-in, MFA and self sign-out remain available; these are account protection,
not access to IT operations. IT retains technical audit/health/setup permissions,
but does not gain office approvals or company-account administration.

The audit endpoint accepts bounded `page`/`pageSize`, exact `action`, `actorRole`
(SUPER_ADMIN or IT_SECURITY), exact `actorId`, and inclusive UTC ISO `from`/`to`
timestamps. Invalid/reversed ranges and unknown query parameters return 422.
Optional `applicationId` restricts results to that exact application's events
(including linked TechnicalReview withdrawals for IT only), without requiring or
exposing its school contents or nominated admin contacts.
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
The onboarding dialog also offers **View office history** to Super Admin (only
office-allowed events) and **View application history** to IT. IT can open that
same scope directly from a setup-queue card or its progress panel. Navigation
closes the dialog, verifies the original session is still current, clears prior
audit scopes/filters and opens page one for the selected application. Refresh
retains this scope. It sends only audit reads, never provisioning, invitation or
activation writes, and does not expand either role's permissions.
IT's Event filter also includes **IT sign-off recorded** and **IT sign-off
withdrawn**, using exact technical-review actions. Office history does not offer
these options, and the backend rejects either action for Super Admin. Sign-off
evidence, fingerprints and withdrawal reasons are not included in this audit
listing. Withdrawal events reference a TechnicalReview receipt. IT's application
history also includes withdrawals whose internal metadata links exactly to that
application, so both recorded and withdrawn sign-offs can be traced in one scope.
Action, actor and time filters still apply to both kinds of event, before bounded
pagination. Office history continues to use only its office-event allowlist and
does not include TechnicalReview events or withdrawal reasons.
IT can choose **View sign-off history** on a recorded review or its withdrawal.
The exact `technicalReviewId` audit filter includes only the original recorded
review (by event ID) and withdrawals referencing that receipt. It combines with
application/action/actor/time filters rather than replacing them. Missing IDs
return an empty list. Super Admin receives 403 for this filter. Opening the view
clears prior scopes and resets pagination; Refresh retains the review scope and
Show all clears it. No private evidence, reasons or new write action is exposed.
**View actor activity** on an event opens an exact `actorId` scope for IT only,
clears the application/action/role/period filters and resets page
one. Refresh and subsequent filters retain this scope; opening application
history or clearing all events removes it. Events without an actor ID do not
offer this action. The scope follows the recorded actor, not the affected entity,
and the UI explicitly warns that failed-login IDs are targets, not verified people.
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
The health panel also reevaluates snapshot age locally every 15 seconds. At
60 seconds old, its heading requires refresh rather than claiming current
availability. Missing, invalid or future check timestamps show an unverified-time
warning (including possible device clock skew). A fresh successful response
restores the normal heading. This is a UI freshness threshold, not an SLA or a
background health probe; it sends no network requests and stops on disposal.

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

For a disposable, local-only company and family demonstration, run from `backend`:

```bash
npm run platform:demo -- --start
```

This creates a new private `/tmp/afaq-local-demo-*` MariaDB data directory and
Redis instance on loopback ports, installs the schema there, and binds a
full application API to `127.0.0.1:4087`. It does not use the configured school
database or import its records. Two Super Admins, one IT account, one school
admin and one parent account get random
passwords; credentials are written to the printed private JSON
file (mode 600 in a mode-700 directory), never to project files. These seeded
identities are demo fixtures, not production bootstrap or an IT invitation flow.
The parent has two linked demo children, with no fabricated academic results.
Use the school admin's Family accounts page to issue its family number. The
parent can then use that number with its unchanged password. Child admission
numbers remain separate. New starts do not preserve issued family numbers.
The API runs in a separate process with explicit disposable database/Redis URLs,
fresh signing secrets, dotenv disabled, and payment-provider mock mode enabled.

Build Flutter web with `--dart-define=API_BASE_URL=http://127.0.0.1:4087` and serve
it at `http://127.0.0.1:8087`; open `/#/login`. Development loopback browser origins
are allowed by the normal app policy; browser auth still requires Origin and
X-MIF-Browser headers. No authenticator or MFA code is required. An optional
`--reuse-demo-passwords /tmp/afaq-local-demo-REPLACE/credentials.json` after
`--start` preserves passwords from a previous local demo when creating fresh
demo accounts; it does not copy school records or modify the previous database.
The normal login rate limits and role authorization remain active. Never
publish this file or reuse these credentials outside the demo. Ctrl+C stops
the demo API and its services; temporary data remains private until removed or
the OS cleans `/tmp`. Each new start creates new accounts and a new directory,
not a resume or password reset. It refuses `NODE_ENV=production` and requires
explicit `--start`; no existing database is migrated or overwritten.

To refresh a running disposable demo API without reseeding its database (Linux):

```bash
node scripts/reload-local-demo-api.mjs <api-pid> <demo-supervisor-pid>
```

Use the Node processes running `scripts/local-demo-api.ts` and
`scripts/platform-local-demo.ts`, not the npm wrapper PIDs. The helper verifies
workspace paths, ancestry and disposable loopback database/Redis configuration
before stopping only the API. It retains the environment in memory, including
existing signing keys; it does not print secrets, run migrations or reseed.
The replacement watches backend source changes and stops when the original demo
supervisor exits. Keep the helper terminal open. Existing credentials and family
numbers remain unchanged. This is a local development handover, not a production
deployment command; schema changes still require a separately reviewed migration.

If the demo supervisor/API/Redis have stopped but its isolated MariaDB process
is still alive, recover without recreating accounts or migrating the database:

```bash
node scripts/resume-local-demo-api.mjs <surviving-demo-mariadbd-pid>
```

The helper validates the private `/tmp/afaq-local-demo-*` data directory and
nonstandard loopback ports, reads the original configuration from that process
without printing secrets, and starts only Redis and the API. Ports must be free.
Passwords, records and signing keys are retained; Redis ephemeral state is not.
Keep this command running. Ctrl+C stops only the services it started, not MariaDB.
It cannot recover a stopped database or missing original process environment.

Unified login JSON is `login`, `password`; company responses include
`scope: platform`, a 15-minute access token and minimal profile, not a refresh
token. School browser responses retain their existing HttpOnly cookie flow.
The compatibility platform endpoint accepts `email`, `password` in the running
application. Role selectors and verification codes are not part of these inputs.
Production requires HTTPS at the trusted ingress. Registration-number issuance
and parent/child selection are a subsequent feature, not implemented by this login change.

The legacy MFA login helpers are retained for compatibility/testing; they do
not govern the new application login. The controlled bootstrap CLI now creates
password-only reviewers without enrolling MFA.

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

For legacy encrypted MFA records, `PLATFORM_MFA_ENCRYPTION_KEY` must be an independent random 32-byte key encoded
as 64 hex characters, distinct from all JWT secrets. Back it up securely outside
the repository: losing it prevents MFA login. Key rotation requires re-encrypting
existing secrets; do not simply replace the key. No automated MFA recovery,
password reset, key rotation or IT-account invitation exists in this phase.
This encryption key is not required for the password-only bootstrap or login;
retain existing keys securely rather than deleting historic secrets.

After backup, staging migration tests and secure key configuration, an authorized
host operator can run the following in a private, non-recorded interactive terminal:

```bash
ALLOW_PLATFORM_BOOTSTRAP=true npm run platform:bootstrap
```

The command requires a distinct platform signing key and asks for authorized
setup confirmation, name/email and a hidden password twice. It creates the
account and audit event atomically, without an authenticator setup or code.
Sign in through the common login page with email and password. Repeat for a
second trusted reviewer, then remove the bootstrap environment flag.
There are no default passwords and no credentials are written to project files.

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

Verified: 80 tests pass in headless Chromium, including shared password-only login,
opening Super Admin onboarding readiness, failed refresh hiding stale results,
successful retry, IT queue search/setup filters/pagination, provisioning/progress
views, application/actor-scoped audit navigation, onboarding overview navigation,
main-list refresh failure/retry handling, service-specific health guidance,
snapshot expiry, unverified check timestamps and office/IT next-step guidance,
and session-bound dialogs.
Role-boundary regression checks additionally cover office-only history, hidden
technical navigation and omitted IT readiness for Super Admin. Backend checks
cover direct technical endpoint/filter denial and the office allowlist. Both
isolated fresh-install and upgrade-baseline suites pass; the upgrade HTTP journey
also verifies real database office history excludes provisioning events visible
to IT. The internal activation service is still not exposed as an operator action;
independent IT sign-off and office activation approval are enforced internally.
Delivery, operator-facing review screens and reviewed rollout remain prerequisites
before exposing that workflow.
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
# Family Login Foundation

The family uses one PARENT account linked to one guardian profile. Existing
student-guardian links allow that account to switch between children without
merging their academic, attendance or financial records. A family login is not
a student's admission number and is never used as the password.

After applying the additive `202610091400_family_login` migration to an explicitly
selected test database and generating Prisma Client, a school ADMIN can call:

```http
POST /api/users/:id/family-registration
Content-Type: application/json
Authorization: Bearer <school-admin-access-token>

{"regionCode":"DSM"}
```

The response includes `userId` and `familyLoginId`, for example
`DSM/FAM/26/001`. FAM denotes the family rather than a child's current course.
The server chooses the Dar es Salaam calendar year and allocates a sequence
shared across schools for each region/year. The identifier is globally unique.
Repeated requests return the existing identifier unchanged. Issuance, counter
allocation and the school audit entry share one serializable transaction.
Only active school admins can issue numbers to active parents with a guardian
profile in their school; branch-scoped admins are restricted to their branch.

The existing unified login accepts the family identifier and existing password.
Parent Home and Support pages display the account's family sign-in number with
a copy action. Unissued numbers show office guidance instead of sample data.
Both parent profile and workspace overview return only the signed-in family's
identifier; student admission numbers remain separate.
Email/phone login remains compatible during rollout. Ambiguous identities fail
with `Invalid credentials`; registration does not grant access to new children.

School admins now have a **Family accounts** workspace page for existing parent
accounts. It supports local search, guardian confirmation, region validation,
idempotent issuance, selectable numbers and clipboard copying. Disabled or
unlinked accounts cannot issue a number from the UI. Server authorization remains
authoritative. Existing passwords are never displayed or changed. Admins can
choose **Create parent account** for an existing guardian, supply an email and
initial password, then issue the family number after creation. Initial passwords
are discarded with the form; the next dialog reloads the saved family and linked
children from the server before issuance. Cancelling that dialog preserves the
account for later issuance. If reloading fails, retry only refreshes the list and
never repeats account creation. Initial passwords
must be shared privately; no email is sent. The paginated guardian picker excludes
already-linked guardians. Branch admins can only select families with children
linked exclusively within their branch; mixed-branch families require a
school-wide admin. The server rechecks those restrictions at creation and defaults
the new account to the branch admin's branch, rejecting a different requested branch.
Demo data includes Salma Demo and Yusuf Demo as a family awaiting account creation.
The family directory has mutually exclusive stages: Needs guardian, Awaiting
number, Number issued and Disabled. Counts cover the loaded authorized parent
accounts, not unregistered guardians. Search also matches linked child names and
admission numbers. Issuance updates the stage immediately and shows a confirmation
with a Show issued action; no email delivery is implied by that confirmation.

Public parent signup and office-reviewed approval are now implemented as described
below. Configured regional-code policy and automated email delivery remain separate
work. The UI requires the migrations and updated backend; it has not been enabled
on the existing school database.
No email delivery is configured. Do not apply this migration to an
existing school database without the normal backup and deployment review.

### Isolated family-account verification

From `backend/`, run:

```bash
npm run test:platform:staging -- --fresh-install --family-registration
```

This creates disposable MariaDB and Redis instances on temporary loopback ports,
installs the migration history in an empty test database, and removes the
instances afterward. It never falls back to the configured school database.
The integration suite exercises issuance and unchanged passwords, unified login,
browser cookie refresh, sibling visibility, unrelated-child denial, role/school/
branch restrictions, concurrent issuance, cross-school uniqueness, transaction
rollback on audit failure, and disabled-account denial.

Account creation also claims guardian/student links conditionally inside the
transaction. Concurrent requests cannot replace an existing parent or learner
link: the losing transaction rolls back its newly created account and returns
409. The isolated suite now includes both creation races (10 integration tests).
This protects one account per guardian record; it does not merge duplicate
guardian records.

Verified on 2026-10-09: eight disposable-database integration tests and 24
family/unified-login regression tests passed, with TypeScript checking clean.
MariaDB's changed-record error 1020 is retried as a full transaction, alongside
Prisma serialization conflicts, with a three-attempt limit. Other unknown database
errors are not retried or masked. Browser-session checks here use HTTP requests;
they are not a manual browser or physical-device UI acceptance test.

### Family self-registration and password recovery

- `/parent-access` is the public family request form. Name, email, phone, child
  references and a chosen password are submitted to `/api/auth/family-registration`.
  The server chooses the public site's active organization and main branch; no
  caller-supplied role, school, branch or student link is accepted. Multi-school
  public hosting must configure the correct `PUBLIC_SITE_ORG_CODE` per deployment.
- A pending application grants no login or child access. Only the password hash is
  stored. Duplicate emails receive the same generic response and never replace a
  pending applicant's password. Each response provides a private receipt; the
  accepted application's receipt hash is stored, never its plain receipt.
- School ADMIN opens Family accounts > Registration requests. Independent identity
  verification and the applicant's original receipt are required for approval.
  A name/admission match is not proof of guardianship. The receipt is NOT a login
  factor or a password. If it is lost or a request is disputed, do not approve it:
  the office can reject the pending request and ask the verified family to submit
  again. Resubmission issues a fresh receipt/password hash only for rejected requests.
- Approval atomically claims an available guardian in the reviewing admin's scope,
  creates an active PARENT account, issues a family number, and records an audit
  event. Concurrent approvals cannot create a second account. Rejection creates
  no account. Both decisions erase the application's stored password hash.
  Branch admins are restricted to their branch. School-wide admins may approve a
  family whose children span branches; that parent account has school-wide scope
  but still sees only its verified guardian-linked children.
- The school supplies the family number privately. The password chosen at signup
  stays unchanged. No automatic email, receipt delivery or email verification is
  implemented; never promise delivery. Pending requests require office follow-up.
  Duplicate pending requests never replace the original credentials. A new public
  submission can reopen an office-rejected request; the previous decision remains
  in the audit trail.
- School users can use Account menu > Change password. Super Admin and IT can use
  the Change password control in the company console. The current password is
  required; success revokes all sessions and requires sign-in again.
- Verified family recovery is available to school ADMIN through Reset password on
  a parent card. It cannot reset school administrators or company accounts. The
  office supplies the new password privately; the family number is unchanged.
  The public Forgot password page remains an office-help request, NOT an automatic
  email reset. Company account recovery remains with the company's authorized IT
  operating procedure; a school administrator never receives that authority.
- School access/refresh tokens carry `authVersion`. Password changes increment the
  version and revoke refresh tokens; all authenticated school requests check the
  current account/version, including branch and active-school status. Legacy tokens
  without a version represent version zero only. Company changes revoke its
  database-backed sessions independently.

### Deployment boundary

Migration `202610091600_family_applications` adds the request table and school
session version. Deploy it before running the new API. The isolated integration
command above installs all migrations and tests pending access denial, receipt
validation, approval races, scoped review, rejection, and password revocation.

The live isolated demo can be backed up and upgraded without losing its accounts:

```bash
node scripts/upgrade-local-family-demo.mjs DEMO_API_PID --confirm-isolated-demo
```

This Linux helper verifies the process, working directory and private loopback
database. It refuses port 3306 and any database except `afaq_local_demo`, makes a
private SQL backup under `/tmp`, then runs migration deploy with the demo's own
environment. Never use it for the real school database.

Before real deployment: arrange a protected database backup and tested restore,
review migrations, configure the public school mapping and trusted web origins,
schedule the API/client deployment together, and run acceptance checks with
authorized school accounts. This work does not migrate the existing `mms` database.
Replace all API workers together: old workers do not enforce the new session
version and must not continue serving traffic after password recovery is enabled.
Automatic email remains blocked on choosing/configuring an email provider and
verifying its sender domain. Do not paste SMTP passwords or API keys into chat.

## Family Email Preview (2026-10-09)

From `backend`, inspect the Afaq notification drafts without sending email or
reading account data:

```bash
npm run email:preview -- approved
npm run email:preview -- password-changed
npm run email:preview -- approved --html
npx vitest run tests/family-email.test.ts
```

The previews use synthetic contacts and `https://example.test/#/login`, not a
real sign-in destination. Templates contain no passwords, verification receipts,
student names or student records. Names are escaped in HTML; payloads reject
unknown fields. A password-change template is only appropriate after the
password transaction and session revocation have successfully committed.

This does not enable delivery or change the existing MANUAL approval workflow.
Before integrating a provider, IT must configure a verified sender and a trusted
HTTPS public login URL from server configuration (never from a request). Confirm
recipient ownership separately: office identity/receipt checks do not themselves
verify an email address. Persist notification jobs with the business transaction,
deduplicate retries, record provider acceptance separately from delivery, and
keep passwords, receipts and message bodies out of logs. Do not call an email
provider from inside an approval database transaction. Email setup remains an IT
responsibility, not a Super Admin setting.

### Afaq Deployment Target

IT can run the offline configuration preflight from `backend`:

```bash
npm run deployment:check -- --env-file .env.production.example
```

The example intentionally exits with code 1 because deployment secrets and the
real school mapping are empty. Supply an explicitly selected, protected deployment
configuration file to check the actual settings; do not commit that file. The
command does not load the local `.env`, connect to services, change DNS, apply
migrations or print configuration values. Exit 0 means the automated configuration
checks passed, not that deployment is ready. Exit 1 means blocked settings; exit 2
means invalid CLI usage or an unreadable configuration file. Complete every
`MANUAL` item separately, including provider setup and verified email recipients.
Secret length/format checks cannot prove randomness: generate secrets securely.

Use `.env.production.example` as the configuration reference for the agreed
domain layout: frontend `https://afaq.africa`, API `https://api.afaq.africa`,
sender `noreply@afaq.africa`, and planned support mailbox `support@afaq.africa`.
These are deployment targets, not proof of domain ownership, working DNS,
mailbox creation or email delivery. The support address is reserved configuration;
it is not wired to the application's support UI or API yet.

The template deliberately leaves secrets, database URLs and the public school
code empty, so it cannot start against a guessed database or school. Configure
them in the deployment environment. Do not replace the local development `.env`.
Only the exact apex web origin is allowed; add `www` explicitly if it will be
served, or redirect it to the apex at the hosting layer.

Build the future production web client from `frontend` with:

```bash
flutter build web --dart-define=API_BASE_URL=https://api.afaq.africa
```

Do not publish or switch local clients to this API until DNS, HTTPS and the API
deployment have been verified. `EMAIL_MODE=disabled` remains mandatory for this
template: SMTP is not integrated with automatic account notifications. IT must verify domain ownership,
configure the selected provider's exact DNS records and test delivery before
enabling automatic delivery. No DNS values or provider credentials are
invented by this configuration.

### Running Offline Capture

`afaq.africa` is a planned domain, not a verified sender. There is no DNS or
provider integration yet. Use only synthetic data in the CLI sandbox:

```bash
# Run from backend. mktemp creates a private directory for this preview session.
export EMAIL_CAPTURE_DIR="$(mktemp -d /tmp/afaq-email-preview-XXXXXX)"
export EMAIL_MODE=capture
export EMAIL_FROM=noreply@example.test
export EMAIL_LOGIN_URL=https://example.test/#/login
npm run email:capture -- approved
npm run email:capture -- password-changed
```

The command prints a path to a private JSON file containing both text and HTML.
It never sends email, accesses the database or contacts a provider. `CAPTURED`
means saved locally, not sent or delivered. Capture is forbidden when
`NODE_ENV=production` and accepts only `.test` recipients, senders and login hosts.
`EMAIL_MODE=disabled` is the default; unsupported provider modes fail validation.
The current sandbox settings are consumed by the CLI, not the running API.

Files are published atomically with mode 0600 in an owner-only directory.
Repeated identical demo commands reuse the existing file; conflicting content
under the same key is rejected. Use a fresh temporary directory after changing
the templates. Temporary previews are not a durable notification queue and have
no automatic retention policy; remove your preview directory when finished.
Do not place it under a public web directory or commit captures to source control.

Verification: `npx vitest run tests/email-sandbox.test.ts tests/family-email.test.ts`
covers configuration, private files, concurrency, conflicting retries and blocked
real recipients. Provider credentials, durable jobs, verified recipients and real
delivery tracking remain separate work before enabling automatic notifications.

### Standalone SMTP Adapter

A Nodemailer SMTP adapter is implemented, independently of the capture CLI and
the registration/password endpoints. It has no automatic callers and does not
enable delivery merely because SMTP variables are configured. Keep the production
application's `EMAIL_MODE=disabled` until verified recipients and a durable outbox
are integrated. There is no public email-send endpoint or Super Admin email panel.

IT can prepare a separate protected configuration file with `EMAIL_MODE=smtp`,
`EMAIL_FROM`, `EMAIL_LOGIN_URL`, `SMTP_HOST`, `SMTP_PORT` (465 or 587), `SMTP_USER`
and `SMTP_PASSWORD`. Set `EMAIL_SENDER_VERIFIED=true` only after completing the
selected provider's sender verification. This is an operator acknowledgement,
not automatic proof of DNS or mailbox ownership. Never commit this private file.

```bash
# Offline configuration validation, no network connections.
npm run email:check-smtp -- --env-file /absolute/path/to/private-smtp-config
# Explicitly connect and authenticate, but do not send any email.
npm run email:check-smtp -- --env-file /absolute/path/to/private-smtp-config --connect
```

The check reads only the supplied file, not local `.env`. Exit 0 means the requested
check passed, 1 means a connection/authentication failure, and 2 means invalid
usage/configuration. Errors are redacted. Connection verification does not prove
sender authorization or inbox delivery. No actual provider has been contacted
as part of implementation; tests mock the transport.

The adapter requires TLS and certificate validation, uses bounded timeouts, and
disables file/URL content fetching and protocol logging, following the
[Nodemailer SMTP documentation](https://nodemailer.com/smtp).
Only strict Afaq template payloads are accepted; arbitrary MIME, attachments and
raw messages are not forwarded. The eventual worker must load matching recipient
verification from trusted storage, never from a request-supplied flag. Family
application approval alone is not email ownership verification.

Results distinguish `SMTP_ACCEPTED`, `REJECTED` and `UNKNOWN`; acceptance is not
inbox delivery. Exceptions/timeouts return `UNKNOWN` without provider text. Do not
blindly retry: a server may have accepted the message before the connection was
lost. A stable notification UUID becomes the Message-ID for correlation, but SMTP
does not guarantee deduplication by Message-ID. The future durable outbox must
handle leases, retries and ambiguous outcomes explicitly.

Verification: 54 targeted email/preflight tests and TypeScript checks passed.
The dependency audit reports 15 issues elsewhere in the installed dependency
tree (including one critical); Nodemailer is not listed in that report. This is
not a clean production security audit. Review and test dependency remediation
before production rather than applying unchecked bulk upgrades.

### Dependency Security Remediation (2026-10-09)

The follow-up remediation resolved the 15 issues noted above: the refreshed
lockfile audit reports zero known vulnerabilities. Install with `npm ci` to
reproduce the patched dependency graph, and run `npm audit --audit-level=high`
as CI now does. Existing deployments need a tested rebuild/redeploy; an installed
package update does not replace code already loaded in a running process.

Express 4.22.3 resolves proxy-addr 2.0.8, and Morgan 1.12.1, Vitest 4.1.11 and
tsx 4.23.15 raise the direct dependency minimums. Other affected transitive
packages are pinned by the lockfile. Prisma and its client remain 6.19.3.
The narrowly scoped `@prisma/config -> deepmerge-ts: 8.0.2` override addresses
[the deepmerge advisory](https://github.com/advisories/GHSA-ggr8-5vv4-36mx).
It crosses that transitive dependency's major version, so do not remove or update
it without repeating Prisma config-load, generate and isolated migration tests.
No real database migration is part of this dependency update.

To check an already-running disposable demo after a runtime restart, use its
private credentials file printed by `npm run platform:demo -- --start`:

```bash
npm run smoke:demo -- --confirm-local-demo /tmp/afaq-local-demo-XXXXXX/credentials.json
```

This accepts only the five synthetic `.test` accounts from a private demo file
and targets fixed loopback port 4087. It checks health, login, authorized read
endpoints and denied cross-scope access, then logs out its test sessions. It
never prints credentials/tokens or changes school records; login/logout audit
and session records are expected. It does not test the browser UI, issue family
numbers, send email, reseed accounts or migrate a database. A newly created demo
has new passwords unless the previous private credential file is explicitly
reused. Temporary demo files are not production backups.

`tests/dependency-security.test.ts` verifies the
[patched proxy trust behavior](https://github.com/advisories/GHSA-jqcg-44mw-7w3h)
and loads a temporary Prisma configuration through the real config loader.
Known-advisory checks supplement application testing and deployment review;
they do not prove that the system has no vulnerabilities.

Post-update verification passed: 115 targeted unit/HTTP regressions, 20 isolated
family integration cases, Prisma generation, typecheck and backend build. The
fresh-install runner replayed all 31 migrations and checked repeat-deploy safety
on a disposable database. No migration ran against the real `mms` database.
# Shared Curriculum

The platform `Curriculum & Subjects` workspace uses `/api/platform/curriculum`.
Only active Super Admin accounts can access these endpoints; school and IT
accounts cannot manage institution frameworks.

- Create a unique subject/version draft with description and learning objectives.
- The author may edit only a draft. Submit it for an independent Super Admin review.
- Approve, then publish. Published versions are immutable; changes require a new version.
- Assign published versions to active madrasas. Repeated assignments are idempotent.
  Assignments record distribution, not teacher adoption or completion, and do not
  overwrite local subjects, lessons, assessments or older assignments.
- All writes and their audit events share one transaction. This workflow does not
  send email or SMS and does not require a messaging provider.

Deployment requires migration `202610160300_curriculum_versions`, followed by
`npx prisma generate` and an API restart. Apply migrations through the normal
deployment process; do not use `db push` against production.

Tests: `npx vitest run tests/platform-curriculum.test.ts`. For the isolated local
demo only, `node_modules/.bin/tsx scripts/test-curriculum-demo.ts <database-pid>`
checks draft, review, publication and assignment against the real database and
rolls back every test record.
