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

J7 が仮定と異なった（人間向け出力が集約する）ため、Task 5a はここで停止する。`validate-mixed-preexisting-and-new.txt` は未作成（4. のユーザー回答後に選ばれた形で作る）。`mixed-preexisting-and-new.diff` は形式非依存のため保存済み。

### ユーザー回答後の取り直し（2026-09-28）

J7 不成立を受け、ユーザーは選択肢 (a)（観点9 の入力と README 併用節 (d) の取得手順を `terraform validate -json` の出力に変える）を選んだ。理由: 人間向け出力（`-no-color`）は同じ要約 `Argument is deprecated` の警告を1件に集約し、変更前からの使用と新規使用が同居すると新規使用側の位置が消えるため（上記の実測）。選択肢 (b)（人間向け出力のまま限界として明記する）は、新規使用の見落としが手順を変えても構造的に残る点が採らなかった理由。

この選択に伴い、fixture 09 の全ケース（陽性・属性／陰性／境界／陽性・resource／組み合わせ）の validate 出力を `mise exec -- terraform validate -json`（各ケースとも 2. と同じ一時編集を作り直した状態、単独コマンド）で取り直し、`validate-*.txt`（ファイル名は変えず、内容を `-json` の出力に置換。組み合わせケースのみ新規に `validate-mixed-preexisting-and-new.txt` を作成）とした。各ケースとも、作り直した状態の `git diff`（または `git diff --no-index /dev/null <一時ファイル>`）が保存済みの `.diff`（先頭のコメント行を除く）と一致することを確認した。

`-json` 出力（`diagnostics[].range.filename`・`range.start.line`）は次のとおり:

- 陽性（属性）: `repository.tf` line 82（`positive-attribute.diff` の追加行と一致）
- 陰性: 警告なし（`diagnostics: []`）
- 境界: `repository.tf` line 82（`boundary-preexisting.diff` の追加行〔`variables.tf`〕には無い）
- 陽性（resource）: `deployment_branch_policy.tf` line 1（`positive-resource.diff` の追加行と一致）
- 組み合わせ: 2件、`sandbox_repository.tf` line 6（`mixed-preexisting-and-new.diff` の追加行 `has_downloads = true` と一致）と `repository.tf` line 82（前提の既存使用側）。集約されず両方とも `range` を個別に持つ。

すべてのケースの後始末（`git restore repository.tf variables.tf`、一時ファイル `deployment_branch_policy.tf`・`sandbox_repository.tf` の削除）を行い、`git status --short` で `.tf`・`.tfvars`・`.terraform.lock.hcl` の変更・未追跡が無いことを確認した。

### 書き換えのケースの追加（2026-09-28、ユーザー決定 (b)）

Task 5b のレビューで、行単位の照合では変更前からある非推奨の属性の行が `terraform fmt` の桁揃え等で削除行と追加行の組になると、新規の使用と誤って指摘されることが分かった。ユーザーは (b)（同じ resource の削除行に同じ属性の行がある場合、または削除行に同じ型の resource の見出し行がある場合は、変更前からの使用の書き換えとみなして指摘しない）を選んだ。resource 単位の条件は、その後のコントローラの裁定で、差分の `moved` ブロックによる同じ型の変更前のアドレスからの移動か、同じ hunk 内の見出し行の書き換えに限った（別の場所で同じ型の resource を削除しただけでは書き換えとみなさない）。この規則の陰性ケースとして、fixture 09 に `boundary-rewritten-preexisting.diff`／`validate-boundary-rewritten-preexisting.txt` を追加した。

- **手順**（作業ディレクトリは worktree ルート。fmt・validate・git はそれぞれ単独コマンド）: `git status --short` でインデックスと `.tf` が clean であることを確認 → `repository.tf` の `github_repository.this` に `vulnerability_alerts = true` を加えて `mise exec -- terraform fmt repository.tf` で整形し、`git add repository.tf` でインデックスに置いた（インデックス＝PR 前の状態。インデックスの blob は `427df50` で、`positive-attribute.diff` の適用後と同じ）→ 同じ桁揃えのまとまりに `web_commit_signoff_required = true`（provider docs v6.12.1 の `github_repository` に非推奨の記載なし、`github_repository.this` に未設定）を加えて fmt で整形 → `git diff -- repository.tf`（作業ツリー対インデックス＝PR の差分）を保存 → `mise exec -- terraform validate -json` を実行 → `git restore --staged repository.tf`、`git restore repository.tf` で戻し、`git status --short`・`git diff --cached --name-only` でインデックス・`.tf` とも clean を確認。
- **差分**: hunk `@@ -75,11 +75,12 @@ resource "github_repository" "this" {`。桁揃えで `archived`・`description`・`homepage_url`・`topics`・`vulnerability_alerts` の5行が削除行と追加行の組になり、`web_commit_signoff_required = true` が1行増えた（追加行は 78〜83 行目、`vulnerability_alerts        = true` は 82 行目）。
- **validate -json**: `"valid": true`、`"warning_count": 1`。警告は `Argument is deprecated`（`address` `github_repository.this`、`range` `repository.tf` line 82 column 33〜37）の1件だけで、`web_commit_signoff_required` には警告が無かった（非推奨でないことの確認）。警告の行は差分の追加行に当たり、同じ resource の削除行に `vulnerability_alerts = true` がある。
- **validate の失敗時の出力（参考）**: 同じ状態で、出力をファイルへリダイレクトする形（`mise exec -- terraform validate -json > <file>`）で実行したところ、サンドボックスの除外に一致せず provider プラグインを起動できずに失敗した。出力は `"valid": false`、`"error_count": 1`、`"warning_count": 0` で、診断は `Failed to load plugin schemas`（`range` なし）の error 1件だけだった。validate が失敗すると非推奨の警告が0件になる例として記録する（観点9 の「未評価（validate が失敗）」の扱いの裏付け）。この出力は fixture に使わず、fixture には単独コマンドで取得した上記の出力を原文のまま書き写した。
