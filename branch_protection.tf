locals {
  # ---------------------------------------------------------------------------
  # Branch-protection preset, applied to every managed repository.
  # Values mirror the gachanuma "main protection" ruleset so existing repos
  # import to a no-op. Override per repository via var.repositories.
  # ---------------------------------------------------------------------------
  branch_protection_preset = {
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
}

locals {
  # ---------------------------------------------------------------------------
  # Effective settings per repository = preset + per-repo override.
  # "ovr.X != null ? ovr.X : local.branch_protection_preset.X" applies the
  # override only when set; this is type-safe for bool/number/string/list alike
  # (unlike coalesce on lists/bools).
  # ---------------------------------------------------------------------------
  branch_protection = {
    for repo, ovr in var.repositories : repo => {
      name        = local.branch_protection_preset.name
      target      = local.branch_protection_preset.target
      enforcement = ovr.enforcement != null ? ovr.enforcement : local.branch_protection_preset.enforcement

      creation            = local.branch_protection_preset.creation
      deletion            = local.branch_protection_preset.deletion
      non_fast_forward    = local.branch_protection_preset.non_fast_forward
      required_signatures = local.branch_protection_preset.required_signatures

      required_approving_review_count   = ovr.required_approving_review_count != null ? ovr.required_approving_review_count : local.branch_protection_preset.required_approving_review_count
      dismiss_stale_reviews_on_push     = ovr.dismiss_stale_reviews_on_push != null ? ovr.dismiss_stale_reviews_on_push : local.branch_protection_preset.dismiss_stale_reviews_on_push
      require_code_owner_review         = ovr.require_code_owner_review != null ? ovr.require_code_owner_review : local.branch_protection_preset.require_code_owner_review
      require_last_push_approval        = ovr.require_last_push_approval != null ? ovr.require_last_push_approval : local.branch_protection_preset.require_last_push_approval
      required_review_thread_resolution = ovr.required_review_thread_resolution != null ? ovr.required_review_thread_resolution : local.branch_protection_preset.required_review_thread_resolution
      allowed_merge_methods             = ovr.allowed_merge_methods != null ? ovr.allowed_merge_methods : local.branch_protection_preset.allowed_merge_methods

      strict_required_status_checks_policy = ovr.strict_required_status_checks_policy != null ? ovr.strict_required_status_checks_policy : local.branch_protection_preset.strict_required_status_checks_policy
      do_not_enforce_on_create             = ovr.do_not_enforce_on_create != null ? ovr.do_not_enforce_on_create : local.branch_protection_preset.do_not_enforce_on_create

      status_check_contexts       = ovr.status_check_contexts
      status_check_integration_id = ovr.status_check_integration_id
    }
  }
}

# Branch protection (Repository Ruleset) for every managed repository.
# One ruleset per repo, expanded with for_each keyed by repository name so that
# adding/removing a repo never recreates the others.
resource "github_repository_ruleset" "branch_protection" {
  for_each = local.branch_protection

  name        = each.value.name
  repository  = each.key
  target      = each.value.target
  enforcement = each.value.enforcement

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    creation            = each.value.creation
    deletion            = each.value.deletion
    non_fast_forward    = each.value.non_fast_forward
    required_signatures = each.value.required_signatures

    pull_request {
      required_approving_review_count   = each.value.required_approving_review_count
      dismiss_stale_reviews_on_push     = each.value.dismiss_stale_reviews_on_push
      require_code_owner_review         = each.value.require_code_owner_review
      require_last_push_approval        = each.value.require_last_push_approval
      required_review_thread_resolution = each.value.required_review_thread_resolution
      allowed_merge_methods             = each.value.allowed_merge_methods
    }

    # Only emit a required_status_checks rule when the repo declares CI contexts.
    dynamic "required_status_checks" {
      for_each = length(each.value.status_check_contexts) > 0 ? [1] : []
      content {
        dynamic "required_check" {
          for_each = each.value.status_check_contexts
          content {
            context        = required_check.value
            integration_id = each.value.status_check_integration_id
          }
        }
        strict_required_status_checks_policy = each.value.strict_required_status_checks_policy
        do_not_enforce_on_create             = each.value.do_not_enforce_on_create
      }
    }
  }
}
