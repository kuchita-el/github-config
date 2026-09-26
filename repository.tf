# github_repository resource for every managed repository.
# Preset values live as optional() defaults on var.repositories (variables.tf);
# per-repo overrides are plain values in terraform.tfvars. No locals/merge()
# composition, so every attribute keeps its declared type.
#
# See: docs/adr/0001-repository-resource-structure.md
#  - §決定 > 1 (single file + variable defaults)
#  - §決定 > 3 (lifecycle.ignore_changes scope = visibility, archived only)
#  - §影響 > 子Issue #16 (this issue's scope)

resource "github_repository" "this" {
  for_each = var.repositories

  name = each.key

  # Required per-repo declaration (no default). Drift-protected by
  # lifecycle.ignore_changes below.
  visibility = each.value.visibility

  # Security-axis attributes (Issue #16).
  archived         = each.value.archived
  allow_auto_merge = each.value.allow_auto_merge
  has_wiki         = each.value.has_wiki
  has_projects     = each.value.has_projects
  has_discussions  = each.value.has_discussions

  # Process-axis attributes pulled forward from Issue #17: the provider plans
  # them to false/null when unset, so they must be declared for the import to
  # be a no-op. The remaining process-axis attributes are added by Issue #17.
  has_issues             = each.value.has_issues
  delete_branch_on_merge = each.value.delete_branch_on_merge
  description            = each.value.description

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
