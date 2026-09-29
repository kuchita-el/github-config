# terraform-design-reviewer

Terraform 変更を伴う PR の **設計逸脱を機械的に検出する** プロジェクトローカル subagent。

- 定義: [`/.claude/agents/terraform-design-reviewer.md`](../../../.claude/agents/terraform-design-reviewer.md)
- 起動形: `Agent(subagent_type: "terraform-design-reviewer", description: ..., prompt: ...)`
- 位置付け: 既存 `dev-workflow:code-reviewer`（汎用）を置換せず、`.tf` 固有観点の補完として並列起動する
- 関連 Issue: [#20](https://github.com/kuchita-el/github-config/issues/20)（新設）、[#79](https://github.com/kuchita-el/github-config/issues/79)（観点を不変条件で書く）、[#103](https://github.com/kuchita-el/github-config/issues/103)（判定の根拠を一般的な出典へ移す）、[#109](https://github.com/kuchita-el/github-config/issues/109)（観点 9 に provider schema の非推奨の印を加える）

## 観点サマリ

各観点は「守る不変条件」を判定の軸とし、一般的な Terraform 設計の観点で判定する。判定の根拠は Terraform・provider・GitHub の公式ドキュメント等の一般的な出典に限り、本リポ固有の規約（設計記録・設計仕様・運用手順）への準拠は判定しない（Issue [#103](https://github.com/kuchita-el/github-config/issues/103)）。準拠の確認は、呼び出し側が汎用 reviewer に参照先を渡して委ねる（[`/README.md`](../../../README.md#pr-レビュー時の-reviewer-併用)「PR レビュー時の reviewer 併用」節）。worktree の既存コードは差分を読み解くための文脈として読むが、判定の根拠にはしない。下表は要旨で、判定手順・検出条件と出典の詳細は reviewer 定義の各観点にある。

| # | 観点 | 重大度 | 守る不変条件の要旨 | 判定の根拠（一般的な出典） |
|---|---|---|---|---|
| 1 | `moved` ブロック不在 | blocker | 既存リソースがアドレスの付け替えだけで破棄・再作成されない | Terraform 公式 [Refactor modules](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)・[`moved` ブロック](https://developer.hashicorp.com/terraform/language/block/moved) |
| 2 | `variable` の `validation` 不足 | warning | 入力値の暗黙の制約に反する入力が plan 前に拒否される | Terraform 公式 [input variables](https://developer.hashicorp.com/terraform/language/values/variables) の custom validation rules・[`language/validate`](https://developer.hashicorp.com/terraform/language/validate) の「Input variable validation」 |
| 3 | lifecycle 保護の縮退 | warning | 既存の lifecycle 保護（`ignore_changes`・`prevent_destroy`）が理由の示されないまま外されたり弱められたりしない。変更前から存在する同型 resource が持つ保護を欠く resource の追加も検出する | Terraform 公式 [lifecycle meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)・[Remove a resource from state](https://developer.hashicorp.com/terraform/language/state/remove)・[`removed` ブロック](https://developer.hashicorp.com/terraform/language/block/removed) |
| 4 | `for_each` vs `count` | warning | 固有の識別子を持つ要素のインスタンスが識別子で追跡される。`count = 1` は許容 | Terraform 公式 [`count`](https://developer.hashicorp.com/terraform/language/meta-arguments/count)・[`for_each`](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) |
| 5 | ハードコード値の抽出 | suggestion | Terraform 固有の定数の宣言場所が定まり、リソース定義の本体に散らばらない | Terraform 公式 [local values](https://developer.hashicorp.com/terraform/language/values/locals)・[input variables](https://developer.hashicorp.com/terraform/language/values/variables)・[スタイルガイド](https://developer.hashicorp.com/terraform/language/style) |
| 6 | 既定値の合成と単一の置き場所 | blocker（判定の限界は warning） | 未指定（null）が揃えた値を消さない、揃えた値の正の置き場所が一つ、必須だった宣言を省略可能にしない | Terraform 公式 [`merge` 関数](https://developer.hashicorp.com/terraform/language/functions/merge)・[型制約 `optional`](https://developer.hashicorp.com/terraform/language/expressions/type-constraints)・[Types and Values の `null`](https://developer.hashicorp.com/terraform/language/expressions/types) |
| 7 | 差分が要する provider 権限の列挙 | warning | 差分が provider に新たに要求する権限が、レビューの時点で漏れなく列挙される。付与状況との照合は呼び出し側で行う | [GitHub Apps permissions reference](https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps)・[GitHub REST API](https://docs.github.com/en/rest) の各エンドポイントのドキュメント・`integrations/github` provider の[公式ドキュメント](https://registry.terraform.io/providers/integrations/github/latest/docs)と[ソース](https://github.com/integrations/terraform-provider-github) |
| 8 | plan-time リスク | warning / blocker | 意図しない破棄・再作成を伴って適用されない。PR の `import` ブロックの対象アドレスが plan 出力で置換・破棄されるときは blocker | Terraform 公式 [import](https://developer.hashicorp.com/terraform/language/import)・[`import` ブロック](https://developer.hashicorp.com/terraform/language/block/import)・[`terraform plan`](https://developer.hashicorp.com/terraform/cli/commands/plan) |
| 9 | provider 非推奨の新規使用 | warning | provider が非推奨とした属性・resource（data source を含む）を差分で新たに使い始めない。入力は `terraform validate -json` の出力（validate 経路）と、`terraform providers schema -json` から抜き出した非推奨スキーマ一覧（スキーマ経路。値の由来によらず、追加行に書かれた属性・block・型を照合する）。両方とも未提供なら未評価。非推奨スキーマ一覧が無いと、値が validate の時点で決まらない属性は、警告が出ない場合は新規使用を検出できない（判定の限界） | Terraform 公式の provider 開発ドキュメント「Deprecations, Removals, and Renames」（[SDKv2](https://developer.hashicorp.com/terraform/plugin/sdkv2/best-practices/deprecations)・[Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework/deprecations)）・provider の公式ドキュメントと CHANGELOG・[`terraform validate`](https://developer.hashicorp.com/terraform/cli/commands/validate)・[`terraform providers schema`](https://developer.hashicorp.com/terraform/cli/commands/providers/schema) |

## 起動例

### 呼び出し側の事前準備

reviewer は `Bash` ツールを持たないため、呼び出し側で `git diff`・validate 出力・非推奨スキーマ一覧を事前取得する:

```bash
git diff main...HEAD -- '*.tf' '*.tfvars' > /tmp/tf-diff.txt
terraform validate -json   # PR 適用後（HEAD）の作業ディレクトリで実行し、出力を ## validate 出力 に貼る
# 非推奨スキーマ一覧: terraform providers schema -json の出力を extract-deprecations.jq で抜き出し、## 非推奨スキーマ一覧 に貼る
```

validate の実行に要る初期化と環境変数は [`/README.md`](../../../README.md#pr-レビュー時の-reviewer-併用)「PR レビュー時の reviewer 併用」節を参照。`## validate 出力` には `terraform validate -json` の出力（JSON）をそのまま貼る。リポジトリのルート以外のディレクトリで validate を実行した場合は、見出しの後の最初の行（JSON の前）に `実行ディレクトリ: <リポジトリのルートからの相対パス>`（例: `実行ディレクトリ: infra`）の1行を置き、その次の行から JSON を貼る。reviewer は見出しの後の最初の空でない行が `実行ディレクトリ:` で始まるときだけそれを実行ディレクトリとして読み、JSON はその行を除いて読む。この行が無ければ、reviewer はリポジトリのルートで実行したものとみなす（読み方の定めは reviewer 定義の「入力」節）。人間向けの出力（`-json` なし）や validate が失敗した出力を貼ると、観点 9 の validate 経路は未評価になる。

非推奨スキーマ一覧の取得手順（型の書き出し・schema を取得するディレクトリ・サンドボックスの制約）も同じ節を参照。`## 非推奨スキーマ一覧` には [`extract-deprecations.jq`](extract-deprecations.jq) の出力（JSON）をそのまま貼る（形式の定めは reviewer 定義の「入力」節）。貼らない場合、観点 9 は validate 経路だけで評価され、値が validate の時点で決まらない属性の非推奨は、警告が出ない場合は検出できない。

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

    ## validate 出力（任意）
    実行ディレクトリ: <リポジトリのルート以外で実行した場合だけ書く。ルートで実行した場合はこの行を省く>
    <`terraform validate -json` の出力（JSON）。未提供なら空欄>

    ## 非推奨スキーマ一覧（任意）
    <`extract-deprecations.jq` の出力（JSON）。未提供なら空欄>

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
    ## plan 出力（任意）
    <HCP plan 出力テキスト>
    ## validate 出力（任意）
    実行ディレクトリ: <リポジトリのルート以外で実行した場合だけ書く。ルートで実行した場合はこの行を省く>
    <`terraform validate -json` の出力（JSON）>
    ## 非推奨スキーマ一覧（任意）
    <`extract-deprecations.jq` の出力（JSON）>
    ## 要件情報
    <Issue/PR 本文の要点>
  """
)
```

両出力は呼び出し側で統合する。重複指摘抑止ルール（[`/README.md`](../../../README.md#pr-レビュー時の-reviewer-併用) 参照）:

- 観点 5（ハードコード）は Terraform 固有定数に限定。汎用 reviewer の「コード重複」観点と境界が重なる場合は本 reviewer を採用しない（汎用に委ねる）。
- 汎用 reviewer に本リポ固有の規約への準拠の確認を委ねて参照先を渡した場合、次の観点はその準拠の指摘と同じ行に重なりうる。重なった場合は、下記の同一行・同主旨の運用ルールに従う（観点 7 を除く）。
  - 観点 2（`variable` の `validation` 不足）: 入力の検証の定め
  - 観点 3（lifecycle 保護の縮退）: 保護する属性の定め
  - 観点 6（既定値の合成と単一の置き場所）: 揃える値の置き場所や上書きの経路の定め
  - 観点 7（差分が要する provider 権限の列挙）: App 等に与える権限の定め。観点 7 の列挙は、汎用 reviewer の指摘と重なっても捨てずに両方を残す（統合段で付与状況と照合する入力になるため。運用ルールの例外）
  - 観点 8（plan-time リスク）: 既存リソースの取り込みの手順の定め
- 観点 1, 4, 9 は Terraform 固有の設計の観点であり、汎用 reviewer の汎用の観点（コード重複等）とは重ならない。準拠の指摘と同じ行に重なった場合も、下記の運用ルールに従う。
- 同一行・同主旨の指摘が出た場合は片方を採用する（二重表示しない。観点 7 の列挙は上記の例外）。

## フィクスチャ駆動の検証

reviewer 動作確認用フィクスチャを `fixtures/` 配下に観点ごとに配置している。ディレクトリ名（`03-lifecycle-coverage`・`06-preset-merge`・`07-app-permission-boundary`）は、検証記録からのパスを保つため改訂前の観点名のまま残している。

| 観点 # | ディレクトリ | ケース（ファイル） | 期待 |
|---|---|---|---|
| 1 | `fixtures/01-moved-missing/` | `for_each` キー変更 × `moved` なし（`positive.tf.example`）／あり（`negative.tf.example`） | blocker ／ 発火なし |
| 2 | `fixtures/02-validation-missing/` | optional フィールド追加 × `validation` なし（`positive.tf.example`）／あり（`negative.tf.example`） | warning ／ 発火なし |
| 3 | `fixtures/03-lifecycle-coverage/` | 既存の保護を外す（`positive.tf.example`） | warning |
| 3 | 同上 | 保護を欠く同型の追加（`positive-same-type.tf.example`、適用後ケース `positive-same-type-applied.diff`） | warning |
| 3 | 同上 | 同じ保護を持つ同型の追加（`negative-same-type.tf.example`、適用後ケース `negative-same-type-applied.diff`） | 発火なし |
| 3 | 同上 | 保護を変えない変更（`negative.tf.example`） | 発火なし |
| 4 | `fixtures/04-for-each-vs-count/` | 固有キーの要素を `count` で作る（`positive.tf.example`）／`for_each`（`negative.tf.example`）／境界 `count = 1`（`boundary-count-one.tf.example`） | warning ／ 発火なし ／ 発火なし |
| 5 | `fixtures/05-hardcoded-values/` | `15368` 直書き（`positive.tf.example`）／`terraform.tfvars` 経由参照（`negative.tf.example`） | suggestion ／ 発火なし |
| 6 | `fixtures/06-preset-merge/` | 必須だった宣言の optional 化（`positive-repository.tf.example`）、未指定の null が揃えた値を消す（`positive-branch-protection.tf.example`）、揃える値をリポごとの入力の既定値に置く（`positive-default-as-policy.tf.example`） | blocker |
| 6 | 同上 | 全リポ共通値への属性追加（`negative-repository.tf.example`・`negative-branch-protection.tf.example`）、null を除いて重ねるリポごとの上書き（`negative-override-with-fallback.tf.example`）、命名だけがリポジトリの規約と異なる設定種別の追加（`negative-local-convention.tf.example`）、タグ保護の追加（`adr0004-compliant-tag-protection.tf.example`） | 発火なし |
| 7 | `fixtures/07-app-permission-boundary/` | 変更前のコードで使っていない型の追加: `github_actions_secret`（`positive-secret.tf.example`、適用後ケース `positive-secret-applied.diff`）、`github_repository_file`（`positive-file.tf.example`） | warning（必要な権限の列挙） |
| 7 | 同上 | 変更前から使っている型 `github_repository_ruleset` の追加（`negative-ruleset.tf.example`）、名前の付け替えと `moved`（適用後ケース `negative-rename-applied.diff`） | 発火なし |
| 8 | `fixtures/08-plan-time-risk/` | plan テキスト 4 種: destroy（`plan-positive-destroy.txt`）／replace（`plan-positive-replace.txt`）／no-change（`plan-negative-nochange.txt`）／未提供（`plan-empty.txt`） | warning ／ warning ／ 発火なし ／ 未評価 |
| 8 | 同上 | `import` ブロック連携の格上げ: `import-block.tf.example` を差分、`plan-positive-replace.txt` を plan 出力として組で渡す | blocker |
| 9 | `fixtures/09-provider-deprecation/` | 各ケースは `<ケース>.diff`（差分）・`validate-<ケース>.txt`（`terraform validate -json` の出力）・`schema-<ケース>.txt`（非推奨スキーマ一覧）の組。属性の新規使用（`positive-attribute`）、resource の新規使用（`positive-resource`） | warning |
| 9 | 同上 | 値が `each.value` に由来する属性の新規使用（`positive-attribute-each-value`）、値が input variable に由来する属性の新規使用（`positive-attribute-variable`）。validate の警告は無く、スキーマ経路だけが検出する | warning |
| 9 | 同上 | 非推奨でない属性の追加（`negative`）、変更前からの使用（`boundary-preexisting`）、変更前からの使用の書き換え（`boundary-rewritten-preexisting`） | 発火なし |
| 9 | 同上 | 変更前からの使用と新規の使用の同居（`mixed-preexisting-and-new`） | 新規の使用の行だけ warning |
| 9 | 同上 | 非推奨スキーマ一覧の未提供（`positive-attribute-each-value` の `.diff` と `validate-*.txt` だけを渡す） | 発火なし（validate 経路だけで評価し、判定の限界を併記） |
| 9 | 同上 | 両方の未提供（`positive-attribute.diff` だけを渡す） | 未評価 |

各ディレクトリの `expected.md` に期待出力（観点 # / 重大度 / 指摘文言の主旨）と、末尾の「期待する判定根拠」節に判定根拠として期待する一般的な出典を記録。検証結果の照合表は [`verification.md`](verification.md) を参照。

### フィクスチャの形式と評価時の渡し方

- `.tf.example`: PR の内容を HCL で示す。worktree は変更せず、fixture を PR の内容として reviewer に渡す（worktree＋fixture を PR 適用後の状態として評価する）。`（PR 後…）` の節見出しの下は worktree の同じファイルの該当箇所を書き換えた後の内容、`（PR で新規追加）` の節見出しの下は新しく加えるファイルの内容として読む。
- `.txt`（観点 8）: HCP plan 出力のテキスト。`## plan 出力` として渡す。
- `.diff`・`validate-*.txt`・`schema-*.txt`（観点 9）: `.diff` を `## git diff`、対応する `validate-*.txt` を `## validate 出力`、対応する `schema-*.txt` を `## 非推奨スキーマ一覧` として渡す。worktree は変更しない。`schema-*.txt` は、`.diff` が触れた `.tf` ファイル（PR 適用後）にある型を [`extract-deprecations.jq`](extract-deprecations.jq) に渡した出力。
- `*-applied.diff`（観点 3・7 の適用後ケース）: 評価の前に `git apply` で worktree に置いて PR 適用後の状態を作り、同じ `.diff` を `## git diff` として渡す（下記「適用後ケースの評価手順」）。
- `.diff` の先頭の `#` で始まるコメント行は、PR の内容と評価の前提の説明であり、差分の本体ではない。

フィクスチャ拡張子は `.tf.example`・`.diff`・`.txt`（`*.tf` ではない）で、`terraform validate` の評価対象外。さらに `/.terraformignore` で `docs/agents/` 全体を HCP リモート実行のアップロード対象から除外している。

### worktree の既存の定義との名前の重なり

`.tf.example` の fixture は worktree＋fixture を PR 適用後の状態として評価するため、fixture が新規追加として示す定義の名前（resource の `(TYPE, NAME)`、`locals` の名前、`variable` の名前、ファイル名、Ruleset 名）は worktree の既存の定義と重ねない。既存の定義の書き換えとして示す場合は、`（PR 後…）` の節見出しの下に置く。名前や内容を保つ理由があって新規追加の定義が worktree の既存の定義と重なる場合は、fixture の冒頭コメントに「評価では worktree の `<ファイル>` の代わりに下記を扱う」と明記する（例: 06 `adr0004-compliant-tag-protection.tf.example`・07 `negative-ruleset.tf.example` の `tag_protection.tf`）。`*-applied.diff` の resource ラベルとファイル名も worktree の既存の名前と重ねない（新規ファイルの差分は、同名のファイルが worktree にあると適用できない）。

### 適用後ケースの評価手順

1. `git status --short` で、worktree の追跡ファイルに未コミットの変更が無いことを確かめる。
2. `git apply --check <fixture の .diff>` で、現在の worktree に適用できることを確かめる。失敗した場合は評価せず、下記「適用後ケースの作り直し」で `.diff` を作り直してから進む。
3. `git apply <fixture の .diff>` で worktree に置く（新規ファイルの差分はそのファイルができ、既存ファイルの差分はそのファイルが書き換わる）。
4. 同じ `.diff` を `## git diff` として reviewer に渡して評価する。
5. 評価後に元に戻す。新規ファイルの差分（03 `positive-same-type-applied.diff`・`negative-same-type-applied.diff`、07 `positive-secret-applied.diff`）は置いたファイルを削除し、既存ファイルの差分（07 `negative-rename-applied.diff`）は `git restore <ファイル>` で戻す。`git status --short` で `.tf` の変更・未追跡の `.tf` が無いことを確かめる（一時的に置いた `.tf` を残すと Terraform の構成として読み込まれ、コミットすれば適用の対象になる）。

### 適用後ケースの作り直し

worktree の追跡ファイルが変わると、`*-applied.diff` が適用できなくなることがある。例: `negative-rename-applied.diff` は `dependabot_security_updates.tf` のコメント行を文脈行に使うため、そのコメントが変わると適用できない。新規ファイルの差分も、worktree に同名のファイルができると適用できない。`git apply --check` が失敗したら、次の手順で作り直す。

1. 状態を作る: 新規ファイルの差分は、worktree ルートに、差分が新規追加するファイル（`+++ b/<ファイル>`）と同じ名前・同じ内容の一時ファイルを作る（内容は元の `.diff` の追加行、または対応する `.tf.example` の追加ブロック）。worktree に同じ名前のファイルができて適用に失敗した場合は、worktree の既存の名前と重ならない名前に改めて作り、`expected.md` の記載（ファイル名など）も改める。既存ファイルの差分は、その追跡ファイルを一時的に編集し、fixture の冒頭コメントが述べる変更を現行の本文に加える（例: `negative-rename-applied.diff` は resource のラベルを `security_updates` に改め、対応する `moved` ブロックを同じファイルに加える）。
2. 差分を取る: 新規ファイルは `git diff --no-index /dev/null <ファイル>`（差分があると終了コード 1 を返すが正常）、既存ファイルは `git diff -- <ファイル>`。
3. 保存する: 出力の先頭に、PR の内容だけを中立に記す `#` のコメント行を付けて、fixture の `.diff` に上書き保存する（`(positive)`/`(negative)` の区分、期待、判定の手掛かりは書かない）。
4. 元に戻す: 一時ファイルを削除し、編集した追跡ファイルは `git restore <ファイル>` で戻す。`git status --short` で `.tf` の変更・未追跡の `.tf` が無いことを確かめる。
5. `git apply --check <fixture の .diff>` で適用できることと、`expected.md` の行番号・ファイル名などの記述と食い違わないことを確かめてから、作り直した `.diff`（と改めた `expected.md`）をコミットし、評価手順に戻る。

## resource 型 × 必要権限テーブル（観点 7）

reviewer 定義の観点 7 に埋め込まれた静的テーブル（差分で新たに使い始める resource 型の必要な権限を引く表。付与状況との照合には使わない）の導出元:

- [GitHub Apps permissions reference](https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps) — GitHub App の権限ごとの REST エンドポイントとアクセス（read・write）の公式の対応。表の権限名はこの reference の権限名に合わせる
- GitHub REST API ドキュメントの各エンドポイントの "Fine-grained access tokens for ..." 節 — エンドポイントが要する権限の組（すべてを要するか、いずれか1つで足りるか）
- [`integrations/github` provider 公式ドキュメント](https://registry.terraform.io/providers/integrations/github/latest/docs) — 各 resource ページの権限に関する注記
- [provider ソースリポジトリ `integrations/terraform-provider-github`](https://github.com/integrations/terraform-provider-github) の `github/resource_github_<型>.go` — 作成・読み取り・更新・削除・取り込みで呼ぶ REST・GraphQL のエンドポイントから、上記の reference とドキュメントで必要な権限を引く

表は #103 で provider v6.12.1 のソースと上記の reference で照合した。provider バージョン更新時はテーブルの見直し起点として上記を確認すること。

## 設計判断履歴

- 配置先: `.claude/agents/` プロジェクトローカル（Issue #20 の確定事項。プラグイン化への移行余地は残す）
- 起動経路: `.tf` 差分検出時に手動 `Agent` 起動（自動 hook 化は将来検討）
- AC5 重複抑止: 観点定義の相互排他 + 運用ルール（同主旨指摘は片方採用）
- 観点を不変条件で書き、実現形は実行時に ADR・実コードを読ませる（#79）。ADR 0004 の規約を観点定義へ書き写す案は、ADR を改訂するたびに観点定義の改訂が要る状態を再生産するため採らなかった
- 判定の根拠を一般的な出典へ移す（#103）: #79 の方式のうち、実現形（その時点の正しい書き方）を実行時に ADR・実コードから読む点を改め、判定の根拠を Terraform・provider・GitHub の公式ドキュメント等の一般的な出典に限った。観点を不変条件で書き、不変条件を判定の軸とする点は #79 から引き継いでいる。本リポ固有の規約への準拠は reviewer では判定せず、呼び出し側が汎用 reviewer に参照先を渡して確認する（[`/README.md`](../../../README.md#pr-レビュー時の-reviewer-併用)）。worktree の既存コードは差分を読み解く文脈としてだけ読み、判定の根拠にしない。あわせて観点 3 を lifecycle 保護の縮退の検出（warning）に、観点 6 を既定値の合成と単一の置き場所（blocker）に、観点 7 を差分が要する provider 権限の列挙（warning。付与状況との照合は呼び出し側）に改め、観点 9（provider 非推奨の新規使用、warning）を加えた。
  - 観点を足しすぎていないかの確認: tflint の `recommended` プリセット（公式ルール一覧）と観点 1〜8 を突き合わせ、重複は無く、削る観点は無かった。
  - 観点として追加しなかった候補と再検討の条件: 秘密値の `sensitive` 指定は、秘密を受け取る variable・output を導入するときに再検討する。plan 時に値が確定しない `for_each` キーは、Speculative Plan を経ない適用経路ができたときに再検討する（#103 の時点では、plan の `Invalid for_each argument` で必ず止まる）。
  - 本リポ専用の準拠確認エージェントの新設は採らず、汎用 reviewer に参照先を渡す形にした。運用で確認漏れの実績が出たら別 Issue で再検討する。

## 関連ドキュメント

- 判定の出典: reviewer 定義（[`/.claude/agents/terraform-design-reviewer.md`](../../../.claude/agents/terraform-design-reviewer.md)）の各観点の「判定の根拠」
- 本リポ固有の規約への準拠の確認: [`/README.md`](../../../README.md#pr-レビュー時の-reviewer-併用)「PR レビュー時の reviewer 併用」節（汎用 reviewer に渡す参照先）
- 検証記録: [`verification.md`](verification.md)
- リポジトリ運用フロー: [`/README.md`](../../../README.md)
