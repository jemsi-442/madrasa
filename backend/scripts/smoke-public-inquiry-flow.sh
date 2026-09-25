#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:4000}"
LOGIN_VALUE="${SMOKE_ADMIN_LOGIN:-admin@example.com}"
PASSWORD_VALUE="${SMOKE_ADMIN_PASSWORD:-ChangeMe123!}"
STAMP="${SMOKE_STAMP:-$(date +%s)}"

json_eval() {
  local expr="$1"

  node -e '
    const fs = require("fs");
    const input = fs.readFileSync(0, "utf8");
    const data = JSON.parse(input);
    const expr = process.argv[1];
    const result = Function("data", `return (${expr});`)(data);

    if (result === undefined || result === null) {
      process.exit(2);
    }

    if (typeof result === "string") {
      process.stdout.write(result);
      process.exit(0);
    }

    process.stdout.write(JSON.stringify(result));
  ' "$expr"
}

post_json() {
  local path="$1"
  local payload="$2"
  local token="${3:-}"

  if [[ -n "$token" ]]; then
    curl -fsS -m 20 -X POST "$BASE_URL$path" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $token" \
      -d "$payload"
  else
    curl -fsS -m 20 -X POST "$BASE_URL$path" \
      -H "Content-Type: application/json" \
      -d "$payload"
  fi
}

patch_json() {
  local path="$1"
  local payload="$2"
  local token="$3"

  curl -fsS -m 20 -X PATCH "$BASE_URL$path" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d "$payload"
}

request() {
  local path="$1"
  local token="$2"

  curl -fsS -m 20 "$BASE_URL$path" -H "Authorization: Bearer $token"
}

printf '== MMS Public Inquiry Smoke ==\n'
printf 'Base URL: %s\n' "$BASE_URL"
printf 'Stamp: %s\n' "$STAMP"

inquiry_subject="Public Inquiry Smoke ${STAMP}"
inquiry_payload="$(cat <<JSON
{"inquiryType":"ADMISSIONS","fullName":"Smoke Public Parent ${STAMP}","phone":"255744${STAMP: -6}","email":"public.inquiry.${STAMP}@example.com","subject":"${inquiry_subject}","message":"Please share the next admissions steps and the documents required for onboarding.","preferredContact":"phone","sourcePage":"admissions"}
JSON
)"
inquiry_response="$(post_json "/api/public/inquiries" "$inquiry_payload")"
inquiry_id="$(printf '%s' "$inquiry_response" | json_eval 'data.data.id')"
printf 'Public inquiry submit: %s\n' "$inquiry_id"

login_payload="$(printf '{"login":"%s","password":"%s"}' "$LOGIN_VALUE" "$PASSWORD_VALUE")"
login_response="$(post_json "/api/auth/login" "$login_payload")"
access_token="$(printf '%s' "$login_response" | json_eval 'data.data.accessToken')"
printf 'Admin login: ok\n'

list_response="$(request "/api/public-inquiries?search=${STAMP}" "$access_token")"
listed_id="$(printf '%s' "$list_response" | json_eval 'data.data[0]?.id')"
listed_status="$(printf '%s' "$list_response" | json_eval 'data.data[0]?.status')"
printf 'Inquiry inbox list: %s (%s)\n' "$listed_id" "$listed_status"

status_payload='{"status":"CONTACTED"}'
status_response="$(patch_json "/api/public-inquiries/${inquiry_id}/status" "$status_payload" "$access_token")"
updated_status="$(printf '%s' "$status_response" | json_eval 'data.data.status')"
printf 'Inquiry status update: %s\n' "$updated_status"

printf 'Public inquiry smoke result: passed\n'
printf 'Created artifact: inquiry=%s subject="%s"\n' "$inquiry_id" "$inquiry_subject"
