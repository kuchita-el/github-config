# 観点 7（差分が要する provider 権限の列挙）の期待出力

`.tf.example` のケースは、worktree (post) を main のままとし、fixture を PR の内容として reviewer に渡したときの期待出力。fixture の `（PR 後…）` の節見出しの下の記述は、worktree の同じファイルの該当箇所を書き換えた後の内容として、`（PR で新規追加）` の節見出しの下の記述は、新しく加えるファイルの内容として読む。`*-applied.diff` のケースは、評価の前に `git apply` で差分を worktree に適用し、その `.diff` を `## git diff` として渡したときの期待出力（評価後は適用した変更を元に戻す）。`.diff` の先頭の `#` で始まるコメント行は PR の内容の説明であり、差分の本体ではない。

本ファイルは照合用であり、評価者（reviewer）には渡さない。PASS 条件は、発火の有無・観点番号・重要度の一致と、発火するケースで列挙した権限が、そのケースの「列挙する権限」と一致すること。

列挙した権限が、認証に使う GitHub App 等に与えられているかの照合は、reviewer ではなく呼び出し側の統合段で行う。reviewer の期待出力は、差分で新たに使い始める resource 型ごとの必要な権限の列挙までであり、照合の結果、権限が足りないという判定、blocker、resource の取り除きや権限の追加の提案を含まない。

## 陽性 1: `github_actions_secret` の追加 (`positive-secret.tf.example`)

- **観点 #**: 7
- **重大度**: warning
- **対象**: `actions_secrets.tf` で追加した `github_actions_secret.actions_secrets`
- **列挙する権限**: Secrets（書き込み）、Metadata（読み取り）
- **指摘文言の主旨**: 変更前のコードで使っていない resource 型 `github_actions_secret` を使い始めている。`github_actions_secret` の操作に要する権限: Secrets（書き込み）、Metadata（読み取り）。付与状況との照合は呼び出し側で行うこと。
- **判定の経過**: worktree (post) の走査範囲（ルートモジュールの `*.tf`）に `github_actions_secret` の resource ブロックは無く、差分の削除集合 R も空のため、変更前から存在する同型 resource が無い。

## 陽性 2: `github_repository_file` の追加 (`positive-file.tf.example`)

- **観点 #**: 7
- **重大度**: warning
- **対象**: `codeowners.tf` で追加した `github_repository_file.codeowners`
- **列挙する権限**: Contents（書き込み）、Metadata（読み取り）
- **指摘文言の主旨**: 変更前のコードで使っていない resource 型 `github_repository_file` を使い始めている。`github_repository_file` の操作に要する権限: Contents（書き込み）、Metadata（読み取り）。付与状況との照合は呼び出し側で行うこと。
- **判定の経過**: worktree (post) の走査範囲に `github_repository_file` の resource ブロックは無く、R も空のため、変更前から存在する同型 resource が無い。

## 陽性 3: `github_actions_secret` の追加、適用後 (`positive-secret-applied.diff`)

- **評価時の配置**: 評価の前に `git apply` で差分を worktree に置く（worktree ルートに `actions_secrets.tf` ができ、`github_actions_secret.deploy_token` を含む）。評価後は置いたファイルを取り除く。
- **観点 #**: 7
- **重大度**: warning
- **対象**: `actions_secrets.tf` で追加した `github_actions_secret.deploy_token`
- **列挙する権限**: Secrets（書き込み）、Metadata（読み取り）
- **指摘文言の主旨**: 陽性 1 と同じ（対象は `github_actions_secret.deploy_token`）。
- **判定の経過**: worktree (post) の走査範囲にある `github_actions_secret.deploy_token` は、差分の `+resource` ヘッダで作る追加集合 A にあるため、変更前から存在する同型 resource に数えない。worktree の fixture 配下の例示ファイル（`positive-secret.tf.example`）にある同型の行頭 `resource`（`github_actions_secret.actions_secrets`）は、走査範囲外のため数えない。R は空。したがって変更前から存在する同型 resource は無く、発火する。
- **判別する誤り**: 追加集合 A を除かずに worktree の同型ブロックを数えると、`deploy_token` を既存と数えて発火しない。走査範囲をルートモジュールに限らずに worktree 全体の行頭 `resource` を数えると、例示の `actions_secrets`（A に無いラベル）を既存と数えて発火しない。いずれの誤りでも本ケースは発火なしになるため、発火すれば両方の限定が働いている。

## 陰性 1: タグ保護の追加 (`negative-ruleset.tf.example`)

- 期待出力: 「観点 7: ✅」（観点 7 の指摘なし）
- 理由: 追加した `github_repository_ruleset.tag_protection` の型 `github_repository_ruleset` は、変更前から存在する同型 resource（`branch_protection.tf` の `github_repository_ruleset.branch_protection`。走査範囲にあり A に含まれない）を持つため、差分で新たに使い始める型に当たらない。
- 前提の読み方: fixture の冒頭コメントのとおり、`tag_protection.tf` を本 PR で新規追加するファイルとし、評価では worktree の `tag_protection.tf` の代わりに fixture の内容を PR 後の `tag_protection.tf` として扱う。`github_repository_ruleset.tag_protection` は本 PR が追加したもの（A にあるもの）であり、変更前から存在する同型 resource に数えない。

## 陰性 2: 名前の付け替え、適用後 (`negative-rename-applied.diff`)

- **評価時の配置**: 評価の前に `git apply` で差分を worktree に適用する（`dependabot_security_updates.tf` の resource のラベルが `security_updates` になり、`moved` ブロックが加わる）。評価後は `git restore dependabot_security_updates.tf` で戻す。
- 期待出力: 「観点 7: ✅」「観点 1: ✅」（観点 7・観点 1 の指摘なし）
- 理由（観点 7）: 差分の `-resource` ヘッダにある `github_repository_dependabot_security_updates.dependabot_security_updates` は削除集合 R にあり、変更前から存在する同型 resource に数える。worktree (post) の走査範囲にある同型は、A にある `github_repository_dependabot_security_updates.security_updates` の1件だけで、これは数えないが、R の旧ブロックがあるため `github_repository_dependabot_security_updates` は差分で新たに使い始める型に当たらない。
- 理由（観点 1）: R と A に同型・異名の resource が1件ずつあり NAME 変更に当たるが、差分がそれに対応する `moved` ブロック（`from` が旧アドレス、`to` が新アドレス）を追加しているため発火しない。
- **判別する誤り**: 削除集合 R を「変更前から存在する同型 resource」に含めないと、変更前から使っている型を新たに使い始めた型と誤って発火する。

## 期待する判定根拠

発火するケースの指摘は、観点 7 の「判定の根拠」に挙げた次の一般的な出典に基づく（リポジトリ固有の規約文書を根拠にしない）。列挙する権限は、定義の観点 7 の静的表（`integrations/github` provider v6.12.1 のソースが呼ぶエンドポイントを、下記の permissions reference とエンドポイントのドキュメントで引いたもの）による。

- GitHub Apps permissions reference: <https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps>
- GitHub REST API の各エンドポイントのドキュメント（「Fine-grained access tokens for …」の節）: <https://docs.github.com/en/rest>
- `integrations/github` provider 公式ドキュメント（Terraform Registry）: <https://registry.terraform.io/providers/integrations/github/latest/docs>
- `integrations/github` provider のソース（各 resource の実装 `github/resource_github_<型>.go`）: <https://github.com/integrations/terraform-provider-github>
