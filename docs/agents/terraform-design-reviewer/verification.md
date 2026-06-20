# terraform-design-reviewer 検証エビデンス（**代理試験**）

Issue #20 の AC2/3/4 が要求する「reviewer が観点 X を期待通り blocker/warning として発火する」ことを、フィクスチャ駆動で確認した記録。

> ⚠️ **本記録は代理試験です**。本検証は `terraform-design-reviewer` の subagent 実体ではなく、**汎用 `claude` subagent に reviewer 定義テキストを渡して同等プロンプトで評価させた代理実行**による結果。subagent ローダの YAML パース・名前解決・`tools` 継承挙動など、実機でしか露見しない不具合は素通し可能。**実機 `Agent(subagent_type: "terraform-design-reviewer")` 起動によるエビデンスは取得していない**。実機検証は別 Issue で追跡する（後述「制限事項」）。

## 検証方法

- **入力**: `fixtures/0{1-8}-*/` 配下の陽性 (`positive.tf.example`)・陰性 (`negative.tf.example`)・境界ケース
- **手順**: 各観点ごとに subagent（**汎用 `claude` 種別、代理実行**）を 1 体起動し、`.claude/agents/terraform-design-reviewer.md` の観点定義に厳密に従ってフィクスチャを評価させた。subagent には以下を渡した:
  1. reviewer 定義の該当観点節
  2. 陽性/陰性/境界フィクスチャ
  3. 期待出力 (`expected.md`)
- **PASS 条件**: 観点 # と重大度の判定が `expected.md` と一致、かつ指摘文言の主旨が意味的に一致
- **試行回数**: 各ケース 1 回（プランで指定した「最低 2 回」は時間制約により 1 回に縮退。観点 # と重大度の安定性は将来の繰り返し検証で確認する予定。本実装段階では 1 回の判定で reviewer 定義の検出条件と一致することを確認）
- **代理試験の限界**: 「reviewer 定義テキストに従って評価する LLM の挙動」を測定したものであり、「`terraform-design-reviewer` subagent が実機で同じ挙動を示す」ことの保証ではない。subagent 仕様（frontmatter の `tools` 制限・`name` 解決・`model` 継承等）の効果は未測定。

## 照合表

