# 観点 6（既定値の合成と単一の置き場所）の期待出力

各ケースは、worktree (post) を main のままとし、fixture を PR の内容として reviewer に渡したときの期待出力。fixture の `（PR 後…）` の節見出しの下の記述は、worktree の同じファイルの該当箇所を書き換えた後の内容として、`（PR で新規追加）` の節見出しの下の記述は、新しく加えるファイルの内容として読む。

本ファイルは照合用であり、評価者（reviewer）には渡さない。PASS 条件は、発火の有無・観点番号・重要度の一致と、発火するケースで指摘の根拠が、そのケースの「根拠の示し方」に挙げた不変条件の番号と出典を含むこと（出典は下記「期待する判定根拠」の一覧のうち、そのケースの「根拠の示し方」に挙げたものだけを要し、一覧のすべてを要しない）。

## 陽性 1: 必須だった宣言の optional 化 (`positive-repository.tf.example`)

- **観点 #**: 6
- **重大度**: blocker
- **対象**: `variables.tf` の `variable "repositories"` の `visibility`
- **指摘文言の主旨**: 不変条件 3 に反する。必須だった `visibility` の宣言を既定値付きの optional（`optional(string, "public")`）にしており、宣言漏れのリポが既定値で作られる。
- **根拠の示し方**: 不変条件 3 と、Terraform 公式の型制約 `optional`（省略した属性には既定値が入る）。

## 陽性 2: 未指定の null が揃えた値を消す (`positive-branch-protection.tf.example`)

- **観点 #**: 6
- **重大度**: blocker
- **対象**: `locals` の `branch_protection` の `enforcement`・`required_approving_review_count`
- **指摘文言の主旨**: 不変条件 1 に反する。`enforcement`・`required_approving_review_count` にリポごとの値（`ovr.enforcement`・`ovr.required_approving_review_count`。既定値なしの `optional`）をそのまま使っており、値を指定しないリポでは、合成の結果（`locals` の `branch_protection`）で全リポ共通値（`local.branch_protection_preset` の値）に代わって null が入り、揃えた値が消える。合成の結果の段階で反するため、この値を参照する resource が差分や worktree (post) に無くても発火する（参照する resource があれば、null は引数の省略として扱われ provider の既定値になる）。
- **根拠の示し方**: 不変条件 1 と、Terraform 公式の型制約 `optional`（既定値の無い optional の属性は、省略すると null になる）・「Types and Values」の `null`（resource の引数の null は省略として扱われる）。

## 陽性 3: 揃える値をリポごとの入力の既定値に置く (`positive-default-as-policy.tf.example`)

- **観点 #**: 6
- **重大度**: blocker
- **対象**: `variables.tf` の `variable "repositories"` の `repository.allow_update_branch`（`optional(bool, true)`）
- **指摘文言の主旨**: 不変条件 2 に反する。全管理リポで揃えると決めた値（`allow_update_branch = true`）を、リポごとの入力の属性の既定値に置いている。入力の既定値はリポごとに指定できる値を省略したときの代わりの値であり、揃える値の置き場所にならない。
- **根拠の示し方**: 不変条件 2 と、Terraform 公式の型制約 `optional`（既定値は、属性を省略したときに入る値）。

## 陰性 1: 全リポ共通値への属性追加、repository (`negative-repository.tf.example`)

- 期待出力: 「観点 6: ✅」（観点 6 の指摘なし）
- 理由: 揃えると決めた値（`allow_update_branch = true`）を `locals` の `repository_preset` の1か所に足し、resource から直接参照している。null が揃えた値に代わって resource の引数へ届く経路は無く（不変条件 1）、リポごとの入力の既定値にも置いておらず（不変条件 2）、必須の宣言にも触れていない（不変条件 3）。

## 陰性 2: 全リポ共通値への属性追加、branch_protection (`negative-branch-protection.tf.example`)

- 期待出力: 「観点 6: ✅」（観点 6 の指摘なし）
- 理由: 揃えると決めた値（`required_linear_history = true`）を `locals` の `branch_protection_preset` の1か所に足し、resource から直接参照している。不変条件 1〜3 のいずれにも反しない（陰性 1 と同じ）。

## 陰性 3: null を除いて重ねるリポごとの上書き (`negative-override-with-fallback.tf.example`)

