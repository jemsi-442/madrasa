# Modern Islamic Foundation Flutter App

This is the only active frontend. It targets web, Android, and iOS and talks to the existing Express API.

## Run locally

```bash
flutter pub get
flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

Open `http://127.0.0.1:8080` in a browser. The public home, sign-in, and registration pages are separate routes.

Use `flutter devices` to find Android/iOS targets. Native builds default to `http://127.0.0.1:4000` for local development; USB-connected Android phones need `adb reverse` as shown below. Local web builds use the browser host on port 4000. Devices outside this local setup need a reachable API URL, using HTTPS:

```bash
flutter run -d <device-id> --dart-define=API_BASE_URL=https://api.example.com
```

The public home opens without the backend. Signing in and creating an online learning account require the API to be running. All roles use the same sign-in form. The backend decides the role; no role picker is shown. Native access and refresh tokens remain in memory, so a full native restart requires sign-in. Web access tokens are also in memory, while the server-managed browser session can restore sign-in after a reload.

The registration page creates an independent online learner through `POST /api/auth/register` and signs them in. The server assigns `LEARNER`; public callers cannot select staff roles, organization, branch, or student ownership. It does not grant paid-course access.

Contact (`/#/contact`), parent access (`/#/parent-access`), and sign-in help (`/#/forgot-password`) are dedicated pages that submit office inquiries. Sign-in help is an office-assisted recovery request, not an automated password-reset flow. Parent-child linkage and staff accounts remain office-controlled.

## Preview the Built Website

From `frontend/`, build the current source for a local preview:

```bash
flutter build web --release --no-web-resources-cdn --pwa-strategy=none --dart-define=API_BASE_URL=http://127.0.0.1:4000
node tool/serve_web.mjs
```

Open `http://127.0.0.1:8080`. Keep the backend on port 4000 running.
The API must allow this exact origin in `WEB_APP_ORIGINS`. The preview serves
only `build/web`, not the repository or backend secrets. It listens on this
computer only and is not a public production deployment.

`--no-web-resources-cdn` serves the Flutter renderer locally; optional font
fallbacks may still request external fonts. `--pwa-strategy=none` avoids adding
offline caching to this development preview. Rebuild after source changes and
reload the browser. The local Node preview sends `Cache-Control: no-store` and
versions the bootstrap/app scripts using the actual build hash. It does not run
Flutter builds automatically. This does not enable offline login or data access.

If a browser still shows the old four-page accountant menu, open
`http://127.0.0.1:8080/__preview__/refresh` once. This uncached route unregisters
only this origin's root `flutter_service_worker.js`, then opens the current
build. It does not clear cookies, local storage, unrelated service workers or
database records. `--pwa-strategy=none` alone does not unregister a worker from
an older visit. Use the same host and port as the old tab: `localhost` and
`127.0.0.1` have separate browser storage. The correct menu has eight pages,
including Fee structures, Expenses, Financial reports and Finance inbox.

`/__preview__/version` shows the current local build fingerprint. These routes
belong to the local preview server, not the public app or production API.
Preview checks require Node 20+ and no npm installation:

```bash
node --test tool/serve_web.test.mjs
```

On Linux, the preview can alternatively run as a transient user service, so it
does not depend on an open terminal. Run these commands from `frontend/`:

```bash
systemd-run --user --unit=mif-web-preview --collect /usr/bin/node "$PWD/tool/serve_web.mjs"
systemctl --user status mif-web-preview.service
```

Do not start a second server on the same port. Stop the existing preview with
`systemctl --user stop mif-web-preview.service` before switching servers.
The transient service is not enabled at boot; start it again after reboot.

The API is a separate process. If this workspace is using the temporary
`mif-backend-preview.service`, inspect it with
`systemctl --user status mif-backend-preview.service` and check
`curl http://127.0.0.1:4000/api/health`. That preview binds only to `127.0.0.1`
and is not enabled at boot. Before starting `npm run dev` in `backend/`, stop
it with `systemctl --user stop mif-backend-preview.service` to free port 4000.
Stopping either preview does not delete database records.

## Keyboard Navigation

On the website, use Up/Down to scroll a little, Page Up/Page Down or
Space/Shift+Space to scroll a page, and Home/End (also Ctrl+Home/Ctrl+End)
to jump to the start/end. Tab and Shift+Tab still move between controls.
Focused inputs retain text-editing keys, dropdown arrows select options, and
Space activates a focused button instead of scrolling. Default arrow steps are
100 logical pixels, using an 80 ms fast-start animation so held keys do not
continually restart a slow ease-in. Page steps and custom increments are unchanged.

