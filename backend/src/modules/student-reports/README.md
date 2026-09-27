# Student Learning Reports

`/api/student-reports` is separate from the existing operational CSV reports.

- ADMIN creates school-wide periods (month, term or year, at most 366 days).
  Labels/dates are immutable. Creation retries use a client UUID.
- Assigned TEACHER prepares one report per student/period, saves parent-facing
  feedback and refreshes source records. Preparation retries open the same report.
- Draft -> Submitted -> Published requires teacher submission and admin review.
  Admin may return a submission or retract a release with an audited reason.
  Every mutation uses a revision and a tenant writer transaction.
- Publication is allowed only after the period end and requires feedback plus at
  least one learning/attendance record. This is not a claim of complete curriculum
  coverage: missing subjects/days are not invented as grades, zeroes or absences.
- Drafts aggregate published assessments, attendance and non-void Quran sessions
  for this class/student/period. Memorised ayahs require INDEPENDENT observations
  and are deduplicated by surah/ayah. Late counts as present; excused days are
  excluded from the rate. Internal notes and peer records are never serialized.
- Submission/publication compare the saved draft with current source data. Changed
  data requires a teacher refresh and resubmission, not silent admin acceptance.
- A ReportRelease stores an immutable single-child snapshot. Its relational
  assessment source links withhold parent access if any source is retracted.
  Republished assessments do not silently repair that report: retract, refresh
  and publish a new report. Already downloaded copies cannot be recalled.
- Attendance/Quran changes after publication do not rewrite official snapshots.
  Administrators must retract affected reports and request corrections explicitly.
- Every read/download rechecks live account, tenant and guardian/class scope.
  Parent lists/PDFs exclude drafts and retracted releases. Responses use no-store.

## PDF Deployment

Ship `backend/assets/fonts` with both source and compiled deployments. PDFKit
embeds DejaVu fonts (license included) instead of relying on server-installed fonts.
The `/pdf` endpoints return an authenticated JSON envelope with `fileName`,
`contentType` and base64 PDF bytes, using the existing session refresh client.
The web client creates a temporary Blob download URL; no public report URL or
bearer token is stored in the document. Native clients can view reports but this
stage only provides the file download action on web. Fonts cover Latin and many
other scripts; full bidirectional/Arabic document layout is not a tested feature.

Reporting periods are currently append-only; history is never deleted. Weighted
term grades, curriculum completeness rules, ranks, batch publication and report
templates are deliberately not implied by the learning-summary workflow.
