# 実装プラン: Issue #15 リポ管理リソース構造の決定（ADR起票・現状ダンプ・差分一覧）

## 改訂履歴

- **2026-06-20 (実装中改訂)**: 生 JSON ダンプの保存方針を撤回。`security_and_analysis` 等の内部情報や取得者依存の `permissions` が含まれるため、リポジトリへの保存を取りやめ、Issue #15 の AC2 も併せて改訂（「ADR 内に整理された形で記述」へ変更）。Task 3「4リポの API 生レスポンスダンプ取得」と Task 4「ダンプ取得手順の記録」は実施しない。代わりに、再取得手順を ADR 本体の付録 B に記載する。変更対象ファイル表のダンプ JSON 群（`docs/adr/0001-repository-current-state/`）は削除対象。

## 概要

- **Issue**: #15
- **ベースブランチ**: main
- **スコープ**: `github_repository` リソースの構造（1リソース集約 vs 種別別分離）を ADR で決定する spike。決定の前提となる4管理対象リポの GitHub API 生レスポンスを `docs/adr/` 配下に保存し、リポ間で差がある属性の一覧表を ADR 内に Markdown 表で記述する。Terraform リソース定義の実装は本 spike のスコープ外（feature 子Issue #16/#17 で対応）。

## 判断依頼

### 判断待ち（Task 6 開始前に確定 / ユーザー確認結果: 差分表確認後に判断）

Task 5（差分表作成）完了時点でユーザーに以下3点を確認してから Task 6（ADR 起草）に進む。事実ベース（実ダンプの差分実態）で判断するため、差分表完成までは判断保留。

- **[判断待ち]** リソース構造の決定軸: `github_repository` を1リソースで全属性管理する案（A. 集約）か、リソースは1本（`github_repository`）に集約しつつ `*.tf` ファイルをセキュリティ系・開発プロセス系の2枚に分割管理する案（B. ファイル分離・リソース1本）か、`github_repository` と `github_repository_topics` 等の補助リソースに分離する案（C. リソース分離）か。Terraform の `github_repository` 仕様上、属性は1リソースに集まる（リソース分割は補助リソース系のみ）ため、現実的選択は A vs B。誤った場合のコスト: 後から構造変更すると `moved` ブロック整備と全リポ import 再実行が必要。
- **[判断待ち]** `topics` の SoT 化方針: `github_repository.topics` 属性で管理するか、補助リソース `github_repository_topics` に分離するか。Issue #17 備考に「spike の成果物または別途決定」とある。`topics` は UI からも頻繁に変更されやすいため `lifecycle.ignore_changes` 対象とするかも併せて確認する。
- **[判断待ち]** `lifecycle.ignore_changes` 対象属性の確定範囲: Issue #16 で `visibility` と `archived` への `ignore_changes` 設定が明示されているが、`description` / `homepage` / `topics` 等の「運用中に変動しやすい属性」も対象に含めるか。ADR で対象属性一覧と根拠（運用負荷 vs SoT 厳格性のトレードオフ）を明示する。

### 前提確認（ユーザー確認結果: 全項目承認）

- **[承認済]** spike の成果物は ADR 1枚 + API ダンプ JSON 4本（リポごと）。ADR ファイル名は `docs/adr/0001-repository-resource-structure.md`、ダンプは `docs/adr/0001-repository-current-state/<repo>.json` の命名で進める。
- **[承認済]** ADR テンプレートは「コンテキスト/決定/根拠/代替案/影響」の5節構成で進める。
- **[承認済]** ダンプ取得スコープは `visibility / archived / allow_auto_merge / allow_squash_merge / allow_merge_commit / allow_rebase_merge / delete_branch_on_merge / default_branch / description / homepage / topics / has_issues / has_wiki / has_projects / has_discussions` の15属性 + リポ識別子（`name`, `full_name`, `id`）を網羅。`gh api` のフルレスポンス JSON を保存し、ADR の差分表は上記15属性に限定。

