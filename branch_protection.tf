locals {
  # ---------------------------------------------------------------------------
  # Branch-protection profile defaults: per-profile values
  # (terraform-structure.md §4・§7), keyed by every profile identifier with the
  # same attribute set in each row, and referenced directly by the resource
  # below via each.value.profile. They cannot be changed per repository;
  # deviating a repository requires registering the attribute in the exception
  # ledger (terraform-structure.md §4).
  # ---------------------------------------------------------------------------
  branch_protection_profile_defaults = {
    # strict_required_status_checks_policy ("Require branches to be up to date
    # before merging"), a per-profile value (terraform-structure.md §8).
    # Background in ADR 0007: off only where a semantic conflict that slips
    # past pre-merge CI is caught by main's CI and never reaches a real
    # environment or a consumer directly (app).
    distribution = {
      strict_required_status_checks_policy = true
    }
    infra = {
      strict_required_status_checks_policy = true
    }
    app = {
      strict_required_status_checks_policy = false
    }
    local_config = {
      strict_required_status_checks_policy = true
    }
  }

  # ---------------------------------------------------------------------------
  # Branch-protection preset: all-repository common values
  # (terraform-structure.md §4), applied to every managed repository and
  # referenced directly by the resource below. Values originally mirrored the
  # gachanuma "main protection" ruleset so existing repos imported to a no-op;
  # allowed_merge_methods now follows terraform-structure.md §8 (the same
  # merge methods as local.repository_preset; background in ADR 0005). They
  # cannot be changed per repository; deviating a repository requires
  # registering the attribute in the exception ledger (terraform-structure.md
  # §4).
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
    allowed_merge_methods             = ["squash"]

    # required_status_checks rule (contexts are repo-specific → var.repositories;
    # strict_required_status_checks_policy is per-profile → profile defaults above).
    do_not_enforce_on_create = false
  }

  # ---------------------------------------------------------------------------
  # Branch-protection targets: public repositories only, since the GitHub Free
  # plan allows Rulesets on public repositories only (terraform-structure.md
  # §6). Profile is not used to narrow this target set; every profile still
  # gets a branch protection ruleset once it is public.
  # ---------------------------------------------------------------------------
  branch_protection_targets = {
    for repo, cfg in var.repositories : repo => cfg if cfg.visibility == "public"
  }
}

# Branch protection (Repository Ruleset) for every public managed repository.
# One ruleset per repo, expanded with for_each keyed by repository name so that
# adding/removing a repo never recreates the others.
# All-repository common values come from local.branch_protection_preset;
# per-profile values come from local.branch_protection_profile_defaults keyed by
# var.repositories[<repo>].profile; repo-specific values (status check contexts / integration ID) come from
# var.repositories[<repo>].branch_protection (terraform-structure.md §4・§5).
resource "github_repository_ruleset" "branch_protection" {
  for_each = local.branch_protection_targets

  name        = local.branch_protection_preset.name
  repository  = each.key
  target      = local.branch_protection_preset.target
  enforcement = local.branch_protection_preset.enforcement

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    creation            = local.branch_protection_preset.creation
    deletion            = local.branch_protection_preset.deletion
    non_fast_forward    = local.branch_protection_preset.non_fast_forward
    required_signatures = local.branch_protection_preset.required_signatures

    pull_request {
      required_approving_review_count   = local.branch_protection_preset.required_approving_review_count
      dismiss_stale_reviews_on_push     = local.branch_protection_preset.dismiss_stale_reviews_on_push
      require_code_owner_review         = local.branch_protection_preset.require_code_owner_review
      require_last_push_approval        = local.branch_protection_preset.require_last_push_approval
      required_review_thread_resolution = local.branch_protection_preset.required_review_thread_resolution
      allowed_merge_methods             = local.branch_protection_preset.allowed_merge_methods
    }

    # Only emit a required_status_checks rule when the repo declares CI contexts.
    dynamic "required_status_checks" {
      for_each = length(each.value.branch_protection.status_check_contexts) > 0 ? [1] : []
      content {
        dynamic "required_check" {
          for_each = each.value.branch_protection.status_check_contexts
          content {
            context        = required_check.value
            integration_id = each.value.branch_protection.status_check_integration_id
          }
        }
        strict_required_status_checks_policy = local.branch_protection_profile_defaults[each.value.profile].strict_required_status_checks_policy
        do_not_enforce_on_create             = local.branch_protection_preset.do_not_enforce_on_create
      }
    }
  }
}
