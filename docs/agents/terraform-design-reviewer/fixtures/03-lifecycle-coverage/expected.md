# 観点 3（lifecycle.ignore_changes 網羅性）の期待出力

参照: `docs/adr/0001-repository-resource-structure.md` §3
（`visibility` と `archived` を `lifecycle.ignore_changes` 必須保護対象として確定）

## 陽性ケース (`positive.tf.example`)

- **観点 #**: 3
- **重大度**: blocker
- **対象**: `github_repository.this` の `lifecycle` ブロック欠落
- **指摘文言の主旨**: ADR 0001 §3 が必須化している `visibility` と `archived` の `lifecycle.ignore_changes` が無い。`lifecycle { ignore_changes = [visibility, archived] }` を追加すべき。

## 陰性ケース (`negative.tf.example`)

- 期待出力: 「観点 3: ✅」（指摘なし）
- 理由: `lifecycle { ignore_changes = [visibility, archived] }` が ADR 0001 §3 通りに記述されている。

## 注

現リポジトリには `github_repository` 実装が未着手（Issue #15/#16/#17 が未完了）。本フィクスチャは ADR 0001 §3 の仕様から組み立てている。Issue #16/#17 の実装 PR をレビューする際に本観点が発火する想定。
