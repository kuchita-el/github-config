# ADR 0004: Terraform module 構造の方針と類型プロファイル

## ステータス

提案中（2026-09-26、[#32](https://github.com/kuchita-el/github-config/issues/32)）

本 ADR と同じ変更で、[ADR 0001](0001-repository-resource-structure.md) の本文と [ADR 0005](0005-squash-only-merge-method.md) の影響節を書き換えた（「影響」の「ADR 0001 との関係」「ADR 0005 との関係」）。

## コンテキスト

[Issue #32](https://github.com/kuchita-el/github-config/issues/32) は、次の3つの問題を挙げている。

1. 後続の Issue がそれぞれ独立に module 化を検討・実施し、構成が揃わなくなるおそれがある。
2. [ADR 0001](0001-repository-resource-structure.md) のパターンを `github_repository` 以外のリソース型へどう広げるかが決まっていない。
3. module 化を検討する発動条件が定義されておらず、判定が場当たりになる。

本 ADR を単一の参照先として使う後続 Issue は、[#72](https://github.com/kuchita-el/github-config/issues/72)（類型の宣言入力）、[#16](https://github.com/kuchita-el/github-config/issues/16) → [#17](https://github.com/kuchita-el/github-config/issues/17)（`github_repository` のリポジトリ設定。親は [#6](https://github.com/kuchita-el/github-config/issues/6)）、[#5](https://github.com/kuchita-el/github-config/issues/5)（ラベル）、[#7](https://github.com/kuchita-el/github-config/issues/7)（Dependabot / Secret scanning）、[#73](https://github.com/kuchita-el/github-config/issues/73)（Actions 権限）、[#74](https://github.com/kuchita-el/github-config/issues/74)（タグ保護）、[#71](https://github.com/kuchita-el/github-config/issues/71)（既定ブランチの最新化要求）、[#4](https://github.com/kuchita-el/github-config/issues/4)（private リポの取り込みを含む第2バッチ）である。

本 ADR の起票前に、次の方針が決まっている。

- private リポも、Ruleset 以外の設定の管理対象に含める（#4 の 2026-09-26 のコメント）。
- リポの類型プロファイルを導入し、1リポにつき1類型を択一する。複数の類型の構成要素を持つリポ（以下「同居リポ」）は、最も影響範囲の大きい構成要素の類型を選ぶ（#32 の 2026-09-26 のコメント）。
- dotfiles の秘密情報対策は本リポの対象外とする（2026-09-26 のオープン Issue の棚卸し）。

**旧パターンの廃止と AC4 の読み替え**: Issue #32 の本文と AC4 は、ADR 0001 初版の「`repository_security.tf` / `local.repository_security_preset`（動機軸で locals を分割する）」を既存パターンとして参照している。このパターンは ADR 0001 の改訂（[#63](https://github.com/kuchita-el/github-config/issues/63)、2026-06-21）で廃止済みで、`repository_security.tf` はリポに存在しない。本 ADR は AC4 の「既存パターンとの整合」を、廃止済みの旧パターンから新しい規則への対応表（決定 §5）で示す。Issue 本文の規模の記述（`.tf` 5 枚など）は、その後 `locals.tf` と `versions.tf` が #42・#60 で消えているので採らず、付録 A の実測値を正とする。調査の問い1の「他リポでの実例」は根拠の種類の例示と解し、根拠には公式ガイドと本リポの規模を用いる。

**上書き（override）の方針を改めた経緯**: #32 のコメントは、類型プロファイルの構造を「類型既定値 → per-repo override の2段」としていた。2026-09-26 に、本リポの所有者（kuchita-el。本 ADR で「所有者」と書くときは同じ人を指す）が次の方針を示した（発言の原文）。

> repositoryのパラメータについてなんだけど、可能な限り個別のオーバーライドを許可するよりは、プロファイルごとの型にはめて使える運用にしたい。

この方針に従い、本 ADR は属性の値を3つの区分（リポ固有値 / 類型決定値 / 全リポ共通値）に分け、per-repo で値を変えられる範囲を、リポ固有値と例外台帳に登録した属性に限る（決定 §4）。

### 調査の問いと答える節

| 調査の問い（#32） | 答える節 |
|---|---|
| 1. 単一 root module を維持する根拠 | 決定 §1、根拠 §1、付録 A |
| 2. module 化を発動すべき条件と、閾値を定量で示せるか | 決定 §2、根拠 §2、付録 A |
| 3. ADR 0001 のパターンを他のリソース型へ適用できるか、例外条件はあるか | 決定 §3・§4 |
| 4. ファイル命名規則と locals 命名規則を全種別共通の規約にできるか | 決定 §5 |
| 5. ADR 0001 との競合・補完関係 | 影響「ADR 0001 との関係」 |

## 決定

### 1. 単一 root module を維持する

- child module は作らない。root module は本リポ直下の1つ、HCP Terraform の Workspace は `github-config` の1つとする（[CLAUDE.md](../../CLAUDE.md) §1）。
- 設定種別を追加するときは、root 直下に設定種別ファイル（§5）を1枚足し、`for_each` で管理リポへ展開する。
- この構成を変えるのは、§2 の条件が発火し、その条件の行動として起票した Issue で変えると決めた場合に限る。

### 2. 構成を見直す発動条件

条件は3つの区分に分ける。区分 A（root / Workspace 分割）は分割の必要条件となる事象、区分 B（child module 化）は区分 A の結果として生じる事象、区分 C（規模の再評価）は構成を見直す Issue を起票する定量の閾値である。

- 区分は A → B → C の順に評価する。区分 B は、区分 A のいずれかが発火して root 分割の Issue が起票された後にだけ評価する。
- 区分 A と区分 C は独立に評価し、発火した条件の行動をそれぞれとる。
- 区分 C の発火だけでは、Workspace の分割も child module 化も行わない。分割の必要条件は区分 A の事象である。
- 定量の閾値はすべて「超える」で判定する。閾値ちょうどの値では発火せず、閾値に1を足した値から発火する。
- 数値は仮置きである。見直す場合は、本節の数値と付録 A の当てはめを差し替える。
- 各条件の末尾に、reviewer（[terraform-design-reviewer](../../.claude/agents/terraform-design-reviewer.md)）へ将来足す観点9「module 化閾値超過警告」で、Read / Grep / Glob だけで評価できるかを付記する。観点9の追加は別 Issue で行う（影響「reviewer」）。

#### 区分 A: root / Workspace 分割

- **A-1 App の権限の拡張を要する設定種別の追加**
  - 観測対象: 追加する設定種別が使う provider のリソース型と、その API が GitHub App に要求する権限
  - 事象: 要求する権限が、本リポの GitHub App の権限（Administration: Read & write / Metadata: Read）を超える
  - 測定方法: 設定種別を追加する Issue の着手時に、リソース型が呼ぶ REST API の必要権限を GitHub Docs で確かめ、App の権限と照合する
  - 発火時の行動: CLAUDE.md §3 に従い、App の権限の拡張を扱う別 Issue を起票する。その Issue の中で、別 App・別 Workspace（別 root）へ分けることを代替案として必ず評価する
  - 観点9: 対象外（必要権限は GitHub Docs で確かめる）。PR の差分に現れる App 権限の超過は、reviewer の既存の観点7（App 権限境界違反の検出）が扱う
- **A-2 別の owner / Org の設定を管理対象に加える**
  - 観測対象: 管理対象の owner（`var.github_owner`。`terraform.tfvars` の値は `kuchita-el`）
  - 事象: `github_owner` と異なる owner または Org（変更を試すための検証用のアカウントや Org を含む）の設定を管理対象に加える作業に着手する
  - 測定方法: Issue の起票時と着手時に、その Issue が扱う owner を `terraform.tfvars` の `github_owner` と比べる
  - 発火時の行動: root 分割（別ディレクトリ・別 Workspace）を扱う Issue を起票する。区分 B はこの Issue の中で評価する
  - 観点9: 対象外（着手時に判定する事象で、PR の差分より前に判定する）
- **環境分離の扱い**: 本リポが管理するのは1つの owner の GitHub 設定で、dev / stg / prod のような環境の区別は無い。Issue #32 が例示する「環境分離が必要になった時」は、本番の管理リポへ適用する前に変更を試す検証用の owner / Org を設ける場合と解し、A-2 に含める。

#### 区分 B: child module 化

- **B-1 2つ目の root が既存の root と同じ設定種別を必要とする**
  - 観測対象: root module の数と、各 root が必要とする設定種別（§3 の設定種別名で数える）
  - 事象: 区分 A の Issue で root 分割を決めた結果として2つ目の root が生じ、その root が既存の root と同じ設定種別を必要とすることが確定した
  - 測定方法: root 分割の Issue の中で、新しい root が必要とする設定種別を §3 の設定種別名で列挙し、既存の root の設定種別ファイルと突き合わせる
  - 発火時の行動: 同じ root 分割の Issue の中で、共通する設定種別を child module に切り出すかを評価する（別の Issue は起票しない）
  - 観点9: 対象外
- 区分 B は区分 A の後にだけ発火するので、同じ事象（例: 別の owner への展開）から「root 分割」と「child module 化」が別々の行動として並び立つことはない。別の owner への展開に当てはめた場合の行動は、「A-2 により root 分割の Issue を起票し、その中で B-1 を評価する」の1つである。区分 A が発火していないときに child module 化を検討することはない。

#### 区分 C: 規模の再評価

- **C-1 resource 型の異なり数**
  - 観測対象: root 直下の `.tf` に宣言された resource の型の異なり数（data source は数えない）
  - 閾値: 10 を超える
  - 測定方法: root 直下で `grep -hoE '^resource "[a-z_]+"' *.tf | sort | uniq -c` を実行し、出力の行数を数える
  - 発火時の行動: 構成を見直す Issue を起票する（本節末尾の「区分 C の発火時の行動」）
  - 観点9: 対象（Grep で数えられる）
- **C-2 設定種別ファイルの数**
  - 観測対象: root 直下の `*.tf` から `terraform.tf` / `providers.tf` / `variables.tf` / `locals.tf` / `outputs.tf` を除いたファイルの数
  - 閾値: 10 を超える
  - 測定方法: root 直下の `*.tf` を列挙し、上の5つの名前を除いて数える
  - 発火時の行動: 構成を見直す Issue を起票する
  - 観点9: 対象（Glob で数えられる）
- **C-3 `.tf` の行数**
  - 観測対象: root 直下の各 `.tf` の行数
  - 閾値: いずれか1つでも 300 行を超える
  - 測定方法: root 直下で `wc -l *.tf` を実行する
  - 発火時の行動: 構成を見直す Issue を起票する
  - 観点9: 対象（Read で行数を数えられる）
- **C-4 管理リソース数**
  - 観測対象: HCP Terraform の管理リソース数。HCP Terraform Free の上限（組織全体で 500）と同じ数え方で、`for_each` の各インスタンスを1件と数える
  - 閾値: 400（Free の上限の 80%）を超える
  - 測定方法: HCP Terraform の組織が管理するリソースインスタンスを数える。本 root の分は、resource ブロックごとの `for_each` の展開後のインスタンス数を足して数えられる
  - 発火時の行動: 構成を見直す Issue を起票する。管理リソース数は組織全体で数えるので、module 化しても Workspace を分けても減らない。見直しの Issue では、リソースのモデリングの見直し（集約型リソースの採用など）か、HCP のプランの変更を判断する
  - 観点9: 対象外（state か HCP の情報が要る）
- **C-5 GitHub API のレート制限**
  - 観測対象: HCP の Remote 実行の plan の結果
  - 事象: GitHub API のレート制限を原因として plan が失敗する（1回で発火する）
  - 測定方法: 失敗した run のログで、エラーが GitHub API のレート制限によるものかを確かめる
  - 発火時の行動: 構成を見直す Issue を起票する
  - 観点9: 対象外（HCP の実行結果が要る）

**区分 C の発火時の行動**: 構成を見直す Issue を起票する。見直しの Issue では、公式スタイルガイドが大きなコードベースに勧める Workspace の分割と、リソースのモデリングの見直し（集約型リソースの採用など）を比べる。閾値を超えたこと自体は分割の理由にしない。見直しの Issue が Workspace の分割を結論した場合は、その結論を新しい ADR（または本 ADR §2 の改訂）として記録してから分割する。

#### 発動条件に採らないもの

- **テストの独立性**: 本リポには自動テストが無い。また `terraform test` は、コマンドを実行したディレクトリの設定をそのまま対象にでき（公式ドキュメント「Tests」の要旨。2026-09-26 確認）、テストのために module 化する必要が無い。
- **共通設定の共有**（調査の問い2の「共通設定共有」）は B-1 として扱う。**root module の認知負荷の限界**は、C-1〜C-3 の定量の閾値で観測する。

調査の問い1には §1・根拠 §1・付録 A が、問い2には本節と付録 A が答える。

### 3. 設定種別と適用表

**設定種別**は、GitHub 上の1つの機能に対応する設定のまとまりで、1つの設定種別ファイル（§5）で表す。1つの設定種別が複数のリソース型を使ってよく、同じリソース型が複数の設定種別に現れてよい（例: `github_repository_ruleset` は `branch_protection` と `tag_protection` の両方に現れ、`actions_permissions` は2つのリソース型を使う）。ただし `github_repository` の属性は、どの機能に関わるものでも設定種別 `repository` に置く（`github_repository.this` の resource ブロックは複数のファイルに分割できない。ADR 0001 の案 B）。

**基本パターン**:

- 1つの設定種別を1つのファイルに置く。
- 属性の値は、§4 の区分ごとの置き場所から resource が直接参照する。
- 1リポに1インスタンスを置き、`for_each` のキーはリポ名とする。

**例外パターン**（該当する設定種別だけに適用する）:

- **1:N の集合**: 1リポに複数の要素を持つ設定種別は、全リポに共通の集合（共通集合）と、リポごとの差分（追加分・除外分）で表す。実効の集合は「共通集合から除外分を除き、追加分を加えたもの」とする。要素ごとにリソースを置く場合、インスタンスのキーはリポ名と要素の識別子から決まるものにし、リストの位置に依存させない（共通集合に要素を足したとき、既存の要素と他のリポのインスタンスが作り直されないようにするため）。要素単位のリソースにするか、リポ単位で集合を管理する集約型のリソースにするかは担当 Issue が選ぶ。判断基準は次の2つである。
  - 管理リソース数: 要素単位のリソースは「要素数 × リポ数」のインスタンスになり、§2 C-4 の数に効く。
  - 管理外の要素を削除してよいか: 集約型のリソース（ラベルなら `github_issue_labels`）は、リポの集合を権威的に管理し、管理外の要素を削除する。要素単位のリソース（`github_issue_label`）とは併用できない。
- **visibility の制約**: Free プランの private リポで使えないリソースや属性を持つ設定種別は、visibility で適用範囲を出し分ける（§6）。
- **例外台帳の登録属性**: 類型決定値・全リポ共通値のうち、特定のリポで値を変える必要があり例外台帳に登録した属性は、per-repo のフィールドを持つ（§4）。

**適用表**（値の区分の列は見込みであり、確定は担当 Issue が §4 の判定手順で行う。本 ADR は具体値を決めない）:

| 設定種別名 | provider のリソース型 | 1リポあたりの基数 | visibility の制約 | 値の区分の見込み（確定は担当 Issue） | 適用する例外パターン | ファイル名 | 担当 Issue |
|---|---|---|---|---|---|---|---|
| `branch_protection` | `github_repository_ruleset`（target は branch） | 1:1 | public のみ（Free では private で Ruleset を使えない） | `status_check_contexts` / `status_check_integration_id` はリポ固有値。`allowed_merge_methods` は全リポ共通値（ADR 0005）。`strict_required_status_checks_policy` は #71 が判定。それ以外は現行の preset どおり全リポ共通値 | visibility の制約（リソース単位）。例外台帳の登録属性の有無は #71 の判定による | `branch_protection.tf`（既存） | 移行 Issue・#71・#4 |
| `tag_protection` | `github_repository_ruleset`（target は tag） | 1:1 | public のみ | 有効にする類型は類型決定値。保護対象のタグの範囲と新規作成の扱いの区分は #74 が判定 | visibility の制約（リソース単位） | `tag_protection.tf` | #74 |
| `repository` | `github_repository` | 1:1 | private にも適用する。private で使えない属性がありうる（#7 の Secret scanning など。可否は #7 が確認） | `visibility`（`repositories.<k>` 直下）、`archived`、`description` / `homepage` / `topics`、説明系属性を管理外にする指定はリポ固有値。`allow_squash_merge` / `allow_merge_commit` / `allow_rebase_merge` と `squash_merge_commit_title` / `squash_merge_commit_message` は全リポ共通値（ADR 0005、#17）。`allow_auto_merge` / `has_wiki` / `has_projects` / `has_discussions` は #16、`delete_branch_on_merge` / `default_branch` / `has_issues` は #17、`vulnerability_alerts` と `security_and_analysis` 配下は #7 が判定 | visibility の制約（属性単位） | `repository.tf` | #16・#17・#7 |
| `labels` | `github_issue_label` か `github_issue_labels`（#5 が選ぶ） | 1:N | 制約なし（private も対象） | 共通集合は全リポ共通値（類型で変えるなら類型決定値）。追加分はリポ固有値。除外分は例外台帳への登録対象 | 1:N の集合、例外台帳の登録属性（除外分） | `labels.tf` | #5 |
| `dependabot_security_updates` | `github_repository_dependabot_security_updates` | 1:1 | private での可否は #7 が確認 | #7 が判定 | private で使えなければ visibility の制約（リソース単位）。要否は #7 が確認 | `dependabot_security_updates.tf` | #7 |
| `actions_permissions` | `github_actions_repository_permissions` と `github_workflow_repository_permissions` | 1:1 | 制約なし（#73 の参考欄によれば Free の private でも設定できる） | 類型決定値（値は #73 が決める） | 例外台帳の登録属性（候補: PR の作成を許す必要があるリポ。要否は #73） | `actions_permissions.tf` | #73 |

「移行 Issue」は、`branch_protection.tf` を本 ADR の値の区分へ移す Issue である（影響「branch_protection の移行 Issue」）。

**表に無い設定種別の分類手順**（上から順にたどる）:

1. 設定種別名を決める。追加する設定が `github_repository` の属性なら、設定種別 `repository` に加え、新しい設定種別は作らない。それ以外は、GitHub 上の機能名を snake_case にしたものを設定種別名とする（語形の規則を含め §5）。
2. §2 A-1 に従い、使うリソース型の API が要求する App の権限を確かめる。
3. 1リポあたりの基数を決める。1リポに1インスタンスなら 1:1（基本パターン）、1リポに複数の要素を持つなら 1:N（例外パターン「1:N の集合」）とする。
4. visibility の制約を確かめる。Free の private リポで使えるかを GitHub Docs で確かめ、リソース全体が使えなければリソース単位、一部の属性だけが使えなければ属性単位で出し分ける（§6）。使えるなら制約なしとする。
5. 属性ごとに §4 の判定手順で値の区分を決め、区分ごとの置き場所に置く。
6. 特定のリポで類型決定値・全リポ共通値から外す必要がある属性は、§4 の例外台帳の手続きを踏む（例外パターン「例外台帳の登録属性」）。
7. GitHub 側に既存の設定があれば、CLAUDE.md §2 の手順で取り込み、実値との食い違いは §4「取り込み時の食い違い」で扱う。

調査の問い3には本節と §4 が答える。ADR 0001 のパターン（1ファイルへの集約と、値の置き場所からの直接参照）は全設定種別に適用し、例外は上の3つのパターンに限る。

### 4. 値の区分と例外台帳

#### 3つの区分

- **リポ固有値**: リポの同一性や構成に由来し、方針として揃える値を持たないもの（例: リポ名、説明、topics、CI の job 名、visibility、類型、archived）。
- **類型決定値**: 方針として揃える値（方針値）があり、その方針値が類型（§7）によって変わるもの。
- **全リポ共通値**: 方針値があり、類型を問わず同じもの。

**判定手順**: 属性ごとに、次の表の条件1 → 条件2 の順に判定する。条件1 の判定に迷う場合は「いいえ」とする（所有者の方針〔コンテキスト〕に従い、per-repo で変えられる範囲を広げない側に倒す）。

| 条件1: 値がリポの同一性・構成に由来し、方針として揃える値を持たない | 条件2: 方針値が類型によって変わる | 区分 | 置き場所 | per-repo で変えられるか |
|---|---|---|---|---|
| はい | （問わない） | リポ固有値 | `repositories.<k>.<concern>.<属性>`（visibility と profile は `repositories.<k>` 直下） | 変えられる（値そのものが入力） |
| いいえ | はい | 類型決定値 | `local.<concern>_profile_defaults` | 例外台帳に登録した属性だけ |
| いいえ | いいえ | 全リポ共通値 | `local.<concern>_preset` | 例外台帳に登録した属性だけ |

`<k>` はリポ名（`repositories` のキー）、`<concern>` は設定種別名（§5）である。

#### 置き場所と参照

- リポ固有値は `repositories.<k>.<concern>.<属性>`（visibility と profile は `repositories.<k>` 直下）に置く。必須のフィールドとするか、自然な「無し」の値（空リスト、null など）を既定値とする optional とする。方針値を既定値にしない。
- 類型決定値は、設定種別ファイルの冒頭の `local.<concern>_profile_defaults` に、類型の識別子をキーとして置き、resource から `local.<concern>_profile_defaults[var.repositories[each.key].profile].<属性>` の形で直接参照する（表の作り方は §7）。
- 全リポ共通値は、設定種別ファイルの冒頭の `local.<concern>_preset` に置き、resource から `local.<concern>_preset.<属性>` の形で直接参照する。1:N の共通集合もここに置く（類型で変えるなら `local.<concern>_profile_defaults`）。
- 値の合成に `merge()` は使わない。

#### per-repo で変えられる範囲

- per-repo で値を変えられるのは、リポ固有値と、例外台帳に登録した属性（以下「台帳登録属性」）だけである。
- 台帳に登録していない類型決定値・全リポ共通値には、per-repo のフィールドを作らない。
- 台帳に登録していない属性について、特定のリポだけ別の値が必要になった場合は、per-repo のフィールドを足して値を書くことはしない。次の順に扱う。
  1. 類型の割り当ての見直し（§7 の判定基準による）か、類型決定値の表・全リポ共通値の見直しで表せるかを確かめる。表せれば、そちらを変える。
  2. 表せなければ、下の「登録の要件」を満たすかを確かめる。満たせば「登録の手続き」に従って台帳へ登録する。
  3. 満たさなければ、そのリポも区分の値に従う。

#### 例外台帳の規則

- **登録の要件**: 次の3つをすべて満たすこと。
  - その属性の値の差が、類型の割り当ての見直しや、類型決定値の表・全リポ共通値の見直しでは表せない。
  - 差が恒常的である（一時的な事情によるものではない）。
  - 差の理由を書ける。
- **登録の手続き**: その属性を必要とする Issue の PR で、本 ADR の「例外台帳」節に行を足し、所有者の承認を得る。per-repo のフィールドの追加と台帳の追記は、同じ変更で行う。台帳の行の変更（使用リポの追加・削除を含む）も、同じ手続きで行う。
- **記録の粒度と項目**: 属性単位で1行とし、設定種別、属性、元の区分、理由、登録した Issue / PR、使用リポとリポごとの理由、見直しの条件を記録する。使用リポを増やすときも台帳の行を更新する。
- **実装形**: 台帳登録属性だけ、`repositories.<k>.<concern>.<属性>` に既定値なしの `optional(T)` を置く。実効値は、per-repo の値が null でなければその値、null なら元の区分の置き場所の値とする（null フォールバック）。
  - 判定は null かどうかだけで行い、null だけを未指定とみなす。false・空リスト・0・空文字は、per-repo の値として有効に扱い、元の区分の値へ戻さない。
  - 空文字や空リストを読み飛ばす関数（`coalesce` / `coalescelist`）は使わない。
  - 1:N の除外分は、null フォールバックではなく、既定値を空集合とする差分のフィールド（`exclude`。§5）で表す。
  - 例（類型決定値の属性 `strict_required_status_checks_policy` を台帳に登録した場合）:

    ```hcl
    strict_required_status_checks_policy = (
      var.repositories[each.key].branch_protection.strict_required_status_checks_policy != null
      ? var.repositories[each.key].branch_protection.strict_required_status_checks_policy
      : local.branch_protection_profile_defaults[var.repositories[each.key].profile].strict_required_status_checks_policy
    )
    ```

- **登録の解除**: 使用リポが無くなったら、per-repo のフィールドと台帳の行を同じ変更で消す。

#### 取り込み時の食い違い

GitHub 側に既に存在する設定を管理対象に入れるとき（CLAUDE.md §2 の import、または管理済みのリソースに未管理だった属性を加えるとき）、ある属性の実値が、そのリポに適用される類型決定値・全リポ共通値と異なる場合は、次のとおり扱う。リポ固有値は、実値を `terraform.tfvars` に宣言して合わせる。

1. 食い違いの由来を判定する。リポの性質から来る差で、上の「登録の要件」を満たし理由を書けるものを「理由のある差」、過去の UI 操作の名残など理由を書けないものを「由来の無い差」とする。
2. 理由のある差は、例外台帳に恒久的に登録し（登録の手続きに従う）、per-repo の値として実値を宣言して、import の plan を no-op にする。
3. 由来の無い差は、取り込みの前に GitHub 側の実値を区分の値へ変え、そのうえで import の plan が no-op であることを確かめて取り込む。実値の変更は外から観測される振る舞いの変更なので、リポと属性ごとに所有者の承認を得てから行い、取り込み Issue に記録する（リポ、属性、変更前後の値、承認）。所有者が実値の変更を承認しなかった場合は、「所有者が変更しないと判断した」を理由として例外台帳に登録し（登録の手続きに従う）、per-repo の値として実値を宣言して取り込む。

- `terraform.tfvars`、`local.<concern>_preset`、`local.<concern>_profile_defaults` を、食い違ったリポの実態へ寄せない（共通値や類型の表を寄せると、そのリポ以外の方針も変わる）。CLAUDE.md §2 の手順2 が述べる「`terraform.tfvars` / `branch_protection.tf` を実態へ寄せる」は、リポ固有値と、台帳登録属性の per-repo の値に限って行う。
- import と同じ plan で、食い違う属性を in-place update する手順は採らない。CLAUDE.md §2 は、import の plan が `0 to change` であることを求めている。
- 前例: #4 では、dependabot-triage-action を取り込みの前に承認を得て public 化した（#4 の 2026-06-15 のコメント）。
- 既知の食い違い: `has_wiki`（gachanuma と claude-shared-skills が true、ほかは false）と `delete_branch_on_merge`（claude-shared-skills だけ true）がある（ADR 0001 付録 A、2026-06-20 取得。後者は #17 の 2026-09-12 のコメントでも確認）。これらの区分は #16・#17 が判定し、類型決定値か全リポ共通値に区分した場合に本規則を適用する。

#### 区分の変更

区分の変更（例: 全リポ共通値を類型決定値へ移す）は、その設定種別を担当する Issue の通常の変更として行う。値を置く locals が変わるだけで、state のアドレスは変わらない。値が変わるリポの分だけ、plan に in-place update が現れる。

#### 経過措置

- 移行 Issue が完了するまで、`variables.tf` の `repositories` に残る未使用の上書きフィールド9つ（L25-33 の `enforcement`、`required_approving_review_count`、`dismiss_stale_reviews_on_push`、`require_code_owner_review`、`require_last_push_approval`、`required_review_thread_resolution`、`allowed_merge_methods`、`strict_required_status_checks_policy`、`do_not_enforce_on_create`）は使わない。使う必要が生じた場合は、例外台帳への登録を経る。
- 移行 Issue が完了するまでの `branch_protection.tf` の書き方は、[ADR 0002](0002-branch-protection-preset-merge-pattern.md) の注記（L7）に従う。この注記は上書きフィールドを足すことを指示しておらず、本節と食い違わない。

#### #32 コメントの「2段」を改めたこと

#32 のコメントは、値の決め方を「類型既定値 → per-repo override の2段」（全属性で per-repo の上書きを許す構造）としていた。本 ADR はこれを「類型決定値・全リポ共通値が基本で、per-repo で変えられるのはリポ固有値と台帳登録属性だけ」に改める。理由は、2026-09-26 の所有者の方針（コンテキスト）である。値が類型ごとの型に収まり、差がどこに・なぜあるかを台帳の1か所で読め、上書きの経路が減る。

### 5. 命名と配置

- **ファイル名**: 設定種別ファイルの名前は `<concern>.tf` とする（`<concern>` は設定種別名）。設定種別に属さない root 直下のファイルは、`terraform.tf` / `providers.tf` / `variables.tf` / `locals.tf` / `outputs.tf` とする。既存の `branch_protection.tf`（設定種別ファイル）と `providers.tf` / `terraform.tf` / `variables.tf`（設定種別に属さないファイル）は、この規則に適合する。
- **設定種別名**: GitHub 上の機能名を snake_case にしたものとし、`github_` や `repository_` の接頭辞は付けない（全設定種別がリポ単位なので冗長になる）。ただし `github_repository` 自体の設定種別は `repository` とする。既知の設定種別名は §3 の適用表の6つ（`branch_protection` / `tag_protection` / `repository` / `labels` / `dependabot_security_updates` / `actions_permissions`）で確定する。
- **設定種別名の語形（単数・複数）**: 1リポに N 個の要素を持つ設定種別（1:N の集合）は、リソース型の選び方によらず複数形とする。それ以外で名前が provider のリソース型名に由来する場合は、その型名の単数・複数に従う。1つのリソース型を複数の関心事で使う場合（`github_repository_ruleset`）は、`<対象>_protection` とする。既知の6つへの当てはめは次のとおりである。
  - `branch_protection` / `tag_protection`: `github_repository_ruleset` を branch と tag の2つの関心事で使うので、`<対象>_protection`。
  - `repository`: `github_repository` の単数形。
  - `dependabot_security_updates`: `github_repository_dependabot_security_updates` の複数形。
  - `actions_permissions`: `github_actions_repository_permissions` / `github_workflow_repository_permissions` の複数形（permissions）。
  - `labels`: 1:N の集合なので複数形。#5 が要素単位の `github_issue_label` と集約型の `github_issue_labels` のどちらを選んでも、名前は変わらない。
- **resource ラベル**: 設定種別名とする（既存の `github_repository_ruleset.branch_protection` と同じ形）。1つの設定種別が2つのリソース型を使う場合も、それぞれ設定種別名とする（例: `github_actions_repository_permissions.actions_permissions` と `github_workflow_repository_permissions.actions_permissions`）。ADR 0001 が決めた `github_repository.this` はそのまま残す。
- **`repositories` のフィールド構造**:
  - `repositories.<k>` の直下には、`visibility` と類型（フィールド名 `profile`。`local.<concern>_profile_defaults` と名前を揃える）だけを置く。
  - 各設定種別のリポ固有値と台帳登録属性は、設定種別名と同じ名前のキーの下に置く（例: `repositories.<k>.branch_protection.status_check_contexts`）。これにより「設定種別名＝ファイル名＝フィールド群のキー」が対応する。
  - キーは、その設定種別にリポ固有値か台帳登録属性があるときだけ設ける。どちらも無い設定種別（例: 起票時点の `tag_protection`、`actions_permissions`）にはキーを設けない。
  - 対応の例外: `github_repository` の属性は、どの機能に関わるものでも `repositories.<k>.repository.*` に置く（ただし `visibility` は直下）。このため、#7 の値は `repositories.<k>.repository.*`（`security_and_analysis` など）と `repositories.<k>.dependabot_security_updates.*` の2か所に分かれうる。
  - 1:N の差分のフィールド名は、追加分を `add`、除外分を `exclude` とする。
  - `terraform.tfvars` の形の例（リポ名と値は例示）:

    ```hcl
    repositories = {
      "<repo>" = {
        visibility = "public" # 直下は visibility と profile だけ
        profile    = "app"

        branch_protection = { # 設定種別名のキー
          status_check_contexts       = ["build"] # リポ固有値
          status_check_integration_id = 15368     # リポ固有値
        }
        labels = {
          add     = [] # リポ固有値（要素の型は #5 が決める）
          exclude = [] # 台帳登録属性（#5 が登録する）
        }
      }
    }
    ```

- **locals の命名**: `local.<concern>_<用途>` とし、用途は次の4つに限る。

  | 用途 | 意味 | 例 |
  |---|---|---|
  | `preset` | 全リポ共通値（1:N の共通集合を含む） | `local.branch_protection_preset`、`local.labels_preset` |
  | `profile_defaults` | 類型決定値の表（類型の識別子をキーとする） | `local.actions_permissions_profile_defaults` |
  | `targets` | visibility などで絞り込んだ適用対象の集合（`for_each` に渡す） | `local.tag_protection_targets` |
  | `instances` | `for_each` に渡す、1:N の集合を展開した結果 | `local.labels_instances` |

- **locals の配置**: 1つのファイルだけで使うものはそのファイルの冒頭に置き、複数のファイルから参照するものは `locals.tf` に置く。公式スタイルガイドの「Local values」節（<https://developer.hashicorp.com/terraform/language/style#local-values>、2026-09-26 取得）の原文どおりである。

  > Define local values in one of two places:
  >
  > - If you reference the local value in multiple files, define it in a file named `locals.tf`.
  > - If the local value is specific to a file, define it at the top of that file.

**旧→新の対応表**（AC4 が挙げる旧パターンと、現行コード・README の名前から、新しい配置への対応）:

| 旧（廃止済み、または移行で変わる名前） | 新しい配置 |
|---|---|
| `repository_security.tf` / `repository_process.tf`（ADR 0001 初版） | 新設しない。`github_repository` の属性は `repository.tf` に集約する（ADR 0001、#63） |
| `local.repository_security_preset` / `local.repository_process_preset`（ADR 0001 初版） | 区分ごとに分かれる。全リポ共通値は `local.repository_preset`、類型決定値は `local.repository_profile_defaults`、リポ固有値は `repositories.<k>.repository.*` |
| `<resource>_<axis>.tf` / `local.<resource>_<axis>_preset`（Issue #32 本文の命名案） | 採らない。`<concern>.tf` と `local.<concern>_<用途>` |
| `local.branch_protection_preset`（現行。`merge()` で合成） | 全リポ共通値の置き場所として残し、resource から直接参照する |
| `local.branch_protection`（現行。`merge()` による合成結果） | 移行 Issue で削除する |
| `repositories.<k>` 直下の branch protection の9属性（現行。未使用の上書きフィールド） | 移行 Issue で削除する。必要になったら例外台帳への登録を経る |
| `repositories.<k>.status_check_contexts` / `status_check_integration_id`（現行） | `repositories.<k>.branch_protection.status_check_contexts` / `status_check_integration_id`（移行 Issue で移す） |
| README の例示 `repository_labels.tf` | `labels.tf` |
| README の `local.<resource>_preset` | `local.<concern>_preset` |

調査の問い4には本節が答える。ファイル名と locals の名前は、`<axis>`（動機軸）を含まない `<concern>.tf` と `local.<concern>_<用途>` として全設定種別に共通の規約にする。

### 6. visibility による出し分け

- **原則**: 適用できるかどうか（プラットフォームの制約）と、方針値（類型決定値・全リポ共通値）を別の軸として扱う。プラットフォームの制約を、類型決定値の表や per-repo のフィールドで表さない。
- **visibility の値の出所**: `repositories.<k>.visibility`（必須。#16 で入る）。`visibility` は `github_repository` の `lifecycle.ignore_changes` の対象なので（ADR 0001 §3）、宣言値と実際の値がずれることがある。
- **出し分けの2つの形**:
  - **リソース単位**: 設定種別ファイルの冒頭の `local.<concern>_targets` で、`for_each` の対象を visibility で絞り込む。
  - **属性単位**: private リポにも適用するリソース（`github_repository`）の中で、private では使えない属性を、visibility を条件にした条件分岐（dynamic ブロックか条件式）で出し分ける。これは適用可否の条件分岐であり、例外台帳の null フォールバックとも、per-repo の上書きとも別物である。例外台帳への登録は要らない。ADR 0001 の「三項演算子を採用しない」の対象外でもある。
- **Ruleset は public リポのみに適用する**: branch 保護とタグ保護（`branch_protection` と `tag_protection`）の Ruleset は、public リポにだけ適用する。GitHub Docs「About rulesets」（<https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets>、2026-09-26 取得）は、次のように述べている。

  > Rulesets are available in public repositories with GitHub Free and GitHub Free for organizations, and in public and private repositories with GitHub Pro, GitHub Team, and GitHub Enterprise Cloud. See GitHub's plans.

  tag を対象とする Ruleset も同様であることは、#74 の参考欄に 2026-09-26 の一次確認として記録されている。
- **状態遷移**:

  | 遷移前の宣言値 | 遷移後の宣言値 | Ruleset 系の設定種別 | その他の設定種別 | 作業者が確認すること |
  |---|---|---|---|---|
  | public | private | UI で変更する前に宣言値を更新して apply し、当該リポのインスタンスを destroy する | 変化なし | 計画上の destroy が当該リポの Ruleset 系に限られていること。apply の後に UI で private にすること（その間は Ruleset が無い状態になる） |
  | private | public | UI で public にした後に宣言値を更新し、当該リポのインスタンスが create として計画に現れる | 変化なし | 宣言値を更新する前に、GitHub 側に既存の Ruleset が残っていないか。残っていれば import の手順（CLAUDE.md §2）に従う |
  | public | public（手順に反して UI だけで private にした） | 宣言値が public のままなので計画上は変化しないが、refresh で呼ぶ取得 API が private の Free リポで失敗するおそれがある（未確認） | 変化なし（visibility は ignore_changes の対象で、drift として現れない） | 宣言値を private に直して plan すること。失敗した場合の復旧手順は、#4 で取得 API の応答を一次確認してから本 ADR に追記する |

- **public → private の手順**（宣言値を先に変える）:
  1. UI で変える前に、`terraform.tfvars` の当該リポの `visibility` を `private` にした PR を作る。
  2. plan で、destroy が当該リポの Ruleset 系（branch 保護とタグ保護）のインスタンスだけであり、他のリポと他の設定種別に変化が無いことを確かめて apply する。
  3. apply の後に、UI で当該リポを private にする。apply から UI の変更までの間、当該リポには Ruleset が無い。これは意図どおりの帰結である。
- **private → public の手順**（UI を先に変える）:
  1. UI で当該リポを public にする。
  2. `gh api repos/{owner}/{repo}/rulesets` で GitHub 側に既存の Ruleset が残っていないかを確かめる。残っていれば、CLAUDE.md §2 の import の手順に従って取り込む。
  3. `visibility` を `public` にした PR を作り、plan で当該リポの Ruleset 系のインスタンスが create として現れることを確かめて apply する。逆順にすると、private のうちに Ruleset の作成を試みることになる。
- **未確認の前提**: private リポに対する Ruleset の API（plan の refresh で呼ぶ取得、destroy で呼ぶ削除、create で呼ぶ作成）の応答は確認されていない。#4（private リポを最初に管理対象へ加える Issue）で一次確認する。遷移ごとの依存は次のとおりである。
  - public → private: 上の手順は未確認の応答に依存しない（destroy は public のうちに行う）。
  - private → public: 上の手順は未確認の応答に依存しない（create は public にした後に行う）。private の間に GitHub 側に Ruleset が残っているかは、手順2で確かめる。
  - 手順に反して UI だけで private にした場合: refresh で呼ぶ取得の応答に依存する。復旧手順は、#4 で応答を確認してから本 ADR に追記する。
- **private リポを管理対象にする基準**: リポ名（説明系の属性を管理する場合は説明系の属性も）が公開されてよいこと（#4 の 2026-09-26 のコメント）。本リポは public で、`terraform.tfvars` に書いた値は公開される。
- **委ねる先**: 説明系の属性を per-repo で管理外にする構造は #17、Secret scanning などが private で使えるかの確認と出し分けの宣言は #7、Ruleset の適用対象を public に絞る最初の実装は #4 の第2バッチが行う。

### 7. 類型プロファイル

**類型の一覧と識別子**（判定基準は「リポの変更がどこへ届くか」）:

| 類型 | 識別子（`profile` の値） | 定義と判定基準 |
|---|---|---|
| 配布物 | `distribution` | 第三者や所有者の他のリポが、ref（タグ・ブランチ・SHA）で参照するか、内容を複製して取り込む成果物を公開するリポ（GitHub Action、プラグイン、スキル、ライブラリ、テンプレート） |
| インフラ | `infra` | リポの変更が、CI や IaC の実行を通じて外部の実環境（クラウド、SaaS、GitHub の設定）へ適用されるリポ |
| アプリ | `app` | 実行されるアプリケーションのソースを持ち、利用者がリポを ref で参照も複製もしないリポ |
| ローカル構成 | `local_config` | 所有者の端末環境の構成を持ち、外部へ配布も適用もしないリポ |

- **境界例の割り当て**:
  - テンプレートリポは配布物とする。テンプレートから生成したリポは内容を複製して取り込み、改竄された内容は生成後のリポに残るので、所有者の側では回収できない。ref では参照されないのでタグ保護は実質的に効かないが、有効になっても害は無い。
  - スキル集（marketplace から ref で取り込まれるもの）は配布物とする。
  - 所有者の dotfiles はローカル構成とする。
  - 個々の管理リポへの類型の割り当ては #72 が行い、本 ADR では行わない。
- **1リポ1類型**: 1つのリポには類型を1つだけ宣言する。
- **どの類型の定義にも当たらないリポ**: 判定基準（リポの変更がどこへ届くか）で最も近い類型を選ぶ。最も近い類型を1つに決められない場合は、本 ADR を改訂して類型を追加する。
- **同居リポの選択規則**: リポが複数の類型の定義に当たる場合は、当たる類型のうち、次の順序で最も上位のものを選ぶ。

  **配布物 > インフラ > アプリ > ローカル構成**

  順序の軸は「被害が所有者の管理の外へ及ぶか」である。2つの類型に当たる場合の選択は次のとおりで、3つ以上に当たる場合も同じ順序で最上位を選ぶ。

  | 当たる類型の組 | 選ぶ類型 |
  |---|---|
  | 配布物 + インフラ | 配布物（`distribution`） |
  | 配布物 + アプリ | 配布物（`distribution`） |
  | 配布物 + ローカル構成 | 配布物（`distribution`） |
  | インフラ + アプリ | インフラ（`infra`） |
  | インフラ + ローカル構成 | インフラ（`infra`） |
  | アプリ + ローカル構成 | アプリ（`app`） |

- **同居リポで類型の値から外したい属性**: 選んだ類型の類型決定値を、そのリポだけ変えたい属性は、§4 の例外台帳の手続きで扱う（per-repo のフィールドを直接足さない）。#32 のコメントの「緩めたい属性は per-repo override で個別に扱う」を、本 ADR はこのように改める。
- **パス単位の差**: 同居リポの中でパスによって扱いを変えたい差は、Ruleset の外（HCP のトリガー条件、CI の集約 gate ジョブなど）で吸収する（#32 のコメント）。
- **宣言入力の規約**（実装は #72）:
  - フィールド名は `profile`、位置は `repositories.<k>` の直下とする。
  - 必須とし、既定値を持たない。宣言を省略した場合はエラーとし、既定の類型は用いない。
  - 値は上の4つの識別子に限る。一覧にない値は変数の検証（validation）で拒否する。
  - どちらの場合も、`terraform validate` か `terraform plan` がエラーで失敗する。
- **類型決定値の表**:
  - 設定種別ファイルの冒頭の `local.<concern>_profile_defaults` に、4つの識別子すべてをキーとして置き、全類型が同じ属性の集合を持つように作る。
  - resource からは `local.<concern>_profile_defaults[var.repositories[each.key].profile].<属性>` で直接参照する。台帳登録属性だけ、§4 の null フォールバックを通す。
  - 全類型が同じ属性の集合を持つ表で型が揃うことは、最初に表を作る消費側の Issue（#71 / #73 / #74 / #7 のうち最初に着手するもの）で一次確認する。#72 は類型ごとの具体値を扱わないので、#72 では確かめない。
  - 類型ごとの値そのものは、各設定種別の Issue が決める。本 ADR は決めない。
- **類型を変えたとき**: リポの `profile` だけを書き換えた場合、そのリポの類型決定値のうち新旧の類型で値が異なる属性だけが変わる（属性の値は in-place update として、設定種別を有効にするかどうかのように適用対象の集合〔`local.<concern>_targets`〕を決める類型決定値は、そのリポのインスタンスの create / destroy として plan に現れる）。そのリポのリポ固有値・全リポ共通値・台帳登録属性の per-repo の値と、他のリポは変わらない。

## 例外台帳

類型決定値・全リポ共通値のうち、特定のリポで値を変えることを許した属性の一覧である。登録・変更・解除の規則は決定 §4「例外台帳の規則」に従う。

| 設定種別 | 属性 | 元の区分 | 理由 | 登録した Issue / PR | 使用リポとリポごとの理由 | 見直しの条件 |
|---|---|---|---|---|---|---|

起票時点では登録なし。

## 根拠

### 1. 単一 root module の維持

- **公式ガイドの位置づけ**: 公式ドキュメント「When to write a module」（<https://developer.hashicorp.com/terraform/language/modules/develop#when-to-write-a-module>、2026-09-26 取得）は、次のように述べている。

  > A good module should raise the level of abstraction by describing a new concept in your architecture that is constructed from resource types offered by providers.

  > We *do not* recommend writing modules that are just thin wrappers around single other resource types. If you have trouble finding a name for your module that isn't the same as the main resource type inside it, that may be a sign that your module is not creating any new abstraction and so the module is adding unnecessary complexity. Just use the resource type directly in the calling module instead.

  本リポの設定種別は、いずれも管理リポごとに同じ設定を置くもので、module で包むと単一のリソース型の薄い包装になる（module の名前が中のリソース型と同じになる）。
- **`for_each` による追従**: 管理リポの増減は `repositories` のエントリの増減として `for_each` が吸収し、module を増やす必要が無い。
- **再利用先の root が1つ**: 共通部分を切り出しても、使う root は本リポ直下の1つしかない（2つ目の root が生じる事象は §2 の区分 A として扱う）。
- **Workspace の SoT**: CLAUDE.md §1 は、Workspace `github-config` の Remote 実行を唯一の正としている。
- **公式スタイルガイドの「Multiple environments」節**（<https://developer.hashicorp.com/terraform/language/style#multiple-environments>、2026-09-26 取得）: HCP Terraform の利用者と、HCP を使わない場合とで、次のように勧め方を分けている。

  > For HCP Terraform and Terraform Enterprise users, we recommend that you use separate workspaces for each environment. For larger codebases, we recommend that you split your resources across multiple workspaces to prevent large state files and limit unintended consequences from changes.

  > If you do not use HCP Terraform or Terraform Enterprise, we recommend that you use modules to encapsulate your configuration, and use a directory for each environment so that each one has a separate state file.

  HCP を使う本リポでは、環境の分離と規模への対処は Workspace（root）の分割で扱うものであり、child module 化だけでは解決しない。このため §2 は root / Workspace 分割と child module 化を区別する。
- **規模**: 付録 A の実測値（`.tf` 4 枚、resource 型 1、管理リポ 4、管理リソース 4）は、§2 のどの条件にも当たらない。

### 2. 発動条件

- **定性的な事象を分割の必要条件にする**: 行数やファイル数が増えたこと自体は module 化の理由にならない（根拠 §1 の公式ガイド）。閾値の超過を「分割する」に直結させると誤った分割を誘発するので、分割は事象（区分 A）に結び付け、定量の閾値は見直しの Issue を起票する条件（区分 C）に留める。これにより、規模の悪化を検知しつつ、分割の判断を事象に結び付けられる。
- **区分の順序で行動を1つに決める**: child module 化の区分 B を区分 A の後にだけ評価するので、1つの事象から2つの行動が並び立たない。
- **閾値の数値**: バックログ（#5 / #7 / #16 / #17 / #73 / #74）が着地した後の見込み（resource 型 6〔ruleset / repository / issue labels / dependabot security updates / actions repository permissions / workflow repository permissions〕、設定種別ファイル 6〜7）に対して、1.5〜2 倍の余裕を取った。C-4 の 400 は HCP Terraform Free の上限 500 の 80% である（公式ドキュメント「HCP Terraform overview」の要旨: Free の上限は管理リソース 500 で、`for_each` の各インスタンスを数える。2026-09-26 確認）。
- **観測できること**: C-1〜C-3 は Read / Grep / Glob で数えられるので、Bash を持たない reviewer でも評価できる。C-4・C-5 は state や HCP の実行結果が要る。
- **環境分離**: 公式スタイルガイドも、HCP 利用時の環境の分離を環境ごとの Workspace として扱っている（根拠 §1）。本リポには環境の区別が無いので、検証用の owner / Org を設ける場合として A-2 に含めた。

### 3. 設定種別と適用表

- **ファイルを設定種別で分ける**: 公式スタイルガイドの「File names」節（<https://developer.hashicorp.com/terraform/language/style#file-names>、2026-09-26 確認）は、"organize resources and data sources in separate files by logical groups" とし、"it should be immediately clear where a maintainer can find a specific resource or data source definition" を求めている。設定種別は論理的なグループにあたり、既存の `branch_protection.tf`、README の手順例、#5 の本文もすでに設定種別の単位になっている。既存ファイルの改名も要らない。
- **同じ型が複数の設定種別に現れる**: `github_repository_ruleset` は branch 保護とタグ保護の両方に使われ、Actions 権限は2つの型にまたがる。リソース型の単位では関心事の局所性が失われる。
- **既知の設定種別名を ADR で確定する**: 後続 Issue が名前を個別に決めると揺れる（README の手順例は `repository_labels.tf`、#5 の本文は `labels.tf` だった）。
- **1:N の集合を例外にする**: `optional(type, default)` の既定値に集合を持たせると、per-repo で指定した時点で集合全体が置き換わり、追加・除外の差分を表せない。#5 の AC（リポ別に追加・除外できる構造）を最小の記述量で満たすため、共通集合と差分で表す。例外は 1:N の集合に限り、スカラー属性には広げない。

### 4. 値の区分と例外台帳

- **所有者の方針**: 値を類型ごとの型に収め、差がどこに・なぜあるかを台帳の1か所で読めるようにし、上書きの経路を減らす（コンテキスト）。
- **置き場所が区分に一対一で決まる**: リポ固有値＝`repositories.<k>.<concern>.*`（visibility と profile は直下）、類型決定値＝`local.<concern>_profile_defaults`、全リポ共通値＝`local.<concern>_preset` の3つに一対一で決まり、子 Issue の作業者も reviewer も規則だけで配置を判定できる。`local.<concern>_profile_defaults` と `local.<concern>_preset` が同じファイル冒頭に並ぶので、設定種別の方針全体をファイル冒頭で読める。既存の `local.branch_protection_preset` はそのまま残せる。
- **型の検査**: ADR 0001 が `local.*_preset` を採らなかった理由は、`merge()` の戻り値が `map(any)` になって型検査を失うことだった。locals の object を resource から直接参照する形なら、存在しない属性の参照は `terraform validate` が拒否し、値の型は provider のスキーマで検査される。`merge()` を使わないことで、この理由は解消する。
- **既定値は別のフィールドを参照できない（一次確認）**: 2026-09-26 に、`cloud {}` も provider も含まない使い捨てのディレクトリで、Terraform v1.15.6（`mise exec terraform@1.15.6 -- terraform validate`）を実行した。object 型の variable のフィールドに `optional(bool, self.profile == "infra")`（同じ object の別フィールドへの参照）と `optional(bool, var.other)`（別の変数への参照）を書いた設定は、どちらも `Error: Variables not allowed`（`Variables may not be used here.`）で失敗した。公式ドキュメント「Type constraints」の optional object type attributes（<https://developer.hashicorp.com/terraform/language/expressions/type-constraints#optional-object-type-attributes>、2026-09-26 取得）は、既定値について次のように述べる。

  > **Default:** (Optional) The second argument defines the default value that Terraform should use if the attribute is not present. This must be compatible with the attribute type. If not specified, Terraform uses a `null` value of the appropriate type as the default.

  既定値の式で同じ object の別のフィールドや別の変数を参照できるかは、この本文には明示が無い。このため、上の validate の実行結果で一次確認した。既定値を省いた `optional(T)` が null を既定値にすることは、この本文による（決定 §4 の実装形）。したがって、類型で変わる値を型の側（`optional()` の既定値）で解決することはできず、類型決定値は表を直接参照し、台帳登録属性の既定値は null フォールバックで解決する。
- **null だけを未指定とみなす**: 偽値（false、空リスト、0、空文字）を未指定と取り違える合成を防ぐため。ADR 0002 の案 B（`coalesce`）で議論した問題と同じ種類のものである。
- **取り込み時の食い違いを由来で分ける**: 台帳を恒常的な例外だけに保て、暫定のフィールドを足しては消す手数が要らない。変更の対象は属性1つずつで、承認と記録を Issue に残せば追跡できる。代償として、取り込み前の実値の変更は Terraform の plan を経ないので、plan の差分としてはレビューされない。
- **台帳の記録を属性単位＋使用リポにする**: 「可能な限り型にはめる」方針に沿い、reviewer が使用リポごとに理由を照合できる。後から緩めやすい。

### 5. 命名と配置

- **設定種別ごとの入れ子**: Ruleset が branch 用と tag 用の2本になると、`enforcement` などのフィールド名がフラットな構造では衝突する。入れ子にすれば名前の衝突は構造的に起きず、「設定種別名＝ファイル名＝フィールド群のキー」が（`repository` の例外を除いて）一対一で対応し、作業者が規則だけで配置を決められる。現行の `terraform.tfvars` が使っているのは `status_check_contexts` / `status_check_integration_id` だけなので、いま構造を変えても移行コストは小さい。
- **`preset` を全リポ共通値の用途名にする**: 1:N の共通集合（#5 のラベル）も全リポ共通値として `local.labels_preset` で扱えるので、共通集合のためだけの用途名は要らない。README の `local.<resource>_preset` は、名前の形を `<concern>` に直せばそのまま使える。
- **用途名を4つに固定する**: 子 Issue の作業者が locals の名前を ADR だけで決められるようにするため。
- **locals の配置**: 決定 §5 に引用した公式スタイルガイドの「Local values」節の原文に合わせる。現行の `local.branch_protection_preset` も、`branch_protection.tf` の冒頭に置かれている。
- **設定種別に属さないファイルの名前**: 公式スタイルガイドの「File names」節（<https://developer.hashicorp.com/terraform/language/style#file-names>、2026-09-26 取得）は、次の命名を勧めている。

  > We recommend the following file naming conventions:
  >
  > - A `backend.tf` file that contains your backend configuration. You can define multiple `terraform` blocks in your configuration to separate your backend configuration from your Terraform and provider versioning configuration.
  > - A `main.tf` file that contains all resource and data source blocks.
  > - A `outputs.tf` file that contains all output blocks in alphabetical order.
  > - A `providers.tf` file that contains all `provider` blocks and configuration.
  > - A `terraform.tf` file that contains a single `terraform` block which defines your `required_version` and `required_providers`.
  > - A `variables.tf` file that contains all variable blocks in alphabetical order.
  > - A `locals.tf` file that contains local values. Refer to local values for more information.
  > - A `override.tf` file that contains override definitions for your configuration. Terraform loads this and all files ending with `_override.tf` last. Use them sparingly and add comments to the original resource definitions, as these overrides make your code harder to reason about. Refer to the override files documentation for more information.

  決定 §5 の設定種別に属さない5つの名前（`terraform.tf` / `providers.tf` / `variables.tf` / `locals.tf` / `outputs.tf`）は、このうちの5つである。`main.tf` に集める代わりに設定種別ファイルへ分け（根拠 §3）、`backend.tf` は置かない（本リポの `cloud {}` ブロックは `terraform.tf` にある。CLAUDE.md §1）。`override.tf` は、設定種別に属さない5つの名前に含めていない。

### 6. visibility による出し分け

- **軸を分ける**: 類型と visibility は互いに独立なので、「private なら OFF」を類型決定値の表で表すと、同じ類型の private リポで破綻する。per-repo のフィールドで表すと、制約を外せてしまい制約を表せない。
- **設定種別ファイルの冒頭に適用対象の集合を置く**: 制約がそのファイルの中で閉じる。中央の表にすると、設定種別を足すたびに2つのファイルを触ることになる（ADR 0001 が解消した2ファイル問題が再び起きる）。
- **宣言値を先に変える（public → private）**: 未確認の API の挙動に依存しない唯一の順序である。Ruleset が無い期間は、所有者が apply と UI の変更を続けて行う間に限られる。

### 7. 類型プロファイル

- **判定基準を「変更がどこへ届くか」にする**: 類型決定値の主な差（タグ保護、Actions 権限）は、変更が届く先で決まる。判定基準を固定すると、誰が判定しても同じ類型になる。
- **配布物を最上位にする**: インフラの被害は所有者が管理する実環境の中に閉じ、所有者自身が復旧手段（revert、state、credential の再発行）を持っている。配布物の被害は利用者の環境へ届き、所有者の側では回収できない。タグ保護（#74）のような供給網の防御が既定で外れると、そのまま利用者への被害につながる。
- **宣言を必須にする**: 付け忘れを構造的に防げ、`visibility`（必須）と同じ扱いになる。#72 の AC1 がすでに全リポへの類型の宣言を求めているので、必須にしても手間は増えない。一覧にない値の拒否は #72 の AC2 が求めている。

## 代替案

### 1. 単一 root module の維持

- **child module 化（設定種別ごとに module を作る）**: state・plan の対象・影響半径・App 権限は変わらず、単一のリソース型の薄い包装になる。公式ガイドが勧めない形である。
- **環境ごとの root**: 本リポに環境の区別は無い。検証用の owner / Org を設ける場合は §2 の A-2 として扱う。
- **private リポの定義を HCP Workspace の変数へ分離する**（#4 の 2026-09-26 のコメントで却下）: PR のレビュー経路を失う。
- **private リポ専用の非公開 config リポ・Workspace を別に建てる**（同コメントで却下）: root module が2つになり、運用コストに見合わない。

### 2. 発動条件

- **定量の閾値だけで定める**: 機械判定はしやすいが、閾値の超過を分割に直結させると誤った分割を誘発する。
- **定性的な事象だけで定める**: 観測できるかどうかが事象の定義しだいになり、規模の悪化も検知できない。
- **child module 化だけを扱う**: 環境の分離や App 権限の分離を判断する基準がどこにも無いまま残る。

### 3. 設定種別と適用表

- **リソース型ごとにファイルを分ける**（`branch_protection.tf` を `repository_ruleset.tf` に改名し、タグ保護も同じファイルに入れる）: ADR 0001 の旧来の字面（1ファイル=1リソース種別）とは合うが、関心事の局所性が失われ、Ruleset のファイルが膨らむ。
- **子 Issue ごとにファイルを分ける**: Issue の切り方にファイル構成が引きずられ、再編のたびに改名が連鎖する。
- **1:N の集合を例外にせず、per-repo に実効の集合を全量書く**: `terraform.tfvars` に共通集合の複製が増え、共通集合を変えても各リポの記述が追従しない。
- **1:N の共通集合を型付き variable の既定値に置く**: `terraform.tfvars` や HCP の変数から上書きできる別の経路ができ、正とする記述場所が2つになる。

### 4. 値の区分と例外台帳

- **類型既定値 → per-repo override の2段（全属性で per-repo の上書きを許す）**: 例外登録制の前に採っていた構造（#32 のコメント）。所有者の方針（コンテキスト）により改めた。
- **類型ごとのサブマップ（類型決定値の実現形）**: `repositories` を類型ごとの map に分け、それぞれに異なる `optional` の既定値を書く。object 型の定義を類型の数だけ複製することになり、属性を1つ足すたびに4か所を直す必要がある。
- **類型決定値の表を型付き variable の既定値に置く**: 表を `terraform.tfvars` や HCP の変数から上書きできてしまう。
- **`merge()` で合成する**: 型を失い、重ねる順序が暗黙の優先順位になる（ADR 0001、#32 のコメント）。
- **全リポ共通値を resource ブロックの引数にリテラルで書く**: 間接参照は無くなるが、共通値が resource の中に散らばり、冒頭の類型決定値の表と並べて比べられない。1:N の共通集合はリテラルでは書きにくく結局 locals が要るので、区分ごとの置き場所が揃わない。移行で preset の値を resource の引数へ展開する作業も増える。
- **全リポ共通値を型付きのトップレベル variable の既定値に置く**: 型制約を明示でき「variable defaults 化」の字義に最も近いが、`terraform.tfvars` や HCP の変数から共通値全体を上書きできる別の経路ができ、正とする記述場所が2つになる。類型決定値の表（locals）とも置き場所が揃わない。
- **全リポ共通値を `repositories` のフィールド既定値に置く**（ADR 0001 の #63 改訂時の形）: per-repo の上書き経路そのものなので、例外登録制と両立しない。検討の対象外とした。
- **取り込み時の食い違い: 取り込みの後に Terraform で寄せる**: 取り込みの PR で台帳に暫定の行とフィールドを足して実値で取り込み、続く PR で消して区分の値への変更を plan の in-place update としてレビューする。変更がすべて plan を通るが、取り込みのたびにフィールドと台帳の行を足しては消すことになり、台帳に暫定の行が混ざる。
- **取り込み時の食い違い: すべて台帳に恒久登録する**: 手数は最小だが、取り込みの時点の実態がそのまま例外として固定され、型にはめる方針が取り込みのたびに崩れる。
- **取り込み時の食い違い: 食い違った属性をリポ固有値へ区分し直す**: その属性は方針値を持たなくなり、揃える対象から外れる。
- **取り込み時の食い違い: import と同じ plan で in-place update する**: CLAUDE.md §2 の「import の plan が `0 to change`」に反するので、対象外とした。
- **台帳を属性単位で登録するだけにする（登録後はどのリポも使える）**: 使用リポごとの理由を照合できず、「可能な限り型にはめる」方針に沿わない。

### 5. 命名と配置

- **フラットのまま、衝突するものだけに接頭辞を付ける**（例: `tag_protection_enforcement`）: 接頭辞の要否がフィールドごとに揺れ、規則が「衝突したら付ける」という事後判断になる。
- **ADR 0001 の図どおりフラットにする**: 衝突したときの命名がその場しのぎになる。
- **Issue #32 本文の `<resource>_<axis>.tf` / `local.<resource>_<axis>_preset`**: ADR 0001 の改訂（#63）で廃止した動機軸の分割を再び採ることになり、改訂の根拠（resource ブロックを分割できないことによる2ファイル問題、`merge()` による型の喪失）とぶつかる。
- **locals の用途名を各 Issue に任せる**: ADR だけで locals の名前を決められなくなる。

### 6. visibility による出し分け

- **中央の適用可否表（`locals.tf`）を全設定種別から参照する**: 一覧しやすいが、設定種別を足すたびに2つのファイルを触ることになる。
- **類型決定値の表で「private なら OFF」を表す**: 根拠 §6 のとおり破綻する。
- **public → private で UI を先に変える**: Ruleset が無い期間は生じないが、private になったリポの Ruleset を refresh や destroy で扱う API が Free で失敗した場合（未確認）、plan か apply が失敗し、state から外す復旧作業が要る。
- **`removed` ブロック（`lifecycle { destroy = false }`）で state からだけ外す**: 削除の API を呼ばずに済むが、`removed` ブロックは Terraform 1.7.0 で導入されたもので（CHANGELOG）、現在の `required_version`（`>= 1.6`）の引き上げが要る。`for_each` の1インスタンスだけを対象にできるかも未確認で、GitHub 側には Ruleset が残る。

### 7. 類型プロファイル

- **判定基準を「リポが保持する権限や秘密」にする**: インフラの判定は明確になるが、配布物とアプリの区別（ref や複製で取り込まれるか）が基準に現れず、タグ保護の対象を決める根拠にならない。
- **順序をインフラ > 配布物 > アプリ > ローカル構成にする**（保持する権限の強さを軸にする）: 所有者が後から回収できない利用者側の被害を、既定で防げなくなる。
- **既定の類型を置く（例: アプリ）**: 付け忘れたリポに既定の類型の方針が黙って適用される。
- **「類型なし」を許し、全類型に共通の値へ落とす**: 類型決定値の表ごとに「類型なし」の行が要り、表が5行になる。
- **性質別プリセットの重ね合わせ（ミックスイン。複数を `merge()` で重ねる）**（#32 のコメントで却下）: 重ね順が暗黙の優先順位になり、衝突規則の別途定義が要る。`merge()` は浅い合成で、list などが丸ごと置き換わる。
- **複数の類型を重ね、属性ごとに厳しい方を採る**（同コメントで却下）: 属性ごとに「厳しさ」の順序の定義が要り、複雑になる。
- **複合類型（例: `infra_app`）を列挙する**（同コメントで却下）: 組み合わせの数だけ型が増える。

## 影響

### 子 Issue の早見表

module 化の要否は、§2 の事象が起きていないことを前提とする。新しい設定種別を足す Issue（#5・#7・#73・#74）は、着手時に §2 A-1 を確かめる（#73・#74 は、本文の参考欄に Administration write で書き込めることの一次確認が記録されている）。ラベルの API が App の権限（Administration / Metadata）を超えるかは、#5 で CLAUDE.md §3 に従い確認する。超える場合は、別 Issue で権限を拡張する。#6 は #16・#17 の親として、この2行を通じて扱う。

| Issue | module 化の要否 | ファイル | resource ラベル | フィールドの配置 | locals の名前 | per-repo で変えられる範囲 | 前提となる Issue |
|---|---|---|---|---|---|---|---|
| #16 | しない | `repository.tf`（新設）、`variables.tf` | `github_repository.this`（ADR 0001） | `repositories.<k>.visibility`（直下、必須）と `repositories.<k>.repository.archived` などのリポ固有値。`allow_auto_merge` / `has_wiki` / `has_projects` / `has_discussions` は #16 が §4 で区分し、リポ固有値のときだけ `repositories.<k>.repository.*` に置く | `local.repository_preset`（全リポ共通値）、`local.repository_profile_defaults`（類型決定値があれば） | リポ固有値と台帳登録属性だけ | #32。類型決定値を置くなら #72。移行 Issue とは直列（前後は問わない） |
| #17 | しない | `repository.tf`（#16 が新設したもの）、`variables.tf` | `github_repository.this` | `description` / `homepage` / `topics` と説明系属性を管理外にする指定は `repositories.<k>.repository.*`（リポ固有値）。`allow_squash_merge` / `allow_merge_commit` / `allow_rebase_merge` と `squash_merge_commit_title` / `squash_merge_commit_message` は per-repo のフィールドを持たない（全リポ共通値の見込み。確定は #17）。`delete_branch_on_merge` / `default_branch` / `has_issues` は #17 が §4 で区分する | `local.repository_preset`、`local.repository_profile_defaults`（類型決定値があれば） | リポ固有値と台帳登録属性だけ | #16 |
| #5 | しない | `labels.tf` | `labels`（`github_issue_label.labels` か `github_issue_labels.labels`） | `repositories.<k>.labels.add`（リポ固有値）、`repositories.<k>.labels.exclude`（例外台帳に登録して置く） | `local.labels_preset`（共通集合。類型で変えるなら `local.labels_profile_defaults`）、`local.labels_instances`（`for_each` に渡す展開結果） | 追加分と、台帳に登録した除外分 | #32。共通集合を類型で変えるなら #72 |
| #7 | しない | `repository.tf`（`vulnerability_alerts`、`security_and_analysis` 配下）と `dependabot_security_updates.tf` | `github_repository.this` と `github_repository_dependabot_security_updates.dependabot_security_updates` | `repositories.<k>.repository.*` と `repositories.<k>.dependabot_security_updates.*` の2か所に分かれうる。どちらも、リポ固有値か台帳登録属性があるときだけ置く | `local.repository_preset` / `local.repository_profile_defaults`、`local.dependabot_security_updates_preset` / `local.dependabot_security_updates_profile_defaults`（区分に応じて）。private で使えないリソースは `local.dependabot_security_updates_targets`、`repository.tf` の中の private で使えない属性は visibility を条件にした条件分岐（§6） | リポ固有値と台帳登録属性だけ。private で使えないことによる出し分けは台帳の登録を要しない | #16、#72 |
| #72 | しない | `variables.tf`、`terraform.tfvars` | なし（resource を足さない） | `repositories.<k>.profile`（直下、必須、値は §7 の4つの識別子に限る） | なし（`local.<concern>_profile_defaults` は各設定種別の Issue が作る） | `profile` 自体はリポごとに宣言する値である | #32。移行 Issue とは直列（前後は問わない） |
| #73 | しない | `actions_permissions.tf` | `github_actions_repository_permissions.actions_permissions` と `github_workflow_repository_permissions.actions_permissions` | 無い。台帳に登録した属性があるときだけ `repositories.<k>.actions_permissions.*` を置く（候補: PR の作成を許す必要があるリポ） | `local.actions_permissions_profile_defaults`（類型決定値）。全リポ共通値があれば `local.actions_permissions_preset`。visibility の制約が無いので `targets` は置かない | 台帳登録属性だけ | #72。移行 Issue は待たない |
| #74 | しない | `tag_protection.tf` | `github_repository_ruleset.tag_protection` | 無い（リポ固有値も台帳登録属性も無ければ `repositories.<k>.tag_protection` のキーを設けない） | `local.tag_protection_targets`（public かつ類型で有効なリポ）、`local.tag_protection_profile_defaults`（有効にする類型。値は #74 が決める）、`local.tag_protection_preset`（保護対象の範囲などが全リポ共通値なら） | 台帳登録属性だけ | #72、#16（public での絞り込みに `visibility` を要する。`visibility` は #16 で入る）。移行 Issue は待たない |
| #71 | しない | `branch_protection.tf` | `github_repository_ruleset.branch_protection` | per-repo のフィールドは無い（外すリポがあれば台帳に登録して `repositories.<k>.branch_protection` に足す） | 類型決定値にするなら `local.branch_protection_profile_defaults`、全リポ共通値のままなら `local.branch_protection_preset` | 台帳登録属性だけ | 移行 Issue、#72 |
| #4 | しない（別の owner の追加は §2 A-2） | `terraform.tfvars`（リポの追加）、`branch_protection.tf`（Ruleset の適用対象を public に絞る） | 既存のもの（`github_repository_ruleset.branch_protection` など） | 追加するリポに `visibility`、#72 の完了後は `profile`、必須のリポ固有値を宣言する | `local.branch_protection_targets`（public のリポ）を新設する。`tag_protection` があり public で絞られていなければ、`local.tag_protection_targets` も public で絞る | リポ固有値と台帳登録属性だけ | #16（`visibility`） |

取り込み（import）や未管理だった属性の追加を伴う Issue（#16・#17・#5・#7・#73・#74・#4）は、実値が類型決定値・全リポ共通値と食い違う属性を §4「取り込み時の食い違い」で扱う。#73 の本文は、Actions の設定が「リポごとに手動設定されている」としている。

### ADR 0001 との関係

J12 の判断（ADR 0001 の本文を書き換える。補注方式は採らない）に従い、本 ADR と同じ変更で、ADR 0001 の次の箇所を書き換えた。行番号は書き換え前（main 2718578）の ADR 0001 のものである。ADR 0001 のステータス節には「改訂済（2026-09-26、#32）」を追記し、#63 の改訂履歴の後に #32 の改訂履歴を足した。

| # | ADR 0001 の箇所 | 書き換え前の要旨 | 書き換え後の要旨 |
|---|---|---|---|
| 1 | L5・L7（ステータス） | 改訂済（#63）と改訂範囲 | 「改訂済（2026-09-26、#32）」と #32 の改訂範囲（決定 §1、根拠 §1、影響の3小節と import 節の該当行、ロールバック可能性）を追記し、§2・§3・付録は変更しない旨を書く。本 ADR へのリンクを置く |
| 2 | L40（決定 §1 の見出し） | `repository.tf` 1ファイル集約 + variable defaults | `repository.tf` 1ファイル集約 + 値の区分に応じた直接参照 |
| 3 | L48 の直後 | （追加） | #32 の改訂履歴（変えたこと、理由、本 ADR の節）を、#63 の改訂履歴の引用ブロック（L42-48）の後に別の引用ブロックで追記する |
| 4 | L48 | `merge()` パターンから variable defaults への実コード移行は別 Issue | L48 は #63 の改訂履歴の引用ブロックの中にあるので書き換えない。#3 で追記した #32 の改訂履歴の中で、移行先が本 ADR §4 の値の区分に変わったこと（移行は別 Issue）を述べる |
| 5 | L51 | preset を `repositories` のフィールド既定値に置く。`local.*_preset` + `merge()` / null sentinel / ternary は採用しない | 置き場所を値の区分で決める（リポ固有値＝`repositories` のフィールド、類型決定値＝`local.<concern>_profile_defaults`、全リポ共通値＝`local.<concern>_preset`）。`merge()` は採用しない。null センチネルと三項演算子は、例外台帳に登録した属性の null フォールバックに限る。visibility による適用可否の条件分岐はこの対象外 |
| 6 | L52 | `archived = optional(bool, false)` を preset（4リポ共通値）の例とする | リポ固有値と全リポ共通値の例に差し替える（#16 の AC は archived を per-repo の必須宣言としており、書き換え前の例とも食い違っていた） |
| 7 | L53 | per-repo override は変数値でフィールドを上書きする | per-repo で値を変えられるのは、リポ固有値と台帳登録属性だけ |
| 8 | L56 | 属性値は `var.repositories[each.key].<attr>` を直接参照 | 区分ごとの参照先（入れ子のパス、`local.<concern>_preset`、類型決定値の表） |
| 9 | L58-72 | フラットな型の図 | 直下に visibility と profile、設定種別ごとの入れ子にリポ固有値を置く図 |
| 10 | L74 | variable defaults を `repositories` 全体に適用し、branch_protection も preset を default 化する | 値の区分を全設定種別に適用する。branch_protection の移行内容は本 ADR の影響「branch_protection の移行 Issue」のとおり |
| 11 | L75 | 「1ファイル=1リソース種別 + variable defaults」 | 「1ファイル=1設定種別」（本 ADR §5） |
| 12 | L90（根拠 §1 の見出し） | 1ファイル集約 + variable defaults 採用 | 決定 §1 の見出し（#2）に合わせる |
| 13 | L92 | 改訂後は variable defaults を採用する | #63 の採用を過去形で述べ、#32 で値の区分を加えた根拠は本 ADR §4 を参照する1文を足す |
| 14 | L94 | 型安全性の維持（preset 値も per-repo override も同一の `map(object)` 型に収まる） | 値を型付きの変数（リポ固有値）と locals の object（類型決定値・全リポ共通値）から直接参照し、`merge()` による `map(any)` 化を避ける |
| 15 | L95 | `var.repositories[each.key].X` を直接参照するだけ | 入れ子のパスと区分ごとの参照先 |
| 16 | L96 | 公式スタイルガイドとの整合（preset 値は variable のデフォルトとして表現され、独立した locals ファイル群を新設しない） | locals を本 ADR §5 の配置（ファイル固有のものはそのファイルの冒頭、複数のファイルから参照するものは `locals.tf`）に置くことで整合する |
| 17 | L97 | 「1ファイル=1リソース種別」、同じ variable defaults パターンへ統一する | 「1ファイル=1設定種別」、値の区分へ統一する |
| 18 | L156 | 属性値は `var.repositories[each.key].<attr>` を直接参照（`merge()` / locals 合成は使わない） | `merge()` は使わず、区分ごとの置き場所から直接参照する |
| 19 | L157 | セキュリティ系属性を `optional(type, default)` で宣言し、差分のある has_wiki は per-repo override | 各属性の区分は #16 が本 ADR §4 の基準で判定する。付録 A の共通の値は候補値。has_wiki の食い違いは本 ADR §4 の取り込み時の規則に従う |
| 20 | L162 | 開発プロセス系属性（同上）、差分のある delete_branch_on_merge / description は per-repo override | 同上。description はリポ固有値の見込み、delete_branch_on_merge の食い違いは取り込み時の規則に従う |
| 21 | L163 | variable defaults に集約されるため | 区分ごとの置き場所に集約されるため |
| 22 | L164 | 差分のある3属性を per-repo override として tfvars に追記 | リポ固有値は tfvars に書き、区分の値と食い違う属性は取り込み時の規則で扱う |
| 23 | L169 | variable defaults パターンを `repositories` 全体に適用するため | 値の区分を全設定種別に適用するため |
| 24 | L171 | branch protection 系属性を `optional(type, default)` で再宣言し、preset の値を default に移植 | status_check の2属性を `branch_protection.*` へ入れ子にし、未使用の上書きフィールド9つを削除する。全リポ共通値は `local.branch_protection_preset` に置く |
| 25 | L172 | `merge()` の for 式を全削除し、`var.repositories[each.key].X` を直接参照 | `merge()` の for 式を削除し、全リポ共通値は `local.branch_protection_preset` から、リポ固有値は入れ子のパスから直接参照する |
| 26 | L173 | preset と for 式は削除可能（`name` / `target` 等の固定値は resource に直接記述） | for 式は削除する。`local.branch_protection_preset` は全リポ共通値の置き場所として残し、resource から直接参照する |
| 27 | L180 | `optional(type, default)` 既定値 + per-repo override（差分のある属性だけ tfvars）で No changes | リポ固有値は tfvars に書き、区分の値と食い違う属性は取り込み時の規則で扱って No changes にする |
| 28 | L204 | `visibility`（required）のみの宣言で済む | visibility と profile（ともに必須）と、必須のリポ固有値の宣言で済む |
| 29 | L208 | ロールバック（1ファイル集約 + variable defaults ↔ 案 B'） | 起点を改訂後の構造に合わせ、#32 の改訂を戻す手順（類型決定値・全リポ共通値を `repositories` のフィールド既定値へ戻す。tfvars と型定義の書き換えだけで、state は変わらない）を1項目足す |

ADR 0001 の #63 の改訂履歴（L42-48）、§2・§3、根拠 §2〜§4、代替案、リポ名変更と `moved` の節、付録 A・B は変更していない。L27・L115・付録 A の「per-repo override 必須範囲」は #15 の時点の観測の記録であり、L140 は案 B' を退けた理由の記録である。

### ADR 0005 との関係

J18 の判断に従い、本 ADR と同じ変更で [ADR 0005](0005-squash-only-merge-method.md) を書き換えた。ステータス節（L5）に、影響節の上書き機構の記述を #32（本 ADR）で改訂したこと（2026-09-26）を追記した。L64 の「既存の per-repo override 機構（…）は変更しないため、個別リポジトリで本方針から外す余地は残る」は、「`allowed_merge_methods` は本 ADR の全リポ共通値にあたる。個別のリポで本方針から外す場合は、本 ADR の例外台帳への登録を要する。`variables.tf` に残る未使用の上書きフィールドは移行 Issue で削除する」という趣旨に書き換えた。L20 の決定（`local.branch_protection_preset.allowed_merge_methods` を統一する）は、全リポ共通値の置き場所が `local.branch_protection_preset` のままなので、そのまま成り立つ。

### ADR 0002 との関係

[ADR 0002](0002-branch-protection-preset-merge-pattern.md) は変更しない。L7 の注記（移行 Issue が完了するまで `merge()` パターンに従う）は上書きフィールドを足すことを指示していないので、本 ADR と食い違わない（決定 §4「経過措置」）。L9-18 は ADR 0001 の改訂（#63）を説明した過去の記録である。

### branch_protection の移行 Issue

移行 Issue は未起票（本 ADR の承認後に起票）。ADR 0001（L48・L74・L169-175）と ADR 0002 の注記が「別 Issue で実施」としている移行を、本 ADR の値の区分を反映した範囲で行う。

- **範囲**:
  - `status_check_contexts` / `status_check_integration_id` を `repositories.<k>.branch_protection.*` へ入れ子にする。
  - `variables.tf` の未使用の上書きフィールド9つを削除する。
  - `merge()` 式の `local.branch_protection` を削除し、全リポ共通値は `local.branch_protection_preset` から、リポ固有値は入れ子のパスから直接参照する。
  - `variables.tf` の description とコメント、`branch_protection.tf` のコメント、`terraform.tfvars` L1 を直し、tf-docs スキル（`.claude/skills/tf-docs/`）で README の変数表（L45-60）を再生成する。
  - README L17・L20・L31・L32・L229 を直す。
  - plan が No changes であることを確かめる。
- **順序**: 本 ADR の承認の後、#71 の前に置く。#72・#16 とは同じ `variables.tf` を触るので直列にするが、前後は問わない。#74・#73 は移行を待たない。
- 移行の後に着手する #71 は、`strict_required_status_checks_policy` を類型決定値にするなら `local.branch_protection_profile_defaults` へ移し、特定のリポで外すなら例外台帳に登録する。

### reviewer

- reviewer の観点6（`.claude/agents/terraform-design-reviewer.md` の「観点 6: preset 上書き経路の一貫性」、`docs/agents/terraform-design-reviewer/README.md` の観点表、fixture `06-preset-merge/`）は、改訂前の ADR 0001 の `merge(local.repository_security_preset, ...)` と三項演算子による合成を正としており、陳腐化している。新しい検査は次のとおりである。
  - `repositories` のフィールドが、リポ固有値か台帳登録属性に限られる。
  - null フォールバックは台帳登録属性だけに使う。
  - `merge()` を使わない。
  - 値を区分の置き場所から直接参照する。
- §2 のうち Read / Grep / Glob で評価できる条件（C-1〜C-3）で、観点9を足す余地がある。
- 観点6の是正と観点9の追加は、本 ADR の承認後に別 Issue として起票する。

### PR #19

[PR #19](https://github.com/kuchita-el/github-config/pull/19)（#16 を改訂前の ADR 0001 のパターンで実装したもの）は、廃止済みのパターンに基づく。#16 は ADR 0001 と本 ADR に従って作り直す。PR をクローズするか書き直すかは、#16 の着手時に決める。

### 陳腐化した記述と是正の時期

「per-repo override の機構を維持する」「per-repo override で上書きする」という趣旨を現在形で述べる記述は、次のとおり扱う。

- **本 ADR と同じ変更で直したもの**（方針を指示する記述）: ADR 0001（上記）、ADR 0005 L5・L64（上記）、README L20・L40・L143・L152-154・L237-245・L283（行番号は main 2718578）。
- **CLAUDE.md §2 の手順2（L22）**: 「`terraform.tfvars` / `branch_protection.tf` を実態へ寄せる」と書いている。類型決定値・全リポ共通値の食い違いには §4「取り込み時の食い違い」が優先する。同じ趣旨の1文を CLAUDE.md に足すのは、所有者の明示承認を得た場合に限る。
- **移行 Issue で直すもの**（コードの現状の説明）: README L17・L31・L32・L45-60・L229、`variables.tf` の description（L7-14）と L24 のコメント、`branch_protection.tf` L6・L35-39 のコメント、`terraform.tfvars` L1。いずれも現行コードの説明としては正しく、移行 Issue でコードと一緒に変わる。
- **Issue 本文**（本 ADR の承認後に編集する）: #71（ブロッカー、AC2、AC3、制約、参考の1項目目と最終項目）、#72（背景）、#73（目的、IN、AC2、AC5）、#74（IN）、#7（完了条件の2項目目、備考の追記）、#5（スコープ）、#16（ゴール、スコープの `archived`、完了条件の1項目目）、#17（ゴール、完了条件の1・2項目目）、#4（L9 のスコープ、L23 の備考「既存リポの個別カスタマイズを上書きしない」）、#6（L7 のスコープ、L12 の `archived`）。#32 の本文（スコープの「2段構造」と AC4 の文言）は所有者が更新する。#4 L23 について、§4「取り込み時の食い違い」の由来の無い差を承認を得て変える手順は、承認を経た意図的な変更であり黙った上書きではないが、制約の文言は更新が要る。
- **編集しないもの**: #70（クローズ済み）の制約文は、完了した Issue の記録である。

### ADR の番号

本 ADR は 0004、#70 の ADR は 0005（マージ済み）である。#10 は保留で ADR を起票しないので、番号を予約しない。

## ロールバック可能性

- **§1・§2（単一 root、発動条件）**: 文書だけの決定で、戻すのは本 ADR の改訂で済む。state への影響は無い。閾値の数値の変更も同じである。
- **§3・§5（設定種別ごとのファイル、命名）**: ファイル名を変えても state のアドレス（リソース型とラベル）は変わらない。resource ラベルを変える場合は `moved` ブロックが要る。
- **§4 の例外登録制を戻す（全属性で per-repo の上書きを許す）**: per-repo のフィールドを足し、区分の置き場所からの直接参照を null フォールバックに置き換える変更で済む。state は変わらない。
- **類型決定値・全リポ共通値の置き場所を `repositories` のフィールド既定値へ戻す**（#63 の改訂時の形）: 型定義と `terraform.tfvars` の書き換えだけで済み、state は変わらない（ADR 0001 のロールバック可能性に1項目を足した）。既定値からは類型を参照できないので（根拠 §4）、類型で値が異なる属性は、各リポの `terraform.tfvars` に値を書く形になる。
- **設定種別ごとの入れ子をフラットに戻す**: 型定義と `terraform.tfvars` の書き換えだけで済み、state は変わらない。
- **取り込み時の食い違いの規則**: 規則を戻しても、取り込み前に GitHub 側で変えた実値は戻らない。戻すには、取り込み Issue に記録した変更前の値へ GitHub 側で戻す（Terraform の管理下にあれば、宣言値の変更として plan を通す）。
- **§6（visibility による出し分け）**: 適用対象の集合を変えると、Ruleset のインスタンスの create / destroy が生じ、state が変わる。public → private の手順（宣言値を先に変える）を変えるのは手順の変更だけで、state には影響しない。
- **§7（類型）**: リポの類型を変えると、新旧の類型で値が異なる類型決定値だけが変わる（適用対象の集合を決めるものはインスタンスの create / destroy、それ以外は in-place update）。類型の一覧や順序を変えるには、`profile` の値の検証、各設定種別の `local.<concern>_profile_defaults`、`terraform.tfvars` の `profile` を書き換える。state のアドレスは変わらない。

## 再評価の条件

次のいずれかが成立した場合、本 ADR を見直す。

- `optional()` の既定値で、同じ object の別のフィールドや別の変数を参照できるようになった場合（§4 の null フォールバックの前提が消える）。
- GitHub Free で、private リポに Ruleset を使えるようになった場合（§6 の前提が消える）。
- private リポに対する Ruleset の API の挙動が確認され、public → private の手順を UI 先行に変えられると分かった場合（§6 の手順を見直す）。
- 例外台帳の行数が増え続け、類型の定義の見直しが要ると判断される場合（§7 を見直す）。

## 付録 A: 規模の実測値

取得時点: 2026-09-26、origin/main 2718578。root 直下で取得した。

| 指標 | 値 | 取得方法 |
|---|---|---|
| `.tf` の枚数と行数 | 4 枚（`branch_protection.tf` 105 行、`providers.tf` 19 行、`terraform.tf` 20 行、`variables.tf` 45 行） | `wc -l *.tf` |
| resource 型の異なり数（§2 C-1） | 1（`github_repository_ruleset`） | `grep -hoE '^resource "[a-z_]+"' *.tf \| sort \| uniq -c` の出力の行数 |
| 設定種別ファイルの数（§2 C-2） | 1（`branch_protection.tf`） | 上の `.tf` の一覧から `terraform.tf` / `providers.tf` / `variables.tf` / `locals.tf` / `outputs.tf` を除いて数える |
| `.tf` の最大行数（§2 C-3） | 105（`branch_protection.tf`） | `wc -l *.tf` |
| 管理リポ数 | 4 | `terraform.tfvars` の `repositories` のエントリ数 |
| 管理リソース数（§2 C-4） | 4 | resource ブロックは `github_repository_ruleset.branch_protection` の1つで、`for_each` が `repositories` の4エントリへ展開する |

**§2 の条件への当てはめ**（取得時点）:

| 条件 | 当てはめ | 判定 |
|---|---|---|
| A-1 App の権限の拡張 | 管理しているリソース型は `github_repository_ruleset` だけで、App の権限（Administration: Read & write / Metadata: Read）の範囲に収まっている | 未発火 |
| A-2 別の owner / Org | `github_owner` は `kuchita-el` の1つだけ | 未発火 |
| B-1 2つ目の root | root は1つ | 未発火 |
| C-1 resource 型の異なり数 | 1（10 以下） | 未発火 |
| C-2 設定種別ファイルの数 | 1（10 以下） | 未発火 |
| C-3 `.tf` の行数 | 最大 105（300 以下） | 未発火 |
| C-4 管理リソース数 | 4（400 以下） | 未発火 |
| C-5 レート制限による plan の失敗 | 未取得 | 未取得 |
