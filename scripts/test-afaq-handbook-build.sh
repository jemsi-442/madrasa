#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_script="$root_dir/scripts/build-afaq-handbook.sh"
source_file="$root_dir/docs/afaq-system-handbook.html"
temporary_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

broken_source="$temporary_dir/broken.html"
duplicate_source="$temporary_dir/duplicate.html"
protected_output="$temporary_dir/protected.pdf"
valid_output="$temporary_dir/valid.pdf"
failure_log="$temporary_dir/expected-failure.log"

sed 's/href="#contents"/href="#missing-section"/' "$source_file" > "$broken_source"
cp "$root_dir/docs/Afaq_System_User_Handbook.pdf" "$protected_output"
protected_hash="$(sha256sum "$protected_output" | cut -d ' ' -f 1)"

if HANDBOOK_SOURCE="$broken_source" HANDBOOK_OUTPUT="$protected_output" \
  bash "$build_script" > "$failure_log" 2>&1; then
  printf 'Broken-anchor build unexpectedly succeeded.\n' >&2
  exit 1
fi

grep -q 'points to a missing section' "$failure_log"

sed 's/<body>/<body><span id="contents"><\/span>/' "$source_file" > "$duplicate_source"
if HANDBOOK_SOURCE="$duplicate_source" HANDBOOK_OUTPUT="$protected_output" \
  bash "$build_script" > "$failure_log" 2>&1; then
  printf 'Duplicate-anchor build unexpectedly succeeded.\n' >&2
  exit 1
fi

grep -q 'duplicate section id: contents' "$failure_log"

if [[ "$(sha256sum "$protected_output" | cut -d ' ' -f 1)" != "$protected_hash" ]]; then
  printf 'Failed build changed the existing output.\n' >&2
  exit 1
fi

HANDBOOK_OUTPUT="$valid_output" bash "$build_script"
metadata="$(pdfinfo "$valid_output")"
grep -q '^Tagged:[[:space:]]*yes$' <<<"$metadata"
grep -q 'Page size:.*A4' <<<"$metadata"
grep -q '^Author:[[:space:]]*Afaq Foundation$' <<<"$metadata"
grep -q '^Subject:.*Afaq Foundation' <<<"$metadata"
# Match content independently of line wrapping and column spacing.
pdf_text="$(pdftotext "$valid_output" - | tr '\n\r\f\t' ' ' | sed 's/  */ /g')"
for expected_text in \
  'Edition 1.4' \
  'Reviewed 8 October 2026' \
  'IT / Security Operator' \
  'Review restoration' \
  'Create and onboard a madrassa' \
  'Approval is not activation.' \
  'Create inactive madrassa' \
  'PENDING_ACTIVATION' \
  'ONBOARDING PROGRESS' \
  'acceptance API remains disabled' \
  'Company access: suspend and restore' \
  'Built and tested, not deployed by this update.' \
  'Administrator' \
  'Finance Officer' \
  'Teacher' \
  'Parent' \
  'Learner' \
  'Troubleshooting common issues' \
  'Role quick-start checklists'; do
  if ! grep -Fq "$expected_text" <<<"$pdf_text"; then
    printf 'Generated PDF is missing expected text: %s\n' "$expected_text" >&2
    exit 1
  fi
done

outline="$(mutool show "$valid_output" outline)"
for expected_bookmark in \
  'How work connects across Afaq.' \
  'Three responsibilities. Clear boundaries.' \
  'Approve first. Provision second. Activate last.' \
  'Protect the service. Prove what happened.' \
  'Sign in, then follow the page trail.' \
  'Start well in your workspace.' \
  'Key terms at a glance.'; do
  if ! grep -Fq "$expected_bookmark" <<<"$outline"; then
    printf 'Generated PDF is missing a navigation bookmark: %s\n' "$expected_bookmark" >&2
    exit 1
  fi
done

printf 'Handbook build checks passed.\n'
