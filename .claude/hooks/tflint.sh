#!/usr/bin/env bash
# PostToolUse hook: Edit/Write/MultiEdit 後に対象が .tf なら tflint を適用する。
# 失敗系は常に exit 0 で抜け、編集操作をブロックしない（Issue #22 AC3 / AC4）。
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "tflint hook: warn: jq not found, skipping" >&2
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

target_dir="$(dirname "$file_path")"
file_name="$(basename "$file_path")"
config="${CLAUDE_PROJECT_DIR:-$PWD}/.tflint.hcl"

if [[ ! -f "$config" ]]; then
  echo "tflint hook: warn: .tflint.hcl not found at $config" >&2
  exit 0
fi

if command -v mise >/dev/null 2>&1; then
  tflint_bin="$(mise which tflint 2>/dev/null || true)"
else
  tflint_bin=""
fi

if [[ -z "$tflint_bin" ]] && command -v tflint >/dev/null 2>&1; then
  tflint_bin="$(command -v tflint)"
fi

if [[ -z "$tflint_bin" ]]; then
  echo "tflint hook: warn: tflint not found, skipping lint for $file_path" >&2
  exit 0
fi

(cd "$target_dir" 2>/dev/null && "$tflint_bin" --config="$config" --filter="$file_name" --no-color --format=compact 2>&1) >&2 || true

exit 0
