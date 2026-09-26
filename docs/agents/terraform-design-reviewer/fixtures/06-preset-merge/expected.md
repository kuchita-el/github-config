# 観点 6（preset 上書き経路の一貫性）の期待出力

参照: reviewer 定義 §観点 6 の不変条件と、評価時に reviewer が読む ADR 0004 決定 §3〜§7（`docs/adr/0004-terraform-module-structure-policy.md`）。指摘の根拠は ADR の節番号と規定の引用で示されること。

本ファイルの「期待する根拠」は照合用の目安であり、評価者（reviewer）には渡さない。PASS 条件は発火の有無・観点番号・重要度の一致と、根拠が期待する ADR の節を含むこと。

## 既存ケース（#20 以来のケース。#79 で陰性の2件を現行コードの形へ差し替え）

### 陽性 repository (`positive-repository.tf.example`、旧 `positive-defaults.tf.example`)

- **観点 #**: 6
- **重大度**: blocker
- **指摘文言の主旨**: (a) locals で全リポ共通値とリポごとの値を `merge()` で重ね合わせている、(b) 全リポで揃える値（`has_wiki`）をリポごとの上書きフィールドとして default なしで置き、未指定のリポでは null が provider に渡る、(c) `visibility` が省略可能になっている。
- **期待する根拠**: ADR 0004 §4（値の区分・置き場所、`merge()` を使わない、例外台帳）、ADR 0001 のステータス節で引き続き有効とされた `visibility` の必須化。

### 陰性 repository (`negative-repository.tf.example`、旧 `negative-defaults.tf.example` を差し替え)

- 期待出力: 「観点 6: ✅」（指摘なし）
- 理由: 現行 `repository.tf` と同じ構造。全リポで揃える値を設定種別ファイル冒頭の locals に足し、resource から直接参照している。
- 差し替えの理由: 旧フィクスチャは ADR 0001 §1 の variable defaults（全リポで揃える値を `repositories` のフィールド既定値に置く）を準拠形としていた。この形は ADR 0004 §4 が置き換えたため、現行 ADR の下では違反になる。

### 陽性 branch_protection (`positive-branch-protection.tf.example`、旧 `positive-ternary.tf.example`)

- **観点 #**: 6
- **重大度**: blocker
- **指摘文言の主旨**: `enforcement` / `required_approving_review_count` をリポごとの値（`ovr.X`）で直接置き換えており、未指定のリポでは null が全リポ共通値を消す。例外台帳への登録なしにリポごとの上書き経路を足している。
- **期待する根拠**: 観点 6 の不変条件 1・2、ADR 0004 §4（例外台帳、null フォールバックの実装形）。

### 陰性 branch_protection (`negative-branch-protection.tf.example`、旧 `negative-ternary.tf.example` を差し替え)

- 期待出力: 「観点 6: ✅」（指摘なし）
- 理由: 現行 `branch_protection.tf` と同じ構造。全リポで揃える値を locals に足し、resource から直接参照している。
- 差し替えの理由: 旧フィクスチャは ADR 0002 以前の三項演算子パターン（effective map）を準拠形としていたが、実コードは #84 で ADR 0004 の形へ移っており、食い違っていた（Issue #79 の「振る舞い不変の宣言」で差し替えを明示）。

## ADR 0004 §3〜§7 の規約領域（#79 で追加）

新規ケースのフィクスチャには期待を書かず、PR の内容だけを中立に記す（評価者への手掛かりを避けるため）。準拠ケースは、複数の領域の準拠例を兼ねる。

| 規約領域 | 違反フィクスチャ | 準拠フィクスチャ | 期待する根拠（違反時） |
|---|---|---|---|
| 設定種別の命名・配置 | `adr0004-violation-naming.tf.example` | `adr0004-compliant-tag-protection.tf.example` | §3（既知の設定種別 `tag_protection`）・§5（ファイル名、resource ラベル） |
| 値の区分と置き場所 | `adr0004-violation-value-category.tf.example` | `negative-repository.tf.example` | §4（全リポ共通値の置き場所、方針値をフィールド既定値にしない） |
| 例外台帳 | `adr0004-violation-ledger.tf.example` | `adr0004-compliant-ledger.tf.example` | §4「例外台帳」（登録の手続き。README の台帳に行が無い） |
| 取り込み時の食い違い | `adr0004-violation-import.tf.example` | `adr0004-compliant-import.tf.example` | §4「取り込み時の食い違い」（全リポ共通値を実態へ寄せない、由来の無い差の扱い） |
| `repositories` のフィールドの入れ子構造 | `adr0004-violation-nesting.tf.example` | `adr0004-compliant-nesting.tf.example` | §5（`repositories` のフィールド構造） |
| locals の名前 | `adr0004-violation-locals-name.tf.example` | `adr0004-compliant-tag-protection.tf.example` | §5（locals の名前と用途） |
| visibility による出し分け | `adr0004-violation-visibility.tf.example` | `adr0004-compliant-tag-protection.tf.example` | §6（Ruleset は public リポだけ、対象の集合で絞る） |
| 類型プロファイル | `adr0004-violation-profile.tf.example` | `adr0004-compliant-tag-protection.tf.example` | §7（類型決定値の表は4つの識別子すべてをキーに持ち、同じ属性の集合を持つ） |

- 違反フィクスチャ: いずれも **観点 # 6 / 重大度 blocker**。指摘の根拠に上表の節を含むこと。
- 準拠フィクスチャ: いずれも「観点 6: ✅」（指摘なし）。

## 現行コード（AC4）

現行の `branch_protection.tf` と `repository.tf`（`variables.tf`・`terraform.tfvars` を文脈として含む）を入力とした評価で、観点 6 は発火しない。README「手順: 設定種別を追加する」節と ADR 0004「帰結」節が後続 Issue に送ると明記している未適用事項（Ruleset の visibility による絞り込み）は、reviewer 定義の「既知の未適用事項」に当たり、指摘しない。
