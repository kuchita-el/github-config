# 実装プラン: Issue #20 Terraform 変更 PR で設計ベストプラクティスからの逸脱を自動検出する

## 概要

- **Issue**: #20
- **ベースブランチ**: main
- **スコープ**: Terraform 変更を伴う PR の機械的レビュアー `terraform-design-reviewer` を `.claude/agents/` 配下に新規追加し、観点 1〜8（moved/validation/lifecycle/for_each-count/ハードコード/preset 合成/App 権限境界/plan-time リスク）を網羅したレビュー定義として配置する。既存 `dev-workflow:code-reviewer` を置換せず、並列補完 reviewer として動作させる。検証はリポジトリ内に「指摘されるべき .tf 例」のフィクスチャを配置し、人手で `Agent` 経由起動 → 期待指摘の照合という目視確認スタイルで行う。
- **重要な前提**: 観点 3（`github_repository` の `lifecycle.ignore_changes`）と 観点 6（`merge() + null除去` の preset 合成）は ADR 0001 が定義する将来構造を対象とする。現リポは Issue #15/#16/#17 が未完了で `repository.tf` / `github_repository` 系統が未着手。**フィクスチャは ADR 0001 §1/§3 の仕様から組み立てる**（「既存」を参照しない）。これにより本 reviewer は **#16/#17 の実装 PR 自体のレビュー**にも活用できる位置付けとなる。

## 判断依頼

**[判断待ち] 3 件はユーザー確定済み**（2026-06-20）。以下は確定後の方針。

- **[確定] 配置先と命名 → (A) `.claude/agents/` ローカル配置**
  - `.claude/agents/terraform-design-reviewer.md` をプロジェクトローカルに配置する。Issue 本文の想定どおり。後から `dev-workflow` プラグイン化または新規プラグイン化に移行する場合は `git mv` + 起動コードの参照経路差し替えで対応可能。

- **[確定] reviewer の起動経路 → (a) 手動 Agent 起動**
  - `.tf` 差分検出時に手動で `Agent(subagent_type: "terraform-design-reviewer")` を起動する運用とする。`README.md` に手順を明記。将来 hook による自動並列起動（dev-loop Phase 2 前段）に移行する余地は残す。

- **[確定] AC5 重複指摘抑止 → (iii) 観点定義の相互排他 + 運用ルール**
  - 観点 5（ハードコード値）を「Terraform 固有のリテラル定数・環境依存値」に限定し、汎用 `code-reviewer` のコード重複観点との境界を reviewer 定義に明文化する。Task 13 の `README.md` 追記で「同主旨指摘の片方採用」を運用ルール化する。

- **[前提確認] フィクスチャ拡張子と HCP 送信制御**
  - 拡張子 `.tf.example`（または `.txt`）で配置し、`terraform validate` 評価対象外とする。**加えて、HCP リモート実行のアップロード対象から除外するため `.terraformignore` を新設し `docs/agents/` 配下を除外する**（Task 11.5）。`.terraformignore` 未設定だとリモート実行の tarball にフィクスチャが含まれる懸念（HCP は `.gitignore` を自動参照しないため）。
  - 異なる場合の影響: 拡張子の選択は表記の好み。`.terraformignore` を入れない場合、tar が無駄に肥大化し、極稀に `.tf` の誤検出に繋がる懸念がある。

- **[前提確認] App 権限境界の判定リスト導出源**
  - 観点 7 で reviewer 定義に埋め込む resource 型 × 必要 App 権限の静的テーブルは、**`integrations/github` provider 公式ドキュメント（各 resource ページの "GitHub API Token Scopes" 節）と GitHub Apps permissions reference を一次情報**として導出する。リスト全体を網羅せず「観点 7 の検出に必要な範囲」（境界外で代表的なもの＋境界内で代表的なもの）に絞る。
  - 異なる場合の影響: 動的取得は reviewer の読み取り専用原則を破る／全網羅は陳腐化リスクと保守コストが大きい。

- **[前提確認] Claude Code subagent の frontmatter 規約**
  - `.claude/agents/<name>.md` 配下の frontmatter は `name` / `description` / `model` / `color` を持ち、`Agent` ツールの `subagent_type` は **ファイルパスではなく `name` フィールドの値**で解決される。本プランでは `name: terraform-design-reviewer` を採用し、起動形は `Agent(subagent_type: "terraform-design-reviewer")` とする。
  - 異なる場合の影響: 起動形が誤りだと Task 1 完了条件の試験起動が失敗する。Task 1 で実起動確認を行うことで早期に気付ける。

## 検証方針

### テストレベル

- 本リポジトリは Terraform IaC で JavaScript/TypeScript 等の自動テストフレームワークは導入されていない。reviewer エージェントは Markdown ファイルとして配置される設定資産であり、ロジックは LLM の解釈に依存するため、**ユニット/統合/E2E の自動テストは設定しない**。
- 代替の検証方法として **フィクスチャ駆動の目視確認** を採用する:
  - 観点 1〜8 ごとに「指摘されるべき .tf 例」（陽性ケース）と「指摘されるべきでない .tf 例」（陰性ケース）を `docs/agents/terraform-design-reviewer/fixtures/` 配下に配置。
  - reviewer を `Agent(subagent_type: "terraform-design-reviewer")` で起動し、フィクスチャを入力として与え、期待される指摘（観点 #・重要度・指摘文言の主旨）が出力に含まれるかをチェックリストで確認する。
  - **LLM 出力の確率的変動**に備え、各フィクスチャは最低 2 回起動し、期待観点 # と重要度が両回で一致することを PASS 条件とする。指摘文言は「主旨判定」（人手の対照表に照らした意味的一致）とする。
  - 検証結果（実行ログと判定）は同じディレクトリの `verification.md` に記録し、PR の本文で参照する。
