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

The accountant has four destinations on both mobile and desktop:

- **Home:** reported invoice, collection, expense and cash-flow totals, plus
  shortcuts to overdue invoices, pending payments and new course requests.
- **Invoices:** debounced server search, status filters, pagination, balances and
  a detail view with the learner, fee and due date.
- **Payments:** server search, status/channel filters and invoice-scoped records.
  Opening a payment fetches its latest saved details; completed payments can open
  an in-app receipt.
- **Course access:** status-filtered requests with local learner/course search,
  office notes and the latest linked invoice, including independent learners.

The primary flow is Home -> filtered register -> invoice details -> linked
payments -> payment details -> receipt. Course requests can also lead to linked
payments. Details use a scrollable mobile bottom sheet or a desktop dialog.
Close/back returns to the underlying list with its filters intact. Selecting a
different bottom tab/sidebar destination opens that section without the previous
invoice scope; Refresh retains the current page filters.

These pages are read-only. They do not initiate charges, reconcile providers,
edit invoices, grant access, delete financial history or generate PDF exports.
Backend permissions and tenant/branch scope still apply. Failed requests have a
retry state, not success notifications or fabricated balances.

Individual records display their API currency and exact decimal amounts. The
existing summary endpoint supplies no currency, so its totals are explicitly
labelled as reported amounts rather than being assumed to be TZS or converted.
Do not use that aggregate to compare mixed-currency accounts. Invoice details
reflect the loaded list; payment details and receipts are separately fetched.

Run the accountant tests, or opt in to fixture-only visual previews:

```bash
flutter test test/accountant_page_test.dart
flutter test test/accountant_page_test.dart --update-goldens --dart-define=ACCOUNTANT_PREVIEWS=true
```

The preview command writes four pages per layout to
`/tmp/accountant-{mobile,desktop}-{home,invoices,payments,course-access}.png`.
It uses mock records and does not contact or alter the live finance database.

## Verify

```bash
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

Public pages, selected role read views and the admin workflows listed above have been migrated. The old React workflows are not implemented in Flutter yet. Prioritize porting each workflow with API integration and tests before treating this as a production replacement. Never rely on hidden navigation as authorization; backend RBAC, tenant scope and record ownership remain the security boundary.

Platform development notes: iOS compilation requires macOS/Xcode. Android release and iOS builds should use HTTPS; do not ship cleartext production APIs. Web deployment must configure the backend CORS origin and an HTTPS API URL.