## 検証方針

### テストレベル

本 spike は ADR・ダンプ・差分表の作成であり、Terraform コード変更は伴わない。ユニット/統合/E2E の自動テストは不要。検証は以下に集約する:

- **ダンプの正当性検証**: 4リポ分の JSON ファイルが `docs/adr/` 配下に存在し、`jq` でパース可能・対象15属性が全て含まれていることを目視 + シェル検証で確認。
- **差分表の網羅性検証**: ADR 内の差分表が15属性 × 4リポを網羅し、属性値の表記がダンプ JSON と一致することを目視確認。
- **ADR の構造検証**: 「コンテキスト/決定/根拠/代替案/影響」の5節が揃い、決定根拠が親 Issue #6 の動機（セキュリティリスクの横断的制御 + 開発プロセス標準化）と紐付いていることを目視確認。
- **後続子Issue着手可能性検証**: 本 spike の成果物（ADR・ダンプ・差分表）への参照のみで #16/#17 のタスク分解が可能か、各子Issue の AC（`visibility` per-repo 必須宣言、`archived` の `ignore_changes`、base preset 構造等）に必要な情報が ADR にあるかをチェックリストで確認。

### 検証すべき振る舞い

- **Given** 4管理対象リポの API 生レスポンス JSON が `docs/adr/` 配下に保存されている
  **When** 差分表で「リポ間で値が異なる属性」を特定する
  **Then** ダンプ JSON の値と差分表の値が一致し、per-repo override 必須範囲が一意に決まる
  **検証レベル**: 目視確認
- **Given** ADR で「リソース構造の決定」が明記されている
  **When** #16/#17 の実装者が ADR を参照する
  **Then** 1リソース vs 分離の選択結果と、選択しなかった代替案を不採用とした根拠が読み取れる
  **検証レベル**: 目視確認
- **Given** `visibility` がリポ間で混在（public/private）する可能性
  **When** 4リポの `visibility` をダンプから抽出する
  **Then** Issue #16 の「`visibility` per-repo 必須宣言」方針の妥当性（混在の実態がある）が ADR で根拠付けられる
  **検証レベル**: 目視確認
- **Given** ADR で `topics` SoT 化方針が決定されている
  **When** #17 の実装者が `topics` 属性の扱いを判断する
  **Then** `github_repository.topics` 属性使用か `github_repository_topics` 補助リソース使用かが一意に決まる
  **検証レベル**: 目視確認
- **Given** ダンプ取得時点と spike 完了時点の間にリポ属性の手動変更が発生する可能性
  **When** ダンプ JSON にタイムスタンプ/取得コマンドが記録されている
  **Then** 後続作業時に「ダンプ時点」を再現可能で、import 時の差分が「ダンプ後の手動変更」か「ダンプ時点の SoT 不整合」か切り分けられる
  **検証レベル**: 目視確認

## テストケース対応表

