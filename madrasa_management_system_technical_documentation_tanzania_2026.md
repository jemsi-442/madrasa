# Madrasa Management System (MMS) - Technical Documentation
## Tanzania Market Edition 2026

---

## 1. Document Purpose

This document defines the technical architecture, data model, integration patterns, and operational requirements for the Madrasa Management System (MMS).

It is intended for:
- Software engineers
- Technical leads
- Product owners
- QA engineers
- DevOps and support teams

This version is written as an implementation-oriented specification, not only a product overview.

---

## 2. System Summary

The Madrasa Management System (MMS) is a multi-tenant SaaS platform for madrasas in Tanzania. It digitizes core operations including student enrollment, class management, attendance, hifdh tracking, fee billing, mobile money payments, and parent communication.

Primary market assumptions:
- Institutions operate in Tanzanian Shillings (TZS)
- Parents commonly pay through mobile money
- Some campuses experience unstable or slow internet
- Users may prefer Kiswahili and Arabic-friendly content
- A single organization may manage multiple branches

Primary business goals:
- Reduce manual paper-based administration
- Improve fee collection visibility
- Provide transparent academic and attendance reporting
- Support scalable SaaS onboarding across many madrasa organizations

---

## 3. Non-Functional Requirements

### 3.1 Performance
- Typical dashboard and listing endpoints should respond in under 2 seconds for normal tenant workloads
- Payment webhook acknowledgement should return in under 5 seconds
- Attendance marking should support bulk submission for a class in one request

### 3.2 Availability
- Production target uptime: 99.5% minimum
- Payment webhook processing must be retry-safe and idempotent
- Background jobs must survive worker restarts

### 3.3 Security
- Each request must be tenant-scoped
- All sensitive routes require authentication
- Financial and user-management actions must be auditable

### 3.4 Scalability
- The system must support multi-tenant growth without schema redesign
- Queue-backed async processing should be used for SMS, receipts, and reconciliation

### 3.5 Localization
- Currency formatting must support TZS
- Date handling should support Africa/Dar_es_Salaam timezone
- UI copy should be designed for Kiswahili-first expansion

---

## 4. High-Level Architecture

### 4.1 Technology Stack
- Backend: Node.js, Express, TypeScript
- Frontend: React, TypeScript, Vite
- Database: MariaDB
- ORM: Prisma
- Cache and Queues: Redis, BullMQ
- Authentication: JWT access tokens + refresh token rotation
- Payments: Snippe API
- Web server: Nginx
- Process manager: PM2
- Observability: file logs plus optional centralized monitoring

### 4.2 Logical Components
- Web Client: browser-based admin, teacher, accountant, and parent interfaces
- API Layer: REST endpoints, authentication, validation, response shaping
- Domain Services: business logic for students, fees, attendance, hifdh, and reporting
- Database Layer: relational persistence in MariaDB
- Queue Workers: async processing for SMS, webhook events, receipts, and reconciliation
- Integration Layer: Snippe payment API and messaging providers

### 4.3 Request Flow

```text
React Client
  -> Nginx
  -> Express API
  -> Auth Middleware
  -> Tenant Resolver
  -> Controller
  -> Service Layer
  -> Prisma ORM
  -> MariaDB

Async Side Effects
  -> Redis / BullMQ
  -> Worker
  -> SMS / Receipt / Reconciliation / Notification
```

### 4.4 Payment Flow

```text
Invoice Created
  -> Parent initiates payment
  -> MMS sends request to Snippe
  -> Snippe prompts mobile money payment
  -> Snippe calls MMS webhook
  -> Webhook verified and recorded
  -> Payment applied to invoice
  -> Receipt and notifications queued
```

---

## 5. Multi-Tenancy and Branch Model

### 5.1 Tenant Model

Each madrasa organization is a tenant identified by `org_id`.

Tenant isolation rules:
- Every business table must include `org_id`
- Every authenticated query must be filtered by `org_id`
- Cross-tenant access is never permitted in application logic
- Global admin access, if introduced later, must be explicitly separate from tenant roles

