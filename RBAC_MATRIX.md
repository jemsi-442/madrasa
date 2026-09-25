# MODERN ISLAMIC FOUNDATION RBAC Matrix

Last updated: `2026-09-25`

This document is the intended access reference for the MODERN ISLAMIC FOUNDATION platform.

**Flutter migration note:** Frontend URL/page tables below describe the former React implementation and desired access boundaries, not currently shipped Flutter routes. The active Flutter app has role-specific read-only navigation only. Backend route and ownership checks remain enforceable; each Flutter workflow must be checked against this matrix as it is rebuilt.

For the future online learning platform, protected media direction, and free-vs-paid content architecture, see [LMS_CONTENT_BLUEPRINT.md](LMS_CONTENT_BLUEPRINT.md).

It defines:

- which role may open which frontend page
- which role may call which backend area
- which access is limited by ownership or teaching assignment
- which admin capabilities are normal admin access and which are preview-only

## 1. Core Roles

### `ADMIN`

Purpose:

- oversee the institution
- manage admissions, students, guardians, classes, reports, and cross-role review
- supervise finance without becoming limited to finance-only work

Normal access:

- operations home and overview pages
- student and guardian governance
- finance and inquiry follow-up
- teacher and parent preview routes

### `ACCOUNTANT`

Purpose:

- manage billing, invoices, payments, receipts, expenses, and finance follow-up

Normal access:

- finance home
- finance workspace
- public inquiries that need office and finance follow-up

Not allowed:

- student governance pages
- teacher work pages
- parent family pages
- operations-wide reporting home

### `TEACHER`

Purpose:

- manage assigned class work, attendance, roster context, and hifdh work

Normal access:

- teaching home
- attendance pages
- hifdh pages
- class detail and teacher-scoped student detail

Not allowed:

- finance office pages
- guardian governance
- operations-wide reporting home
- parent pages

### `PARENT`

Purpose:

- follow their own child or children only
- view attendance, updates, finance, receipts, and hifdh progress

Normal access:

- family home
- parent portal pages

Not allowed:

- staff pages
- finance office pages
- teacher pages
- institution-wide reports

## 1A. `LEARNER` Role Direction

`LEARNER` is active in backend auth and RBAC, and a student can link to one learner login. Self-scoped learner APIs include profile, study, billing, and course/media access. Flutter currently provides a role-aware read-only learner workspace, not the former React `/learner-dashboard` route.

The page and media experience below is the direction for dedicated Flutter screens; backend availability does not imply the Flutter workflow is complete.

Purpose:

- let an enrolled learner follow their own study journey directly
- separate self-service learner access from `PARENT` access
- support older course students without turning them into staff or parent users

Recommended rule:

- do not create a role called `BIG STUDENT`
- use one role called `LEARNER`
- distinguish program type in data, not in RBAC role count

Recommended learner categories in data:

- `MADRASA_CHILD`
- `COURSE_STUDENT`

Why this is cleaner:

- role answers: "what may this person do?"
- category answers: "which program is this learner in?"
- the system avoids role sprawl caused by age group naming

## 2. Access Rules

The system follows these rules at all times:

- sidebar visibility is not security
- frontend route guards must block wrong-role page access
- backend `requireRole(...)` must block wrong-role API access
- service-level ownership checks must block cross-record leakage
- `ADMIN` preview is an oversight capability, not a merged staff role

## 3. Frontend Page Matrix

Legend:

- `Y` = allowed
- `P` = allowed as admin preview/oversight
- `-` = not allowed

