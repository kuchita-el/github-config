# Config-driven import of agent-config for #117.
# Temporary: delete this file after the apply imports it into state.
# README "手順: 新規リポを管理対象に追加する" describes the workflow.
#
# import id for all 6 resource types below is the repository name alone.
# agent-config has no pre-existing Ruleset, so the branch_protection and
# tag_protection Rulesets are created (not imported): the expected plan is
# 6 to import, 2 to add, 0 to change, 0 to destroy.

import {
  to = github_repository.this["agent-config"]
  id = "agent-config"
}

import {
  to = github_branch_default.repository["agent-config"]
  id = "agent-config"
}

import {
  to = github_actions_repository_permissions.actions_permissions["agent-config"]
  id = "agent-config"
}

import {
  to = github_workflow_repository_permissions.actions_permissions["agent-config"]
  id = "agent-config"
}

import {
  to = github_repository_vulnerability_alerts.vulnerability_alerts["agent-config"]
  id = "agent-config"
}

import {
  to = github_repository_dependabot_security_updates.dependabot_security_updates["agent-config"]
  id = "agent-config"
}
