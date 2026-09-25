# Modern Islamic Foundation Flutter App

This is the only active frontend. It targets web, Android, and iOS and talks to the existing Express API.

## Run locally

```bash
flutter pub get
flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

Open `http://127.0.0.1:8080` in a browser. The public home, sign-in, and registration pages are separate routes.

Use `flutter devices` to find Android/iOS targets. The Android emulator defaults to `http://10.0.2.2:4000`; web and iOS Simulator default to `http://127.0.0.1:4000`. A physical device needs a reachable API URL, preferably HTTPS:

```bash
flutter run -d <device-id> --dart-define=API_BASE_URL=https://api.example.com
```

The public home opens without the backend. Signing in and creating an online learning account require the API to be running. All roles use the same sign-in form. The backend decides the role; no role picker is shown. The Flutter app keeps access and refresh tokens in memory, not in web local storage. A restart signs the user out.

The registration page creates an independent online learner through `POST /api/auth/register` and signs them in. The server assigns `LEARNER`; public callers cannot select staff roles, organization, branch, or student ownership. It does not grant paid-course access.

Contact (`/#/contact`), parent access (`/#/parent-access`), and sign-in help (`/#/forgot-password`) are dedicated pages that submit office inquiries. Sign-in help is an office-assisted recovery request, not an automated password-reset flow. Parent-child linkage and staff accounts remain office-controlled.

## Public footer

The home footer groups support and information links above a separate, divided copyright strip. Login and registration retain the minimal copyright footer.

Terms (`/#/terms`) and privacy (`/#/privacy`) have dedicated public pages. No approved institutional legal text was supplied, so both clearly show publication-pending notices instead of invented policies. Approved terms and privacy copy are required before public release.

The Instagram icon is intentionally disabled until the foundation supplies its official URL. Both contact numbers (+255715735335 and +255683186987) remain visible and selectable beside their own WhatsApp icons; each icon opens the matching `https://wa.me/` link. No message is sent automatically.

## Dashboard Design Stage

The signed-in workspace uses a fixed navy sidebar, gold selection, collapsible desktop navigation, page search, and mobile drawer/bottom navigation. Sidebar links remain role-specific.

The admin reference implementation now includes a six-card overview with actual
admissions, assessment coverage, recent activity, donations and upcoming events.
Teachers and Subjects have independent searchable directories and create forms.
Students support admissions with new or existing guardians, and Classes support
creation with branch/teacher assignment. Attendance is still a read-only summary.

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
tracking, admin attendance entry, teacher leave/attendance, reports/downloads,
communications delivery, notifications/global record search and offline sync.
Those controls are not shown as working features. See
[the admin domain contract](../ADMIN_PANEL_ARCHITECTURE.md) for their data design.

## Verify

```bash
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

Public pages, selected role read views and the admin workflows listed above have been migrated. The old React workflows are not implemented in Flutter yet. Prioritize porting each workflow with API integration and tests before treating this as a production replacement. Never rely on hidden navigation as authorization; backend RBAC, tenant scope and record ownership remain the security boundary.

Platform development notes: iOS compilation requires macOS/Xcode. Android release and iOS builds should use HTTPS; do not ship cleartext production APIs. Web deployment must configure the backend CORS origin and an HTTPS API URL.
