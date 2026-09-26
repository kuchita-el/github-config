# Managed repositories and their repo-specific values (ADR 0004 §4・§5).
# Each entry declares visibility / profile at the top level and nests other
# repo-specific values under the concern key (repository / branch_protection /
# actions_permissions);
# a concern key is written only when the repo has values for it. All-repository
# common values live in local.<concern>_preset and are not set here.
# This file holds only public values (no secrets) and is committed intentionally.

github_owner = "kuchita-el"

repositories = {
  # gachanuma: the existing repo whose "main protection" ruleset was the origin of
  # the branch-protection preset values. status check contexts are gachanuma-specific.
  #
  # profile = app（ADR 0004 §7）: TypeScript 製の実行アプリケーション（確率計算ツール）で、
  # main への push を CI 成功後に GitHub Pages へ静的サイトとしてデプロイする。利用者は
  # デプロイ済みの Web ページを訪れるだけで、リポジトリを ref で参照も複製もしない。
  gachanuma = {
    visibility = "public"
    profile    = "app"

    branch_protection = {
      status_check_contexts       = ["lint", "typecheck", "test", "build", "e2e"]
      status_check_integration_id = 15368 # GitHub Actions
    }
  }

  # github-config: self-governance (dogfooding). CI added in #8.
  #
  # profile = infra（ADR 0004 §7）: 本リポ自身。HCP Terraform の Remote 実行を通じて
  # GitHub 側の実環境（Organization 配下のリポジトリ設定）へ変更が適用される。
  "github-config" = {
    visibility = "public"
    profile    = "infra"

    repository = {
      description = "Terraform-managed GitHub repository settings (rulesets etc.) as IaC"
    }
    branch_protection = {
      status_check_contexts       = ["fmt", "validate", "tflint"]
      status_check_integration_id = 15368 # GitHub Actions
    }
    actions_permissions = {
      patterns_allowed = ["jdx/mise-action@*"] # ワークフローが使う外部 action
    }
  }

  # claude-shared-skills: onboarded by standardizing its pre-existing ruleset
  # (which was enforcement=disabled) to the preset. No CI → no contexts, so no
  # branch_protection key.
  # Imported via a temporary import {} block, then converged. See README.
  #
  # profile = distribution（ADR 0004 §7）: Claude Code / Codex 向けのプラグイン・スキル集。
  # 利用者は marketplace 経由で ref 参照してインストールする（ADR 0004 §7 の識別子表が
  # 「スキル」「プラグイン」を配布物の例として明示）。
  "claude-shared-skills" = {
    visibility = "public"
    profile    = "distribution"

    actions_permissions = {
      patterns_allowed = ["jdx/mise-action@*"] # ワークフローが使う外部 action
    }
  }

  # dependabot-triage-action: public-ized for #4 (was private). No pre-existing
  # ruleset → fresh apply. CI job "build" required.
  #
  # profile = distribution（ADR 0004 §7）: GitHub Action 本体。利用者のワークフローから
  # `uses:` で ref 参照される成果物であり、ADR 0004 §7 の識別子表が「GitHub Action」を
  # 配布物の例として明示する。
  "dependabot-triage-action" = {
    visibility = "public"
    profile    = "distribution"

    branch_protection = {
      status_check_contexts       = ["build"]
      status_check_integration_id = 15368 # GitHub Actions
    }
    actions_permissions = {
      patterns_allowed = ["jdx/mise-action@*", "dependabot/fetch-metadata@*"] # ワークフローが使う外部 action
    }
  }
}
