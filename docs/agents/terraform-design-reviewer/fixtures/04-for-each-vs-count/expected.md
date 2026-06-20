# 観点 4（for_each vs count 適切性）の期待出力

## 陽性ケース (`positive.tf.example`)

- **観点 #**: 4
- **重大度**: warning
- **対象**: `github_repository_ruleset.branch_protection` の `count = length(var.repos)`
- **指摘文言の主旨**: 要素が固有キー（リポ名）を持つので `for_each = toset(var.repos)` に変更すべき。`count` ではリストの中間要素削除でインデックス再採番が起き destroy/recreate になる。`branch_protection.tf:4-5` の `for_each = local.branch_protection` パターン参照。

## 陰性ケース (`negative.tf.example`)

- 期待出力: 「観点 4: ✅」（指摘なし）
- 理由: `for_each = local.branch_protection` 使用。

## 境界ケース (`boundary-count-one.tf.example`)

- 期待出力: 「観点 4: ✅」（指摘なし）
- 理由: `count = var.enable ? 1 : 0` の条件付き生成は慣用句として許容され、本観点では指摘しない。
