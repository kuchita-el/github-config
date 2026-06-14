locals {
  # ---------------------------------------------------------------------------
  # Base branch-protection preset, applied to every managed repository.
  # Values mirror the gachanuma "main protection" ruleset so existing repos
  # import to a no-op. Override per repository via var.repositories.
  # ---------------------------------------------------------------------------
  base_branch_protection = {
    name        = "main protection"
    target      = "branch"
    enforcement = "active"

    # Boolean rules (presence = enforced).
    creation            = true
    deletion            = true
    non_fast_forward    = true
    required_signatures = true

    # pull_request rule.
    required_approving_review_count   = 0
    dismiss_stale_reviews_on_push     = true
    require_code_owner_review         = false
    require_last_push_approval        = false
    required_review_thread_resolution = true
    allowed_merge_methods             = ["rebase", "merge"]

    # required_status_checks rule (contexts are repo-specific → injected per repo).
    strict_required_status_checks_policy = true
    do_not_enforce_on_create             = false
  }

  # ---------------------------------------------------------------------------
  # Effective settings per repository = base preset + per-repo override.
  # "ovr.X != null ? ovr.X : base.X" applies the override only when set; this is
  # type-safe for bool/number/string/list alike (unlike coalesce on lists/bools).
  # ---------------------------------------------------------------------------
  branch_protection = {
    for repo, ovr in var.repositories : repo => {
      name        = local.base_branch_protection.name
      target      = local.base_branch_protection.target
      enforcement = ovr.enforcement != null ? ovr.enforcement : local.base_branch_protection.enforcement

      creation            = local.base_branch_protection.creation
      deletion            = local.base_branch_protection.deletion
      non_fast_forward    = local.base_branch_protection.non_fast_forward
      required_signatures = local.base_branch_protection.required_signatures

      required_approving_review_count   = ovr.required_approving_review_count != null ? ovr.required_approving_review_count : local.base_branch_protection.required_approving_review_count
      dismiss_stale_reviews_on_push     = ovr.dismiss_stale_reviews_on_push != null ? ovr.dismiss_stale_reviews_on_push : local.base_branch_protection.dismiss_stale_reviews_on_push
      require_code_owner_review         = ovr.require_code_owner_review != null ? ovr.require_code_owner_review : local.base_branch_protection.require_code_owner_review
      require_last_push_approval        = ovr.require_last_push_approval != null ? ovr.require_last_push_approval : local.base_branch_protection.require_last_push_approval
      required_review_thread_resolution = ovr.required_review_thread_resolution != null ? ovr.required_review_thread_resolution : local.base_branch_protection.required_review_thread_resolution
      allowed_merge_methods             = ovr.allowed_merge_methods != null ? ovr.allowed_merge_methods : local.base_branch_protection.allowed_merge_methods

      strict_required_status_checks_policy = ovr.strict_required_status_checks_policy != null ? ovr.strict_required_status_checks_policy : local.base_branch_protection.strict_required_status_checks_policy
      do_not_enforce_on_create             = ovr.do_not_enforce_on_create != null ? ovr.do_not_enforce_on_create : local.base_branch_protection.do_not_enforce_on_create

      status_check_contexts       = ovr.status_check_contexts
      status_check_integration_id = ovr.status_check_integration_id
    }
  }
}
