# ADR 0008: Actions 権限を全リポ共通値で絞り、許可する外部 action をリポ固有値にする

## ステータス

承認（2026-09-26、[#73](https://github.com/kuchita-el/github-config/issues/73)）

## コンテキスト

[#73](https://github.com/kuchita-el/github-config/issues/73) は、管理対象リポの GitHub Actions の権限を本リポの管理下に入れ、被害範囲を限定する。扱う設定は、設定種別 `actions_permissions`（ADR 0004 §3）の2つのリソース型にある。

| リソース型 | 属性 | 意味 |
|---|---|---|
| `github_actions_repository_permissions` | `enabled` | Actions を使えるか |
| `github_actions_repository_permissions` | `allowed_actions` | 使える action の範囲 |
| `github_actions_repository_permissions` | `allowed_actions_config` | `allowed_actions = "selected"` のときに許可する action（GitHub 製の許可 `github_owned_allowed`、検証済みの作成者の一括許可 `verified_allowed`、明示するパターン `patterns_allowed`） |
| `github_actions_repository_permissions` | `sha_pinning_required` | action の参照をコミット SHA の完全な値に限るか |
| `github_workflow_repository_permissions` | `default_workflow_permissions` | ワークフローの `GITHUB_TOKEN` が既定で持つ権限 |
| `github_workflow_repository_permissions` | `can_approve_pull_request_reviews` | GitHub Actions による PR の作成と承認を許すか |

GitHub 製として扱われるのは、`actions` と `github` の組織の action に限られる（GitHub 公式ドキュメント「Managing GitHub Actions settings for a repository」）。以下、それ以外の action を外部 action と呼ぶ。

action を通じた被害には、次の2つの経路がある。

- 許可済みの action の中身がすり替わる。タグやブランチでの参照は付け替えられるので、参照先のリポが乗っ取られると、ワークフローの参照を書き換えなくても別の内容が実行される。
- 見知らぬ action や、名前を似せた action が新しく持ち込まれる。

これとは別に、`permissions:` の宣言を書き忘れたワークフローは、`GITHUB_TOKEN` の既定の権限で動く。

管理対象リポの状況（2026-09-26、本決定による変更の前）は次のとおり。

| リポ | 類型（ADR 0004 §7） | `allowed_actions` | `sha_pinning_required` | `default_workflow_permissions` | `can_approve_pull_request_reviews` | 使っている外部 action |
|---|---|---|---|---|---|---|
| `gachanuma` | `app` | `all` | `false` | `write` | `true` | なし |
| `github-config` | `infra` | `all` | `false` | `read` | `false` | `jdx/mise-action` |
| `claude-shared-skills` | `distribution` | `all` | `false` | `read` | `false` | `jdx/mise-action` |
| `dependabot-triage-action` | `distribution` | `all` | `false` | `read` | `false` | `jdx/mise-action`、`dependabot/fetch-metadata` |

- `enabled` は4リポとも `true` で、4リポともワークフローを実行している。
- ワークフローが参照する action を SHA で固定していたのは `github-config` だけだった。
- 書き込み権限を要するワークフローは、`gachanuma` の `deploy.yml`（`pages: write`、`id-token: write`）と `dependabot-triage-action` の `release.yml`（`contents: write`）で、どちらも `permissions:` で権限を宣言している。
- `GITHUB_TOKEN` で PR を作成・承認するワークフローは無い。`dependabot-triage-action` の `triage.yml` は、PR の操作に個人アクセストークンを使う。`triage.yml` はローカル action（`uses: ./`）も使う。

## 決定

### 1. 値と区分

設定種別 `actions_permissions`（`actions_permissions.tf`）の属性を、ADR 0004 §4 の区分で次のとおり定める。

| リソース型 | 属性 | 区分（ADR 0004 §4） | 値 |
|---|---|---|---|
| `github_actions_repository_permissions` | `enabled` | 全リポ共通値 | `true` |
| `github_actions_repository_permissions` | `allowed_actions` | 全リポ共通値 | `"selected"` |
| `github_actions_repository_permissions` | `allowed_actions_config.github_owned_allowed` | 全リポ共通値 | `true` |
| `github_actions_repository_permissions` | `allowed_actions_config.verified_allowed` | 全リポ共通値 | `false` |
| `github_actions_repository_permissions` | `allowed_actions_config.patterns_allowed` | リポ固有値 | そのリポのワークフローが使う外部 action |
| `github_actions_repository_permissions` | `sha_pinning_required` | 全リポ共通値 | `true` |
| `github_workflow_repository_permissions` | `default_workflow_permissions` | 全リポ共通値 | `"read"` |
| `github_workflow_repository_permissions` | `can_approve_pull_request_reviews` | 全リポ共通値 | `false` |

- 全リポ共通値は `actions_permissions.tf` 冒頭の `local.actions_permissions_preset` に置く。類型決定値にあたる属性は無い。
- `patterns_allowed` は `repositories.<k>.actions_permissions.patterns_allowed` に置き、既定値は空リストとする（ADR 0004 §4・§5）。
- `patterns_allowed` 以外の属性に per-repo のフィールドは設けない。特定のリポで外す必要が生じた場合は、ADR 0004 §4 の例外台帳の手続きに従う。

### 2. 取り込み

変更前の値と決定値の差（全リポの `allowed_actions = "all"` と `sha_pinning_required = false`、`gachanuma` の `default_workflow_permissions = "write"` と `can_approve_pull_request_reviews = true`）は、理由を書けない差（ADR 0004 §4 の由来の無い差）と判定した。ADR 0004 §4「取り込み時の食い違い」に従い、所有者の承認を得て GitHub 側の実値を先に決定値へ変え（2026-09-26、4リポ）、そのうえで CLAUDE.md §2 の手順（`import {}` → plan の no-op の確認 → apply → `import {}` の削除）で取り込む。

### 3. 適用の前提条件

`sha_pinning_required = true` を適用すると、タグで参照している action を使うワークフローは失敗する。このため、次の2つを各リポの PR で行い、そのマージを本決定の適用の前提条件とした（2026-09-26 にすべてマージ済み）。本リポの GitHub App は Contents の権限を持たないので（CLAUDE.md §3）、ワークフローの書き換えは本リポの Terraform からは行えない。

- `gachanuma` / `claude-shared-skills` / `dependabot-triage-action` のワークフローが参照する action を、SHA 参照（`github-config` の既存の書式 `uses: <owner>/<repo>@<40桁の SHA> # <バージョン>`）へ書き換える（[kuchita-el/gachanuma#189](https://github.com/kuchita-el/gachanuma/pull/189)、[kuchita-el/claude-shared-skills#876](https://github.com/kuchita-el/claude-shared-skills/pull/876)、[kuchita-el/dependabot-triage-action#61](https://github.com/kuchita-el/dependabot-triage-action/pull/61)）。
- 4リポに Dependabot の `github-actions` の更新を加える（上の3件と [#91](https://github.com/kuchita-el/github-config/pull/91)）。SHA で固定した参照はタグの更新に追従しないので、以前から SHA で固定していた `github-config` も対象にした。

## 根拠

### `sha_pinning_required`

- SHA 参照に限ると、ワークフローが実行する action の内容は、参照を書いたときのコミットに固定される。参照先のリポが乗っ取られてタグが付け替えられても、許可済みの action の中身はすり替わらない。
- 類型で値を分ける場合（代替案）に比べて、決定 §3 の書き換えが要るリポが2つから3つに増え、今後管理対象に取り込むリポでもワークフローの SHA 固定が要る。所有者はこの手間を受け入れ、全リポで強制することを選んだ（2026-09-26）。
- 固定した SHA の更新は、Dependabot の `github-actions` の更新から PR として受け取る。

### `allowed_actions` と `allowed_actions_config`

- SHA 固定が防ぐのは許可済みの action の中身のすり替えで、見知らぬ action や名前を似せた action の持ち込みは防がない。`selected` にすると、外部 action の追加は本リポの PR（`patterns_allowed` の変更）を通らないとできなくなり、許可範囲がすべて宣言に現れる。外部 action は2種で、追加の頻度は低い。
- `github_owned_allowed = true`: 4リポのワークフローが使う action の大半は GitHub 製（`actions/*`）である。
- `verified_allowed = false`: 検証済みの作成者の範囲は GitHub 側で変わるので、一括で許可すると、宣言から実際の許可範囲を読み取れない。
- `patterns_allowed` をリポ固有値にする: どの外部 action を使うかはリポの構成に由来し、方針として揃える値が無い（ADR 0004 §4 のリポ固有値の定義）。所有者は、1つのリポで使う action を他のリポへ波及させないことを求めた（2026-09-26）。
- ローカル action（`uses: ./`）は、`selected` のもとでも常に許可される（GitHub 公式ドキュメント「Managing GitHub Actions settings for a repository」）。

### `enabled`、`default_workflow_permissions`、`can_approve_pull_request_reviews`

- `enabled = true`: 4リポともワークフローを実行している。
- `default_workflow_permissions = "read"`: 書き込み権限を要するワークフローはどれも `permissions:` で権限を宣言しており、既定値の影響を受けない。既定を read にすると、宣言を書き忘れたワークフローは書き込み権限を持たない。
- `can_approve_pull_request_reviews = false`: `GITHUB_TOKEN` で PR を作成・承認するワークフローは無い。`triage.yml` の PR の操作は個人アクセストークンを使うので、この設定の影響を受けない。

## 代替案

### `sha_pinning_required` を類型決定値にする（`distribution` / `infra` は `true`、`app` / `local_config` は `false`）

決定 §3 の書き換えは `claude-shared-skills` と `dependabot-triage-action` の2リポで済み、ADR 0007 と同じ判断軸（被害がどこへ届くか）で説明できる。`app` のリポでは、許可済みの action の中身のすり替えを防げない。

**採用しなかった理由**: 所有者が、書き換えの手間が増えることを受け入れて、全リポでの強制を選んだ（2026-09-26）。

### `sha_pinning_required` を `false` のままにする

決定 §3 の書き換えが要らない。

**採用しなかった理由**: 許可済みの action の中身のすり替えを防げない。

### `sha_pinning_required = false` で先に適用し、決定 §3 の作業の後で `true` へ切り替える

決定 §3 の作業を待たずに適用できる。

**採用しなかった理由**: 一時的に決定と異なる値が宣言され、PR も1本増える。

### 複合 action の内部参照で拒否された `gachanuma` のために、`sha_pinning_required` を一時的に `false` に戻す

`gachanuma` の `deploy.yml` を、action の更新を待たずに動かせる（帰結）。

**採用しなかった理由**: GitHub 側の値が決定値と食い違い、取り込みの plan が no-op になる前提（決定 §2）が崩れる。

### `gachanuma` の `sha_pinning_required` を例外台帳に登録して `false` にする

**採用しなかった理由**: 上流の action の更新で解消する差であり、恒常的でない。ADR 0004 §4 の登録の要件（差が恒常的である）を満たさない。

### `allowed_actions` を `all` のままにし、SHA 固定だけに頼る

パターンの保守が要らない。

**採用しなかった理由**: 見知らぬ action や名前を似せた action の持ち込みを防げない。

### 検証済みの作成者を一括で許可する（`verified_allowed = true`）

パターンの保守がほぼ要らなくなる。

**採用しなかった理由**: 検証済みの作成者の範囲は GitHub 側で変わり、宣言から実際の許可範囲を読み取れない。

### 許可するパターンを全リポ共通の1つのリストにする

保守する箇所が1か所になる。

**採用しなかった理由**: 1つのリポで使う action が、ほかのリポでも使えるようになる。所有者の方針（1つのリポで使う action を他のリポへ波及させない）に反する。

### `default_workflow_permissions` を類型決定値にし、`app` だけ `write` を許す

`gachanuma` の変更前の値を保てる。

**採用しなかった理由**: `app` のリポに `write` を要する実態が無く、ADR 0004 §4 の「広げない側に倒す」原則にも反する。書き込み権限を要するワークフローは、そのワークフローの `permissions:` で宣言すれば足りる。

### 取り込みで import せず、新規作成として GitHub 側の値を上書きする

**採用しなかった理由**: plan に変更前の値が現れないまま GitHub 側の値が上書きされる。CLAUDE.md §2 は import → plan の no-op の確認 → apply の順を求めている。

### 変更前の実値で import し、その後に Terraform で決定値へ変える

変更がすべて plan を通る。

**採用しなかった理由**: 取り込みの時点で、全リポ共通値を変更前の実値へ寄せることになる。ADR 0004 §4 は、`local.<concern>_preset` を食い違ったリポの実態へ寄せないと定めている。

## 帰結

- 4リポの GitHub 側の値は、取り込みの前に決定値へ変わった。`gachanuma` では、`GITHUB_TOKEN` の既定の権限が read になり、GitHub Actions による PR の作成と承認ができなくなった。
- `sha_pinning_required = true` は、ワークフローの `uses:` だけでなく、ワークフローが使う複合 action の内部の `uses:` にも及ぶ。このため、複合 action は、内部の参照も SHA で固定されている版を選ぶ必要がある。
  - `gachanuma` では、SHA で固定した `actions/upload-pages-artifact`（v3.0.1）が内部で `actions/upload-artifact@v4` をタグで参照しており、`deploy.yml` が「Set up job」で拒否された（2026-09-26、[run 36249590718](https://github.com/kuchita-el/gachanuma/actions/runs/36249590718)、エラーは "All actions must also be pinned to a full-length commit SHA"）。`actions/upload-pages-artifact` は v4.0.0 以降で内部の参照を SHA で固定している。
  - `gachanuma` は、`actions/upload-pages-artifact` を v5.0.0 へ上げる Dependabot の PR（[kuchita-el/gachanuma#194](https://github.com/kuchita-el/gachanuma/pull/194)）をマージして直す。
- ワークフローで新しい外部 action を使うには、そのリポの `patterns_allowed` への追加（本リポへの PR）と、SHA での参照が要る。`dependabot/fetch-metadata` は `dependabot` 組織の action で GitHub 製にあたらないので、使うリポの `patterns_allowed` に書く。
- 書き込み権限を要するワークフローは、そのワークフローの `permissions:` で権限を宣言する必要がある。
- 今後管理対象に取り込むリポは、取り込みの前に、ワークフローの action を SHA 参照へ固定し、使う外部 action を `patterns_allowed` に書く必要がある。
- Actions のランナー上で動く Dependabot の更新ジョブは、リポジトリの Actions ポリシーの検査と Actions の無効化設定を迂回する（GitHub 公式ドキュメント「About Dependabot on GitHub Actions runners」）。
- provider（integrations/github 6.12.1）は `sha_pinning_required` を `GetOk` で判定して API へ送るので、`false` を宣言しても API へ送らない。将来 `false` に戻す場合は、provider の挙動を確かめてから変更する。
- `sha_pinning_required = true` のもとでローカル action（`uses: ./`）が拒否されないかは、2026-09-26 時点で確認できていない（公式ドキュメントに明記が無く、根拠はコミュニティの報告だけ）。`dependabot-triage-action` の `triage.yml` が `uses: ./` を使うので、同ワークフローの実行で確かめる。

## ロールバック可能性

- `local.actions_permissions_preset` と `patterns_allowed` の値を戻せば、Terraform の apply で GitHub 側の値が戻る。state のアドレスは変わらない。ただし `sha_pinning_required` を `false` に戻す場合は、帰結に書いた provider の挙動を確かめる。
- 区分を変える場合（例: `sha_pinning_required` を類型決定値へ移す）も、ADR 0004 §4 のとおり state のアドレスは変わらない。
- 取り込みの前に GitHub 側で変えた値は、本 ADR を戻しても戻らない。戻す場合は、コンテキストの表の変更前の値を使う。
- 決定 §3 の SHA 参照と Dependabot の更新は各リポのファイルにあり、本リポの変更では戻らない。

## 再評価の条件

- `sha_pinning_required = true` のもとで、ローカル action（`uses: ./`）が拒否されると分かった場合。
- GitHub Actions による PR の作成・承認を要するワークフローが、管理対象リポに必要になった場合（類型の見直しか、ADR 0004 §4 の例外台帳で扱う）。
- 外部 action の追加が頻繁になり、`patterns_allowed` の保守の手間が、持ち込みを防ぐ効果に見合わなくなった場合。
