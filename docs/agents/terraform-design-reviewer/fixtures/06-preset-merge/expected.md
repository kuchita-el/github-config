# 観点 6（preset 上書き経路の一貫性）の期待出力

参照: `docs/adr/0001-repository-resource-structure.md` §1（`merge() + null 除去`）／`locals.tf:36-55`（三項演算子パターン）

## 検出条件 A（merge パターン）

### 陽性 (`positive-merge.tf.example`)

- **観点 #**: 6
- **重大度**: blocker
- **指摘文言の主旨**: ADR 0001 §1 の合成式から逸脱: (a) `repository_security_preset` 引数欠落、(b) null 除去 comprehension 欠落。ADR 通りの `merge(local.repository_security_preset, local.repository_process_preset, { for k, v in var.repositories[each.key] : k => v if v != null })` に修正すべき。

### 陰性 (`negative-merge.tf.example`)

- 期待出力: 「観点 6: ✅」（指摘なし）
- 理由: ADR 0001 §1 通りの形式。

## 検出条件 B（三項演算子パターン）

### 陽性 (`positive-ternary.tf.example`)

- **観点 #**: 6
- **重大度**: blocker
- **指摘文言の主旨**: `ovr.enforcement` 等のフォールバックが欠落。`locals.tf:36-55` の既存パターンに倣い `ovr.X != null ? ovr.X : local.base_branch_protection.X` 形式に修正すべき。

### 陰性 (`negative-ternary.tf.example`)

- 期待出力: 「観点 6: ✅」（指摘なし）
- 理由: 三項演算子で null フォールバックを保持。

## 注

検出条件 A の `repository_security_preset` / `repository_process_preset` / `repository.tf` 等は現リポに未導入。本観点 A は Issue #16/#17 で導入される PR を対象とする。検出条件 B は現リポの `locals.tf` に既に適用済み。
