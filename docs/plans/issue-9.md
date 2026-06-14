# 実装プラン: 認証を PAT から GitHub App へ移行

## 概要
- **Issue**: #9
- **ベースブランチ**: main
- **スコープ**: GitHub provider 認証を fine-grained PAT から GitHub App（環境変数 + 空 `app_auth {}` ブロック方式）へ移行する。コード変更は `providers.tf` の認証ブロック追加とコメント刷新、README の認証手順全面改訂に閉じる。App 作成・PEM 生成・HCP env var 差し替えは手動ステップとして明示分離する。

## 判断依頼

> **確定事項（ユーザー承認済 2026-06-14）**
> - **①切替順序**: App変数3本を追加 → コードを main マージ → plan/apply 成功確認 → その後 PAT 変数を削除（PAT 削除を最後に遅延、ロールバック余地確保）。
> - **②PAT 削除タイミング/ロールバック文書化**: PAT 削除は本番 apply 成功まで遅延、要ユーザー明示承認。ロールバック手順（`GITHUB_TOKEN` 再追加 + `app_auth {}` revert）を README に残す。
> - **環境変数方式**: HCP sensitive env var 3本 + 空 `app_auth {}` を採用（PEM の HCL 直書きは不採用）。

- **[前提確認]** 環境変数方式 vs HCL 直書き方式の選択。Remote 実行では HCP の sensitive env var（`GITHUB_APP_ID` / `GITHUB_APP_INSTALLATION_ID` / `GITHUB_APP_PEM_FILE`）+ provider 側の空 `app_auth {}` ブロックを採用する前提で計画。PEM を tfvars/HCL に書く方式は secret scanning・state 漏洩リスクで不採用。もし「App ID/installation_id は非秘匿なので HCL 直書きで PEM のみ env var」という別案を採るなら Task 3 の `app_auth {}` 内記述が変わる。

- **[判断待ち]** 二重認証回避の切替順序。env var の置換は不可逆操作（PAT 削除）を含む。標準順序は「(A) App 変数3本を先に追加 → (B) コード（`app_auth {}`）を main へマージ → (C) plan/apply 成功を確認 → (D) その後 PAT 変数 `GITHUB_TOKEN` を削除」。「A→B の間に PAT と App 変数が共存する瞬間」を許容するか、「メンテ時間帯を設けて一気に切替」かを確認したい。

- **[判断待ち]** ロールバック発動条件と手順の粒度。App で plan/apply が失敗（403 等）した場合に PAT へ戻す。PAT 変数を削除済みだと即時復旧に PAT 再発行が必要になるため、「(D) PAT 削除は App 成功を本番 apply まで確認した後に遅延させる」方針を提案。ロールバックを「コード revert + env var 復帰」のどこまで手順化して README に残すかを確認したい。

- **[前提確認]** App 権限スコープは確定済（Selected repositories / Administration: RW + Metadata: Read のみ、Contents 不付与、Issues は #5 で増分）。本計画はこれを再議論せず前提とする。`Metadata: Read` は GitHub App が他権限付与時に自動必須化される点も前提に含む。

## 検証方針

### テストレベル
本プロジェクトは Terraform/IaC でユニットテストフレームワークを持たない。自動テストは不要。理由: 変更は provider 認証の構成差し替えであり、ロジック（locals 合成・for_each 展開）を一切触らない。検証は以下のコマンド + 目視に集約する。

- **静的検証**: `mise exec -- terraform fmt -check`（整形）、`mise exec -- terraform validate`（スキーマ・構文。`app_auth {}` ブロックが provider v6 スキーマに適合するか）。
- **認証疎通検証（最重要）**: `mise exec -- terraform plan`（HCP Remote 実行）。App 認証で GitHub API へ到達し、既存 Ruleset 2件（gachanuma / github-config）に対し `No changes` が返ること。これが「App 認証成功」の一次証拠。
- **適用検証**: `mise exec -- terraform apply` が `No changes`（または意図した差分のみ）で完走すること。
- **目視確認**: HCP workspace の Variables 画面で App 変数3本が登録・PAT 変数が削除されていること。README の認証手順が App 手順に置換されていること。

