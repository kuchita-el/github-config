# Managed repositories and their per-repo overrides.
# This file holds only public values (no secrets) and is committed intentionally.

github_owner = "kuchita-el"

repositories = {
  # gachanuma: the existing repo whose "main protection" ruleset is the source of
  # truth for the base preset. status check contexts are gachanuma-specific.
  gachanuma = {
    status_check_contexts       = ["lint", "typecheck", "test", "build", "e2e"]
    status_check_integration_id = 15368 # GitHub Actions
  }
}