- フィクスチャ追加自体は `terraform validate` / `terraform plan` / HCP リモート実行に影響を与えてはならない。拡張子（`.tf.example`）と `.terraformignore` の両方で物理的に隔離する。

### 検証すべき振る舞い

- **Given** `for_each = { "old_key" = ... }` を `{ "new_key" = ... }` に変更した差分のみで `moved` ブロックがない PR
  **When** `terraform-design-reviewer` を起動する
  **Then** 観点 1 が blocker として、対象リソースアドレスと「`moved` 追加が必要」の指摘文言を含めて出力される
  **検証レベル**: 目視確認

- **Given** `var.repositories` 型に optional フィールドが追加され `validation` ブロック追加がない差分
  **When** reviewer を起動する
  **Then** 観点 2 が warning として、追加フィールドの不変条件（例: 列挙値、空でない、相互排他）を `validation` で表現することを促す指摘が出力される
  **検証レベル**: 目視確認

- **Given** ADR 0001 §3 が要求する `lifecycle.ignore_changes = [visibility, archived]` を欠いた `github_repository` を追加する差分
  **When** reviewer を起動する
  **Then** 観点 3 が blocker として、ADR 0001 §3 への参照とともに「`visibility`/`archived` を `ignore_changes` に追加せよ」の指摘が出力される
  **検証レベル**: 目視確認

- **Given** `for_each` の代わりに `count = N`（N >= 2）で複数件のリソースを生成する差分
  **When** reviewer を起動する
  **Then** 観点 4 が warning として、`count` だと中間要素の追加削除でインデックスが再採番されリソース再作成を招く旨を含む指摘が出力される（`count = 1` は指摘しない境界条件）
  **検証レベル**: 目視確認

- **Given** `resource` ブロック内に環境依存リテラル（GitHub App ID 等の整数定数、リポジトリ名固有の文字列）が直書きされ `locals`/`variables` に抽出されていない差分
  **When** reviewer を起動する
  **Then** 観点 5 が suggestion として、Terraform 固有の抽出先（`locals.tf` / `variables.tf`）と汎用コード重複との境界を明示した指摘が出力される
  **検証レベル**: 目視確認

- **Given** ADR 0001 §1 が定義する `merge(repository_security_preset, repository_process_preset, { for k,v in ... if v != null })` パターンから片方の preset を落とした差分
  **When** reviewer を起動する
  **Then** 観点 6 が blocker として、ADR 0001 §1 への参照とともに「両 preset の合成漏れ」の指摘が出力される
  **検証レベル**: 目視確認

- **Given** `branch_protection` 系で既存の三項演算子パターン（`ovr.X != null ? ovr.X : base.X`）に違反し `null` 上書きを許す差分
  **When** reviewer を起動する
  **Then** 観点 6 が blocker として、`null` フォールバックの欠落を指摘する（既存 `locals.tf` パターンも観点 6 のスコープに含むことを reviewer 定義で明示）
  **検証レベル**: 目視確認

- **Given** `github_actions_secret` または `github_repository_file` のリソース追加を含む差分
  **When** reviewer を起動する
  **Then** 観点 7 が blocker として、App スコープ（Administration RW + Metadata R）に該当 resource 型の権限が含まれない旨と「App 権限拡張は別 Issue で扱う」旨を含む指摘が出力される
  **検証レベル**: 目視確認

- **Given** HCP plan 出力テキストに `destroy` または `must be replaced` が含まれる
  **When** reviewer に diff と plan テキストの両方を渡して起動する
  **Then** 観点 8 が warning として、対象アドレスと `moved` ブロックや `import.tf` 整合の検討を促す指摘が出力される
  **検証レベル**: 目視確認

- **Given** 既存 `code-reviewer` と `terraform-design-reviewer` を同一 PR diff に対し並列起動した状況で、両者がハードコード値（観点 5 と汎用コード重複観点）に対し指摘を出した
  **When** ユーザーが統合された指摘リストを参照する
  **Then** AC5 に従い、同一行・同一主旨の指摘が二重表示されない（観点 5 のスコープを Terraform 固有定数に限定する reviewer 定義 + README.md の運用ルールで抑止）
  **検証レベル**: 目視確認

## テストケース対応表

