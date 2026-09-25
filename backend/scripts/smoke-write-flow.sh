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

request() {
  local path="$1"
  local token="${2:-}"

  if [[ -n "$token" ]]; then
    curl -fsS -m 20 "$BASE_URL$path" -H "Authorization: Bearer $token"
  else
    curl -fsS -m 20 "$BASE_URL$path"
  fi
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

printf '== MMS Write Smoke ==\n'
printf 'Base URL: %s\n' "$BASE_URL"
printf 'Stamp: %s\n' "$STAMP"

login_payload="$(printf '{"login":"%s","password":"%s"}' "$LOGIN_VALUE" "$PASSWORD_VALUE")"
login_response="$(post_json "/api/auth/login" "$login_payload")"
access_token="$(printf '%s' "$login_response" | json_eval 'data.data.accessToken')"
printf 'Login: ok\n'

org_response="$(request "/api/organizations/me" "$access_token")"
branch_id="$(printf '%s' "$org_response" | json_eval 'data.data.branches[0]?.id')"
branch_name="$(printf '%s' "$org_response" | json_eval 'data.data.branches[0]?.name')"
printf 'Organization branch: %s (%s)\n' "$branch_name" "$branch_id"

classes_response="$(request "/api/classes" "$access_token")"
class_id="$(printf '%s' "$classes_response" | json_eval 'data.data[0]?.id' 2>/dev/null || true)"
class_name="$(printf '%s' "$classes_response" | json_eval 'data.data[0]?.name' 2>/dev/null || true)"
if [[ -n "${class_id:-}" ]]; then
  printf 'Class scope: %s (%s)\n' "$class_name" "$class_id"
else
  printf 'Class scope: none available, continuing without class assignment\n'
fi

guardian_phone="25574${STAMP: -6}"
guardian_email="smoke.guardian.${STAMP}@example.com"
guardian_payload="$(cat <<JSON
{"fullName":"Smoke Guardian ${STAMP}","phone":"${guardian_phone}","email":"${guardian_email}","relationship":"Mother","address":"QA Flow ${STAMP}"}
JSON
)"
guardian_response="$(post_json "/api/guardians" "$guardian_payload" "$access_token")"
guardian_id="$(printf '%s' "$guardian_response" | json_eval 'data.data.id')"
printf 'Guardian create: %s\n' "$guardian_id"

student_payload="$(cat <<JSON
{"admissionNo":"SMK-${STAMP}","fullName":"Smoke Student ${STAMP}","gender":"male","branchId":"${branch_id}","$( [[ -n "${class_id:-}" ]] && printf 'classId":"%s","' "$class_id")joinedOn":"$(date +%F)","notes":"Write smoke flow ${STAMP}","primaryGuardianId":"${guardian_id}"}
JSON
)"
student_response="$(post_json "/api/students" "$student_payload" "$access_token")"
student_id="$(printf '%s' "$student_response" | json_eval 'data.data.id')"
printf 'Student create: %s\n' "$student_id"

student_update_payload="$(cat <<JSON
{"notes":"Write smoke flow ${STAMP} updated","status":"ACTIVE"}
JSON
)"
student_update_response="$(patch_json "/api/students/${student_id}" "$student_update_payload" "$access_token")"
updated_notes="$(printf '%s' "$student_update_response" | json_eval 'data.data.notes')"
printf 'Student update: %s\n' "$updated_notes"

fee_structure_payload="$(cat <<JSON
{"name":"Smoke Fee ${STAMP}","amount":"12345.00","billingCycle":"ONE_TIME","branchId":"${branch_id}","isActive":true}
JSON
)"
fee_structure_response="$(post_json "/api/fee-structures" "$fee_structure_payload" "$access_token")"
fee_structure_id="$(printf '%s' "$fee_structure_response" | json_eval 'data.data.id')"
printf 'Fee structure create: %s\n' "$fee_structure_id"

invoice_payload="$(cat <<JSON
{"studentId":"${student_id}","feeStructureId":"${fee_structure_id}","dueDate":"$(date --date='+14 day' +%F)"}
JSON
)"
invoice_response="$(post_json "/api/invoices" "$invoice_payload" "$access_token")"
invoice_id="$(printf '%s' "$invoice_response" | json_eval 'data.data.id')"
invoice_no="$(printf '%s' "$invoice_response" | json_eval 'data.data.invoiceNo')"
printf 'Invoice create: %s (%s)\n' "$invoice_no" "$invoice_id"

payment_payload="$(cat <<JSON
{"invoiceId":"${invoice_id}","payerPhone":"${guardian_phone}","channel":"mpesa","customer":{"firstname":"Smoke","lastname":"Guardian","email":"${guardian_email}"}}
JSON
)"
payment_response="$(post_json "/api/payments" "$payment_payload" "$access_token")"
payment_id="$(printf '%s' "$payment_response" | json_eval 'data.data.id')"
payment_status="$(printf '%s' "$payment_response" | json_eval 'data.data.status')"
printf 'Payment request: %s (%s)\n' "$payment_id" "$payment_status"

expense_payload="$(cat <<JSON
{"title":"Smoke Expense ${STAMP}","description":"QA expense smoke ${STAMP}","amount":"4500.00","expenseDate":"$(date +%F)","branchId":"${branch_id}"}
JSON
)"
expense_response="$(post_json "/api/expenses" "$expense_payload" "$access_token")"
expense_id="$(printf '%s' "$expense_response" | json_eval 'data.data.id')"
printf 'Expense create: %s\n' "$expense_id"

publish_at="$(date --iso-8601=seconds)"
expires_at="$(date --date='+1 day' --iso-8601=seconds)"
announcement_payload="$(cat <<JSON
{"title":"Smoke Announcement ${STAMP}","message":"QA announcement flow ${STAMP} for write smoke verification.","audience":"PARENTS","publishAt":"${publish_at}","expiresAt":"${expires_at}","branchId":"${branch_id}"}
JSON
)"
announcement_response="$(post_json "/api/announcements" "$announcement_payload" "$access_token")"
announcement_id="$(printf '%s' "$announcement_response" | json_eval 'data.data.id')"
printf 'Announcement create: %s\n' "$announcement_id"

printf 'Write smoke result: passed\n'
printf 'Created artifacts: guardian=%s student=%s feeStructure=%s invoice=%s payment=%s expense=%s announcement=%s\n' \
  "$guardian_id" "$student_id" "$fee_structure_id" "$invoice_id" "$payment_id" "$expense_id" "$announcement_id"
