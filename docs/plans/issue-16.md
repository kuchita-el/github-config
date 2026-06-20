# 実装プラン: Issue #16 セキュリティ系プリセット管理（visibility / archived / has_* 等）

## 概要

- **Issue**: #16
- **ベースブランチ**: main
- **スコープ**: `github_repository` リソースを `repository.tf` に新設し、セキュリティ系 base preset（`repository_security.tf` の `local.repository_security_preset`）と per-repo override を合成して4管理対象リポを管理下に取り込む。`visibility` / `archived` には `lifecycle.ignore_changes` を設定。実装スケルトンは ADR 0001「影響 > 子Issue #16 / #17 への影響」セクションに従う。

## 判断依頼

### 確定済み（ユーザー回答済み）

- **import 戦略**: **config-driven `import {}` ブロック方式**を採用。`import.tf` に4件まとめて記述 → speculative plan で4件 no-op を一括確認 → apply → ブロック削除。Task 7-10 がこの前提。
- **AC5 検証手段**: **実 apply の HCP run ログでの実証のみ**を採用。初回 apply 成功 = 権限境界 OK と判定し、PR 本文に run ログ抜粋を貼る。追加実装（スクショ証跡 / `gh api` 自動検証）は導入しない。Task 10 / 12 がこの前提。

### 前提確認（プラン内で仮定明記、異なる場合は影響を要評価）

- **`repository_process.tf` 空雛形配置の責務境界**: `locals { repository_process_preset = {} }` のみ配置し、#17 で埋める属性キーは記述しない。`merge()` 合成式は #16 で最終形を書き、#17 では preset 値の追記のみとする。異なる場合: preset ファイルに「将来 #17 で埋める属性リスト」をコメントで添えるか否かが変わる。
- **`visibility` 型レベル required の実装方式**: `var.repositories` の object 型に `visibility = string`（optional ではない非デフォルト）として定義。terraform.tfvars 既存4リポ全件に `visibility = "public"` を明示追加する。異なる方式（`optional(string)` + validation）の場合: plan 出力・エラーメッセージの差が発生。
- **`lifecycle.ignore_changes` の構文**: `ignore_changes = [visibility, archived]` をリテラル参照で記述する仮定。Terraform は `for_each` 配下でも本構文を許容する。dynamic block 化は不要。

## 検証方針

### テストレベル

本リポジトリには Terraform テストフレームワーク（`*.tftest.hcl` 等）も Go test も導入されていない（`find` で確認済）。自動テストは導入せず、以下の手段で検証する:

- **静的検証**: `terraform fmt -check` と `terraform validate` で構文・スキーマ整合。
- **plan ベース冪等性検証**: `import {}` ブロック投入後の `terraform plan` 出力が「Plan: 4 to import, 0 to add, 0 to change, 0 to destroy.」であること、`apply` 後の `terraform plan` 再実行が "No changes" であること。これは AC3 / AC4 の直接検証。
- **drift 保護検証**: `visibility` / `archived` の UI 経由変更を `terraform plan` が差分検出しないことを目視確認(実 UI 変更は環境影響があるため、`lifecycle.ignore_changes` のリテラル記述の存在をレビューで確認する代替手段でも可)。
- **権限境界の実証**: 初回 apply を実行し、`Administration: Read & write` 権限下で全 attribute 書き込みが成功することを HCP run ログで確認（AC5）。`Contents` 等の追加権限を要求するエラーが出ないこと。

ユニット/統合/E2E テストは該当なし。Terraform プロジェクトの性質上、`terraform plan/apply` の目視確認が一次検証手段。

### 検証すべき振る舞い

- **Given** 4管理対象リポが GitHub 側で既に稼働中で各 `github_repository` 属性が現状値を持つ
  **When** `import {}` ブロックを4件記述し `terraform plan` を実行する
  **Then** `4 to import, 0 to add, 0 to change, 0 to destroy` となり、属性値の差分が出ない
  **検証レベル**: 目視確認

