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
Space activates a focused button instead of scrolling.

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
