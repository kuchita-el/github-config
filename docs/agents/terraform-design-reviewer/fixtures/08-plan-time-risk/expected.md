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

## `import.tf` 連携時の格上げ（blocker）(`import-block.tf.example` + `plan-positive-replace.txt`)

`import-block.tf.example` を `## git diff` 相当、`plan-positive-replace.txt` を `## plan 出力` として渡したときの期待出力。PR 内の `import {}` ブロックの対象アドレスが plan 出力で replace されているため、重大度を **blocker** に格上げする（`plan-positive-destroy.txt` の対象アドレスを `import {}` ブロックで import 対象としている場合も同じ）。

- **観点 #**: 8
- **重大度**: blocker
- **検出パターン**: `-/+ resource` および `forces replacement` および `must be replaced`（対象アドレス `github_repository_ruleset.branch_protection["gachanuma"]` が `import {}` ブロックの `to` と一致）
- **指摘文言の主旨**: import 対象アドレスが同じ plan で replace されている。import は既存のリソースをそのまま state に取り込む操作だが、この plan では取り込みと同時に置換・破棄されるため、取り込み対象の既存リソースが作り直される（destroy の場合は破棄される）。
