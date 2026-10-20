# Quran Foundation content integration

This first increment exposes chapters to authenticated, active school teachers:
`GET /api/teacher-workspace/quran/content/chapters`.
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

## Behaviour and verification

Client Credentials tokens are held server-side and renewed before expiry.
Concurrent chapter requests share a request; chapter metadata is cached in memory
for 60 seconds. A provider 401 triggers one token renewal and one retry only.
Other upstream errors use a generic 503 without provider bodies or secrets.
Requests have a ten-second timeout and reject redirects. URLs are fixed by
environment; clients cannot supply an upstream URL. No learner data is sent.

Run `npm test -- tests/quran-content.test.ts` from backend.
Tests use mocked HTTP and synthetic metadata labels, never generated Quran text.
Live provider verification still requires configured credentials.

## Not complete yet

This is not a complete Quran Reader. Verse retrieval, rendering, audio,
translations, resource attribution, permitted offline caching, and access for
other Afaq roles are still pending. Content availability must not be treated as
student achievement. Reading must not automatically create teacher observations.