| AC# | テストケース概要 | 観点 | 採用技法 | テストレベル |
|---|---|---|---|---|
| AC1 | ADR ファイル `docs/adr/NNNN-<slug>.md` が存在し、リソース構造の決定（A/B/C いずれか）と根拠が記述されている | 典型ケース | ユースケーステスト | 目視確認 |
| AC1 | ADR の決定セクションが代替案を含む（採用 + 不採用の根拠） | 組み合わせ | ディシジョンテーブル | 目視確認 |
| AC1 | ADR の根拠セクションが親 Issue #6 の動機（セキュリティ横断制御 + プロセス標準化）に紐付く | 典型ケース | ユースケーステスト | 目視確認 |
| AC2 | 4管理対象リポ全件の API 生レスポンス JSON が `docs/adr/` 配下に保存されている | 典型ケース | 同値分割 | 目視確認 |
| AC2 | 各 JSON が `gh api repos/{owner}/{repo}` 由来の生レスポンス形式（マージ系・基本属性・default_branch を含む） | 境界値 | 境界値分析 | 目視確認 |
| AC2 | 各 JSON が `jq .` でパース可能（構文的妥当性） | 異常系 | 同値分割 | 目視確認 |
| AC3 | リポ間で差がある属性の一覧表が ADR 内に Markdown 表形式で記述されている | 典型ケース | ユースケーステスト | 目視確認 |
| AC3 | 差分表が15属性 × 4リポを網羅（属性名 × リポ名のマトリクス） | 組み合わせ | ディシジョンテーブル | 目視確認 |
| AC3 | 差分表のセル値がダンプ JSON の対応値と一致 | 典型ケース | 同値分割 | 目視確認 |
| AC3 | 差分表に per-repo override 必須範囲（差がある属性のリスト）の集計が含まれる | 組み合わせ | ディシジョンテーブル | 目視確認 |
| AC4 | #16 着手に必要な情報（`visibility` の混在実態、`archived` の現状値、`has_*` の現状値、`allow_auto_merge` の現状値）が ADR から読み取れる | 状態遷移 | ユースケーステスト | 目視確認 |
| AC4 | #17 着手に必要な情報（マージ系3属性の現状値、`delete_branch_on_merge` の現状値、`default_branch` の統一性、`description/homepage/topics/has_issues` の現状値）が ADR から読み取れる | 状態遷移 | ユースケーステスト | 目視確認 |
| AC4 | ADR で `topics` SoT 化方針が決定済（属性 vs 補助リソースのいずれか） | 状態遷移 | ディシジョンテーブル | 目視確認 |

## 実装設計

### 変更概要

**外部IO**:
- GitHub REST API（`GET /repos/{owner}/{repo}`）への読み取り操作のみ。`gh api` CLI 経由（既存の `gh` 認証を使用、Terraform App 認証経路は使わない）。書き込みなし。
- `docs/adr/` ディレクトリ新設、ADR Markdown + JSON ダンプファイル群の新規作成のみ。

**ビジネスロジック**:
- なし。Terraform リソース定義（`*.tf`）・`locals.tf` 合成ロジック・`variables.tf` 型定義は一切触らない。ロジックは #16/#17 で導入する。

### データフロー

```
gh api repos/kuchita-el/{repo} （4リポ分）
      │ JSON 生レスポンス
      ▼
docs/adr/NNNN-repository-current-state/{repo}.json （ファイル保存）
      │ 人手で属性抽出・比較
      ▼
docs/adr/NNNN-repository-resource-structure.md
  ├─ コンテキスト（親 Issue #6 の動機・スコープ要約）
  ├─ 決定（リソース構造 A/B/C のいずれを採用したか）
  ├─ 根拠（決定理由を動機軸で説明）
  ├─ 代替案（採用しなかった案と不採用理由）
  ├─ 影響（#16/#17 への影響、import 戦略への影響）
  └─ 付録: 現状ダンプ差分表（15属性 × 4リポの Markdown 表）
```

### エラーハンドリング

- `gh api` で 403/404 が返る場合: App 認証ではなく `gh` CLI の認証（PAT/keyring）を使うため、Issue 本文の「App 権限 `Administration: Read & write`」は spike の API 呼び出しには影響しない。`gh` 認証で4リポ全てに到達可能か事前確認する。
- ダンプ取得失敗時の対処: 該当リポを単独で再実行。全件失敗時は `gh auth status` で認証状態を確認。

### 変更対象ファイル