### 検証すべき振る舞い
- **Given** App 認証用の env var 3本が HCP workspace に登録され provider に空認証ブロックがある **When** Remote 実行で plan を走らせる **Then** GitHub API 認証が成立し既存リソースに対し no-op（`No changes`）が返る / **検証レベル**: terraform plan（Remote）
- **Given** provider に `owner` が設定済 **When** App 認証で API 操作する **Then** `403 Resource not accessible by integration` が発生しない（owner 未指定時の既知エラーが出ない）/ **検証レベル**: terraform plan
- **Given** PAT 変数を削除し App 変数のみが残る状態 **When** plan を再実行する **Then** 認証は App のみで成立し、PAT 不在による `Required token could not be found` 等のエラーが出ない / **検証レベル**: terraform plan
- **Given** App のインストールスコープが Selected repositories で管理対象セットと一致 **When** 管理対象全リポに対し plan する **Then** いずれのリポも認証エラーなく到達できる / **検証レベル**: terraform plan
- **Given** App 認証で plan/apply が失敗した状況 **When** ロールバック手順を実行する **Then** PAT 認証構成へ復帰し plan が再び成立する / **検証レベル**: 目視確認 + terraform plan

## テストケース対応表

| AC# | テストケース概要 | 観点 | 採用技法 | テストレベル |
|---|---|---|---|---|
| AC1 | App 認証で plan が既存2リソースに no-op を返す | 典型ケース | ユースケーステスト | terraform plan |
| AC1 | App 認証で apply が成功完走する | 典型ケース | ユースケーステスト | terraform apply |
| AC1 | owner 設定済で 403 integration エラーが出ない | 異常系 | 同値分割 | terraform plan |
| AC1 | App スコープ外リポが無く全管理対象に到達 | 組み合わせ | 同値分割 | terraform plan |
| AC1 | `app_auth {}` 空ブロックが provider スキーマで通る | 境界値 | 境界値分析 | terraform validate |
| AC2 | PAT 削除後も App 単独で plan 成立 | 状態遷移 | 状態遷移テスト | terraform plan |
| AC2 | HCP workspace に `GITHUB_TOKEN` が存在しない | 状態遷移 | ユースケーステスト | 目視確認 |
| AC2 | PEM がリポにコミットされていない | 異常系 | ユースケーステスト | 目視確認 |
| AC3 | README 認証セクションが App 手順へ更新済 | 典型ケース | ユースケーステスト | 目視確認 |
| AC3 | README トラブルシュート表が App 起因エラーに更新 | 組み合わせ | ディシジョンテーブル | 目視確認 |
| 全 | ロールバック手順で PAT 構成へ復帰可能 | 状態遷移 | 状態遷移テスト | 目視確認 + terraform plan |

## 実装設計

### 変更概要（外部IO / ビジネスロジック）
- **外部IO**: GitHub API への認証方式が PAT（`GITHUB_TOKEN`）から GitHub App（`GITHUB_APP_ID` / `GITHUB_APP_INSTALLATION_ID` / `GITHUB_APP_PEM_FILE`）へ変わる。`GITHUB_APP_PEM_FILE` は PEM の「内容」を渡す（パスではない）。
- **ビジネスロジック**: 変更なし。locals 合成・branch_protection の for_each 展開・variables 型定義は一切触らない。認証は provider 層に閉じる。
- **構成**: `providers.tf` に空の `app_auth {}` ブロックを追加。env var 名は provider v6 が自動認識するため、ブロック内に値は書かない（Remote 実行で HCP が env var を注入）。

