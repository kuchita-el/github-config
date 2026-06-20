# 観点 5（ハードコード値の locals/variables 抽出提案）の期待出力

## 陽性ケース (`positive.tf.example`)

- **観点 #**: 5
- **重大度**: suggestion
- **対象**: `integration_id = 15368` の直書き（2箇所）
- **指摘文言の主旨**: GitHub Actions の App ID（15368）が resource 内に直書きされている。`terraform.tfvars:11/27` で既に同値が参照されているように、`locals.tf` または `variables.tf` に抽出すべき。

## 陰性ケース (`negative.tf.example`)

- 期待出力: 「観点 5: ✅」（指摘なし）
- 理由: `15368` を `terraform.tfvars` で定義し、resource では `each.value.status_check_integration_id` で属性参照している。

## 観点間の境界（AC5 重複抑止）

本観点は **Terraform 固有のリテラル定数・環境依存値** に限定する。汎用 `code-reviewer` の「コード重複」観点（複数箇所で反復する同一ロジック）と境界が重なる場合、本観点は採用せず汎用に委ねる。
