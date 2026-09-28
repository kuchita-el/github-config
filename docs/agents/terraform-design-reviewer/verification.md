# terraform-design-reviewer 検証エビデンス（**代理試験**）

Issue #20 の AC2/3/4 が要求する「reviewer が観点 X を期待通り blocker/warning として発火する」ことを、フィクスチャ駆動で確認した記録。Issue #79 で観点定義を書き直した後の再試験結果を含む。

> ⚠️ **本記録は代理試験です**。本検証は `terraform-design-reviewer` の subagent 実体ではなく、**汎用 `claude` subagent に reviewer 定義テキストを渡して同等プロンプトで評価させた代理実行**による結果。subagent ローダの YAML パース・名前解決・`tools` 継承挙動など、実機でしか露見しない不具合は素通し可能。**実機 `Agent(subagent_type: "terraform-design-reviewer")` 起動によるエビデンスは取得していない**。実機検証は別 Issue で追跡する（後述「制限事項」）。

## 検証方法

- **入力**: `fixtures/0{1-8}-*/` 配下の陽性・陰性・境界フィクスチャ（観点 8 は plan テキスト）。観点 6 は ADR 0004 §3〜§7 の規約領域ごとの違反・準拠フィクスチャ（`fixtures/06-preset-merge/adr0004-*.tf.example`）を含む。
- **手順**: 観点（観点 6 はフィクスチャ群）ごとに汎用 subagent（**代理実行**）を 1 体起動し、次を渡した。
  1. reviewer 定義（`.claude/agents/terraform-design-reviewer.md`）のパス。評価者は定義全体を読み、定義の「実現形の参照先」に従って ADR・README・`CLAUDE.md`・実コードを worktree から読む
  2. 評価対象のフィクスチャのパス
  3. 禁止事項: `expected.md`・`verification.md`・`docs/agents/terraform-design-reviewer/README.md` を読まない（期待値を渡さず、判定後に照合する）。書き込みをしない
- **PASS 条件**: 対象観点の発火の有無・観点番号・重要度が `expected.md` と一致すること。観点 6 はさらに、指摘の根拠に `expected.md` が挙げる ADR の節が含まれること。
- **試行回数**: 各ケース 1 回。LLM 出力は確率的に変動するため、安定性の確認には本来複数回試行が望ましい（制限事項参照）。
- **代理試験の限界**: 「reviewer 定義テキストに従って評価する LLM の挙動」を測定したものであり、「`terraform-design-reviewer` subagent が実機で同じ挙動を示す」ことの保証ではない。subagent 仕様（frontmatter の `tools` 制限・`name` 解決・`model` 継承等）の効果は未測定。

## 照合表（#79 再試験、2026-09-26）

Issue #79（観点を不変条件で書き直し、実現形を実行時に ADR・実コードから読む形へ変更）の後に、全ケースを再試験した。評価者は sonnet の汎用 subagent。#20 時点の結果は git 履歴を参照。

### 既存ケース

| 観点 # | ケース | フィクスチャ | 期待 重大度 | 実出力 重大度 | 判定 |
|---|---|---|---|---|---|
| 1 | 陽性 | `01-moved-missing/positive.tf.example` | blocker | blocker | PASS |
| 1 | 陰性 | `01-moved-missing/negative.tf.example` | (発火しない) | 発火なし | PASS |
| 2 | 陽性 | `02-validation-missing/positive.tf.example` | warning | warning | PASS |
| 2 | 陰性 | `02-validation-missing/negative.tf.example` | (発火しない) | 発火なし | PASS |
| 3 | 陽性 | `03-lifecycle-coverage/positive.tf.example` | blocker | blocker | PASS |
| 3 | 陰性 | `03-lifecycle-coverage/negative.tf.example` | (発火しない) | 発火なし | PASS |
| 4 | 陽性 | `04-for-each-vs-count/positive.tf.example` | warning | warning | PASS |
| 4 | 陰性 | `04-for-each-vs-count/negative.tf.example` | (発火しない) | 発火なし | PASS |
| 4 | 境界 (count=1) | `04-for-each-vs-count/boundary-count-one.tf.example` | (発火しない) | 発火なし | PASS |
| 5 | 陽性 | `05-hardcoded-values/positive.tf.example` | suggestion | suggestion | PASS |
| 5 | 陰性 | `05-hardcoded-values/negative.tf.example` | (発火しない) | 発火なし | PASS |
| 6 | 陽性 repository | `06-preset-merge/positive-repository.tf.example` | blocker | blocker | PASS |
| 6 | 陰性 repository ※ | `06-preset-merge/negative-repository.tf.example` | (発火しない) | 発火なし | PASS |
| 6 | 陽性 branch_protection | `06-preset-merge/positive-branch-protection.tf.example` | blocker | blocker | PASS |
| 6 | 陰性 branch_protection ※ | `06-preset-merge/negative-branch-protection.tf.example` | (発火しない) | 発火なし | PASS |
| 7 | 陽性 1 (secret) | `07-app-permission-boundary/positive-secret.tf.example` | blocker | blocker | PASS |
| 7 | 陽性 2 (file) | `07-app-permission-boundary/positive-file.tf.example` | blocker | blocker | PASS |
| 7 | 陰性 (ruleset) | `07-app-permission-boundary/negative-ruleset.tf.example` | (発火しない) | 発火なし | PASS |
| 8 | 陽性 1 (destroy) | `08-plan-time-risk/plan-positive-destroy.txt` | warning | warning | PASS |
| 8 | 陽性 2 (replace) | `08-plan-time-risk/plan-positive-replace.txt` | warning | warning | PASS |
| 8 | 陰性 (no change) | `08-plan-time-risk/plan-negative-nochange.txt` | (発火しない) | 発火なし | PASS |
| 8 | 未提供 (empty) | `08-plan-time-risk/plan-empty.txt` | (未評価) | 未評価 | PASS |

※ 観点 6 の陰性2件は、Issue #79 の「振る舞い不変の宣言」に従い現行 `repository.tf` / `branch_protection.tf` の形へ差し替えた（旧 `negative-defaults` / `negative-ternary`）。陽性2件はファイル名のみ変更（旧 `positive-defaults` / `positive-ternary`）。差し替えの理由は `fixtures/06-preset-merge/expected.md` に記す。

既存 22 ケースすべてで、対象観点の発火の有無・観点番号・重要度が #20 時点の期待と一致した。

### ADR 0004 §3〜§7 の規約領域（AC6）

| 規約領域 | 違反フィクスチャ → 結果 | 根拠として引用された節 | 準拠フィクスチャ → 結果 | 判定 |
|---|---|---|---|---|
| 設定種別の命名・配置 | `adr0004-violation-naming` → 観点 6 blocker | §3 既知の設定種別表、§5 ファイル名・resource ラベル | `adr0004-compliant-tag-protection` → 発火なし | PASS |
| 値の区分と置き場所 | `adr0004-violation-value-category` → 観点 6 blocker | §4 区分表、「方針値を既定値にしない」 | `negative-repository` → 発火なし | PASS |
| 例外台帳 | `adr0004-violation-ledger` → 観点 6 blocker | §4「登録の手続き」 | `adr0004-compliant-ledger` → 発火なし | PASS |
| 取り込み時の食い違い | `adr0004-violation-import` → 観点 6 blocker | §4「取り込み時の食い違い」（preset を実態へ寄せない、由来の無い差の扱い） | `adr0004-compliant-import` → 発火なし | PASS |
| フィールドの入れ子構造 | `adr0004-violation-nesting` → 観点 6 blocker | §5「`repositories` のフィールド構造」、§3 | `adr0004-compliant-nesting` → 発火なし | PASS |
| locals の名前 | `adr0004-violation-locals-name` → 観点 6 blocker | §5「locals の名前」 | `adr0004-compliant-tag-protection` → 発火なし | PASS |
| visibility による出し分け | `adr0004-violation-visibility` → 観点 6 blocker | §6（Ruleset は public のみ、対象の集合で絞る） | `adr0004-compliant-tag-protection` → 発火なし | PASS |
| 類型プロファイル | `adr0004-violation-profile` → 観点 6 blocker | §7（4つの識別子すべてをキーに、同じ属性の集合） | `adr0004-compliant-tag-protection` → 発火なし | PASS |

いずれの指摘も、reviewer 定義ではなく実行時に読んだ ADR 0004 の文言を引用して根拠にしていた（規約の語彙・判定基準は reviewer 定義に書かれていない）。新規フィクスチャには期待を書かず、PR の内容だけを記した。

### 現行コード（AC4）

| 入力 | 観点 6 | 判定 |
|---|---|---|
| 現行 `branch_protection.tf` / `repository.tf`（全行を追加行として入力。`variables.tf`・`terraform.tfvars` は文脈） | 発火なし（全観点で指摘なし、観点 8 は未評価） | PASS |

評価者は ADR 0004 §3〜§7 を節ごとに照合した。§6（Ruleset を public リポに絞る）は `branch_protection.tf` が未適用だが、ADR 0004「帰結」節と README「手順: 設定種別を追加する」節が後続 Issue で対応すると明記しており、reviewer 定義の「既知の未適用事項」に当たるため指摘しなかった。一方、同じ未適用を新たに持ち込む `adr0004-violation-visibility` では発火しており、両者を区別できている。

### 対象観点以外の発火（参考記録）

評価者には定義全体（観点 1〜8）で評価させたため、対象観点以外の発火も記録された。PASS 判定は対象観点で行い、以下は判定に含めない。

#### 初回（背景コードの整備前）

