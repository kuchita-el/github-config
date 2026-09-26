locals {
  # ---------------------------------------------------------------------------
  # Actions-permissions preset: all-repository common values for the Actions
  # permissions concern (github_actions_repository_permissions and
  # github_workflow_repository_permissions, ADR 0004 §4), referenced directly by
  # the resources below. They cannot be changed per repository; deviating a
  # repository requires registering the attribute in the README exception
  # ledger (ADR 0004 §4). There is no per-profile value for this concern (no
  # local.actions_permissions_profile_defaults).
  # ---------------------------------------------------------------------------
  actions_permissions_preset = {
    # Actions permissions (github_actions_repository_permissions). "selected"
    # narrows the allowed action surface to allowed_actions_config below,
    # instead of "all" (any published action) or "local_only" (same-owner only).
    enabled              = true
    allowed_actions      = "selected"
    sha_pinning_required = true
    github_owned_allowed = true
    verified_allowed     = false

    # Workflow permissions (github_workflow_repository_permissions). "read"
    # narrows the default GITHUB_TOKEN scope; a workflow that needs write access
    # requests it explicitly via `permissions:` in its own YAML.
    default_workflow_permissions     = "read"
    can_approve_pull_request_reviews = false
  }
}

# github_actions_repository_permissions resource for every managed repository.
# All-repository common values come from local.actions_permissions_preset;
# the repo-specific allowlist (patterns_allowed) comes from
# var.repositories[<repo>].actions_permissions (ADR 0004 §4・§5).
#
# See: docs/adr/0004-terraform-module-structure-policy.md (§4 value categories, §5 layout)
resource "github_actions_repository_permissions" "actions_permissions" {
  for_each = var.repositories

  repository = each.key

  enabled              = local.actions_permissions_preset.enabled
  allowed_actions      = local.actions_permissions_preset.allowed_actions
  sha_pinning_required = local.actions_permissions_preset.sha_pinning_required

  allowed_actions_config {
    github_owned_allowed = local.actions_permissions_preset.github_owned_allowed
    verified_allowed     = local.actions_permissions_preset.verified_allowed
    # Repo-specific value. An empty list means no additional actions beyond
    # github_owned_allowed / verified_allowed above.
    patterns_allowed = each.value.actions_permissions.patterns_allowed
  }
}

# github_workflow_repository_permissions resource for every managed repository.
# All values are all-repository common (local.actions_permissions_preset); this
# concern has no repo-specific values.
resource "github_workflow_repository_permissions" "workflow_permissions" {
  for_each = var.repositories

  repository = each.key

  default_workflow_permissions     = local.actions_permissions_preset.default_workflow_permissions
  can_approve_pull_request_reviews = local.actions_permissions_preset.can_approve_pull_request_reviews
}
