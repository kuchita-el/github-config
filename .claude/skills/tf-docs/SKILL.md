---
name: tf-docs
description: variables.tf（将来的に outputs.tf も対象）の description を README.md の TF_DOCS ブロック（Inputs/Outputs テーブル）へ terraform-docs 経由で反映する。variable の description を追加・変更した後、または README の変数表が最新か確認したいときに使用。
allowed-tools: Bash(mise exec -- terraform-docs *) Bash(git diff *)
---

# tf-docs

リポジトリルートで以下を順に実行する。

1. 差分の有無を確認する: `mise exec -- terraform-docs --output-check .`
   - exit 0（up to date）なら反映済み。以降の手順は不要。
   - 非ゼロ終了（out of date）なら手順2へ。
2. 反映する: `mise exec -- terraform-docs .`
3. 反映結果を確認する: `git diff README.md`
   - `<!-- BEGIN_TF_DOCS -->` から `<!-- END_TF_DOCS -->` の内側だけが変化していることを目視確認する。
   - マーカー外に差分がある場合は、マーカーが誤って移動・削除されている可能性がある（README.md からマーカーが失われると `terraform-docs` はエラーにせずファイル末尾へ新しいマーカーブロックを自動追記するため、意図しない位置に挿入され得る）。その場合は変更を元に戻し、マーカー位置を手動で復元してから再実行する。

`terraform-docs` が見つからない場合（`mise exec -- terraform-docs` がエラー終了する場合）は、リポジトリルートで `mise install` を実行してから再試行する。