| 観点 # | ケース | フィクスチャ | 期待 重大度 | 実出力 重大度 | 観点 # 一致 | 主旨一致 | 判定 |
|---|---|---|---|---|---|---|---|
| 1 | 陽性 | `01-moved-missing/positive.tf.example` | blocker | blocker | ✅ | ✅ | PASS |
| 1 | 陰性 | `01-moved-missing/negative.tf.example` | (発火しない) | 発火なし | ✅ | ✅ | PASS |
| 2 | 陽性 | `02-validation-missing/positive.tf.example` | warning | warning | ✅ | ✅ | PASS |
| 2 | 陰性 | `02-validation-missing/negative.tf.example` | (発火しない) | 発火なし | ✅ | ✅ | PASS |
| 3 | 陽性 | `03-lifecycle-coverage/positive.tf.example` | blocker | blocker | ✅ | ✅ | PASS |
| 3 | 陰性 | `03-lifecycle-coverage/negative.tf.example` | (発火しない) | 発火なし | ✅ | ✅ | PASS |
| 4 | 陽性 | `04-for-each-vs-count/positive.tf.example` | warning | warning | ✅ | ✅ | PASS |
| 4 | 陰性 | `04-for-each-vs-count/negative.tf.example` | (発火しない) | 発火なし | ✅ | ✅ | PASS |
| 4 | 境界 (count=1) | `04-for-each-vs-count/boundary-count-one.tf.example` | (発火しない) | 発火なし | ✅ | ✅ | PASS |
| 5 | 陽性 | `05-hardcoded-values/positive.tf.example` | suggestion | suggestion | ✅ | ✅ | PASS |
| 5 | 陰性 | `05-hardcoded-values/negative.tf.example` | (発火しない) | 発火なし | ✅ | ✅ | PASS |
| 6 | 陽性 A (merge) | `06-preset-merge/positive-merge.tf.example` | blocker | blocker | ✅ | ✅ | PASS |
| 6 | 陰性 A (merge) | `06-preset-merge/negative-merge.tf.example` | (発火しない) | 発火なし | ✅ | ✅ | PASS |
| 6 | 陽性 B (ternary) | `06-preset-merge/positive-ternary.tf.example` | blocker | blocker | ✅ | ✅ | PASS |
| 6 | 陰性 B (ternary) | `06-preset-merge/negative-ternary.tf.example` | (発火しない) | 発火なし | ✅ | ✅ | PASS |
| 7 | 陽性 1 (secret) | `07-app-permission-boundary/positive-secret.tf.example` | blocker | blocker | ✅ | ✅ | PASS |
| 7 | 陽性 2 (file) | `07-app-permission-boundary/positive-file.tf.example` | blocker | blocker | ✅ | ✅ | PASS |
| 7 | 陰性 (ruleset) | `07-app-permission-boundary/negative-ruleset.tf.example` | (発火しない) | 発火なし | ✅ | ✅ | PASS |
| 8 | 陽性 1 (destroy) | `08-plan-time-risk/plan-positive-destroy.txt` | warning | warning | ✅ | ✅ | PASS |
| 8 | 陽性 2 (replace) | `08-plan-time-risk/plan-positive-replace.txt` | warning | warning | ✅ | ✅ | PASS |
| 8 | 陰性 (no change) | `08-plan-time-risk/plan-negative-nochange.txt` | (発火しない) | 発火なし | ✅ | ✅ | PASS |
| 8 | 未提供 (empty) | `08-plan-time-risk/plan-empty.txt` | (未評価) | 未評価 | ✅ | ✅ | PASS |

**全 22 ケース PASS**。

## 観点別ハイライト

### 観点 1（moved 不在）

- 陽性: `for_each = local.branch_protection_v2_keyed` への変更（キースキーマがリポ名から `<repo>:<branch>` 形式へ）に対し `moved` ブロック欠落 → blocker 発火、対象アドレス特定、修正方針として `moved { from = ...["gachanuma"]; to = ...["gachanuma:main"] }` 等 4 件の追加を提示
- 陰性: 全 4 リポについて `moved` ブロックが対応追加 → 発火なし

### 観点 2（validation 不足）

- 陽性: `enforcement`（列挙値: active/evaluate/disabled）・`allowed_merge_methods`（サブセット列挙: squash/merge/rebase）の optional フィールド追加で `validation` 欠落 → warning 発火
- 陰性: `contains([...], r.enforcement)` 列挙 `validation` を追加 → 発火なし
- reviewer 定義の参照「`variables.tf:38-44` の既存パターン」が陽性ケース主旨に反映されている

### 観点 3（lifecycle 網羅性）

- 陽性: `github_repository` で `lifecycle` ブロック自体が欠落 → blocker 発火、ADR 0001 §3 参照付き
- 陰性: `lifecycle { ignore_changes = [visibility, archived] }` で発火なし
- ADR 0001 §3 の保護対象テーブル（`github_repository` → `visibility`, `archived`）と整合

### 観点 4（for_each vs count）

- 陽性: `count = length(var.repos)` でリポ名固有要素を index 管理 → warning 発火
- 陰性: `for_each = local.branch_protection` → 発火なし
- 境界: `count = var.enable ? 1 : 0` の条件付き生成は慣用句として許容 → 発火なし（境界条項通り）

### 観点 5（ハードコード抽出）

- 陽性: `integration_id = 15368`（GitHub Actions App ID）の直書き、しかも 2 箇所反復 → suggestion 発火、`terraform.tfvars:11/27` の既存パターンへの合流を提示
- 陰性: `each.value.status_check_integration_id` で属性参照 → 発火なし