| Page Area | ADMIN | ACCOUNTANT | TEACHER | PARENT |
| --- | --- | --- | --- | --- |
| Public website | Y | Y | Y | Y |
| Login / forgot password / parent access | Y | Y | Y | Y |
| Operations Home (`/dashboard`) | Y | - | - | - |
| Enrollment Overview (`/dashboard/students`) | Y | - | - | - |
| Attendance Overview (`/dashboard/attendance`) | Y | - | - | - |
| Finance Overview (`/dashboard/finance`) | Y | - | - | - |
| Student pages (`/students*`) | Y | - | - | - |
| Finance Home (`/accountant-dashboard`) | Y | Y | - | - |
| Finance workspace (`/finance*`) | Y | Y | - | - |
| Public Inquiries (`/inquiries`) | Y | Y | - | - |
| Teaching Home (`/teacher-dashboard`) | P | - | Y | - |
| Teacher workspace (`/teacher*`) | P | - | Y | - |
| Class detail (`/classes/:classId`) | P | - | Y | - |
| Family Home (`/parent-dashboard`) | P | - | - | Y |
| Parent portal (`/parent*`) | P | - | - | Y |

## 3A. Proposed Learner Frontend Matrix

This is the former React route map and a target for future Flutter pages, not a list of currently shipped Flutter routes.

| Page Area | LEARNER |
| --- | --- |
| Public website | Y |
| Login / forgot password | Y |
| Learner Home (`/learner-dashboard`) | Y |
| Learner Attendance (`/learner/attendance`) | Y |
| Learner Results / Progress (`/learner/progress`) | Y |
| Learner Hifdh or Course Progress (`/learner/hifdh`) | Y |
| Learner Billing (`/learner/billing`) | Y |
| Learner Receipts (`/learner/receipts`) | Y |
| Learner Announcements (`/learner/updates`) | Y |
| Parent pages (`/parent*`) | - |
| Teacher pages (`/teacher*`) | - |
| Finance office pages (`/finance*`) | - |
| Student governance pages (`/students*`) | - |
| Operations pages (`/dashboard*`) | - |

## 4. Page Purpose Map

These names are intentional so that home pages do not swallow full work pages.

### Admin

- `Operations Home`
  - welcome, institutional health, and direction
- `Enrollment Overview`
  - admissions and student intake direction
- `Attendance Overview`
  - institution-wide attendance signal
- `Finance Overview`
  - institution-wide finance signal

### Accountant

- `Finance Home`
  - office entry page for financial health and next steps
- `Collection Health`
  - billing pressure and collection signal
- `Recent Payments`
  - recent money-in activity
- `Open Invoices`
  - unpaid workload needing follow-up

### Teacher

- `Teaching Home`
  - class welcome page and work direction
- `Class Readiness`
  - assigned-class readiness and roster pressure
- `Recent Hifdh`
  - latest memorization follow-up

### Parent

- `Family Home`
  - welcome page for family overview and next actions
- `Linked Students`
  - child relationship context
- `Attendance History`
  - child attendance follow-up
- `Finance Snapshot`
  - billing and receipt visibility
- `School Updates`
  - family-facing notices
- `Hifdh Progress`
  - memorization progress follow-up

### Proposed Learner

- `Learner Home`
  - welcome page for self-service learning overview
- `My Attendance`
  - own attendance follow-up
- `My Progress`
  - own academic or course progress
- `My Hifdh`
  - own memorization progress when applicable
- `My Billing`
  - own fee and invoice visibility
- `My Receipts`
  - own completed payment proof
- `My Updates`
  - learner-facing notices and schedule updates

## 5. Backend API Matrix

This matrix reflects the current enforced direction of the main backend areas.

| Backend Area | ADMIN | ACCOUNTANT | TEACHER | PARENT |
| --- | --- | --- | --- | --- |
| `/api/auth` | Y | Y | Y | Y |
| `/api/public/*` | Y | Y | Y | Y |
| `/api/reports/dashboard` | Y | - | - | - |
| `/api/reports/teacher-dashboard` | Y | - | Y | - |
| `/api/reports/attendance/summary` | Y | - | Y | - |
| `/api/reports/attendance/export` | Y | - | Y | - |
| `/api/reports/students/export` | Y | - | Y | - |
| `/api/reports/finance/monthly-summary` | Y | Y | - | - |
| `/api/students` list | Y | Y | - | - |
| `/api/students/:id` detail | Y | - | Y* | - |
| `/api/guardians` | Y | - | - | - |
| `/api/classes/:id` | Y | - | Y | - |
| `/api/enrollments` | Y | - | Y | - |
| `/api/invoices` | Y | Y | - | P** |
| `/api/payments` | Y | Y | - | - |
| `/api/expenses` | Y | Y | - | - |
| `/api/parent-portal/*` read | Y*** | - | - | Y |
| `/api/parent-portal/students/:studentId/payments` | - | - | - | Y |
| `/api/hifdh-progress` | Y | - | Y | P** |