観点 6 が、観点 1〜5・7 の既存フィクスチャで副次的に発火した（blocker: `03` 陽性・陰性、`04` 陽性・境界、`05` 陽性、`07` 全3件 / warning（判定の限界）: `01` 陽性・陰性、`02` 陽性・陰性、`04` 陰性、`05` 陰性）。原因は、フィクスチャの背景コード（対象観点の検出対象でない部分）が ADR 0004 以前の構造（全リポ共通値のリテラル直書き、`repositories` のフラットなフィールド、単一リポの固定インスタンス、定義の無い locals の参照等）だったこと。観点 5（suggestion）も `04` 陽性・境界、`07` 全3件でリポ名の直書きに対して発火した。

#### 背景コードの整備と再試験（PR #87 のレビュー対応）

観点 1〜5・7 のフィクスチャの背景コードを、main の `variables.tf` / `branch_protection.tf` / `repository.tf` に倣う ADR 0004 の形へ揃えた。各フィクスチャの検出対象部分（陽性の違反・陰性の準拠・境界）は変えていない。主な変更:

- `01`: キー変更の向きを「リポ名 → owner 付き」から「owner 付き（旧実装）→ リポ名」に反転した。1:1 の設定種別でキーをリポ名以外にすること自体が ADR 0004 §3 の基本パターンに反し、初回の整備案（owner 付きキーへ変更）でも観点 6 が発火したため。`for_each` キー変更に `moved` が無い／揃っている、という検出対象は同じ
- `02`: 追加フィールド（`enforcement` / `allowed_merge_methods`）を `branch_protection` キーの下へ入れ子にし、例外台帳の登録（README 抜粋）をフィクスチャに同梱した。`validation` の有無という検出対象は同じ
- `03`: `github_repository.this` を現行 `repository.tf` と同じ形にした（`lifecycle` の有無だけが陽性・陰性の差）
- `04`: 値を `local.branch_protection_preset` から参照し、陽性はリポ名の一覧に `keys(var.repositories)` を使う形、陰性は `for_each = var.repositories`、境界は全リポ共通値のフラグで切り替える単一インスタンスにした
- `05`: 現行 `branch_protection.tf` の resource と同じ形にし、陽性は `integration_id` だけをリテラルにした（直書きは1か所になった）
- `07`: secret・file を `for_each = var.repositories` と設定種別ファイル冒頭の locals で書き、秘密値は sensitive な変数から渡す形にした。陰性は `06-preset-merge/adr0004-compliant-tag-protection.tf.example` と同じタグ保護にした

`04`・`05`・`07` の `expected.md` は、対象の表記（`count` の右辺、直書きの箇所数、resource ラベル）を新しいフィクスチャに合わせた。発火の有無・観点番号・重要度の期待は変えていない。

再試験の結果（評価者は sonnet の汎用 subagent、各1回、`expected.md` は読ませていない）:

| 観点 # | ケース | 対象観点の判定 | 観点 6 の副次発火 | その他の副次発火 |
|---|---|---|---|---|
| 1 | 陽性 | blocker（PASS） | なし | なし |
| 1 | 陰性 | 発火なし（PASS） | なし | なし |
| 2 | 陽性 | warning（PASS） | なし | なし |
| 2 | 陰性 | 発火なし（PASS） | なし | なし |
| 3 | 陽性 | blocker（PASS） | なし | なし |
| 3 | 陰性 | 発火なし（PASS） | なし | なし |
| 4 | 陽性 | warning（PASS） | blocker（残存） | 観点 1 blocker（残存） |
| 4 | 陰性 | 発火なし（PASS） | なし | なし |
| 4 | 境界 | 発火なし（PASS） | blocker（残存） | 観点 5 suggestion（残存） |
| 5 | 陽性 | suggestion（PASS） | blocker（残存） | なし |
| 5 | 陰性 | 発火なし（PASS） | なし | なし |
| 7 | 陽性 1 (secret) | blocker（PASS） | なし | なし |
| 7 | 陽性 2 (file) | blocker（PASS） | なし | なし |
| 7 | 陰性 (ruleset) | 発火なし（PASS） | なし | なし |

`01`・`02` は整備の途中で一度再試験し、観点 6 の副次発火（`01`: owner 付きキーが §3 の基本パターンに反する、`02`: 台帳の理由が時限的に読め §4 の「差が恒常的」要件を満たさない）を受けてフィクスチャを直し、上表はその後の再試験の結果である。

#### 残った副次発火とその理由

いずれも、対象観点の検出対象そのものが ADR 0004 の規約にも反しているため、観点 6 などが併せて発火するのは正しい判定である。背景コードの整備では消せない。

- `04` 陽性（観点 6 blocker、観点 1 blocker）: リポ名という固有キーを持つ要素を `count` で展開すること自体が、ADR 0004 §3 の基本パターン（`for_each`、キーはリポ名）に反する。また評価者は main の `branch_protection.tf` を変更前の状態とみなし、同じアドレスの `for_each` → `count` 切替として観点 1 を発火させた（reviewer 定義の観点 1「`count` ↔ `for_each` 切替は観点 4 と必ず同時に発火する」と整合）
- `04` 境界（観点 6 blocker、観点 5 suggestion）: 単一リポへの条件付き単一インスタンスは、ADR 0004 §3 の基本パターン（全管理リポへ `for_each` で展開）にも、§4 の例外台帳の経路にも当たらない。`count = <条件> ? 1 : 0` の境界を表す以上、特定の1インスタンスを置く形は避けられない
- `05` 陽性（観点 6 blocker）: リポ固有値（`status_check_integration_id`）を参照せずリテラルで与えることが、ADR 0004 §4 の「resource は区分ごとの置き場所から値を直接参照する」に反する。観点 5 の検出対象（Terraform 固有定数の直書き）と同じ箇所を、観点 6 は置き場所の規約違反として捉えている

### 評価者のツール環境についての記録

評価者（汎用 subagent）には、この試験の環境で `Grep` / `Glob` ツールが提供されていなかった。多くの評価者は `Read` のみで代替したが、一部は読み取り専用の `grep` / `ls` を `Bash` で実行した（指示違反として自己申告あり。ファイル変更・git 操作は無し）。reviewer 実機（`tools: Read, Grep, Glob`）とはツール構成が異なる点も代理試験の限界に含まれる。

## 実機起動エビデンス（1 ケース）

PR #31 マージ後の Claude Code セッションで `subagent_type: "terraform-design-reviewer"` が候補として認識されることを確認し、観点 1 陽性フィクスチャを実機 reviewer で評価した。

- **実施日**: 2026-06-20（PR #31 マージ後セッション）
- **subagent_type**: `terraform-design-reviewer`（`.claude/agents/terraform-design-reviewer.md` 由来、プロジェクトローカル）
- **評価対象**: `fixtures/01-moved-missing/positive.tf.example`
- **判定**: 観点 1 が blocker で発火、他観点 2〜7 は静的に不発火、観点 8 は plan 出力未提供で未評価
- **指摘内容の主旨**: `github_repository_ruleset.branch_protection` の `for_each` 右辺式が `local.branch_protection` → `local.branch_protection_v2_keyed` に変化し、コメントからキースキーマが `<repo>` → `<repo>:<branch>` に変わると明示されているため、対応する `moved` ブロックが必要。修正方針として `moved { from = ...["gachanuma"]; to = ...["gachanuma:main"] }` 形式を全リポ分追加するよう提示
- **期待出力との照合**: `expected.md` の期待（観点 #1, blocker, 対象アドレス, 指摘文言主旨, 修正方針）と完全一致 → **PASS**
- **frontmatter `tools` 制限の効果**: 実行ログ上、reviewer は `Read` のみを使用（Write/Edit/任意 Bash の発動なし）。`tools: Read, Grep, Glob, Bash` 制限が機能していることを確認

これにより、subagent ローダ・`name` 解決・`tools` 継承が `.claude/agents/` 配下のプロジェクトローカル subagent として実機で機能することを 1 ケースで確認した。

## 制限事項

- **試行回数の限界**: 本実装は各フィクスチャ 1 回試行に留めた。LLM 出力の確率的変動への対処として、観点 # と重大度の安定性は将来の繰り返し検証で確認する。本実装段階では 1 回で観点 # と重大度が reviewer 定義通りに判定されることを確認した。
- **検証時のサブエージェント種別**: 上記「実機起動エビデンス」節の通り、観点 1 陽性 1 ケースで実機 `Agent(subagent_type: "terraform-design-reviewer")` 起動を確認済み。残り 21 ケース（観点 1 陰性〜観点 8 未提供）の実機補強は将来の繰り返し検証で対応する。本表（照合表）の結果は依然として代理試験ベース。
- **`github_repository` 系のフィクスチャ**: 観点 3 のフィクスチャは ADR 0001 §3 の仕様から組み立てている。観点 6 の陰性は #79 で現行の `repository.tf` / `branch_protection.tf` の形へ差し替えた。
- **既存フィクスチャの背景コード**: 観点 1〜5・7 のフィクスチャの背景コードは PR #87 のレビュー対応で ADR 0004 の形へ揃えた。検出対象そのものが ADR 0004 に反する3ケースでは観点 6 等の副次発火が残る（「対象観点以外の発火」節）。
- **#79 の再試験中の定義の文言修正**: 評価の開始後に、観点 8 の不変条件の2文目を言い換えた（取り込み時に Terraform が実設定を変更しない旨の表現の明確化。判定手順・検出パターン・重要度は不変）。観点 8 の評価者が修正前後のどちらを読んだかは記録していない。

## 結論

#79 の再試験で、既存 22 ケース、ADR 0004 §3〜§7 の8つの規約領域の違反・準拠 12 ケース（準拠は一部が複数領域を兼ねる）、現行コード（AC4）のすべてで、対象観点の判定が期待と一致した（**代理試験**、各1回）。実機 `terraform-design-reviewer` 起動による補強は観点 1 陽性 1 ケース（#20 時点）に留まる。

## 観点9 の実測記録（#103）