### 5.2 Branch Model

One organization may operate multiple branches.

Branch design:
- `branches` table belongs to `organizations`
- Students, classes, invoices, and attendance records should be branch-aware
- Branch scoping is required for reporting where organizations manage multiple campuses

### 5.3 Tenant Resolution

Recommended resolution order:
1. Read authenticated user record
2. Extract `org_id` from JWT claims
3. Confirm user still belongs to the same active organization
4. Apply `org_id` filter at service and repository layers

---

## 6. Functional Modules

### 6.1 Authentication and Authorization

Core capabilities:
- Login with email or phone plus password
- Access token issuance
- Refresh token rotation
- Logout and token invalidation
- Password reset flow
- Role-based authorization

System roles:
- `admin`
- `accountant`
- `teacher`
- `parent`

Authorization expectations:
- Admin manages users, classes, students, fees, and reports
- Accountant manages invoices, payments, expenses, and finance reports
- Teacher manages attendance, class records, and hifdh progress
- Parent views own children, invoices, receipts, attendance summaries, and announcements

### 6.2 Student and Guardian Management

Core capabilities:
- Student registration
- Guardian creation and linking
- Branch assignment
- Class enrollment
- Status lifecycle management
- Student transfer or graduation handling

Student statuses:
- `active`
- `inactive`
- `suspended`
- `graduated`

### 6.3 Academic Module

Core capabilities:
- Level and class setup
- Subject catalog management
- Student-class enrollment
- Exam definitions
- Score entry and reports

Initial subject examples:
- Quran
- Tajweed
- Aqeedah
- Fiqh
- Arabic

### 6.4 Hifdh Tracking

Core capabilities:
- Juz progress tracking
- Surah memorization logs
- Daily revision scoring
- Teacher remarks
- Mastery progress reporting

Expected metrics:
- Current juz
- Current surah
- Memorization score
- Revision consistency
- Completion percentage

### 6.5 Attendance Management

Core capabilities:
- Daily student attendance
- Teacher attendance
- Reason capture for absence or lateness
- Bulk class attendance submission
- Parent notifications for absence

Suggested statuses:
- `present`
- `absent`
- `late`
- `excused`

### 6.6 Finance and Billing

Core capabilities:
- Fee structure setup per class or program
- Invoice generation per term, month, or custom schedule
- Manual payment capture
- Mobile money payment tracking
- Expense logging
- Financial reporting

Recommended invoice statuses:
- `pending`
- `partially_paid`
- `paid`
- `overdue`
- `cancelled`

### 6.7 Payment Integration

Core capabilities:
- Payment initiation via Snippe
- Direct use of Snippe Payments API `POST /v1/payments`
- Transaction reference storage
- Webhook verification
- Reconciliation jobs
- Duplicate-event protection

Snippe-specific implementation assumptions:
- MMS uses Snippe's Payments API for direct mobile money collection rather than hosted sessions for MVP
- `payment_type` for MVP is `mobile`
- `details.amount` must be sent as an integer in TZS smallest unit
- Minimum supported amount is `500` TZS
- `Idempotency-Key` must be included on payment creation requests

Recommended provider-aligned payment statuses:
- `pending`
- `completed`
- `failed`
- `voided`
- `expired`

### 6.8 Communication Module

Core capabilities:
- Bulk SMS notifications
- Fee reminders
- Attendance alerts
- Announcement broadcasting
- Optional WhatsApp integration

### 6.9 Analytics and Reporting

Core KPIs:
- Total students
- Active classes
- Attendance rate
- Monthly billed amount
- Monthly collected amount
- Outstanding balances
- Payment success rate
- Student performance trends

---

## 7. Authorization Matrix

