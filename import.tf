# Config-driven import of the existing default branch of the 4 managed repos.
# Temporary: delete this file after the apply imports them into state
# (Issue #17). README "既存リポの取り込み" describes the workflow.
#
# import id for github_branch_default = the repository name (single string).
# See: https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch_default#import

import {
  to = github_branch_default.repository["gachanuma"]
  id = "gachanuma"
}

import {
  to = github_branch_default.repository["github-config"]
  id = "github-config"
}

import {
  to = github_branch_default.repository["claude-shared-skills"]
  id = "claude-shared-skills"
}

import {
  to = github_branch_default.repository["dependabot-triage-action"]
  id = "dependabot-triage-action"
}
