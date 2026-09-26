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
  EOT

  type = map(object({
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
}
