# Temporary config-driven import blocks (CLAUDE.md §2, Issue #7).
# github_repository_vulnerability_alerts / github_repository_dependabot_security_updates
# already exist on GitHub for all 8 managed repositories (Dependabot alerts /
# security updates predate this Issue); bring them under Terraform management
# without recreating them. Import ID for both resource types is the bare
# repository name (provider docs: repository_vulnerability_alerts.html.markdown,
# repository_dependabot_security_updates.html.markdown).
#
# security_and_analysis is not imported here: it is a new attribute on the
# already-managed github_repository.this, not a separate resource, so it
# surfaces as an in-place plan diff on that existing resource instead.
#
# Delete this file after `terraform apply` succeeds and re-`plan` shows
# "No changes" (README「既存リポの取り込み（import）」手順6).

import {
  to = github_repository_vulnerability_alerts.vulnerability_alerts["gachanuma"]
  id = "gachanuma"
}

import {
  to = github_repository_vulnerability_alerts.vulnerability_alerts["github-config"]
  id = "github-config"
}

import {
  to = github_repository_vulnerability_alerts.vulnerability_alerts["claude-shared-skills"]
  id = "claude-shared-skills"
}

import {
  to = github_repository_vulnerability_alerts.vulnerability_alerts["dependabot-triage-action"]
  id = "dependabot-triage-action"
}

import {
  to = github_repository_vulnerability_alerts.vulnerability_alerts["work-abstraction"]
  id = "work-abstraction"
}

import {
  to = github_repository_vulnerability_alerts.vulnerability_alerts["budget-baker"]
  id = "budget-baker"
}

import {
  to = github_repository_vulnerability_alerts.vulnerability_alerts["cody"]
  id = "cody"
}

import {
  to = github_repository_vulnerability_alerts.vulnerability_alerts["coffeeshop"]
  id = "coffeeshop"
}

import {
  to = github_repository_dependabot_security_updates.dependabot_security_updates["gachanuma"]
  id = "gachanuma"
}

import {
  to = github_repository_dependabot_security_updates.dependabot_security_updates["github-config"]
  id = "github-config"
}

import {
  to = github_repository_dependabot_security_updates.dependabot_security_updates["claude-shared-skills"]
  id = "claude-shared-skills"
}

import {
  to = github_repository_dependabot_security_updates.dependabot_security_updates["dependabot-triage-action"]
  id = "dependabot-triage-action"
}

import {
  to = github_repository_dependabot_security_updates.dependabot_security_updates["work-abstraction"]
  id = "work-abstraction"
}

import {
  to = github_repository_dependabot_security_updates.dependabot_security_updates["budget-baker"]
  id = "budget-baker"
}

import {
  to = github_repository_dependabot_security_updates.dependabot_security_updates["cody"]
  id = "cody"
}

import {
  to = github_repository_dependabot_security_updates.dependabot_security_updates["coffeeshop"]
  id = "coffeeshop"
}
