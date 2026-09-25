# Admin Panel Implementation Contract

The supplied desktop images are the admin design specification. They do not
change teacher, accountant, parent or learner workspaces. Keep the institution's
existing identity, navy sidebar, gold actions, white panels and responsive tables.
Image numbers, names, dates and percentage changes are examples, not seed data.

## Page Ownership

| Page | Purpose and source of truth | Backend extension |
| --- | --- | --- |
| Overview | Today's overview, admissions trend, recent work, upcoming events; links to task pages | Dedicated admin read model and foundation events |
| Students | Admissions, guardian links, class assignment, student details | Existing student CRUD; demographic aggregates and per-student attendance |
| Classes | Class creation, teachers, rooms, capacity, roster | Existing class/enrollment modules; lifecycle and room fields |
| Teachers | Teacher accounts, assignments and workload | Existing users/classes/courses; separate employment/leave records before showing leave or staff attendance |
| Subjects | Subject catalog and curriculum coverage | Reuse Subject; add class-subject teaching assignments and ordered curriculum lessons, not duplicate LMS subjects |
| Qur'an Tracking | Passage-level learning and teacher assessment | Keep HifdhProgress scores; add canonical surah/ayah catalog and passage states before claiming completion |
| Attendance | Daily class roster, mark/correct attendance, history | Explicit admin recording permission with actor audit, teacher ownership unchanged; optional check-in time |
| Reports | Period analysis, generated report history and downloads | Snapshot jobs with scope, filters, status and expiring file access |
| Donations | Donors, campaigns, pledges, received donations and receipts | Separate fundraising ledger, not school fee invoices |
| Communications | Compose notices, templates, audiences and delivery history | Existing announcements for in-app notices; channel adapters and transactional outbox for external delivery |
| Settings | Foundation details and authorized account settings | Existing organization/auth modules; audited administration |

## Domain Boundaries

- Routes authenticate the current tenant and role. Services validate every linked
  record within that tenant. New financial relationships also use tenant-aware
  composite database foreign keys. Cross-tenant IDs return not found.
- Fundraising uses decimal amounts in TZS. A pledge is a promise, not income.
  Only received, non-voided donations count as collections. Voids retain the
  original record, actor, reason and audit trail. Donation entry uses an
  idempotency key; a retry cannot silently create a second receipt.
- Financial records and their audit entry commit in one transaction. No hard
  delete endpoint for donations. Provider payment callbacks, when added, must
  use the same posting service and verified callback/idempotency rules.
- Events store UTC timestamps and display in the user's locale. Past/cancelled
  events do not appear as upcoming events. No fictional calendar entries.
- Aggregate endpoints compute full tenant totals, never totals from the current
  table page. Lists paginate and order deterministically. Date ranges are bounded.
- Teacher account status is not employment leave. Memorization assessment scores
  are not Qur'an completion. Missing denominators display no data, not 0% success.
- Admin UI permissions are explicit, not the union of all other roles. Admin
  tools do not impersonate teachers or accountants. Existing role restrictions
  remain until a specific capability and its tests are deliberately changed.

## Follow-on Data Design

- Academics: ClassSubjectAssignment(org, class, subject, teacher, academicYear),
  CurriculumLesson(assignment, sequence, title), ClassLessonCompletion(lesson,
  completedAt, recordedBy). TeacherLeave is separate from authentication status.
- Qur'an: canonical Surah and Ayah ranges; StudentPassageProgress with state,
  assessor, assessedAt and history. Calculate completion from distinct covered
  ayahs, not overlapping ranges or assessment averages.
- Communications: Message, MessageTemplate, AudienceSnapshot, MessageRecipient,
  DeliveryAttempt and OutboxEvent. Retry with provider idempotency; preserve
  consent, opt-outs and verified delivery callbacks. Never label queued as sent.
- Reports: ReportJob includes requester, tenant, filters, immutable snapshot,
  output location and expiry. Recheck authorization on download.
- Offline: device-scoped command IDs, revision checks, conflict resolution and
  sync checkpoints. Do not expose "Synced" until this protocol exists.

## Delivery Checks

Each implementation stage must include migration validation (when applicable),
RBAC/tenant tests, mutation/empty/error coverage, Flutter analysis/widget tests,
desktop/mobile inspection, updated progress documentation and its own commit.
Do not add clickable controls for workflows that are not implemented.
