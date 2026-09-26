# 観点 7（App 権限境界違反検出）の期待出力

参照: `README.md:9, 76-77`（App スコープ Administration RW + Metadata R）／ memory `app-auth-least-privilege-policy.md`

## 陽性ケース 1 (`positive-secret.tf.example`)

- **観点 #**: 7
- **重大度**: blocker
- **対象**: `github_actions_secret.deploy_token`
- **指摘文言の主旨**: `github_actions_secret` は本リポの App 権限境界外（必要権限: Actions: Secrets RW）。本リポは Administration RW + Metadata R のみを許可している。本 PR からは本リソースを削除するか、App 権限拡張を別 Issue で提案する。

## 陽性ケース 2 (`positive-file.tf.example`)

- **観点 #**: 7
- **重大度**: blocker
- **対象**: `github_repository_file.codeowners`
- **指摘文言の主旨**: `github_repository_file` は本リポの App 権限境界外（必要権限: Contents RW）。README.md「設計思想」が「Contents は意図的に付与しない」と明示しており、本観点は特に重大。

## 陰性ケース (`negative-ruleset.tf.example`)

- 期待出力: 「観点 7: ✅」（指摘なし）
- 理由: `github_repository_ruleset` は Administration RW で動作可能（既存 `branch_protection.tf` と同じ権限）。

## テーブル導出元

reviewer 定義の resource 型 × 必要 App 権限の静的テーブルは以下を一次情報とする:

- `integrations/github` provider 公式ドキュメント（各 resource ページ末尾 "GitHub API Token Scopes" 節）
- GitHub Apps permissions reference: <https://docs.github.com/en/rest/overview/permissions-required-for-github-apps>