| Capability | Admin | Accountant | Teacher | Parent |
| --- | --- | --- | --- | --- |
| Manage users | Yes | No | No | No |
| Manage students | Yes | Limited | No | No |
| View student profile | Yes | Yes | Yes | Own only |
| Mark attendance | Yes | No | Yes | No |
| Manage hifdh records | Yes | No | Yes | No |
| Create invoices | Yes | Yes | No | No |
| Record payments | Yes | Yes | No | No |
| View finance reports | Yes | Yes | No | No |
| View announcements | Yes | Yes | Yes | Yes |
| View child attendance | No | No | No | Own only |
| View child invoices | No | No | No | Own only |

Notes:
- "Own only" means scoped strictly to children linked to the authenticated parent
- "Limited" means accountant access may be read-only for student identities, depending on final policy

---

## 8. Data Model

### 8.1 Design Principles

- Every business table includes `id`, `org_id`, `created_at`, and `updated_at`
- Foreign keys are enforced at database level
- Soft delete may be used for selected entities such as students and announcements
- Financial records should be append-friendly and audit-safe
- External payment payloads should be stored for dispute investigation

### 8.2 Core Tables

#### organizations

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Tenant identifier |
| name | varchar(150) | Registered organization name |
| code | varchar(50) unique | Short tenant code |
| status | enum | active, suspended, trial |
| plan | varchar(50) | Subscription tier |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

#### branches

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Branch identifier |
| org_id | bigint FK | References organizations.id |
| name | varchar(150) | Branch name |
| location | varchar(255) | Physical location |
| phone | varchar(30) | Optional branch contact |
| is_main | boolean | Main branch flag |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

Indexes:
- `idx_branches_org_id`

#### users

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | User identifier |
| org_id | bigint FK | Tenant ownership |
| branch_id | bigint FK nullable | Optional primary branch |
| full_name | varchar(150) | User name |
| email | varchar(150) unique per tenant | Login identifier |
| phone | varchar(30) unique per tenant | Alternate login/contact |
| password_hash | varchar(255) | Hashed password |
| role | enum | admin, accountant, teacher, parent |
| status | enum | active, disabled |
| last_login_at | datetime nullable | Audit field |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

Indexes:
- `idx_users_org_role`
- `uniq_users_org_email`
- `uniq_users_org_phone`

#### guardians

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Guardian identifier |
| org_id | bigint FK | Tenant ownership |
| user_id | bigint FK nullable | Linked parent portal account |
| full_name | varchar(150) | Guardian name |
| phone | varchar(30) | Contact phone |
| email | varchar(150) nullable | Optional email |
| relationship | varchar(50) | Father, mother, uncle, etc. |
| address | varchar(255) nullable | Optional address |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

Indexes:
- `idx_guardians_org_phone`

#### students

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Student identifier |
| org_id | bigint FK | Tenant ownership |
| branch_id | bigint FK | Branch ownership |
| admission_no | varchar(50) unique per tenant | Internal student number |
| full_name | varchar(150) | Student name |
| gender | enum | male, female |
| dob | date | Date of birth |
| status | enum | active, inactive, suspended, graduated |
| class_id | bigint FK nullable | Current class |
| primary_guardian_id | bigint FK | Main guardian |
| joined_on | date | Admission date |
| left_on | date nullable | Exit date |
| notes | text nullable | Optional remarks |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

Indexes:
- `uniq_students_org_admission_no`
- `idx_students_org_branch_class`

#### student_guardians

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Link row |
| org_id | bigint FK | Tenant ownership |
| student_id | bigint FK | Student reference |
| guardian_id | bigint FK | Guardian reference |
| is_primary | boolean | Primary contact flag |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

#### classes

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Class identifier |
| org_id | bigint FK | Tenant ownership |
| branch_id | bigint FK | Branch ownership |
| name | varchar(100) | Class name |
| level | varchar(100) | Program or level |
| academic_year | varchar(20) | Example: 2026 |
| teacher_id | bigint FK nullable | Assigned teacher |
| capacity | int nullable | Optional limit |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

Indexes:
- `idx_classes_org_branch_year`

#### subjects

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Subject identifier |
| org_id | bigint FK | Tenant ownership |
| code | varchar(30) | Subject code |
| name | varchar(100) | Subject name |
| is_core | boolean | Core subject flag |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