| AC# | テストケース概要 | 観点 | 採用技法 | テストレベル |
|---|---|---|---|---|
| AC1 | 観点 1 に「検出条件」「指摘文言テンプレ」「重要度: blocker」が記載されている | 典型ケース | ディシジョンテーブル | 目視確認 |
| AC1 | 観点 2 に「検出条件」「指摘文言テンプレ」「重要度: warning」が記載されている | 典型ケース | ディシジョンテーブル | 目視確認 |
| AC1 | 観点 3 に「検出条件」「指摘文言テンプレ」「重要度: blocker」+ ADR 0001 §3 参照が記載されている | 典型ケース | ディシジョンテーブル | 目視確認 |
| AC1 | 観点 4 に「検出条件」「指摘文言テンプレ」「重要度: warning」+ 境界条件（count=1 で発火しない）が記載されている | 境界値 | 境界値分析 | 目視確認 |
| AC1 | 観点 5 に「検出条件」「指摘文言テンプレ」「重要度: suggestion」+ 汎用 reviewer との境界宣言が記載されている | 典型ケース | ディシジョンテーブル | 目視確認 |
| AC1 | 観点 6 に「検出条件」「指摘文言テンプレ」「重要度: blocker」+ ADR 0001 §1 参照 + 三項演算子パターンの並行スコープが記載されている | 組み合わせ | ディシジョンテーブル | 目視確認 |
| AC1 | 観点 7 に「検出条件」「指摘文言テンプレ」「重要度: blocker」+ resource 型×必要権限の静的テーブルが記載されている | 典型ケース | ディシジョンテーブル | 目視確認 |
| AC1 | 観点 8 に「検出条件」「指摘文言テンプレ」「重要度: warning」+ plan 未提供時の未評価扱い + `import.tf` 連携格上げ条件が記載されている | 組み合わせ | ディシジョンテーブル | 目視確認 |
| AC1 | 重要度値が blocker / warning / suggestion の3値のみで他値を含まない | 境界値 | 同値分割 | 目視確認 |
| AC2 | `for_each` キー変更のみ・`moved` ブロックなし → 観点 1 が blocker で発火 | 典型ケース | ユースケーステスト | 目視確認 |
| AC2 | リソース名変更（rename）・`moved` ブロックあり → 観点 1 は発火しない（陰性確認） | 状態遷移 | 同値分割 | 目視確認 |
| AC2 | `for_each` キーの大文字小文字のみ変更 → 観点 1 が blocker（HCL では別キー扱い） | 境界値 | 境界値分析 | 目視確認 |
| AC3 | `github_actions_secret` 追加 → 観点 7 が blocker で発火 | 異常系 | ユースケーステスト | 目視確認 |
| AC3 | `github_repository_file` 追加 → 観点 7 が blocker で発火 | 異常系 | ユースケーステスト | 目視確認 |
| AC3 | 権限範囲内の `github_repository_ruleset` 追加 → 観点 7 は発火しない（陰性確認） | 境界値 | 同値分割 | 目視確認 |
| AC4 | plan 出力に `1 to destroy` を含む → 観点 8 が warning で発火 | 典型ケース | ユースケーステスト | 目視確認 |
| AC4 | plan 出力に `must be replaced` を含む → 観点 8 が warning で発火 | 典型ケース | ユースケーステスト | 目視確認 |
| AC4 | plan 出力が `No changes` → 観点 8 は発火しない（陰性確認） | 境界値 | 境界値分析 | 目視確認 |
| AC4 | plan 出力テキストが未提供 → 観点 8 は「未評価」と明示出力 | 異常系 | 同値分割 | 目視確認 |
| AC4 | `import.tf` の import ブロックと同一アドレスが plan で `replaced` → 観点 8 が blocker に格上げ | 組み合わせ | ディシジョンテーブル | 目視確認 |
| AC5 | 観点 5（Terraform 固有ハードコード）vs `code-reviewer` の汎用コード重複の境界が reviewer 定義に明文化されている | 組み合わせ | ディシジョンテーブル | 目視確認 |
| AC5 | 両 reviewer を同一 PR diff に対し並列起動した目視結果で、同主旨指摘が単一行に統合される（README.md 運用ルールに従う） | 典型ケース | ユースケーステスト | 目視確認 |

## 実装設計

### 変更概要

**外部IO**: なし。本変更は Markdown ファイル（reviewer 定義）とフィクスチャ（`.tf.example` / `.txt`）の追加、および `.terraformignore` 新設のみ。Terraform リソース・GitHub App・HCP との実体的な接点変更はない。

**ビジネスロジック**: Terraform 設計逸脱の検出ロジックを「観点 1〜8 × 検出条件 × 指摘文言テンプレ × 重要度」のテーブル形式で reviewer 定義に記述する。ロジック実体は LLM の HCL 解釈に依存する。固定的な判定要素（App 権限境界の許容 resource 型一覧、ADR 参照先パス、汎用 reviewer との観点境界）は静的テーブルとして reviewer 定義内に埋め込む。

### データフロー

```
PR diff（git diff base...HEAD）
   + （任意）HCP plan 出力テキスト（PR コメント等から取得）
        │
        ▼
Agent(subagent_type="terraform-design-reviewer")   ← name フィールドで解決
        │  観点 1〜8 を順次評価
        ▼
レビュー結果（# / 重大度 / 観点# / ファイル:行 / 指摘 / 修正方針 のテーブル）
        │
        ▼（並列起動された場合）
既存 dev-workflow:code-reviewer の出力と統合（呼び出し元が両出力を merge、運用ルールで重複抑止）
```

### subagent_type 解決方式

- `.claude/agents/terraform-design-reviewer.md` の frontmatter `name` を `terraform-design-reviewer` とする。`Agent` ツールの `subagent_type` 引数は `name` 値で解決される（ファイルパスではない）。
- 起動形: `Agent(subagent_type: "terraform-design-reviewer", description: ..., prompt: ...)`
- 既存 `dev-workflow:<name>` 形式の plugin agent と区別され、プロジェクトローカルの subagent として登録される。

### HCP リモート実行への影響制御

- `.terraformignore` を新設し、以下を除外する:
  - `docs/agents/` 配下（フィクスチャ全般、reviewer 関連ドキュメント）
- フィクスチャは `.tf.example` 拡張子（観点 8 のみ `.txt`）とし、`terraform init/validate/plan` の評価対象外であることを二重に担保する。
- `mise.toml` 等の既存除外設定との整合は、Task 11.5 で確認する。

### 変更対象ファイル

