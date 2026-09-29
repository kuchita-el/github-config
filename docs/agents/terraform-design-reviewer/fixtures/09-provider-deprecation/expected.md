# 観点 9（provider 非推奨の新規使用）の期待出力

各ケースの `.diff` を `## git diff`、対応する `validate-*.txt`（`terraform validate -json` の出力）を `## validate 出力`、対応する `schema-*.txt`（`terraform providers schema -json` の出力から `extract-deprecations.jq` で抜き出した非推奨スキーマ一覧）を `## 非推奨スキーマ一覧` として reviewer に渡したときの期待出力。`.diff` の先頭の `#` で始まるコメント行は PR の内容と評価の前提の説明であり、差分の本体ではない。行番号は PR 適用後のファイルでの行番号。

`schema-*.txt` は、`.diff` が触れた `.tf` ファイル（PR 適用後）にある resource・data source の型を `extract-deprecations.jq` に渡した出力である（provider `integrations/github` v6.12.1 の schema による）。

未提供のケースを除き、validate 経路とスキーマ経路の両方を評価する。総評の観点 9 の欄は「観点9: ✅/❌（validate 経路: 評価、スキーマ経路: 評価）」となる。以下の「観点 9: ✅」は、この経路の状態の併記を略して記す。

## 陽性 1: 属性 (`positive-attribute.diff` + `validate-positive-attribute.txt` + `schema-positive-attribute.txt`)

- **観点 #**: 9
- **重大度**: warning
- **ファイル:行**: `repository.tf:82`
- **突き合わせ**: 診断（`summary` `Argument is deprecated`、`address` `github_repository.this`、`range.filename` `repository.tf`、`range.start.line` 82）の位置が、hunk `@@ -75,10 +75,11 @@` の追加行（78〜82 行目）のうち `vulnerability_alerts = true`（82 行目）に当たる。同じ resource の削除行（桁揃え前の `archived`・`description`・`homepage_url`・`topics` の4行）に `vulnerability_alerts` は無いため、書き換えには当たらない。スキーマ経路でも、82 行目は hunk ヘッダの見出し `resource "github_repository" "this" {` の直下の属性 `vulnerability_alerts` で、一覧の `{"kind": "resource", "type": "github_repository", "target": "attribute", "path": "vulnerability_alerts"}` と一致する。両経路の検出は同じ追加行のため1件にまとめ、文言は validate の警告を使う。
- **指摘文言の主旨**: provider が非推奨とした属性 `vulnerability_alerts` を差分で新たに使っている（provider の案内: `github_repository_vulnerability_alerts` resource を使う）。修正方針は、provider が案内する代替へ移すこと。

## 陽性 2: resource (`positive-resource.diff` + `validate-positive-resource.txt` + `schema-positive-resource.txt`)

- **観点 #**: 9
- **重大度**: warning
- **ファイル:行**: `deployment_branch_policy.tf:1`
- **突き合わせ**: 診断（`summary` `Deprecated Resource`、`address` `github_repository_deployment_branch_policy.sandbox`、`range.filename` `deployment_branch_policy.tf`、`range.start.line` 1）の位置が、新規ファイル（`@@ -0,0 +1,5 @@`）の追加行 `resource "github_repository_deployment_branch_policy" "sandbox" {`（1 行目）に当たる。スキーマ経路でも、1 行目の見出し行は一覧の `{"kind": "resource", "type": "github_repository_deployment_branch_policy", "target": "type", "path": ""}` と一致する。両経路の検出を1件にまとめる。
- **指摘文言の主旨**: provider が非推奨とした resource `github_repository_deployment_branch_policy` を差分で新たに使っている（provider の案内: `github_repository_environment_deployment_policy` resource が代替）。修正方針は、provider が案内する代替へ移すこと。
- **他の観点の発火**: 追加する `github_repository_deployment_branch_policy` は、観点 7 の静的表に無く、worktree のルートモジュールにも同型の resource が無い（差分で新たに使い始める型に当たる）。このため観点 7 が warning（表に無い型の扱い。一次情報で必要な権限を確かめられなければ「必要権限: 未確定」）で発火しうる。本ケースの照合対象は観点 9 とする。

## 陰性 (`negative.diff` + `validate-negative.txt` + `schema-negative.txt`)

- 期待出力: 「観点 9: ✅」（観点 9 の指摘なし）
- 理由: validate 出力の `diagnostics` が空で、非推奨の警告が無い。スキーマ経路でも、差分が追加した `allow_update_branch` は一覧の `deprecated` に無い（`github_repository` の非推奨の属性は `default_branch`・`has_downloads`・`ignore_vulnerability_alerts_during_read`・`private`・`vulnerability_alerts`、block は `pages`）。