#### enrollments

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Enrollment identifier |
| org_id | bigint FK | Tenant ownership |
| student_id | bigint FK | Student reference |
| class_id | bigint FK | Class reference |
| academic_year | varchar(20) | Example: 2026 |
| status | enum | active, completed, withdrawn |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

#### attendance_records

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Attendance identifier |
| org_id | bigint FK | Tenant ownership |
| branch_id | bigint FK | Branch ownership |
| class_id | bigint FK | Class reference |
| student_id | bigint FK | Student reference |
| date | date | Attendance date |
| status | enum | present, absent, late, excused |
| reason | varchar(255) nullable | Optional reason |
| marked_by | bigint FK | User who marked attendance |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

Indexes:
- `uniq_attendance_org_student_date`
- `idx_attendance_org_class_date`

#### fee_structures

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Fee structure identifier |
| org_id | bigint FK | Tenant ownership |
| branch_id | bigint FK nullable | Optional branch-level fee setup |
| class_id | bigint FK nullable | Optional class-level fee setup |
| name | varchar(150) | Example: Term 1 Fees |
| amount | decimal(12,2) | TZS amount |
| billing_cycle | enum | one_time, monthly, termly |
| is_active | boolean | Availability flag |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

#### invoices

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Invoice identifier |
| org_id | bigint FK | Tenant ownership |
| branch_id | bigint FK | Branch ownership |
| student_id | bigint FK | Student reference |
| fee_structure_id | bigint FK nullable | Optional source structure |
| invoice_no | varchar(50) unique per tenant | Human-readable invoice number |
| amount_due | decimal(12,2) | Total billed amount |
| amount_paid | decimal(12,2) | Running paid amount |
| currency | char(3) | TZS |
| due_date | date | Invoice due date |
| status | enum | pending, partially_paid, paid, overdue, cancelled |
| issued_at | datetime | Issue timestamp |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

Indexes:
- `uniq_invoices_org_invoice_no`
- `idx_invoices_org_student_status`

#### payments

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Payment identifier |
| org_id | bigint FK | Tenant ownership |
| invoice_id | bigint FK | Invoice reference |
| provider | varchar(50) | Snippe or manual |
| reference | varchar(100) nullable | Snippe payment reference |
| external_reference | varchar(100) nullable | Downstream provider reference from Snippe |
| provider_txn_ref | varchar(100) nullable | Legacy or alternate provider transaction reference |
| request_id | varchar(100) nullable | Internal outbound initiation identifier |
| amount | decimal(12,2) | Paid amount |
| currency | char(3) | TZS |
| status | enum | pending, completed, failed, voided, expired |
| payment_type | varchar(30) | mobile, card, dynamic-qr |
| channel | varchar(50) | mpesa, airtel_money, tigo_pesa, cash |
| api_version | varchar(20) nullable | Example: 2026-01-25 |
| paid_at | datetime nullable | Payment completion time |
| raw_response | json nullable | Provider response payload |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

Indexes:
- `idx_payments_org_invoice_status`
- `uniq_payments_reference`
- `uniq_payments_provider_txn_ref`

#### payment_webhooks

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Webhook log identifier |
| org_id | bigint FK nullable | Tenant may be resolved after parsing payload |
| provider | varchar(50) | Snippe |
| event_type | varchar(100) | Provider event name |
| event_id | varchar(100) nullable | Provider event id if supplied |
| api_version | varchar(20) nullable | Webhook payload API version |
| signature | varchar(255) nullable | Received signature |
| webhook_timestamp | bigint nullable | Value of X-Webhook-Timestamp |
| payload | json | Raw webhook payload |
| raw_body | longtext | Raw body used for signature verification |
| processing_status | enum | received, processed, ignored, failed |
| received_at | datetime | Receive timestamp |
| processed_at | datetime nullable | Process timestamp |
| error_message | text nullable | Failure details |

Indexes:
- `idx_payment_webhooks_provider_status`
- `uniq_payment_webhooks_event_id`