凡例: 本節と「照合表（#103 再試験、2026-09-28）」節の J1〜J7・決定1〜9・Task N・テストケース対応表・検証すべき振る舞いは、#103 の実装プラン（リポジトリ外）の項目名で、要旨は #103 の PR 本文と Issue #103 のコメント（決定の要旨: <https://github.com/kuchita-el/github-config/issues/103#issuecomment-5856725382>）にある。ユーザー決定に付けた (a)〜(c) はユーザーに示した選択肢の記号で、選ばれた内容は各所の括弧内に書いた。

- **実施日**: 2026-09-28
- **版**: Terraform v1.15.6、provider `integrations/github` v6.12.1（`.terraform.lock.hcl` と一致）
- **手順**: worktree ルートで `mise exec -- terraform init -backend=false -plugin-dir=/home/kuchita/Development/github-config/.terraform/providers -lockfile=readonly -input=false` を実行し（追跡ファイル・`.terraform.lock.hcl` に変更なし、`.terraform/` に `terraform.tfstate` なしを確認）、以降 `mise exec -- terraform validate -no-color`（人間向け）・`mise exec -- terraform validate -json`（JSON）を、各ケースにつき一時編集 → 実行 → 記録 → `git restore` / 一時ファイル削除の順で単独コマンドとして実行した。
- **現行コード（一時編集なし）での validate**: `Success! The configuration is valid.`（警告なし）。

### 各ケースの実測

- **陽性（属性）**: `repository.tf` の `github_repository.this` に `vulnerability_alerts = true` を1行追加（fmt 後 82 行目）。`Warning: Argument is deprecated`、`on repository.tf line 82`、内容は「`github_repository_vulnerability_alerts` resource へ移行せよ」。`positive-attribute.diff`／`validate-positive-attribute.txt`。
- **陰性**: 同じ位置に `allow_update_branch = false`（provider docs に非推奨の記載なし）を追加。警告なし（`Success! The configuration is valid.`）。`negative.diff`／`validate-negative.txt`。
- **境界**: `repository.tf` に `vulnerability_alerts = true`（PR 前からの使用という前提、diff には含めない）を置いた状態で、`variables.tf` の `variable "github_owner"` の `description` を1行変更。`git diff -- variables.tf` を `boundary-preexisting.diff` に保存。validate は `repository.tf line 82` を警告するが、この行は `variables.tf` の diff の追加行に無い。`validate-boundary-preexisting.txt`。
- **陽性（resource、J3）**: worktree ルートに一時ファイル `deployment_branch_policy.tf` を作り、`resource "github_repository_deployment_branch_policy" "sandbox"`（`repository`・`environment_name`・`name` をリテラルで指定）を配置。`Warning: Deprecated Resource`、`on deployment_branch_policy.tf line 1`、内容は「`github_repository_environment_deployment_policy` resource が代替」。`positive-resource.diff`（`git diff --no-index /dev/null deployment_branch_policy.tf`、終了コード1は正常）／`validate-positive-resource.txt`。
- **組み合わせ（J7）**: `repository.tf` に `vulnerability_alerts = true`（境界と同じ前提）を置いた状態で、worktree ルートに一時ファイル `sandbox_repository.tf` を作り、`github_repository.sandbox`（`github_repository.this` と同じ `lifecycle { ignore_changes = [visibility, archived] }`）に `has_downloads = true`（新規使用）を追加。`git diff --no-index /dev/null sandbox_repository.tf` を `mixed-preexisting-and-new.diff` に保存（前提コメント付き、validate 出力の形式に非依存）。

### J3 の結果: 成立

resource 単位の非推奨（`github_repository_deployment_branch_policy`）でも `terraform validate` は `Warning: Deprecated Resource` を、対象アドレス・ファイル・行付きで出す。属性単位の警告（`Warning: Argument is deprecated`）と見出しの文言は異なるが、いずれも位置付きの警告として検出できる。決定6（観点9の対象を属性・resourceの両方とする）と決定7（情報源を validate 出力に限る）は両立する。

### J7 の結果: 不成立（集約される）

組み合わせケースの人間向け出力（`terraform validate -no-color`）は次のとおりで、2件目が集約され「(and one more similar warning elsewhere)」に畳まれた（先頭は「ファイル名、次に位置」の順で `repository.tf`〔fmt 後 82 行目〕が `sandbox_repository.tf`〔6 行目〕より先になり、新規使用〔`sandbox_repository.tf`〕側が畳まれた1件になる）:

```
Warning: Argument is deprecated

  with github_repository.this,
  on repository.tf line 82, in resource "github_repository" "this":
  82:   vulnerability_alerts = true

Use the github_repository_vulnerability_alerts resource instead. This field
will be removed in a future version.

(and one more similar warning elsewhere)
Success! The configuration is valid, but there were some validation warnings
as shown above.
```

同じ状態で `terraform validate -json` を実行すると、集約されず2件とも個別にファイル名・行が付く:

```json
{
  "format_version": "1.0",
  "valid": true,
  "error_count": 0,
  "warning_count": 2,
  "diagnostics": [
    {
      "severity": "warning",
      "summary": "Argument is deprecated",
      "detail": "This attribute is no longer in use, but it hasn't been removed yet. It will be removed in a future version. See https://github.com/orgs/community/discussions/102145#discussioncomment-8351756",
      "address": "github_repository.sandbox",
      "range": {
        "filename": "sandbox_repository.tf",
        "start": { "line": 6, "column": 19, "byte": 110 },
        "end": { "line": 6, "column": 23, "byte": 114 }
      }
    },
    {
      "severity": "warning",
      "summary": "Argument is deprecated",
      "detail": "Use the github_repository_vulnerability_alerts resource instead. This field will be removed in a future version.",
      "address": "github_repository.this",
      "range": {
        "filename": "repository.tf",
        "start": { "line": 82, "column": 26, "byte": 4027 },
        "end": { "line": 82, "column": 30, "byte": 4031 }
      }
    }
  ]
}
```

（`snippet` フィールドは記録を簡潔にするため省略。両診断とも `filename`・`start.line` を個別に持つことは確認済み。）

J7 が仮定と異なった（人間向け出力が集約する）ため、実測はここでいったん止めた。この時点では `validate-mixed-preexisting-and-new.txt` を作らず、ユーザーの回答後に選ばれた形で作ることにした。`mixed-preexisting-and-new.diff` は形式に依存しないため、この時点で保存した。

### ユーザー回答後の取り直し（2026-09-28）

J7 不成立を受け、ユーザーは選択肢 (a)（観点9 の入力と、ルート README の併用節〔「PR レビュー時の reviewer 併用」〕にある「validate 出力の取得」の手順を `terraform validate -json` の出力に変える）を選んだ。理由: 人間向け出力（`-no-color`）は同じ要約 `Argument is deprecated` の警告を1件に集約し、変更前からの使用と新規使用が同居すると新規使用側の位置が消えるため（上記の実測）。選択肢 (b)（人間向け出力のまま限界として明記する）は、新規使用の見落としが手順を変えても構造的に残る点が採らなかった理由。

この選択に伴い、fixture 09 の全ケース（陽性・属性／陰性／境界／陽性・resource／組み合わせ）の validate 出力を `mise exec -- terraform validate -json`（各ケースとも上記「各ケースの実測」と同じ一時編集を作り直した状態、単独コマンド）で取り直し、`validate-*.txt`（ファイル名は変えず、内容を `-json` の出力に置換。組み合わせケースのみ新規に `validate-mixed-preexisting-and-new.txt` を作成）とした。各ケースとも、作り直した状態の `git diff`（または `git diff --no-index /dev/null <一時ファイル>`）が保存済みの `.diff`（先頭のコメント行を除く）と一致することを確認した。

`-json` 出力（`diagnostics[].range.filename`・`range.start.line`）は次のとおり:

- 陽性（属性）: `repository.tf` line 82（`positive-attribute.diff` の追加行と一致）
- 陰性: 警告なし（`diagnostics: []`）
- 境界: `repository.tf` line 82（`boundary-preexisting.diff` の追加行〔`variables.tf`〕には無い）
- 陽性（resource）: `deployment_branch_policy.tf` line 1（`positive-resource.diff` の追加行と一致）
- 組み合わせ: 2件、`sandbox_repository.tf` line 6（`mixed-preexisting-and-new.diff` の追加行 `has_downloads = true` と一致）と `repository.tf` line 82（前提の既存使用側）。集約されず両方とも `range` を個別に持つ。

すべてのケースの後始末（`git restore repository.tf variables.tf`、一時ファイル `deployment_branch_policy.tf`・`sandbox_repository.tf` の削除）を行い、`git status --short` で `.tf`・`.tfvars`・`.terraform.lock.hcl` の変更・未追跡が無いことを確認した。

### 書き換えのケースの追加（2026-09-28、ユーザー決定 (b)）

Task 5b のレビューで、行単位の照合では変更前からある非推奨の属性の行が `terraform fmt` の桁揃え等で削除行と追加行の組になると、新規の使用と誤って指摘されることが分かった。ユーザーは (b)（同じ resource の削除行に同じ属性の行がある場合、または削除行に同じ型の resource の見出し行がある場合は、変更前からの使用の書き換えとみなして指摘しない）を選んだ。resource 単位の条件は、その後の実装側の判断で、差分の `moved` ブロックによる同じ型の変更前のアドレスからの移動か、同じ hunk 内の見出し行の書き換えに限った（別の場所で同じ型の resource を削除しただけでは書き換えとみなさない）。この規則の陰性ケースとして、fixture 09 に `boundary-rewritten-preexisting.diff`／`validate-boundary-rewritten-preexisting.txt` を追加した。

