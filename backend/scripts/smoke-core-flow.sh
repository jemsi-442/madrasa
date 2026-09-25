#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:4000}"
LOGIN_VALUE="${SMOKE_ADMIN_LOGIN:-admin@example.com}"
PASSWORD_VALUE="${SMOKE_ADMIN_PASSWORD:-ChangeMe123!}"

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
    curl -fsS -m 15 "$BASE_URL$path" -H "Authorization: Bearer $token"
  else
    curl -fsS -m 15 "$BASE_URL$path"
  fi
}

post_json() {
  local path="$1"
  local payload="$2"
  local token="${3:-}"

  if [[ -n "$token" ]]; then
    curl -fsS -m 15 -X POST "$BASE_URL$path" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $token" \
      -d "$payload"
  else
    curl -fsS -m 15 -X POST "$BASE_URL$path" \
      -H "Content-Type: application/json" \
      -d "$payload"
  fi
}

printf '== MMS Core Smoke ==\n'
printf 'Base URL: %s\n' "$BASE_URL"

health_response="$(request "/api/health")"
printf 'Health: %s\n' "$(printf '%s' "$health_response" | json_eval 'data.message ?? "ok"' 2>/dev/null || printf 'ok')"

login_payload="$(printf '{"login":"%s","password":"%s"}' "$LOGIN_VALUE" "$PASSWORD_VALUE")"
login_response="$(post_json "/api/auth/login" "$login_payload")"
access_token="$(printf '%s' "$login_response" | json_eval 'data.data.accessToken')"
refresh_token="$(printf '%s' "$login_response" | json_eval 'data.data.refreshToken')"
printf 'Login: ok\n'

dashboard_response="$(request "/api/reports/dashboard" "$access_token")"
student_total="$(printf '%s' "$dashboard_response" | json_eval 'data.data.students.total')"
printf 'Dashboard: %s students\n' "$student_total"

attendance_response="$(request "/api/reports/attendance/summary" "$access_token")"
attendance_rate="$(printf '%s' "$attendance_response" | json_eval 'data.data.totals.attendanceRate')"
printf 'Attendance summary: %s%%\n' "$attendance_rate"

finance_response="$(request "/api/reports/finance/monthly-summary?year=$(date +%Y)" "$access_token")"
net_cash_flow="$(printf '%s' "$finance_response" | json_eval 'data.data.totals.netCashFlow')"
printf 'Finance summary: net cash flow %s\n' "$net_cash_flow"

users_response="$(request "/api/users" "$access_token")"
teacher_id="$(printf '%s' "$users_response" | json_eval 'data.data.find((user) => user.role === "TEACHER")?.id' 2>/dev/null || true)"
parent_user_id="$(printf '%s' "$users_response" | json_eval 'data.data.find((user) => user.role === "PARENT")?.id' 2>/dev/null || true)"

if [[ -n "$teacher_id" ]]; then
  teacher_response="$(request "/api/reports/teacher-dashboard?teacherId=${teacher_id}" "$access_token")"
  assigned_classes="$(printf '%s' "$teacher_response" | json_eval 'data.data.summary.assignedClasses')"
  printf 'Teacher preview: %s assigned classes\n' "$assigned_classes"
else
  printf 'Teacher preview: skipped (no teacher user)\n'
fi

if [[ -n "$parent_user_id" ]]; then
  parent_profile_response="$(request "/api/parent-portal/me?parentUserId=${parent_user_id}" "$access_token")"
  parent_student_id="$(printf '%s' "$parent_profile_response" | json_eval 'data.data.students[0]?.id' 2>/dev/null || true)"
  linked_children="$(printf '%s' "$parent_profile_response" | json_eval 'data.data.students.length')"
  printf 'Parent preview: %s linked children\n' "$linked_children"

  if [[ -n "$parent_student_id" ]]; then
    parent_finance_response="$(request "/api/parent-portal/students/${parent_student_id}/finance?parentUserId=${parent_user_id}" "$access_token")"
    invoice_count="$(printf '%s' "$parent_finance_response" | json_eval 'data.data.length')"
    printf 'Parent finance: %s invoices\n' "$invoice_count"

    completed_payment_id="$(printf '%s' "$parent_finance_response" | json_eval 'data.data.flatMap((invoice) => invoice.payments).find((payment) => payment.status === "COMPLETED")?.id' 2>/dev/null || true)"
    current_class_id="$(printf '%s' "$parent_profile_response" | json_eval 'data.data.students[0]?.currentClass?.id' 2>/dev/null || true)"

    if [[ -n "$completed_payment_id" ]]; then
      receipt_response="$(request "/api/parent-portal/students/${parent_student_id}/payments/${completed_payment_id}/receipt?parentUserId=${parent_user_id}" "$access_token")"
      receipt_no="$(printf '%s' "$receipt_response" | json_eval 'data.data.receiptNo')"
      printf 'Parent receipt: %s\n' "$receipt_no"
    else
      printf 'Parent receipt: skipped (no completed payment)\n'
    fi

    if [[ -n "$current_class_id" ]]; then
      class_attendance_response="$(request "/api/attendance/class/${current_class_id}" "$access_token")"
      attendance_rows="$(printf '%s' "$class_attendance_response" | json_eval 'data.data.length')"
      printf 'Class attendance: %s rows\n' "$attendance_rows"
    else
      printf 'Class attendance: skipped (student has no class)\n'
    fi
  else
    printf 'Parent detail: skipped (no linked student)\n'
  fi
else
  printf 'Parent preview: skipped (no parent user)\n'
fi

refresh_response="$(post_json "/api/auth/refresh" "$(printf '{"refreshToken":"%s"}' "$refresh_token")")"
new_access_token="$(printf '%s' "$refresh_response" | json_eval 'data.data.accessToken')"

if [[ -n "$new_access_token" ]]; then
  printf 'Refresh: ok\n'
fi

printf 'Smoke result: passed\n'
