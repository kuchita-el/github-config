locals {
  # ---------------------------------------------------------------------------
  # Repository preset: all-repository common values for the repository concern
  # (github_repository and github_branch_default, ADR 0004 §3・§4), referenced
  # directly by the resources below. They cannot be
  # changed per repository; deviating a repository requires registering the
  # attribute in the README exception ledger (ADR 0004 §4).
  # ---------------------------------------------------------------------------
  repository_preset = {
    # Security-axis attributes (Issue #16).
    # Close the path where a PR meeting the conditions merges without human review.
    allow_auto_merge = false
    # wiki / projects / discussions widen the external write surface; narrow by
    # default while matching the actual state of the managed repositories.
    has_wiki        = false
    has_projects    = true
    has_discussions = false

    # Process-axis attributes. has_issues / delete_branch_on_merge were pulled
    # forward from Issue #17 into #16 because the provider plans them to
    # false/null when unset. delete_branch_on_merge was unified to true across
    # all repositories in #83.
    has_issues             = true
    delete_branch_on_merge = true

    # Default branch of every repository, applied by github_branch_default below
    # (Issue #17). Not the deprecated github_repository.default_branch.
    default_branch = "main"
  }
}

# github_repository resource for every managed repository.
# All-repository common values come from local.repository_preset; repo-specific
# values (archived / description / homepage_url / topics) come from
# var.repositories[<repo>].repository
# (ADR 0004 §4・§5). visibility is a required top-level field of each entry.
#
# See: docs/adr/0004-terraform-module-structure-policy.md (§4 value categories, §5 layout)
#      docs/adr/0001-repository-resource-structure.md
#  - §決定 > 1 (single file, required visibility)
#  - §決定 > 3 (lifecycle.ignore_changes scope = visibility, archived only)

resource "github_repository" "this" {
  for_each = var.repositories

  name = each.key

  # Required per-repo declaration (no default). Drift-protected by
  # lifecycle.ignore_changes below.
  visibility = each.value.visibility

  # Repo-specific values. null archived falls back to the provider default
  # (false); null description / homepage_url mean none; an empty topics set
  # means no topics.
  archived     = each.value.repository.archived
  description  = each.value.repository.description
  homepage_url = each.value.repository.homepage_url
  topics       = each.value.repository.topics

  # All-repository common values.
  allow_auto_merge       = local.repository_preset.allow_auto_merge
  has_wiki               = local.repository_preset.has_wiki
  has_projects           = local.repository_preset.has_projects
  has_discussions        = local.repository_preset.has_discussions
  has_issues             = local.repository_preset.has_issues
  delete_branch_on_merge = local.repository_preset.delete_branch_on_merge

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

# Default branch of every managed repository (Issue #17). Managed with the
# dedicated resource because github_repository.default_branch is deprecated in
# provider 6.x, and the two must not be combined (the provider docs warn of a
# permanent diff).
#
# rename is left at its default (false): a changed branch is applied by
# switching the default to an existing branch (PATCH /repos/{owner}/{repo}),
# never by renaming the branch. Destroying this resource does not change the
# default branch on GitHub (the provider's Delete sends an empty PATCH).
resource "github_branch_default" "repository" {
  for_each = var.repositories

  repository = github_repository.this[each.key].name
  branch     = local.repository_preset.default_branch
}