- **手順**（作業ディレクトリは worktree ルート。fmt・validate・git はそれぞれ単独コマンド）: `git status --short` でインデックスと `.tf` が clean であることを確認 → `repository.tf` の `github_repository.this` に `vulnerability_alerts = true` を加えて `mise exec -- terraform fmt repository.tf` で整形し、`git add repository.tf` でインデックスに置いた（インデックス＝PR 前の状態。インデックスの blob は `427df50` で、`positive-attribute.diff` の適用後と同じ）→ 同じ桁揃えのまとまりに `web_commit_signoff_required = true`（provider docs v6.12.1 の `github_repository` に非推奨の記載なし、`github_repository.this` に未設定）を加えて fmt で整形 → `git diff -- repository.tf`（作業ツリー対インデックス＝PR の差分）を保存 → `mise exec -- terraform validate -json` を実行 → `git restore --staged repository.tf`、`git restore repository.tf` で戻し、`git status --short`・`git diff --cached --name-only` でインデックス・`.tf` とも clean を確認。
- **差分**: hunk `@@ -75,11 +75,12 @@ resource "github_repository" "this" {`。桁揃えで `archived`・`description`・`homepage_url`・`topics`・`vulnerability_alerts` の5行が削除行と追加行の組になり、`web_commit_signoff_required = true` が1行増えた（追加行は 78〜83 行目、`vulnerability_alerts        = true` は 82 行目）。
- **validate -json**: `"valid": true`、`"warning_count": 1`。警告は `Argument is deprecated`（`address` `github_repository.this`、`range` `repository.tf` line 82 column 33〜37）の1件だけで、`web_commit_signoff_required` には警告が無かった（非推奨でないことの確認）。警告の行は差分の追加行に当たり、同じ resource の削除行に `vulnerability_alerts = true` がある。
- **validate の失敗時の出力（参考）**: 同じ状態で、出力をファイルへリダイレクトする形（`mise exec -- terraform validate -json > <file>`）で実行したところ、サンドボックスの除外に一致せず provider プラグインを起動できずに失敗した。出力は `"valid": false`、`"error_count": 1`、`"warning_count": 0` で、診断は `Failed to load plugin schemas`（`range` なし）の error 1件だけだった。validate が失敗すると非推奨の警告が0件になる例として記録する（観点9 の「未評価（validate が失敗）」の扱いの裏付け）。この出力は fixture に使わず、fixture には単独コマンドで取得した上記の出力を原文のまま書き写した。

### 判定の限界: 値が validate の時点で決まらない属性（2026-09-28、ユーザー決定 (c)）

#103 の実装中に、属性単位の非推奨は、属性の値が validate の時点で決まらない（input variable 由来など）と `terraform validate` が警告を出さないことが分かった。ユーザーは (c)（この PR で限界を実測付きで定義の観点9 の「判定の限界」と本記録に明記し、観点9 の情報源に provider schema を加えて限界を解消する件は別 Issue で扱う）を選んだ。以下はその実測で、定義の観点9 の「判定の限界」の裏付けである。

- **実施日**: 2026-09-28
- **版**: Terraform v1.15.6、provider `integrations/github` v6.12.1（`mise exec -- terraform version` で確認）
- **手順**: 作業ディレクトリは worktree ルート（初期化済み。上記「手順」の init による）。一時ファイル `zz_tmp_deprecation_check.tf` を worktree ルートに作り、状態ごとに内容を書き換えて `mise exec -- terraform validate -json` を単独コマンドで実行した。一時ファイルを置く前の現行コードでの出力は `"warning_count": 0`・`"diagnostics": []` だった。非推奨の属性には `github_repository` の `has_downloads`（組み合わせケースで `Argument is deprecated` が出た属性）、非推奨の resource には `github_repository_deployment_branch_policy`（陽性・resource ケースで `Deprecated Resource` が出た型）を使った。(a)〜(c) が確認の対象、(d)・(e) は値の由来の違いを確かめるための補足である。

| 状態 | 一時ファイルの内容（要旨） | `warning_count` | 警告 |
|---|---|---|---|
| (a) 属性・input variable | `variable "zz_tmp_has_downloads" { type = bool }` と、`github_repository.zz_tmp_check` に `has_downloads = var.zz_tmp_has_downloads` | 0 | なし |
| (b) 属性・リテラル | (a) と同じ `variable` を置いたまま、`has_downloads = true` | 1 | `Argument is deprecated`（line 7） |
| (c) resource・引数がすべて input variable | `variable "zz_tmp_value" { type = string }` と、`github_repository_deployment_branch_policy.zz_tmp_check` の `repository`・`environment_name`・`name` をすべて `var.zz_tmp_value` | 1 | `Deprecated Resource`（line 5） |
| (d) 属性・`each.value`（補足） | `github_repository.zz_tmp_check` に `for_each = { "zz-tmp-check" = true }`、`name = each.key`、`has_downloads = each.value` | 0 | なし |
| (e) 属性・リテラルだけから決まる local value（補足） | `locals { zz_tmp_has_downloads = true }` と、`has_downloads = local.zz_tmp_has_downloads` | 1 | `Argument is deprecated`（line 7） |

(a) の一時ファイルと出力（原文）:

```hcl
variable "zz_tmp_has_downloads" {
  type = bool
}

resource "github_repository" "zz_tmp_check" {
  name          = "zz-tmp-check"
  has_downloads = var.zz_tmp_has_downloads
}
```

```json
{
  "format_version": "1.0",
  "valid": true,
  "error_count": 0,
  "warning_count": 0,
  "diagnostics": []
}
```

(b) の一時ファイルと出力（原文）:

```hcl
variable "zz_tmp_has_downloads" {
  type = bool
}

resource "github_repository" "zz_tmp_check" {
  name          = "zz-tmp-check"
  has_downloads = true
}
```

```json
{
  "format_version": "1.0",
  "valid": true,
  "error_count": 0,
  "warning_count": 1,
  "diagnostics": [
    {
      "severity": "warning",
      "summary": "Argument is deprecated",
      "detail": "This attribute is no longer in use, but it hasn't been removed yet. It will be removed in a future version. See https://github.com/orgs/community/discussions/102145#discussioncomment-8351756",
      "address": "github_repository.zz_tmp_check",
      "range": {
        "filename": "zz_tmp_deprecation_check.tf",
        "start": {
          "line": 7,
          "column": 19,
          "byte": 148
        },
        "end": {
          "line": 7,
          "column": 23,
          "byte": 152
        }
      },
      "snippet": {
        "context": "resource \"github_repository\" \"zz_tmp_check\"",
        "code": "  has_downloads = true",
        "start_line": 7,
        "highlight_start_offset": 18,
        "highlight_end_offset": 22,
        "values": []
      }
    }
  ]
}
```

(c) の一時ファイルと出力（原文）:

```hcl
variable "zz_tmp_value" {
  type = string
}

resource "github_repository_deployment_branch_policy" "zz_tmp_check" {
  repository       = var.zz_tmp_value
  environment_name = var.zz_tmp_value
  name             = var.zz_tmp_value
}
```

```json
{
  "format_version": "1.0",
  "valid": true,
  "error_count": 0,
  "warning_count": 1,
  "diagnostics": [
    {
      "severity": "warning",
      "summary": "Deprecated Resource",
      "detail": "This resource is deprecated in favour of the github_repository_environment_deployment_policy resource.",
      "address": "github_repository_deployment_branch_policy.zz_tmp_check",
      "range": {
        "filename": "zz_tmp_deprecation_check.tf",
        "start": {
          "line": 5,
          "column": 70,
          "byte": 114
        },
        "end": {
          "line": 5,
          "column": 71,
          "byte": 115
        }
      },
      "snippet": {
        "context": "resource \"github_repository_deployment_branch_policy\" \"zz_tmp_check\"",
        "code": "resource \"github_repository_deployment_branch_policy\" \"zz_tmp_check\" {",
        "start_line": 5,
        "highlight_start_offset": 69,
        "highlight_end_offset": 70,
        "values": []
      }
    }
  ]
}
```

(d) の一時ファイルと出力（原文）:

```hcl
resource "github_repository" "zz_tmp_check" {
  for_each = {
    "zz-tmp-check" = true
  }

  name          = each.key
  has_downloads = each.value
}
```

```json
{
  "format_version": "1.0",
  "valid": true,
  "error_count": 0,
  "warning_count": 0,
  "diagnostics": []
}
```

(e) の一時ファイルと出力（原文）:

```hcl
locals {
  zz_tmp_has_downloads = true
}

resource "github_repository" "zz_tmp_check" {
  name          = "zz-tmp-check"
  has_downloads = local.zz_tmp_has_downloads
}
```

```json
{
  "format_version": "1.0",
  "valid": true,
  "error_count": 0,
  "warning_count": 1,
  "diagnostics": [
    {
      "severity": "warning",
      "summary": "Argument is deprecated",
      "detail": "This attribute is no longer in use, but it hasn't been removed yet. It will be removed in a future version. See https://github.com/orgs/community/discussions/102145#discussioncomment-8351756",
      "address": "github_repository.zz_tmp_check",
      "range": {
        "filename": "zz_tmp_deprecation_check.tf",
        "start": {
          "line": 7,
          "column": 19,
          "byte": 139
        },
        "end": {
          "line": 7,
          "column": 45,
          "byte": 165
        }
      },
      "snippet": {
        "context": "resource \"github_repository\" \"zz_tmp_check\"",
        "code": "  has_downloads = local.zz_tmp_has_downloads",
        "start_line": 7,
        "highlight_start_offset": 18,
        "highlight_end_offset": 44,
        "values": []
      }
    }
  ]
}
```