- **Given** `lifecycle.ignore_changes = [visibility, archived]` が resource ブロックに記述されている
  **When** GitHub UI で `archived` を `true` に変更し `terraform plan` を実行する
  **Then** `terraform plan` は当該属性の差分を表示しない（変更を無視する）
  **検証レベル**: 目視確認（drift 注入は環境影響大のため、構文存在の確認で代替可）

- **Given** per-repo override が `visibility = "public"` のみで他フィールドが省略されている
  **When** `merge(local.repository_security_preset, local.repository_process_preset, { for k, v in var.repositories[each.key] : k => v if v != null })` で属性が合成される
  **Then** override で `null` 指定された optional フィールドが base preset 値を `null` で上書きせず、base 値が保持される
  **検証レベル**: 目視確認（plan 出力の属性値で確認）

- **Given** `claude-shared-skills` のみ `has_wiki=true` が override 必須範囲（ADR 付録 A）
  **When** terraform.tfvars に `claude-shared-skills.has_wiki = true` を明示し、他リポは省略する
  **Then** plan 出力で4リポすべて期待値（`gachanuma`/`claude-shared-skills` は `true`、`github-config`/`dependabot-triage-action` は `false`）になる
  **検証レベル**: 目視確認

- **Given** GitHub App の権限が `Administration: Read & write` + `Metadata: Read` のみ
  **When** 初回 `terraform apply` を実行する
  **Then** 全属性の書き込みが成功し、追加権限要求（`Contents` 等）のエラーが出ない
  **検証レベル**: 目視確認（HCP run ログで確認）

- **Given** `apply` 後にコード変更なしで `terraform plan` を再実行
  **When** 同一 HCP workspace で plan を実行する
  **Then** "No changes. Your infrastructure matches the configuration." となる（冪等）
  **検証レベル**: 目視確認

## テストケース対応表

| AC# | テストケース概要 | 観点 | 採用技法 | テストレベル |
|---|---|---|---|---|
| AC1 | `local.repository_security_preset` に `archived` / `allow_auto_merge` / `has_wiki` / `has_projects` / `has_discussions` の5属性が定義されている | 典型ケース | ユースケーステスト | 目視確認 |
| AC1 | `local.repository_security_preset` に `visibility` が**含まれていない**（per-repo 必須宣言の徹底） | 境界値 | 境界値分析 | 目視確認 |
| AC1 | `var.repositories` の object 型で `visibility` が required（optional ではない）として宣言されている | 異常系 | 同値分割 | 目視確認 |
| AC1 | `var.repositories` の object 型で `archived` が optional（per-repo override 用） | 典型ケース | 同値分割 | 目視確認 |
| AC1 | terraform.tfvars の4リポ全件で `visibility = "public"` が明示されている | 組み合わせ | ディシジョンテーブル | 目視確認 |
| AC2 | resource `github_repository.this` 内に `lifecycle { ignore_changes = [visibility, archived] }` が記述されている | 典型ケース | ユースケーステスト | 目視確認 |
| AC2 | UI 上で `archived` を変更しても `terraform plan` が差分を出さない | 状態遷移 | 状態遷移テスト | 目視確認（注入は省略可、構文存在で代替） |
| AC2 | UI 上で `visibility` を変更しても `terraform plan` が差分を出さない | 状態遷移 | 状態遷移テスト | 目視確認（注入は省略可、構文存在で代替） |
| AC3 | `import {}` ブロック投入後の `terraform plan` が「4 to import, 0 to add, 0 to change, 0 to destroy」となる | 典型ケース | ユースケーステスト | 目視確認 |
| AC3 | `gachanuma` リポについて plan 出力に属性差分が出ない | 同値分割 | 同値分割 | 目視確認 |
| AC3 | `github-config` リポについて plan 出力に属性差分が出ない | 同値分割 | 同値分割 | 目視確認 |
| AC3 | `claude-shared-skills` リポ（差分属性 `delete_branch_on_merge=true` / `has_wiki=true` 保有）について plan 出力に属性差分が出ない | 境界値 | 境界値分析 | 目視確認 |
| AC3 | `dependabot-triage-action` リポについて plan 出力に属性差分が出ない | 同値分割 | 同値分割 | 目視確認 |
| AC4 | 初回 `terraform apply` 完了後の連続した `terraform plan` 実行で "No changes" となる | 典型ケース | ユースケーステスト | 目視確認 |
| AC4 | per-repo override 未指定フィールドが `null` で base を上書きせず保持される（`merge()` null 除去ロジックの実証） | 異常系 | ディシジョンテーブル | 目視確認（plan 属性値で確認） |
| AC5 | 初回 `terraform apply` の HCP run ログで `Administration: Read & write` 範囲外の権限要求エラーが出ない | 異常系 | 同値分割 | 目視確認 |
| AC5 | App 権限設定（GitHub UI）で `Administration: Read & write` + `Metadata: Read` 以外が付与されていない | 境界値 | 境界値分析 | 目視確認 |