| ファイル/モジュール | 操作 | 変更内容 |
|---|---|---|
| `docs/adr/` | 新規（ディレクトリ） | ADR 配置ディレクトリの新設（本 spike が ADR ディレクトリの新設も兼ねる） |
| `docs/adr/0001-repository-resource-structure.md` | 新規 | リソース構造決定の ADR 本体（コンテキスト/決定/根拠/代替案/影響 + 差分表 + ダンプへの参照） |
| `docs/adr/0001-repository-current-state/gachanuma.json` | 新規 | `gh api repos/kuchita-el/gachanuma` の生レスポンス JSON |
| `docs/adr/0001-repository-current-state/github-config.json` | 新規 | `gh api repos/kuchita-el/github-config` の生レスポンス JSON |
| `docs/adr/0001-repository-current-state/claude-shared-skills.json` | 新規 | `gh api repos/kuchita-el/claude-shared-skills` の生レスポンス JSON |
| `docs/adr/0001-repository-current-state/dependabot-triage-action.json` | 新規 | `gh api repos/kuchita-el/dependabot-triage-action` の生レスポンス JSON |
| `docs/adr/0001-repository-current-state/README.md` | 新規（任意） | ダンプ取得コマンド・取得日時の記録（再取得時の手順保存） |
| `README.md` | 修正（任意） | プロジェクト README の「アーキテクチャ」または「スコープ外」節に ADR ディレクトリの存在を追記 |

## タスク分解

### Task 1: 作業ブランチ作成
- **ファイル**: なし（git 操作）
- **内容**: 最新 main から `feature/15-repository-resource-structure-adr` を作成し switch する。
- **完了条件**: `git status` clean、HEAD が main 最新と一致。`git branch --show-current` がブランチ名を返す。
- **依存**: なし

### Task 2: ADR ディレクトリと採番方針の確定
- **ファイル**: `docs/adr/`（新規ディレクトリ）
- **内容**: `docs/adr/` ディレクトリを新設。本 spike を採番 `0001` とし、ファイル名 `0001-repository-resource-structure.md`、ダンプ配置ディレクトリ `0001-repository-current-state/` を確定する。採番ルール（4桁ゼロ埋め連番）を ADR 本文の末尾または別ファイルに残すかは Task 4 の ADR 本体記述時に判断。
- **完了条件**: ディレクトリ `docs/adr/` と `docs/adr/0001-repository-current-state/` が存在する。`ls docs/adr/` で空ディレクトリが見える（`.gitkeep` 不要、後続 Task で実ファイルが追加される）。
- **依存**: Task 1

### Task 3: 4リポの API 生レスポンスダンプ取得
- **ファイル**: `docs/adr/0001-repository-current-state/{gachanuma,github-config,claude-shared-skills,dependabot-triage-action}.json`
- **内容**: 各管理対象リポについて `gh api repos/kuchita-el/<repo>` を実行し、生 JSON レスポンスを上記4ファイルに保存する。`jq .` でパース・整形して保存（可読性確保 + 構文的妥当性確認を兼ねる）。各ファイルは `gh api` のフルレスポンスを保持し、ADR 差分表で参照する15属性（visibility, archived, allow_auto_merge, allow_squash_merge, allow_merge_commit, allow_rebase_merge, delete_branch_on_merge, default_branch, description, homepage, topics, has_issues, has_wiki, has_projects, has_discussions）を含むこと。
- **完了条件**: 4ファイルが存在し、各ファイルが `jq -e '.name and .visibility and .default_branch' <file>` で真を返す（最低限の属性網羅確認）。`jq -r '.name' <file>` が期待のリポ名を返す。
  - 入出力例（github-config の場合）:
    - 入力: `gh api repos/kuchita-el/github-config`
    - 期待出力（部分抜粋）: `{"name":"github-config","visibility":"public","archived":false,"default_branch":"main","allow_auto_merge":false,"allow_squash_merge":true,"allow_merge_commit":true,"allow_rebase_merge":true,"delete_branch_on_merge":false,"has_issues":true,"has_wiki":false,"has_projects":true,"has_discussions":false,"description":"Terraform-managed GitHub repository settings (rulesets etc.) as IaC","homepage":null,"topics":[]}`
- **依存**: Task 2

