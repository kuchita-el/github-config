# 観点 8（plan-time リスク検出）の期待出力

reviewer に `git diff` と `<HCP plan 出力テキスト>` を渡したときの期待出力。

## 陽性 1: destroy (`plan-positive-destroy.txt`)

- **観点 #**: 8
- **重大度**: warning
- **検出パターン**: `1 to destroy`
- **指摘文言の主旨**: HCP plan 出力に destroy 兆候。対象アドレス `github_repository_ruleset.branch_protection["github-config"]`。`for_each` キー変更による destroy なら `moved` ブロック、リソース定義削除なら影響範囲の確認を行うこと。

## 陽性 2: replace (`plan-positive-replace.txt`)

- **観点 #**: 8
- **重大度**: warning
- **検出パターン**: `-/+ resource` および `forces replacement` および `must be replaced`
- **指摘文言の主旨**: HCP plan 出力に replace 兆候。対象アドレス `github_repository_ruleset.branch_protection["gachanuma"]`。`name` の変更が forces replacement を引き起こしている。

## 陰性: No changes (`plan-negative-nochange.txt`)

- 期待出力: 「観点 8: ✅」（指摘なし）
- 理由: 検出パターンのいずれもマッチしない。

## 未提供ケース (`plan-empty.txt` または plan 出力が渡されない場合)

- 期待出力: 「観点 8: 未評価（plan 出力未提供）」
- 理由: 観点 8 は plan 出力が無いと評価不能。reviewer は警告ではなく未評価と明示し、エラー扱いとしない。

## `import.tf` 連携時の格上げ（blocker）

PR 内に `import {}` ブロックがあり、`plan-positive-destroy.txt` または `plan-positive-replace.txt` の対象アドレスと一致する場合は、重大度を **blocker** に格上げする。指摘文言は「import 対象アドレスが plan で destroy/replace されている。`terraform.tfvars`/`locals.tf` を実態に寄せて no-op に収束させること（README.md「既存リポの取り込み」参照）」。
