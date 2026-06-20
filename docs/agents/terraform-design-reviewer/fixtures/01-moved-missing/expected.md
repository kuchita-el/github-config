# 観点 1（moved ブロック不在検出）の期待出力

## 陽性ケース (`positive.tf.example`)

reviewer は以下の指摘を出すべき:

- **観点 #**: 1
- **重大度**: blocker
- **対象**: `github_repository_ruleset.branch_protection` の `for_each` キー変更
- **指摘文言の主旨**: `for_each` のキースキーマが変わったが対応する `moved` ブロックがない。destroy/recreate を回避するため `moved { from = ...; to = ... }` を追加すること。

## 陰性ケース (`negative.tf.example`)

reviewer は観点 1 を発火させない:

- 期待出力: 「観点 1: ✅」（指摘なし）
- 理由: `for_each` キー変更ごとに `moved` ブロックが対応して追加されている。
