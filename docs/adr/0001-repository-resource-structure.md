# ADR 0001: `github_repository` リソースの構造

## ステータス

承認済（2026-06-20）

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

### 1. リソース構造: 案 B'（リソース1本・preset を動機軸で locals 分割）

- `github_repository` resource ブロックは `repository.tf` 1枚に集約する（Terraform は同一アドレスの resource ブロックを1ファイル内でアトミックに定義する制約があるため、resource ブロック自体は分割しない）。
- 動機軸ごとの base preset は **locals で2ファイルに分割**する。
  - セキュリティ系（#16）: `repository_security.tf` に `local.repository_security_preset` を定義
  - 開発プロセス系（#17）: `repository_process.tf` に `local.repository_process_preset` を定義
- `repository.tf` の resource ブロックは両 locals を `merge()` で合成し、per-repo override（`var.repositories` 経由）を上書きする形で属性を埋める。`visibility` は base preset に含めず per-repo 必須宣言とする（影響セクション #16 参照）。
- ファイルレイアウト（イメージ）:
  - `repository.tf`: `resource "github_repository" "this" { for_each = var.repositories }`（属性は locals 合成で埋まる）
  - `repository_security.tf`: `locals { repository_security_preset = { archived = ..., allow_auto_merge = ..., has_wiki = ..., has_projects = ..., has_discussions = ... } }`（`visibility` は含めない）
  - `repository_process.tf`: `locals { repository_process_preset = { allow_squash_merge = ..., allow_merge_commit = ..., allow_rebase_merge = ..., delete_branch_on_merge = ..., default_branch = ..., description = ..., homepage = ..., topics = ..., has_issues = ... } }`
