# ADR 0005: 管理対象リポジトリのマージ方式を squash に統一する

## ステータス

承認（2026-09-26、[#70](https://github.com/kuchita-el/github-config/issues/70)）

影響節の「既存の per-repo override 機構は変更しないため、個別リポジトリで本方針から外す余地は残る」は [ADR 0004](0004-terraform-module-structure-policy.md)（提案中、[#32](https://github.com/kuchita-el/github-config/issues/32)）が置き換える。`allowed_merge_methods` は ADR 0004 の全リポ共通値にあたり、個別リポジトリで外すには ADR 0004 の例外台帳への登録を要する。

## コンテキスト

コーディングエージェントが PR を起票する運用が常態になり、マージ方式の選択が持つ意味が変わった。エージェントは試行錯誤のコミット（レビュー指摘対応・typo・テスト追加）を人間より細かく速く積むため、それらが既定ブランチへそのまま流入すると履歴のノイズになる。一方で PR 単位に潰せば、1 コミット = 1 タスクとなり revert / bisect の単位が明快になる。潰した結果が「revert 単位として粗すぎる」と感じたときは、それ自体が PR を小さく保てていないシグナルとして機能する。

この方針は決まっておらず、さらに2つの管理層が矛盾していた。

- `branch_protection.tf` の `branch_protection_preset` は `allowed_merge_methods = ["rebase", "merge"]` を宣言しており、Ruleset レベルで squash を禁止している。
- リポジトリレベルのマージ設定（`allow_squash_merge` 等）は Terraform 管理外で、GitHub 既定のまま 3 方式とも許可されている。

この状態では、リポジトリレベルで squash を許可しても Ruleset がブロックするため機能しない。[#17](https://github.com/kuchita-el/github-config/issues/17) はリポジトリレベル側の属性を扱うが、Ruleset 側との整合には触れていないため、#17 単独を実装しても矛盾は解消しない。

## 決定

`local.branch_protection_preset.allowed_merge_methods` を `["squash"]` に統一する。

## 根拠

- **試行錯誤コミットの吸収**: エージェントが積む細かいコミットを PR 単位へ潰すことで、既定ブランチの履歴ノイズを避けられる。
- **revert / bisect 単位の明快化**: 1 コミット = 1 PR となり、revert 対象が常に PR 単位で確定する。
- **粗さのシグナル化**: squash 結果が「revert 単位として粗すぎる」と感じられた場合、それは PR を小さく保てていないことの表面化であり、運用上の気づきとして機能する。

## 代替案

### 案 A: 現状維持（`["rebase", "merge"]`）

試行錯誤コミットが既定ブランチにそのまま流入し、履歴のノイズになる。revert / bisect の単位が PR 単位に揃わない。

**採用しなかった理由**: 決定で採用した根拠がそのまま不成立になるため。

### 案 B: 全許可（squash + merge + rebase、GitHub 既定）

方式選択の余地を残すことで、狙いである「履歴の粒度を PR 単位に揃える」効果が薄れる。

**採用しなかった理由**: 選択の余地を残すこと自体が、統一によって得たい効果（履歴粒度の一貫性）を打ち消す。

### 案 C: squash + rebase 併用

rebase を残すと、PR が大きすぎる場合に revert 単位が粗くなるシグナルが失われる（Issue #70 本文「参考: 実現の手がかり」参照）。

**採用しなかった理由**: rebase でマージされた PR は複数コミットのまま既定ブランチへ入るため、squash 単独で得られる「粗さの気づき」効果が一部の PR で無効化される。

### 案 D: squash + merge 併用

上記案 C と同じ理由に加え、マージコミットが生成されるため squash の狙い（コミット履歴の単純化）と矛盾する。

**採用しなかった理由**: マージコミットの発生自体が、履歴を単純化する目的と直接矛盾する。

### 案 E: 線形履歴の強制（`required_linear_history`）を追加する

Issue #70 のコメント（2026-09-26）での検討の結果、見送りとした。squash 統一下では PR 経由のマージはマージコミットを生まず実質的に線形になるため、強制が効くのは bypass による直接 push に限られ、実益が薄い。

**採用しなかった理由**: squash 統一という決定自体が既に実質的な線形性をもたらしており、`required_linear_history` を追加で強制する対象（bypass 経由の直接 push）は限定的で、追加のルールを持つコストに見合わない。

## 影響

- 管理対象4リポジトリ全件（`gachanuma` / `github-config` / `claude-shared-skills` / `dependabot-triage-action`）に及ぶ。
- `github-config` 自身が管理対象に含まれるため、本 PR の Apply 完了以降は本リポの PR（本 Issue を実装する PR 自身は除く。既存オープン PR [#19](https://github.com/kuchita-el/github-config/pull/19) を含む）も squash でしかマージできなくなる。
- 既存の per-repo override 機構（`variables.tf` の `allowed_merge_methods` optional 属性）は変更しないため、個別リポジトリで本方針から外す余地は残る。
- リポジトリレベルのマージ設定（`allow_squash_merge` 等）は本 Issue のスコープ外であり Terraform 管理外のまま残る。両層が揃うのは [#17](https://github.com/kuchita-el/github-config/issues/17) の完了時点。

### 付録（事前確認結果）

管理対象4リポジトリのリポジトリレベル `allow_*_merge` 属性、および現行 Ruleset の `allowed_merge_methods` を、取得日時 2026-09-26T03:20:52Z（`gh api repos/kuchita-el/<repo>`）および同日時点（`gh api repos/kuchita-el/<repo>/rulesets/<id>`）で確認した。drift はなく、現行 Ruleset は preset 記述（`["rebase", "merge"]`）と一致している。

| リポジトリ | `allow_squash_merge` | `allow_merge_commit` | `allow_rebase_merge` | Ruleset `allowed_merge_methods` |
|---|---|---|---|---|
| `gachanuma` | `true` | `true` | `true` | `["rebase", "merge"]` |
| `github-config` | `true` | `true` | `true` | `["rebase", "merge"]` |
| `claude-shared-skills` | `true` | `true` | `true` | `["rebase", "merge"]` |
| `dependabot-triage-action` | `true` | `true` | `true` | `["rebase", "merge"]` |

取得コマンド:

```bash
gh api repos/kuchita-el/<repo> --jq '{allow_squash_merge, allow_merge_commit, allow_rebase_merge}'
gh api repos/kuchita-el/<repo>/rulesets/<id> --jq '{id, name, rules: [.rules[] | select(.type=="pull_request") | .parameters.allowed_merge_methods]}'
```

## ロールバック可能性

`allowed_merge_methods` の値を `["rebase", "merge"]` に戻すだけで切り替え可能。Ruleset リソース自体の再作成は発生しないため state は不変であり、`plan` が再び差分ゼロになる。コストは低い。
