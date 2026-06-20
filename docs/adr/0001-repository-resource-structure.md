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

### 1. リソース構造: 案 B（リソース1本・ファイル2枚分割）

- `github_repository` リソースは Terraform 上1本に集約する（属性は1リソースに集まる）。
- `*.tf` ファイルはセキュリティ系プリセット（#16）と開発プロセス系プリセット（#17）の2枚に分割する。
  - セキュリティ系: `repository_security.tf`
  - 開発プロセス系: `repository_process.tf`
- 既存の `branch_protection.tf` と命名規則を揃え、リソース種別単位でファイル分割するという既存規範に合わせる。

### 2. `topics` の SoT 化方針: `github_repository.topics` 属性で管理

- `github_repository.topics` 属性を Terraform の SoT とする。
- `lifecycle.ignore_changes` 対象に含めない（SoT 厳格性を優先）。
- 補助リソース `github_repository_topics` は採用しない。

### 3. `lifecycle.ignore_changes` 対象属性: `visibility` と `archived` のみ

- 保護対象: `visibility`, `archived`
- 対象外: `description`, `homepage`, `topics`, その他全属性

## 根拠

### 1. リソース構造（案 B 採用）

親 Issue #6 が動機軸（セキュリティ vs 開発プロセス）で子Issue #16/#17 を分割している以上、SoT 構造もその軸を反映する方が「なぜこの属性がここに置かれているか」が読みやすい。

- **既存規範との整合**: 既存の `branch_protection.tf` がリソース種別ごとに `*.tf` 分割している。`github_repository.tf` 単一にすると属性が肥大化し、`#16`/`#17` のスコープ境界がコード上見えなくなる。
- **動機軸の SoT 上での可視化**: ファイル名が「セキュリティ系設定の SoT は `repository_security.tf`」「開発プロセス系設定の SoT は `repository_process.tf`」を直接示す。`grep` で属性を探す際もスコープが絞れる。
- **影響範囲の制御**: Terraform 上ではリソース1本なので `terraform plan` / `import` / `state mv` の単位は変わらない。分割によって Terraform 操作のコストは増えない。

### 2. `topics` 方針（属性管理・`ignore_changes` なし）

- **現状実態**: 4リポ全件で `topics=[]`。UI 経由での変動実績がない。補助リソース `github_repository_topics` を導入する利点（UI 変動からの保護）が現状ない。
- **SoT 厳格性**: `topics` を `ignore_changes` 対象にすると Terraform から `topics` の状態が読めなくなり、SoT としての性質を失う。親 Issue #6 の動機「セキュリティリスクの横断的制御」は `topics` には直接かからないが、「設定を SoT で担保する」という原則は維持すべき。
- **リソース定義コスト**: 補助リソース `github_repository_topics` は `github_repository` と1:1対応するため、リソース定義が倍になる。実態ベースでメリットがない以上、採用しない。

### 3. `ignore_changes` 範囲（最小: `visibility`, `archived`）

- **破壊回避の対象を絞る**: `visibility` の誤上書き（public → private、または private → public）と `archived` の誤上書き（false → true）は復旧コストが極めて高い破壊的変更。これらは Issue #16 が明示的に `ignore_changes` 保護を要求している。
- **SoT 厳格性を優先**: `description` / `homepage` / `topics` 等の運用中変動属性も保護候補だが、保護を増やすほど SoT としての可視性が失われる。UI と Terraform の二重管理を許す方針より、UI からの変更は `terraform plan` で drift として検知される運用を選ぶ。
- **drift 検知運用**: 現状の drift（例: `claude-shared-skills` の `delete_branch_on_merge=true` が UI 設定由来か Terraform 由来か不明）も、`terraform plan` で可視化されることで運用上扱える状態になる。

### 4. 現状ダンプから読み取れる事実

付録 A の差分表から、per-repo override 必須範囲は**3属性**:

