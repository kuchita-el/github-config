#!/usr/bin/env bash
# PostToolUse hook: Edit/Write/MultiEdit 後に対象が .tf なら terraform fmt を適用する。
# 失敗系は常に exit 0 で抜け、編集操作をブロックしない（Issue #24 AC3）。
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "terraform-fmt hook: warn: jq not found, skipping" >&2
  exit 0
fi

file_path="$(jq -r '.tool_input.file_path // empty' 2>/dev/null)"

if [[ -z "$file_path" ]]; then
  exit 0
fi

if [[ "$file_path" != *.tf ]]; then
  exit 0
fi

if [[ "$file_path" != /* ]]; then
  file_path="${CLAUDE_PROJECT_DIR:-$PWD}/$file_path"
fi

if command -v mise >/dev/null 2>&1; then
  terraform_bin="$(cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null && mise which terraform 2>/dev/null || true)"
else
  terraform_bin=""
fi

if [[ -z "$terraform_bin" ]] && command -v terraform >/dev/null 2>&1; then
  terraform_bin="$(command -v terraform)"
fi

if [[ -z "$terraform_bin" ]]; then
  echo "terraform-fmt hook: warn: terraform not found, skipping fmt for $file_path" >&2
  exit 0
fi

if ! "$terraform_bin" fmt "$file_path" >/dev/null 2>&1; then
  echo "terraform-fmt hook: warn: terraform fmt failed for $file_path" >&2
  exit 0
fi

exit 0