- 期待出力: 指摘なし（観点 6 を含むいずれの観点も発火しない）
- 理由: リポごとの入力（既定値なしの `optional(bool)` の `has_wiki`）を、全リポ共通値（`local.repository_preset`）に `merge()` と null の除去で重ねている。値を指定しないリポでは上書き側から `has_wiki` が除かれ、全リポ共通値のまま resource の引数へ届く（不変条件 1 を満たす）。揃えた値の置き場所は `repository_preset` の1か所で、リポごとの入力は既定値を持たない（不変条件 2 を満たす）。必須の宣言にも触れていない（不変条件 3 を満たす）。`merge()` を使うこと自体は発火条件にしない。リポごとに揃えた値から外す経路が認められたものか（登録などの手続きを経たか）は、観点 6 が判定しないことに当たり、指摘の理由にしない。
- 陽性・陰性の期待の整合: この合成（揃えた値に `merge()` と null の除去で重ねる）は、改訂前の `positive-repository.tf.example` の逸脱 (a) と同じ形で、改訂前は陽性の一部として扱っていた。不変条件 1〜3 のいずれにも反しないため、改訂で陽性から外し、この陰性へ移した。陽性 1 は不変条件 3 だけに反する形へ書き直しており、この合成を含まない。

## 陰性 4: 命名だけがリポジトリの規約と異なる設定種別の追加 (`negative-local-convention.tf.example`)

- 期待出力: 指摘なし（観点 6 を含むいずれの観点も発火しない）
- 理由: worktree のルートモジュールに無い設定種別（release ブランチの保護）を、揃えると決めた値を `locals` の1か所に置いて resource から直接参照し、リポ名をキーにした `for_each` で追加している。不変条件 1〜3 のいずれにも反しない。ファイル名（`ruleset_release_branches.tf`）と resource のラベル（`release_branches`）が本リポの命名規約（設定種別名にそろえる）と異なるが、規約への準拠は観点 6 が判定しないことに当たり、呼び出し側が別の担い手に委ねる。resource 型 `github_repository_ruleset` は変更前から worktree に同型があり（`branch_protection.tf`・`tag_protection.tf`）、同型の既存 resource は lifecycle の保護を持たない。
- 名前の重なり: 追加する `locals` の名前（`release_branch_protection_preset`・`release_branch_protection_targets`）・resource の (TYPE, NAME)（`github_repository_ruleset.release_branches`）・ファイル名・Ruleset 名（`release branch protection`）は、worktree のルートモジュールと重ならない。

## 陰性 5: タグ保護の追加 (`adr0004-compliant-tag-protection.tf.example`)

- 期待出力: 「観点 6: ✅」（観点 6 の指摘なし）
- 理由: 揃えると決めた値を `locals` の `tag_protection_preset` と `tag_protection_profile_defaults`（類型ごとの表）に置き、resource から直接参照している。null が揃えた値に代わって resource の引数へ届く経路は無く、リポごとの入力の既定値に揃える値を置いておらず、必須の宣言にも触れていない。不変条件 1〜3 のいずれにも反しない。
- 前提の読み方: fixture の冒頭コメントのとおり、`tag_protection.tf` を本 PR で新規追加するファイルとし、評価では worktree の `tag_protection.tf` の代わりに fixture の内容を PR 後の `tag_protection.tf` として扱う。
- 名前を維持した理由: ADR 0009:37（決定記録のため本文を変えない）と `verification.md` の既存記録が、このファイル名で本 fixture を参照しているため、改訂後も名前を変えない。

## 期待する判定根拠

発火するケースの指摘は、観点 6 の「判定の根拠」に挙げた次の一般的な出典と、反する不変条件の番号（陽性 1 は 3、陽性 2 は 1、陽性 3 は 2）に基づく（リポジトリ固有の規約文書を根拠にしない）。

- Terraform 公式ドキュメント `merge` 関数: <https://developer.hashicorp.com/terraform/language/functions/merge>
- Terraform 公式ドキュメント 型制約（「Optional Object Type Attributes」の `optional`）: <https://developer.hashicorp.com/terraform/language/expressions/type-constraints>
- Terraform 公式ドキュメント「Types and Values」（`null`）: <https://developer.hashicorp.com/terraform/language/expressions/types>
