# Managed repositories and their per-repo overrides.
# This file holds only public values (no secrets) and is committed intentionally.

github_owner = "kuchita-el"

repositories = {
  # gachanuma: the existing repo whose "main protection" ruleset is the source of
  # truth for the preset. status check contexts are gachanuma-specific.
  gachanuma = {
    status_check_contexts       = ["lint", "typecheck", "test", "build", "e2e"]
    status_check_integration_id = 15368 # GitHub Actions
  }

  # github-config: self-governance (dogfooding). No CI yet (#8), so no status
  # check contexts — branch-protection preset only. Add contexts once #8 lands.
  "github-config" = {}

  # claude-shared-skills: onboarded by standardizing its pre-existing ruleset
  # (which was enforcement=disabled) to the preset. No CI → no contexts.
  # Imported via a temporary import {} block, then converged. See README.
  "claude-shared-skills" = {}

  # dependabot-triage-action: public-ized for #4 (was private). No pre-existing
  # ruleset → fresh apply. CI job "build" required.
  "dependabot-triage-action" = {
    status_check_contexts       = ["build"]
    status_check_integration_id = 15368 # GitHub Actions
  }
}
