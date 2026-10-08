#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="${HANDBOOK_SOURCE:-$root_dir/docs/afaq-system-handbook.html}"
output_file="${HANDBOOK_OUTPUT:-$root_dir/docs/Afaq_System_User_Handbook.pdf}"
output_dir="$(dirname "$output_file")"
temporary_file=""

cleanup() {
  if [[ -n "$temporary_file" ]]; then
    rm -f "$temporary_file"
  fi
}
trap cleanup EXIT

if ! command -v weasyprint >/dev/null 2>&1; then
  printf 'weasyprint is required to build the Afaq handbook PDF.\n' >&2
  exit 1
fi

if ! command -v pdfinfo >/dev/null 2>&1; then
  printf 'pdfinfo is required to validate the Afaq handbook PDF.\n' >&2
  exit 1
fi

if ! [[ -f "$source_file" ]]; then
  printf 'Handbook HTML source was not found: %s\n' "$source_file" >&2
  exit 1
fi

while IFS= read -r anchor; do
  if ! grep -Fq "id=\"$anchor\"" "$source_file"; then
    printf 'Handbook link points to a missing section: #%s\n' "$anchor" >&2
    exit 1
  fi
done < <(grep -oE 'href="#[^"]+"' "$source_file" | cut -d '"' -f 2 | cut -c 2-)

duplicate_anchor="$(grep -oE 'id="[^"]+"' "$source_file" | cut -d '"' -f 2 | sort | uniq -d | head -n 1 || true)"
if [[ -n "$duplicate_anchor" ]]; then
  printf 'Handbook contains a duplicate section id: %s\n' "$duplicate_anchor" >&2
  exit 1
fi

temporary_file="$(mktemp "$output_dir/.afaq-handbook.XXXXXX.pdf")"
weasyprint --pdf-tags --custom-metadata "$source_file" "$temporary_file"

metadata="$(pdfinfo "$temporary_file")"
page_count="$(sed -n 's/^Pages:[[:space:]]*//p' <<<"$metadata")"
expected_pages="$(grep -c '<section class="page' "$source_file")"
tagged="$(sed -n 's/^Tagged:[[:space:]]*//p' <<<"$metadata")"
page_size="$(sed -n 's/^Page size:[[:space:]]*//p' <<<"$metadata")"

if [[ ! "$page_count" =~ ^[0-9]+$ || "$page_count" -lt 1 ]]; then
  printf 'Generated PDF has an invalid page count.\n' >&2
  exit 1
fi

if [[ "$page_count" != "$expected_pages" ]]; then
  printf 'PDF has %s pages, but the handbook source defines %s pages. Check for content overflow.\n' \
    "$page_count" "$expected_pages" >&2
  exit 1
fi

if [[ "$tagged" != "yes" ]]; then
  printf 'Generated PDF is missing accessibility tags.\n' >&2
  exit 1
fi

if [[ "$page_size" != *"A4"* ]]; then
  printf 'Generated PDF is not A4: %s\n' "$page_size" >&2
  exit 1
fi

mv -f "$temporary_file" "$output_file"
printf 'Built %s (%s A4 pages, tagged).\n' "$output_file" "$page_count"
