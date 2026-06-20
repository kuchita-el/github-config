# terraform-design-reviewer

Terraform 変更を伴う PR の **設計逸脱を機械的に検出する** プロジェクトローカル subagent。

- 定義: [`/.claude/agents/terraform-design-reviewer.md`](../../../.claude/agents/terraform-design-reviewer.md)
- 起動形: `Agent(subagent_type: "terraform-design-reviewer", description: ..., prompt: ...)`
- 位置付け: 既存 `dev-workflow:code-reviewer`（汎用）を置換せず、`.tf` 固有観点の補完として並列起動する
- 関連 Issue: [#20](https://github.com/kuchita-el/github-config/issues/20)

## 観点サマリ

| # | 観点 | 重大度 | 検出条件の要旨 | 参照一次情報 |
|---|---|---|---|---|
| 1 | `moved` ブロック不在 | blocker | リソース名・`for_each` キー変更時に対応 `moved` ブロックが無い | Terraform 公式 [Refactoring](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) |
| 2 | `variable` の `validation` 不足 | warning | 列挙・範囲・相互排他等の不変条件がある型に `validation` が無い | [`variables.tf`](../../../variables.tf) L38-44 |
| 3 | `lifecycle.ignore_changes` 網羅性 | blocker | `github_repository` に `visibility`/`archived` の `ignore_changes` が無い | [ADR 0001](../../adr/0001-repository-resource-structure.md) §3 |
| 4 | `for_each` vs `count` | warning | 固有キーを持つ要素が `count = N`（N≥2）で生成。`count = 1` は許容 | [`branch_protection.tf`](../../../branch_protection.tf) L4-50 |
| 5 | ハードコード値の抽出 | suggestion | Terraform 固有のリテラル定数・環境依存値が resource 内に直書き | [`terraform.tfvars`](../../../terraform.tfvars) L11/L27 |
| 6 | preset 上書き経路の一貫性 | blocker | `merge() + null除去` または `ovr.X != null ? ovr.X : base.X` から逸脱 | [ADR 0001](../../adr/0001-repository-resource-structure.md) §1 / [`locals.tf`](../../../locals.tf) L36-60 |
| 7 | App 権限境界違反 | blocker | App スコープ（Administration RW + Metadata R）の範囲外 resource 追加 | [`README.md`](../../../README.md) §設計思想, §初期セットアップ §3 |
| 8 | plan-time リスク | warning / blocker | HCP plan 出力に destroy/replace 兆候。`import.tf` 連携時は blocker | reviewer 定義 §観点 8 |

## 起動例

### 単独起動

```
Agent(
  subagent_type: "terraform-design-reviewer",
  description: "Review TF diff for PR #N",
  prompt: |
    ベースブランチ: main
    要件情報: <Issue/PR 本文の要点>
    HCP plan 出力: <あれば貼り付け、なければ「未提供」>

    git diff main...HEAD で .tf 差分を取得し観点 1〜8 を評価せよ。
)
```

### 汎用 reviewer との並列起動（PR レビュー時）

```
# 同一メッセージ内で並列起動（互いに独立、結果統合は呼び出し側で）
Agent(subagent_type: "code-reviewer", prompt: ...)
Agent(subagent_type: "terraform-design-reviewer", prompt: ...)
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
| 6 | `fixtures/06-preset-merge/` | `merge()` パターン (A) と三項演算子パターン (B) の陽性/陰性 |
| 7 | `fixtures/07-app-permission-boundary/` | `github_actions_secret` / `github_repository_file` / `github_repository_ruleset` |
| 8 | `fixtures/08-plan-time-risk/` | plan テキスト 4 種（destroy/replace/no-change/未提供） |

各ディレクトリの `expected.md` に期待出力（観点 # / 重大度 / 指摘文言の主旨）を記録。
検証結果の照合表は [`verification.md`](verification.md) を参照（全 22 ケース PASS）。

フィクスチャ拡張子は `.tf.example`（観点 8 のみ `.txt`）で、`terraform validate` の評価対象外。さらに `/.terraformignore` で `docs/agents/` 全体を HCP リモート実行のアップロード対象から除外している。

## resource 型 × 必要 App 権限テーブル（観点 7）

reviewer 定義 §観点 7 に埋め込まれた静的テーブルの導出元:

- [`integrations/github` provider 公式ドキュメント](https://registry.terraform.io/providers/integrations/github/latest/docs) — 各 resource ページ末尾の "GitHub API Token Scopes" 節
- [GitHub Apps permissions reference](https://docs.github.com/en/rest/overview/permissions-required-for-github-apps)

provider バージョン更新時はテーブルの見直し起点として上記を確認すること。

## 設計判断履歴

- 配置先: `.claude/agents/` プロジェクトローカル（Issue #20 の確定事項。プラグイン化への移行余地は残す）
- 起動経路: `.tf` 差分検出時に手動 `Agent` 起動（自動 hook 化は将来検討）
- AC5 重複抑止: 観点定義の相互排他 + 運用ルール（同主旨指摘は片方採用）

## 関連ドキュメント

- 実装プラン: [`docs/plans/issue-20.md`](../../plans/issue-20.md)
- ADR 0001（観点 3 / 6 の一次情報）: [`docs/adr/0001-repository-resource-structure.md`](../../adr/0001-repository-resource-structure.md)
- リポジトリ運用フロー: [`/README.md`](../../../README.md)