## 境界: 変更前からの使用 (`boundary-preexisting.diff` + `validate-boundary-preexisting.txt` + `schema-boundary-preexisting.txt`)

- 期待出力: 「観点 9: ✅」（観点 9 の指摘なし）
- 理由: 診断（`Argument is deprecated`、`repository.tf` 82 行目）は、`.diff` 先頭のコメントが前提とする変更前からの非推奨の使用を指す。差分の追加行は `variables.tf` の 3 行目（`description` の変更）だけで、`repository.tf` の行は差分に無いため、診断の位置は追加行に当たらない。スキーマ経路でも、追加行は `variable` ブロックの中の行で resource・data source のブロックの外にあり、照合しない（一覧は `variables.tf` に resource・data source が無いため `checked`・`deprecated` とも空）。

## 境界: 変更前からの使用の書き換え (`boundary-rewritten-preexisting.diff` + `validate-boundary-rewritten-preexisting.txt` + `schema-boundary-rewritten-preexisting.txt`)

- 期待出力: 「観点 9: ✅」（観点 9 の指摘なし）
- 理由: 診断（`Argument is deprecated`、`address` `github_repository.this`、`repository.tf` 82 行目）の位置は、hunk `@@ -75,11 +75,12 @@` の追加行（78〜83 行目）のうち `vulnerability_alerts        = true`（82 行目）に当たる。しかし同じ resource（hunk ヘッダの後ろの `resource "github_repository" "this" {`）の削除行に `vulnerability_alerts = true` があり、`terraform fmt` の桁揃えで同じ属性の行が削除行と追加行の組になった、変更前からの使用の書き換えに当たる。スキーマ経路でも、82 行目の `vulnerability_alerts` は一覧と一致するが、同じ resource の削除行に同じパスの属性 `vulnerability_alerts` があるため、書き換えとして除く。新たに加わった `web_commit_signoff_required` には警告が無く、一覧の `deprecated` にも無い。

## 組み合わせ: 変更前からの使用と新規の使用の同居 (`mixed-preexisting-and-new.diff` + `validate-mixed-preexisting-and-new.txt` + `schema-mixed-preexisting-and-new.txt`)

- **観点 #**: 9
- **重大度**: warning（観点 9 の指摘は次の1件だけ）
- **ファイル:行**: `sandbox_repository.tf:6`
- **突き合わせ**: validate 出力には `Argument is deprecated` の診断が2件ある。
  - `sandbox_repository.tf` 6 行目（`address` `github_repository.sandbox`）: 新規ファイル（`@@ -0,0 +1,14 @@`）の追加行 `has_downloads = true`（6 行目）に当たる → 指摘する。
  - `repository.tf` 82 行目（`address` `github_repository.this`）: `.diff` 先頭のコメントが前提とする変更前からの使用で、差分に `repository.tf` の追加行は無い → 指摘しない。
  - スキーマ経路: 新規ファイルの追加行のうち、6 行目の属性 `has_downloads`（見出し `resource "github_repository" "sandbox" {` の直下）が一覧と一致する。validate 経路の検出と同じ追加行のため1件にまとめる。`visibility` は一覧に無く、`lifecycle` の中の `visibility`・`archived` は照合しない。
- **指摘文言の主旨**: provider が非推奨とした属性 `has_downloads` を差分で新たに使っている（provider の案内: この属性はもう使われておらず、将来の版で除かれる）。修正方針は、provider の案内に従い使用をやめること。
- **指摘しないもの**: `repository.tf:82` の `vulnerability_alerts`（変更前からの使用）。

## 陽性 3: `each.value` に由来する値の属性 (`positive-attribute-each-value.diff` + `validate-positive-attribute-each-value.txt` + `schema-positive-attribute-each-value.txt`)

- **観点 #**: 9
- **重大度**: warning
- **ファイル:行**: `repository.tf:82`
- **突き合わせ**: validate 出力の `diagnostics` は空（値 `each.value.repository.has_downloads` が validate の時点で決まらないため、非推奨の警告が出ない）で、validate 経路は何も検出しない。スキーマ経路で、hunk `@@ -75,10 +75,11 @@` の追加行（78〜82 行目）のうち `has_downloads = each.value.repository.has_downloads`（82 行目）は、hunk ヘッダの見出し `resource "github_repository" "this" {` の直下の属性 `has_downloads` で、一覧の `{"kind": "resource", "type": "github_repository", "target": "attribute", "path": "has_downloads"}` と一致する。同じ resource の削除行（桁揃え前の `archived`・`description`・`homepage_url`・`topics` の4行）に `has_downloads` は無いため、書き換えには当たらない。`variables.tf` の追加行は `variable` ブロックの中の行で、照合しない。
- **指摘文言の主旨**: provider が非推奨とした属性 `has_downloads` を差分で新たに使っている（provider schema の非推奨の印。provider schema には案内の文言が無く、provider のドキュメントと CHANGELOG で代替を確かめる）。修正方針は、provider の案内に従い代替へ移すか使用をやめること。