#### hifdh_progress

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Progress identifier |
| org_id | bigint FK | Tenant ownership |
| student_id | bigint FK | Student reference |
| teacher_id | bigint FK | Assessor |
| juz_number | tinyint | 1 to 30 |
| surah_name | varchar(100) | Surah reference |
| ayah_from | int nullable | Start ayah |
| ayah_to | int nullable | End ayah |
| memorization_score | decimal(5,2) | Score value |
| revision_score | decimal(5,2) nullable | Revision value |
| remarks | text nullable | Teacher notes |
| assessed_on | date | Assessment date |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

#### announcements

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Announcement identifier |
| org_id | bigint FK | Tenant ownership |
| branch_id | bigint FK nullable | Optional branch scope |
| title | varchar(150) | Announcement title |
| message | text | Announcement content |
| audience | enum | all, parents, teachers, accountants |
| publish_at | datetime | Publish time |
| expires_at | datetime nullable | Optional expiry |
| created_by | bigint FK | Author |
| created_at | datetime | Audit field |
| updated_at | datetime | Audit field |

#### audit_logs

| Column | Type | Notes |
| --- | --- | --- |
| id | bigint PK | Audit identifier |
| org_id | bigint FK | Tenant ownership |
| actor_user_id | bigint FK nullable | User who acted |
| action | varchar(100) | Example: invoice.created |
| entity_type | varchar(100) | Example: invoice |
| entity_id | varchar(100) | Target id |
| metadata | json nullable | Additional details |
| ip_address | varchar(64) nullable | Request IP |
| created_at | datetime | Event time |

### 8.3 Critical Relationships

- `organizations` 1-to-many `branches`
- `organizations` 1-to-many `users`
- `guardians` many-to-many `students` through `student_guardians`
- `branches` 1-to-many `classes`
- `classes` 1-to-many `students` or `enrollments`
- `students` 1-to-many `attendance_records`
- `students` 1-to-many `invoices`
- `invoices` 1-to-many `payments`
- `students` 1-to-many `hifdh_progress`

---

## 9. API Design

### 9.1 General Conventions

- Base URL: `/api`
- JSON request and response bodies
- All private endpoints require `Authorization: Bearer <token>`
- Validation errors return `422 Unprocessable Entity`
- Authentication errors return `401 Unauthorized`
- Authorization errors return `403 Forbidden`
- Paginated list endpoints should accept `page`, `per_page`, and optional filters

### 9.2 Standard Response Shape

Successful response example:

```json
{
  "success": true,
  "message": "Student created successfully",
  "data": {
    "id": 101
  }
}
```

Error response example:

```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "full_name": ["Full name is required"]
  }
}
```

### 9.3 Authentication Endpoints

- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `POST /api/auth/forgot-password`
- `POST /api/auth/reset-password`

Login request example:

```json
{
  "login": "parent@example.com",
  "password": "Password123!"
}
```

Login response example:

```json
{
  "success": true,
  "data": {
    "access_token": "jwt-token",
    "refresh_token": "refresh-token",
    "expires_in": 900,
    "user": {
      "id": 12,
      "full_name": "Amina Yusuf",
      "role": "parent",
      "org_id": 3
    }
  }
}
```

### 9.4 Student Endpoints

- `GET /api/students`
- `POST /api/students`
- `GET /api/students/:id`
- `PATCH /api/students/:id`
- `POST /api/students/:id/guardians`
- `POST /api/students/:id/enrollments`

### 9.5 Attendance Endpoints

- `POST /api/attendance/bulk-mark`
- `GET /api/attendance/class/:classId`
- `GET /api/attendance/student/:studentId`

Bulk attendance request example:

```json
{
  "class_id": 9,
  "date": "2026-05-07",
  "records": [
    { "student_id": 101, "status": "present" },
    { "student_id": 102, "status": "late", "reason": "Transport delay" }
  ]
}
```

### 9.6 Finance Endpoints

- `POST /api/fee-structures`
- `GET /api/fee-structures`
- `POST /api/invoices`
- `GET /api/invoices`
- `GET /api/invoices/:id`
- `POST /api/invoices/:id/manual-payments`
- `GET /api/reports/finance/summary`