| ファイル/モジュール | 操作 | 変更内容 |
|---|---|---|
| `.claude/agents/terraform-design-reviewer.md` | 新規 | reviewer の frontmatter（`name: terraform-design-reviewer` / `description` / `model: inherit` / `color`）と本文（姿勢・ツール制限・入力・8観点の検出ロジック・重大度分類・出力フォーマット）。汎用 `code-reviewer.md` の構造を踏襲しつつ Terraform 固有節を追加。ツールは `Read` / `Grep` / `Glob` / `Bash(git diff*)` / `Bash(git log*)` に限定 |
| `.terraformignore` | 新規 | `docs/agents/` 配下を HCP アップロード対象から除外 |
| `docs/agents/terraform-design-reviewer/README.md` | 新規 | reviewer の目的・起動方法（`Agent(subagent_type: "terraform-design-reviewer")` 例）・既存 `code-reviewer` との並列運用ガイド・観点 1〜8 サマリ・参照 ADR 一覧 |
| `docs/agents/terraform-design-reviewer/fixtures/01-moved-missing/` | 新規 | 観点 1 の陽性 (`positive.tf.example`) / 陰性 (`negative.tf.example`) + `expected.md` |
| `docs/agents/terraform-design-reviewer/fixtures/02-validation-missing/` | 新規 | 観点 2 の陽性/陰性 + `expected.md`（陰性は `variables.tf` L38 周辺の既存 `validation` ブロックパターンに準拠） |
| `docs/agents/terraform-design-reviewer/fixtures/03-lifecycle-coverage/` | 新規 | 観点 3 の陽性/陰性 + `expected.md`（**ADR 0001 §3 の仕様から作成**、現リポに `github_repository` 実装がないため一次情報は ADR 0001） |
| `docs/agents/terraform-design-reviewer/fixtures/04-for-each-vs-count/` | 新規 | 観点 4 の陽性/陰性 + `expected.md`（陰性は `branch_protection.tf` L4-12 周辺の `for_each` パターンに準拠、要素数1の境界ケースを含む） |
| `docs/agents/terraform-design-reviewer/fixtures/05-hardcoded-values/` | 新規 | 観点 5 の陽性/陰性 + `expected.md`（陽性は `terraform.tfvars` L11,L27 の `15368` を resource に直書きしたケース） |
| `docs/agents/terraform-design-reviewer/fixtures/06-preset-merge/` | 新規 | 観点 6 の陽性/陰性 + `expected.md`（**ADR 0001 §1 の `merge()` 仕様から作成**、加えて `locals.tf` L36-55 の `branch_protection` 三項演算子パターン違反も陽性ケースに含める） |
| `docs/agents/terraform-design-reviewer/fixtures/07-app-permission-boundary/` | 新規 | 観点 7 の陽性/陰性 + `expected.md`（resource 型×必要権限テーブルは Task 8 で公式ドキュメントから導出） |
| `docs/agents/terraform-design-reviewer/fixtures/08-plan-time-risk/` | 新規 | 観点 8 の陽性/陰性（`plan-positive.txt`/`plan-negative.txt`）+ `expected.md` |
| `docs/agents/terraform-design-reviewer/verification.md` | 新規 | 全フィクスチャ × reviewer 起動結果（2 回試行）の照合表 |
| `README.md` | 修正 | 「運用フロー」節に `.tf` 変更を含む PR で `terraform-design-reviewer` を `code-reviewer` と並列起動する手順・AC5 重複抑止運用ルール（同主旨指摘は片方を採用）を追記 |

### App 権限境界リスト導出（観点 7 の根拠）

- **一次情報**:
  - `integrations/github` provider 公式ドキュメント（resource ページ末尾の "GitHub API Token Scopes" 節）
  - GitHub Apps の permissions reference（Administration / Metadata / Actions / Contents 等の権限と対応 API エンドポイント）
- **採用範囲**: 観点 7 検出に必要な代表的 resource を絞る（網羅しない）:
  - **境界内（許容）**: `github_repository`, `github_repository_ruleset`, `github_repository_collaborator`, `github_team_repository`, `github_branch_default` 等（Administration RW + Metadata R で動作確認できるもの）
  - **境界外**: `github_actions_secret`, `github_actions_variable`, `github_repository_file`, `github_repository_environment`, `github_repository_dependabot_security_updates` 等（Actions RW / Contents RW / Environment RW 等の追加権限が必要）
- リスト全体の一次情報は `docs/agents/terraform-design-reviewer/README.md` に「参照元」として記録し、provider バージョン更新時の見直し起点とする。

### エラーハンドリング

- reviewer は読み取り専用のため runtime エラーは発生しない。LLM 解釈の失敗（誤検知・見落とし）への対処として、reviewer 定義に「判断に迷う場合はブロッカー側に倒す」原則（既存 `code-reviewer.md` 末尾と同じ）を明記する。
- 観点 8 で plan 出力が未提供の場合は、reviewer は警告ではなく「観点 8: 未評価（plan 出力未提供）」と総評で明示する。エラー扱いとしない。
- 観点 7 で provider が `integrations/github` 以外のリソースが含まれる場合は、reviewer は「観点 7: 対象外 provider」として未評価扱いとする。

### 新規依存ライブラリ

なし。本変更は Markdown ファイル・フィクスチャ・`.terraformignore` の追加のみで、Terraform provider・外部ライブラリの導入はない。

## タスク分解

