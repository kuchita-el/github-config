# Managed repositories and their repo-specific values
# (terraform-structure.md §4・§5).
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
  # profile = app（terraform-structure.md §7）: TypeScript 製の実行アプリケーション（確率計算ツール）で、
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
  # profile = infra（terraform-structure.md §7）: 本リポ自身。HCP Terraform の Remote 実行を通じて
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
  # profile = distribution（terraform-structure.md §7）: Claude Code / Codex 向けのプラグイン・スキル集。
  # 利用者は marketplace 経由で ref 参照してインストールする（terraform-structure.md §7 の類型の表が
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
  # profile = distribution（terraform-structure.md §7）: GitHub Action 本体。利用者のワークフローから
  # `uses:` で ref 参照される成果物であり、terraform-structure.md §7 の類型の表が「GitHub Action」を
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

  # agent-config: Claude Code・Codex の個人設定（#117）。Ruleset の無い新規リポとして import した。
  # CI が無いため branch_protection のキーは持たない。
  #
  # profile = local_config（terraform-structure.md §7）: 公開されているが、読み手が参照・取り込みの対象に
  # しない設定集（§7 の境界例）。変更が自動で届く先は所有者の端末だけで、読み手による写し取りは
  # 一回きりで変更を追いかけない。
  "agent-config" = {
    visibility = "public"
    profile    = "local_config"

    repository = {
      description = "Claude Code と Codex の個人設定（読んで参考にする資料）"
    }
  }

  # work-abstraction: private リポ（#4）。ビジネスワークフローの Web アプリ。
  #
  # profile = app（terraform-structure.md §7）: 実行アプリケーションのソースを持ち、利用者は ref で参照も
  # 複製もしない。private のため branch_protection / tag_protection の Ruleset は対象外
  # （local.<concern>_targets が visibility == "public" のリポだけに絞る、terraform-structure.md §6）。
  "work-abstraction" = {
    visibility = "private"
    profile    = "app"

    actions_permissions = {
      patterns_allowed = ["pnpm/action-setup@*"] # ワークフローが使う外部 action
    }
  }

  # budget-baker: private リポ（#4）。予実管理アプリ。
  #
  # profile = app（terraform-structure.md §7）: 実行アプリケーションのソースを持ち、利用者は ref で参照も
  # 複製もしない。private のため branch_protection / tag_protection の Ruleset は対象外
  # （local.<concern>_targets が visibility == "public" のリポだけに絞る、terraform-structure.md §6）。
  "budget-baker" = {
    visibility = "private"
    profile    = "app"
  }

  # cody: private リポ（#4）。オンラインでコードを書く Web アプリ。
  #
  # profile = app（terraform-structure.md §7）: 実行アプリケーションのソースを持ち、利用者は ref で参照も
  # 複製もしない。private のため branch_protection / tag_protection の Ruleset は対象外
  # （local.<concern>_targets が visibility == "public" のリポだけに絞る、terraform-structure.md §6）。
  cody = {
    visibility = "private"
    profile    = "app"
  }

  # coffeeshop: private リポ（#4）。カフェの業務システム。
  #
  # profile = app（terraform-structure.md §7）: 実行アプリケーションのソースを持ち、利用者は ref で参照も
  # 複製もしない。private のため branch_protection / tag_protection の Ruleset は対象外
  # （local.<concern>_targets が visibility == "public" のリポだけに絞る、terraform-structure.md §6）。
  coffeeshop = {
    visibility = "private"
    profile    = "app"
  }
}