- `delete_branch_on_merge`（`claude-shared-skills` のみ `true`、他は `false`）
- `description`（`github-config` のみ実値、他は `null`）
- `has_wiki`（`gachanuma`/`claude-shared-skills` は `true`、`github-config`/`dependabot-triage-action` は `false`）

`visibility` は4リポ全て `public` で実態差分はないが、Issue #16 は「per-repo 必須宣言」を要求している。これは将来の private リポ追加への備え（型レベルで宣言を強制する）であり、ADR としてもこの方針を採用する。

## 代替案

### 案 A: 単一 `*.tf` への集約

- **採用しなかった理由**: `github_repository` 関連属性が15個あり、`branch_protection.tf` と並べたとき1ファイルあたりの行数が肥大化する。属性のスコープ境界（セキュリティ系 vs 開発プロセス系）が SoT 上見えない。
- **再採用条件**: 子Issue #16/#17 のスコープ境界が将来消滅した場合（例: 1つの動機軸に統合された場合）は案 A に moves する余地がある。Terraform 上はリソース1本のため `moved` ブロックは不要、`*.tf` 間で resource ブロックを引っ越すだけで切り替え可能。

### 案 C: 補助リソース分離（`github_repository_topics` 等）

- **採用しなかった理由**: 現状 `topics` 実態が空で、補助リソース導入の便益（UI 変動からの隔離）が現状ない。リソース定義コストが2倍になり、`terraform plan` 出力も冗長になる。
- **再採用条件**: 将来 `topics` が UI 経由で頻繁に変更される運用に変わった場合、または `topics` を `ignore_changes` 対象にしたい運用要請が出た場合に再評価する。

## 影響

### 子Issue #16 / #17 への影響

- **#16 セキュリティ系**: `repository_security.tf` に `github_repository` リソース本体を配置する。属性: `visibility`（per-repo 必須宣言）, `archived`, `allow_auto_merge`, `has_wiki`, `has_projects`, `has_discussions`。`lifecycle.ignore_changes = [visibility, archived]` をブロック内に記述する。
- **#17 開発プロセス系**: `repository_process.tf` を新設し、`github_repository` リソース本体の追加属性（マージ系3属性 / `delete_branch_on_merge` / `default_branch` / `description` / `homepage` / `topics` / `has_issues`）を記述する。
- **per-repo override 型定義**: `variables.tf` の `repositories` 型に override 用 optional フィールド3個（`delete_branch_on_merge`, `description`, `has_wiki`）を追加する。`visibility` は型レベルで required にする。
- **base preset 値**: 付録 A 差分表で「差分なし」の属性は base preset に集約。base 値は4リポの共通値を採用（例: `allow_squash_merge=true`, `default_branch="main"`, `has_issues=true` 等）。

### import 戦略への影響

- 4リポは既に GitHub 側で稼働中のため、Terraform `import` → `terraform plan` "No changes" 収束で取り込む（破壊回避）。
- 4リポすべて差分表（付録 A）の値で `import` 後 base + override を組めば "No changes" になる前提で実装する。
- `import` 実行順序は #16（`github_repository` リソース本体導入）→ #17（追加属性は同一リソースに対する属性追加なので import 不要）。

### 新規リポ追加時の影響

- 新規リポは Terraform 経由で作成する（Issue #6 前提）。`repositories` 変数に該当リポの override を追加 → `terraform apply` で作成。
- override 不要（base preset で全てカバー）な属性のリポなら、`visibility` のみ宣言で済む。

### ロールバック可能性

- 構造変更（A↔B）: ファイル分割のみのためロールバックは `*.tf` 間で resource ブロックを移動するだけ。Terraform state は変わらない。
- 構造変更（B↔C）: 補助リソース分離は `moved` ブロック整備 + `terraform state mv` が必要。コストは中程度。
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
| `visibility` | `public` | 誤上書き時の復旧コスト極大（public ⇔ private） |
| `archived` | `false` | 誤上書きでアーカイブ化（書き込み不可状態）に陥るリスク |

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
