# Development-process-axis preset for github_repository.
# Placeholder skeleton for Issue #17. Issue #16 lays the empty locals so that
# repository.tf can write the final merge() expression now; #17 only adds values
# (no resource-block or merge-expression changes).
#
# See: docs/adr/0001-repository-resource-structure.md
#  - §決定 > 1 (motivation-axis preset split via locals)
#  - §影響 > 子Issue #17 (target attributes: allow_squash_merge, allow_merge_commit,
#    allow_rebase_merge, delete_branch_on_merge, default_branch, description,
#    homepage, topics, has_issues)
# Issue: #17

locals {
  repository_process_preset = {}
}
