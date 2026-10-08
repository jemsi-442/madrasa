#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_bin="${FLUTTER_BIN:-flutter}"
if [[ -z "${CHROME_EXECUTABLE:-}" ]]; then
  CHROME_EXECUTABLE="$(command -v chromium || command -v google-chrome || true)"
fi
if [[ -z "$CHROME_EXECUTABLE" || ! -x "$CHROME_EXECUTABLE" ]]; then
  printf 'Set CHROME_EXECUTABLE to an installed Chromium or Chrome executable.\n' >&2
  exit 1
fi
export CHROME_EXECUTABLE
printf 'Testing platform UI in a real browser with mocked API responses, not a live backend.\n'
cd "$root_dir/frontend"
"$flutter_bin" test --no-pub --platform chrome --reporter expanded \
  test/platform_onboarding_flow_test.dart \
  test/platform_progress_refresh_test.dart \
  test/platform_onboarding_progress_test.dart \
  test/platform_provisioning_panel_test.dart \
  test/platform_audit_test.dart \
  test/platform_overview_test.dart \
  test/platform_list_refresh_test.dart \
  test/platform_health_test.dart \
  test/platform_dialog_session_test.dart
