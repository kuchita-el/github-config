#!/usr/bin/env bash
# PostToolUse hook: Edit/Write/MultiEdit 後に対象が .tf なら terraform fmt を適用する。
# 失敗系は常に exit 0 で抜け、編集操作をブロックしない（Issue #24 AC3）。
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "terraform-fmt hook: warn: jq not found, skipping" >&2
  exit 0
fi

file_path="$(jq -r '.tool_input.file_path // empty')"

if [[ -z "$file_path" ]]; then
  exit 0
fi

if [[ "$file_path" != *.tf ]]; then
  exit 0
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform-fmt hook: warn: terraform not found, skipping fmt for $file_path" >&2
  exit 0
fi

if ! terraform fmt "$file_path" >/dev/null; then
  echo "terraform-fmt hook: warn: terraform fmt failed for $file_path" >&2
  exit 0
fi

exit 0
