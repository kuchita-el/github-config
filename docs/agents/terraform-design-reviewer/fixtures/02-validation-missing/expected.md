# 観点 2（validation ブロック不足）の期待出力

## 陽性ケース (`positive.tf.example`)

- **観点 #**: 2
- **重大度**: warning
- **対象**: `variable "repositories"` の `enforcement` / `allowed_merge_methods`
- **指摘文言の主旨**: 列挙値を取りうる optional フィールドが追加されたが `validation` ブロックがない。`variables.tf` の `repositories` 変数にある既存の `validation` に倣い `validation { condition = ...; error_message = ... }` を追加すべき。

## 陰性ケース (`negative.tf.example`)

- 期待出力: 「観点 2: ✅」（指摘なし）
- 理由: `enforcement` と `allowed_merge_methods` に対して列挙値 `validation` が追加されている。
