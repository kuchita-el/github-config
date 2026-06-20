# github_repository resource for every managed repository.
# Attributes are composed by merging the security preset, the process preset,
# and the per-repo override; null entries in the override are stripped first so
# unset values cannot overwrite base preset values with null.
#
# See: docs/adr/0001-repository-resource-structure.md
#  - §決定 > 1 (resource block = single file, preset = motivation-axis locals split)
#  - §決定 > 3 (lifecycle.ignore_changes scope = visibility, archived only)
#  - §影響 > 子Issue #16 (this issue's scope)

locals {
  # Effective per-repo settings = security preset ⊕ process preset ⊕ override (null-stripped).
  # Order matters: later entries win in merge(). null is stripped from override so
  # unset optional fields fall back to base preset values rather than becoming null.
  repository_settings = {
    for repo, ovr in var.repositories : repo => merge(
      local.repository_security_preset,
      local.repository_process_preset,
      { for k, v in ovr : k => v if v != null },
    )
  }
}

resource "github_repository" "this" {
  for_each = var.repositories

  name = each.key

  # Required per-repo declaration, passed directly (not via merge).
  # Drift-protected by lifecycle.ignore_changes below.
  visibility = each.value.visibility

  # Security preset attributes (ADR 0001 付録 A baseline + per-repo overrides).
  archived         = local.repository_settings[each.key].archived
  allow_auto_merge = local.repository_settings[each.key].allow_auto_merge
  has_wiki         = local.repository_settings[each.key].has_wiki
  has_projects     = local.repository_settings[each.key].has_projects
  has_discussions  = local.repository_settings[each.key].has_discussions

  # Process preset attributes are added by Issue #17. Until then,
  # local.repository_process_preset is an empty map and these attributes inherit
  # provider defaults.

  lifecycle {
    # Drift protection: UI/API changes to these attributes do not surface as plan
    # diff. visibility flips (public ⇔ private) have extreme blast radius; archived
    # transitions block writes (Issue/PR/CI). See ADR 0001 §決定 > 3.
    ignore_changes = [
      visibility,
      archived,
    ]
  }
}
