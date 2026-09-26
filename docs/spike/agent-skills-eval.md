# HashiCorp 公式 Terraform Skill 群（hashicorp/agent-skills）の採用評価

> **本文書の扱い（短命ドキュメント）**
>
> 本文書は Issue #35 の spike レポートであり、**判断根拠の暫定保管庫**として置く。
> 採用判定の根拠は後続 Issue 本文へ転記し、本文書は次のいずれかの条件を満たした時点で削除可:
> 1. 採用判定された skill の導入 Issue が全件マージまたは却下で決着し、本文書への参照が不要になった
> 2. `hashicorp/agent-skills` のラインナップ更新等で本文書の記述が陳腐化した
>
> 「なぜ却下したか」を恒久的に残したい場合は ADR 化（`docs/adr/`）して本文書は削除する。

## 1. 背景と評価対象

- 親 Issue: #35
- 関連 Issue: #21（PR #33 で `hashicorp/terraform-mcp-server` 導入済み）、#22, #24, #25, #26, #27, #32, #4
- 評価対象: `hashicorp/agent-skills` リポジトリ配下の Terraform 系 skill / plugin（**12 skill / 3 plugin**）
- スコープ外: `anthropics/claude-plugins-official` の `external_plugins/terraform`（PR #33 評価時に MCP ラッパーのみで `terraform-mcp-server` と内容重複と確認済み）、HashiCorp 公式以外の Terraform 関連 skill

## 2. 調査の問いと回答

### Q1: 公開されている Terraform 系 skill / plugin の全件

`hashicorp/agent-skills` は **3 plugin / 12 skill** で構成:

| plugin | 内包 skill |
| --- | --- |
| terraform-code-generation | azure-verified-modules / terraform-search-import / terraform-style-guide / terraform-test |
| terraform-module-generation | refactor-module / terraform-stacks |
| terraform-provider-development | new-terraform-provider / provider-actions / provider-docs / provider-resources / provider-test-patterns / run-acceptance-tests |

参考: marketplace には Packer 系 plugin も含まれるが、本評価では対象外。

### Q2: 各 skill の中身（要点）

| skill | 主旨 | 主な依存 |
| --- | --- | --- |
| azure-verified-modules | AVM 認証要件に沿った Azure module 作成 | `azurerm` / `azapi` |
| terraform-search-import | TF 1.14+ の list block で discovery → bulk import | TF >= 1.14、provider の list resource 対応 |
| terraform-style-guide | 公式 Style Guide に沿った HCL 生成・レビュー | なし（手順ガイド） |
| terraform-test | `.tftest.hcl` の書き方・assertion・mock provider | TF >= 1.7 |
| refactor-module | モノリス TF 設定を再利用可能 module へリファクタ | なし |
| terraform-stacks | `.tfcomponent.hcl` / `.tfdeploy.hcl` 作成・管理 | Terraform Stacks 対応 HCP/TFE |
| new-terraform-provider | Plugin Framework で provider scaffold | provider 開発環境 |
| provider-actions | Plugin Framework の provider actions 実装 | provider 開発環境 |
| provider-docs | `tfplugindocs` で provider ドキュメント生成 | `tfplugindocs` |
| provider-resources | Plugin Framework で resource / data source 実装 | provider 開発環境 |
| provider-test-patterns | `terraform-plugin-testing` の test patterns | provider 開発環境 |
| run-acceptance-tests | `TestAcc*` の実行手順 | Go test 環境 |

各 plugin の `.mcp.json` 同梱状況:
- `terraform-code-generation` / `terraform-module-generation`: `hashicorp/terraform-mcp-server`（**floating tag**、env `TFE_TOKEN` / `TFE_ADDRESS` 付き）を MCP 名 `terraform` で bundle
- `terraform-provider-development`: MCP 非同梱

### Q3: 本プロジェクトでの適合性判定

| skill | 判定 | 根拠 |
| --- | --- | --- |
| terraform-style-guide | **採用** | HashiCorp 公式 Style Guide の規約適用が本プロジェクトでも有効。`branch_protection.tf` のファイル分割は概ね Style Guide と整合し、レビュー時の客観基準として価値あり |
| refactor-module | **採用（ケイパビリティ担保）** | Issue #32（単一 root module 維持の方針 ADR 化）は未決定。将来モジュール分割を検討する際の手順ガイドとして事前確保し、分割側の選択肢を残す |
| terraform-search-import | **不採用** | `integrations/github` provider は v6.12.1 時点で **list resource 未対応**。対応 Issue（integrations/terraform-provider-github#2955）は `Status: Blocked` で停滞。skill が技術的に動作しない |
| terraform-test | **保留** | 単体テストの価値は理論上あるが、Issue #22（tflint + terraform validate）の静的検証導入が先。locals.tf の合成ロジック拡張時に再評価 |
| azure-verified-modules | 不採用 | Azure 専用。本プロジェクトは `integrations/github` のみ |
| terraform-stacks | 不採用（plugin 同梱のため install は並走） | Stacks 採用予定なし。ただし `refactor-module` と同じ `terraform-module-generation` plugin に同梱されるため install そのものは伴う（未使用時の起動コストはほぼゼロ） |
| new-terraform-provider | 不採用 | provider 開発者向け。本プロジェクトは利用者 |
| provider-actions | 不採用 | 同上 |
| provider-docs | 不採用 | 同上 |
| provider-resources | 不採用 | 同上 |
| provider-test-patterns | 不採用 | 同上 |
| run-acceptance-tests | 不採用 | 同上 |

