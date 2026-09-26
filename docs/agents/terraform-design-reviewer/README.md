# terraform-design-reviewer

Terraform 変更を伴う PR の **設計逸脱を機械的に検出する** プロジェクトローカル subagent。

- 定義: [`/.claude/agents/terraform-design-reviewer.md`](../../../.claude/agents/terraform-design-reviewer.md)
- 起動形: `Agent(subagent_type: "terraform-design-reviewer", description: ..., prompt: ...)`
- 位置付け: 既存 `dev-workflow:code-reviewer`（汎用）を置換せず、`.tf` 固有観点の補完として並列起動する
- 関連 Issue: [#20](https://github.com/kuchita-el/github-config/issues/20)

## 観点サマリ

各観点は「守る不変条件」を判定の軸とし、その時点の正しい書き方は reviewer が判定の都度「参照一次情報」を読んで確かめる（Issue [#79](https://github.com/kuchita-el/github-config/issues/79)）。ADR や実コードの書き方が変わっても、reviewer 定義を書き換えずに判定が追従することを狙う。このため下表と reviewer 定義には、行番号付きの参照や ADR の規約の書き写しを置かない。

| # | 観点 | 重大度 | 守る不変条件の要旨 | 参照一次情報 |
|---|---|---|---|---|
| 1 | `moved` ブロック不在 | blocker | 既存リソースがアドレスの付け替えだけで破棄・再作成されない | Terraform 公式 [Refactoring](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) / [ADR 0001](../../adr/0001-repository-resource-structure.md) §影響「リポジトリ名変更時の destroy リスクと `moved` ブロックによる回避」 |
| 2 | `variable` の `validation` 不足 | warning | 入力値の暗黙の制約に反する入力が plan 前に拒否される | [`variables.tf`](../../../variables.tf) の `repositories` 変数の `validation` 群 |
| 3 | `lifecycle.ignore_changes` 網羅性 | blocker | 上書きの復旧コストが大きい属性が、GitHub 側の変更を巻き戻さない保護の下にある | [ADR 0001](../../adr/0001-repository-resource-structure.md) §3 / [`repository.tf`](../../../repository.tf) の `github_repository.this` |
| 4 | `for_each` vs `count` | warning | 固有の識別子を持つ要素のインスタンスが識別子で追跡される。`count = 1` は許容 | [`branch_protection.tf`](../../../branch_protection.tf) の `github_repository_ruleset.branch_protection` |
| 5 | ハードコード値の抽出 | suggestion | Terraform 固有の定数の宣言場所が定まり、resource 本体に散らばらない | [`terraform.tfvars`](../../../terraform.tfvars) の `status_check_integration_id` |
| 6 | preset 上書き経路の一貫性 | blocker | 未指定が揃えた値を消さない、揃えた値の正の置き場所が一つ、per-repo の逸脱は ADR が認めた経路だけ、必須の宣言を省略できない、構造は現行の構造方針 ADR に従う | [ADR 0004](../../adr/0004-terraform-module-structure-policy.md) 決定 §3〜§7（各 ADR のステータス節で置き換え関係を確認）/ [`/README.md`](../../../README.md)「例外台帳」節 / [`repository.tf`](../../../repository.tf)・[`branch_protection.tf`](../../../branch_protection.tf) |
| 7 | App 権限境界違反 | blocker | Terraform が要する API 権限が App に付与済みの権限に収まる | [`/CLAUDE.md`](../../../CLAUDE.md) §3 / [`README.md`](../../../README.md)「設計思想」節・「GitHub App の作成・インストール・秘密鍵の生成」節 |
| 8 | plan-time リスク | warning / blocker | 意図しない破棄・再作成を伴って適用されない。`import.tf` 連携時は blocker | [`/CLAUDE.md`](../../../CLAUDE.md) §2 / [`README.md`](../../../README.md)「既存リポの取り込み（import）」節 |

## 起動例

### 呼び出し側の事前準備

reviewer は `Bash` ツールを持たないため、呼び出し側で `git diff` を事前取得する:

```bash
git diff main...HEAD -- '*.tf' '*.tfvars' > /tmp/tf-diff.txt
```

### 単独起動

```
Agent(
  subagent_type: "terraform-design-reviewer",
  description: "Review TF diff for PR #N",
  prompt: """
    ベースブランチ: main

    ## git diff
    <`/tmp/tf-diff.txt` の中身を貼り付け>

    ## plan 出力（任意）
    <HCP plan 出力テキスト。未提供なら空欄>

    ## 要件情報
    <Issue/PR 本文の要点>
  """
)
```

### 汎用 reviewer との並列起動（PR レビュー時）

```
# 同一メッセージ内で並列起動（互いに独立、結果統合は呼び出し側で）
Agent(subagent_type: "dev-workflow:code-reviewer", prompt: "...")
Agent(
  subagent_type: "terraform-design-reviewer",
  prompt: """
    ベースブランチ: main
    ## git diff
    <事前取得した diff を貼る>
    ## 要件情報
    <Issue/PR 本文の要点>
  """
)
```

両出力は呼び出し側で統合する。重複指摘抑止ルール（[`/README.md`](../../../README.md#pr-レビュー時の-reviewer-併用) 参照）:

- 観点 5（ハードコード）は Terraform 固有定数に限定。汎用 reviewer の「コード重複」観点と境界が重なる場合は本 reviewer を採用しない（汎用に委ねる）。
- 観点 1, 2, 3, 4, 6, 7, 8 は汎用 reviewer の射程外で重複しない。
- それでも同一行・同主旨の指摘が出た場合は片方を採用する（二重表示しない）。

## フィクスチャ駆動の検証

reviewer 動作確認用フィクスチャを `fixtures/` 配下に観点ごとに配置している。

| 観点 # | ディレクトリ | 内容 |
|---|---|---|
| 1 | `fixtures/01-moved-missing/` | `for_each` キー変更 × `moved` ありなし |
| 2 | `fixtures/02-validation-missing/` | optional フィールド追加 × `validation` ありなし |
| 3 | `fixtures/03-lifecycle-coverage/` | `github_repository` の `lifecycle.ignore_changes` 網羅性 |
| 4 | `fixtures/04-for-each-vs-count/` | `for_each` vs `count`（境界 `count = 1` 含む） |
| 5 | `fixtures/05-hardcoded-values/` | `15368` 直書き vs `terraform.tfvars` 経由参照 |
| 6 | `fixtures/06-preset-merge/` | `repository` / `branch_protection` の陽性・陰性（陰性は現行コードの形）と、ADR 0004 §3〜§7 の規約領域ごとの違反・準拠 |
| 7 | `fixtures/07-app-permission-boundary/` | `github_actions_secret` / `github_repository_file` / `github_repository_ruleset` |
| 8 | `fixtures/08-plan-time-risk/` | plan テキスト 4 種（destroy/replace/no-change/未提供） |

各ディレクトリの `expected.md` に期待出力（観点 # / 重大度 / 指摘文言の主旨）を記録。
検証結果の照合表は [`verification.md`](verification.md) を参照。

フィクスチャ拡張子は `.tf.example`（観点 8 のみ `.txt`）で、`terraform validate` の評価対象外。さらに `/.terraformignore` で `docs/agents/` 全体を HCP リモート実行のアップロード対象から除外している。

## resource 型 × 必要 App 権限テーブル（観点 7）

reviewer 定義 §観点 7 に埋め込まれた静的テーブルの導出元:

- [`integrations/github` provider 公式ドキュメント](https://registry.terraform.io/providers/integrations/github/latest/docs) — 各 resource ページの "Import" 節・"Argument Reference"・概要記述に散在する権限注記
- [provider ソースリポジトリ `integrations/terraform-provider-github`](https://github.com/integrations/terraform-provider-github) の `github/*.go` API クライアントコード（CRUD で呼ぶ REST/GraphQL エンドポイントから必要権限を逆引き）
- [GitHub Apps permissions reference](https://docs.github.com/en/rest/overview/permissions-required-for-github-apps) — REST エンドポイント × 必要 App permission の公式マッピング
- GitHub REST API ドキュメントの各エンドポイント "Fine-grained access tokens require ..." 節

provider バージョン更新時はテーブルの見直し起点として上記を確認すること。

## 設計判断履歴

- 配置先: `.claude/agents/` プロジェクトローカル（Issue #20 の確定事項。プラグイン化への移行余地は残す）
- 起動経路: `.tf` 差分検出時に手動 `Agent` 起動（自動 hook 化は将来検討）
- AC5 重複抑止: 観点定義の相互排他 + 運用ルール（同主旨指摘は片方採用）
- 観点を不変条件で書き、実現形は実行時に ADR・実コードを読ませる（#79）。ADR 0004 の規約を観点定義へ書き写す案は、ADR を改訂するたびに観点定義の改訂が要る状態を再生産するため採らなかった

## 関連ドキュメント

- ADR 0001（観点 1 / 3 / 6 の一次情報）: [`docs/adr/0001-repository-resource-structure.md`](../../adr/0001-repository-resource-structure.md)
- ADR 0004（観点 6 の一次情報）: [`docs/adr/0004-terraform-module-structure-policy.md`](../../adr/0004-terraform-module-structure-policy.md)
- リポジトリ運用フロー: [`/README.md`](../../../README.md)