Notes:

- `Y*`
  - teacher access is limited to students connected to the teacher's assigned class ownership
- `P**`
  - parent access happens through parent-scoped portal flows, not office-wide list authority
- `Y***`
  - admin may enter parent portal read flows as oversight preview when needed

## 5A. Proposed Learner API Matrix

This is the recommended backend direction if `LEARNER` is added later.

| Backend Area | LEARNER |
| --- | --- |
| `/api/auth` | Y |
| `/api/public/*` | Y |
| `/api/learner/me` | Y |
| `/api/learner/attendance` | Y |
| `/api/learner/progress` | Y |
| `/api/learner/hifdh` | Y |
| `/api/learner/finance` | Y |
| `/api/learner/receipts` | Y |
| `/api/learner/announcements` | Y |
| `/api/students` | - |
| `/api/guardians` | - |
| `/api/invoices` office list | - |
| `/api/payments` office list | - |
| `/api/expenses` | - |
| `/api/reports/*` | - |

Important:

- learner APIs must always be self-scoped
- learner must never supply another learner's id in a way that changes ownership
- learner billing/receipt access must expose only personal records

## 6. Ownership and Scope Rules

### Teacher scope

Teacher access must remain limited to:

- assigned classes
- class rosters under that teacher
- attendance connected to those classes
- hifdh work under the teacher's responsibility
- student detail only when the student belongs to the teacher's current class

Teacher must never gain:

- branch-wide student governance authority
- office finance authority
- guardian registry authority

### Parent scope

Parent access must remain limited to:

- their linked child or children
- their own invoices, payments, receipts, attendance, and hifdh progress
- parent-facing announcements

Parent must never gain:

- office-wide invoice or payment lists
- other families' data
- teacher or staff pages

### Accountant scope

Accountant access must remain limited to:

- finance home and finance workspace
- invoices, payments, receipts, expenses, finance reports
- finance-related inquiry follow-up
- branch-scoped finance records when the accountant account is tied to a branch
- branch-scoped finance inquiries when the accountant account is tied to a branch

Accountant must never gain:

- admissions governance
- guardian governance
- teacher work pages
- parent family pages
- cross-branch finance visibility when the account is branch-bound

### Proposed learner scope

Learner access must remain limited to:

- their own attendance
- their own results or course progress
- their own hifdh or study progress
- their own invoices, balances, and receipts
- learner-facing announcements only

Learner must never gain:

- parent-family overview of other children
- student registry access
- teacher work surfaces
- finance office lists
- operations or oversight reports
- access to another learner's records

## 7. Admin Preview Policy

`ADMIN` preview exists so office leadership can inspect parent and teacher surfaces without collapsing role boundaries.

Allowed:

- open teacher home and teacher work pages in preview mode
- open family home and parent portal pages in preview mode
- inspect the same page structure another role sees
- review records, summaries, receipts, and page context in read-only mode

Not intended:

- to convert teacher or parent permissions into normal admin navigation everywhere
- to weaken service ownership checks
- to act as a shortcut around record scoping rules
- to save teacher attendance during preview
- to record hifdh entries during preview
- to initiate parent payment requests during preview

## 8. Explicit Denied Examples

These examples should remain denied:

- accountant creating or governing students
- accountant opening teacher home or teacher work pages
- teacher opening operations home
- teacher opening finance monthly summary
- teacher reading guardian registry
- parent opening office invoice and payment lists
- parent opening attendance summary reports

