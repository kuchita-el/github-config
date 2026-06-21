#!/usr/bin/env bash
# PreToolUse hook: *.tfstate* / *.pem / .terraform.lock.hcl への Edit/Write/MultiEdit を deny する。
# HCP が State of Truth の state ファイル・App 秘密鍵・lock ファイルの「うっかり編集」を事前に阻止する。
set -u

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

file_path="$(jq -r '.tool_input.file_path // empty' 2>/dev/null)"

if [[ -z "$file_path" ]]; then
  exit 0
fi

filename="$(basename "$file_path")"

block_reason=""

if [[ "$filename" == *.tfstate || "$filename" == *.tfstate.* || "$filename" == *.tfstate* ]]; then
  block_reason="*.tfstate* は HCP Terraform が管理する State of Truth です。直接編集は禁止されています（#25）。"
elif [[ "$filename" == *.pem ]]; then
  block_reason="*.pem は GitHub App 秘密鍵です。直接編集は禁止されています（#25）。"
elif [[ "$filename" == ".terraform.lock.hcl" ]]; then
  block_reason=".terraform.lock.hcl は terraform init が管理するバージョン固定ファイルです。直接編集は禁止されています（#25）。"
fi

if [[ -n "$block_reason" ]]; then
  printf '{"decision":"block","reason":"%s"}' "$block_reason"
  exit 0
fi

exit 0
