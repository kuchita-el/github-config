variable "github_owner" {
  type        = string
  description = "管理対象リポジトリが属する GitHub アカウント（owner）。例: 自分のユーザー名。"
}

variable "repositories" {
  description = <<-EOT
    管理対象リポジトリ。キーはリポジトリ名。

    各エントリは branch_protection.tf で定義したブランチ保護プリセットを上書きする。
    属性を未指定にするとプリセットの値を引き継ぐ。リポジトリごとに異なるのが通例の値は
    必須ステータスチェックのコンテキスト（CI ジョブ名）のみであり、
    そのためプリセットではなくここに置く。

    github_repository の属性（visibility を除く）は optional の default をプリセット値とし、
    差分のあるリポジトリだけが値を指定する（ADR 0001 §1）。visibility は全リポジトリで必須。

    profile（類型プロファイル、ADR 0004 §7）も全リポジトリで必須。類型ごとの設定既定値を
    参照する resource は未実装で、現時点では宣言と検証のみ行う。
  EOT

  type = map(object({
    # リポジトリの公開範囲（必須）。全リポジトリで明示宣言を強制するため optional にしない
    # （ADR 0001 §影響 > #16）。既定値の編集で全リポジトリの公開範囲が変わる事故を防ぐため、
    # default を持たせない。
    visibility = string

    # リポジトリの類型プロファイル（必須、ADR 0004 §7）。判定基準は「リポの変更がどこへ届くか」。
    # 既定値は持たせない（付け忘れを構造的に防ぐ。visibility と同じ扱い）。
    # 類型ごとの設定既定値（local.<concern>_profile_defaults）を消費する resource は本 Issue では
    # まだ無く、ここでは宣言と検証だけを行う。
    profile = string

    # このリポジトリの必須ステータスチェックのコンテキスト（CI ジョブ名）。
    # 空リストの場合、このリポジトリには required_status_checks ルールを作らない。
    status_check_contexts = optional(list(string), [])
    # 上記チェックを生成する GitHub App の ID（15368 = GitHub Actions）。
    # status_check_contexts が空でない場合は必須。
    status_check_integration_id = optional(number)

    # リポジトリ単位でのプリセット上書き（任意）。null はプリセットの値を引き継ぐ。
    enforcement                          = optional(string)
    required_approving_review_count      = optional(number)
    dismiss_stale_reviews_on_push        = optional(bool)
    require_code_owner_review            = optional(bool)
    require_last_push_approval           = optional(bool)
    required_review_thread_resolution    = optional(bool)
    allowed_merge_methods                = optional(list(string))
    strict_required_status_checks_policy = optional(bool)
    do_not_enforce_on_create             = optional(bool)

    # github_repository のセキュリティ系属性（ADR 0001 §1 / Issue #16）。
    # default がプリセット値（管理対象4リポの共通値、ADR 0001 付録 A）で、リポジトリ単位で上書きできる。
    # 書き込み可能な状態を既定とする。lifecycle.ignore_changes で drift から保護する。
    archived = optional(bool, false)
    # 条件を満たした PR が人のレビューを経ずにマージされる経路を既定で閉じる。
    allow_auto_merge = optional(bool, false)
    # wiki / projects / discussions は外部からの書き込み面を広げるため、実態に合わせつつ既定で絞る。
    has_wiki        = optional(bool, false)
    has_projects    = optional(bool, true)
    has_discussions = optional(bool, false)

    # github_repository の開発プロセス系属性のうち、#16 に前倒しするもの（ADR 0001 §影響 #16）。
    # provider はこれらを宣言しないと空値（false / null）へ変更する plan を出すため、import を no-op に
    # するには #16 の時点で実態値の宣言が要る。default は ADR 0001 §影響 #17 の preset 値。
    has_issues             = optional(bool, true)
    delete_branch_on_merge = optional(bool, false)
    # preset 値が null のため default を省略する（null = 説明文なし）。
    description = optional(string)
  }))

  # Enforce: if a repo declares status check contexts, it must also declare the
  # integration_id (otherwise null is passed to required_check.integration_id).
  validation {
    condition = alltrue([
      for r in values(var.repositories) :
      length(r.status_check_contexts) == 0 || r.status_check_integration_id != null
    ])
    error_message = "status_check_integration_id is required when status_check_contexts is non-empty."
  }

  # profile は ADR 0004 §7 が定める4つの識別子以外を拒否する。
  validation {
    condition = alltrue([
      for r in values(var.repositories) :
      contains(["distribution", "infra", "app", "local_config"], r.profile)
    ])
    error_message = "profile must be one of: distribution, infra, app, local_config (ADR 0004 §7)."
  }
}