## 実装設計

### 変更概要

**外部IO**:
- GitHub REST API（`PATCH /repos/{owner}/{repo}` 等）への書き込み操作。`github` provider 経由（HCP 上で App installation token を mint）。初回は `import` のため読み取りのみ、`apply` から書き込み発生。
- 既存 `branch_protection.tf` の `github_repository_ruleset` 系は無関係（本 Issue では触らない）。

**ビジネスロジック**:
- セキュリティ系5属性（`archived` / `allow_auto_merge` / `has_wiki` / `has_projects` / `has_discussions`）の base preset 値を `repository_security.tf` の locals で宣言。
- `visibility` を per-repo 必須宣言として `var.repositories` 型に required で定義。
- 属性合成ロジック: `merge(local.repository_security_preset, local.repository_process_preset, { for k, v in var.repositories[each.key] : k => v if v != null })`（ADR 0001 該当行を踏襲、null 除去で base 保護）。

### データフロー

```
terraform.tfvars (var.repositories: visibility 必須 + 差分3属性の override)
        │
        ▼
variables.tf (object 型に visibility=required + optional override 3属性)
        │
        ▼
repository_security.tf (local.repository_security_preset: セキュリティ系5属性の base 値)
repository_process.tf (local.repository_process_preset: {} 空雛形)
        │
        ▼
repository.tf
  ├─ resource "github_repository" "this" { for_each = var.repositories }
  ├─ visibility = each.value.visibility       （直接渡し、merge の対象外）
  ├─ 他属性 = merge(security_preset, process_preset, { for k,v in ovr: k=>v if v != null })
  └─ lifecycle { ignore_changes = [visibility, archived] }
        │
        ▼
GitHub API (App 認証, Administration: Read & write)
```

### エラーハンドリング

- **import 後 plan で差分が出る場合**: terraform.tfvars の override 値、または `local.repository_security_preset` の base 値を実態（ADR 付録 A 差分表）に寄せる。差分が出る属性をログで特定 → tfvars/locals 修正 → plan 再実行のループ。
- **`Administration: Read & write` 不足エラー**: 即座に apply 中止。GitHub App 権限設定を確認し、不足があれば付与 → installation 再承認。
- **per-repo override の null 取り扱いミス**: terraform.tfvars で `archived = null` 等を明示記述すると `merge()` 前の null 除去で除外されるが、混乱を避けるため tfvars では override したい値のみ記述する運用とする。`merge()` 式の `if v != null` で破壊回避は保証される。

### 新規依存ライブラリ

なし。既存 provider `integrations/github ~> 6.0`（`versions.tf`）のみ使用。

### 変更対象ファイル

