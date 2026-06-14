variable "github_owner" {
  type        = string
  description = "GitHub account (owner) that the managed repositories belong to (e.g. your username)."
}

variable "repositories" {
  description = <<-EOT
    Repositories under management, keyed by repository name.

    Each entry overrides the base branch-protection preset defined in locals.tf.
    Leave an attribute unset to inherit the base value. The only commonly
    repo-specific values are the required status check contexts (CI job names),
    which differ per repository, so they live here rather than in the base.
  EOT

  type = map(object({
    # Required status check contexts (CI job names) for this repo. Empty list = no
    # required_status_checks rule for this repo.
    status_check_contexts = optional(list(string), [])
    # GitHub App ID that produces the checks above (15368 = GitHub Actions).
    # Required when status_check_contexts is non-empty.
    status_check_integration_id = optional(number)

    # Optional per-repo overrides of the base preset (null = inherit base).
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
}
