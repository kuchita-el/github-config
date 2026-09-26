# 観点 6（preset 上書き経路の一貫性）の期待出力

参照: `docs/adr/0001-repository-resource-structure.md` §1（variable defaults パターン）／`branch_protection.tf:39-63`（三項演算子パターン）

## 検出条件 A（variable defaults パターン）

### 陽性 (`positive-defaults.tf.example`)

- **観点 #**: 6
- **重大度**: blocker
- **指摘文言の主旨**: ADR 0001 §1 の variable defaults パターンから逸脱: (a) locals の preset と `merge()` + null 除去で `has_wiki` / `has_discussions` を合成している、(b) `has_wiki = optional(bool)` に preset 値の default が無い、(c) `visibility` が `optional` 化されている。preset 値は `optional(<type>, <preset 値>)` で宣言し、resource から `var.repositories[each.key].<attr>` を直接参照すべき。

### 陰性 (`negative-defaults.tf.example`)

- 期待出力: 「観点 6: ✅」（指摘なし）
- 理由: ADR 0001 §1 通りの形式。`description` の default 省略は preset 値が null の属性として許容範囲。

## 検出条件 B（三項演算子パターン）

### 陽性 (`positive-ternary.tf.example`)

- **観点 #**: 6
- **重大度**: blocker
- **指摘文言の主旨**: `ovr.enforcement` 等のフォールバックが欠落。`branch_protection.tf:39-63` の既存パターンに倣い `ovr.X != null ? ovr.X : local.branch_protection_preset.X` 形式に修正すべき。

### 陰性 (`negative-ternary.tf.example`)

- 期待出力: 「観点 6: ✅」（指摘なし）
- 理由: 三項演算子で null フォールバックを保持。

## 注

検出条件 A は現リポの `repository.tf` / `variables.tf`（Issue #16 で導入）に適用済み。検出条件 B は現リポの `branch_protection.tf` に既に適用済み。
