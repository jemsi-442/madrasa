# Quran Foundation content integration

These endpoints expose provider content to authenticated, active school teachers:

- `GET /api/teacher-workspace/quran/content/chapters`
- `GET /api/teacher-workspace/quran/content/chapters/:chapter/verses?page=1&per_page=10`

Verses use provider `text_uthmani` without rewriting it. Page size is 1-50.
Verse keys, sequence, counts and pagination are checked against the existing
verified catalog. Invalid or incomplete provider data returns 503, not invented
replacement content. Pre-live requests outside surahs 1-2 fail explicitly.
Verse responses are not persisted or cached by this implementation.
It uses existing teacher authentication and tenant/account checks. It does not
change the verified local catalog, student sessions, or login flow.

## Server configuration

Create a Backend/server app at https://dev-console.quran.foundation.
Store the following in local or deployment secret configuration, never Git,
Flutter build defines, browser storage, logs, or chat:

```dotenv
QF_ENABLED=true
QF_ENV=prelive
QF_CLIENT_ID=
QF_CLIENT_SECRET=
```

Restart the backend after configuration changes. Default is disabled. Missing
credentials return 503 without contacting the provider.
Pre-live content is limited to Al-Fatihah and Al-Baqarah per the current provider
quickstart. Production credentials and permission are required for full content;
do not change to production until access is approved. Endpoint responses identify
their environment and whether content is limited.

Official reference: https://api-docs.quran.foundation/docs/quickstart/

## Private connection check

From `backend`, validate a private dotenv file without network access:

```sh
npm run quran:check -- --env-file /absolute/path/to/private.env
```

After that succeeds, explicitly test provider access:

```sh
npm run quran:check -- --env-file /absolute/path/to/private.env --connect
```

The check reads only the selected file. It does not use the database, change
demo records, or print credentials, tokens or Quran text. The live check obtains
a token, loads chapter metadata, and validates one verse from surah 1.
Exit codes: 0 success, 1 connection/content failure, 2 invalid configuration or
arguments. A successful dry run does not prove the credentials work; even a live
sample does not verify all surahs, audio or translations.

## Disposable demo startup and reload

`npm run platform:demo -- --start` now uses `scripts/start-local-demo.mjs`.
Before launching the existing demo runner it reads only `QF_ENABLED`, `QF_ENV`,
`QF_CLIENT_ID` and `QF_CLIENT_SECRET` from `backend/.env`. Other file settings
(including database URLs and signing keys) are never imported. The runner still
creates its isolated infrastructure. Use this command only when a new disposable
demo is intended, not to refresh a running demo with existing records.

Invalid Quran settings stop startup before infrastructure is created. A missing
file retains inherited provider settings. The wrapper preserves runner arguments
and forwards termination signals so the runner can perform its normal cleanup.
Directly running the TypeScript runner bypasses this provider-settings loader.

`scripts/reload-local-demo-api.mjs` now reads only the four `QF_` settings
from `backend/.env` before stopping the existing demo API. Database, Redis,
JWT and other inherited demo settings are preserved. Invalid Quran settings
abort before stopping the API; missing `.env` retains inherited settings.
An explicit `QF_ENABLED=false` disables content access.

The existing Linux PID/ancestry and disposable-database safeguards still apply:
this helper requires an API belonging to the specified original demo supervisor.
It is not a general restart command for a detached watcher.

Verify isolation with `node --test backend/scripts/local-demo-quran-env.test.mjs`
from the repository root.
Startup preflight and settings isolation have automated tests. A full fresh-demo
launch was not run for this change to avoid replacing the running demo experience.

## Behaviour and verification

Client Credentials tokens are held server-side and renewed before expiry.
Concurrent chapter requests share a request; chapter metadata is cached in memory
for 60 seconds. Duplicate surah IDs or verse counts that disagree with the
verified local catalog are rejected without caching the response.
A provider 401 triggers one token renewal and one retry only.
Other upstream errors use a generic 503 without provider bodies or secrets.
Requests have a ten-second timeout and reject redirects. URLs are fixed by
environment; clients cannot supply an upstream URL. No learner data is sent.

Run `npm test -- tests/quran-content.test.ts` from backend.
Tests use mocked HTTP, synthetic metadata labels, and one verbatim verse example
from the provider's documentation, never generated Quran text.
Live provider verification still requires configured credentials.

Run `npm test -- tests/quran-routes.test.ts tests/quran-check.test.ts` for
HTTP permission boundaries and the private configuration command. Route tests
use real authentication/role middleware with a mocked database and content client:
anonymous requests, unavailable accounts, stale token versions and other school
roles cannot call the provider. Platform tokens do not grant teacher access.
Successful teacher responses are marked `no-store`; only chapter and pagination
parameters reach the content client. These are not live-database integration tests.

## Teacher reader

Teachers can select **Open Quran Reader** from their Quran workspace. The shared
dialog loads chapters and paginated Uthmani text through the backend, with
selectable right-to-left verses and provider attribution. Pre-live shows its
two-surah limitation. Failures show a safe error and retry, not replacement text.
Reading does not submit observations or alter the teacher's current session.

Flutter widget tests:
`flutter test --no-pub test/quran_reader_test.dart test/teacher_workspace_test.dart`.
They cover narrow/desktop layouts, access failures, retries and closing during
an in-flight request with mocked responses. Navigation tests check that switching
surahs clears old verses and failed pages can be retried or left safely.
Workspace tests open and close the reader during an unsaved teacher session,
with both available and unavailable provider responses. They verify that the
passage and observation survive, no learner context is sent to content endpoints,
and no session is submitted until the teacher explicitly saves.

Browser regression command (run from `frontend`):

```sh
CHROME_EXECUTABLE=/usr/bin/chromium flutter test --no-pub --platform chrome test/quran_reader_test.dart
```

All nine reader tests passed locally in Chromium on 2026-10-20, including
390px/1440px layouts, RTL selectable text, error recovery and navigation.
The reader suite is included in `scripts/test-platform-web.sh` for CI.
These use mocked content responses; they do not verify a signed-in reader
against the live backend or replace visual review of Arabic glyphs.

## Not complete yet

Production connectivity was verified locally on 2026-10-20: metadata for 114
surahs and sample verses from surahs 1, 3 and 114 passed the content checks.
This was a read-only API check, not verification of every verse or browser rendering.
Arabic typography on physical devices remains unverified.
The web shell opts out of automatic browser translation using `translate="no"`
and the Google `notranslate` meta tag. App-managed language selection is separate;
these hints cannot guarantee that every browser extension respects them.
This is not a complete Quran Reader. Audio,
translations, resource attribution, permitted offline caching, and access for
other Afaq roles are still pending. Content availability must not be treated as
student achievement. Reading must not automatically create teacher observations.