- **結果**: 属性単位の非推奨の警告は、属性の値が validate の時点で決まる場合（リテラル、リテラルだけから決まる local value）に限り出て、値が input variable や `each.value` に由来する場合は出なかった。resource 単位の非推奨の警告（`Deprecated Resource`）は、引数をすべて input variable にしても出た。Terraform 公式ドキュメント `terraform validate` は、validate が与えられた変数の値や state によらずに構成を検査すると説明しており、変数由来の値は validate の時点では決まらない。
- **定義への反映**: 観点9 に「判定の限界」を置き、値が validate の時点で決まらない属性は警告が出ない場合に新規使用を検出できないこと、総評の「✅」は警告が出ない新規使用が無いことまでは示さないことを書き、評価した場合の総評にこの限界を併記するようにした。fixture 09 の入力はいずれもリテラルの値で、この限界に当たらない。
- **解消の扱い**: 観点9 の情報源に provider schema（非推奨の印）を加えてこの限界を解消する件は、別 Issue（#109）で扱う。
- **後始末**: 一時ファイル `zz_tmp_deprecation_check.tf` を削除し、`git status --short` に `.tf` の変更・未追跡の `.tf` が無いことを確認した。

## 照合表（#103 再試験、2026-09-28）

Issue #103（判定の根拠を一般的な出典へ移し、観点3・6・7 を改め、観点9 を加えた改訂）の後に、全ケースを代理試験で評価した。本節の照合表は、定義 a06c48d（`.claude/agents/terraform-design-reviewer.md`）で全ケースを評価し直した最終パスの結果である。それより前の評価で PASS しなかったケースと直した経緯は、下記「PASS しなかったケースと直した経緯」に記す。

最終パスの後に、観点1 の判定の根拠に挙げた Terraform 公式ドキュメントの出典名の表記だけを、「Refactoring」から現行のページ題名「Refactor modules」に合わせた（定義・reviewer README・`expected.md` 01。URL は変えていない）。判定・期待に影響しないため評価し直しておらず、下表の実出力の「Refactoring」は評価者の出力のままである。

### 検証方法

- **評価者**: sonnet の汎用 subagent（**代理実行**。記録上のモデルは `claude-sonnet-5`）。観点1〜9 に1体ずつ（観点どうしは独立のため並列）、観点9 の未提供ケースに別の1体、適用後ケース4件に1件ずつ1体の計14体。各ケース1回。
- **渡したもの**: (1) 改訂後の定義の worktree 上の絶対パス、(2) worktree ルートの絶対パスを「worktree (post)」として（リポのファイル〔`*.tf`・`*.tfvars`・README・その他の文書〕はこの配下から読み、作業ディレクトリが別の場所でもそこを worktree として読まないよう指示）、(3) 評価対象の fixture の絶対パス（観点8 は plan テキスト、格上げケースは `import-block.tf.example` と `plan-positive-replace.txt` の組、観点9 は `.diff` と `validate-*.txt` の組）、(4) ケースごとに独立に評価すること、(5) 禁止事項: `expected.md`・`verification.md`・`docs/agents/terraform-design-reviewer/README.md` を読まない、書き込み・git コマンド・サブエージェントの起動をしない、(6) 実行した全ツール呼び出しを実行ログとして出力に含めること。リポジトリ内の文書（ADR・設計仕様書・CLAUDE.md など）を読むことは禁じていない（実運用と同じ条件で、定義が本リポ文書を判定の根拠に使わせないことを確かめるため）。
- **定義を絶対パスで渡した理由**: `subagent_type` による名前解決は、作業ディレクトリから上位へたどって `.claude/agents/` を探し、ファイルの監視はセッション開始時に存在したディレクトリに限る。main checkout で起動して worktree へ移ったセッションでは、改訂後の定義と main checkout の改訂前の定義のどちらが読まれるかを確定できないため、名前解決に依存しない形にした（J5）。評価者14体の記録で、読んだ定義の全行が a06c48d の版と一致することを確かめた。
- **worktree (post) のルートを絶対パスで渡した理由**: 評価者の作業ディレクトリが main checkout でありうるため。渡さないと評価者は PR 適用前の main を読み、適用後ケースが追加集合 A・削除集合 R の処理を通らずに期待どおりの結果になりうる。
- **適用後ケースを worktree に適用して1件ずつ評価した理由**: 実運用では worktree が PR 適用後で、差分が追加した resource ブロック自体を含む。「変更前から存在する同型 resource」を判定に使う観点3 (b)・観点7 で、追加集合 A を既存と数えないこと（観点7 は、走査範囲をルートモジュールに限り fixture 配下の例示を数えないことも）と、削除集合 R を既存に含めることを、追加ブロックが実在する状態で確かめるため。worktree を書き換えるため、他の評価者と並列にせず、観点ごとの評価がすべて終わってから1件ずつ行った。各ケースの前に `git apply --check` が通り、`git apply` の後の `git status --short` に当該ファイルだけが現れ（新規ファイルは未追跡、`negative-rename-applied` は ` M dependabot_security_updates.tf`）、評価後に元に戻して `.tf` の変更・未追跡の `.tf` が無いことを確かめた。`git apply --check` は4件とも通り、fixture の作り直しは無かった。評価者には、worktree に適用したことを伝えていない。
- **観点9 の未提供ケースを別の評価者で評価した理由**: 同じ評価者が直前に `validate-positive-attribute.txt` で同じ属性の非推奨の警告を読んでいると、評価者自身の知識による指摘が出ないことを試せないため。この評価者には `positive-attribute.diff` だけを渡し、`fixtures/09-provider-deprecation/` の `validate-*.txt` を読むことを禁じた（記録上、呼び出しは Read 4件〔評価者への共通指示、定義2回、`positive-attribute.diff`〕だけで、`validate-*.txt` を読んでいない）。なお、定義の観点9 の入出力例に同じ属性・同じ位置（`vulnerability_alerts`、`repository.tf:82`）の診断が載っており、評価者は同じ属性の非推奨を定義から知った状態だった（出力でも言及している）。それでも validate 出力が無いときは指摘しないことが示され、期待の判定は変わらない。
- **記録の検査**: 評価者の自己申告（出力中の実行ログ）は証拠にせず、評価者の記録（transcript）のツール呼び出しと結果で確かめた。(i) 適用後ケースで worktree (post) 配下の適用ファイルを読んだこと（下記「全ケースの照合」の「記録の検査」の列）。(ii) 書き込み・git 操作が無いこと: 14体の呼び出しは Read 101件・Bash 32件・最終報告の受け渡し14件だけで、Write・Edit 等は0件。Bash 32件はいずれも `cd` と `ls`・`find`・`grep`・`sed -n`・`cat`・`head`・`sort`・`echo`（区切りの表示）による読み取りで、ファイルへのリダイレクト（`2>/dev/null`・`2>&1` を除く）と git は0件。(iii) 期待値が漏れていないこと: 9件の `expected.md`・`verification.md`・reviewer README の各行（空白を詰めて12文字以上）を禁止行とし、全ツール結果の各行と照合した。一致した行はすべて、その結果を返したファイル自身（定義、fixture の `.tf.example`・`.diff`・`validate-*.txt`、worktree の `repository.tf`・`variables.tf`）の行で、禁止ファイルから来た行は0行。禁止ファイルを読んだ呼び出しも0件。自己申告の実行ログには記録と食い違うもの（前置していない `cd` を書く、失敗した呼び出しを省く、読んだ順が異なる）があり、自己申告が証拠にならないことを示している。
- **文脈**: 14体とも、プロジェクトの CLAUDE.md（App に付与した権限の記述を含む）が文脈に載っていた（規約文書が文脈に載っている状態でも指摘に引用しないこと〔AC1 の振る舞い面〕を確かめる前提を満たす）。
- **ツール環境**: 評価者は `Grep`・`Glob` を持たず、`Read` と読み取りの `Bash` を使った。reviewer 実機（`tools: Read, Grep, Glob`）とはツール構成が異なる（代理試験の限界）。観点4 の評価者は、最終報告の受け渡しが成功した後に、API の使用上限の通知で終了した。照合には記録上の最終報告を使った。
- **PASS 条件**: 対象観点の発火の有無・観点番号・重要度が `expected.md` と一致すること。加えて、観点7 は列挙した権限が「列挙する権限」と一致すること、観点9 は指摘のファイル・行が一致すること、観点6 は指摘の根拠が各ケースの「根拠の示し方」の不変条件の番号と出典を含み、`merge` の使用そのものを指摘しないこと、観点8 の格上げケースは修正方針が収束のさせ方（構成と実リソースのどちらを変えるか）を指示しないこと。観点9 を評価したケースの総評に付く限界の併記は定義どおりで、不一致にしない。適用後ケースは (i)〜(iii) を、それ以外のケースは (iii) を確かめられた場合に限り PASS とする。対象観点以外の発火は、`expected.md` に記載があれば照合し、無ければ参考記録とする。
- **抜き取り確認**: 評価者の出力はドラフトとして扱い、各観点で2〜3件の主張（指摘の行番号、比較の相手、列挙した権限、plan のアドレス、validate の診断の位置）を fixture・worktree・定義と照らした。判定に影響する齟齬は無かった（軽微なもの: `03-positive-same-type` の指摘箇所の行番号を、新規ファイルの行でなく fixture 上の行で書いた）。

### worktree との名前の重なりの確認

評価の前（定義 a9ecd60 の時点）に、01〜09 の全 fixture が新規追加または書き換えとする定義の名前（locals 名・resource の (TYPE, NAME)・variable 名・ファイル名・Ruleset 名）を、worktree ルートの `*.tf` と突き合わせた。分類は (a) 既存の定義を書き換える PR として重なり、その旨が fixture に明記されている、(b) 明記の無い重なり（PR 後の状態が定義の二重化になり、定義と無関係な理由で対象外の観点が発火しうる）。その後の是正（2232cdc・a06c48d）は定義と expected.md（06・08）だけを変え、fixture の入力と worktree の `.tf` を変えていないため、この結果は最終パスにも当てはまる。