| ファイル/モジュール | 操作 | 変更内容 |
|---|---|---|
| `repository.tf` | 新規 | `resource "github_repository" "this" { for_each = var.repositories }` を定義。`visibility = each.value.visibility` を直接指定。他属性は `merge()` 合成。`lifecycle { ignore_changes = [visibility, archived] }` を記述 |
| `repository_security.tf` | 新規 | `locals { repository_security_preset = { archived = ..., allow_auto_merge = ..., has_wiki = ..., has_projects = ..., has_discussions = ... } }` を定義（ADR 付録 A の base preset 候補値に従う） |
| `repository_process.tf` | 新規 | `locals { repository_process_preset = {} }` の空雛形（#17 で値を埋める。`merge()` 合成式は #16 で最終形を書く方針） |
| `variables.tf` | 修正 | `repositories` 変数の object 型に `visibility = string`（required）と `archived = optional(bool)` / `has_wiki = optional(bool)` 等のセキュリティ系 override フィールドを追加。`description` / `delete_branch_on_merge` 等の開発プロセス系フィールドは #17 で追加するが、merge ロジックは null 除去で動くため #16 では不要 |
| `terraform.tfvars` | 修正 | 既存4リポ全件に `visibility = "public"` を明示追加。`claude-shared-skills` の `has_wiki = true`、`gachanuma` の `has_wiki = true` を override として追記 |
| `import.tf` | 新規（暫定） | 4リポ分の `import {}` ブロック。リソースアドレス `github_repository.this["<repo>"]`、id は `<repo>` 単独（`github_repository` の import id 仕様）。apply 完了後に削除 |
| `README.md` | 修正 | 「アーキテクチャ」表に `repository.tf` / `repository_security.tf` / `repository_process.tf` の役割を追記。「手順: 設定種別を追加する」セクションは既存パターンと差分があるため ADR 0001 への参照を追記 |

## タスク分解

### Task 1: 作業ブランチ作成
- **ファイル**: なし（git 操作）
- **内容**: 最新 main から `feature/16-repository-security-preset` を作成し switch する（CLAUDE.md ブランチ命名規約に従う）。
- **完了条件**: `git switch -c feature/16-repository-security-preset` 成功、`git status` clean、HEAD が main 最新と一致。
- **依存**: なし

### Task 2: `variables.tf` 拡張（visibility 必須 + セキュリティ系 override 型）
- **ファイル**: `variables.tf`
- **内容**: `repositories` 変数の object 型に `visibility = string`（required・optional ではない）を追加。セキュリティ系 override 用の optional フィールド（`archived = optional(bool)`, `has_wiki = optional(bool)`, `has_projects = optional(bool)`, `has_discussions = optional(bool)`, `allow_auto_merge = optional(bool)`）を追加。既存の branch-protection 用フィールドは温存。
- **完了条件**: `terraform validate` 成功。`visibility` の必須化を未指定で意図的に違反させると validate がエラーになることを目視確認（確認後元に戻す）。
- **入出力例**: 入力 = object 型定義に `visibility = string` を追加。期待挙動 = terraform.tfvars で `visibility` 省略時に `Missing required attribute` エラー。
- **依存**: Task 1

### Task 3: `terraform.tfvars` 更新（visibility 明示 + has_wiki override 追加）
- **ファイル**: `terraform.tfvars`
- **内容**: 既存4リポ全件に `visibility = "public"` を明示追加（ADR 付録 A: 4リポ全件 `public`）。`gachanuma` と `claude-shared-skills` に `has_wiki = true` を追記（base は `false`）。`allow_auto_merge` / `has_projects` / `has_discussions` / `archived` は base 値と一致するため override 不要。`delete_branch_on_merge` / `description` の override は #17 のスコープ。
- **完了条件**: `terraform validate` 成功（Task 2 の型と整合）。`terraform fmt -check` パス。
- **入出力例**: `gachanuma = { visibility = "public", has_wiki = true, status_check_contexts = [...], status_check_integration_id = 15368 }` のように既存項目と共存。
- **依存**: Task 2

