# #73 の取り込み用。apply 後に削除する。
# import ID はいずれもリポジトリ名のみ（github_actions_repository_permissions /
# github_workflow_repository_permissions とも import 時は
# schema.ImportStatePassthroughContext でリポ名をそのまま ID とする）。

import {
  to = github_actions_repository_permissions.actions_permissions["gachanuma"]
  id = "gachanuma"
}

import {
  to = github_workflow_repository_permissions.actions_permissions["gachanuma"]
  id = "gachanuma"
}

import {
  to = github_actions_repository_permissions.actions_permissions["github-config"]
  id = "github-config"
}

import {
  to = github_workflow_repository_permissions.actions_permissions["github-config"]
  id = "github-config"
}

import {
  to = github_actions_repository_permissions.actions_permissions["claude-shared-skills"]
  id = "claude-shared-skills"
}

import {
  to = github_workflow_repository_permissions.actions_permissions["claude-shared-skills"]
  id = "claude-shared-skills"
}

import {
  to = github_actions_repository_permissions.actions_permissions["dependabot-triage-action"]
  id = "dependabot-triage-action"
}

import {
  to = github_workflow_repository_permissions.actions_permissions["dependabot-triage-action"]
  id = "dependabot-triage-action"
}
