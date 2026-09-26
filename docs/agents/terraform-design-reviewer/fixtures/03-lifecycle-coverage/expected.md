# 観点 3（lifecycle.ignore_changes 網羅性）の期待出力

参照: `docs/adr/0001-repository-resource-structure.md` §3
（保護対象の属性は評価時に reviewer が同節を読んで確定する。現時点は `visibility` と `archived`）

## 陽性ケース (`positive.tf.example`)

- **観点 #**: 3
- **重大度**: blocker
- **対象**: `github_repository.this` の `lifecycle` ブロック欠落
- **指摘文言の主旨**: ADR 0001 §3 が必須化している `visibility` と `archived` の `lifecycle.ignore_changes` が無い。`lifecycle { ignore_changes = [visibility, archived] }` を追加すべき。

## 陰性ケース (`negative.tf.example`)

- 期待出力: 「観点 3: ✅」（指摘なし）
- 理由: `lifecycle { ignore_changes = [visibility, archived] }` が ADR 0001 §3 通りに記述されている。

## 注

本フィクスチャは ADR 0001 §3 の仕様から組み立てている。現リポの `repository.tf` の `github_repository.this` は同節の保護対象を `ignore_changes` に含んでおり、本観点は発火しない。
