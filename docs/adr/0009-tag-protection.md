# ADR 0009: タグ保護 Ruleset を配布物類型のみ有効にし、release 固有タグのみ保護対象にする

## ステータス

承認（2026-09-27、[#74](https://github.com/kuchita-el/github-config/issues/74)）

## コンテキスト

現在の Ruleset preset（`branch_protection.tf`）は branch のみを対象としており、タグは保護されていない。配布物（プラグイン・GitHub Action 等）のリポでは、利用者がタグやコミットを ref として参照するため、既存タグの削除や別コミットへの付け替えは、利用者の環境へ意図しないコードを届ける供給網上の経路になる。

管理対象4リポのうち、タグを持つのは `dependabot-triage-action` のみ（2026-09-27 時点: `v1` / `v1.0.0` / `v1.1.0` / `v1.2.0`）。同リポの `release.yml` は、GitHub の推奨（"Using immutable releases and tags to manage your action's releases"）に沿い、release 固有タグ `vX.Y.Z` を新規作成したうえで、floating major タグ `v1` を Actions の `GITHUB_TOKEN` で `git tag -f` + `git push -f` して最新リリースへ付け替える。`vX.Y.Z` は新規作成のみで force-update しない。同リポは Immutable releases が有効（`v1.2.0` は `immutable=true`）で、release に紐づくタグは既に GitHub 側で保護されている。他の3リポはタグを持たない。

保護は release 固有タグ `vX.Y.Z` のみを対象にする必要がある。全タグ（floating タグを含む）に deletion / update / non_fast_forward の禁止を bypass actor なしで適用すると、`v1` の付け替えが拒否され、`release.yml` の既存手順が壊れる。

管理対象4リポの類型（ADR 0004 §7）と public/private:

| リポ | 類型 | visibility | タグ |
|---|---|---|---|
| `gachanuma` | `app` | public | なし |
| `github-config` | `infra` | public | なし |
| `claude-shared-skills` | `distribution` | public | なし |
| `dependabot-triage-action` | `distribution` | public | `v1`、`v1.0.0`、`v1.1.0`、`v1.2.0` |

GitHub Free プランでは Ruleset は public リポジトリでのみ使える（tag ターゲットも同様、2026-09-26 一次確認）。

`conditions.ref_name` の include/exclude パターンは fnmatch 構文を使う（GitHub Docs「Creating rulesets for a repository」）。同ページの説明:

> "You can use `fnmatch` syntax to include or exclude branches or tags based on a pattern."
> "You can use the `*` wildcard to match any string of characters. Because GitHub uses the `File::FNM_PATHNAME` flag for the `File.fnmatch` syntax, the `*` wildcard does not match directory separators (`/`)."

`.` は fnmatch のワイルドカードではなくリテラル文字として扱われる。したがって `refs/tags/v*.*.*` というパターンは「`v` に続き、`/` を含まない任意の文字列＋リテラル `.`＋`/` を含まない任意の文字列＋リテラル `.`＋`/` を含まない任意の文字列」を要求する。

- `refs/tags/v1`（`.` を含まない）: リテラル `.` を2個要求するパターンに一致しない → 除外される。
- `refs/tags/v1.1`（`.` を1個しか含まない）: 2個目のリテラル `.` を満たせない → 除外される。
- `refs/tags/v1.0.0`（`.` を2個含む）: `v` + `1` + `.` + `0` + `.` + `0` で一致する → 対象になる。

`conditions.ref_name` の include/exclude はフルパス形式（GitHub REST API docs「Repository rules」の例: `"include": ["refs/heads/main"]`）。tag ターゲットの直接例は無いが、`refs/tags/` プレフィックスを使う（fixture `docs/agents/terraform-design-reviewer/fixtures/06-preset-merge/adr0004-compliant-tag-protection.tf.example` の `~ALL` 相当の使用実績と整合）。

## 決定

### 1. 値と区分

設定種別 `tag_protection`（`tag_protection.tf`、1リポ1件）の属性を、ADR 0004 §4 の区分で次のとおり定める。

| 属性 | 区分（ADR 0004 §4） | 値 |
|---|---|---|
| `name` | 全リポ共通値 | `"tag protection"` |
| `target` | 全リポ共通値 | `"tag"` |
| `conditions.ref_name.include` | 全リポ共通値 | `["refs/tags/v*.*.*"]` |
| `conditions.ref_name.exclude` | 全リポ共通値 | `[]` |
| `rules.deletion` | 全リポ共通値 | `true` |
| `rules.update` | 全リポ共通値 | `true` |
| `rules.non_fast_forward` | 全リポ共通値 | `true` |
| `rules.creation` | （宣言しない＝制限しない） | — |
| `bypass_actors` | （ブロックを置かない＝bypass なし） | — |
| `enforcement` | 類型決定値 | `distribution = "active"` / `infra = "disabled"` / `app = "disabled"` / `local_config = "disabled"` |
| 適用対象 | `local.tag_protection_targets`（visibility のみで絞る） | `visibility == "public"` |

- 全リポ共通値は `tag_protection.tf` 冒頭の `local.tag_protection_preset` に置く。
- 類型決定値は `local.tag_protection_profile_defaults` に置き、4つの識別子すべてをキーに持つ（ADR 0004 §7）。無効な類型は `enforcement = "disabled"` のインスタンスとして表す（適用対象からは外さない。Issue #74 Q2）。
- 適用対象 `local.tag_protection_targets` は visibility のみで絞り、類型では絞らない（ADR 0004 §6）。
- `repositories.<k>.tag_protection` は設けない。現時点でリポ固有値を要する属性が無い（ADR 0004 §4 のリポ固有値の定義「方針として揃える値を持たない」に該当する属性が無い）。必要が生じた場合は、その時点で `variables.tf` へ追加する。

### 2. ADR 0004 帰結の置き換え

ADR 0004 の帰結（L248）は次のように記述していた。

> 管理対象リポの visibility を切り替えると、§6 により Ruleset のインスタンスが create / destroy される。private の Free リポに Ruleset が残らない切り替えの手順は、Ruleset の適用対象を visibility で絞る実装（`local.<concern>_targets`）を入れる Issue で定め、README に置く。

本 ADR は、この「README に置く」を「絞り込みを実装した Issue に記録する」へ置き換える。`tag_protection` は最初から `local.tag_protection_targets` を持つ設定種別だが、visibility 切り替え手順そのものは本 Issue（#74）では記述しない。手順の記述は [#4](https://github.com/kuchita-el/github-config/issues/4)（`branch_protection` 側の適用対象の絞り込みを扱う Issue）の本文・コメントへ既に移設済みである（2026-09-27）。これは、visibility 切り替えの影響が `branch_protection` と `tag_protection` の両方の Ruleset インスタンスに及び、手順を1箇所（絞り込みを実装する Issue）にまとめる方が、複数の設定種別ファイルへ手順を分散させるより保守しやすいためである。

## 根拠

### `enforcement` を類型決定値にし、`distribution` のみ `active` にする

- 判定基準は ADR 0004 §7 と同じ「リポの変更がどこへ届くか」。`distribution`（配布物）のリポだけが、タグを ref として外部の利用者に参照される（`uses: owner/repo@vX.Y.Z` 等）。`infra` はリポの変更が実環境（GitHub 設定等）へ IaC 経由で適用されるが、そのリポ自身のタグを外部利用者が参照する契約は無い。`app` は実行アプリのソースで、利用者は ref で参照しない。
- 現状、`infra`（`github-config`）・`app`（`gachanuma`）はどちらもタグを1つも持たない。`active` にしても実害は無いが、無効類型を `disabled` インスタンスで表すという値の区分（Issue #74 Q2 決定）に忠実に従い、実際に保護が必要な類型だけを `active` にした。
- `local_config` は管理対象リポに現在存在しないが、ADR 0004 §7 の4識別子すべてを表に持つ規則（§7）により行を置き、`disabled` とした。

### 保護対象を release 固有タグ `vX.Y.Z` のみにする

- GitHub 公式ドキュメント「Using immutable releases and tags to manage your action's releases」: 不変版は release 固有タグ（例 `v1.0.0`）で出し、major / minor タグ（`v1`、`v1.1` 等）は最新の互換版へ `git tag -f` / `git push -f` で付け替える、が公式推奨。`dependabot-triage-action` の `release.yml` の現行手順はこれに一致する。
- 全タグを保護すると `v1` の付け替えが拒否され、既存のリリース手順が壊れる（2026-09-27 実態調査）。
- Immutable releases は release に紐づくタグのみを保護し、release 非紐づけのタグには触れない（GitHub 公式ドキュメントは非紐づけタグに言及していない）。Ruleset は release の有無によらず版タグ（`v1.0.0` / `v1.1.0` 等）を覆うため、Immutable releases の補完になる。

### 新規タグ作成を制限しない

- 保護の目的は「公開済みの版タグの内容がすり替わらないこと」であり、新規タグの作成自体は脅威ではない。`creation` ルールを宣言しないことで、GitHub 側の既定（作成は無制限）に従う。

### bypass actor を置かない

- 利用者は所有者本人のみで、bypass を必要とする自動化や共同作業者が存在しない（Issue #74 Q1、所有者判断）。bypass を置くと、その actor 経由での削除・付け替えが保護の外側から可能になり、保護の意味が薄れる。

## 代替案

### 全類型で `enforcement = "active"` にする

類型ごとの分岐が無く、`local.tag_protection_profile_defaults` の値がすべて同じになる。

**採用しなかった理由**: 現状タグを持たないリポ（`gachanuma`・`github-config`）に対しては効果が無い変更であり、類型区分を導入した意味が失われる。将来これらのリポが版タグを外部公開する運用に変わった場合、`local.tag_protection_profile_defaults` の該当行を `active` に変えるだけで対応できるため、先に全類型を `active` にしておく利点が乏しい。

### `repositories.<k>.tag_protection` というリポ固有値を設ける

将来、特定のリポだけ保護対象タグの範囲やルールを変えたくなった場合に備えられる。

**採用しなかった理由**: 現時点でリポ固有値を要する実態が無い（ADR 0004 §4 のリポ固有値の定義に合致する属性が無い）。使わない拡張ポイントを先に用意すると、`variables.tf` の型定義と `README` の Inputs 表が実態の無い属性で膨らむ。必要が生じた時点で追加すれば、state のアドレスも変わらず追加できる。

### `conditions.ref_name.include` を `~ALL` にし、`exclude` で `v1` / `v1.1` 等の floating タグを列挙する

include 側を単純にできる。

**採用しなかった理由**: floating タグの命名は将来増え得る（例: `v2` が追加される、`v1.2` のような minor floating が増える）。そのたびに `exclude` へ追記が要り、追記漏れは保護漏れに直結する。`include` を `vX.Y.Z` 限定にする方式は、floating タグの命名パターンが今後何であっても、リテラル `.` を2個含まない限り自動的に対象外になる。

### bypass actor に所有者（Organization owner 相当のロール）を許す

緊急時に所有者が直接タグを操作できる。

**採用しなかった理由**: 利用者は所有者本人のみであり、bypass を許すと Ruleset による拒否そのものが機能しなくなる（Issue #74 Q1、所有者判断）。誤操作の抑止という Ruleset の目的（AC4）と両立しない。

### private リポにも tag_protection を適用する

visibility を問わず一貫した保護になる。

**採用しなかった理由**: GitHub Free プランでは Ruleset を private リポジトリで使えない（一次確認済み、Issue #74 OUT スコープ）。

## 帰結

- `dependabot-triage-action`・`claude-shared-skills`（`distribution`）は `enforcement = "active"` の tag Ruleset を持つ。`gachanuma`（`app`）・`github-config`（`infra`）は `enforcement = "disabled"` の tag Ruleset を持つ（4リポとも `for_each` で作成されるが、後者2件は無効状態）。
- `dependabot-triage-action` の既存タグ（`v1.0.0` 等）はそのまま残る。apply は Ruleset を新規作成するだけで、既存タグへの遡及的な変更は無い。
- `dependabot-triage-action` の `release.yml` による `v1` の付け替えは、`v1` が `refs/tags/v*.*.*` に一致しないため、引き続き成功する。
- `terraform apply`（HCP Remote 実行）は GitHub App の権限（`Administration: Read & write` / `Metadata: Read`）を変更しない。`github_repository_ruleset` の作成・更新は Administration 権限の範囲内である。
- visibility 切り替え時のタグ Ruleset インスタンスの create/destroy は、branch_protection 側と合わせて [#4](https://github.com/kuchita-el/github-config/issues/4) の手順に従う（決定 §2）。

## ロールバック可能性

- `local.tag_protection_profile_defaults` の値を戻せば、Terraform の apply で GitHub 側の `enforcement` が戻る。state のアドレスは変わらない。
- リポを `local.tag_protection_targets` から外す（= `repositories` から削除するか visibility を private にする）と、そのリポの tag Ruleset は destroy される。
- 区分を変える場合（例: `enforcement` を全リポ共通値へ統合する）も、ADR 0004 §4 のとおり state のアドレスは変わらない。

## 再評価の条件

- `infra`（`github-config`）や `app`（`gachanuma`）が、版タグを外部利用者に ref として公開する運用に変わった場合。該当類型の `enforcement` を `active` に変える。
- 保護対象のタグ命名規則が `vX.Y.Z` 以外（例: プレリリース `v1.0.0-beta`）に広がった場合、`ref_include` パターンの見直しが要る。
- `dependabot-triage-action` 以外の管理対象リポがタグを持つようになり、そのリポの release 運用が `v1` 型の floating タグ付け替えを使わない場合、`ref_exclude` での明示除外方式への切り替えを検討する。