### 9.7 Payment Endpoints

- `POST /api/payments/initiate`
- `GET /api/payments/:id`
- `GET /api/payments/status/:id`
- `POST /api/webhooks/snippe`

MMS-to-Snippe provider call for mobile money:
- `POST https://api.snippe.sh/v1/payments`
- Header: `Authorization: Bearer <SNIPPE_API_KEY>`
- Header: `Idempotency-Key: <unique_key>`

Payment initiation request example:

```json
{
  "invoice_id": 5001,
  "payer_phone": "255781000000",
  "customer": {
    "firstname": "Amina",
    "lastname": "Yusuf",
    "email": "amina@example.com"
  }
}
```

Payment initiation response example:

```json
{
  "success": true,
  "message": "Payment request submitted",
  "data": {
    "payment_id": 8801,
    "provider": "snippe",
    "reference": "9015c155-9e29-4e8e-8fe6-d5d81553c8e6",
    "status": "pending"
  }
}
```

Expected Snippe request payload generated by MMS:

```json
{
  "payment_type": "mobile",
  "details": {
    "amount": 50000,
    "currency": "TZS"
  },
  "phone_number": "255781000000",
  "customer": {
    "firstname": "Amina",
    "lastname": "Yusuf",
    "email": "amina@example.com"
  },
  "webhook_url": "https://your-domain.com/api/webhooks/snippe",
  "metadata": {
    "invoice_id": 5001,
    "org_id": 3
  }
}
```

Representative Snippe success response:

```json
{
  "status": "success",
  "code": 201,
  "data": {
    "amount": {
      "currency": "TZS",
      "value": 50000
    },
    "api_version": "2026-01-25",
    "expires_at": "2026-01-25T05:04:54.063993853Z",
    "object": "payment",
    "payment_type": "mobile",
    "reference": "9015c155-9e29-4e8e-8fe6-d5d81553c8e6",
    "status": "pending"
  }
}
```

### 9.8 Reporting Endpoints

- `GET /api/dashboard/kpis`
- `GET /api/reports/attendance`
- `GET /api/reports/collections`
- `GET /api/reports/hifdh-progress`

---

## 10. Payment Integration and Webhook Processing

### 10.1 Outbound Payment Rules

- Every payment initiation must generate an internal idempotency key
- Snippe request must use `POST https://api.snippe.sh/v1/payments`
- Request headers must include `Authorization: Bearer <SNIPPE_API_KEY>` and `Idempotency-Key`
- Internal `payment_id` must be created before the provider request is sent
- Provider request and response payloads should be logged safely
- `Idempotency-Key` should remain short and deterministic per attempt
- MMS should store Snippe `reference`, `api_version`, and `expires_at`
- Invoice status should not switch to `paid` until confirmed by webhook or verified reconciliation

Recommended field mapping:
- `invoice.amount_due` or requested payment amount -> `details.amount`
- Fixed currency -> `details.currency = TZS`
- parent phone -> `phone_number`
- guardian or payer identity -> `customer`
- internal invoice and tenant identifiers -> `metadata`
- public webhook callback -> `webhook_url`

### 10.2 Webhook Endpoint

- Route: `POST /api/webhooks/snippe`
- Authentication: signature verification from provider headers
- Response: acknowledge quickly after storing payload
- Production webhook URL must use HTTPS
- Handler must read the raw request body before JSON parsing
- Endpoint should return `2xx` in under 30 seconds

### 10.3 Webhook Processing Flow

1. Receive webhook on `POST /api/webhooks/snippe`
2. Extract `X-Webhook-Event`, `X-Webhook-Timestamp`, and `X-Webhook-Signature`
3. Validate timestamp freshness and compute HMAC-SHA256 against `{timestamp}.{raw_body}`
4. Persist raw payload in `payment_webhooks`
5. Check whether event was already processed using `event.id` or `data.reference`
6. Resolve payment by Snippe `reference`, `external_reference`, or metadata
7. Update `payments.status`
8. Recalculate `invoices.amount_paid`
9. Mark invoice `paid` only if billed amount is fully covered
10. Queue receipt generation and parent notification
11. Record audit log

