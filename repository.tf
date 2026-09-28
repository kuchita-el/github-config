locals {
  # ---------------------------------------------------------------------------
  # Repository preset: all-repository common values for the repository concern
  # (github_repository and github_branch_default, terraform-structure.md §3・§4),
  # referenced directly by the resources below. They cannot be changed per
  # repository; deviating a repository requires registering the attribute in the
  # exception ledger (terraform-structure.md §4).
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

    # Merge methods: squash only, matching the Ruleset's allowed_merge_methods
    # (terraform-structure.md §8, local.branch_protection_preset) at the
    # repository layer so the
    # merge button offers squash alone (Issue #17). The squash commit defaults
    # to the PR title and body. The provider sends the squash_* attributes only
    # while allow_squash_merge is true, and merge_commit_title /
    # merge_commit_message only while allow_merge_commit is true, so the latter
    # two are not declared here (they stay at the provider defaults).
    allow_merge_commit          = false
    allow_rebase_merge          = false
    allow_squash_merge          = true
    squash_merge_commit_title   = "PR_TITLE"
    squash_merge_commit_message = "PR_BODY"

    # Default branch of every repository, applied by github_branch_default below
    # (Issue #17). Not the deprecated github_repository.default_branch.
    default_branch = "main"

    # security_and_analysis (Issue #7): secret scanning / push protection only
    # (advanced_security is out of scope, ADR 0010). The provider docs require
    # visibility=public (or advanced_security enabled, or an org split license)
    # to set these to "enabled"; the dynamic block below emits this whole block
    # only for public repos (terraform-structure.md §6), so these values are
    # never sent for a private repo.
    secret_scanning_status                 = "enabled"
    secret_scanning_push_protection_status = "enabled"
  }
}

# github_repository resource for every managed repository.
# All-repository common values come from local.repository_preset; repo-specific
# values (archived / description / homepage_url / topics) come from
# var.repositories[<repo>].repository
# (terraform-structure.md §4・§5). visibility is a required top-level field of
# each entry.
#
# See: docs/design/terraform-structure.md (§4 value categories, §5 layout,
#      §6 required visibility, §8 repository: single file,
#      lifecycle.ignore_changes scope = visibility, archived only)
# Background: docs/adr/0001-repository-resource-structure.md

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

  allow_merge_commit          = local.repository_preset.allow_merge_commit
  allow_rebase_merge          = local.repository_preset.allow_rebase_merge
  allow_squash_merge          = local.repository_preset.allow_squash_merge
  squash_merge_commit_title   = local.repository_preset.squash_merge_commit_title
  squash_merge_commit_message = local.repository_preset.squash_merge_commit_message

  # secret_scanning / secret_scanning_push_protection (Issue #7,
  # terraform-structure.md §6・§8):
  # public repos only. The GitHub Free plan cannot enable these on a private
  # repo (provider docs), so the block itself is omitted for private repos
  # instead of sending status = "disabled" (terraform-structure.md §6, ADR 0010
  # 代替案).
  dynamic "security_and_analysis" {
    for_each = each.value.visibility == "public" ? [1] : []
    content {
      secret_scanning {
        status = local.repository_preset.secret_scanning_status
      }
      secret_scanning_push_protection {
        status = local.repository_preset.secret_scanning_push_protection_status
      }
    }
  }

  lifecycle {
    # Drift protection: UI/API changes to these attributes do not surface as plan
    # diff. visibility flips (public ⇔ private) have extreme blast radius; archived
    # transitions block writes (Issue/PR/CI). See terraform-structure.md §8.
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