### Task 4: ダンプ取得手順の記録（任意ファイル）
- **ファイル**: `docs/adr/0001-repository-current-state/README.md`
- **内容**: ダンプ取得に使ったコマンド（`gh api repos/kuchita-el/<repo> | jq . > <repo>.json` の形）、取得日時、取得者の `gh auth status` 上の identity、再取得時の手順を簡潔に記録。再取得や追加リポ取り込み時に同じ手順で揃えられるようにする。
- **完了条件**: ファイルが存在し、コマンドと取得日時が読み取れる。再取得時にコピペで実行できる。
- **依存**: Task 3

### Task 5: 差分表の作成（属性 × リポのマトリクス）
- **ファイル**: なし（Task 6 で ADR 本体に取り込むためのデータ整理。中間メモは作業ツリー外で良い）
- **内容**: 4リポのダンプ JSON から15属性の値を抽出し、Markdown 表形式に整形する。表の構造は「行 = 属性、列 = リポ名（4列）+ 差分有無列」とし、リポ間で値が完全一致する属性は「差分なし」、1つでも異なる属性は「差分あり」とマーキング。`topics` のような配列・`description`/`homepage` のような null 許容属性は表記ルール（空配列は `[]`、null は `null`）を統一する。per-repo override 必須範囲（差分ありの属性集合）を集計する。
- **完了条件**: 15属性 × 4リポのマトリクスが完成し、「差分あり」属性集合が一意に決まる。差分ありが0件なら ADR の「per-repo override 不要」根拠、1件以上なら「per-repo override 必須範囲」根拠として記述可能な状態。表のセル値が Task 3 のダンプ JSON と一致（目視確認）。
- **依存**: Task 3

### Task 6: ADR 本体の起草（コンテキスト/決定/根拠/代替案/影響）
- **ファイル**: `docs/adr/0001-repository-resource-structure.md`
- **内容**: 以下の節構成で ADR を執筆する:
  - **タイトル**: `# ADR 0001: github_repository リソースの構造`
  - **ステータス**: 「提案中」または「承認済」（判断依頼の結論で確定）
  - **コンテキスト**: 親 Issue #6 の動機（セキュリティリスク横断制御 + 開発プロセス標準化）の要約、子 Issue #16/#17 のスコープ要約、本 spike の3つの調査の問いを記述。
  - **決定**: 判断依頼の「リソース構造の決定軸」「`topics` SoT 化方針」「`ignore_changes` 対象属性」の3点について決定内容を箇条書きで明示。
  - **根拠**: 各決定の根拠を、親 Issue 動機軸 + 現状ダンプ差分表 + 一貫性/影響範囲のトレードオフから説明。
  - **代替案**: 採用しなかった構造案（A/B/C のうち不採用案）と不採用理由。
  - **影響**: #16/#17 のタスク分解への影響、import 戦略への影響、後続新規リポ追加時の影響、ロールバック可能性。
  - **付録: 現状ダンプ差分表**: Task 5 の Markdown 表を埋め込み、per-repo override 必須範囲を集計表示。ダンプ JSON への参照（`docs/adr/0001-repository-current-state/<repo>.json`）も記載。
- **完了条件**: ファイルが存在し、5節 + 付録の構造が揃う。判断依頼で確定した決定が「決定」節に明示。「該当なし」「TBD」「適切に判断」等のプレースホルダがゼロ。Task 5 の差分表が付録に埋め込まれ、セル値がダンプ JSON と一致。
  - 入出力例（決定節の記述例）:
    - 「採用: 案 B（`github_repository` リソース1本に集約、`*.tf` ファイルをセキュリティ系（`repository_security.tf`）と開発プロセス系（`repository_process.tf`）に分離）」
    - 「`topics` SoT 化方針: `github_repository.topics` 属性で管理。`lifecycle.ignore_changes` 対象に含めない（SoT 厳格性を優先）」
    - 「`lifecycle.ignore_changes` 対象: `visibility`, `archived` のみ（Issue #16 指定どおり、運用負荷より破壊回避を優先）」