- **`merge()` 合成と null 処理**: per-repo override (`var.repositories[each.key]`) は optional フィールドの未指定要素が `null` として入る map になる。`merge()` は後勝ちで `null` も採用するため、未指定 override が base preset 値を `null` で上書きしてしまう。これを避けるため、`merge()` に渡す前に **null フィールドを除去**する。例: `merge(local.repository_security_preset, local.repository_process_preset, { for k, v in var.repositories[each.key] : k => v if v != null })`。`visibility` のみ「必須」として `var.repositories[each.key].visibility` を resource ブロックで直接指定する。
- **既存 `locals.tf` パターンとの整合**: 既存の `branch_protection` は `ovr.X != null ? ovr.X : base.X` のセレクター式で属性ごとにガードしている。本構造はリポジトリ属性が15個と多く、セレクター式で書くと冗長になるため `merge()` + null 除去パターンを採用する。型安全性は `variables.tf` の optional 型定義で担保する。※ ADR 0002（[Issue #43](https://github.com/kuchita-el/github-config/issues/43)、2026-06-21）にて `branch_protection` も `merge()` + null 除去パターンへ統一済み。本記述は ADR 0001 起票時点（`branch_protection` がセレクター式だった状態）の記録。
- 既存の `branch_protection.tf` は「1ファイル=1リソース種別」のパターンだが、本構造は「1リソース種別を動機軸ごとに preset 分割し、resource ブロックは別ファイルに集約」というパターン。既存パターンの単純な踏襲ではなく、動機軸の SoT 可視化を優先した独自パターンである旨を明記する。※ ADR 0002 により `branch_protection` の合成パターンも `merge()` 系に統一され、コードベース全体で preset 合成方式が1本化された。

### 2. `topics` の SoT 化方針: `github_repository.topics` 属性で管理

- `github_repository.topics` 属性を Terraform の SoT とする。
- `lifecycle.ignore_changes` 対象に含めない（SoT 厳格性を優先）。
- 補助リソース `github_repository_topics` は採用しない。

### 3. `lifecycle.ignore_changes` 対象属性: `visibility` と `archived` のみ

- 保護対象: `visibility`, `archived`
- 対象外: `description`, `homepage`, `topics`, その他全属性

## 根拠

### 1. リソース構造（案 B' 採用）

親 Issue #6 が動機軸（セキュリティ vs 開発プロセス）で子Issue #16/#17 を分割している以上、SoT 構造もその軸を反映する方が「なぜこの属性がここに置かれているか」が読みやすい。一方、Terraform は同一 resource ブロックの複数ファイル分割を許さないため、**「resource ブロックは1ファイル集約 + preset を動機軸で locals 分割」**という構造で動機軸の可視化と技術制約を両立させる。

- **動機軸の SoT 上での可視化**: 属性名 `visibility` を変更したい開発者は `repository_security.tf` を、`description` を変更したい開発者は `repository_process.tf` を見ればよい。ファイル名と編集対象が1:1で対応する。`grep` で属性を探す際もスコープが絞れる。
- **resource ブロック責務の単一化**: `repository.tf` は preset 合成と per-repo override の機械的な合流のみを担い、属性値の「決め」は両 preset ファイルに閉じる。属性追加・変更の差分が動機軸ファイル内に局所化される。
- **影響範囲の制御**: resource ブロックは1本のため `terraform plan` / `import` / `state mv` の単位は変わらない。分割によって Terraform 操作のコストは増えない。
- **既存ファイル命名との整合**: `branch_protection.tf` は「1ファイル=1リソース種別（`github_repository_ruleset`）」のパターンだが、本構造は別パターンとなる。動機軸の SoT 可視化を優先した独自パターンであることを ADR で明示し、既存規範の単純な踏襲とは区別する。

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

### 案 A: 単一 `*.tf` への集約

- **採用しなかった理由**: `github_repository` 関連属性が15個あり、preset を全て1ファイルに書くと属性追加時の動機軸の境界がコード上で見えなくなる。「これはセキュリティ系か開発プロセス系か」を ADR を読み返さないと判断できない。
- **再採用条件**: 子Issue #16/#17 のスコープ境界が将来消滅した場合（例: 1つの動機軸に統合された場合）は案 A に moves する余地がある。`repository.tf` は resource ブロックのみ・preset は同ファイルに統合、もしくは `repository_security.tf` / `repository_process.tf` を1枚にまとめる。Terraform state は変わらないため `moved` ブロック不要、locals の物理配置を変えるだけで切り替え可能。

### 案 B（旧、不採用）: resource ブロックを2ファイルに分割

- **採用しなかった理由**: Terraform は同一アドレス（`github_repository.this`）の resource ブロックを複数ファイルに分割することを許さない（重複定義エラー）。技術制約上成立しない。本 ADR の元案として検討されたが、レビューで指摘され不採用。
- **再採用条件**: なし。Terraform の言語仕様が変わらない限り技術的に成立しない。動機軸の SoT 可視化を実現したい場合は案 B'（locals 分割）を採用する。

### 案 C: 補助リソース分離（`github_repository_topics` 等）

- **採用しなかった理由**: 現状 `topics` 実態が空で、補助リソース導入の便益（UI 変動からの隔離）が現状ない。リソース定義コストが2倍になり、`terraform plan` 出力も冗長になる。
- **再採用条件**: 将来 `topics` が UI 経由で頻繁に変更される運用に変わった場合、または `topics` を `ignore_changes` 対象にしたい運用要請が出た場合に再評価する。

## 影響

### 子Issue #16 / #17 への影響

- **#16 セキュリティ系**:
  - `repository.tf` を新設し、`resource "github_repository" "this" { for_each = var.repositories }` を定義する。属性値は `merge(local.repository_security_preset, local.repository_process_preset, { for k, v in var.repositories[each.key] : k => v if v != null })` で合成する。
  - `repository_process.tf` も #16 で空雛形として配置し、`locals { repository_process_preset = {} }` を定義する（#17 で値を埋める）。これにより `repository.tf` の `merge()` 合成式を #16 時点から最終形で書け、#17 では値の追加のみで済む。
  - `repository_security.tf` を新設し、`local.repository_security_preset` を定義する。対象属性: `archived`, `allow_auto_merge`, `has_wiki`, `has_projects`, `has_discussions`。
  - `visibility` は base preset に含めず per-repo 必須宣言とする。`var.repositories` の `visibility` は型レベルで required（optional ではない）にし、resource ブロックで `visibility = each.value.visibility` のように直接渡す。
  - `repository.tf` の resource ブロック内に `lifecycle { ignore_changes = [visibility, archived] }` を記述する。
- **#17 開発プロセス系**:
  - `repository_process.tf` の `local.repository_process_preset` に対象属性の値を埋める。対象属性: `allow_squash_merge`, `allow_merge_commit`, `allow_rebase_merge`, `delete_branch_on_merge`, `default_branch`, `description`, `homepage`, `topics`, `has_issues`。
  - `repository.tf` の resource ブロック・`merge()` 合成式・`repository_process.tf` のファイル雛形は #16 で配置済みのため、#17 では新規作成・合成式変更は不要（locals 値の追記のみ）。
- **per-repo override 型定義**: `variables.tf` の `repositories` 型に override 用 optional フィールド3個（`delete_branch_on_merge`, `description`, `has_wiki`）を追加する。`visibility` は型レベルで required にする。
- **base preset 値**: 付録 A 差分表で「差分なし」の属性は base preset に集約。base 値は4リポの共通値を採用（例: `allow_squash_merge=true`, `default_branch="main"`, `has_issues=true` 等）。
- **着手順序の制約**: #16 が `repository.tf` の resource ブロックを先に配置するため、#17 は #16 のマージ後に着手する（#16 → #17 の直列依存）。

### import 戦略への影響

- 4リポは既に GitHub 側で稼働中のため、Terraform `import` → `terraform plan` "No changes" 収束で取り込む（破壊回避）。
- 4リポすべて差分表（付録 A）の値で `import` 後 base + override を組めば "No changes" になる前提で実装する。
- `import` 実行は #16 で実施（`github_repository` resource ブロック導入時）。#17 は同一 resource への属性追加なので `import` 不要だが、preset 拡張後に `terraform plan` "No changes" を再確認する。

### 新規リポ追加時の影響

- 新規リポは Terraform 経由で作成する（Issue #6 前提）。`repositories` 変数に該当リポの override を追加 → `terraform apply` で作成。
- override 不要（base preset で全てカバー）な属性のリポなら、`visibility` のみ宣言で済む。

### ロールバック可能性

- 構造変更（A↔B'）: locals の物理配置を変えるだけ（`local.repository_security_preset` / `local.repository_process_preset` を1ファイルに統合 / 分離）。resource ブロックは元から1ファイル集約なので触らない。Terraform state は変わらず `moved` ブロック不要、`terraform plan` "No changes" のまま切り替え可能。
- 構造変更（B'↔C）: 補助リソース分離は `moved` ブロック整備 + `terraform state mv` が必要。コストは中程度。
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
