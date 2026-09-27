# Parent Portal

The supplied parent screenshots define the visual direction: navy navigation,
gold selected actions, white panels, pale metric icons, child selection, and
responsive multi-column layouts. Keep the current application's brand assets.
Names, scores, dates, photographs and contact information in mockups are not data.

## Stage 1: Verified Family Records

- Parent-only workspace endpoints resolve the current authenticated account and
  its guardian/student links on every request. Never accept another parent ID.
- Dashboard and My Children use linked children, monthly attendance and unique
  independently memorised ayahs. Profile includes school details, enrollment
  history and the current class timetable, not internal support notes.
- Attendance distinguishes present, late, absent, excused and unrecorded days.
  Attendance rate counts late as present and excludes excused records from its
  denominator; missing records are not absences. A school calendar is necessary
  before claiming a count of scheduled school days.
- Quran progress uses the same canonical surah/juz catalog as the teacher
  workspace. Voided records are excluded, overlapping ayahs are deduplicated,
  and reading/revision/tajweed are not treated as memorisation. Raw internal
  session notes are not released as parent-facing comments.
- Existing scoped announcements and finance endpoints remain the source of
  school notices, invoices and payment status. No payment is marked successful
  from a client click or provider initiation alone.
- Add Child and profile corrections require office verification. A parent
  must never obtain another child's records by entering an admission number.

No new tables are needed for these read workflows. Add indexes only against
measured query needs; the existing org/student/date indexes cover their scope.

## Stage 2: Private Family Messages

- FamilyConversation is unique per tenant, child, verified parent and class
  teacher. Different guardians never share a conversation. The eligible-contact
  directory uses the same active-class assignment policy as the teacher portal.
- FamilyMessage uses tenant-composite foreign keys, immutable text and a unique
  sender/client UUID. Retrying an uncertain send with the same payload returns
  the original message; changing the payload with that UUID returns 409.
- Every directory, inbox, history, send and read acknowledgement rebuilds access
  from live guardian links, active student/accounts, current class teacher and
  teacher branch scope. Reassignment/revocation removes access, not stored history.
  Re-linking the same verified pair restores their retained thread. A newly
  assigned teacher cannot read a previous teacher's conversation.
- Sends lock the organisation, student, class and membership rows before
  authorisation, sharing the school writer's locking order. Audit entries contain
  IDs only, never private message bodies. Reads use no-store responses.
- History is cursor-paginated. Each participant has a monotonic read-through
  message ID; acknowledgements validate that ID belongs to this conversation.
  New messages arriving after the acknowledged ID remain unread.
- The UI requires explicit contact selection, confirms unsent draft disposal and
  retains the exact pending payload for retries. It is in-app text only, with
  manual refresh; no offline persistence, attachments, SMS or WhatsApp delivery.
- Endpoints live at /api/family-messages for PARENT/TEACHER only. ADMIN does not
  acquire private-message access merely because it is an administrator.

## Remaining Domain Work

The screenshot features below are separate backend-backed stages, not fake
statistics, pretend inboxes or buttons claiming a save without persistence:

1. Published academic reports: Assessment, AssessmentResult, ReportingPeriod,
   StudentReport and immutable published ReportSnapshot. Teacher drafts remain
   private. Admin publication/retraction is audited. Parent report and PDF routes
   recheck guardian access; averages and ranks require a defined grading policy.
2. Communication extensions: reviewed administrative support conversations,
   authorised attachments, realtime delivery and retention/export policy. The
   initial private parent/class-teacher text conversation is implemented above.
3. Parent requests: verified account and optional linked child, typed request,
   review state, admin/staff ownership, replies and audit history. Attendance
   explanations are requests, never permission to change the school register.
4. Events: add explicit publication and audience/branch targeting to the existing
   FoundationEvent model before exposing events to families. Default existing
   events to staff-only. Registration/meeting slots require capacity, cancellation
   and concurrency rules; no public exposure of today's internal event records.
5. Resources: published class/subject assignments, authorised asset delivery and
   safe downloads. Reuse course media storage without granting locked content.
6. Support/settings: persisted notification preferences, profile-change requests,
   password verification and session revocation, data export, and reviewed account
   closure. Do not display nonfunctional toggles or translate labels only while
   claiming a complete language switch. Reuse configured support contacts.

## Verification

Test tenant isolation, removed links, disabled accounts, unknown IDs, multiple
children/branches, future/private announcements, empty records, late/excused
attendance, overlapping/voided Quran sessions, responsive layouts, failed loads
and child selection across page changes. Do not use real children as test fixtures.