| fixture | worktree と重なった名前 → 分類 | 重ならない名前 |
|---|---|---|
| 01（陽性・陰性） | `github_repository_ruleset.branch_protection`（`branch_protection.tf`）→ (a)、節見出し「（PR 後、resource）」 | － |
| 02（陽性・陰性） | variable `repositories`（`variables.tf`）→ (a)、節見出し「（PR 後）」 | － |
| 03 `positive`・`negative` | `github_repository.this`、locals `repository_preset`（`repository.tf`）→ (a)、節見出し「（PR 後、…）」 | － |
| 03 `positive-same-type`・`negative-same-type`、適用後2件 | － | locals `sandbox_repository`、`github_repository.sandbox`、ファイル `sandbox_repository.tf` |
| 04 `positive`・`negative` | `github_repository_ruleset.branch_protection` → (a)、節見出し「（PR 後、resource）」 | － |
| 04 `boundary-count-one` | locals `branch_protection_preset` → (a)、節見出し「（PR 後、変更部分）」 | `github_repository_ruleset.branch_protection_self` |
| 05（陽性・陰性） | `github_repository_ruleset.branch_protection` → (a)、節見出し「（PR 後、resource）」 | － |
| 06 `positive-repository` | variable `repositories` → (a)、節見出し「（PR 後、…）」 | － |
| 06 `positive-branch-protection` | variable `repositories` → (a)、節見出し「（PR 後、抜粋）」 | locals `branch_protection` |
| 06 `positive-default-as-policy` | variable `repositories`、`github_repository.this` → (a)、節見出し「（PR 後、…）」 | － |
| 06 `negative-repository` | locals `repository_preset`、`github_repository.this`、variable `repositories` → (a)、節見出し「（PR 後、抜粋…）」 | － |
| 06 `negative-branch-protection` | locals `branch_protection_preset`、`github_repository_ruleset.branch_protection` → (a)、節見出し「（PR 後、抜粋…）」 | － |
| 06 `negative-override-with-fallback` | variable `repositories`、`github_repository.this` → (a)、節見出し「（PR 後、…）」 | locals `repository_settings` |
| 06 `negative-local-convention` | － | locals `release_branch_protection_preset`・`release_branch_protection_targets`、`github_repository_ruleset.release_branches`、ファイル `ruleset_release_branches.tf`、Ruleset 名 `release branch protection` |
| 06 `adr0004-compliant-tag-protection`、07 `negative-ruleset` | `tag_protection.tf` 一式（locals `tag_protection_targets`・`tag_protection_profile_defaults`・`tag_protection_preset`、`github_repository_ruleset.tag_protection`、Ruleset 名 `tag protection`）→ (a)、冒頭のコメントに「評価では worktree の `tag_protection.tf` の代わりに、下記を PR 後の内容として扱う」旨を明記 | － |
| 07 `positive-secret`・`positive-file`・`positive-secret-applied` | `variables.tf`（`positive-secret` の節見出し「（PR 後、追加部分）」）→ (a) | variable `deploy_token`、locals `actions_secrets_preset`・`codeowners_preset`、`github_actions_secret.actions_secrets`・`github_actions_secret.deploy_token`、`github_repository_file.codeowners`、ファイル `actions_secrets.tf`・`codeowners.tf` |
| 07 `negative-rename-applied` | `dependabot_security_updates.tf` とその resource（既存ファイルへの実差分）→ (a) | 新しいラベル `security_updates` |
| 08 | plan テキストは定義を持たない（アドレスは worktree に実在する resource を指す）。`import-block.tf.example` は既存のアドレスを取り込み対象にするブロックだけで、新しい定義を持たない | ファイル `import.tf` |
| 09 | 既存ファイルへの実差分（`positive-attribute`・`negative`・`boundary-preexisting`・`boundary-rewritten-preexisting`）は新しい名前を持たない | `positive-resource` の `deployment_branch_policy.tf`・`github_repository_deployment_branch_policy.sandbox`、`mixed-preexisting-and-new` の `sandbox_repository.tf`・`github_repository.sandbox` |

結果: 重なった名前はすべて (a) で、(b) は0件。直した fixture は無い。

### 全ケースの照合

テストケース対応表の AC3 の全ケースと、境界の追加ケース `09-boundary-rewritten-preexisting`（ユーザー決定）の計40件。「実出力」は評価者の最終報告から取った。行番号のうち `.tf.example` のケースは fixture 上の行。観点9 の ✅・❌ には限界の併記が付いている（定義どおり）。「記録の検査」の (i) は適用後ケースで worktree (post) 配下の適用ファイルを読んだ記録、(ii) は書き込み・git 操作が無いこと、(iii) は Read・Bash（grep 等）の結果に `expected.md`・`verification.md`・reviewer README の行が無いこと。