- **依存**: Task 5、判断依頼の確定

### Task 7: 後続子Issue着手可能性のセルフレビュー
- **ファイル**: なし（レビュー作業）
- **内容**: 完成した ADR・ダンプ・差分表を「初見の #16/#17 実装者」視点で読み直し、以下をチェックリストで確認する:
  - #16 着手に必要な情報（`visibility` の混在実態、`archived` の現状値、`has_*` の現状値、`allow_auto_merge` の現状値）が ADR から読み取れるか
  - #17 着手に必要な情報（マージ系3属性の現状値、`delete_branch_on_merge` の現状値、`default_branch` の統一性、`description/homepage/topics/has_issues` の現状値）が ADR から読み取れるか
  - リソース構造の決定（A/B/C）が一意に確定しており、#16/#17 の Terraform リソース定義タスクが ADR 参照のみで分解可能か
  - `topics` SoT 化方針が確定し、#17 の `topics` 属性タスクが ADR 参照のみで実装方針を決められるか
  - `lifecycle.ignore_changes` 対象属性が確定し、#16 の対応タスクが ADR 参照のみで分解可能か
  - 差分表で「per-repo override 必須範囲」が一意に集計され、#16/#17 の `variables.tf` 型定義タスクが ADR 参照のみで分解可能か
- **完了条件**: チェックリスト全項目が「読み取れる」状態。読み取れない項目があれば Task 6 へ戻り ADR を補強する。
- **依存**: Task 6

### Task 8: README への ADR 参照追記（任意）
- **ファイル**: `README.md`
- **内容**: プロジェクト README の「アーキテクチャ」節または「スコープ外」節に、`docs/adr/` ディレクトリと ADR 0001 の存在を1-2行で追記。本 spike 起点で ADR を導入したことと、今後の設計判断も同形式で追加する旨を明示。
- **完了条件**: README に `docs/adr/` への参照が追加されている。本文の他箇所と矛盾しない。
- **依存**: Task 6

### Task 9: コミット・PR 作成
- **ファイル**: なし（git 操作）
- **内容**: `docs/adr/0001-repository-resource-structure.md`、`docs/adr/0001-repository-current-state/*.json`、`docs/adr/0001-repository-current-state/README.md`、必要なら `README.md` の変更をコミットし PR 作成。PR 本文に以下を明記:
  - 本 spike の決定内容（リソース構造・`topics` SoT・`ignore_changes` 対象）
  - 差分表の集計結果（per-repo override 必須範囲）
  - AC1-4 の充足状況
  - 後続 #16/#17 着手可能の宣言
- **完了条件**: PR が作成済。PR 本文に決定・集計・AC 充足が記載。Issue #15 にリンク。
- **依存**: Task 3, Task 4, Task 6, Task 7, Task 8

## 参照ドキュメント

- 親 Issue #6 「リポジトリ基本設定（`github_repository`）のプリセット管理を追加」 - 動機・スコープ・属性分類
- 子 Issue #16 「セキュリティ系プリセット管理（visibility / archived / has_* 等）」 - セキュリティ系属性スコープ・`ignore_changes` 方針
- 子 Issue #17 「開発プロセス系プリセット管理（マージ系 / default_branch / topics 等）」 - 開発プロセス系属性スコープ・`topics` SoT 検討依頼
- `docs/plans/issue-9.md` - ADR/Plan 体裁の先例
- `README.md` - 既存アーキテクチャ・branch-protection 管理対象リポ母集団・import 戦略
- `terraform.tfvars` - 管理対象リポ4件（gachanuma / github-config / claude-shared-skills / dependabot-triage-action）の確定リスト
- メモリ: app-auth-least-privilege-policy - App 権限 `Administration: Read & write` のみの最小権限方針
- [integrations/github provider v6 docs - github_repository](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository) - 属性仕様（リソース構造決定時の前提）