集計: **採用 2 / 保留 1 / 不採用 9**（うち `terraform-stacks` は `refactor-module` の plugin に同梱される従属採用）

### Q4: `terraform-mcp-server`（PR #33 導入済み）との関係

| 区分 | skill |
| --- | --- |
| 補完（skill = 手順、MCP = 属性照会、役割異なる） | terraform-style-guide / terraform-test / terraform-search-import / refactor-module / terraform-stacks / azure-verified-modules |
| 無関係（provider 開発者向け、Registry 利用と層が違う） | provider-development plugin 内 6 skill |

**MCP 重複懸念は当初想定したが、実機検証で衝突しないことを確認**（次節）。

### Q5: 採用 skill の導入スコープ

- 採用判定 `terraform-style-guide` は **チーム共有が前提**（コードレビュー基準）
- Issue #35 の要件「リポにコミット、チーム全員が同じ構成を共有」と整合させるには **project スコープ**
- 実機検証で `claude plugin install -s project` は `.claude/settings.json` の `enabledPlugins` をプロジェクト直下に書き込む形で実現できることを確認（次節）
- 結論: **project スコープでの plugin install** を採用方式とする

## 3. 実機検証（Phase A）

`terraform-code-generation` plugin を `claude plugin install -s project` でインストールし、以下を観察:

| 観察項目 | 結果 |
| --- | --- |
| `.claude/settings.json` の生成 | `{"enabledPlugins": {"terraform-code-generation@hashicorp": true}}` の 11 行 JSON が作成され、コミット可能 |
| MCP 名前空間衝突 | **衝突なし**。plugin 同梱 MCP は `plugin:terraform-code-generation:terraform` というプレフィクス付きで登録され、PR #33 の `terraform` MCP と両立 |
| plugin 同梱 MCP の起動 | floating tag・env (TFE_TOKEN/TFE_ADDRESS) 未設定でも `✔ Connected` |
| project スコープ plugin の uninstall | `claude plugin uninstall` は project スコープでは禁止（チーム共有保護）。`.claude/settings.json` の編集 or 削除で対応 |
| 個別 skill の有効/無効 | plugin 単位のみ。skill 単体 enable/disable は不可（不要 skill は同梱されるが、未起動時のコストはほぼゼロ） |

**重要な訂正**: 当初「PR #33 の MCP と plugin 同梱 MCP が衝突する」と想定していたが、Claude Code は plugin 由来 MCP に `plugin:<plugin>:<server>` のプレフィクスを付与して分離するため、**衝突しない**。skill のみ vendoring する回避策は不要。

検証完了後、`.claude/settings.json` を削除して元の状態に復帰した（プロジェクト本体への変更なし）。

## 4. 結論と後続 Issue

### 採用

- **terraform-style-guide**（`terraform-code-generation` plugin） — project スコープで導入、`.claude/settings.json` をリポにコミット
- **refactor-module**（`terraform-module-generation` plugin） — project スコープで導入。同 plugin に `terraform-stacks` skill も同梱されるが、未使用時の起動コストはほぼゼロのため許容
  - 動機: Issue #32 が未決定であり、将来モジュール分割を検討する余地を残すために手順ガイドを事前確保する

**後続 Issue: #36**（上記 2 plugin の導入をまとめて 1 件で起票。採用方式・スコープ・MCP 衝突の扱いが共通で、分離する意義が薄いため）。

### 保留

- **terraform-test** — Issue #22 の静的検証導入後に再評価。**後続 Issue は起票しない**

### 不採用（9 件）

- 採用しない skill は本 spike の判断記録のみで完結。**後続 Issue は起票しない**
- `terraform-stacks` は `refactor-module` と同 plugin のため install そのものは並走（従属採用）

### マーケットプレイス追加について

- 採用判定の skill 導入には `claude plugin marketplace add hashicorp/agent-skills` が前提
- これは **user スコープ**（`~/.claude.json` 等）の設定で、リポにはコミットされない
- 採用後続 Issue で `README.md` への手順記載で対応する

## 5. 参考リンク

- [hashicorp/agent-skills](https://github.com/hashicorp/agent-skills)
- [Introducing HashiCorp Agent Skills](https://www.hashicorp.com/en/blog/introducing-hashicorp-agent-skills)
- [integrations/terraform-provider-github#2955](https://github.com/integrations/terraform-provider-github/issues/2955)（list resource 対応依頼、Blocked）
- [Terraform Style Guide (公式)](https://developer.hashicorp.com/terraform/language/style)
