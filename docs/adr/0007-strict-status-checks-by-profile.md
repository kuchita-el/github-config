# ADR 0007: 既定ブランチ最新化要求（strict）を類型決定値にする

## ステータス

承認（2026-09-26、[#71](https://github.com/kuchita-el/github-config/issues/71)）

## コンテキスト

Ruleset の `required_status_checks` ルールの `strict_required_status_checks_policy`（GitHub UI の「Require branches to be up to date before merging」。以下 strict）は、`local.branch_protection_preset` で全リポ共通値 `true` として宣言されていた。strict が有効だと、PR ブランチが既定ブランチの最新を取り込んでいない限り、コンフリクトが無くてもマージできない。

Dependabot の PR を続けてマージする運用では、1件マージするたびに残りの PR が既定ブランチに対して遅れ、そのたびに既定ブランチの取り込み（Update branch）と CI の再実行が要る。一方で strict は、各 PR の CI が最新の既定ブランチを土台にした結果であることを保証する。無効にすると、単独では通る2つの PR が組み合わさって壊れる意味的衝突を、マージ前に検出できなくなる。

手間を省く手段として、次を一次情報で確認した。

- **merge queue**: organization が所有する public リポジトリでだけ使える（github/docs `data/reusables/gated-features/merge-queue.md`）。管理対象リポの owner `kuchita-el` は User アカウントなので使えない。
- **Dependabot の自動 rebase**: Dependabot が PR を rebase するのは、スケジュール実行・PR の再オープン・target-branch の変更・コンフリクトの発生のときに限られる（github/docs `content/code-security/reference/supply-chain-security/dependabot-options-reference.md` の `rebase-strategy` 節）。コンフリクトの無い遅れでは rebase されないので、strict が有効だと毎回手動の Update branch が要る。

管理対象リポの状況（2026-09-26 時点）は次のとおり。

| リポ | 類型（ADR 0004 §7） | required status checks | 直近約4か月の Dependabot PR のマージ件数 |
|---|---|---|---|
| `gachanuma` | `app` | あり | 37件（42分の間に3件を続けてマージした例あり） |
| `github-config` | `infra` | あり | 0件 |
| `claude-shared-skills` | `distribution` | なし（CI が無い） | 0件 |
| `dependabot-triage-action` | `distribution` | あり | 1件 |

CI の所要時間は数十秒〜90秒である。`claude-shared-skills` には `required_status_checks` ルール自体が無いので、strict の値はどちらでも効かない。

## 決定

strict を ADR 0004 §4 の**類型決定値**とし、類型ごとに次の値にする。

| 類型 | `strict_required_status_checks_policy` |
|---|---|
| `distribution` | `true` |
| `infra` | `true` |
| `app` | `false` |
| `local_config` | `true` |

- 値は `branch_protection.tf` 冒頭の `local.branch_protection_profile_defaults` に置き、`local.branch_protection_preset` から strict を外す。resource は `local.branch_protection_profile_defaults[each.value.profile].strict_required_status_checks_policy` を直接参照する（ADR 0004 §4・§5・§7）。
- per-repo で strict を変えるフィールドは設けない。特定のリポで外す必要が生じた場合は、ADR 0004 §4 の例外台帳の手続きに従う。

## 根拠

- **判断軸は、意味的衝突の被害がどこへ届くか**とする。これは ADR 0004 §7 の類型の判定基準（リポの変更がどこへ届くか）と同じ軸であり、strict の値が類型で決まるのはこのためである。
- **app（false）**: 意味的衝突がマージ前の CI をすり抜けても、main の CI で事後に検出して修正でき、実環境や利用者へ直接は届かない。一方で、Dependabot のマージ実績が集中しているのは app の `gachanuma` であり、strict の手間が定常的に生じている。
- **infra（true）**: main へのマージが HCP Terraform の apply に直結し、意味的衝突がそのまま実環境へ適用される。
- **distribution（true）**: 利用者が ref で参照するため、main に入った衝突が利用者の環境へ届き、所有者の側では回収できない（ADR 0004 §7 の根拠と同じ）。
- **local_config（true）**: 現時点で該当する管理対象リポは無い。ADR 0004 §7 の表は4つの識別子すべてに値を要し、事後検出の仕組み（main の CI とデプロイの分離）が類型として保証されないため、安全側の `true` を置く。値を変えるのは、該当リポを取り込む Issue で実態を見てからとする。
- merge queue は owner が User アカウントなので使えず、Dependabot の自動 rebase はコンフリクトの無い遅れを解消しない。strict を保ったまま手間を省く GitHub 側の機能は、現状の管理対象には無い。

## 代替案

### 案 A: 全リポで `true` を維持する

**採用しなかった理由**: app の `gachanuma` で、Dependabot の PR を続けてマージするたびに Update branch と CI の再実行を要する定常的な手間が残る。app では意味的衝突を main の CI で事後に検出でき、この手間に見合う検出能力の差が無い。

### 案 B: 全リポで `false` にする

**採用しなかった理由**: infra と distribution では、意味的衝突がマージ前に検出されないまま実環境や利用者へ届く。

### 案 C（本決定）: 類型決定値にする（app のみ `false`）

採用。

### 案 D: Dependabot の `groups` を広げて PR を束ねる

**採用しなかった理由**: `.github/dependabot.yml` は各リポの Contents にあり、本リポの GitHub App の権限（Administration / Metadata）の外にある。各リポが独自に採ることは妨げないが、本リポが決める事項ではない。本決定と併用してよい。

### 案 E: merge queue を使う

**採用しなかった理由**: organization 所有の public リポジトリに限られ、User アカウント所有の管理対象リポでは使えない。

### 案 F: 全リポ共通値 `true` のまま、`gachanuma` だけを例外台帳に登録して `false` にする

**採用しなかった理由**: 差の理由（事後検出でき、実環境・利用者へ直接届かない）は `gachanuma` 固有ではなく app という類型の性質である。ADR 0004 §4 は、類型決定値の見直しで表せる差を例外台帳に登録しないと定めている。

## 帰結

- HCP Terraform の plan は、`gachanuma` の Ruleset で strict が `true` から `false` へ変わる in-place update の1件だけになる。他のリポは値が変わらず、`github_repository` にも変化は無い。
- `gachanuma` では、既定ブランチに対して遅れていてもコンフリクトの無い PR を、取り込み無しでマージできるようになる。
- 今後 app に分類されるリポは、取り込み時に strict が `false` になる。既存の Ruleset を取り込む場合、実値が `true` なら ADR 0004 §4「取り込み時の食い違い」に従う。
- `branch_protection.tf` に `local.branch_protection_profile_defaults` が初めて置かれ、`profile` が値の解決に使われ始める。

## ロールバック可能性

- `local.branch_protection_profile_defaults.app.strict_required_status_checks_policy` を `true` に戻せば、該当リポの Ruleset が in-place update で戻る。state のアドレスは変わらない。
- strict を全リポ共通値へ戻す場合も、値を `local.branch_protection_preset` へ移して resource の参照先を替えるだけで、state のアドレスは変わらない（ADR 0004 §4）。

## 再評価の条件

- 管理対象リポの owner が organization へ移り、merge queue が使えるようになった場合。
- Dependabot が、コンフリクトの無い遅れでも PR を自動で rebase するようになった場合。
- app のリポで、strict が無いことによる意味的衝突が main に入り、事後の修正で吸収できない被害が生じた場合。
- `local_config` の管理対象リポを取り込む場合（その Issue で値を見直す）。