## 陽性 4: input variable に由来する値の属性 (`positive-attribute-variable.diff` + `validate-positive-attribute-variable.txt` + `schema-positive-attribute-variable.txt`)

- **観点 #**: 9
- **重大度**: warning
- **ファイル:行**: `sandbox_downloads.tf:12`
- **突き合わせ**: validate 出力の `diagnostics` は空（値 `var.sandbox_has_downloads` が validate の時点で決まらないため、非推奨の警告が出ない）。スキーマ経路で、新規ファイル（`@@ -0,0 +1,20 @@`）の追加行 `has_downloads = var.sandbox_has_downloads`（12 行目）は、見出し `resource "github_repository" "sandbox_downloads" {`（7 行目）の直下の属性 `has_downloads` で、一覧と一致する。1〜5 行目の `variable` ブロックの行と、`lifecycle` の中の行は照合しない。
- **指摘文言の主旨**: 陽性 3 と同じ（属性 `has_downloads`、`github_repository.sandbox_downloads`）。
- **他の観点の発火**: `name = "sandbox-downloads"` のリポジトリ名の直書きに観点 5 suggestion が発火しうる。本ケースの照合対象は観点 9 とする。

## 非推奨スキーマ一覧の未提供ケース (`positive-attribute-each-value.diff` + `validate-positive-attribute-each-value.txt` を渡し、非推奨スキーマ一覧を渡さない場合)

- 期待出力: 観点 9 の指摘なし。総評に「観点9: ✅（validate 経路: 評価、スキーマ経路: 未評価（非推奨スキーマ一覧未提供））」と、「非推奨スキーマ一覧が無いため、値が validate の時点で決まらない属性の非推奨は、警告が出ない場合は検出できない」を併記する。
- 観点 9 の指摘を出さない: 差分は非推奨の属性 `has_downloads` を新たに使っているが、validate 出力に警告が無く、reviewer 自身の知識による非推奨の指摘は出ない。
- 理由: スキーマ経路が未評価で、validate 経路だけで評価するため（定義の観点 9 の「判定の限界」）。

## 両方の未提供ケース (`positive-attribute.diff` だけを渡し、validate 出力も非推奨スキーマ一覧も渡さない場合)

- 期待出力: 総評に「観点9: 未評価（validate 経路: 未評価（validate 出力未提供）、スキーマ経路: 未評価（非推奨スキーマ一覧未提供））」を明示する（エラー扱いとしない）。
- 観点 9 の指摘を出さない: 差分は非推奨の属性 `vulnerability_alerts` を新たに使っているが、reviewer 自身の知識による非推奨の指摘は出ない。
- 理由: 観点 9 の判定に使う情報は validate 出力の診断と非推奨スキーマ一覧に限られ、どちらも無いと評価できない。

## 期待する判定根拠

発火するケースの指摘は、観点 9 の「判定の根拠」に挙げた次の一般的な出典に基づく（リポジトリ固有の規約文書を根拠にしない）。

- Terraform 公式 provider 開発ドキュメント SDKv2「Deprecations, Removals, and Renames」: <https://developer.hashicorp.com/terraform/plugin/sdkv2/best-practices/deprecations>
- Terraform 公式 provider 開発ドキュメント Plugin Framework「Deprecations, removals, and renames」: <https://developer.hashicorp.com/terraform/plugin/framework/deprecations>
- `integrations/github` provider 公式ドキュメント（Terraform Registry）: <https://registry.terraform.io/providers/integrations/github/latest/docs>
- `integrations/github` provider のリリースノート（CHANGELOG）: <https://github.com/integrations/terraform-provider-github/releases>
- Terraform 公式ドキュメント `terraform validate`（JSON 出力形式）: <https://developer.hashicorp.com/terraform/cli/commands/validate>
- Terraform 公式ドキュメント `terraform providers schema`（JSON 出力形式の非推奨の印 `deprecated`）: <https://developer.hashicorp.com/terraform/cli/commands/providers/schema>
- Terraform 公式ドキュメント「References to Named Values」（`address` の resource・data source の形）: <https://developer.hashicorp.com/terraform/language/expressions/references>
- Terraform 公式ドキュメント「Resource Address Reference」（`address` のモジュールパス・インスタンスのキー）: <https://developer.hashicorp.com/terraform/cli/state/resource-addressing>