### Task 1: reviewer 定義の骨格作成
- **ファイル**: `.claude/agents/terraform-design-reviewer.md`
- **内容**: 既存 `dev-workflow:code-reviewer` の構造（frontmatter / 姿勢 / ツール制限 / 入力 / レビュー手順 / 出力フォーマット）を踏襲した骨格を作成する。frontmatter は `name: terraform-design-reviewer` / `description: <Issue #20 の目的を 2-3 文で要約>` / `model: inherit` / `color: <未使用色>`。ツール制限は `Read` / `Grep` / `Glob` / `Bash(git diff*)` / `Bash(git log*)`。本文の「8観点」セクションは Task 2〜9 で埋める空 placeholder として配置する。
- **完了条件**: ファイルが `.claude/agents/` 配下に作成され、frontmatter が valid。`Agent(subagent_type: "terraform-design-reviewer", description: "ping", prompt: "echo hello")` 形式の試験起動で `name` 解決エラーが出ないことを確認（出力内容の正しさは Task 2 以降で検証）。
- **依存**: 判断依頼の前提確認 3 件（拡張子/HCP・App 権限境界導出源・subagent frontmatter 規約）の確認（判断待ち 3 件は確定済み）

### Task 2: 観点 1（moved ブロック不在検出）の定義追加
- **ファイル**: `.claude/agents/terraform-design-reviewer.md`
- **参照**: `branch_protection.tf` L4-12（`for_each = local.branch_protection` の既存パターン）、`locals.tf` L36-60（`for repo, ovr in var.repositories` の既存パターン）
- **内容**: 観点 1 の節を追加。検出条件: 差分でリソースアドレス（`resource "TYPE" "NAME"` の NAME）または `for_each` キーが変更されており、同一 PR 内に対応する `moved { from = ... to = ... }` ブロックが追加されていないこと。指摘文言テンプレ: 「リソース `<TYPE>.<NAME>` の `<アドレス変更|for_each キー変更>` に対し `moved` ブロックがありません。destroy/recreate を防ぐため `moved { from = "<旧>"; to = "<新>" }` を追加してください」。重要度: blocker。入出力例として、`branch_protection.tf` の `for_each` キーがリポ名から別キーに切り替わるケースを陽性、`moved` ブロックを伴うケースを陰性として簡潔に示す。
- **完了条件**: 観点 1 節に「検出条件」「指摘文言テンプレ」「重要度」「入出力例（陽性1・陰性1）」の4要素が記述されている。
- **依存**: Task 1

### Task 3: 観点 2（validation ブロック不足）の定義追加
- **ファイル**: `.claude/agents/terraform-design-reviewer.md`
- **参照**: `variables.tf` L38 周辺（既存の `validation` ブロック）
- **内容**: 観点 2 の節を追加。検出条件: `variable` ブロック新規追加または既存 `variable` への optional フィールド追加で、不変条件が暗黙に存在しうる型（`string` 列挙、`number` 範囲、`list` の空非空、相互排他フィールド）に `validation` ブロックがないこと。指摘文言テンプレと重要度（warning）、入出力例（`variables.tf` L38 周辺の既存パターンを陰性、validation 欠落を陽性）を記述。
- **完了条件**: 観点 2 節に4要素が記述され、`variables.tf` の既存 `validation` ブロックへの行範囲付き参照が含まれる。
- **依存**: Task 1

### Task 4: 観点 3（lifecycle.ignore_changes 網羅性）の定義追加
- **ファイル**: `.claude/agents/terraform-design-reviewer.md`
- **参照**: `docs/adr/0001-repository-resource-structure.md` §3（保護対象 `visibility` / `archived` の確定範囲）と「影響」節（`github_repository` の lifecycle 記述計画）
- **内容**: 観点 3 の節を追加。検出条件: `github_repository` リソースの新規追加または変更で、`lifecycle.ignore_changes` に ADR 0001 §3 で確定された保護対象（`visibility`, `archived`）が含まれないこと。**現リポには `github_repository` 実装がないため、ADR 0001 §3 を一次情報として参照リンク付きで記述する**。リソース型×保護属性の対応表（拡張余地）を reviewer 定義内に静的テーブルで保持。指摘文言テンプレと重要度（blocker）、入出力例（ADR 0001 §3 から組み立てる陽性／陰性）を記述。
- **完了条件**: 観点 3 節に4要素 + リソース型×保護属性の対応表 + ADR 0001 §3 への明示的参照がある。
- **依存**: Task 1

### Task 5: 観点 4（for_each vs count 適切性）の定義追加
- **ファイル**: `.claude/agents/terraform-design-reviewer.md`
- **参照**: `branch_protection.tf` L4-12（`for_each` パターン）
- **内容**: 観点 4 の節を追加。検出条件: 新規リソースで `count = N`（N >= 2）が使用され、要素が論理的に key を持つ（リスト要素が固有名・固有 ID を持つ）こと。`count = 1` は指摘しない（特殊ケース・境界）。指摘文言テンプレと重要度（warning）、入出力例（`branch_protection.tf` の `for_each` を陰性、`count = N` 使用例を陽性）を記述。
- **完了条件**: 観点 4 節に4要素 + 「`count = 1` なら指摘しない」境界条件の明記がある。
- **依存**: Task 1

### Task 6: 観点 5（ハードコード値の抽出提案）の定義追加
- **ファイル**: `.claude/agents/terraform-design-reviewer.md`
- **参照**: `terraform.tfvars` L11, L27（`15368` の使用箇所）、`locals.tf` 全体（locals 抽出パターンの慣習）
- **内容**: 観点 5 の節を追加。検出条件: `resource` ブロック内の属性値にリテラル（環境依存値、リテラル ID、URL、整数定数、複数箇所で反復する同値）が直書きされ、`locals` / `variables` に抽出されていないこと。汎用 `code-reviewer` の「コード重複」観点との境界として、**本観点は Terraform 固有のハードコード（環境依存値、リテラル ID、URL、整数定数等）に限定**する旨を明記する（AC5 重複抑止）。指摘文言テンプレと重要度（suggestion）、入出力例（`15368` を resource 内に直書きしたケースを陽性、`terraform.tfvars` 経由参照を陰性）を記述。
- **完了条件**: 観点 5 節に4要素 + 汎用 reviewer との境界宣言がある。
- **依存**: Task 1

