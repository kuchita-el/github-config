# 観点 2（validation ブロック不足）の期待出力

## 陽性ケース (`positive.tf.example`)

- **観点 #**: 2
- **重大度**: warning
- **対象**: `variable "repositories"` の `enforcement` / `allowed_merge_methods`
- **指摘文言の主旨**: 列挙値を取りうる optional フィールドが追加されたが `validation` ブロックがない。制約に反する入力を plan の前に拒否するため、`validation { condition = ...; error_message = ... }` を追加すべき。

## 陰性ケース (`negative.tf.example`)

- 期待出力: 「観点 2: ✅」（指摘なし）
- 理由: `enforcement` と `allowed_merge_methods` に対して列挙値 `validation` が追加されている。

## 期待する判定根拠

発火するケースの指摘は、観点 2 の「判定の根拠」に挙げた次の一般的な出典に基づく（リポジトリ固有の規約文書を根拠にしない）。

- Terraform 公式ドキュメント input variables（custom validation rules）: <https://developer.hashicorp.com/terraform/language/values/variables>
- Terraform 公式ドキュメント「Input variable validation」: <https://developer.hashicorp.com/terraform/language/validate>
