# Config-driven import for the 4 managed repos.
# Temporary: delete this file after the initial apply imports the repos into
# state (Issue #16 Task 10 / plan-issue-16). README "既存リポの取り込み" describes
# the workflow.
#
# import id for github_repository = the repository name (single string).
# See: https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository#import

import {
  to = github_repository.this["gachanuma"]
  id = "gachanuma"
}

import {
  to = github_repository.this["github-config"]
  id = "github-config"
}

import {
  to = github_repository.this["claude-shared-skills"]
  id = "claude-shared-skills"
}

import {
  to = github_repository.this["dependabot-triage-action"]
  id = "dependabot-triage-action"
}
