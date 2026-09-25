#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_SMOKE="${RUN_SMOKE:-0}"
BASE_URL="${BASE_URL:-http://127.0.0.1:4000}"
WEB_API_BASE_URL="${WEB_API_BASE_URL:-https://example.invalid}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

step() {
  printf '\n== %s ==\n' "$1"
}

step "Backend Typecheck"
(
  cd "$ROOT_DIR/backend"
  npm run typecheck
)

step "Backend Build"
(
  cd "$ROOT_DIR/backend"
  npm run build
)

step "Backend Tests"
(
  cd "$ROOT_DIR/backend"
  npm test
)

if [[ "$RUN_SMOKE" == "1" ]]; then
  step "Backend Smoke Core"
  (
    cd "$ROOT_DIR/backend"
    BASE_URL="$BASE_URL" npm run smoke:core
  )

  step "Backend Smoke Write"
  (
    cd "$ROOT_DIR/backend"
    BASE_URL="$BASE_URL" npm run smoke:write
  )

  step "Backend Smoke Public Inquiry"
  (
    cd "$ROOT_DIR/backend"
    BASE_URL="$BASE_URL" npm run smoke:public-inquiry
  )
fi

step "Flutter Dependencies"
(
  cd "$ROOT_DIR/frontend"
  "$FLUTTER_BIN" pub get
)

step "Flutter Analyze"
(
  cd "$ROOT_DIR/frontend"
  "$FLUTTER_BIN" analyze
)

step "Flutter Tests"
(
  cd "$ROOT_DIR/frontend"
  "$FLUTTER_BIN" test
)

step "Flutter Web Build"
(
  cd "$ROOT_DIR/frontend"
  "$FLUTTER_BIN" build web --release --dart-define="API_BASE_URL=$WEB_API_BASE_URL"
)

printf '\nRelease gate passed.\n'