Main pages and dialogs have explicit primary scroll targets. Sidebar navigation
returns focus to the new page, while the small-screen drawer has an independent
scroll scope. Horizontal tables keep Left/Right scrolling without swallowing
vertical page keys. Native platforms retain Flutter's platform key bindings.

When adding a page, mark its main vertical scroll view `primary: true`.
Do not share that primary controller with a sidebar or nested secondary view;
use a separate controller or `primary: false` there. Dialog routes get their
own primary controller. These changes do not intercept player/iframe keyboard
events outside Flutter.

Regression checks (Chrome is required for the second command):

```bash
flutter test test/keyboard_scrolling_test.dart
flutter test --platform chrome test/keyboard_scrolling_test.dart
```

## Workspace Navigation Flow

Every role uses the same navigation pattern on web and native mobile:
a fixed current-page trail with **Back** and a **Home** icon, grouped menu
sections and **Find a page** search. Search matches page names and their task
descriptions, shows the current page, and lists only that role's destinations.
On mobile it is available from the app bar and drawer.

**Back** retraces the workspace pages visited during this session. On Android,
system Back closes an open drawer first, then returns through that same page
history; at Home with no history the normal platform exit behavior applies.
**Home** returns to the role's overview and clears the in-memory trail.
A restored non-home section with no history offers Back to the overview.

Navigation restores context passed between pages: the teacher's class/student,
the parent's child, and accountant status/invoice scope. Class changes in the
teaching and academic record pages also update that navigation context.
Other page-local searches, pagination, periods and status filters are not a
full saved-page snapshot.
The trail is bounded to 30 visits and is not persisted across reload/sign-out.
The existing per-account last-section restoration remains unchanged; this does
not add browser address-bar routes, browser Back/Forward history or deep links.

Related links below each non-home page offer up to two real next destinations,
for example Invoices -> Payments, My Classes -> My Students / Attendance,
or Academic Progress -> Reports. They navigate only; they do not submit forms,
send messages or perform financial actions. Leaving Qur'an tracking or an
unsent family message still uses the existing draft confirmation. Dialog forms
keep their own close/discard behavior. Backend authorization is unchanged.

Regression checks:

```bash
flutter test test/workspace_flow_test.dart
flutter test --platform chrome test/workspace_flow_test.dart
```

## Connected Learning Records

Teacher class cards open that class's students, attendance, Qur'an, assessments
and reports. Assessments and Reports carry the chosen class into their API
filters and show a **Working with [class]** panel linking its source records.
Administrators can move between class-scoped assessment review, reports and
attendance; teacher-only Qur'an recording is not exposed to administrators.

Class selections made inside Students, Attendance, Qur'an, Assessments or Reports
update the workspace's in-memory context for subsequent navigation. Choosing a
different class clears a previously selected learner. Qur'an class/student
changes update shared context only after the existing draft confirmation.
Back restores the class of the prior visit, not just the page name.

New assessment forms preselect the current class. Report preparation preselects
the current class and the report page's selected period, then loads that class's
authorized roster. A successful create follows the saved class, resets the list
page and removes a status filter that could hide the newly prepared draft.
Opening links or forms never creates, submits or publishes records by itself.

An incoming class absent from the authorized academic options shows an explicit
unavailable state before any filtered list request. It does not silently change
to all classes. The user can explicitly choose **Show available classes**.
Teacher creation is disabled when the required class/subject or reporting period
setup is absent; the screen explains what the school office needs to configure.
The administrator's reporting-period setup remains available.

Reports still use the existing server workflow: recorded attendance and Qur'an
sessions plus published assessments within the reporting period. Teachers prepare,
refresh sources and submit drafts; administrators review and publish. Published
snapshots are not automatically overwritten. Parents/learners retain their
existing published-only, ownership-scoped views. No new APIs, database tables,
automatic messages or permission changes are introduced here.

```bash
flutter test test/learning_workflow_test.dart test/assessments_test.dart test/student_reports_test.dart
```

## Lesson Media Experience

### Learning Library And Course Contents

The learner Home links into the same course library and curriculum used by
**My courses**. Subject filters, illustrated subject covers, search and grid/list
views use the published course API; covers are generated UI artwork, not uploaded
course photos. No points, study-time totals or quiz results are fabricated.

