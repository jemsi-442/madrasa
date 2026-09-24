# Modern Islamic Foundation Flutter App

This is the only active frontend. It targets web, Android, and iOS and talks to the existing Express API.

## Run locally

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

Use `flutter devices` to find Android/iOS targets. The Android emulator defaults to `http://10.0.2.2:4000`; web and iOS Simulator default to `http://127.0.0.1:4000`. A physical device needs a reachable API URL, preferably HTTPS:

```bash
flutter run -d <device-id> --dart-define=API_BASE_URL=https://api.example.com
```

The backend must be running and seeded with a valid account. All roles use the same sign-in form. The backend decides the role; no role picker is shown. The Flutter app keeps access and refresh tokens in memory, not in web local storage. A restart signs the user out.

## Verify

```bash
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

Only public entry, sign-in and selected read-only role pages have been migrated so far. The old React workflows are not implemented in Flutter yet. Prioritize porting each workflow with API integration and tests before treating this as a production replacement. Never rely on hidden navigation as authorization; backend RBAC, tenant scope and record ownership remain the security boundary.

Platform development notes: iOS compilation requires macOS/Xcode. Android release and iOS builds should use HTTPS; do not ship cleartext production APIs. Web deployment must configure the backend CORS origin and an HTTPS API URL.
