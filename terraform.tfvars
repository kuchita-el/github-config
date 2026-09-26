# Managed repositories and their per-repo overrides.
# This file holds only public values (no secrets) and is committed intentionally.

github_owner = "kuchita-el"

repositories = {
  # gachanuma: the existing repo whose "main protection" ruleset is the source of
  # truth for the preset. status check contexts are gachanuma-specific.
  # has_wiki=true overrides the security preset (false).
  #
  # profile = app（ADR 0004 §7）: TypeScript 製の実行アプリケーション（確率計算ツール）で、
  # main への push を CI 成功後に GitHub Pages へ静的サイトとしてデプロイする。利用者は
  # デプロイ済みの Web ページを訪れるだけで、リポジトリを ref で参照も複製もしない。
  gachanuma = {
    visibility                  = "public"
    profile                     = "app"
    has_wiki                    = true
    status_check_contexts       = ["lint", "typecheck", "test", "build", "e2e"]
    status_check_integration_id = 15368 # GitHub Actions
  }

  # github-config: self-governance (dogfooding). CI added in #8.
  #
  # profile = infra（ADR 0004 §7）: 本リポ自身。HCP Terraform の Remote 実行を通じて
  # GitHub 側の実環境（Organization 配下のリポジトリ設定）へ変更が適用される。
  "github-config" = {
    visibility                  = "public"
    profile                     = "infra"
    description                 = "Terraform-managed GitHub repository settings (rulesets etc.) as IaC"
    status_check_contexts       = ["fmt", "validate", "tflint"]
    status_check_integration_id = 15368 # GitHub Actions
  }

  # claude-shared-skills: onboarded by standardizing its pre-existing ruleset
  # (which was enforcement=disabled) to the preset. No CI → no contexts.
  # Imported via a temporary import {} block, then converged. See README.
  # has_wiki=true overrides the security preset (false).
  # delete_branch_on_merge=true overrides the process preset (false).
  #
  # profile = distribution（ADR 0004 §7）: Claude Code / Codex 向けのプラグイン・スキル集。
  # 利用者は marketplace 経由で ref 参照してインストールする（ADR 0004 §7 の識別子表が
  # 「スキル」「プラグイン」を配布物の例として明示）。
  "claude-shared-skills" = {
    visibility             = "public"
    profile                = "distribution"
    has_wiki               = true
    delete_branch_on_merge = true
  }

  # dependabot-triage-action: public-ized for #4 (was private). No pre-existing
  # ruleset → fresh apply. CI job "build" required.
  #
  # profile = distribution（ADR 0004 §7）: GitHub Action 本体。利用者のワークフローから
  # `uses:` で ref 参照される成果物であり、ADR 0004 §7 の識別子表が「GitHub Action」を
  # 配布物の例として明示する。
  "dependabot-triage-action" = {
    visibility                  = "public"
    profile                     = "distribution"
    status_check_contexts       = ["build"]
    status_check_integration_id = 15368 # GitHub Actions
  }
}