### Task 4: `repository_security.tf` 新規作成（セキュリティ系 base preset）
- **ファイル**: `repository_security.tf`
- **内容**: `locals { repository_security_preset = { archived = false, allow_auto_merge = false, has_wiki = false, has_projects = true, has_discussions = false } }` を定義。値は ADR 0001 付録 A の「差分なし」属性の共通値、および `has_wiki` の base 候補値 `false`（4リポ中2リポが `false` で多数派 + ADR 付録 A.per-repo override 必須範囲表参照）。コメントで ADR 0001 への参照と各属性のセキュリティ的意義を簡潔に記載。
- **完了条件**: `terraform validate` 成功。`terraform fmt -check` パス。属性5個が全て宣言されている（grep で確認）。`visibility` が**含まれない**こと（grep `-c visibility` で 0）。
- **入出力例**: 出力 = `local.repository_security_preset.archived` で `false` が取得可能。
- **依存**: Task 1

### Task 5: `repository_process.tf` 新規作成（空雛形）
- **ファイル**: `repository_process.tf`
- **内容**: `locals { repository_process_preset = {} }` の空雛形を配置。コメントで「#17 で属性を埋める。#16 では `merge()` 合成式を最終形で書くための雛形として配置」と明記。ADR 0001「影響 > 子Issue #17」セクションへの参照を添える。
- **完了条件**: `terraform validate` 成功。`local.repository_process_preset` が空 map として参照可能。
- **依存**: Task 1

### Task 6: `repository.tf` 新規作成（resource + merge 合成 + lifecycle）
- **ファイル**: `repository.tf`
- **内容**:
  - `resource "github_repository" "this" { for_each = var.repositories }` を宣言。
  - `name = each.key`。
  - `visibility = each.value.visibility`（merge の対象外、直接渡し）。
  - 他属性は `merge(local.repository_security_preset, local.repository_process_preset, { for k, v in var.repositories[each.key] : k => v if v != null })` の合成結果を1属性ずつ参照（`archived = local.merged[each.key].archived` のように locals 経由で展開するか、直接 `merge()` 式の中で属性参照するかは実装時の可読性で選択。ADR の例示式に合わせる）。
  - `lifecycle { ignore_changes = [visibility, archived] }` を resource ブロック内に記述。
  - コメントで ADR 0001「決定 > 1. リソース構造」「決定 > 3. ignore_changes 対象属性」への参照を添える。
- **完了条件**: `terraform validate` 成功。`terraform fmt -check` パス。`grep ignore_changes` で当該行が1本ヒット。`grep "for_each = var.repositories"` で resource ブロックが1本。
- **入出力例**: `for_each` 展開後の resource アドレスは `github_repository.this["gachanuma"]` 等4本。`visibility` のみ tfvars 直接、`archived` は base preset 由来の `false`。
- **依存**: Task 2, 4, 5

### Task 7: `import.tf` 暫定追加（config-driven import 4件）
- **ファイル**: `import.tf`
- **内容**: 4管理対象リポ分の `import {}` ブロックを記述。各ブロックは `to = github_repository.this["<repo>"]`、`id = "<repo>"`（`github_repository` の import id 仕様）。コメントで「apply 後 Task 10 で削除する暫定ブロック」と明記。
- **完了条件**: `terraform validate` 成功。4件の import ブロックが揃う（grep で `to = github_repository` の出現が4回）。
- **入出力例**: `import { to = github_repository.this["gachanuma"]; id = "gachanuma" }` を4リポ分。
- **依存**: Task 6

### Task 8: ローカル静的検証
- **ファイル**: なし（コマンド実行）
- **内容**: `terraform fmt -check` と `terraform validate` をローカル実行。`app_auth` 不足エラーが出る場合は環境変数（`GITHUB_APP_ID` / `GITHUB_APP_INSTALLATION_ID` / `GITHUB_APP_PEM_FILE`）を export した上で validate（README.md トラブルシュート参照）。
- **完了条件**: `terraform fmt -check` 終了ステータス 0。`terraform validate` `Success! The configuration is valid.` を出力。
- **依存**: Task 7