### Task 7: 観点 6（preset 合成漏れ）の定義追加
- **ファイル**: `.claude/agents/terraform-design-reviewer.md`
- **参照**: `docs/adr/0001-repository-resource-structure.md` §1（`merge() + null除去` パターン）、`locals.tf` L36-55（`branch_protection` の三項演算子パターン）
- **内容**: 観点 6 の節を追加。検出条件は **2 パターン**:
  1. **`merge()` パターン（ADR 0001 §1）**: `merge(<security_preset>, <process_preset>, { for k, v in var.repositories[each.key] : k => v if v != null })` から (a) 片方の preset が欠落 (b) null 除去 comprehension が抜けて `null` 上書きを許す
  2. **三項演算子パターン（既存 `locals.tf` L36-55）**: 各属性に `ovr.X != null ? ovr.X : base.X` のフォールバックがあるべき箇所で `ovr.X` 直接代入になっており `null` 上書きを許す
  両パターンを reviewer 定義の「並行有効なフォールバック方式」として記述。指摘文言テンプレと重要度（blocker）、入出力例（ADR 0001 §1 の `merge()` パターンを陰性、片 preset 欠落を陽性／既存セレクター式を陰性、null フォールバック欠落を陽性）を記述。
- **完了条件**: 観点 6 節に4要素 + ADR 0001 §1 と `locals.tf` 三項演算子パターンへの明示参照 + 両パターンの検出条件が独立して記述されている。
- **依存**: Task 1

### Task 8: 観点 7（App 権限境界違反検出）の定義追加
- **ファイル**: `.claude/agents/terraform-design-reviewer.md`
- **参照**:
  - `README.md` の「初期セットアップ §3」「設計思想」節（App スコープ `Administration: Read and write + Metadata: Read`）
  - `/home/kuchita/.claude/projects/-home-kuchita-Development-github-config/memory/app-auth-least-privilege-policy.md`（権限境界方針メモ）
  - `integrations/github` provider 公式ドキュメント（各 resource ページの "GitHub API Token Scopes" 節）
  - GitHub Apps permissions reference（一次情報）
- **内容**: 観点 7 の節を追加。検出条件: `integrations/github` provider の resource 追加が、App スコープ（Administration RW + Metadata R）の許容範囲外であること。reviewer 定義内に **resource 型 × 必要 App 権限の静的テーブル**を埋め込む（許容範囲内: `github_repository`, `github_repository_ruleset`, `github_repository_collaborator`, `github_team_repository`, `github_branch_default` 等。境界外: `github_actions_secret`, `github_actions_variable`, `github_repository_file`, `github_repository_environment`, `github_repository_dependabot_security_updates` 等）。**テーブルの導出元（provider ドキュメント URL・GitHub Apps permissions reference）を reviewer 定義のコメントに明記**。指摘文言テンプレ: 「リソース `<TYPE>` は App 権限境界外（必要権限: `<権限名>`）。本リポジトリの App スコープは Administration RW + Metadata R に限定されている（README.md / メモリ `app-auth-least-privilege-policy.md` 参照）。権限境界の拡張は別 Issue で扱う」。重要度: blocker。
- **完了条件**: 観点 7 節に4要素 + resource 型 × 必要権限の静的テーブル + 一次情報への参照（コメント付き） + README.md / メモリへの参照記述がある。
- **依存**: Task 1

### Task 9: 観点 8（plan-time リスク検出）の定義追加
- **ファイル**: `.claude/agents/terraform-design-reviewer.md`
- **内容**: 観点 8 の節を追加。検出条件: 入力に HCP plan 出力テキストが含まれ、その中に `<N> to destroy`（N >= 1）、`# .* must be replaced`、`-/+ resource`、`forces replacement` のいずれかのパターンを検出すること。指摘文言テンプレと重要度（warning）、入出力例を記述。plan 出力未提供時は「観点 8: 未評価（plan 出力未提供）」と総評に明示する仕様を記述。`import.tf` 連携整合: PR 内に `import {}` ブロックがあり、かつ plan 出力に当該アドレスの replace が出ている場合は blocker に格上げする。
- **完了条件**: 観点 8 節に4要素 + plan 出力検出パターン4種 + plan 未提供時の未評価扱い + `import.tf` 連携の格上げ条件が記述されている。
- **依存**: Task 1

### Task 10: レビュー手順と出力フォーマットの追加
- **ファイル**: `.claude/agents/terraform-design-reviewer.md`
- **内容**: Task 2〜9 で観点を埋めた後、「レビュー手順」「重大度の分類」「出力フォーマット」節を既存 `code-reviewer.md` と同形式で追加する。差分取得は `git diff <ベースブランチ>...HEAD` の `*.tf` ファイルのみを対象とする。出力テーブルは `# / 重大度 / 観点# / ファイル:行 / 指摘内容 / 修正方針` の6列とし、既存 `code-reviewer` の出力（6観点）と統合可能な形式に揃える（AC5 統合要件）。総評セクションに各観点（1〜8）の判定サマリを含める。観点 5 と汎用コード重複の境界宣言を「観点間の境界」節として明記する。
- **完了条件**: レビュー手順と出力フォーマットが既存 `code-reviewer.md` と整合し、表のカラム構造が統一されている。「観点間の境界」節がある。
- **依存**: Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9