Supported Snippe payment events for MVP:
- `payment.completed`
- `payment.failed`
- `payment.voided`
- `payment.expired`

Representative webhook envelope:

```json
{
  "id": "evt_a1b2c3d4e5f6g7h8i9j0",
  "type": "payment.completed",
  "api_version": "2026-01-25",
  "created_at": "2026-01-24T10:30:00Z",
  "data": {
    "reference": "pi_a1b2c3d4e5f6",
    "external_reference": "SEL123456789",
    "status": "completed",
    "amount": {
      "value": 50000,
      "currency": "TZS"
    },
    "channel": {
      "type": "mobile_money",
      "provider": "mpesa"
    },
    "metadata": {
      "invoice_id": 5001,
      "org_id": 3
    },
    "completed_at": "2026-01-24T10:30:00Z"
  }
}
```

### 10.4 Idempotency Rules

- Duplicate webhook events must not create duplicate payments
- Reprocessing the same event must be safe
- `reference`, `provider_txn_ref`, and `event_id` should be unique where available
- Same `Idempotency-Key` with the same body should be treated as the same outbound attempt
- Same `Idempotency-Key` with a different body should be treated as an integration error

### 10.5 Reconciliation

Scheduled reconciliation job:
- Fetch pending or recently updated provider transactions
- Compare provider status from `GET /v1/payments/{reference}` with internal records
- Repair stuck `pending` transactions where verified
- Flag mismatches for manual review

Webhook retry expectation from Snippe:
- Non-`2xx` responses or timeouts may trigger exponential backoff retries
- Integration should tolerate up to 5 delivery attempts for the same event

---

## 11. Frontend Architecture

### 11.1 Directory Structure

Suggested structure:
- `src/pages`
- `src/components`
- `src/layouts`
- `src/routes`
- `src/services`
- `src/hooks`
- `src/store`
- `src/features`
- `src/utils`
- `src/i18n`

### 11.2 Frontend Responsibilities

- Authenticate users and manage session refresh
- Render role-based navigation
- Support filtering, searching, and export-friendly reporting
- Optimize for low-bandwidth interactions
- Provide clear payment and attendance status feedback

### 11.3 State Management

Recommended split:
- Server state: React Query or equivalent
- UI state: local state or lightweight store
- Auth state: token lifecycle plus current user profile

### 11.4 Route Groups

- `/auth/*`
- `/admin/*`
- `/accounting/*`
- `/teacher/*`
- `/parent/*`

### 11.5 Key Screens

- Login
- Dashboard
- Student list and profile
- Guardian list and profile
- Attendance marking screen
- Hifdh progress screen
- Fee setup screen
- Invoice list and invoice detail
- Payment tracking screen
- Parent portal

### 11.6 Low-Bandwidth Considerations

- Keep list payloads paginated
- Defer non-critical charts until primary content loads
- Use optimistic UI carefully for attendance submission
- Cache reference data such as classes and subjects
- Avoid heavy image use in admin areas

---

## 12. Background Jobs and Queues

### 12.1 Queue Use Cases

- SMS dispatch
- Receipt generation
- Payment reconciliation
- Announcement fan-out
- Daily summary generation

### 12.2 Queue Design

Recommended BullMQ queues:
- `payments`
- `notifications`
- `reports`
- `maintenance`

### 12.3 Retry Policy

- Retry transient provider and network failures
- Apply exponential backoff
- Move poison jobs to dead-letter handling after max retry count

---

## 13. Security Design

### 13.1 Authentication Controls

- Passwords hashed with bcrypt
- Access tokens short-lived
- Refresh tokens rotated on each refresh
- Logout invalidates refresh token record

### 13.2 Authorization Controls

- RBAC enforced at middleware and service layers
- Parent role restricted to linked student records only
- Tenant boundary checks enforced on every business query

