# 観点 9（provider 非推奨の新規使用）の期待出力

各ケースの `.diff` を `## git diff`、対応する `validate-*.txt`（`terraform validate -json` の出力）を `## validate 出力` として reviewer に渡したときの期待出力。`.diff` の先頭の `#` で始まるコメント行は PR の内容と評価の前提の説明であり、差分の本体ではない。行番号は PR 適用後のファイルでの行番号。

## 陽性 1: 属性 (`positive-attribute.diff` + `validate-positive-attribute.txt`)

- **観点 #**: 9
- **重大度**: warning
- **ファイル:行**: `repository.tf:82`
- **突き合わせ**: 診断（`summary` `Argument is deprecated`、`address` `github_repository.this`、`range.filename` `repository.tf`、`range.start.line` 82）の位置が、hunk `@@ -75,10 +75,11 @@` の追加行（78〜82 行目）のうち `vulnerability_alerts = true`（82 行目）に当たる。
- **指摘文言の主旨**: provider が非推奨とした属性 `vulnerability_alerts` を差分で新たに使っている（provider の案内: `github_repository_vulnerability_alerts` resource を使う）。修正方針は、provider が案内する代替へ移すこと。

## 陽性 2: resource (`positive-resource.diff` + `validate-positive-resource.txt`)

- **観点 #**: 9
- **重大度**: warning
- **ファイル:行**: `deployment_branch_policy.tf:1`
- **突き合わせ**: 診断（`summary` `Deprecated Resource`、`address` `github_repository_deployment_branch_policy.sandbox`、`range.filename` `deployment_branch_policy.tf`、`range.start.line` 1）の位置が、新規ファイル（`@@ -0,0 +1,5 @@`）の追加行 `resource "github_repository_deployment_branch_policy" "sandbox" {`（1 行目）に当たる。
- **指摘文言の主旨**: provider が非推奨とした resource `github_repository_deployment_branch_policy` を差分で新たに使っている（provider の案内: `github_repository_environment_deployment_policy` resource が代替）。修正方針は、provider が案内する代替へ移すこと。

## 陰性 (`negative.diff` + `validate-negative.txt`)

- 期待出力: 「観点 9: ✅」（観点 9 の指摘なし）
- 理由: validate 出力の `diagnostics` が空で、非推奨の警告が無い（差分が追加した `allow_update_branch` は非推奨でない）。

## 境界: 変更前からの使用 (`boundary-preexisting.diff` + `validate-boundary-preexisting.txt`)

- 期待出力: 「観点 9: ✅」（観点 9 の指摘なし）
- 理由: 診断（`Argument is deprecated`、`repository.tf` 82 行目）は、`.diff` 先頭のコメントが前提とする変更前からの非推奨の使用を指す。差分の追加行は `variables.tf` の 3 行目（`description` の変更）だけで、`repository.tf` の行は差分に無いため、診断の位置は追加行に当たらない。

## 組み合わせ: 変更前からの使用と新規の使用の同居 (`mixed-preexisting-and-new.diff` + `validate-mixed-preexisting-and-new.txt`)

- **観点 #**: 9
- **重大度**: warning（観点 9 の指摘は次の1件だけ）
- **ファイル:行**: `sandbox_repository.tf:6`
- **突き合わせ**: validate 出力には `Argument is deprecated` の診断が2件ある。
  - `sandbox_repository.tf` 6 行目（`address` `github_repository.sandbox`）: 新規ファイル（`@@ -0,0 +1,14 @@`）の追加行 `has_downloads = true`（6 行目）に当たる → 指摘する。
  - `repository.tf` 82 行目（`address` `github_repository.this`）: `.diff` 先頭のコメントが前提とする変更前からの使用で、差分に `repository.tf` の追加行は無い → 指摘しない。
- **指摘文言の主旨**: provider が非推奨とした属性 `has_downloads` を差分で新たに使っている（provider の案内: この属性はもう使われておらず、将来の版で除かれる）。修正方針は、provider の案内に従い使用をやめること。
- **指摘しないもの**: `repository.tf:82` の `vulnerability_alerts`（変更前からの使用）。

## 未提供ケース (`positive-attribute.diff` を渡し、validate 出力を渡さない場合)

- 期待出力: 総評に「観点 9: 未評価（validate 出力未提供）」を明示する（エラー扱いとしない）。
- 観点 9 の指摘を出さない: 差分は非推奨の属性 `vulnerability_alerts` を新たに使っているが、reviewer 自身の知識による非推奨の指摘は出ない。
- 理由: 観点 9 の判定に使う情報は validate 出力の診断に限られ、validate 出力が無いと評価できない。

## 期待する判定根拠

発火するケースの指摘は、観点 9 の「判定の根拠」に挙げた次の一般的な出典に基づく（リポジトリ固有の規約文書を根拠にしない）。

- Terraform 公式 provider 開発ドキュメント SDKv2「Deprecations, Removals, and Renames」: <https://developer.hashicorp.com/terraform/plugin/sdkv2/best-practices/deprecations>
- Terraform 公式 provider 開発ドキュメント Plugin Framework「Deprecations, removals, and renames」: <https://developer.hashicorp.com/terraform/plugin/framework/deprecations>
- `integrations/github` provider 公式ドキュメント（Terraform Registry）: <https://registry.terraform.io/providers/integrations/github/latest/docs>
- `integrations/github` provider のリリースノート（CHANGELOG）: <https://github.com/integrations/terraform-provider-github/releases>
- Terraform 公式ドキュメント `terraform validate`（JSON 出力形式）: <https://developer.hashicorp.com/terraform/cli/commands/validate>
