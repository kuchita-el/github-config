# ADR 0002: `branch_protection` の preset 合成を `merge()` + null除去パターンへ統一

## ステータス

**Superseded by [ADR 0001 改訂](0001-repository-resource-structure.md)（[#63](https://github.com/kuchita-el/github-config/issues/63)、2026-06-21）**

初版は同日 2026-06-21 承認済。承認直後に ADR 0001 改訂（#63）で `repositories` 変数全体を `optional(type, default)` による variable defaults パターンへ統一する方針が確定し、`branch_protection` も同方針の適用対象に含まれることが明示された。これに伴い本 ADR の「`merge()` + null除去パターンへ統一」決定は上位解（variable defaults）に置き換えられ、superseded となる。

本 ADR が解決を試みた以下2点は ADR 0001 改訂で**より強い形で達成される**:

- **合成パターンの一本化**: ADR 0001 改訂では `merge()` 自体を使わず、preset 値を `optional(type, default)` で variable に集約する。`branch_protection` と `github_repository` 系の双方が同じ「variable defaults + 直接参照」レイアウトに揃う。
- **属性追加コストの線形化回避**: 属性追加は `variables.tf` の型定義1行追加のみで済む（resource ブロック側の変更も不要）。

加えて ADR 0001 改訂が指摘した `merge()` の戻り値の `map(any)` 化による静的型チェック喪失も、`optional(type, default)` で型保証されることで解消される。

本 ADR の決定内容（`merge()` パターン）は履歴として残し削除しない。`branch_protection.tf` 実コードを variable defaults へ移行する作業は ADR 0001 改訂のスコープ外であり、別 Issue で実施する。本 ADR が定義した `status_check_*` の `contains` フィルタ + 第3引数明示注入は、移行時に `status_check_contexts = optional(list(string), [])` 宣言で代替されるため不要になる。

## コンテキスト

`branch_protection.tf` の `local.branch_protection`（effective map）は、per-repo override の各属性に対して `ovr.X != null ? ovr.X : base.X` というセレクター式を属性ごとに機械的に列挙していた（Issue #43 時点で実コード9行）。属性追加時には base preset・`variables.tf` の型・このセレクター式の3箇所を同期して変更する必要があり、属性数のスケールに対して保守コストが線形に増える構造だった。

一方、ADR 0001（[Issue #15](https://github.com/kuchita-el/github-config/issues/15)）§1 では `github_repository` 系（[#16](https://github.com/kuchita-el/github-config/issues/16)/[#17](https://github.com/kuchita-el/github-config/issues/17)）の preset 合成方式として **`merge()` + null除去パターン**を採用すると決定済みであった。ADR 0001 §1 はその際に「既存の `branch_protection` はセレクター式で記述しており、この構造を踏襲しない」と明記していた（`github_repository` の属性が15個と多く冗長を避けるための判断）。

しかし `branch_protection` も将来属性が増えれば同じ問題に直面する。また、コードベース全体で preset 合成パターンが2系統に分かれると、読み手が両方の流儀を理解する必要があり、属性追加手順が片方だけ複雑になるというデメリットが生じる。本 ADR は [Issue #43](https://github.com/kuchita-el/github-config/issues/43) の成果物として、`branch_protection` も `merge()` + null除去パターンへ統一することを決定する。

### `status_check_*` の特殊性

`branch_protection_preset` には `status_check_contexts` / `status_check_integration_id` の2キーが存在しない（これらはリポ固有の値であり、base preset に含めると全リポに同一の CI コンテキストが強制される）。素直な `merge(preset, filtered_ovr)` ではこれらが effective map に入らず `dynamic "required_status_checks"` ブロックが無効化される。

## 決定

`local.branch_protection`（effective map）の構築を `merge()` 3引数構造へ統一する:

```hcl
branch_protection = {
  for repo, ovr in var.repositories : repo => merge(
    local.branch_protection_preset,
    {
      for k, v in ovr : k => v
      if v != null && contains(keys(local.branch_protection_preset), k)
    },
    {
      status_check_contexts       = ovr.status_check_contexts
      status_check_integration_id = ovr.status_check_integration_id
    }
  )
}
```

**3引数の役割**:
1. `local.branch_protection_preset` — base 値（name/target/enforcement/boolean群/pull_request群/status_checks policy群）
2. `{ for k, v in ovr : k => v if v != null && contains(keys(preset), k) }` — null でない、かつ preset に存在するキーのみの override。`status_check_*` は `contains` フィルタによって自動的に除外される（preset に不在のキーのため）
3. `{ status_check_contexts = ..., status_check_integration_id = ... }` — preset に無いリポ固有の2キーを明示注入

この構造により、`status_check_*` が base preset に混入するリスクを `contains` フィルタで防ぎつつ、第3引数で明示的に注入することでリポ固有属性の伝播を保証する。

## 根拠

- **合成パターンの一本化**: `branch_protection` と `github_repository` 系（将来）が同一の合成方式となり、読み手はひとつの流儀を覚えるだけでよい
- **属性追加手順の単純化**: セレクター式パターンでは属性追加時に合成式の行も追加が必要だったが、`merge()` パターンでは base preset に追加するだけで合成式は変更不要
- **振る舞い不変**: 本変更は合成式の書き換えのみであり、`github_repository_ruleset.branch_protection` リソースに渡る属性値は管理対象4リポ全件で現状と完全一致する（HCP Remote Speculative Plan で `No changes` を確認する）
- **型安全性の維持**: `contains(keys(preset), k)` フィルタは preset キーの有無に基づく静的チェックであり、`coalesce` のような型不一致リスク（bool/list の誤判定）を回避する

## 代替案

### 案 A: セレクター式を維持

- **採用しなかった理由**: 属性追加時に合成式の行追加が必要で保守コストが線形増。コードベースで2系統の合成パターンが混在し続ける

### 案 B: `coalesce` を使用

- **採用しなかった理由**: `coalesce` は `null` と空文字列の区別や、`bool` の `false`・リストの空配列 `[]` を誤判定するリスクがある。型安全性の観点から不採用

### 案 C: `contains` フィルタを使わずに直接 merge

```hcl
merge(
  local.branch_protection_preset,
  { for k, v in ovr : k => v if v != null }
)
```

- **採用しなかった理由**: `ovr` の `status_check_contexts` / `status_check_integration_id` が `null` でない限り（空配列 `[]` や `null` でない値の場合）、preset に存在しないキーとして effective map に混入する。特に `status_check_contexts = []` は null でないため第2引数でそのまま入り、`status_check_integration_id = null` は除外されるという非対称な動作になる。`contains` フィルタ + 第3引数の明示注入で意図を明確にする構造を採用する

## 影響

- `branch_protection.tf` の `local.branch_protection` 構築ブロックのみ変更
- `local.branch_protection_preset`（base 値）・`github_repository_ruleset.branch_protection`（resource）は不変
- `variables.tf` の型定義は変更不要（OUT スコープ）
- Terraform state への影響なし（`moved` ブロック・`state mv` 不要）
- ADR 0001 §1 の「既存の `branch_protection` はセレクター式で…踏襲しない」旨の記述は、本 ADR で統一方針へ更新されたことを追記参照にて明示する

## ロールバック可能性

`branch_protection.tf` の `local.branch_protection` ブロックをセレクター式形式へ戻すだけで切り替え可能。Terraform state は不変のため `plan` が再び `No changes` になる。コストは低。
