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