**Start learning / Resume lesson** uses the API's `resumeLesson` hint and checks
the current curriculum before opening it. If access changed, the curriculum
stays visible with an explanation. The lesson endpoint checks access again.
This is the next available unfinished lesson, not a saved video playback position.

In the reader, **Course contents** sits beside the lesson on wide screens and
opens as an inline collapsible panel on phones. Modules group the topics; current,
completed and locked lessons have distinct states. Choosing a topic releases the
old media and reloads authorized content without pushing another reader route.
Completion indicators update only after a successful explicit save. Lesson notes
include text-size controls (14-24px), in addition to system accessibility scaling.
Existing admin, finance, teacher and parent navigation is unchanged.

```bash
flutter test test/learning_library_design_test.dart test/lesson_journey_test.dart
```

### Player Inside Each Lesson

Go to **My courses > View lessons > Open lesson / Continue learning**. The
lesson player is visible above the notes, even before any media has loaded.
**Load lesson video/audio** opens the first available recording in that same
player; other resources can still be selected from **Lesson resources**.
The recording does not autoplay. Locked or unconnected resources are never
selected by this shortcut, and real delivery still requires API authorization.

When no playable recording is available, **Load sample video** and
**Load sample audio** let you try the controls inside the lesson itself, without
visiting Explore or a separate preview page. Samples are explicitly labelled as
practice, not lesson content. They neither call school-media endpoints nor save
progress, and never replace a failed real recording automatically. Returning to
notes, changing resources/lessons or leaving the reader releases playback.

```bash
flutter test test/lesson_player_entry_test.dart test/lesson_media_flow_test.dart
```

### Try The Player Without A Course

Every signed-in role can open **Account menu > Try media player** on desktop
or mobile. **My courses** also has a preview button that stays available when
the catalogue is empty or cannot load. The preview opens a normal in-app page
and returns to your previous work, without signing you out.

Five built-in samples let users explore the actual player: a 40-second silent
video, 40 seconds of quiet synthetic audio, an illustration, a two-page PDF
and a text checklist. The samples are clearly labelled, do not autoplay, and
use the same playback, seeking, speed, zoom, resource and Focus view controls
as lessons. No course, upload, payment or learning-progress record is needed
or created. Sources are packaged Flutter assets, not external demo links.
The signed-school-resource URL/expiry checks are unchanged for real lessons.

The local preview server serves media MIME types and single byte ranges so
video/audio seeking works. Keep equivalent range support on production static
asset hosting. See `assets/README.md` for sample provenance and regeneration.

```bash
flutter test test/media_player_preview_test.dart test/lesson_media_native_test.dart
node --test tool/serve_web.test.mjs
```

### Learning With Real Resources

Courses and lessons open as ordinary full-page routes inside the app, with
**Back to courses** and **Back to course** actions. Media does not open another
dialog or route: the selected resource is embedded in the lesson beside the
resource list on wide screens, and above the list on small screens. Lesson
notes and explicit completion remain on the same page.

The reader shows its position in the published curriculum and the current
module. **Previous lesson** and **Next lesson** move within the same reader
route, including across modules; Back returns directly to the curriculum and
refreshes its progress. Adjacent locked lessons stay disabled instead of being
silently skipped. Available previews can still be opened from the curriculum.
Each lesson change loads fresh server-authorized content and progress, disposes
the previous media, clears local errors and returns scroll/focus to the top.
An authorization failure shows a retry for the requested lesson, not old content.

Moving between lessons neither completes them nor advances automatically after
a save. **Mark complete** applies only to the active lesson; lesson navigation
and leaving the reader are blocked while that save is pending. At the end of
published lessons, **Return to curriculum** offers a review of remaining work
without claiming that the entire course is complete.

Video and audio share a VLC-inspired dark stage and orange transport bar on
web and supported native platforms. Images retain pan/reset zoom;
PDFs retain page and zoom controls; text attachments remain plain, selectable
text. Audio has a dedicated listening area. Shared transport controls use a
high-contrast strip with a separate time label for narrow screens and larger
text. Opening media does not autoplay or automatically mark a lesson complete.