### Task 9: HCP Terraform plan 実行（import 計画の確認）
- **ファイル**: なし（HCP workspace 上で実行）
- **内容**: PR を作成し HCP Terraform の speculative plan を起動（または手元から `terraform plan` を Remote 実行）。plan 出力で `Plan: 4 to import, 0 to add, 0 to change, 0 to destroy.` を確認。属性差分が出る場合は ADR 0001 付録 A の値と照合し、`repository_security.tf` / `terraform.tfvars` を実態へ寄せる（README.md「既存リポの取り込み（import）」手順4と同じループ）。
- **完了条件**: plan 出力の最終行が `Plan: 4 to import, 0 to add, 0 to change, 0 to destroy.` であること。`change` / `add` / `destroy` がいずれも 0 であること。
- **入出力例**: 出力ログから `# github_repository.this["gachanuma"] will be imported` のような行が4件分出る。
- **依存**: Task 8

### Task 10: 初回 apply 実行 + import ブロック削除
- **ファイル**: `import.tf`（削除）
- **内容**: Task 9 で no-op を確認できたら HCP workspace で `terraform apply`。成功確認後、`import.tf` を削除し、削除後の plan が "No changes" を維持することを確認。
- **完了条件**: `apply` が `Apply complete! Resources: 4 imported, 0 added, 0 changed, 0 destroyed.` を出力。`import.tf` 削除後の `terraform plan` が `No changes. Your infrastructure matches the configuration.` を出力（AC4 冪等性確認）。HCP run ログで権限不足エラーが出ていないこと（AC5）。
- **依存**: Task 9

### Task 11: README.md 更新
- **ファイル**: `README.md`
- **内容**: 「アーキテクチャ」表に新規3ファイル（`repository.tf` / `repository_security.tf` / `repository_process.tf`）の役割を追記。「手順: 設定種別を追加する（branch protection 以外）」セクションに「ただし `github_repository` のような単一リソース複数属性の場合は ADR 0001 の動機軸 preset 分割パターンに従う」旨を追記（ADR 0001 への参照リンク）。
- **完了条件**: 該当表に3行追加されている。手順セクションに ADR 0001 へのリンクが入っている。
- **依存**: Task 10

### Task 12: PR 作成
- **ファイル**: なし（git/gh 操作）
- **内容**: 全タスクの変更をコミットし、`feature/16-repository-security-preset` を push、`gh pr create` で PR 作成。PR 本文に AC5項目のチェックリスト、ADR 0001 参照、HCP plan/apply ログ抜粋、`Administration: Read & write` のみで完結した実証ログ抜粋を含める。
- **完了条件**: PR が作成され、ベースブランチが main、CI が green、AC5項目全てがチェックリストで証跡付き。
- **依存**: Task 11

## 参照ドキュメント

- `docs/adr/0001-repository-resource-structure.md` - 本Issueの構造的前提。「決定」「影響 > 子Issue #16 / #17 への影響」「付録 A 現状属性差分表」を実装スケルトン・base 値根拠として使用。
- `README.md` - 既存リポの import 手順（`import {}` ブロック方式、Remote 実行制約）、トラブルシュート表（権限エラー対処）、PAT→App 切替・ロールバック手順。
- `docs/plans/issue-15.md` - 直前 spike のプラン（プラン形式の参考、ADR 起票プロセスの履歴）。
- [Issue #6](https://github.com/kuchita-el/github-config/issues/6) - 親 Issue。動機軸（セキュリティ + 開発プロセス）と base preset + per-repo override 方針の出所。
- [Issue #15](https://github.com/kuchita-el/github-config/issues/15) - spike 子Issue（CLOSED）。本 Issue のブロッカー解消済み。
- [Issue #17](https://github.com/kuchita-el/github-config/issues/17) - 兄弟 Issue（開発プロセス系）。本 Issue が `repository.tf` / `repository_process.tf` 空雛形を配置することで #17 の merge 式変更を不要にする直列依存関係。
