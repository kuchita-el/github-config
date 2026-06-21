# CLAUDE.md（プロジェクトスコープ）

本ファイルの主読者は Claude（LLM）。本リポで Claude が逸脱してはならない IaC 特有のガードレールのみを記す。人間向けのセットアップ手順・設計背景は `README.md` および `docs/adr/` を参照すること。

ユーザー共通ルール（言語・コミュニケーションスタイル・Bash / Git 規約等）は `~/.claude/CLAUDE.md` を併用する。本ファイルはそれを上書きせず、IaC 固有のガードレールのみで補完する。

## 1. HCP リモート実行が SoT、ローカル apply は禁止

`terraform plan` / `terraform apply` は HCP Terraform Workspace（organization `kuchita-el` / workspace `github-config`）の Remote 実行で完結させること。`versions.tf` の `cloud {}` ブロックを外したり、別の `backend` に差し替えたりしてローカル state で apply してはならない。

違反すると HCP 上の正規 state と乖離したローカル state が生成され、以降の Remote 実行と drift し復旧コストが極めて高い。

`terraform fmt` / `terraform validate` はローカルで実行してよい（state を生成しないため）。

## 2. 既存リポを管理対象に入れる際は `import` → `plan` no-op 確認必須

既に GitHub 側で稼働中のリポ・Ruleset・Repository 設定を `terraform.tfvars` の `repositories` に追加する場合、必ず以下の順序で進めること。

1. `import {}` ブロックを一時的に追加する（Remote 実行では CLI の `terraform import` コマンドは使えないため、config-driven import を使う）
2. `terraform plan` が `0 to add, 0 to change, 0 to destroy`（import のみ）になるまで `terraform.tfvars` / `branch_protection.tf` を実態へ寄せる
3. no-op を確認できたら `terraform apply` で state に取り込む
4. `import {}` ブロックを削除し、再 `plan` が `No changes` のままであることを確認する

import → plan no-op を経由せずに apply すると、既存設定を Terraform 側の宣言値で上書き新規作成する事故になる。詳細手順は `README.md` の「既存リポの取り込み（import）」節を参照。

## 3. App permission scope の拡張は別 Issue が必要

本リポの GitHub App は **権限: Administration: Read & write / Metadata: Read のみ** に限定されている（`providers.tf` の `app_auth {}` 経由で HCP の sensitive env var を読む構成）。これを超える Terraform リソース（例: Issues 操作・Contents 書き込み・Organization 単位設定）を追加するコードを書く前に、ユーザーへ確認し、**別 Issue で App permission scope の拡張**を行うこと。

App PEM 漏洩時のブラストradius は permission scope で決まる。Contents 権限を付与しない方針はコード改竄を構造的に遮断する設計判断であり、利便性のために緩めない。

なお、**インストールスコープ（Selected repositories）への管理対象リポ追加は通常運用**であり、§2 の import フローと同一 Issue 内で実施する。App 設定画面での追加操作はユーザーがブラウザで行う必要があるため、Claude は対象リポ名を明示してユーザーへ依頼すること。

## 4. `terraform.tfvars` は公開値のみ（秘密は HCP workspace 環境変数）

`terraform.tfvars` には管理対象リポ名・status check contexts・integration ID 等の公開値のみを記述する。GitHub App の `GITHUB_APP_ID` / `GITHUB_APP_INSTALLATION_ID` / `GITHUB_APP_PEM_FILE` および将来追加する任意の秘密値は、HCP Workspace の **Environment variable** に **Sensitive: ON** で登録し、`terraform.tfvars` / `*.auto.tfvars` / コミット対象ファイルには絶対に書かないこと。

違反すると Git 履歴に秘密が永続化し、push protection をすり抜けた場合は App PEM の再発行と全 env var 差し替えが必要になる。`.gitignore` で `*.pem` / `secrets.tfvars` / `*.auto.tfvars` は除外済だが、それに頼らず「秘密は tfvars に書かない」を原則とする。

## 5. ADR / 実装プラン等の配置場所

新規ドキュメントを作成する際は以下の配置に従うこと。ルート直下や任意ディレクトリに散乱させない。

| 種別 | 配置 | Git 追跡 |
|---|---|---|
| 設計判断記録（ADR） | `docs/adr/NNNN-<slug>.md`（連番） | tracked |
| Issue 実装プラン | `docs/plans/issue-<番号>.md` | **untracked**（`docs/plans/.gitignore` でコミット対象外、PR #40） |
| spike / 調査ノート | `docs/spike/<slug>.md` | tracked |
| サブエージェント定義 | `docs/agents/<name>/` | tracked |
| hook スクリプト | `.claude/hooks/<name>.sh` | tracked |

`docs/plans/` 配下は `.gitignore` でコミット対象外であり、リポには `docs/plans/.gitignore` のみが含まれる。プランファイルはローカル参照専用で、`git add` しても無視される。

配置を統一することで、Claude も人間も目的別に参照先を一意に特定できる。散在させると関連文書を新規セッションで見落とし、ADR と矛盾する判断を独立に下すリスクが上がる。
