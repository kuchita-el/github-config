variable "github_owner" {
  type        = string
  description = "管理対象リポジトリが属する GitHub アカウント（owner）。例: 自分のユーザー名。"
}

variable "repositories" {
  description = <<-EOT
    管理対象リポジトリ。キーはリポジトリ名。

    各エントリにはリポ固有値だけを書く（terraform-structure.md §4・§5）。直下には visibility と
    profile（いずれも必須、既定値なし）だけを置き、それ以外のリポ固有値は設定種別名の
    キー（repository / branch_protection / actions_permissions）の下に入れ子にする。設定種別のキーは、その
    設定種別にリポ固有値があるリポだけが書き、省略すると値の無い状態（null / 空リスト）になる。

    全リポ共通値は各設定種別ファイル冒頭の local.<concern>_preset
    （repository.tf の repository_preset、branch_protection.tf の branch_protection_preset、
    actions_permissions.tf の actions_permissions_preset）に置き、
    ここでは変えられない。類型決定値は各設定種別ファイル冒頭の
    local.<concern>_profile_defaults（branch_protection.tf の
    branch_protection_profile_defaults）に置き、各リポの profile（類型プロファイル、
    terraform-structure.md §7）で引く。これもここでは変えられない。特定のリポで
    全リポ共通値・類型決定値から外すには、terraform-structure.md §4 の例外台帳への
    登録を要する。
  EOT

  type = map(object({
    # リポジトリの公開範囲（必須）。全リポジトリで明示宣言を強制するため optional にしない
    # （terraform-structure.md §6）。既定値の編集で全リポジトリの公開範囲が変わる事故を防ぐため、
    # default を持たせない。
    visibility = string

    # リポジトリの類型プロファイル（必須、terraform-structure.md §7）。判定基準は「リポの変更がどこへ届くか」。
    # 既定値は持たせない（付け忘れを構造的に防ぐ。visibility と同じ扱い）。
    # 類型決定値の表（local.<concern>_profile_defaults）を引くキーになる。
    profile = string

    # github_repository（repository.tf）のリポ固有値。値を持たないリポは省略できる。
    repository = optional(object({
      # アーカイブ済みか。null は未アーカイブ（provider の既定値 false）として扱われる。
      # lifecycle.ignore_changes の対象で、drift は plan に出ない。
      archived = optional(bool)
      # リポジトリの説明文。null は説明文なし。
      description = optional(string)
      # リポジトリのホームページ URL（About 欄の Website）。null はホームページなし。
      homepage_url = optional(string)
      # リポジトリの topics（terraform-structure.md §8: github_repository.topics 属性で管理する）。
      # 空リストは topics なし。英小文字・数字・ハイフンのみ、50 文字以内（provider の検証）。
      topics = optional(set(string), [])
    }), {})

    # github_repository_ruleset.branch_protection（branch_protection.tf）のリポ固有値。
    # 値を持たないリポは省略できる。
    branch_protection = optional(object({
      # このリポジトリの必須ステータスチェックのコンテキスト（CI ジョブ名）。
      # 空リストの場合、このリポジトリには required_status_checks ルールを作らない。
      status_check_contexts = optional(list(string), [])
      # 上記チェックを生成する GitHub App の ID（15368 = GitHub Actions）。
      # status_check_contexts が空でない場合は必須。
      status_check_integration_id = optional(number)
    }), {})

    # github_actions_repository_permissions（actions_permissions.tf）のリポ固有値。
    # 値を持たないリポは省略できる。
    actions_permissions = optional(object({
      # このリポジトリのワークフローが使ってよい action の追加許可パターン
      # （allowed_actions_config.patterns_allowed）。github_owned_allowed /
      # verified_allowed で許可される範囲を超えて使う action だけを書く
      # （例: "jdx/mise-action@*"）。空リストは追加許可なし。
      patterns_allowed = optional(set(string), [])
    }), {})
  }))

  # Enforce: if a repo declares status check contexts, it must also declare the
  # integration_id (otherwise null is passed to required_check.integration_id).
  validation {
    condition = alltrue([
      for r in values(var.repositories) :
      length(r.branch_protection.status_check_contexts) == 0 || r.branch_protection.status_check_integration_id != null
    ])
    error_message = "branch_protection.status_check_integration_id is required when branch_protection.status_check_contexts is non-empty."
  }

  # profile は terraform-structure.md §7 が定める4つの識別子以外を拒否する。
  validation {
    condition = alltrue([
      for r in values(var.repositories) :
      contains(["distribution", "infra", "app", "local_config"], r.profile)
    ])
    error_message = "profile must be one of: distribution, infra, app, local_config (docs/design/terraform-structure.md §7)."
  }
}
