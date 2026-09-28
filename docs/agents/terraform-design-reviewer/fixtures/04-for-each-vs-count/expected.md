# 観点 4（for_each vs count 適切性）の期待出力

## 陽性ケース (`positive.tf.example`)

- **観点 #**: 4
- **重大度**: warning
- **対象**: `github_repository_ruleset.branch_protection` の `count = length(keys(var.repositories))`
- **指摘文言の主旨**: 要素が固有キー（リポ名）を持つので `for_each = var.repositories` 等のキー指定に変更すべき。`count` ではリストの中間要素削除でインデックス再採番が起き destroy/recreate になる。

## 陰性ケース (`negative.tf.example`)

- 期待出力: 「観点 4: ✅」（指摘なし）
- 理由: `for_each = var.repositories`（リポ名キー）使用。

## 境界ケース (`boundary-count-one.tf.example`)

- 期待出力: 「観点 4: ✅」（指摘なし）
- 理由: `count = <条件> ? 1 : 0` の条件付き生成は慣用句として許容され、本観点では指摘しない。

## 期待する判定根拠

発火するケースの指摘は、観点 4 の「判定の根拠」に挙げた次の一般的な出典に基づく（リポジトリ固有の規約文書を根拠にしない）。

- Terraform 公式ドキュメント `count`（「How to choose between count and for_each」）: <https://developer.hashicorp.com/terraform/language/meta-arguments/count>
- Terraform 公式ドキュメント `for_each`: <https://developer.hashicorp.com/terraform/language/meta-arguments/for_each>