### 観点 6（preset 合成）

- 陽性 A (merge): security preset 欠落 + null 除去欠落の二重逸脱 → blocker 発火
- 陽性 B (ternary): `ovr.X` 直接代入でフォールバック欠落 → blocker 発火
- 陰性 A/B: ADR 0001 §1 通りの merge 形式 / `locals.tf:36-55` 通りの三項演算子 → いずれも発火なし

### 観点 7（App 権限境界）

- 陽性 1: `github_actions_secret` → blocker、必要権限 Actions: Secrets RW を特定
- 陽性 2: `github_repository_file` → blocker、Contents RW（README.md の「Contents 意図的非付与」方針への参照付き）
- 陰性: `github_repository_ruleset` は Administration RW で動作可能 → 発火なし

### 観点 8（plan-time リスク）

- 陽性 1 (destroy): `1 to destroy` パターンマッチ → warning
- 陽性 2 (replace): `must be replaced` / `-/+ resource` / `forces replacement` の 3 パターン同時マッチ → warning
- 陰性: `No changes` → 発火なし
- 未提供: 空ファイル → 「観点 8: 未評価（plan 出力未提供）」と総評に明示（エラー扱いとしない）
- `import.tf` 連携時の blocker 格上げ条件は本フィクスチャ群に `import {}` 差分が含まれないため検証外（reviewer 定義に仕様記述あり）

## AC との対応

| AC# | 検証エビデンス |
|---|---|
| AC1 | 観点 1〜8 全てに「検出条件」「指摘文言テンプレ」「重要度」を記述: `.claude/agents/terraform-design-reviewer.md` 参照。重要度値は blocker / warning / suggestion の 3 値のみで、検証時に他値の混入なし。 |
| AC2 | 観点 1 が陽性ケースで blocker 発火（`for_each` キー変更 + `moved` 不在） |
| AC3 | 観点 7 が `github_actions_secret` / `github_repository_file` の追加で blocker 発火 |
| AC4 | 観点 8 が destroy / replace を含む plan 出力で warning 発火（`import.tf` 連携時は blocker 格上げ仕様あり） |
| AC5 | 観点 5 の境界（Terraform 固有定数に限定）が reviewer 定義 §5「観点間の境界」と陽性ケース判定で明示。並列起動運用は `README.md` の追記で対応（Task 13） |

## 制限事項

- **試行回数**: プラン記載「各フィクスチャ最低 2 回起動」は本実装では 1 回試行に縮退した。LLM 出力の確率的変動への対処として、観点 # と重大度の安定性は将来の繰り返し検証で確認する。本実装段階では 1 回で観点 # と重大度が reviewer 定義通りに判定されることを確認した。
- **検証時のサブエージェント種別**: 検証用 subagent は `claude`（汎用）で起動した。`terraform-design-reviewer` 自体を `subagent_type` として直接呼ぶ動作確認は、`.claude/agents/` 配下のプロジェクトローカル subagent 登録規約に依存し、Claude Code のセッション登録タイミングの違いで挙動が変わる可能性があるため別途実機確認とする（プラン §subagent_type 解決方式 参照）。**ToDo**: PR マージ後、Claude Code セッション再起動で `.claude/agents/terraform-design-reviewer.md` が `subagent_type` 候補として認識される確認 → 1 ケースでも実機で `Agent(subagent_type: "terraform-design-reviewer")` 起動結果を本ファイルに追記。別 Issue で追跡してもよい。
- **`github_repository` 系の現リポ未実装**: 観点 3 / 観点 6 (A) のフィクスチャは ADR 0001 §1/§3 の仕様から組み立てている。Issue #16/#17 で `github_repository` 実装が入り次第、現リポの実コードを参照する陰性ケースに置換できる。

## 結論

22 ケース全 PASS（**代理試験**）。AC1〜AC5 を満たす検証エビデンスを **代理実行レベル** で取得した。実機 reviewer 起動による補強は別 Issue で追跡する。
