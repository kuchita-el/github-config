locals {
  # ---------------------------------------------------------------------------
  # Dependabot-security-updates preset: all-repository common value for the
  # dependabot_security_updates concern
  # (github_repository_dependabot_security_updates, terraform-structure.md
  # §3・§4, ADR 0010), referenced directly by the resource below. It cannot be
  # changed per repository; deviating a repository requires registering the
  # attribute in the exception ledger (terraform-structure.md §4).
  # ---------------------------------------------------------------------------
  dependabot_security_updates_preset = {
    enabled = true
  }
}

# github_repository_dependabot_security_updates resource for every managed
# repository (Issue #7). No visibility constraint (ADR 0010: GitHub Free
# includes Dependabot security and version updates for public and private
# repos alike), so it applies to all of var.repositories with no
# target-narrowing local.
#
# See: docs/design/terraform-structure.md (§4 value categories, §5 layout)
#      docs/adr/0010-vulnerability-alerts-and-dependabot-security-updates.md
resource "github_repository_dependabot_security_updates" "dependabot_security_updates" {
  for_each = var.repositories

  repository = each.key
  enabled    = local.dependabot_security_updates_preset.enabled
}