| 観点# | ケース | fixture | 期待 | 実出力 | 本リポ文書の引用 | 記録の検査 | 判定 |
|---|---|---|---|---|---|---|---|
| 1 | 01-positive | `01-moved-missing/positive.tf.example` | 観点1 blocker（`github_repository_ruleset.branch_protection` の `for_each` キー変更に `moved` なし） | 観点1 blocker（`branch_protection.tf:17`、キーの体系の変更に `moved` なし。出典は Refactoring・`moved` の解説）。他の観点は発火なし | なし | (ii)(iii) 確認済み | PASS |
| 1 | 01-negative | `01-moved-missing/negative.tf.example` | 観点1 発火なし | 指摘なし | なし | (ii)(iii) 確認済み | PASS |
| 2 | 02-positive | `02-validation-missing/positive.tf.example` | 観点2 warning（`enforcement`・`allowed_merge_methods`） | 観点2 warning×2（`variables.tf:28` の `enforcement`、`:32` の `allowed_merge_methods`） | なし | (ii)(iii) 確認済み | PASS |
| 2 | 02-negative | `02-validation-missing/negative.tf.example` | 観点2 発火なし | 指摘なし | なし | (ii)(iii) 確認済み | PASS |
| 3 | 03-positive | `03-lifecycle-coverage/positive.tf.example` | 観点3 warning（検出条件 (a)、`github_repository.this` の `ignore_changes` から `archived` を外す） | 観点3 warning（`repository.tf:120`、`archived` の変更無視を外している。出典は lifecycle） | なし | (ii)(iii) 確認済み | PASS |
| 3 | 03-negative | `03-lifecycle-coverage/negative.tf.example` | 観点3 発火なし | 指摘なし | なし | (ii)(iii) 確認済み | PASS |
| 3 | 03-positive-same-type | `03-lifecycle-coverage/positive-same-type.tf.example` | 観点3 warning（検出条件 (b)、`github_repository.sandbox` が `github_repository.this` の `visibility`・`archived` の保護を欠く） | 観点3 warning（`sandbox_repository.tf:13`〔fixture 上の行〕、同旨。`this`〔`repository.tf:66`〕の保護は比較の相手として示し、出典は lifecycle） | なし | (ii)(iii) 確認済み | PASS |
| 3 | 03-negative-same-type | `03-lifecycle-coverage/negative-same-type.tf.example` | 観点3 発火なし | 指摘なし | なし | (ii)(iii) 確認済み | PASS |
| 3 | 03-positive-same-type-applied | `03-lifecycle-coverage/positive-same-type-applied.diff`（適用後） | 観点3 warning（追加集合 A の `sandbox` を既存に数えない） | 観点3 warning（`sandbox_repository.tf:8`、比較の相手は `repository.tf:66` の `this`） | なし | (i) worktree (post) のルートの `*.tf` を対象にした grep の結果に適用ファイルの行 `sandbox_repository.tf:8:resource "github_repository" "sandbox" {`（`ls *.tf` にも同ファイル。main checkout に同名ファイルは無い）。(ii)(iii) 確認済み | PASS |
| 3 | 03-negative-same-type-applied | `03-lifecycle-coverage/negative-same-type-applied.diff`（適用後） | 観点3 発火なし | 指摘なし（`this` と `sandbox` の `ignore_changes` が一致） | なし | (i) worktree (post) のルートの `*.tf` を対象にした grep の結果に適用ファイルの行 `sandbox_repository.tf:8:resource "github_repository" "sandbox" {`（`ls -la` にも同ファイル）。(ii)(iii) 確認済み | PASS |
| 4 | 04-positive | `04-for-each-vs-count/positive.tf.example` | 観点4 warning（`count = length(keys(var.repositories))`） | 観点4 warning（fixture 9・13 行、出典は `count`・`for_each`） | なし | (ii)(iii) 確認済み | PASS |
| 4 | 04-negative | `04-for-each-vs-count/negative.tf.example` | 観点4 発火なし | 指摘なし | なし | (ii)(iii) 確認済み | PASS |
| 4 | 04-boundary-count-one | `04-for-each-vs-count/boundary-count-one.tf.example` | 観点4 発火なし（`count = 条件 ? 1 : 0`） | 観点4 発火なし。対象外: 観点5 suggestion（参考記録） | なし | (ii)(iii) 確認済み | PASS |
| 5 | 05-positive | `05-hardcoded-values/positive.tf.example` | 観点5 suggestion（`integration_id = 15368`） | 観点5 suggestion（fixture 50 行） | なし | (ii)(iii) 確認済み | PASS |
| 5 | 05-negative | `05-hardcoded-values/negative.tf.example` | 観点5 発火なし | 指摘なし | なし | (ii)(iii) 確認済み | PASS |
| 6 | 06-positive-repository | `06-preset-merge/positive-repository.tf.example` | 観点6 blocker、不変条件3、出典は型制約 `optional` | 観点6 blocker（`variables.tf:14` の `visibility`）、不変条件3、出典は型制約 `optional`。指摘の文面に本リポ文書の名前・節番号・手続きの名前なし | なし | (ii)(iii) 確認済み | PASS |
| 6 | 06-positive-branch-protection | `06-preset-merge/positive-branch-protection.tf.example` | 観点6 blocker、不変条件1、出典は `null` と、型制約 `optional` または `merge` | 観点6 blocker×2（`branch_protection.tf:45` の `enforcement`、`:48` の `required_approving_review_count`）、不変条件1、出典は「Types and Values」の `null`・型制約 `optional`。`merge` の使用そのものは指摘していない（修正方針に null のフォールバックか、null を除いてから `merge` する形を示す） | なし | (ii)(iii) 確認済み | PASS |
| 6 | 06-positive-default-as-policy | `06-preset-merge/positive-default-as-policy.tf.example` | 観点6 blocker、不変条件2、出典は型制約 `optional` | 観点6 blocker（`variables.tf:13`）、不変条件2、出典は型制約 `optional` | なし | (ii)(iii) 確認済み | PASS |
| 6 | 06-negative-repository | `06-preset-merge/negative-repository.tf.example` | 観点6 発火なし | 指摘なし | なし | (ii)(iii) 確認済み | PASS |
| 6 | 06-negative-branch-protection | `06-preset-merge/negative-branch-protection.tf.example` | 観点6 発火なし | 指摘なし | なし | (ii)(iii) 確認済み | PASS |
| 6 | 06-adr0004-compliant-tag-protection | `06-preset-merge/adr0004-compliant-tag-protection.tf.example` | 観点6 発火なし | 指摘なし | なし | (ii)(iii) 確認済み | PASS |
| 6 | 06-negative-local-convention | `06-preset-merge/negative-local-convention.tf.example` | いずれの観点も発火しない | 指摘なし | なし | (ii)(iii) 確認済み | PASS |
| 6 | 06-negative-override-with-fallback | `06-preset-merge/negative-override-with-fallback.tf.example` | いずれの観点も発火しない（`merge` を理由にしない） | 指摘なし（null を除いてから `merge` で重ねている） | なし | (ii)(iii) 確認済み | PASS |
| 7 | 07-positive-secret | `07-app-permission-boundary/positive-secret.tf.example` | 観点7 warning、Secrets（書き込み）・Metadata（読み取り） | 観点7 warning（`actions_secrets.tf:7` の `github_actions_secret.actions_secrets`）、Secrets（書き込み）・Metadata（読み取り）。付与状況との照合は呼び出し側で行う旨だけで、照合の結果・「境界外」の判定なし | なし | (ii)(iii) 確認済み | PASS |
| 7 | 07-positive-file | `07-app-permission-boundary/positive-file.tf.example` | 観点7 warning、Contents（書き込み）・Metadata（読み取り） | 観点7 warning（`codeowners.tf:10` の `github_repository_file.codeowners`）、Contents（書き込み）・Metadata（読み取り）。照合の結果・「境界外」の判定なし | なし | (ii)(iii) 確認済み | PASS |
| 7 | 07-negative-ruleset | `07-app-permission-boundary/negative-ruleset.tf.example` | 観点7 発火なし | 指摘なし（`branch_protection.tf` に変更前からの同型） | なし | (ii)(iii) 確認済み | PASS |
| 7 | 07-positive-secret-applied | `07-app-permission-boundary/positive-secret-applied.diff`（適用後） | 観点7 warning、Secrets（書き込み）・Metadata（読み取り） | 観点7 warning（`actions_secrets.tf:13` の `github_actions_secret.deploy_token`）、Secrets（書き込み）・Metadata（読み取り）。照合の結果・「境界外」の判定なし | なし | (i) worktree (post) のルートの `*.tf` を対象にした grep の結果に適用ファイルの行 `actions_secrets.tf:13:resource "github_actions_secret" "deploy_token" {`（`ls` にも同ファイル。走査はルート直下の `*.tf` に限り、fixture 配下の例示を数えていない）。(ii)(iii) 確認済み | PASS |
| 7 | 07-negative-rename-applied | `07-app-permission-boundary/negative-rename-applied.diff`（適用後） | 観点7・観点1 発火なし | 指摘なし（R の旧ラベルを変更前からの同型と数える。`moved` あり） | なし | (i) worktree (post) 配下の `dependabot_security_updates.tf` を Read（結果の23行目が新しいラベル `security_updates`、30〜33行目に `moved`）。main checkout の同名ファイルは読んでいない。出力も発火しない理由に R を挙げる。(ii)(iii) 確認済み | PASS |
| 8 | 08-plan-positive-destroy | `08-plan-time-risk/plan-positive-destroy.txt` | 観点8 warning（`1 to destroy`、`github_repository_ruleset.branch_protection["github-config"]`） | 観点8 warning（同じアドレス、`1 to destroy`） | なし | (ii)(iii) 確認済み | PASS |
| 8 | 08-plan-positive-replace | `08-plan-time-risk/plan-positive-replace.txt` | 観点8 warning（`-/+ resource`・`forces replacement`・`must be replaced`、`["gachanuma"]`） | 観点8 warning（同じアドレス、同じパターン。`name` の変更が置換を起こす） | なし | (ii)(iii) 確認済み | PASS |
| 8 | 08-plan-negative-nochange | `08-plan-time-risk/plan-negative-nochange.txt` | 観点8 発火なし | 観点8 ✅ | なし | (ii)(iii) 確認済み | PASS |
| 8 | 08-plan-empty | `08-plan-time-risk/plan-empty.txt` | 観点8 未評価（plan 出力未提供） | 観点8 未評価（plan 出力未提供。空の plan 出力を未提供と同じに扱った） | なし | (ii)(iii) 確認済み | PASS |
| 8 | 08-import-with-replace | `08-plan-time-risk/import-block.tf.example` ＋ `plan-positive-replace.txt` | 観点8 blocker（取り込みと同時に置換され既存リソースが作り直される）。修正方針は、置換・破棄されない状態にしてから取り込むことだけ | 観点8 blocker（`import` ブロック、`["gachanuma"]`）、主旨一致。修正方針は「当該アドレスが同じ plan で置換・破棄されない状態にしてから取り込むこと。」だけ | なし | (ii)(iii) 確認済み | PASS |
| 9 | 09-positive-attribute | `09-provider-deprecation/positive-attribute.diff` ＋ `validate-positive-attribute.txt` | 観点9 warning、`repository.tf:82` | 観点9 warning、`repository.tf:82`（`vulnerability_alerts`） | なし | (ii)(iii) 確認済み | PASS |
| 9 | 09-negative | `negative.diff` ＋ `validate-negative.txt` | 観点9 発火なし | 観点9 ✅ | なし | (ii)(iii) 確認済み | PASS |
| 9 | 09-positive-resource | `positive-resource.diff` ＋ `validate-positive-resource.txt` | 観点9 warning、`deployment_branch_policy.tf:1`（観点7 warning「未確定」は発火しうる） | 観点9 warning、`deployment_branch_policy.tf:1`。観点7 warning（必要権限: 未確定）は expected.md の記載どおり。対象外: 観点5 suggestion×2（参考記録） | なし | (ii)(iii) 確認済み | PASS |
| 9 | 09-boundary-preexisting | `boundary-preexisting.diff` ＋ `validate-boundary-preexisting.txt` | 観点9 発火なし | 観点9 ✅（診断の位置が追加行に無い） | なし | (ii)(iii) 確認済み | PASS |
| 9 | 09-boundary-rewritten-preexisting | `boundary-rewritten-preexisting.diff` ＋ `validate-boundary-rewritten-preexisting.txt` | 観点9 発火なし（同じ resource の削除行に同じ属性） | 観点9 ✅（同じ resource の削除行に `vulnerability_alerts`） | なし | (ii)(iii) 確認済み | PASS |
| 9 | 09-mixed-preexisting-and-new | `mixed-preexisting-and-new.diff` ＋ `validate-mixed-preexisting-and-new.txt` | 観点9 warning、`sandbox_repository.tf:6` だけ（`repository.tf:82` は指摘しない） | 観点9 warning、`sandbox_repository.tf:6`（`has_downloads`）だけ。`repository.tf:82` は差分外として指摘しない。対象外: 観点5 suggestion（参考記録） | なし | (ii)(iii) 確認済み | PASS |
| 9 | 09-unprovided | `positive-attribute.diff` だけ（validate 出力を渡さない） | 観点9 未評価（validate 出力未提供）、知識による指摘なし | 観点9 未評価（validate 出力未提供）、観点9 の指摘なし | なし | (ii)(iii) 確認済み。`validate-*.txt` の読み取りなし | PASS |

40件すべて PASS。AC1 の関連の確認:

- 全40件で、指摘の根拠・指摘内容・修正方針・総評に、本リポの ADR・設計仕様書・CLAUDE.md の引用や、それらが定める手続きの名前は無い（出力を文書名・節番号・手続きの語で走査し、一致したのは禁止事項を守った旨の記述と fixture 名 `adr0004-compliant-tag-protection` だけだった）。worktree の `.tf` には設計記録の節を参照するコメントがあり（例: `repository.tf` の `lifecycle` のコメント）、評価者はそれを読んだが、指摘に使っていない。
- 観点7 の陽性（`07-positive-secret`・`07-positive-file`・`07-positive-secret-applied`、`09-positive-resource` の観点7）で、付与済み権限との照合の結果・「境界外」の判定・blocker は無く、必要権限の列挙と、付与状況との照合は呼び出し側で行う旨だけを出した。

### 対象観点以外の発火（参考記録）

いずれも定義に反する判定ではない。