### 13.3 Input and API Security

- Request validation with Zod
- Rate limiting on auth and webhook endpoints
- Sanitized error messages in production
- File upload restrictions if document uploads are added later

### 13.4 Payment Security

- Verify Snippe webhook signatures
- Compute signature from the exact raw request body and `X-Webhook-Timestamp`
- Use constant-time comparison for signature checks
- Reject stale webhook timestamps, for example older than 5 minutes
- Never trust client-side payment completion claims
- Store provider references and raw payloads for dispute handling

### 13.5 Auditability

Audit logs required for:
- Login and logout events
- User creation and role changes
- Invoice creation and cancellation
- Payment updates and reversals
- Attendance changes after original submission

### 13.6 Data Protection

- HTTPS only in production
- Database credentials in environment variables
- Backups encrypted at rest where supported
- Sensitive logs should exclude raw passwords and secrets

---

## 14. Deployment Architecture

### 14.1 Production Topology

```text
Internet
  -> Nginx
  -> Node.js API (PM2)
  -> Redis
  -> MariaDB

Background Workers
  -> BullMQ workers
  -> Redis
  -> External integrations
```

### 14.2 Environment Variables

Expected configuration:
- `APP_ENV`
- `PORT`
- `DATABASE_URL`
- `REDIS_URL`
- `JWT_SECRET`
- `JWT_REFRESH_SECRET`
- `SNIPPE_BASE_URL`
- `SNIPPE_API_KEY`
- `SNIPPE_WEBHOOK_SECRET`
- `SMS_PROVIDER_KEY`
- `TZ`

### 14.3 Environments

- `local`
- `staging`
- `production`

Deployment expectations:
- Staging mirrors production integrations as closely as practical
- Production secrets are never committed to source control
- Database migrations are executed during release workflow

### 14.4 CI/CD Expectations

- Run linting and tests before deployment
- Build frontend assets
- Apply database migrations in controlled order
- Restart API and worker processes with minimal downtime
- Roll back application release if health checks fail

---

## 15. Observability and Operations

### 15.1 Logging

Minimum logs required:
- API request summary logs
- Authentication failures
- Payment initiation and webhook events
- Queue job failures
- Unhandled application exceptions

### 15.2 Monitoring

Track:
- API error rates
- Response times
- Queue depth
- Failed webhook count
- Payment success rate
- Database CPU and storage trends

### 15.3 Backups

Backup policy:
- Daily database backups
- Retention policy aligned with business requirements
- Periodic restore tests
- Off-server backup storage preferred

### 15.4 Support Operations

Support staff should be able to:
- Inspect payment lifecycle by invoice number or provider reference
- Re-run reconciliation safely
- Review audit trail for disputed finance updates

---

## 16. MVP Delivery Scope

### Phase 1

- Authentication and RBAC
- Organizations and branches
- Students and guardians
- Classes and enrollments
- Fee structures and invoices

### Phase 2

- Snippe payment initiation
- Webhook handling
- Attendance management
- Dashboard KPIs
- Basic reports

### Phase 3

- Parent portal
- Hifdh tracking
- SMS notifications
- Reconciliation tooling

---

## 17. Future Enhancements

- Mobile app with Flutter
- Offline-capable attendance capture and sync
- Automated academic report generation
- AI-assisted risk flags for fee default or student performance
- National-level analytics for umbrella madrasa networks

---

## 18. Open Technical Decisions

Items requiring final team confirmation:
- Whether parent authentication is phone-only, email-only, or hybrid
- Whether branches can have separate fee structures and user permissions
- Whether exam and report-card design belongs in MVP or post-MVP scope
- Whether SMS provider abstraction is needed from day one
- Whether soft delete is required for finance entities or only operational entities

---

## 19. Summary

This specification positions MMS as a tenant-safe, mobile-money-ready, low-bandwidth SaaS platform for madrasa administration in Tanzania. The architecture is centered on clear tenant isolation, auditable financial workflows, resilient payment processing, and practical operational support for multi-branch institutions.

---

## End of Document
