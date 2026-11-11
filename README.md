# Afaq

Afaq is a cross-platform school and online-learning system. The Express API remains the source of truth; a Flutter client now targets web, Android, and iOS.

This repository follows the technical direction defined in [madrasa_management_system_technical_documentation_tanzania_2026.md](madrasa_management_system_technical_documentation_tanzania_2026.md).

## Stack

- Backend: Node.js, Express, TypeScript
- Frontend: Flutter, Dart
- Database: MariaDB
- ORM: Prisma
- Cache / Queues: Redis, BullMQ
- Payments: Snippe

## Repository Layout

```text
backend/   Express API, Prisma schema, scripts, modules
frontend/  Flutter client for web, Android, and iOS
scripts/   Local helper scripts
```

## Afaq User Handbook

The English, Afaq-branded handbook explains the main user journeys for administrators, finance officers, teachers, parents, and learners. Edition 1.4 also documents platform, madrassa and company IT/security governance, distinguishing the implemented onboarding foundation from pending email delivery and live activation workflows. Feature availability can vary by app version and school setup; this guide does not imply that every described workflow is deployed everywhere.

- [Download the PDF handbook](docs/Afaq_System_User_Handbook.pdf)
- [View or edit the HTML source](docs/afaq-system-handbook.html)

After editing the HTML source, regenerate and validate the tagged A4 PDF with `bash scripts/build-afaq-handbook.sh` (requires WeasyPrint and Poppler `pdfinfo`). Run `bash scripts/test-afaq-handbook-build.sh` to check broken-link rejection and safe output replacement.

## Current Backend Scope

Implemented backend modules include:

- Authentication and refresh token rotation
- Organizations and users
- Students and guardians
- Classes and enrollments
- Attendance
- Finance core
- Snippe payments and webhooks
- Parent portal APIs
- Announcements
- Hifdh progress
- LMS subject and course authoring foundation
- Reporting and exports

## RBAC Direction

The system follows five roles with controlled separation of access:

- `ADMIN`
  - full platform oversight
  - admissions, students, guardians, classes, reporting, and preview access
- `ACCOUNTANT`
  - finance dashboards, invoices, payments, receipts, expenses, and finance-related inquiries
  - no general student-governance or parent/teacher workspace authority
- `TEACHER`
  - own teaching home, class readiness, attendance, roster, hifdh, and teacher-scoped student/class access
  - no finance authority and no operations-wide dashboard authority
- `PARENT`
  - own family home and linked children
  - no staff workspace or finance-office authority
- `LEARNER`
  - own courses, progress, billing, and learning notices
  - no staff or other learner data

Important architectural rule:

- sidebar visibility is not treated as security
- route guards and backend role checks must enforce access independently

The formal access reference for routes, pages, and backend areas is maintained in:

- [RBAC Matrix](RBAC_MATRIX.md)

## Shared Curriculum

