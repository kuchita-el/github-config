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
    # Required per-repo declaration: repository visibility. Required (non-optional)
    # to force explicit declaration for every repo (ADR 0001 §3 / Issue #16).
    # Not included in repository_security_preset to prevent accidental drift via
    # base preset edits.
    visibility = string

    # Required status check contexts (CI job names) for this repo. Empty list = no
    # required_status_checks rule for this repo.
    status_check_contexts = optional(list(string), [])
    # GitHub App ID that produces the checks above (15368 = GitHub Actions).
    # Required when status_check_contexts is non-empty.
    status_check_integration_id = optional(number)

    # Optional per-repo overrides of the base branch-protection preset (null = inherit base).
    enforcement                          = optional(string)
    required_approving_review_count      = optional(number)
    dismiss_stale_reviews_on_push        = optional(bool)
    require_code_owner_review            = optional(bool)
    require_last_push_approval           = optional(bool)
    required_review_thread_resolution    = optional(bool)
    allowed_merge_methods                = optional(list(string))
    strict_required_status_checks_policy = optional(bool)
    do_not_enforce_on_create             = optional(bool)

    # Optional per-repo overrides of the base repository_security preset (null = inherit base).
    # ADR 0001 §1 / Issue #16. null is stripped before merge() so unset values
    # do not overwrite base preset values.
    archived         = optional(bool)
    allow_auto_merge = optional(bool)
    has_wiki         = optional(bool)
    has_projects     = optional(bool)
    has_discussions  = optional(bool)
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