### Task 11.5: `.terraformignore` 新設と HCP 影響確認
- **ファイル**: `.terraformignore`（新規）
- **内容**: `docs/agents/` 配下を除外する `.terraformignore` を新設する。`terraform init` → `terraform plan -refresh-only` でフィクスチャがアップロード対象外になることを確認。`mise.toml` 等の既存除外設定との整合を確認。
- **完了条件**: `.terraformignore` が配置され、`terraform plan` 実行（または HCP run の Configuration Files タブ）でフィクスチャが送信対象外であることを目視確認。
- **依存**: Task 10（reviewer 定義骨格と独立して着手可能だが、フィクスチャ配置の前に完了させる）

### Task 11a: フィクスチャ配置（観点 1: moved 不在）
- **ファイル**: `docs/agents/terraform-design-reviewer/fixtures/01-moved-missing/{positive.tf.example, negative.tf.example, expected.md}`
- **内容**: `for_each` キー変更ありなし × `moved` ブロックありなしの組み合わせから陽性（変更あり・`moved` なし）と陰性（変更あり・`moved` あり）を最小コードで作成。`expected.md` に期待出力（観点 1 / blocker / 指摘文言の主旨）を記述。
- **完了条件**: 3 ファイル配置済み、`terraform validate` がリポジトリルートで成功。
- **依存**: Task 10, Task 11.5

### Task 11b: フィクスチャ配置（観点 2: validation 不足）
- **ファイル**: `docs/agents/terraform-design-reviewer/fixtures/02-validation-missing/{positive.tf.example, negative.tf.example, expected.md}`
- **内容**: 陰性は `variables.tf` の既存 `validation` パターンを踏襲、陽性は同等の不変条件が暗黙に存在する `variable` から `validation` を削除したケース。
- **完了条件**: 3 ファイル配置済み、`terraform validate` がリポジトリルートで成功。
- **依存**: Task 10, Task 11.5

### Task 11c: フィクスチャ配置（観点 3: lifecycle 網羅性）
- **ファイル**: `docs/agents/terraform-design-reviewer/fixtures/03-lifecycle-coverage/{positive.tf.example, negative.tf.example, expected.md}`
- **内容**: **ADR 0001 §3 の仕様（保護対象 `visibility` / `archived`）から組み立てる**。陽性は `github_repository` を `lifecycle.ignore_changes` なしで定義、陰性は ADR 0001 §3 通りの `lifecycle.ignore_changes = [visibility, archived]` を持つ定義。
- **完了条件**: 3 ファイル配置済み、ADR 0001 §3 への参照が `expected.md` に含まれる、`terraform validate` がリポジトリルートで成功。
- **依存**: Task 10, Task 11.5

### Task 11d: フィクスチャ配置（観点 4: for_each vs count）
- **ファイル**: `docs/agents/terraform-design-reviewer/fixtures/04-for-each-vs-count/{positive.tf.example, negative.tf.example, expected-count-one.md, expected.md}`
- **内容**: 陽性は `count = 3` で複数件生成、陰性は `for_each` 使用。境界ケースとして `count = 1` のフィクスチャを別ファイルで配置し「指摘されないこと」を `expected-count-one.md` に明記。
- **完了条件**: 4 ファイル配置済み、`terraform validate` がリポジトリルートで成功。
- **依存**: Task 10, Task 11.5

### Task 11e: フィクスチャ配置（観点 5: ハードコード値）
- **ファイル**: `docs/agents/terraform-design-reviewer/fixtures/05-hardcoded-values/{positive.tf.example, negative.tf.example, expected.md}`
- **内容**: 陽性は GitHub App ID `15368` を resource 内に直書き、陰性は `var.github_actions_app_id` 等を経由参照。
- **完了条件**: 3 ファイル配置済み、`terraform validate` がリポジトリルートで成功。
- **依存**: Task 10, Task 11.5

### Task 11f: フィクスチャ配置（観点 6: preset 合成）
- **ファイル**: `docs/agents/terraform-design-reviewer/fixtures/06-preset-merge/{positive-merge.tf.example, negative-merge.tf.example, positive-ternary.tf.example, negative-ternary.tf.example, expected.md}`
- **内容**: **2 パターンに対応**:
  - `merge()` パターン: 陽性は ADR 0001 §1 の合成式から片方の preset を欠落、陰性は ADR 0001 §1 通り
  - 三項演算子パターン: 陽性は `locals.tf` の `ovr.X != null ? ovr.X : base.X` を `ovr.X` 直接代入に変更、陰性は既存の三項演算子パターン
- **完了条件**: 5 ファイル配置済み、ADR 0001 §1 と `locals.tf` 該当行への参照が `expected.md` に含まれる、`terraform validate` がリポジトリルートで成功。
- **依存**: Task 10, Task 11.5

### Task 11g: フィクスチャ配置（観点 7: App 権限境界）
- **ファイル**: `docs/agents/terraform-design-reviewer/fixtures/07-app-permission-boundary/{positive-secret.tf.example, positive-file.tf.example, negative-ruleset.tf.example, expected.md}`
- **内容**: 陽性 2 種（`github_actions_secret`、`github_repository_file`）、陰性 1 種（`github_repository_ruleset`）。`expected.md` に「権限境界外／内の判定根拠」を Task 8 で導出した静的テーブルから引用。
- **完了条件**: 4 ファイル配置済み、`terraform validate` がリポジトリルートで成功。
- **依存**: Task 10, Task 11.5