## 9. Implementation Status

Current enforcement already in place:

- Flutter role-aware workspace navigation; dedicated page routes are not yet ported
- backend route-level `requireRole(...)`
- teacher-scoped student detail ownership checks
- teacher-scoped student export checks
- accountant-scoped inquiry access by inquiry type
- accountant-scoped finance access by branch when branch-bound
- accountant-scoped finance inquiry access by branch when branch-bound
- integration tests for key forbidden paths

Still important to continue:

- expand service-level scope checks in remaining modules
- keep preview capability separate from base role logic
- add more forbidden-path tests whenever a new route is introduced

## 10. Learner Rollout Checklist

Historical implementation order (backend foundation is already in place; Flutter pages remain to be ported):

1. add learner role to the auth and user model
2. add student program category such as `MADRASA_CHILD` and `COURSE_STUDENT`
3. create learner-only routes and learner-only APIs
4. keep learner data self-scoped from day one
5. add learner RBAC tests before expanding learner features

Do not do this:

- do not reuse `PARENT` pages for learner login
- do not add separate RBAC roles for every age group
- do not let learner access depend only on hidden sidebar links

## 11. `LEARNER` Implementation Plan

This section describes the recommended implementation path around the phase-1 foundation that now exists in code.

### Phase 1. Data model

Status:

- done:
  - `LEARNER` user role
  - learner-to-student ownership link
  - learner program category field on `Student`
- next:
  - deeper course, billing, and study data for learner-only APIs

Add or confirm these concepts in the data model:

- user role:
  - `LEARNER`
- learner program category on the student side:
  - `MADRASA_CHILD`
  - `COURSE_STUDENT`
- optional learner account linkage:
  - one learner account should map to one student record

Recommended rule:

- keep `Student` as the academic identity
- keep `User` as the login identity
- link learner login to a single owned student record

### Phase 2. Auth and onboarding

Status:

- Online learners can self-register using name, email, password and confirmation.
- `POST /api/auth/register` always creates an active `LEARNER` with one owned `COURSE_STUDENT` profile in the configured public organization and its main/first branch.
- Public registration rejects role, organization, branch and student identifiers. It never grants staff permissions, parent linkage, enrollment or paid-course access.
- Independent learner profiles may omit guardian and gender; school admissions still require their existing fields.
- Existing office-issued learner accounts continue using the shared login.
- Parent-child access and staff accounts remain office-controlled.
- Registration attempts are limited by Redis (20 per IP per 15 minutes, fail closed if unavailable).
- Sign-in help submits an office inquiry. Automated reset links and email verification are not implemented; registration does not prove ownership of an email address.

Current seed/dev direction:

- one seeded learner account now exists in `seed:e2e-roles`
- add one course learner example later when course data exists

### Phase 3. Frontend routes

Status:

- done:
  - `/learner-dashboard`
  - `/learner/attendance`
  - `/learner/billing`
  - `/learner/receipts`
  - `/learner/hifdh`
  - `/learner/updates`
- next:
  - `/learner/progress`

Recommended learner routes:

- `/learner-dashboard`
- `/learner/attendance`
- `/learner/progress`
- `/learner/hifdh`
- `/learner/billing`
- `/learner/receipts`
- `/learner/updates`

Recommended shell direction:

- sidebar label group:
  - `Overview`
  - `Study Pages`
- home page name:
  - `Learner Home`

### Phase 4. Backend API surface

Status:

- done:
  - `/api/learner/me`
  - `/api/learner/attendance`
  - `/api/learner/finance`
  - `/api/learner/receipts`
  - `/api/learner/hifdh`
  - `/api/learner/announcements`
- next:
  - `/api/learner/progress`

Recommended learner endpoints:

- `/api/learner/me`
- `/api/learner/attendance`
- `/api/learner/progress`
- `/api/learner/hifdh`
- `/api/learner/finance`
- `/api/learner/receipts`
- `/api/learner/announcements`