| ケース | 発火 | 内容 | 定義との関係 |
|---|---|---|---|
| 04-boundary-count-one | 観点5 suggestion | `repository = "github-config"` の直書き | 観点5 の「観点間の境界」が対象に挙げるリポジトリ名固有の文字列に当たる |
| 09-positive-resource | 観点7 warning（必要権限: 未確定） | 静的表に無い `github_repository_deployment_branch_policy` の新規使用 | 観点7 の「表に無い型の扱い」どおり。expected.md 09 の「他の観点の発火」に記載があり、照合上も一致 |
| 09-positive-resource | 観点5 suggestion×2 | `repository = "sandbox-repo"`、`environment_name = "production"` | リポジトリ名固有の文字列、環境依存値に当たる |
| 09-mixed-preexisting-and-new | 観点5 suggestion | `name = "sandbox-repo"` | リポジトリ名固有の文字列に当たる |

1回目の評価（定義 a9ecd60）との違い（参考）: `04-positive` で、1回目は観点4 warning と同時に観点1 blocker（worktree の `for_each` から `count` への切替に `moved` が無い）を出したが、最終パスは「`.tf.example` に `+`/`-` の行が無く、観点1 の抽出の対象が無い」として観点1 を出さなかった。expected.md 04 は観点1 に触れず、照合の対象外。差分の形でない入力で観点1 の検出条件3（`+`/`-` の行からの切替の抽出）をどう読むかが、評価者によって揺れた。`09-positive-resource` の観点5 は、1回目の3件（`name = "release/*"` を含む）から最終パスで2件になった。

### 観点9 の実測

J3（resource 単位の非推奨でも validate が警告を出す）と J7（人間向け出力が同じ要約の警告を集約するか）の実測、fixture 09 の validate 出力の取得手順、判定の限界の実測は、「## 観点9 の実測記録（#103）」節を参照。

### 実機補強

実機未取得。実装セッションのエージェント一覧に表示された `terraform-design-reviewer` の説明文が改訂前の定義のもの（観点9 を含まない観点の列挙）で、改訂後の定義が読み込まれることを確かめられなかったため（`subagent_type` の名前解決が main checkout の改訂前の定義を指す可能性がある）。実機起動による補強は、既存記録の観点1 陽性1ケース（#20 時点）に留まる。

### PASS しなかったケースと直した経緯

1. **1回目の評価**（定義 a9ecd60、同じ条件の14体、40件）: PASS 38件。PASS しなかったのは次の2件。
   - `08-import-with-replace`: 発火・blocker・主旨は期待どおりだったが、修正方針の欄に、構成側を実リソースの現状値に合わせるか `lifecycle.ignore_changes` 等で吸収するという収束のさせ方を書き、検証すべき振る舞い（収束のさせ方を指示しない）に反した。原因は、指摘テーブルが修正方針の列を埋めることを求める一方で、格上げ時の文言に修正方針の書き方が無く、評価者が warning の指摘文言テンプレ（`lifecycle.ignore_changes` の見直し）から補ったこと。`expected.md` 08 にも修正方針の照合項目が無かった。
   - `06-positive-branch-protection`: 発火・blocker・不変条件1 は期待どおりだったが、出典に `merge`・`null` を挙げ、当時の `expected.md` が求めていた型制約 `optional` を欠いた。原因は、定義の入出力例「陽性（不変条件 1）」が、`merge` を使わない形（既定値なしの `optional` の値をそのまま使う）にも出典 `merge`・`null` を当てていたこと（評価者は入出力例どおりに書いた）。
2. **是正（2232cdc）**: 観点8 の格上げの修正方針を「当該アドレスが同じ plan で置換・破棄されない状態にしてから取り込んでください。」とだけ書くと定め、構成と実リソースのどちらを変えて解消するかは指示しない（PR の作成者が決める）と書いた。`expected.md` 08 の陽性3 に同じ照合項目を足した。観点6 の入出力例「陽性（不変条件 1）」の出典を形ごとに分けた（既定値なしの `optional` の値をそのまま使う形は型制約 `optional` と `null`、上書き側の null を除かずに `merge` で重ねる形は `merge` と `null`）。
3. **再試験**（定義 2232cdc、08 の5件と 06 の8件を新しい評価者で）: 08 の5件は期待どおりだった（格上げの修正方針は、置換・破棄されない状態にしてから取り込むことだけ）。06 で次の問題が出た。
   - `06-positive-repository`: 発火・blocker・不変条件3・出典（型制約 `optional`）は期待どおりだったが、指摘内容に、worktree の `variables.tf` のコメントが参照する設計記録の節番号を書き、修正方針でリポジトリ固有の手続きの名前に触れた（本リポ文書の引用に当たる）。`06-negative-override-with-fallback`（発火なし）も、出典の欄で同じ手続きの名前に触れた。原因は、定義がリポジトリ固有の規約文書を判定の根拠にしないとだけ定め、指摘の説明に使うことを止めていなかったこと。
   - `06-positive-branch-protection`: 発火・blocker・不変条件1 は期待どおりで、出典に「Types and Values」の `null` を挙げたうえで、直し方として null を除いてから `merge` する形を示し、`merge` を出典にした（型制約 `optional` は挙げなかった）。どの一般的な出典を補助に挙げるかは指摘が示す直し方の形に依るため、`expected.md` 06 が型制約 `optional` だけを求めていたことは、一般的な出典のどれを選ぶかまで固定し、判定の根拠の一般性とは無関係の不一致を生んでいた。
4. **是正（a06c48d）**: 定義の「文脈としての参照」に、指摘内容・修正方針・総評にもリポジトリ固有の規約文書の名前・節番号や、それらが定める経路・手続きの名前を書かないこと、worktree のファイルのコメントがそれらを参照していても判定の根拠にも指摘の説明にも使わないことを加えた。`expected.md` 06 の陽性2 の「根拠の示し方」を、`null` を必須とし、型制約 `optional` か `merge` のいずれかを認める形に改めた。
5. **最終パス**: 全ケースに共通する枠（「文脈としての参照」）を変えたため、全40件を a06c48d で評価し直した（上記「全ケースの照合」）。40件すべて PASS。

### #103 で削除・改名した fixture と改めた定義の節名

- **改名**（旧名 → 新名。いずれも `fixtures/06-preset-merge/`）: `adr0004-violation-value-category.tf.example` → `positive-default-as-policy.tf.example`、`adr0004-violation-ledger.tf.example` → `negative-override-with-fallback.tf.example`、`adr0004-violation-naming.tf.example` → `negative-local-convention.tf.example`。改名の直後、内容を書き直す前に `git diff --cached -M --name-status` で3件とも R100 と表示されることを確かめた（コミット 5499efb）。書き直した後は、squash マージの履歴で改名として検出されない場合がある
- **削除**（`fixtures/06-preset-merge/`、いずれも `.tf.example`）: `adr0004-compliant-ledger`・`adr0004-compliant-import`・`adr0004-violation-import`・`adr0004-compliant-nesting`・`adr0004-violation-nesting`・`adr0004-violation-locals-name`・`adr0004-violation-visibility`・`adr0004-violation-profile`
- **名前を維持**: `adr0004-compliant-tag-protection.tf.example`（ADR 0009 と既存記録がこの名前で参照するため。内容は一般判定の陰性として使い、前提のコメントを改めた）
- **改めた定義の節名**: 各観点の「実現形の参照先」は「判定の根拠」（一般的な出典）へ置き換えた。観点6 の「既知の未適用事項」は削除した

### 既存記録の読み方（J1）

本ファイルの既存記録（冒頭から「## 結論」節まで）は、#103 で削除・改名した fixture（上記）、#103 で内容を改めた fixture（01・02・03・06・07）と expected.md（02〜08。01 も「期待する判定根拠」の節を足した）、改めた定義の節名（「実現形の参照先」「既知の未適用事項」）を含め、改訂前の版を指す。改訂前の版は git 履歴で参照する。例えば、既存の照合表の観点3 陽性・観点7 陽性の期待 blocker は、改訂後の warning と異なる。

### 観点7 の静的表の是正（J4）

- `github_repository_dependabot_security_updates` の行を「Administration RW + Dependabot Alerts RW」から「Administration（書き込み）」へ直した（表の誤り。J4 の仮定どおり）。provider v6.12.1 の実装はこの型で `/repos/{owner}/{repo}/automated-security-fixes` の GET・PUT・DELETE だけを呼び、GitHub Apps permissions reference では、これらのエンドポイントは「Administration」の節（read・write・write）にだけあり、「Dependabot alerts」の節には無い。App の権限の記述（CLAUDE.md §3）と App permission scope は変えていない。
- ほかの行も、provider v6.12.1 の各 resource の実装が呼ぶエンドポイントを permissions reference とエンドポイントのドキュメントで引き直し、権限名を GitHub Apps の権限名にそろえた: `Actions: Secrets` → Secrets、`Actions: Variables` → Variables、`github_repository_environment` の Environments → Administration（書き込み）・Actions（読み取り）、`github_team_repository` に Members（organization の権限。読み取り）を追加、`github_issue_label` に「または Pull requests」を追加、`github_repository_dependabot_security_updates`・`github_issue_label` を除く各行に Metadata（読み取り）を追加。アクセスの表記は Access 列に合わせて「書き込み」「読み取り」とし、導出元の URL を現行のパスへ張り替えた。行ごとの照合の出典は、コミット 1b6acc7 の本文にある。

### 結論

#103 の改訂後の定義（a06c48d）で、テストケース対応表 AC3 の全39ケースと境界の追加ケース `09-boundary-rewritten-preexisting` の計40件すべてで、対象観点の判定が期待と一致した（**代理試験**、各1回）。全ケースで、指摘の根拠と説明に本リポの ADR・設計仕様書・CLAUDE.md の引用は無かった。適用後ケース4件で worktree (post) 配下の適用ファイルを読んだこと、14体すべてで書き込み・git 操作が無く、ツールの結果に期待値の行が無いことを、評価者の記録で確かめた。実機 `terraform-design-reviewer` 起動による補強は取得していない。