### Task 11h: フィクスチャ配置（観点 8: plan-time リスク）
- **ファイル**: `docs/agents/terraform-design-reviewer/fixtures/08-plan-time-risk/{plan-positive-destroy.txt, plan-positive-replace.txt, plan-negative-nochange.txt, plan-empty.txt, expected.md}`
- **内容**: 陽性 2 種（`1 to destroy` 含む／`must be replaced` 含む）、陰性 1 種（`No changes`）、未提供ケース 1 種（空ファイル）。
- **完了条件**: 5 ファイル配置済み（`.txt` 拡張子で Terraform 評価対象外）、`expected.md` に未提供時の「観点 8: 未評価」明示出力を含む。
- **依存**: Task 10, Task 11.5

### Task 12: 検証エビデンス記録
- **ファイル**: `docs/agents/terraform-design-reviewer/verification.md`
- **内容**: 全フィクスチャ × reviewer 起動結果の照合表（観点 # / フィクスチャパス / 期待指摘 / 試行1 実出力 / 試行2 実出力 / 判定 (PASS/FAIL)）。reviewer を `Agent(subagent_type: "terraform-design-reviewer")` で起動した実ログを添付。**LLM 出力の確率的変動への対処として、各フィクスチャを最低 2 回起動し、観点 # と重要度の一致を PASS 条件とする**。指摘文言は「主旨判定」（人手の対照表で意味的一致）。
- **完了条件**: 9 観点フィクスチャ（観点 4 は count=1 境界 + 通常 = 2 行、観点 6 は 2 パターン = 2 行、観点 7 は陽性 2 種 + 陰性 = 3 行、観点 8 は陽性 2 種 + 陰性 + 未提供 = 4 行、その他は陽性/陰性 = 2 行）の全行 PASS。FAIL があれば reviewer 定義（Task 2〜9）に戻す。
- **依存**: Task 11a, 11b, 11c, 11d, 11e, 11f, 11g, 11h

### Task 13: README とユーザーガイド整備
- **ファイル**: `README.md`（修正）, `docs/agents/terraform-design-reviewer/README.md`（新規）
- **内容**:
  - `README.md`: 「運用フロー（通常の変更）」または新規節として、`.tf` 変更を含む PR では `terraform-design-reviewer` を併用すること、`code-reviewer` と並列起動する Agent 呼び出し例（`Agent(subagent_type: "terraform-design-reviewer", ...)` 形式）、両出力を統合する手順、AC5 重複抑止の運用ルール（観点境界宣言に従う・同主旨指摘は片方を採用）を記述。
  - `docs/agents/terraform-design-reviewer/README.md`: reviewer の目的・観点 1〜8 サマリ表・起動コマンド例・フィクスチャと検証エビデンスへの索引・既存 `code-reviewer` との観点境界（特に観点 5 ハードコード vs 汎用コード重複）・観点 7 静的テーブルの一次情報元（provider ドキュメント URL / GitHub Apps permissions reference）を記述。
- **完了条件**: 並列起動例が `Agent(subagent_type: "terraform-design-reviewer", ...)` 形式で記述されている。観点 7 一次情報元 URL が記録されている。
- **依存**: Task 12

## 参照ドキュメント

- `docs/adr/0001-repository-resource-structure.md` - 観点 3（lifecycle.ignore_changes 対象）と観点 6（preset 合成パターン）の一次情報。§1 が `merge() + null除去` パターン、§3 が `visibility`/`archived` の `ignore_changes` 確定範囲。
- `README.md` - 観点 7（App 権限境界）の一次情報。「初期セットアップ §3」と「設計思想」節が App スコープ（Administration RW + Metadata R）を定義。
- `/home/kuchita/.claude/projects/-home-kuchita-Development-github-config/memory/MEMORY.md` 経由のメモ `app-auth-least-privilege-policy.md` - 観点 7 の権限境界方針メモ。
- `/home/kuchita/.claude/plugins/cache/claude-shared-skills/dev-workflow/0.4.1/agents/code-reviewer.md` - reviewer 定義の format リファレンス（frontmatter・ツール制限・レビュー手順・出力フォーマット・重大度分類）。
- `/home/kuchita/.claude/plugins/cache/claude-shared-skills/dev-workflow/0.4.1/skills/dev-loop/SKILL.md` - Phase 2 セルフレビューの接続契約。並列起動の制約と統合フォーマット要件の根拠。
- `/home/kuchita/.claude/plugins/cache/claude-plugins-official/superpowers/6.0.0/skills/requesting-code-review/SKILL.md` - 現行 dev-loop が委譲する単一 reviewer dispatch 仕様。並列化が dev-workflow 外側で追加実装になる理由の一次情報。
- `branch_protection.tf` L4-12, `locals.tf` L36-60, `variables.tf` L38 周辺, `terraform.tfvars` L11/L27, `providers.tf`, `versions.tf` - 各観点の入出力例で参照する既存実装（観点 1 の `for_each` パターン、観点 2 の `validation` パターン、観点 5 の `15368` ハードコード元、観点 6 の三項演算子パターン）。
- `integrations/github` provider 公式ドキュメント（観点 7 一次情報、URL は Task 8 で記録）
- GitHub Apps permissions reference（観点 7 一次情報、URL は Task 8 で記録）
- Claude Code subagent frontmatter 規約ドキュメント（subagent_type の `name` 解決経路の参照、URL は Task 1 着手時に確認）