Recommended rule:

- learner endpoints should be self-owned by design
- avoid generic `studentId` write access from learner requests where possible
- resolve owned student from the authenticated learner session first

### Phase 5. RBAC enforcement

Required enforcement layers:

- frontend route-role guards
- backend route-level `requireRole("LEARNER")`
- service-level ownership checks
- forbidden-path integration tests

Required denied examples:

- learner opening `/dashboard`
- learner opening `/students`
- learner opening `/finance`
- learner opening `/teacher`
- learner reading another learner's attendance, billing, or hifdh

### Phase 6. UI and product behavior

Recommended learner experience:

- simpler than parent pages
- no sibling/child switching
- no family overview concepts
- direct self-view language such as:
  - `My Attendance`
  - `My Progress`
  - `My Billing`
  - `My Receipts`

Recommended product split:

- `PARENT` sees family and child oversight
- `LEARNER` sees self-service learning and billing context

### Phase 7. Testing and rollout gate

Before release, verify:

- learner login succeeds
- learner lands on `Learner Home`
- learner can only read owned records
- learner cannot access staff or office routes
- learner billing and receipt views load correctly
- learner announcements are properly scoped

Recommended first implementation scope:

1. learner login
2. learner home
3. learner attendance
4. learner billing
5. learner announcements

Recommended second scope:

1. learner progress
2. learner hifdh or course tracking
3. learner receipts

## 12. `LEARNER` Route And API Contract

This section is the concrete contract list for the learner foundation that has started, plus the next learner surfaces to add.

### 12.1 Frontend route contract

Recommended learner routes:

- `/learner-dashboard`
  - purpose:
    - learner welcome page
    - show self-summary only
  - should include:
    - quick attendance summary
    - current course or class summary
    - billing summary
    - latest learner-facing updates

- `/learner/attendance`
  - purpose:
    - learner sees only personal attendance history
  - should include:
    - recent attendance records
    - attendance trend
    - class or course label where relevant

- `/learner/progress`
  - purpose:
    - learner sees own academic or course progress
  - should include:
    - progress summary cards
    - marks or completion trend
    - teacher remarks only if product allows it

- `/learner/hifdh`
  - purpose:
    - learner sees own memorization progress when applicable
  - should include:
    - recent hifdh records
    - progress bands
    - no staff write controls

- `/learner/billing`
  - purpose:
    - learner sees own invoices and balances
  - should include:
    - invoice list
    - current balance
    - payment instructions if enabled

- `/learner/receipts`
  - purpose:
    - learner sees own completed payment proof
  - should include:
    - completed receipts only
    - receipt detail panel

- `/learner/updates`
  - purpose:
    - learner sees learner-facing notices only
  - should include:
    - school notices
    - course notices
    - scheduling or deadline notices where relevant

### 12.2 Sidebar contract

Recommended learner sidebar groups:

- `Overview`
  - `Learner Home`
- `Study Pages`
  - `My Attendance`
  - `My Progress`
  - `My Hifdh`
  - `My Billing`
  - `My Receipts`
  - `My Updates`

Recommended shell wording:

- use `My ...` language
- avoid family language
- avoid office language
- avoid technical words like `workspace`

### 12.3 Backend endpoint contract

Recommended backend endpoints:

- `GET /api/learner/me`
  - returns:
    - learner user summary
    - owned student summary
    - program category
    - current class or course summary

- `GET /api/learner/attendance`
  - query:
    - `dateFrom?`
    - `dateTo?`
  - returns:
    - owned attendance records only

- `GET /api/learner/progress`
  - query:
    - `term?`
    - `courseId?` when relevant
  - returns:
    - owned academic or course progress only

- `GET /api/learner/hifdh`
  - query:
    - `dateFrom?`
    - `dateTo?`
  - returns:
    - owned hifdh records only

