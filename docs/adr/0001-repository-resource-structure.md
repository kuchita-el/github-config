# ADR 0001: `github_repository` リソースの構造

## ステータス

改訂済（2026-06-21、[#63](https://github.com/kuchita-el/github-config/issues/63)）。初版は 2026-06-20 承認済。

改訂範囲: 決定 §1（リソース構造）および §1 に紐づく根拠・代替案・影響セクション。決定 §2（topics 方針）／決定 §3（`lifecycle.ignore_changes` 範囲）／付録 A・B は変更していない。

本改訂により [ADR 0002](0002-branch-protection-preset-merge-pattern.md)（`branch_protection` の `merge()` + null 除去パターン統一、2026-06-21 承認）は superseded となる（§1「適用範囲」が `repositories` 変数全体に及び、`branch_protection` 側も同じ variable defaults パターンへ統一する方針となるため）。

## コンテキスト

親 Issue [#6](https://github.com/kuchita-el/github-config/issues/6) で `github_repository` リソースによるプリセット管理を導入するにあたり、後続の feature 子Issue（[#16](https://github.com/kuchita-el/github-config/issues/16) セキュリティ系 / [#17](https://github.com/kuchita-el/github-config/issues/17) 開発プロセス系）が依存する設計判断を spike で先行確定する必要がある。本 ADR は [Issue #15](https://github.com/kuchita-el/github-config/issues/15) の成果物として、以下3点を決定する。

1. リソース構造: `github_repository` 属性を Terraform 上でどう構造化するか
2. `topics` の SoT 化方針: 属性で管理するか、補助リソースに分離するか
3. `lifecycle.ignore_changes` 対象属性の確定範囲

判断基準は親 Issue #6 の動機軸（セキュリティリスクの横断的制御 + 開発プロセス標準化）と、管理対象4リポの現状属性差分（付録 A）に基づく。

> **現状値の取得方針**: `gh api repos/{owner}/{repo}` で各リポの属性を取得し、差分表で参照する15属性のみを ADR 内に記述する。生レスポンス JSON はリポジトリに保存しない（`security_and_analysis` 等の内部情報や取得者依存の `permissions` フィールドが含まれるため）。再取得手順は本 ADR 末尾「付録 B」参照。

### 調査の問い

1. **(1) リソース構造**: 1リソース集約管理と、設定種別ごとの分離管理、どちらが SoT として妥当か
2. **(2) 現状属性値**: 全管理対象リポ（branch-protection と同一母集団）の現状属性値はどうなっているか
3. **(3) リポ間差分**: per-repo override の必須範囲はどこか

### 管理対象リポ母集団

`terraform.tfvars` の `repositories` キー一覧（branch-protection 管理対象と同一）:

- `gachanuma`
- `github-config`
- `claude-shared-skills`
- `dependabot-triage-action`

## 決定

### 1. リソース構造: `repository.tf` 1ファイル集約 + variable defaults

> **改訂履歴**: 旧版は「案 B'（リソース1本・preset を動機軸で locals 分割）」を採用していたが、以下2点の問題が判明したため改訂した（[#63](https://github.com/kuchita-el/github-config/issues/63)）。
> - resource ブロックは Terraform 言語仕様上 `repository.tf` 1ファイルに集約する制約があり、属性変更時は `repository.tf` と動機軸ファイルの2ファイルを開く必要が生じ「動機軸の可視化」が成立しない。
> - `local.*_preset` + `merge()` / null sentinel パターンは `map(any)` 化で型安全性を喪失する。`optional(type, default)` を使えばプリセット値を variable のデフォルトとして持たせ、null チェック・merge を不要にしながら完全な型安全性を保てる。
>
> 旧採用案（案 B'）と新方針との対比は「代替案」セクションに残す。
>
> **ADR 0002 との関係**: 本改訂と並行して [ADR 0002](0002-branch-protection-preset-merge-pattern.md)（[Issue #43](https://github.com/kuchita-el/github-config/issues/43)、2026-06-21 承認）が `branch_protection` を旧 ternary パターンから `merge()` + null 除去パターンへ統一していた。本改訂が採用する `optional(type, default)` は `merge()` パターンの上位解（型安全性と合成パターン一本化を同時達成）であり、本改訂の「適用範囲」が `repositories` 変数全体に及ぶことから ADR 0002 は本改訂で **superseded** となる（ADR 0002 のステータスを Superseded へ更新済）。`branch_protection.tf` の `merge()` パターンから variable defaults への実コード移行は別 Issue で実施する。

- `github_repository` resource ブロックは `repository.tf` 1枚に集約する。preset を動機軸別ファイル（`repository_security.tf` / `repository_process.tf`）の locals に分割する旧方針（案 B'）は採用しない。
- preset 値は **`variables.tf` の `repositories` 変数のフィールドデフォルト** として `optional(type, default)` で持たせる。`local.*_preset` + `merge()` / null sentinel / ternary パターンは採用しない。
  - 例: `archived = optional(bool, false)` で preset 値（4リポ共通値）を直接デフォルト化し、resource ブロックは `var.repositories[each.key].archived` を**直接参照**する。
  - per-repo override は変数値で該当フィールドを上書きする（未指定なら型レベルでデフォルトが入る）。null センチネルおよび `merge()` 合成式は不要となる。
- `repository.tf` のレイアウト（イメージ）:
  - `resource "github_repository" "this" { for_each = var.repositories ... }` を1ファイルに集約
  - 属性値は `var.repositories[each.key].<attr>` を直接参照
  - `lifecycle { ignore_changes = [visibility, archived] }` を resource ブロック内に記述（決定 §3 参照）
- variable 型レイアウト（イメージ・`variables.tf`）:

  ```hcl
  variable "repositories" {
    type = map(object({
      visibility             = string                          # required
      archived               = optional(bool, false)
      allow_auto_merge       = optional(bool, false)
      delete_branch_on_merge = optional(bool, false)
      description            = optional(string, null)
      has_wiki               = optional(bool, false)
      # ...（残り属性も同様に optional(type, preset値) で宣言）
    }))
  }
  ```

- **適用範囲（branch protection override 含む）**: 本決定の variable defaults パターンは `repositories` 変数**全体**に適用する。現行 `branch_protection.tf` の `merge()` + null 除去パターン（ADR 0002 で確定）も同方針へ統一する（`variables.tf` 側で preset 値をデフォルト化、`branch_protection.tf` 側は `local.branch_protection_preset` / `merge()` 合成式を除去し `var.repositories[each.key].X` を直接参照）。実コード変更は本 ADR のスコープ外であり、別 Issue で実施する（`.tf` 変更は本改訂に含めない）。これにより ADR 0002 は本改訂で superseded となる。
- **既存 `branch_protection.tf` との一貫性**: 改訂後は `branch_protection.tf` の「1ファイル=1リソース種別 + variable defaults」レイアウトと同一パターンになる。動機軸別ファイル分割という独自パターンを廃止し、既存規範および Terraform 公式スタイルガイド（[#59](https://github.com/kuchita-el/github-config/issues/59)）の `locals.tf` 集約規約と整合する。

### 2. `topics` の SoT 化方針: `github_repository.topics` 属性で管理

- `github_repository.topics` 属性を Terraform の SoT とする。
- `lifecycle.ignore_changes` 対象に含めない（SoT 厳格性を優先）。
- 補助リソース `github_repository_topics` は採用しない。

### 3. `lifecycle.ignore_changes` 対象属性: `visibility` と `archived` のみ

- 保護対象: `visibility`, `archived`
- 対象外: `description`, `homepage`, `topics`, その他全属性

## 根拠

### 1. リソース構造（1ファイル集約 + variable defaults 採用）

旧版で採用した案 B'（preset を動機軸別 locals に分割）は「動機軸の SoT 可視化」を狙ったが、resource ブロックを `repository.tf` 1ファイルに集約する技術制約のもとでは、属性変更時に `repository.tf` と動機軸ファイルの2ファイルを開く必要が生じ可視化が成立しなかった。さらに `local.*_preset` + `merge()` / null sentinel パターンは merged 後が `map(any)` となり静的型チェックを喪失する欠点があった。改訂後は以下4点の根拠で「**`repository.tf` 1ファイル集約 + `optional(type, default)` による variable defaults**」を採用する。

- **型安全性の維持**: `optional(type, default)` で属性ごとに型と既定値を宣言すると、preset 値も per-repo override も同一の `map(object({...}))` 型に収まり、Terraform の型チェックが全属性に効く。`merge()` + null フィルタは merged 後が `map(any)` 化して属性名タイポや型ミスマッチを検出できなくなる問題を回避できる。
- **行数とパターンの簡潔さ**: ternary（`ovr.X != null ? ovr.X : preset.X`）は属性数に比例して行数が増えるが、variable defaults では resource ブロックが `var.repositories[each.key].X` を直接参照するだけで済む。preset 値は型宣言1行に集約される。
- **公式スタイルガイドとの整合**: Terraform 公式スタイルガイドの `locals.tf` 集約規約（[#59](https://github.com/kuchita-el/github-config/issues/59)）から逸脱しない。preset 値は variable のデフォルトとして表現され、独立した locals ファイル群を新設する必要がない。
- **既存 `branch_protection.tf` との一貫性**: `branch_protection.tf` の「1ファイル=1リソース種別」レイアウトと同型になる。改訂時に branch_protection 側も同じ variable defaults パターンへ統一する（影響セクション「既存 `branch_protection.tf` への波及」参照）ことで、リポジトリ全体で単一の構造化パターンに揃う。

動機軸の可視化は ADR 本文と Issue #6 の動機軸定義によって担保し、ファイル分割では行わない方針へ転換する。属性ごとの動機（セキュリティ / 開発プロセス）はコード上のコメントで補足してもよい。

### 2. `topics` 方針（属性管理・`ignore_changes` なし）

- **現状実態**: 4リポ全件で `topics=[]`。UI 経由での変動実績がない。補助リソース `github_repository_topics` を導入する利点（UI 変動からの保護）が現状ない。
- **SoT 厳格性**: `topics` を `ignore_changes` 対象にすると Terraform から `topics` の状態が読めなくなり、SoT としての性質を失う。親 Issue #6 の動機「セキュリティリスクの横断的制御」は `topics` には直接かからないが、「設定を SoT で担保する」という原則は維持すべき。
- **リソース定義コスト**: 補助リソース `github_repository_topics` は `github_repository` と1:1対応するため、リソース定義が倍になる。実態ベースでメリットがない以上、採用しない。

### 3. `ignore_changes` 範囲（最小: `visibility`, `archived`）

- **破壊回避の対象を絞る**: `visibility` の誤上書き（public → private、または private → public）は復旧コストが極めて高い破壊的変更（公開状態の急変による外部影響、private 化時のリンク・参照の到達不能等）。`archived` の誤上書き（false → true）は UI/API で巻き戻し可能なため復旧コスト自体は中程度だが、書き込み不能状態への遷移は運用影響が大きい（Issue/PR 作成不可、CI 失敗等）。これらは Issue #16 が明示的に `ignore_changes` 保護を要求している。
- **SoT 厳格性を優先**: `description` / `homepage` / `topics` 等の運用中変動属性も保護候補だが、保護を増やすほど SoT としての可視性が失われる。UI と Terraform の二重管理を許す方針より、UI からの変更は `terraform plan` で drift として検知される運用を選ぶ。
- **drift 検知運用**: 現状 `github_repository` 属性は Terraform 管理外で UI 由来の値がそのまま実態となっている（厳密には drift ではなく未管理状態の現状値。例: `claude-shared-skills` の `delete_branch_on_merge=true` は UI 設定由来）。#16/#17 で管理下に入ると、`description` / `homepage` / `topics` 等の UI 変更は `terraform plan` で drift として可視化され、`apply` で SoT 値へ revert される運用に切り替わる。

### 4. 現状ダンプから読み取れる事実

付録 A の差分表から、per-repo override 必須範囲は**3属性**:

- `delete_branch_on_merge`（`claude-shared-skills` のみ `true`、他は `false`）
- `description`（`github-config` のみ実値、他は `null`）
- `has_wiki`（`gachanuma`/`claude-shared-skills` は `true`、`github-config`/`dependabot-triage-action` は `false`）

`visibility` は4リポ全て `public` で実態差分はないが、Issue #16 は「per-repo 必須宣言」を要求している。これは将来の private リポ追加への備え（型レベルで宣言を強制する）であり、ADR としてもこの方針を採用する。

## 代替案

### 案 A: 単一 `*.tf` への集約（旧版で不採用 → 新方針が実質これに相当）

旧版では「属性追加時の動機軸の境界がコード上で見えなくなる」ことを理由に不採用としたが、改訂後の「1ファイル集約 + variable defaults」が実質的に案 A の構造（`repository.tf` 単一ファイル）を採る。動機軸の可視化はファイル分割では成立しないため、ADR 本文・コメント・Issue #6 の動機軸定義で補う方針に転換した。

### 案 B（不採用）: resource ブロックを2ファイルに分割

- **採用しなかった理由**: Terraform は同一アドレス（`github_repository.this`）の resource ブロックを複数ファイルに分割することを許さない（重複定義エラー）。技術制約上成立しない。
- **再採用条件**: なし。Terraform の言語仕様が変わらない限り技術的に成立しない。

### 案 B'（旧採用、改訂で不採用）: リソース1本・preset を動機軸で locals 分割

旧版で採用していたが、[#63](https://github.com/kuchita-el/github-config/issues/63) で以下の問題が判明し改訂時に不採用へ転換した。

- **動機軸の可視化が成立しない**: resource ブロックは `repository.tf` 1ファイルに集約せざるを得ないため、属性追加・変更の際は必ず `repository.tf` と動機軸ファイル（`repository_security.tf` / `repository_process.tf`）の2ファイルを開く必要がある。ファイル名と編集対象の1:1対応という設計意図が技術制約上成立しなかった。
- **`merge()` + null フィルタの型安全性喪失**: `merge()` の戻り値は `map(any)` となり、属性名タイポや型ミスマッチを Terraform の型チェックで検出できなくなる。
- **公式スタイルガイドおよび既存 `branch_protection.tf` パターンとの乖離**: Terraform 公式スタイルガイドの `locals.tf` 集約規約（[#59](https://github.com/kuchita-el/github-config/issues/59)）から逸脱し、`branch_protection.tf` の「1ファイル=1リソース種別」パターンとも不一致だった。

代替として **`optional(type, default)` による variable defaults パターン**を新採用とした（決定 §1 参照）。

- **再採用条件**: なし。技術制約と型安全性の問題が解消する見込みがない。

### 案 C: 補助リソース分離（`github_repository_topics` 等）

- **採用しなかった理由**: 現状 `topics` 実態が空で、補助リソース導入の便益（UI 変動からの隔離）が現状ない。リソース定義コストが2倍になり、`terraform plan` 出力も冗長になる。
- **再採用条件**: 将来 `topics` が UI 経由で頻繁に変更される運用に変わった場合、または `topics` を `ignore_changes` 対象にしたい運用要請が出た場合に再評価する。

## 影響

### 子Issue #16 / #17 への影響

- **#16 セキュリティ系**:
  - `repository.tf` を新設し、`resource "github_repository" "this" { for_each = var.repositories ... }` を定義する。属性値は `var.repositories[each.key].<attr>` を直接参照する（`merge()` / locals 合成は使わない）。
  - `variables.tf` の `repositories` 型にセキュリティ系属性を `optional(type, default)` で宣言する。preset 値は4リポの共通値を `default` に直接設定する。対象属性: `archived`（default: `false`）, `allow_auto_merge`（default: `false`）, `has_wiki`（default: `false`）, `has_projects`（default: `true`）, `has_discussions`（default: `false`）。差分のある `has_wiki` は per-repo override で `true` を指定する。
  - `visibility` は型レベルで required（`optional` ではない）にし、resource ブロックで `visibility = each.value.visibility` のように直接渡す。
  - `repository.tf` の resource ブロック内に `lifecycle { ignore_changes = [visibility, archived] }` を記述する。
  - `repository_security.tf` / `repository_process.tf` は**新設しない**（locals 分割を行わない）。
- **#17 開発プロセス系**:
  - `variables.tf` の `repositories` 型に開発プロセス系属性を `optional(type, default)` で追記する。対象属性: `allow_squash_merge`（default: `true`）, `allow_merge_commit`（default: `true`）, `allow_rebase_merge`（default: `true`）, `delete_branch_on_merge`（default: `false`）, `default_branch`（default: `"main"`）, `description`（default: `null`）, `homepage`（default: `null`）, `topics`（default: `[]`）, `has_issues`（default: `true`）。差分のある `delete_branch_on_merge` / `description` は per-repo override で実値を指定する。
  - `repository.tf` の resource ブロックには #16 時点で全属性参照を仕込む構成にできない場合、#17 で属性参照を追記する。`merge()` 合成式や locals 値の追記といった作業は発生しない（variable defaults に集約されるため）。
- **per-repo override**: 差分のある3属性（`delete_branch_on_merge` / `description` / `has_wiki`）を `terraform.tfvars` の対応リポエントリに追記する。preset と一致する属性は記述しない（型レベルで default が適用される）。
- **着手順序の制約**: #16 が `repository.tf` の resource ブロックと `variables.tf` のセキュリティ系属性宣言を先に配置するため、#17 は #16 のマージ後に着手する（#16 → #17 の直列依存）。

### 既存 `branch_protection.tf` への波及（範囲外、ADR 0002 を supersede）

決定 §1 の variable defaults パターンは `repositories` 変数全体に適用するため、現行 `branch_protection.tf`（ADR 0002 で確定した `merge()` + null 除去 + `contains` フィルタパターン）も同方針へ統一する必要がある。ただし本 ADR は方針宣言のみで、**実コード変更は本 ADR のスコープ外**であり別 Issue で実施する。実装時は以下を行う:

- `variables.tf` の `repositories` 型に branch protection 系属性を `optional(type, default)` で再宣言（現行は `optional(type)` のみで default が無い）し、`branch_protection.tf` の `local.branch_protection_preset` の値をそのまま default として移植する。
- `branch_protection.tf` の `local.branch_protection` for 式（`merge(local.branch_protection_preset, { for k, v in ovr : k => v if v != null && contains(...) }, { status_check_* = ... })` 構造）を全削除し、`var.repositories[each.key].X` 直接参照へ書き換える。`status_check_contexts` / `status_check_integration_id` は既に `optional` 宣言済みなので、特殊扱い（`contains` フィルタ + 第3引数明示注入）が不要になる。
- `local.branch_protection_preset` および `local.branch_protection` for 式は削除可能（`name` / `target` 等の固定値は resource ブロックに直接記述する）。

切り替えは `terraform plan` で "No changes" を確認しながら段階的に進める。実コード変更後は ADR 0002 も superseded ステータスのまま履歴として残す（削除しない）。

### import 戦略への影響

- 4リポは既に GitHub 側で稼働中のため、Terraform `import` → `terraform plan` "No changes" 収束で取り込む（破壊回避）。
- 4リポすべて差分表（付録 A）の値で `import` 後、`variables.tf` の `optional(type, default)` 既定値 + per-repo override（差分のある属性のみ `terraform.tfvars` に記述）を組めば "No changes" になる前提で実装する。
- `import` 実行は #16 で実施（`github_repository` resource ブロック導入時）。#17 は同一 resource への属性追加なので `import` 不要だが、preset 拡張後に `terraform plan` "No changes" を再確認する。

### リポジトリ名変更時の destroy リスクと `moved` ブロックによる回避

> 本節は `for_each` キー（リポ名）変更を対象とし、後述の「ロールバック可能性」節で扱うリソース構造方針変更（1ファイル集約↔locals 分割、属性管理↔補助リソース分離）に伴う `moved` 要否記述とは別の文脈である。

- **リスク**: `github_repository` リソースは `for_each = var.repositories` で各リポをキー（リポ名）単位で管理する（決定 §1）。このため `terraform.tfvars` の `repositories` キーを `"old-name"` から `"new-name"` へ書き換えると、Terraform は `github_repository.this["old-name"]` の destroy + `github_repository.this["new-name"]` の create として計画する。`github_repository` の destroy は **GitHub リポジトリ本体の削除**（Issue/PR/star/fork/release/Actions 履歴の喪失）を意味するため、何も対処せずに `apply` すると極めて破壊的な事故になる。
- **回避手順**: Terraform 1.1+ の [`moved` ブロック](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) で state アドレスのみを更新し、destroy + create を回避する。`terraform.tfvars` のキー書き換えと同じ PR で以下を追加し、`terraform plan` 出力が destroy/create ではなく state アドレスの移動（`# github_repository.this["old-name"] has moved to github_repository.this["new-name"]`）になることを確認する。

  ```hcl
  moved {
    from = github_repository.this["old-name"]
    to   = github_repository.this["new-name"]
  }
  ```

- **`moved` ブロックの永続保持制約**: **`moved` ブロックは apply 前に削除しない**。apply 前に削除すると plan が再び「`["old-name"]` の destroy + `["new-name"]` の create」として計画され、destroy 事故が再発する。apply 後の削除は本リポの root module + HCP single-state 環境では技術的には安全だが、Terraform 公式は「モジュール利用者全員が apply 済みになるまで保持を推奨」しており、将来のモジュール化・変更 audit trail を兼ねて永続保持する方針とする。`moved` ブロックはリポ名変更のたびに追記し、削除・集約の保守作業は行わない。
- **対処が必要なタイミング**: 対処が必要なのは「`github_repository` リソースが Terraform 管理下に入ったあと（[#16](https://github.com/kuchita-el/github-config/issues/16) マージ後）にリポ名を変更する場合」のみ。管理下に入る前は state にアドレスが存在しないため `moved` ブロック不要であり、GitHub UI で名前変更 → `terraform.tfvars` 更新（リポ名キーは新名で記述）で完結する。
- **機械検出**: 同一シナリオを `terraform plan` 前に検出する仕組みとして、本リポは `terraform-design-reviewer` 観点 1（[`docs/agents/terraform-design-reviewer/README.md`](../agents/terraform-design-reviewer/README.md) 観点表 1行目）を持つ。PR 内で `for_each` キーの差分があるのに対応する `moved` ブロックが無い場合、blocker として検出する。

### 新規リポ追加時の影響

- 新規リポは Terraform 経由で作成する（Issue #6 前提）。`repositories` 変数に該当リポのエントリを追加 → `terraform apply` で作成。
- override 不要（`optional(type, default)` の既定値で全てカバー）な属性のリポなら、`visibility`（required）のみ宣言で済む。

### ロールバック可能性

- 構造変更（1ファイル集約 + variable defaults ↔ 案 B' 相当の locals 分割）: `variables.tf` の `optional(type, default)` から default 値を抜き、`repository_security.tf` / `repository_process.tf` を新設して `local.*_preset` を定義、`repository.tf` の resource ブロックで `merge()` 合成式へ書き換える。型安全性を犠牲にする欠点が残るため通常はロールバック対象外。Terraform state は変わらず `moved` ブロック不要。
- 構造変更（属性管理 ↔ 案 C 補助リソース分離）: 補助リソース分離は `moved` ブロック整備 + `terraform state mv` が必要。コストは中程度。
- `topics` 方針の変更（属性管理 → ignore_changes 追加）: `lifecycle.ignore_changes` 追記のみで切り替え可能。低コスト。

---

## 付録 A: 現状属性差分表

`gh api repos/kuchita-el/{repo}` の生レスポンスから抽出した15属性 × 4リポのマトリクス。生 JSON はリポジトリに保存しない（取得手順は付録 B）。値は取得日時 2026-06-20T07:05:59Z 時点。

| 属性 | gachanuma | github-config | claude-shared-skills | dependabot-triage-action | 差分 |
|---|---|---|---|---|---|
| `visibility` | `public` | `public` | `public` | `public` | なし |
| `archived` | `false` | `false` | `false` | `false` | なし |
| `allow_auto_merge` | `false` | `false` | `false` | `false` | なし |
| `allow_squash_merge` | `true` | `true` | `true` | `true` | なし |
| `allow_merge_commit` | `true` | `true` | `true` | `true` | なし |
| `allow_rebase_merge` | `true` | `true` | `true` | `true` | なし |
| `delete_branch_on_merge` | `false` | `false` | `true` | `false` | **あり** |
| `default_branch` | `main` | `main` | `main` | `main` | なし |
| `description` | `null` | `"Terraform-managed GitHub repository settings (rulesets etc.) as IaC"` | `null` | `null` | **あり** |
| `homepage` | `null` | `null` | `null` | `null` | なし |
| `topics` | `[]` | `[]` | `[]` | `[]` | なし |
| `has_issues` | `true` | `true` | `true` | `true` | なし |
| `has_wiki` | `true` | `false` | `true` | `false` | **あり** |
| `has_projects` | `true` | `true` | `true` | `true` | なし |
| `has_discussions` | `false` | `false` | `false` | `false` | なし |

### per-repo override 必須範囲（差分あり3属性）

| 属性 | base preset 候補値 | override 必須リポ | 備考 |
|---|---|---|---|
| `delete_branch_on_merge` | `false` | `claude-shared-skills`（`true`） | 4リポ中1リポのみ `true` |
| `description` | `null` | `github-config`（実値） | 4リポ中1リポのみ実値 |
| `has_wiki` | `false` | `gachanuma`, `claude-shared-skills`（`true`） | 4リポ中2リポが `true` |

### `visibility` 別扱い

実態差分はない（全リポ `public`）が、Issue #16 方針により**型レベルで per-repo 必須宣言**とする。将来の private リポ追加への備え。

### `ignore_changes` 保護対象

| 属性 | 現状値（全リポ） | 保護理由 |
|---|---|---|
| `visibility` | `public` | 誤上書き時の復旧コスト極大（public ⇔ private、外部参照への影響） |
| `archived` | `false` | 書き込み不能状態への遷移（Issue/PR 作成不可・CI 失敗）による運用影響大。巻き戻しは可能だが影響波及が広い |

---

## 付録 B: 現状値の再取得手順

生 JSON はリポジトリに保存しないため、後続作業で属性値を再確認する場合は以下で取得する。

### 取得対象

`terraform.tfvars` の `repositories` キー一覧（branch-protection 管理対象と同一母集団）:

- `gachanuma`
- `github-config`
- `claude-shared-skills`
- `dependabot-triage-action`

### 取得経路

- 認証: `gh` CLI（PAT・token scopes `repo` を含む）
- API: `GET /repos/{owner}/{repo}`
- ※ Terraform App 認証経路（`Administration: Read & write`）は使用しない。本取得は read-only 操作

### 取得コマンド

差分表で参照する15属性 + 識別子を抽出する例:

```bash
for repo in gachanuma github-config claude-shared-skills dependabot-triage-action; do
  gh api repos/kuchita-el/$repo --jq '{
    name, visibility, archived,
    allow_auto_merge, allow_squash_merge, allow_merge_commit, allow_rebase_merge,
    delete_branch_on_merge, default_branch,
    description, homepage, topics,
    has_issues, has_wiki, has_projects, has_discussions
  }'
done
```

差分検出を自動化する例:

```bash
for attr in delete_branch_on_merge description has_wiki; do
  echo "=== $attr ==="
  for repo in gachanuma github-config claude-shared-skills dependabot-triage-action; do
    val=$(gh api repos/kuchita-el/$repo --jq ".$attr")
    echo "  $repo: $val"
  done
done
```

### 保存しない属性（露出回避）

`gh api` のフルレスポンスには以下の情報も含まれるため、生レスポンスは保存しない:

- `security_and_analysis`: 各リポの secret_scanning / dependabot_security_updates 等の有効/無効。リポオーナー以外は閲覧不可の内部設定
- `permissions`: API を叩いた authenticated user の権限（取得者依存。リポ属性ではない）
- `temp_clone_token`: 通常空だが、稀に値が入る可能性のあるシークレットフィールド
- 各種 `*_url`: GitHub API のテンプレート URL（差分判断に不要）