Direct video and audio include **Back 10 seconds**, **Forward 10 seconds**, and
a **Playback speed** menu (0.5x to 2x) on web and supported native platforms.
Seeking stays within the recording; changing speed does not start playback.
Quick seeking is disabled until a finite duration is available. **Stop** pauses
and rewinds, **Mute** restores the previous volume when unmuted, and **Repeat**
loops only the current recording. Wide players also offer a volume slider.
The custom controls replace the browser's default video/audio toolbar.
Click the playback stage to focus its shortcuts: Space toggles playback,
Left/Right seek 10 seconds and M toggles mute. Focused buttons and sliders keep
their own keyboard behavior. Media failures show an in-stage explanation and
disable transport instead of leaving a browser error panel and loading message.
Focus view and resizing
retain the selected speed; opening another resource starts at normal speed.
Embedded provider videos retain their own controls instead of showing tools
that cannot control the provider's player. PDFs, images and text are unchanged.

**Previous resource** and **Next resource** follow the lesson's available
resource order, skipping locked or unconnected items. The counter describes
available resources, not completion. Boundaries are disabled; there is no
automatic advance or autoplay, and each selected resource is authorized again.

**Focus view** expands the inline viewing area and temporarily hides notes and
the resource list. It is not another route, dialog or browser fullscreen window.
The active surface and its playback/zoom state are retained. The exit button,
page Back, or native Back restores the lesson first; Escape also exits when
Flutter controls have keyboard focus. Embedded players may handle their own
keyboard shortcuts. Previous/Next resource remains available in Focus view;
course navigation is restored when leaving Focus view.

Selecting another resource disposes the previous surface. **Back to lesson
text** stops/removes it, exits Focus view, and scrolls/focuses the reading notes.
Outside Focus view, page Back disposes media and returns to the curriculum.
Resizing between desktop and mobile preserves the selected player's state
instead of fetching another authorization link. Completion still blocks
duplicate saves, resource navigation and focus toggling while saving.

Every resource opening/reload uses the existing authorized delivery endpoint.
Locked and unconnected resources remain unavailable. Errors and expired links
offer an inline retry, not an external-browser fallback. Late authorization
responses and callbacks from replaced players cannot overwrite the active
resource. No media upload/provider/backend permissions are changed here.

```bash
flutter test test/learner_courses_test.dart test/lesson_journey_test.dart test/lesson_media_test.dart test/lesson_media_flow_test.dart test/lesson_media_native_test.dart test/lesson_playback_tools_test.dart
flutter test --platform chrome test/lesson_journey_test.dart test/lesson_playback_tools_test.dart test/lesson_media_flow_test.dart
```

## Native Mobile Experience

Installed Android/iOS builds start at a dedicated welcome screen with Login,
learner registration and parent-access help, not the public website homepage.
Account and help forms use an app bar, back navigation, safe areas and
keyboard-aware scrolling. Privacy and terms remain inside the app.

After sign-in, role-specific pages use a mobile app bar, bottom navigation and
a drawer for other sections, without website header/footer content. The website
keeps its public home and responsive desktop layout, even in a phone browser.
Platform selection changes presentation only; API endpoints and backend
permissions remain the source of truth. Native token persistence is not added.

For USB-connected Android development with the API running on the computer:

```bash
adb reverse tcp:4000 tcp:4000
flutter run
```

Choose the Android phone if Flutter asks for a device. Keep the backend running
on the computer and repeat `adb reverse` after reconnecting USB or restarting
ADB. `adb reverse --list` should include `tcp:4000 tcp:4000`. With multiple
devices, use `adb -s` and `flutter run -d` with the same actual device ID from
`flutter devices`.

For an Android emulator without port reversal, explicitly select its host alias:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
```

Do not use `10.0.2.2` on a physical phone. An explicit `API_BASE_URL` always
overrides the native default. Stop and rerun Flutter when changing
`--dart-define`; hot reload/restart does not change the launch arguments.

If sign-in says "We could not reach the school", check the backend with
`curl http://127.0.0.1:4000/api/health`, the USB reverse mapping and the build's
API URL before resetting a password. A computer-only health check does not prove
that the installed app uses the correct server.

### Prepare Android While the Phone Is Disconnected

The build does not need a connected phone. For the Infinix arm64 device, run
from `frontend/`:

```bash
flutter build apk --debug --target-platform android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

The development APK is `build/app/outputs/flutter-apk/app-debug.apk`.
It is a native Flutter Android app, not a browser shortcut. This debug-signed,
local-API build is for development, not Play Store distribution.

After reconnecting and authorizing USB debugging, with only the intended phone
connected, run from `frontend/`:

```bash
adb devices -l
adb reverse tcp:4000 tcp:4000
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n org.modernislamicfoundation.mif_app/.MainActivity
```

`install -r` updates the existing app without uninstalling it. If Android reports
a signature mismatch, do not uninstall or clear app data to work around it;
check the signing key first. With multiple devices, add `-s` and the intended
device's actual ID to every adb command. API access through this USB mapping
stops when the phone is disconnected. Reapply the mapping after reconnecting.

## Entry Page Design

Home and account pages share the foundation's navy, warm ivory and gold palette,
bundled Noto Serif Display headings, geometric decoration and an arch-shaped
learning illustration. The illustration is not a photograph of an enrolled
student (see `assets/README.md`). Native entry remains distinct from the website:
no website navigation/footer, safe-area scrolling and app-bar back navigation.

The entrance reveal respects reduced-motion settings. Layout tests cover narrow
screens, rotation, zero-size startup, enlarged text, keyboard insets and the
existing sign-in/registration flows. Authentication and API selection are unchanged.

To capture local entry previews with the bundled fonts and image:

```bash
flutter test test/public_entry_design_test.dart --update-goldens --dart-define=ENTRY_PREVIEWS=true
```

This opt-in writes home/login previews to `/tmp/mif-{mobile,desktop}-{home,login}-v2.png`.
Normal test runs do not write screenshots.

## Public footer

On the website, the home footer groups support and information links above a separate, divided copyright strip. Login and registration retain the minimal copyright footer.

Terms (`/#/terms`) and privacy (`/#/privacy`) have dedicated public pages. No approved institutional legal text was supplied, so both clearly show publication-pending notices instead of invented policies. Approved terms and privacy copy are required before public release.

The Instagram icon is intentionally disabled until the foundation supplies its official URL. Both contact numbers (+255715735335 and +255683186987) remain visible and selectable beside their own WhatsApp icons; each icon opens the matching `https://wa.me/` link. No message is sent automatically.

## Dashboard Design Stage

The signed-in workspace uses a fixed navy sidebar, gold selection, collapsible desktop navigation, page search, and mobile drawer/bottom navigation. Sidebar links remain role-specific.

The admin reference implementation now includes a six-card overview with actual
admissions, assessment coverage, recent activity, donations and upcoming events.
Teachers and Subjects have independent searchable directories and create forms.
Students support admissions with new or existing guardians, and Classes support
creation with branch/teacher assignment. Admin Attendance now has a daily class
register, status cards, a seven-day line chart, student search/filter/pagination,
check-in times and a versioned editor with selected-student bulk actions.
Saved corrections require an explanation; conflicts require an explicit reload
and dirty dialogs ask before discarding work. History lists the latest 50 saves.
Unmarked students and days without records are not treated as absence.
Check-in uses Tanzania school time. Historical saved rows stay with their original
class; unrecorded former members are not reconstructed from enrollment history.

Donations is backed by its own database module: add donors and campaigns, record
pledges, receive donations (including partial pledge collections), view receipts
and void mistaken entries with a reason. Collections exclude voided receipts and
unpaid pledges. Lists paginate; charts use full-tenant aggregates. This release
records received money, not a provider checkout, downloadable receipt PDF or
automatic donor messages.

Overview events can be added and cancelled. All these new workflows are admin-only.
The gold action-button theme is scoped to ADMIN; other role layouts are preserved.
Forms keep donation submission keys on retry. Concurrent reads/writes share one
token refresh, and an old form cannot retry under a newly signed-in account.

Remaining reference work includes full class curriculum, passage-level Qur'an
tracking, teacher leave/attendance, reports/downloads,
communications delivery, notifications/global record search and offline sync.
Those controls are not shown as working features. See
[the admin domain contract](../ADMIN_PANEL_ARCHITECTURE.md) for their data design.

## Accountant Workspace

The accountant has eight destinations. Desktop shows all eight in the sidebar;
mobile keeps Home, Invoices and Payments in the bottom bar and opens the other
five through **More**. Home also has shortcuts to the new finance tools.

Desktop navigation groups the eight pages into Overview, Collections and Finance
tools. Registers share responsive headings, primary actions and visible active
filter summaries. Empty lists show an explicit empty state rather than sample
records. Financial reports include a selectable monthly collection/expense chart
using the API's reported amounts, with exact decimal labels, a shared scale,
keyboard/screen-reader support and horizontal scrolling on small screens.
Missing amounts remain unavailable instead of being plotted as zero.