- `GET /api/learner/finance`
  - returns:
    - owned invoices only
    - balances only
    - no office-wide finance list

- `GET /api/learner/receipts`
  - returns:
    - owned completed payments only

- `GET /api/learner/announcements`
  - returns:
    - `ALL + LEARNERS` audience only
    - branch-scoped where relevant

### 12.4 Response-shape direction

Recommended `GET /api/learner/me` response shape:

```json
{
  "user": {
    "id": "12",
    "fullName": "Learner Name",
    "role": "LEARNER"
  },
  "student": {
    "id": "44",
    "admissionNo": "CRS-044",
    "fullName": "Learner Name",
    "programCategory": "COURSE_STUDENT",
    "branch": { "id": "1", "name": "Main Campus" },
    "currentClass": { "id": "3", "name": "Arabic Level 2" }
  }
}
```

Recommended `GET /api/learner/finance` response shape:

```json
{
  "summary": {
    "openInvoices": 2,
    "outstandingBalance": "45000.00",
    "currency": "TZS"
  },
  "invoices": []
}
```

Recommended `GET /api/learner/attendance` response shape:

```json
{
  "summary": {
    "present": 18,
    "absent": 2,
    "late": 1
  },
  "records": []
}
```

### 12.5 Ownership contract

Required learner ownership rules:

- learner never passes arbitrary `studentId` for ownership-changing access
- backend resolves owned learner identity from session first
- if a learner account is not linked to a student record:
  - return controlled empty-state or `403/404` according to endpoint purpose

Recommended pattern:

- `req.authUser -> learner user id`
- service resolves linked owned student
- service fetches only that learner's records

### 12.6 Delivery status

Implemented backend:

- `LEARNER` auth and student linkage
- self-scoped profile, attendance, finance, receipts, hifdh, announcements, courses, and progress APIs
- paid-course requests, invoice/payment flow, and entitlement checks for lessons and media

Flutter migration:

- a role-aware, mostly read-only learner workspace exists
- the `/learner-dashboard` and `/learner/*` paths above describe former React pages, not current Flutter routes
- dedicated course, lesson playback, billing, receipts, and progress pages still need Flutter implementation and tests

Next delivery should build those dedicated Flutter pages against existing APIs, preserving the ownership rules in this matrix.

## 13. LMS Authoring Ownership

For the future online learning side, use this rule:

- `ADMIN` creates subject families and course shells
- `ADMIN` assigns the responsible teacher
- `TEACHER` adds lessons and media assets only for assigned courses
- `ADMIN` controls publishing, pricing, and final learner visibility by default

Recommended ownership split:

- `Subject`
  - catalog structure
  - owned by `ADMIN`
- `Course`
  - teachable offering
  - created by `ADMIN`
  - taught by assigned `TEACHER`
- `Lesson`
  - content authored by assigned `TEACHER`
- `Publishing`
  - default authority stays with `ADMIN`

Why this is safer:

- dini and tech courses stay under one governance model
- teachers do not accidentally publish wrong pricing or wrong visibility
- the office keeps quality and product consistency

## Admin reference panel extension (2026-09-25)

- `GET /api/admin/overview`, `/teachers`, `/subjects`, `/guardians` and
  `/students/summary`: ADMIN only, tenant-scoped read models. No role or password
  fields are accepted from these directory queries.
- `POST /api/admin/events` and `/events/:id/cancel`: ADMIN only, audited.
- `/api/fundraising/*`: ADMIN only for this release. Donors, campaigns, pledges,
  manually received donations, receipts and voids are independent of fee invoices.
  ACCOUNTANT does not inherit these permissions until a separate delegated
  fundraising capability is explicitly approved.
- Financial relations use composite tenant foreign keys. Posting and void audit
  records share the financial transaction; repeated submission keys cannot create
  duplicate receipts. See ADMIN_PANEL_ARCHITECTURE.md for remaining domains.
- This extension does not change attendance marking, teacher class ownership,
  parent linked-child access, or learner self-service permissions.