The curriculum foundation follows `Super Admin: Draft -> Publish -> Assign to
madrasas`, then `Madrasa Admin: map to a school subject -> adopt in classes`.
Teachers can read frameworks adopted by their assigned classes; this does not
record lesson delivery or learner achievement. Assignment, class adoption and
achievement are separate records with separate permissions. See the
[backend curriculum guide](backend/DEVELOPMENT.md#shared-curriculum) for API,
scope and migration details.

Curriculum migrations are present in the repository but have not been applied to
the populated local database. Review all pending migrations and use the normal
database upgrade process before expecting the feature to work against that
database; do not use `db push` or reset school data.

Future role direction:

- the `LEARNER` role now has phase-1 foundation in code for self-service older students or course learners
- the next learner route and API expansion is documented in the same RBAC matrix
- LMS authoring now follows `admin creates subject/course shell -> admin assigns teacher -> teacher authors inside assigned course`
- LMS authoring foundation now includes `modules -> lessons -> media assets` under assigned courses
- paid learner access now has backend grant foundation so `PAID` lessons can open only after explicit access is given
- learner course pricing and access-request flow now lets learners request paid-course access before office approval/grant
- paid learner access now also creates dedicated course invoices, lets learners initiate payment, and auto-grants course access after payment confirmation
- admin grant now marks matching learner access requests as approved automatically
- office can now move course access requests into `REVIEWING` or `REJECTED` before final grant
- office can now save internal notes on course access requests during review
- learner media access checks entitlement and uses short-lived signed links with audit logs; current redirects can still reveal upstream URLs and are not DRM
- the proposed online learning, media protection, and free-vs-paid content architecture is documented in [LMS_CONTENT_BLUEPRINT.md](LMS_CONTENT_BLUEPRINT.md)

## Flutter Frontend

The React client has been retired. Flutter is now the only application frontend, with web, Android, and iOS targets. The initial Flutter migration includes a public entry page, sign-in, role-specific navigation, and read-only views for selected existing API data.

This is a **migration foundation, not feature parity**. Former React features such as admissions forms, student editing, attendance marking, finance operations, course authoring, media lessons, and complete parent/learner workflows are not yet ported. Do not treat a successful Flutter build as proof those workflows are available. Backend RBAC and tenant/ownership checks remain mandatory regardless of what Flutter shows.

## Local Development

### Backend

1. Prepare env:

```bash
cp backend/.env.example backend/.env
```

2. Start Redis:

```bash
docker compose up -d
```

3. Install dependencies and generate the database client:

```bash
cd backend
npm install
npm run prisma:generate
```

For a **new empty database**, set `FRESH_DATABASE_URL` securely to the intended
new database, then run `npm run db:install:fresh -- --confirm-empty-database`.
The installer handles historical prerequisite ordering and refuses non-empty
targets. Do not use it to reset or upgrade an existing school database.

For an **existing initialized database**, back up and test the upgrade before
running `npm run prisma:migrate:deploy` with its configured `DATABASE_URL`.
Direct historical replay on an empty database has an ordering limitation;
see the [safe installation guide](backend/DEVELOPMENT.md#safe-fresh-installation).

To verify a fresh installation without touching school data, run
`npm run test:platform:staging -- --fresh-install` (requires local MariaDB and Redis
binaries). This creates and removes disposable services and runs governance tests.

4. Seed admin:

```bash
npm run seed:admin
```

For integration tests and smoke flows, seed test roles on a disposable local database:

```bash
npm run seed:e2e-roles
```

5. Start backend:

```bash
npm run dev
```

Backend health check:

```bash
curl http://127.0.0.1:4000/api/health
```

Backend verification:

```bash
npm run smoke:core
npm run smoke:write
npm run smoke:public-inquiry
npm test
```

Smoke and integration tests create records; use a disposable database.

After the backend steps above, return to the repository root and run the full local release gate:

```bash
cd ..
bash scripts/release-gate.sh
```

If the backend server is already running and you also want smoke coverage:

```bash
RUN_SMOKE=1 bash scripts/release-gate.sh
```

Set `WEB_API_BASE_URL=https://your-api.example` when building a deployable web artifact; the default URL is a non-production placeholder.

Default seeded admin:

- email: `admin@example.com`
- password: `ChangeMe123!`

These are **local/demo-only** credentials. Do not use them in a shared or production environment.

### Demo Login Credentials

Daily development uses **one database from `backend/.env` (`mms` locally), one Redis and one API on port 4000**. Superadmin, school, teacher, parent and learner dashboards all use this same backend. Demo means synthetic accounts/data, not another database.

#### Shared development server

Start it from the repository root in its own terminal:

```bash
cd backend
npm install
npm run dev
```

Keep the existing local MariaDB and Redis services running. `npm run dev` only starts the API; it never creates a database, migrates, seeds or resets data. The old `npm run platform:demo -- --start` command is a compatibility alias for this same server, not a second setup. Keep one API terminal open; press `Ctrl+C` to stop the API without deleting records.

| Role | Login email | Password |
|---|---|---|
| Super Admin | `superadmin@afaq.test` | Saved locally; read the private file below |
| Office Reviewer (Super Admin) | `reviewer@afaq.test` | Saved locally; read the private file below |
| IT Security | `it@afaq.test` | Saved locally; read the private file below |
| Madrasa Admin | `schooladmin@afaq.test` | Saved locally; read the private file below |
| Parent | `parent@afaq.test` | Saved locally; read the private file below |
| Quran Teacher | `quran.teacher@afaq.test` | Saved locally; read the private file below |

Passwords stay unchanged across startup. See the ignored `LOCAL_CREDENTIALS.md` file, backed by private `~/.afaq/platform-demo/credentials.json` and `teacher-credentials.json`. An explicit local-only reset is available through `DEVELOPMENT_LOGIN_PASSWORD` and `node scripts/reset-development-passwords.mjs --confirm-local-development` from `backend/`. It updates all existing platform and school login accounts, synchronizes these credential files, and revokes existing sessions without reseeding learning data. It refuses production and remote databases; never use a shared development password in production. To display all listed accounts in your own private terminal (requires `jq`), use:

```bash
jq -r '.[] | [.role, (.login // .email), .password] | @tsv' "$HOME/.afaq/platform-demo/credentials.json"
```

The unified `credentials.json` now lists all active local demo accounts across all seven roles, including Accountant and Learner. From `backend/`, run `node scripts/export-development-credentials.mjs --confirm-local-development` to refresh this directory and the account table in `LOCAL_CREDENTIALS.md` without modifying database records. It verifies password hashes and learner/student links before exporting. The teacher-only JSON remains available for existing test scripts.

**Frameworks, assignments, accounts and learning records remain in the shared database across restarts.** Keep `backend/.env` private and retain its authentication/encryption keys. Do not run `migrate reset`, recreate the database or rerun destructive seed scripts to start the app.

For teacher media practice, run these commands from `backend` with the shared development API running:

```bash
node scripts/prepare-teacher-course-demo.mjs --confirm-local-development
node scripts/check-teacher-media.mjs
```

The first command adds one persistent draft course, `Teacher media practice (Demo)`, for the saved demo teacher. It reuses an existing demo subject and never overwrites an existing course or assignment. Repeating it does not duplicate data. In **My Courses**, open that course, then its module and lessons to try video, audio, PDF and text. These are bundled synthetic player samples, not Quran recitation or approved teaching content, and are served only in development after teacher authorization. The second command verifies real API access, byte-range responses and unsigned-link denial without printing credentials or changing learning records.

Desktop Chromium verification (25 October 2026): teacher login, course/module/lesson navigation, video play/pause/seek, audio playback, stopping media when changing lessons, PDF navigation to its second page, and opening the text checklist through **Next resource** passed. Android and iPhone device playback remain unverified; desktop browser results do not replace device tests.

Teacher navigation and refresh verification (25 October 2026): a fresh desktop Chromium session signed in using the saved demo teacher, then opened **My Classes**, **My Students**, **My courses**, **Attendance**, **Qur'an Tracking**, and **Reports**. Each page returned a successful API response and reopened after a browser refresh without returning to login. This navigation check was read-only and signed out only its own browser session.

Attendance browser save verification (25 October 2026): a separate synthetic organization, teacher, class and learner were created in the existing local development database. In desktop Chromium, the teacher selected the class, opened **Take attendance**, selected **Present**, and saved through the form. The POST returned HTTP 200 and a database read confirmed `PRESENT`, version `1`. After a full browser refresh and reselecting the class, the register returned the same status and version, **Update attendance** was available, and the database still contained exactly one attendance record for that synthetic learner. Only this check's synthetic organization and its records were removed afterward; existing demo data was not reset or reseeded. Separate backend integration tests cover attendance and Quran persistence through fresh database connections.

Quran Tracking browser save verification (25 October 2026): an isolated synthetic teacher selected a synthetic learner and saved Al-Mulk (surah 67), ayahs 11-15, as **Memorisation** with **Independent** observation through **Save progress**. The API accepted the save and a database read confirmed the passage, activity and observation. After a full desktop Chromium refresh and reselecting the class and learner, the API returned the same session, ayahs 11-15 appeared in `memorisedAyahs`, and the page labelled ayah 11 as previously memorised. Exactly one session remained in the database. Only the synthetic test records were cleaned up; existing demo frameworks, assignments and learner records were untouched. This tested a synthetic teacher assessment, not achievement inferred from opening the Quran Reader. Mobile browsers, offline saves and interrupted-request recovery were not exercised by this browser check.

Quran Tracking small-screen verification (25 October 2026): the save/refresh scenario also passed in Chromium mobile emulation at **390 x 844**, with touch capability enabled. The check opened the navigation drawer, selected the class and synthetic learner, selected ayahs 11-15, scrolled to the observation form and saved. A database read confirmed the passage, activity and observation. After refresh and reselecting the learner, the same session and memorised ayahs returned without duplication; the screen displayed **5 / 30 memorised**. The captured viewport showed the header, filters, progress summary and bottom navigation fitting within the screen. Automated clicks, scrolling and keyboard dropdown selection were used; this is not a physical Android/iPhone or all-touch gesture test. Offline saving was not exercised. Only the isolated synthetic fixture was removed afterward; existing demo data was preserved.

Quran Tracking lost-response verification (25 October 2026): in the same 390 x 844 Chromium emulation, a separate synthetic save was forwarded to the real local API, then its successful response was deliberately blocked from reaching the browser. The database already contained one session while the UI offered **Retry save**. Retrying sent the identical payload and `clientId`, succeeded, and left exactly one session. A subsequent full refresh returned the same saved passage and memorised ayahs. The focused widget regression test also verifies that passage and observation controls stay locked until the uncertain save is resolved. This is in-page retry protection, not persistent offline queuing: keep the page open while a save is unconfirmed. Browser closure/restart recovery and physical-device behavior remain unverified. Only this check's synthetic records were removed afterward.

Quran retry permission regression (25 October 2026): backend integration tests replay a committed save using the original access token and `clientId` after teacher reassignment, learner transfer or account disabling. Replays are denied (404 for lost class/student scope, 403 for a disabled account), disclose no saved-session data and leave the original record and its single creation audit entry unchanged. After restoring the synthetic assignment/account, retry returns the original session without duplication. All 12 tests in `tests/teacher-workspace.integration.test.ts` passed; these cases use isolated synthetic records and do not alter demo assignments.

Quran permission feedback (25 October 2026): after a save/retry returns 403 or 404, **Save progress** is disabled for that draft and the class-refresh guidance remains visible even when the passage draft is cleared. The generic keep-open/network notice is hidden after permission denial to avoid conflicting guidance. Refreshing or selecting a new class/learner resets the local block; the server still authorizes every request. A 422 response remains editable, while uncertain network failures retain **Retry save** and the original operation ID. All 16 teacher-workspace widget tests and focused Flutter analysis passed. In Chromium mobile emulation (390 x 844), a synthetic class assignment was removed after a committed save's response was lost: retry returned 404, the refresh guidance appeared, **Save progress** was disabled and **Retry save** disappeared. The original database record remained unchanged with one creation audit entry. Restoring that synthetic assignment and refreshing returned the same session without duplication. Only the synthetic fixture was removed afterward. The 403 browser interaction and physical devices remain unverified; 403 has backend and widget test coverage.

Quran access recovery: permission-denied drafts now offer **Refresh class list** beside the explanation. **Stay here** preserves the draft; **Leave session** clears the stale class/learner selection and reloads available classes without submitting another save. The dialog reminds teachers to check learning history before recording again because an earlier uncertain save may already exist. The 403/404 recovery paths passed the teacher-workspace widget suite (16 tests) and focused analysis. Browser verification (25 October 2026, Chromium mobile emulation at 390 x 844) also passed for a revoked class assignment: **Stay here** preserved ayahs 11-15 and kept saving disabled; **Leave session** fetched an empty authorized class list and removed the stale save form without another POST. The original database record stayed unchanged. After restoring the synthetic assignment and refreshing, the same session returned without duplication. Only the isolated synthetic fixture was removed; existing demo data was not reset. Physical devices and the 403 browser recovery scenario remain unverified.

Quran correction regression (25 October 2026): backend integration tests confirm that only the recording teacher can void a session, the original passage and other fields remain unchanged, and the reason/time remain in history. Repeating the void request does not replace the original reason or duplicate its audit entry. Replaying the original save returns the voided session rather than restoring it. Progress excludes the voided passage but retains overlapping ayahs confirmed by another active session. All 13 teacher-workspace backend tests passed with synthetic records. A separate desktop Chromium check (1440 x 1000) exercised **Correct this record**: **Cancel** made no correction request, an empty reason showed validation without a request, and a valid reason submitted one successful correction. The database retained the original record with its reason/time, one void audit entry was created, the refreshed progress response excluded those ayahs, and the UI displayed **Voided**. Only the isolated synthetic fixture was cleaned up. The correction dialog on mobile/physical devices and a full browser restart after correction remain unverified.

Voided Quran history now includes **View correction details**. This opens the shared read-only details dialog with the passage, original observation, learning date, recording teacher, void date and correction reason; it does not expose another void action. Missing legacy reasons have an explicit fallback. The teacher-workspace widget suite passed all 18 tests, including opening/closing this dialog at 390px and 1440px, and focused analysis passed. On 27 October 2026, desktop Chromium automation (1440 x 1000) passed against the local release-mode preview: synthetic teacher login, opening details, checking passage/observation/reason through **Copy details**, and closing the dialog. No mutation requests were sent during the details interaction, the stored record stayed unchanged, and only the isolated fixture was cleaned up. This does not test the correction-save workflow or physical devices. Debug-mode startup still stalls on the debugger handshake; the release-mode preview below avoids that dependency.

Repeatable correction-details browser check (run from `backend`):

```bash
# One-time browser automation dependency outside the application dependencies:
npm install --prefix "$HOME/.afaq/browser-tools" playwright-core@1.60.0
PLAYWRIGHT_MODULE="$HOME/.afaq/browser-tools/node_modules/playwright-core" \
  node scripts/check-quran-correction-details.mjs --confirm-local-development
```

Start the local API on port 4000 and web preview on port 8087 first. The check requires Chromium (`/usr/bin/chromium`, or set `CHROMIUM_BIN`). It refuses production configuration and requires explicit confirmation before creating an isolated synthetic organization, teacher, learner and already-voided session in the existing local development database. It checks read-only details, not the correction-save workflow. No demo credentials are read or printed. Normal success/failure cleanup removes only its own fixture; forcibly terminating the process can interrupt cleanup. Set `CORRECTION_CHECK_SCREENSHOT` to a private local PNG path for an optional failure screenshot. A failed/timeout run is not a passed browser verification.

If the debug preview remains on its loading screen, use a separate local release-mode preview for browser checks. The observed debug failure waits for DWDS to start the app even after its scripts have downloaded; increasing test timeouts does not fix that. This workaround bypasses the debugger, not authentication, and does not change the database or deploy anything:

```bash
# Terminal 1, from frontend (keep the local API running):
flutter run -d web-server --release --web-hostname=127.0.0.1 --web-port=8088 \
  --no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:4000

# Terminal 2, from backend:
WEB_PREVIEW_URL=http://127.0.0.1:8088/ \
PLAYWRIGHT_MODULE="$HOME/.afaq/browser-tools/node_modules/playwright-core" \
  node scripts/check-quran-correction-details.mjs --confirm-local-development
```

Wait for compilation and the preview URL before starting the check. This preview has no hot reload: restart it after source changes. `WEB_PREVIEW_URL` accepts only a `127.0.0.1` HTTP origin. The normal development preview and its hot-reload workflow remain unchanged; the underlying debugger reconnection problem remains unresolved.

Teacher course navigation (27 October 2026): opening a lesson or using **Next lesson / Previous lesson** scrolls to the lesson heading, rather than leaving the teacher at the bottom of the previous lesson. Course cards and headings have separate accessibility nodes. The course/resources widget suites passed all 13 tests, including long lessons at 390px and 1440px and separate heading/card semantics; focused analysis passed. Desktop Chromium (1440 x 1000) passed on the rebuilt release preview: browser login, course/module/lesson navigation, scrolling through long synthetic content, and Next/Previous both revealing the new heading on screen. No mutation requests were sent during lesson navigation, and test-session logout succeeded. The local teacher-media API check previously passed for four authorized resources with unsigned delivery denied. Browsing does not record teaching or learner achievement or automatically open Quran Tracking. Physical-device verification remains outstanding; mobile emulation is documented below. Existing demo frameworks and assignments were not reset.

Mobile course navigation (27 October 2026): Chromium emulation at 390 x 844 passed with touch enabled, opening the mobile navigation menu, entering the assigned course/module/lesson, touch-scrolling long synthetic content, and Next/Previous revealing headings within the viewport. Returning via **Module lessons -> Course modules -> All my courses** also passed, with no mutation requests during navigation and successful test-session logout. This is not a physical Android/iPhone or Safari test; those remain outstanding.

Teacher lesson-to-record handoff: class cards use the same **My courses** label as the sidebar, carrying the selected class into the teacher's assigned course library. The lesson displays the class name from the authorized classes API, or a clear no-selection/unavailable message. One primary **Record lesson results** button opens the shared dialog: **Qur'an practice** (recitation, memorisation or revision) or **Other subject results** (Assessments). Cancel stays in the lesson. No destination is inferred from a course title. The chosen destination preserves the selected class (and learner for Quran when available); workspace Back returns to the same course/module/lesson and reloads its content through the authorized API. Failed lesson access checks hide the old content and record action. No course-to-class assignment or lesson-to-achievement mapping is inferred, and navigation saves no record. The location lasts only in the current workspace session, not across a browser restart. All 67 focused teacher/course/workspace widget tests and analysis passed, including the chooser and class context at 390px and 1440px. The new handoff's full browser save/history round trip remains unverified; earlier browser results cover course browsing, not the new chooser.

Handoff browser verification (27 October 2026): desktop Chromium and mobile Chromium emulation (390 x 844) passed Cancel, both record destinations loading their authorized APIs, and Back reloading the same lesson, with no mutation requests during navigation and successful logout. Returning to a restored lesson automatically reveals its heading without manual scrolling; the focused course/workspace widget suites passed 51 tests and analysis passed after this change. The mobile test now initiates chooser-discovery swipes in the content gutter instead of over selectable lesson text; it uses touch gestures, not forced clicks or programmatic scroll offsets. Saving results, reading their history through this journey, and physical Android/iPhone or Safari tests remain unverified. No demo course content or assignments are changed by this check.

Persistent teacher dashboard demo (local development only): from `backend`, run `node scripts/prepare-teacher-dashboard-demo.mjs --confirm-local-development`. It adds three clearly labelled demo classes assigned to the existing demo teacher, 18 synthetic learners, 15 weekday timetable slots, 18 attendance entries, 18 synthetic Quran reading observations and six support notes. It reuses the existing organization, teacher, school admin, subject and verified Quran chapter metadata. It does not create accounts, change credentials, reset data or alter curriculum assignments. No real child data is used.

The preparation is additive and transactional. Stable event IDs prevent duplicate records, including on a later day; cancelled timetable entries, voided observations and resolved support notes are not reactivated. Changed class ownership or learner scope/status causes an abort rather than overwriting the change. Attendance and learning dates remain their original dates, so today's counters naturally change with the date instead of fabricating daily activity. Timetable validity runs through the end of the following calendar year. The script is manual, not part of server startup. On 27 October 2026, a real local run created the records, a repeat created zero records, and the authenticated teacher overview returned 3 classes, 18 learners, 6 follow-ups and 18 sessions for that date. Eleven focused demo/configuration tests passed.

Repeat the course-navigation browser check from `backend`, with the local API and rebuilt release preview running:

```bash
WEB_PREVIEW_URL=http://127.0.0.1:8088/ \
PLAYWRIGHT_MODULE="$HOME/.afaq/browser-tools/node_modules/playwright-core" \
  node scripts/check-teacher-course-navigation.mjs
```

Append `--mobile` to the command for the 390 x 844 touch-enabled Chromium check. Without arguments it runs at desktop size (1440 x 1000).

This requires the existing synthetic teacher account and teacher media demo course. It reads the local teacher credentials privately, signs in using browser-cookie authentication, and logs out its own browser session afterward. Long synthetic text is substituted only in that browser's lesson responses for the demo course, never saved to the database. The check exercises course/module/lesson navigation, requires scrolling before Next/Previous, verifies the new heading is on screen, and rejects mutation requests during lesson navigation. It does not verify teaching or learner achievement. Optional `NAVIGATION_CHECK_SCREENSHOT` saves a failure screenshot locally.

To repeat the Quran save/refresh check manually, use a synthetic learner, not a real child record:

1. Sign in as the assigned teacher, open **Qur'an Tracking**, and select the class and learner.
2. Select Al-Mulk, ayahs 11-15, **Memorisation**, and **Independent**, then click **Save progress** once and wait for confirmation.
3. Refresh the browser, reselect the class and learner, and check **Learning history** for the saved passage and observation. The selected surah's memorised ayahs should include 11-15.
4. Do not save again merely to check persistence: refresh should preserve the existing session, not create another one. Keep any reusable demo records rather than resetting or reseeding the database.

For the one-time transition of an existing local development database, `npm run dev:prepare` takes a private SQL/config backup under `~/.afaq/backups`, applies pending migrations and creates only missing demo accounts using saved passwords. Existing account conflicts abort the account transaction, rather than changing passwords, roles or status. It preserves existing school data and does not reseed curriculum. It requires local development mode, mock payments and an existing `demo-madrasa` organization/branch. This command is not needed at daily startup.

Preparation refuses to proceed if an old isolated demo database survives under `~/.afaq/platform-demo/runtime/data` or `/tmp/afaq-local-demo-*`; that data must first be backed up and deliberately merged. No old database is automatically deleted. Credentials alone cannot recover an already removed temporary database.

Only explicit isolated integration tests create temporary databases. `npm run test:demo:persistence` is an opt-in legacy-runner regression test, not the daily server; its synthetic HOME/database is removed after testing. Normal development never runs that test automatically.

#### School role seed accounts

After initializing a **disposable local school database** and running `npm run seed:admin` followed by `npm run seed:e2e-roles` from `backend/`, these synthetic accounts use the default credentials below. Their password can be overridden with the matching `E2E_*_PASSWORD` environment variable.

| Role | Login email | Default password |
|---|---|---|
| School Admin | `admin@example.com` | `ChangeMe123!` |
| Accountant | `accountant@example.com` | `ChangeMe123!` |
| Teacher | `teacher@example.com` | `ChangeMe123!` |
| Parent | `parent@example.com` | `ChangeMe123!` |
| Learner | `learner@example.com` | `ChangeMe123!` |

These seed scripts can update account passwords and are for controlled test setup only, not daily startup. Existing school accounts remain usable on the shared API; do not reseed them just to switch dashboards. Automated destructive write-flow tests must use an isolated test database.

### Run and Test on Each Platform

Start the shared backend on port `4000` using `npm run dev`. All dashboard roles use this same API.

#### Web

From the repository root:

```bash
WEB_MODE=release API_BASE_URL=http://127.0.0.1:4000 node scripts/dev-web.mjs
```

Open `http://127.0.0.1:8087/#/login` for every account above. Check backend availability with `curl http://127.0.0.1:4000/api/health`. If your web process was previously compiled against port 4087, stop it and start it again with port 4000.

This optimized preview avoids the debug handshake. Restart the frontend command after source changes; use `WEB_MODE=debug` when you need incremental hot reload.

#### Android

On a USB-connected Android phone, enable Developer options and USB debugging, then:

```bash
cd frontend
flutter pub get
flutter devices
adb devices
adb -s <android-device-id> reverse tcp:4000 tcp:4000
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

On the Android emulator (not a USB phone), use `http://10.0.2.2:4000`; `10.0.2.2` routes to the development computer. To build a debug APK for a device, set `API_BASE_URL` to an API address reachable by that device (prefer HTTPS for shared/device testing):

```bash
flutter build apk --debug --dart-define=API_BASE_URL=https://YOUR-TEST-API
```

#### iOS

iOS builds and Simulator runs require macOS with Xcode and the iOS toolchain installed. From `frontend/` on that Mac:

```bash
flutter pub get
flutter doctor
flutter devices
flutter run -d <ios-simulator-or-device-id> --dart-define=API_BASE_URL=https://YOUR-TEST-API
```

For an iPhone/iPad, `127.0.0.1` means the phone itself, not your development computer. Use an HTTPS test API reachable from the device; it should point to the same development backend, not another database. To build without signing:

```bash
flutter build ios --debug --no-codesign --dart-define=API_BASE_URL=https://YOUR-TEST-API
```

See Flutter's [iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup) for Xcode, Simulator and device setup. Android setup is covered in the [Android guide](https://docs.flutter.dev/platform-integration/android/setup).

#### Basic verification

Run static analysis and Flutter tests from `frontend/`:

```bash
flutter analyze
flutter test
```

Repeat login with each role and confirm it opens the expected workspace; sign out before testing the next account. Verify the health endpoint before troubleshooting login. Daily development records stay in the shared database and are not recreated on startup.

#### Shared location forms

School admins can edit an existing branch address from **Classes > Branch
locations**. Country, region, district and ward are required for that form.
Changes are scoped to the administrator's madrasa/branch, checked against the
loaded revision, and audited. Existing free-text branch addresses are retained.

**Students > Add student > New guardian** includes an optional **Guardian
residence** section using the same suggestion fields. Partial household addresses
are allowed; leaving the section blank does not block admission. The location is
stored on the guardian, not copied onto every learner. It is displayed in student
details and withheld from accountant responses. Tenant suggestion requests use
only the geographic catalog, never another household's or madrasa's saved address.

Existing primary guardian residences can be changed from the student's action
menu using **Edit guardian residence**. Changes require a reason, are audited
without copying addresses into the log, and reject stale forms or changed primary
guardian links. A branch-scoped admin cannot edit a guardian shared with children
outside their branch; a school-wide administrator must do that. Clearing structured
fields preserves the previous free-text address.

The **Student residence** action records an explicit living arrangement: not
recorded, lives with the primary guardian, or a separate address. Guardian-linked
addresses are resolved without copying them; changing the primary guardian flags
the arrangement for confirmation. Saves require a reason and reject stale forms.
Teacher/donor address forms are not yet connected. A guardian address alone is
not confirmation of a child's home.

Learning Oversight prioritizes institution totals and madrasa coverage. Additional
filters and framework/assessment details expand on demand; Quran activities use
separate tabs. Teaching, assessment, and Quran session counts remain distinct.

#### Madrasa identifiers

New madrasa registrations in the UI receive an automatic Afaq identifier such as
`AFQ-000001` from a database auto-increment allocation. Existing identifiers are
not renamed. Numbers may have gaps after failures or rolled-back tests; they are
identifiers, not a count of schools. Leading zeros pad the numeric portion to six
digits for a consistent display; they do not encode location or status. The UI
uses only the Afaq code, without a government registration number field. Legacy API
clients may still submit non-numbered codes; numbered `AFQ-...` codes are reserved
for server allocation.

To add persistent directory demo schools with sourced Tanzanian locations:

```bash
cd backend
node scripts/seed-demo-madrasas.mjs --confirm-local-development
```

This adds five clearly labelled `(Demo)` institutions in the existing shared
development database. Locations reuse `tanzania-villages.json` and its source
references. It fills the original `demo-madrasa` location only when SQL NULL;
reruns preserve existing records, edits, accounts, frameworks and assignments.
New schools are inactive (`PENDING_ACTIVATION`) directory examples, not completed
onboarding applications. No administrators, learners, approval receipts, streets
or hamlets are fabricated by this script.

From `backend/`, run:

```bash
node scripts/check-onboarding-journey.mjs --confirm-local-development
```

This guarded check uses the existing local development database, synthetic
accounts and one rollback-only transaction. It creates no extra database,
does not reset demo records or passwords, and sends no email. The check covers
required location fields, independent application review, inactive provisioning,
one-use invitation acceptance, activation, admin login into the correct tenant,
cross-school denial and access denial after suspension. It confirms that test
records are absent after rollback.

Scope: real database operations and in-process HTTP handlers, including IT
technical review, review withdrawal and independent activation. The check rejects
wrong roles, withdrawn or stale review receipts, and activation after suspension.
Invitation issue uses the HTTP endpoint and real email message/delivery adapter
with a captured SMTP transport (no external connection). It reads the code from
the captured email and verifies expiry, rotation, invalid-code rejection and
one-use acceptance. The private code is never returned to the dashboard.
Nested transactions share the test transaction, so this is not a concurrency
test. External email delivery, rate-limit infrastructure and browser onboarding
are not tested here. The IT onboarding dialog can now send invitations when SMTP
is configured. The public `/#/school-invitation` page accepts the private code
from the email and lets the administrator set a password. Technical review and
activation API endpoints exist, but their dashboard action forms remain pending.

#### Administrator invitation email

Configure the following privately in `backend/.env` (never commit credentials):

```dotenv
EMAIL_MODE=smtp
EMAIL_FROM=noreply@your-domain.example
EMAIL_SENDER_VERIFIED=true
EMAIL_LOGIN_URL=https://your-afaq-domain.example/#/login
SMTP_HOST=smtp.your-provider.example
SMTP_PORT=587
SMTP_USER=your-smtp-user
SMTP_PASSWORD=your-smtp-password
SCHOOL_INVITATIONS_ENABLED=true
SCHOOL_INVITATION_URL=https://your-afaq-domain.example/#/school-invitation
```

Use your provider's verified sender and a reachable HTTPS frontend URL. Port 465
is also supported. Redis must be available for invitation send/accept limits.
Restart the API after configuration. Missing/invalid enabled configuration fails
closed; the default is disabled. Local development currently has no SMTP setup.

Validate configuration, then check SMTP authentication without sending email:

```bash
cd backend
npm run email:check-smtp -- --env-file .env --invitations
npm run email:check-smtp -- --env-file .env --invitations --connect
```

A successful connection does not confirm delivery to an inbox. Test that
separately with an approved administrator recipient after setup.

While waiting for SMTP credentials, leave `EMAIL_MODE=disabled`,
`EMAIL_SENDER_VERIFIED=false` and `SCHOOL_INVITATIONS_ENABLED=false`.
Once available, fill the existing fields in `.env`, set `EMAIL_MODE=smtp`,
and set `EMAIL_SENDER_VERIFIED=true` only after verifying the sender with the
provider. Run both checks above while invitations remain disabled. Then set
`SCHOOL_INVITATIONS_ENABLED=true` and restart the API. The checks never issue
invitations, change passwords, or modify demo records; they do not print secrets.

After provisioning, IT opens **Onboarding progress**, confirms the approved
administrator recipient, then selects **Send invitation email**. The email has a
page link and a separate private one-use code (24-hour expiry), never a password.
Resending rotates the code and invalidates the previous one. SMTP acceptance is
not proof of inbox delivery; an uncertain result must not be automatically retried.
The admin enters the code, name and their chosen password on the invitation page.
Acceptance creates a disabled account pending IT review and independent activation.
No external email was sent by the automated verification above.

### Flutter Frontend

Install Flutter 3.38.5 or compatible stable SDK, then:

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

For a fast browser preview without the debug connection, run from the repository root:

```bash
WEB_MODE=release node scripts/dev-web.mjs
```

Use the same `http://127.0.0.1:8087/#/login` address so browser-saved logins remain
associated with the same origin. This is an optimized **local preview**, not a
production deployment; it still uses the existing local API/database. The first
compile takes time, but opening the compiled app does not wait for the Flutter
debugger. Keep the terminal running. Source changes require restarting this
preview; it never reloads somebody's open form automatically. Do not run two
preview commands on the same port.

For automatic Dart updates while developing, use the debug mode instead:

```bash
node scripts/dev-web.mjs
```

Open `http://127.0.0.1:8087/#/login`. The initial compilation is slower;
subsequent saves under `frontend/lib` trigger debounced incremental hot reload,
not a release rebuild or browser refresh. Keep the terminal running. Requires
a Flutter SDK with web hot reload (the project's installed SDK supports it).
Do not use this debug server for production or performance benchmarks.
Set `FLUTTER_BIN` if Flutter is not on PATH, and `API_BASE_URL` to choose a backend
(all development dashboards use `http://127.0.0.1:4000`). Stop any other server
on port 8087 first. `WEB_PORT` can override the port; backend CORS must allow it.
Dependencies, assets and web-shell changes require restarting the command.
Rejected reloads leave the existing app running; no automatic full restart is
requested. The web renderer is served locally instead of depending on a CDN.
When switching from an older release preview, use a hard refresh once to fetch
the new bootstrap; it retires this app's old Flutter service worker. Subsequent
Dart edits do not require a browser refresh. Automatic updates apply only while
this development command is running, not to production deployments.

The web startup screen uses Afaq branding, actual engine-start stages and a manual
retry if startup fails or takes more than 45 seconds. It disappears on the first
Flutter frame; all startup timers stop then. Slow service-worker storage is bounded
so it cannot hold the splash indefinitely. Retry reloads only on a user click and
does not clear credentials or stored work. This startup screen is separate from
API/session restoration errors inside the application.

While the saved session is being checked, a responsive Afaq connection panel
explains the wait. After eight seconds it shows a slow-connection message, without
issuing another request. An unsuccessful check offers explicit retry/sign-out
actions; expired sessions still return to the public flow. This panel is never
shown over an already restored workspace and respects reduced-motion settings.
Verify it with `flutter test test/account_connection_page_test.dart test/session_restore_test.dart test/company_browser_restore_test.dart`
from `frontend/`.

Startup regression checks (no login credentials or demo fixtures needed):

```bash
node --test scripts/web-loading.test.mjs scripts/web-bootstrap.test.mjs scripts/dev-web.test.mjs
PLAYWRIGHT_MODULE=/absolute/path/to/playwright-core node scripts/check-web-startup.mjs
PLAYWRIGHT_MODULE=/absolute/path/to/playwright-core node scripts/check-account-connection.mjs
```

The browser check needs the preview running and Chromium installed. It verifies
desktop/mobile startup and recovery after a blocked bootstrap script, using fresh
browser contexts. Reported timings are local samples, not production benchmarks.
The account-connection check intercepts refresh responses with synthetic delayed,
unavailable and expired sessions; it does not sign in or change demo records.

Installed Android/iOS builds open a dedicated mobile welcome and account flow, with app-bar/back navigation and a role-specific bottom navigation after login. The website keeps its public homepage, including when opened in a phone browser. See the frontend guide for USB development and native session limitations.

Native local builds default to `http://127.0.0.1:4000`. For a USB-connected Android phone, keep the backend running, execute `adb reverse tcp:4000 tcp:4000`, then `flutter run` (select the phone if prompted). Repeat port reversal after reconnecting USB. For an Android emulator without port reversal, explicitly pass `--dart-define=API_BASE_URL=http://10.0.2.2:4000`; this emulator-only address does not work on a physical phone. Outside local development, supply a reachable HTTPS API URL with `--dart-define=API_BASE_URL=https://your-api.example`. Stop and rerun Flutter when changing this define. Native sessions are held only in memory, so users sign in again after a full app restart. Browser sessions can be restored through the server after a page reload.

Verification:

```bash
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example
```

See [Flutter frontend guide](frontend/README.md) for platform notes.

## Core API Areas

- `/api/auth`
- `/api/organizations`
- `/api/users`
- `/api/students`
- `/api/guardians`
- `/api/classes`
- `/api/enrollments`
- `/api/attendance`
- `/api/hifdh-progress`
- `/api/subjects`
- `/api/courses`
- `/api/teaching/courses`
- `/api/courses/:id/modules`
- `/api/courses/modules/:moduleId/lessons`
- `/api/courses/lessons/:lessonId/assets`
- `/api/learner/courses`
- `/api/learner/courses/:courseId`
- `/api/learner/lessons/:lessonId`
- `/api/learner/assets/:assetId/open`
- `/api/courses/:id/access-requests`
- `/api/invoices`
- `/api/payments`
- `/api/parent-portal`
- `/api/reports`

## Local Superadmin Oversight Browser Check

With the shared development API on `127.0.0.1:4000` and the current Flutter web preview on `127.0.0.1:8087`, run from `backend/`:

```bash
node scripts/check-superadmin-oversight.mjs --confirm-local-development
```

Requires `/usr/bin/chromium` and `playwright-core` (or set `PLAYWRIGHT_MODULE` to its installed module path). Reads the saved local superadmin credentials without printing them. Checks browser login, madrasa coverage, month filters and both refresh actions; asserts that no platform mutation requests occur. This is a desktop browser check, not physical-device certification, and does not seed or delete learning data.

## Local Teacher Period Browser Check

With the local API on `127.0.0.1:4000` and the web preview on
`http://127.0.0.1:8087/`, run from `backend`:

```bash
node scripts/check-teacher-period-flow.mjs --confirm-local-development
node scripts/check-teacher-period-flow.mjs --confirm-local-development --mobile
```

Requires Chromium (`CHROMIUM_BIN`, default `/usr/bin/chromium`) and
`playwright-core` (`PLAYWRIGHT_MODULE` can point to an existing installation).
The check creates a temporary synthetic school, teacher, two students and one
timetable slot in the validated shared local development database. It uses the
browser to select the period, skip a student, save individual observations,
revisit the skipped student, inspect the summary, and reopen history after a
reload. It removes only its own fixture; existing demo accounts, frameworks and
assignments are preserved. The optional `--mobile` run uses a 390x844 browser
viewport, touch gestures and menu-item taps; it is not a physical-device test.
No production database or migration is involved.

## Production Notes

- All business queries must remain tenant-scoped by `org_id`
- Teacher and parent access must remain branch and ownership scoped
- Payment webhooks must remain idempotent
- Finance and user-management actions must remain auditable
- GitHub Actions CI now validates backend and frontend checks from `.github/workflows/ci.yml`

## Related Docs

- [Technical Documentation](madrasa_management_system_technical_documentation_tanzania_2026.md)
- [RBAC Matrix](RBAC_MATRIX.md)
- [Backend Development Guide](backend/DEVELOPMENT.md)
- [Flutter Frontend Guide](frontend/README.md)
- [Project Status](PROJECT_STATUS.md)
- [Backend Migration Plan](backend_foundation_migration_plan.md)
