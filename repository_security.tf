# Security-axis preset for github_repository.
# Holds attributes that bear directly on security risk surface. Per-repo overrides
# go in var.repositories; null entries are stripped before merge() in repository.tf
# so unset overrides cannot overwrite these base values with null.
#
# See: docs/adr/0001-repository-resource-structure.md
#  - §決定 > 1 (motivation-axis preset split via locals)
#  - 付録 A (attribute baseline values)
# Issue: #16
#
# Note: `visibility` is NOT included here. It is declared per-repo as a required
# attribute on var.repositories to force explicit declaration and prevent
# accidental drift from base preset edits (ADR 0001 §決定 > 1, §影響 > #16).

locals {
  repository_security_preset = {
    # Archived state. base=false: managed repos are write-enabled.
    # Drift-protected via lifecycle.ignore_changes in repository.tf.
    archived = false

    # Auto-merge bypasses the human review gate for PRs that meet branch
    # protection requirements. base=false: review-bypass paths are off by default.
    allow_auto_merge = false

    # Attack-surface reduction (wiki/projects/discussions tabs each expand the
    # public surface that can host content). base values reflect 4-repo dump in
    # ADR 0001 付録 A; non-base values are declared per-repo.
    has_wiki        = false
    has_projects    = true
    has_discussions = false
  }
}
