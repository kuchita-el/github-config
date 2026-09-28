# 観点 3（lifecycle 保護の縮退）の期待出力

`.tf.example` のケースは、worktree (post) を main のままとし、fixture を PR の内容として reviewer に渡したときの期待出力。`*-applied.diff` のケースは、評価の前に `git apply` で差分を worktree に置き（worktree ルートに `sandbox_repository.tf` ができる）、その `.diff` を `## git diff` として渡したときの期待出力（評価後は置いたファイルを取り除く）。`.diff` の先頭の `#` で始まるコメント行は PR の内容の説明であり、差分の本体ではない。

## 陽性 1: 既存の保護を外す (`positive.tf.example`)

- **観点 #**: 3（検出条件 (a)）
- **重大度**: warning
- **対象**: `repository.tf` の `github_repository.this` の `lifecycle`（`ignore_changes` から `archived` を外した行）
- **指摘文言の主旨**: `github_repository.this` の `archived` の変更無視を外している。意図した変更なら理由を PR に明記すること。

## 陽性 2: 保護を欠く同型の追加 (`positive-same-type.tf.example`)

- **観点 #**: 3（検出条件 (b)）
- **重大度**: warning
- **対象**: `sandbox_repository.tf` で追加した `github_repository.sandbox`
- **指摘文言の主旨**: 追加した `github_repository.sandbox` は、変更前から存在する同型 resource `github_repository.this`（`repository.tf`）が持つ lifecycle 保護 `ignore_changes` の `visibility`・`archived` を持っていない。同じ保護を付けないことが意図した変更なら理由を PR に明記すること。
- **根拠の示し方**: `github_repository.this` の保護は比較の相手（文脈）として示し、判定の根拠には下記「期待する判定根拠」の出典を挙げる。

## 陽性 3: 保護を欠く同型の追加、適用後 (`positive-same-type-applied.diff`)

- **観点 #**: 3（検出条件 (b)）
- **重大度**: warning
- **対象**: `sandbox_repository.tf` で追加した `github_repository.sandbox`
- **判定の経過**: worktree (post) に置いた `github_repository.sandbox` は差分の `+resource` ヘッダで作る追加集合 A にあるため、変更前から存在する同型 resource に数えない。変更前から存在する同型 resource は `repository.tf` の `github_repository.this` だけで（差分は `repository.tf` を変えていないため、worktree (post) のブロックがそのまま変更前の形）、その保護 `ignore_changes = [visibility, archived]` を追加した `github_repository.sandbox` が欠くため発火する。
- **指摘文言の主旨**: 陽性 2 と同じ。
- **根拠の示し方**: 陽性 2 と同じ。

## 陰性 1: 同じ保護を持つ同型の追加 (`negative-same-type.tf.example`)

- 期待出力: 「観点 3: ✅」（観点 3 の指摘なし）
- 理由: 追加した `github_repository.sandbox` が、変更前から存在する同型 resource `github_repository.this` と同じ `lifecycle { ignore_changes = [visibility, archived] }` を持ち、比較する保護を欠かない。

## 陰性 2: 同じ保護を持つ同型の追加、適用後 (`negative-same-type-applied.diff`)

- 期待出力: 「観点 3: ✅」（観点 3 の指摘なし）
- 理由: worktree (post) に置いた `github_repository.sandbox` は追加集合 A にあるため、変更前から存在する同型 resource に数えない。変更前から存在する同型 resource `github_repository.this` と同じ `ignore_changes = [visibility, archived]` を、追加した `github_repository.sandbox` が持つため発火しない。

## 陰性 3: 保護を変えない変更 (`negative.tf.example`)

- 期待出力: 「観点 3: ✅」（観点 3 の指摘なし）
- 理由: 差分は全リポ共通値に `allow_update_branch` を足して `github_repository.this` から参照するだけで、`lifecycle` の保護（`ignore_changes = [visibility, archived]`）を変えていない。追加した resource も無い。

## 期待する判定根拠

発火するケースの指摘は、観点 3 の「判定の根拠」に挙げた次の一般的な出典に基づく（リポジトリ固有の規約文書を根拠にしない）。

- Terraform 公式ドキュメント lifecycle meta-argument（`ignore_changes`・`prevent_destroy`）: <https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle>
- Terraform 公式ドキュメント「Remove a resource from state」: <https://developer.hashicorp.com/terraform/language/state/remove>（resource を破棄せずに state から外す差分を検出条件 (a) から除く根拠。本 fixture のケースはこれに当たらない）
- Terraform 公式ドキュメント `removed` ブロックの解説: <https://developer.hashicorp.com/terraform/language/block/removed>（同上）
