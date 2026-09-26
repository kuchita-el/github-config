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

- 観点 6 が、観点 1〜5・7 の既存フィクスチャで副次的に発火した（blocker: `03` 陽性・陰性、`04` 陽性・境界、`05` 陽性、`07` 全3件 / warning（判定の限界）: `01` 陽性・陰性、`02` 陽性・陰性、`04` 陰性、`05` 陰性）。原因は、これらのフィクスチャの背景コード（対象観点と無関係な部分）が ADR 0004 以前の構造（全リポ共通値のリテラル直書き、`repositories` のフラットなフィールド、単一リポの固定インスタンス等）で書かれていることで、reviewer 定義の誤りではない。#20 時点の検証は対象観点だけを評価しており、副次発火は測っていなかった。背景コードを現行構造へ揃えるかどうかは別途判断する。
- 観点 5（suggestion）が `04` 陽性・境界、`07` 全3件でリポ名の直書きに対して発火した。

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
- **既存フィクスチャの背景コード**: 観点 1〜5・7 のフィクスチャの背景コードは ADR 0004 以前の構造のままで、観点 6 の副次発火を招く（「対象観点以外の発火」節）。
- **#79 の再試験中の定義の文言修正**: 評価の開始後に、観点 8 の不変条件の2文目を言い換えた（取り込み時に Terraform が実設定を変更しない旨の表現の明確化。判定手順・検出パターン・重要度は不変）。観点 8 の評価者が修正前後のどちらを読んだかは記録していない。

## 結論

#79 の再試験で、既存 22 ケース、ADR 0004 §3〜§7 の8つの規約領域の違反・準拠 12 ケース（準拠は一部が複数領域を兼ねる）、現行コード（AC4）のすべてで、対象観点の判定が期待と一致した（**代理試験**、各1回）。実機 `terraform-design-reviewer` 起動による補強は観点 1 陽性 1 ケース（#20 時点）に留まる。