### データフロー
```
HCP workspace sensitive env vars
  GITHUB_APP_ID / GITHUB_APP_INSTALLATION_ID / GITHUB_APP_PEM_FILE(=PEM内容)
        │ Remote 実行時に注入
        ▼
provider "github" { owner = var.github_owner; app_auth {} }
        │ App installation token を内部生成
        ▼
GitHub API（Selected repos: gachanuma / github-config に Administration:RW）
```
旧フロー（`GITHUB_TOKEN`=PAT）はこの env var 差し替えで置換される。

### エラーハンドリング
- `403 Resource not accessible by integration` → owner 未設定 or App 権限/インストール不足。owner は設定済のため主に権限・スコープ起因。
- `Required token could not be found` 系 → App 変数未登録 or `app_auth {}` ブロック欠落。
- ロールバック: App 変数を残したまま `GITHUB_TOKEN`（PAT）を再追加し、`providers.tf` の `app_auth {}` を revert すれば PAT 認証へ復帰（provider は token env var にフォールバック）。

### 変更対象ファイル
| ファイル/モジュール | 操作 | 変更内容 |
|---|---|---|
| `providers.tf` | 変更 | `provider "github"` に空 `app_auth {}` ブロック追加。認証コメントを PAT 説明から App 説明（env var 3本 + Remote 注入 + PEM は内容渡し）へ刷新 |
| `README.md` | 変更 | 認証種別・アーキ図の「PAT 認証」・providers.tf 行・手順3「PAT 発行」→「App 作成・インストール・PEM 生成」・手順4「PAT 登録」→「App 変数3本登録」・トラブルシュート表（403/token 行）・スコープ外の「App 移行予定」記述を更新 |
| `.gitignore` | 変更（追加） | `*.pem` を ignore に追加（PEM 誤コミットの多層防御。push protection に加えローカルでも遮断） |
| HCP workspace 変数（コード外） | 手動 | sensitive env var を PAT から App 3本へ差し替え |
| GitHub App（コード外） | 手動 | App 作成・権限設定・Selected repos インストール・PEM 生成 |

## タスク分解

### Task 1: 作業ブランチ作成
- **ファイル**: なし（git 操作）
- **内容**: 最新 main から `feature/9-github-app-auth` を作成。
- **完了条件**: ブランチ上で `git status` clean、HEAD が main 最新。
- **依存**: なし

### Task 2: GitHub App の作成・インストール・PEM 生成【手動操作】
- **ファイル**: なし（GitHub UI 操作）
- **内容**: GitHub UI で App を新規作成。権限は確定方針どおり Administration: Read and write + Metadata: Read のみ（Contents・Issues は付与しない）。インストールは Selected repositories で管理対象セット（gachanuma / github-config）のみ。App の private key（PEM）を生成しダウンロード。発行された App ID と installation ID を控える。PEM はローカルの一時安全領域にのみ保持し、リポジトリには絶対に置かない。
- **完了条件**: App ID / installation ID / PEM 内容の3点が手元に揃う。インストール対象が管理対象2リポと一致。権限が Administration:RW + Metadata:Read のみ。
- **依存**: なし（Task 1 と並行可）

### Task 3: providers.tf に App 認証ブロックを追加
- **ファイル**: `providers.tf`
- **内容**: `provider "github"` ブロックに空の `app_auth {}` を追加（値は書かず env var 注入に委ねる）。既存の PAT 説明コメントを、App 認証（HCP sensitive env var 3本 `GITHUB_APP_ID`/`GITHUB_APP_INSTALLATION_ID`/`GITHUB_APP_PEM_FILE`、Remote 実行で注入、PEM は内容を渡す旨、owner 必須の旨）へ刷新。owner 行は維持。
- **完了条件**: `mise exec -- terraform fmt -check` 通過、`mise exec -- terraform validate` が `app_auth {}` を含む構成で成功。コメントに PAT への言及が残らない。
- **依存**: なし（コードのみ。validate は init 済前提）

### Task 4: .gitignore に PEM 除外を追加
- **ファイル**: `.gitignore`
- **内容**: 秘密ファイル節に `*.pem` を追加。理由コメント（App private key の誤コミット防止、push protection の多層防御）を併記。
- **完了条件**: `git check-ignore some.pem` が一致を返す。
- **依存**: なし

