# Config-driven import of the 4 pre-existing private repos for #4
# (work-abstraction / budget-baker / cody / coffeeshop).
# Temporary: delete this file after the apply imports them into state.
# README "既存リポの取り込み（import）" describes the workflow.
#
# import id for all 4 resource types below is the repository name alone
# (github_repository / github_branch_default /
# github_actions_repository_permissions / github_workflow_repository_permissions
# all use schema.ImportStatePassthroughContext keyed by repo name).
# These repos have no pre-existing Ruleset to import: private repos are not
# targeted by branch_protection.tf / tag_protection.tf (local.*_targets filters
# on visibility == "public", ADR 0004 §6), so only these 4 resources per repo
# (16 total) are imported.

import {
  to = github_repository.this["work-abstraction"]
  id = "work-abstraction"
}

import {
  to = github_branch_default.repository["work-abstraction"]
  id = "work-abstraction"
}

import {
  to = github_actions_repository_permissions.actions_permissions["work-abstraction"]
  id = "work-abstraction"
}

import {
  to = github_workflow_repository_permissions.actions_permissions["work-abstraction"]
  id = "work-abstraction"
}

import {
  to = github_repository.this["budget-baker"]
  id = "budget-baker"
}

import {
  to = github_branch_default.repository["budget-baker"]
  id = "budget-baker"
}

import {
  to = github_actions_repository_permissions.actions_permissions["budget-baker"]
  id = "budget-baker"
}

import {
  to = github_workflow_repository_permissions.actions_permissions["budget-baker"]
  id = "budget-baker"
}

import {
  to = github_repository.this["cody"]
  id = "cody"
}

import {
  to = github_branch_default.repository["cody"]
  id = "cody"
}

import {
  to = github_actions_repository_permissions.actions_permissions["cody"]
  id = "cody"
}

import {
  to = github_workflow_repository_permissions.actions_permissions["cody"]
  id = "cody"
}

import {
  to = github_repository.this["coffeeshop"]
  id = "coffeeshop"
}

import {
  to = github_branch_default.repository["coffeeshop"]
  id = "coffeeshop"
}

import {
  to = github_actions_repository_permissions.actions_permissions["coffeeshop"]
  id = "coffeeshop"
}

import {
  to = github_workflow_repository_permissions.actions_permissions["coffeeshop"]
  id = "coffeeshop"
}
