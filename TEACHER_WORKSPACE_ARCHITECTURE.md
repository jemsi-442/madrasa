# Teacher Workspace

The supplied teacher references define the visual direction: navy navigation,
ivory canvas, white working panels, gold actions and separate, purposeful pages.
Keep the institution's existing branding and real records, not screenshot names,
example totals or unverified sync/notification badges.

## Authority and Data

- Admin assigns classes and date-bounded weekly timetable slots. Teachers cannot
  enrol students, change assignments or edit the approved subject catalogue.
- Server access uses the current teacher assignment, tenant and account branch.
  A transferred student or reassigned class is denied, including old open forms.
- Support notes and exact Qur'an sessions belong to the student's school history.
  A newly assigned teacher can see that student's earlier learning records,
  not unrelated students or former class rosters.
- New tables use tenant-composite foreign keys. Writes and audit events share
  a transaction. Client operation IDs make uncertain Qur'an/support saves retryable.
- This slice does not expose new teacher records to parents. Publication and
  messaging require explicit, independently tested parent-access policies.

## Working Slice

| Page | Purpose | Data and actions |
| --- | --- | --- |
| Dashboard | Today's teaching and follow-up tasks | Scoped counts, timetable and recent learning |
| My Classes | Assigned classes and weekly teaching times | Roster counts and admin-managed timetable |
| My Students | Find a learner and follow up | Paginated directory, scoped profile, support notes |
| Qur'an Tracking | Record exact learning activities | Canonical ayah ranges, observations, dated sessions |
| Attendance | Record and correct daily attendance | Existing versioned, audited class register |

Timetable times and school dates use Tanzania time (UTC+3).
Date ranges prevent past-term entries appearing indefinitely. Cancelled slots
stay in history. Class/teacher timetable overlaps are rejected, including
concurrent creation. A timetable subject is a display label, not lesson completion.
There is currently one teacher per class; changing this requires coordinated
assignment and timetable conflict rules across existing modules.

Reading, memorisation practice, revision and tajweed are distinct activities.
Only independently observed memorisation contributes to the recorded-memorised
ayah set. Overlaps count each ayah once. Practice is not mastery.
Voiding an erroneous session requires a reason; the original and audit remain.
Legacy HifdhProgress scores remain unchanged and are not converted into ayah mastery.

The checked-in factual catalogue contains 114 chapter names/counts and 30 juz
boundaries covering 6,236 ayahs. Retrieved 2026-09-25 from Quran Foundation's
public api.quran.com/api/v4 chapters and juzs endpoints. Sources:
[chapter metadata](https://api-docs.quran.com/docs/content_apis_versioned/4.0.0/list-chapters/)
and [juz metadata](https://api-docs.quran.com/docs/content_apis_versioned/4.0.0/list-juzs/).
Duplicate identical juz entries were collapsed and complete, non-overlapping
coverage verified. No scripture text, translation or media is bundled.
Runtime recording does not depend on the remote service. Tests verify integrity.

## Next Slices

These are design contracts, not implemented features:

| Page | Backend model and workflow needed |
| --- | --- |
| Subjects & Lessons | School curriculum versions, class-subject assignments, units/objectives, lesson preparation/resources and delivery events; separate from adult CourseLesson |
| Assessments | Approved rubrics/criteria, assessment instances, student results, versioned drafts and submit/review/publish transitions |
| Monthly Reports | Period/class runs, immutable student snapshots, readiness rules, submission, admin publication and authorized PDF delivery |
| Parent Communication | Student-linked participant threads, messages, read receipts, attachments and audited membership; external delivery is a separate configured adapter |
| Offline Sync | Durable per-account/device outbox, scoped cached rosters, operation IDs, server acknowledgements, conflict review, device registration/revocation and retention |

Storage must survive reload and process exit before saying "Saved locally".
The server must acknowledge an operation before saying "Synced". Reauthorize
revoked accounts, transferred students and reassigned classes on replay.
Never auto-overwrite conflicting attendance or assessment records.
Do not display "Trusted device" without a real registration/trust workflow.
An in-memory queue is not offline support.

Unbuilt pages must not be duplicate dashboard sections or dead links.
Existing teacher online courses and school notices remain accessible during rollout.