- **Home:** reported invoice, collection, expense and cash-flow totals, plus
  shortcuts to overdue invoices, pending payments and new course requests.
- **Invoices:** debounced server search, status filters, pagination, balances and
  a detail view with the learner, fee and due date.
- **Payments:** server search, status/channel filters and invoice-scoped records.
  Opening a payment fetches its latest saved details; completed payments can open
  an in-app receipt.
- **Course access:** status-filtered requests with local learner/course search,
  office notes and the latest linked invoice, including independent learners.
- **Fee structures:** searchable, paginated rate register with active/inactive
  filters, details and a create form for amount, billing cycle and active status.
- **Expenses:** searchable, paginated register, date-range filters, details and a
  create form for amount, expense date and optional description.
- **Financial reports:** year selector, reported totals, monthly breakdown,
  authenticated CSV preview/copy and supported-platform CSV saving.
- **Finance inbox:** finance-only inquiries with search, status filters, contact
  details and NEW / CONTACTED / CLOSED status updates.

The invoice flow is Home -> filtered register -> invoice details -> linked
payments -> payment details -> receipt. Course requests can also lead to linked
payments. Details use a scrollable mobile bottom sheet or a desktop dialog.
Close/back returns to the underlying list with its filters intact. Selecting a
different navigation destination clears the previous invoice scope; Refresh
retains the current page filters.

Fee/expense creation validates positive TZS amounts with up to two decimals and
blocks duplicate taps. The account's backend branch scope is used automatically;
an unassigned accountant creates school-wide entries, with no branch/class
override in these forms. Unsaved changes require confirmation before discarding.
A timeout, network failure or ambiguous save result requires checking the
register before another entry is created. This prevents an immediate blind retry,
but is not backend idempotency.

A fee structure does not create invoices automatically. An expense is a record,
not a bank transfer. Inquiry status updates do not send messages or prove that
contact occurred. Invoices, payments and course requests remain read-only.
These pages do not initiate charges, reconcile providers, edit/delete financial
history, grant access or generate PDFs. Backend permissions and tenant/branch
scope remain the security boundary. Failed requests show a retry/error state,
not fabricated balances or success notifications.

Individual expense/payment records display their API currency and exact decimal
amounts. Fee templates use the backend's TZS billing convention. The summary
endpoint supplies no currency, so aggregate totals are reported amounts, not
assumed TZS or converted values. Do not use that aggregate to compare
mixed-currency accounts. Invoiced less collected is a period difference, not a
current debtor balance. Monthly groups use UTC invoice issue dates, payment
paid dates and expense dates.

CSV export uses authenticated requests, including session refresh, and rejects
non-CSV success responses. **View CSV** stays inside the app with explicit
copy-to-clipboard. **Save CSV** opens Android's destination picker or requests
a browser download on web. Cancelling Android's picker does not report success.
Other native platforms currently support preview/copy only. Exports contain
financial information; choose an appropriate destination and recipient.

Run the accountant tests, or opt in to fixture-only visual previews:

```bash
flutter test test/accountant_page_test.dart test/finance_operations_test.dart test/finance_api_test.dart test/finance_web_layout_test.dart
flutter test test/accountant_page_test.dart --update-goldens --dart-define=ACCOUNTANT_PREVIEWS=true
flutter test test/finance_operations_test.dart --update-goldens --dart-define=FINANCE_OPERATIONS_PREVIEWS=true
```

Preview files are written to
`/tmp/accountant-{mobile,desktop}-{home,invoices,payments,course-access}.png` and
`/tmp/finance-{mobile,desktop}-{fee-structures,expenses,financial-reports,finance-inbox}.png`.
They use mock records and do not contact or alter the live finance database.
Platform-specific Save CSV visibility follows the test host; an Android-shaped
widget preview on Linux is not a device test of the Android file picker.

## Verify

```bash
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

Public pages, selected role read views and the admin workflows listed above have been migrated. The old React workflows are not implemented in Flutter yet. Prioritize porting each workflow with API integration and tests before treating this as a production replacement. Never rely on hidden navigation as authorization; backend RBAC, tenant scope and record ownership remain the security boundary.

Platform development notes: iOS compilation requires macOS/Xcode. Android release and iOS builds should use HTTPS; do not ship cleartext production APIs. Web deployment must configure the backend CORS origin and an HTTPS API URL.