### Task 5: HCP workspace に App 変数を追加【手動操作】
- **ファイル**: なし（HCP UI 操作）
- **内容**: HCP workspace `github-config` の Variables で、Environment variable として `GITHUB_APP_ID`・`GITHUB_APP_INSTALLATION_ID`・`GITHUB_APP_PEM_FILE`（値は PEM の内容、複数行は `\n` 表現可）を Sensitive=ON で追加。この時点では `GITHUB_TOKEN`（PAT）は削除しない（二重認証回避のため切替確認後に削除）。
- **完了条件**: 3変数が登録済・Sensitive=ON。PAT 変数はまだ存在（ロールバック余地確保）。
- **依存**: Task 2（App ID / installation ID / PEM が必要）

### Task 6: App 認証の疎通確認（plan）
- **ファイル**: なし（検証）
- **内容**: Task 3 のコードを反映した状態で `mise exec -- terraform plan`（Remote 実行）。provider が App 変数で API 認証し、既存 Ruleset 2件に `No changes` が返ることを確認。403/token エラーが出ないこと。判断依頼で確定する切替順序に従い、コードを main へ反映するタイミング（PR マージ前後）はユーザー判断に従う。
- **完了条件**: plan が認証成功し `No changes`（または意図差分のみ）。403/required token エラーなし。
- **依存**: Task 3, Task 5

### Task 7: README の認証手順を App 手順へ更新
- **ファイル**: `README.md`
- **内容**: 認証種別を App へ・アーキ図 "PAT 認証" → "App 認証"・providers.tf 説明・手順3を「App 作成・権限（Administration:RW + Metadata:Read）・Selected repos インストール・PEM 生成」へ全面置換・手順4を「App 変数3本を Sensitive env var 登録」へ置換・トラブルシュート表の 403 行・token 行を App 起因（権限不足/インストール漏れ/変数未登録）へ更新・スコープ外の「App 移行予定」記述を「移行済」へ更新。確定済の権限方針（Contents 不付与の根拠、Issues は #5 で増分）を簡潔に明記。切替・ロールバック手順の節を追加。
- **完了条件**: README に PAT を前提とする能動的手順が残らない（歴史的言及を除く）。App 手順だけで初見者がセットアップ可能。
- **依存**: Task 6（実証済の手順を文書化するため）

### Task 8: PAT 変数の削除と最終確認【手動操作 + 検証】
- **ファイル**: なし（HCP UI + 検証）
- **内容**: App 認証成功（Task 6、および本番 apply 確認）後、HCP workspace から `GITHUB_TOKEN`（PAT）変数を削除。削除後に `mise exec -- terraform plan` を再実行し App 単独で認証成立を確認。GitHub 側の旧 PAT も revoke。この不可逆操作はユーザーの明示承認後に実施。
- **完了条件**: workspace に `GITHUB_TOKEN` が存在しない（AC2）。PAT 削除後の plan が App 単独で成功。旧 PAT は revoke 済。
- **依存**: Task 6, Task 7

### Task 9: コミット・PR 作成
- **ファイル**: なし（git 操作）
- **内容**: `providers.tf`・`README.md`・`.gitignore` の変更をコミットし PR 作成。PR 本文に切替順序・ロールバック方針・手動ステップ（App 作成 / HCP 変数操作）の実施状況を明記。
- **完了条件**: PR 作成済。CI/plan が通過。AC1-3 の充足状況が PR に記載。
- **依存**: Task 3, Task 4, Task 7（手動 Task の完了状況も併記）

## 参照ドキュメント
- README.md「初期セットアップ」手順3-4、「トラブルシュート」表（更新対象）
- integrations/github provider v6 docs（App 認証 `app_auth` 仕様）
- Issue #5（ラベル管理。Issues 権限の増分付与は本Issueでは行わない）
- メモリ: app-auth-least-privilege-policy（確定済の permission/scope 方針）
