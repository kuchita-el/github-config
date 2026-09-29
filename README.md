# github-config

個人アカウントの GitHub リポジトリ設定（branch protection 等）を **Terraform で宣言的に管理**する基盤。

設定を Single Source of Truth として版管理し、全リポへ統一的に投入・更新する。冪等・適用前確認（`terraform plan`）・drift 検出は Terraform が標準提供する。

- **state / 実行**: HCP Terraform（旧 Terraform Cloud）無料tier、Remote 実行
- **provider**: `integrations/github` `~> 6.0`
- **認証**: GitHub App installation（Selected repositories、権限は Administration: Read and write + Metadata: Read のみ）
- **最初の設定種別**: branch protection（Repository Ruleset）

---

## アーキテクチャ

```
terraform.tfvars (管理対象リポ + リポ固有値)
        │
        ▼
branch_protection.tf  全リポ共通値 local.branch_protection_preset と
                      リポ固有値 repositories.<k>.branch_protection.* を直接参照
                      github_repository_ruleset を local.branch_protection_targets
                      （visibility=public で絞込）で for_each 展開
repository.tf         全リポ共通値 local.repository_preset と
                      リポ固有値 repositories.<k>.repository.* を直接参照
                      github_repository / github_branch_default を for_each で
                      リポ単位に展開。security_and_analysis は visibility=public
                      のリポにのみ dynamic ブロックで出す（設計仕様書 §6）
actions_permissions.tf 全リポ共通値 local.actions_permissions_preset と
                      リポ固有値 repositories.<k>.actions_permissions.* を直接参照
                      github_actions_repository_permissions /
                      github_workflow_repository_permissions を for_each で
                      リポ単位に展開
vulnerability_alerts.tf 全リポ共通値 local.vulnerability_alerts_preset を直接参照
                      github_repository_vulnerability_alerts を var.repositories
                      （visibility 不問、設計仕様書 §8）で for_each 展開
dependabot_security_updates.tf 全リポ共通値
                      local.dependabot_security_updates_preset を直接参照
                      github_repository_dependabot_security_updates を
                      var.repositories（visibility 不問、設計仕様書 §8）で for_each 展開
tag_protection.tf      全リポ共通値 local.tag_protection_preset と
                      類型決定値 local.tag_protection_profile_defaults を直接参照
                      github_repository_ruleset を local.tag_protection_targets
                      （visibility=public で絞込）で for_each 展開
        │
        ▼
GitHub API (App 認証)        state ⇄ HCP Terraform workspace
```

| ファイル | 役割 |
|---|---|
| `terraform.tf` | Terraform / provider バージョン固定、HCP `cloud {}` バックエンド |
| `providers.tf` | GitHub provider（owner + 空 `app_auth {}`。App 認証情報は環境変数） |
| `variables.tf` | `github_owner`、`repositories`（管理対象 + リポ固有値）の型定義 |
| `branch_protection.tf` | `local.branch_protection_profile_defaults`（類型決定値、[設計仕様書](docs/design/terraform-structure.md) §8）+ `local.branch_protection_preset`（全リポ共通値）+ `local.branch_protection_targets`（visibility=public で絞込、[設計仕様書](docs/design/terraform-structure.md) §6）+ Ruleset リソース（`for_each` 展開）。類型決定値は `repositories.<k>.profile` をキーに、リポ固有値は `repositories.<k>.branch_protection.*` を直接参照 |
| `repository.tf` | `local.repository_preset`（全リポ共通値。既定ブランチ名、`secret_scanning` / `secret_scanning_push_protection` の status を含む、[設計仕様書](docs/design/terraform-structure.md) §8）+ `github_repository` リソース・`github_branch_default` リソース（いずれも `for_each` 展開）。リポ固有値は `repositories.<k>.repository.*` を直接参照 + `lifecycle.ignore_changes`。`security_and_analysis` ブロックは visibility=public のリポにのみ `dynamic` で送る（GitHub Free では private リポで有効化不可、[設計仕様書](docs/design/terraform-structure.md) §6） |
| `actions_permissions.tf` | `local.actions_permissions_preset`（全リポ共通値。類型決定値なし）+ `github_actions_repository_permissions` リソース・`github_workflow_repository_permissions` リソース（いずれも `for_each` 展開）。リポ固有値（`patterns_allowed`）は `repositories.<k>.actions_permissions.*` を直接参照 |
| `vulnerability_alerts.tf` | `local.vulnerability_alerts_preset`（全リポ共通値。類型決定値・リポ固有値なし、[設計仕様書](docs/design/terraform-structure.md) §8）+ `github_repository_vulnerability_alerts` リソース（`var.repositories` を visibility 不問で `for_each` 展開） |
| `dependabot_security_updates.tf` | `local.dependabot_security_updates_preset`（全リポ共通値。類型決定値・リポ固有値なし、[設計仕様書](docs/design/terraform-structure.md) §8）+ `github_repository_dependabot_security_updates` リソース（`var.repositories` を visibility 不問で `for_each` 展開） |
| `tag_protection.tf` | `local.tag_protection_profile_defaults`（類型決定値、[設計仕様書](docs/design/terraform-structure.md) §8）+ `local.tag_protection_preset`（全リポ共通値）+ `local.tag_protection_targets`（visibility=public で絞込、[設計仕様書](docs/design/terraform-structure.md) §6）+ Ruleset リソース（`for_each` 展開）。リポ固有値は無し（`repositories.<k>.tag_protection` は導入していない） |
| `terraform.tfvars` | 管理対象リポの実データ（秘密なし、コミット対象） |
| `docs/adr/` | 設計判断記録（ADR）。リソース構造・属性方針等の重要決定を `NNNN-<slug>.md` 形式で残す |

### 設計思想（重要）

**TF 管理下の設定は「あるべき状態」を強制する。** GitHub UI で手動変更しても、次回 `terraform plan` で drift として検出され、`apply` で宣言値へ revert される。

- リポ個別の値は UI で変えず、**`terraform.tfvars` に書く**。書けるのはリポ固有値と [設計仕様書](docs/design/terraform-structure.md) §4 の例外台帳にそのリポを使用リポとして登録した属性だけで、それ以外は類型または全リポ共通の値に従う（設計仕様書 §4）。
- 既存リポを管理対象に入れるときは、**必ず `import` → `plan` で no-op 確認**してから `apply` する（いきなり apply すると既存設定を上書き新規作成する事故になる）。

---

## 変数

`variables.tf` の `description` を `terraform-docs` で自動反映する（`.claude/skills/tf-docs`）。手動転記しない。

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | 管理対象リポジトリが属する GitHub アカウント（owner）。例: 自分のユーザー名。 | `string` | n/a | yes |
| <a name="input_repositories"></a> [repositories](#input\_repositories) | 管理対象リポジトリ。キーはリポジトリ名。<br/><br/>各エントリにはリポ固有値だけを書く（terraform-structure.md §4・§5）。直下には visibility と<br/>profile（いずれも必須、既定値なし）だけを置き、それ以外のリポ固有値は設定種別名の<br/>キー（repository / branch\_protection / actions\_permissions）の下に入れ子にする。設定種別のキーは、その<br/>設定種別にリポ固有値があるリポだけが書き、省略すると値の無い状態（null / 空リスト）になる。<br/><br/>全リポ共通値は各設定種別ファイル冒頭の local.<concern>\_preset<br/>（repository.tf の repository\_preset、branch\_protection.tf の branch\_protection\_preset、<br/>actions\_permissions.tf の actions\_permissions\_preset）に置き、<br/>ここでは変えられない。類型決定値は各設定種別ファイル冒頭の<br/>local.<concern>\_profile\_defaults（branch\_protection.tf の<br/>branch\_protection\_profile\_defaults）に置き、各リポの profile（類型プロファイル、<br/>terraform-structure.md §7）で引く。これもここでは変えられない。特定のリポで<br/>全リポ共通値・類型決定値から外すには、terraform-structure.md §4 の例外台帳への<br/>登録を要する。 | <pre>map(object({<br/>    # リポジトリの公開範囲（必須）。全リポジトリで明示宣言を強制するため optional にしない<br/>    # （terraform-structure.md §6）。既定値の編集で全リポジトリの公開範囲が変わる事故を防ぐため、<br/>    # default を持たせない。<br/>    visibility = string<br/><br/>    # リポジトリの類型プロファイル（必須、terraform-structure.md §7）。判定基準は「リポの変更がどこへ届くか」。<br/>    # 既定値は持たせない（付け忘れを構造的に防ぐ。visibility と同じ扱い）。<br/>    # 類型決定値の表（local.<concern>_profile_defaults）を引くキーになる。<br/>    profile = string<br/><br/>    # github_repository（repository.tf）のリポ固有値。値を持たないリポは省略できる。<br/>    repository = optional(object({<br/>      # アーカイブ済みか。null は未アーカイブ（provider の既定値 false）として扱われる。<br/>      # lifecycle.ignore_changes の対象で、drift は plan に出ない。<br/>      archived = optional(bool)<br/>      # リポジトリの説明文。null は説明文なし。<br/>      description = optional(string)<br/>      # リポジトリのホームページ URL（About 欄の Website）。null はホームページなし。<br/>      homepage_url = optional(string)<br/>      # リポジトリの topics（terraform-structure.md §8: github_repository.topics 属性で管理する）。<br/>      # 空リストは topics なし。英小文字・数字・ハイフンのみ、50 文字以内（provider の検証）。<br/>      topics = optional(set(string), [])<br/>    }), {})<br/><br/>    # github_repository_ruleset.branch_protection（branch_protection.tf）のリポ固有値。<br/>    # 値を持たないリポは省略できる。<br/>    branch_protection = optional(object({<br/>      # このリポジトリの必須ステータスチェックのコンテキスト（CI ジョブ名）。<br/>      # 空リストの場合、このリポジトリには required_status_checks ルールを作らない。<br/>      status_check_contexts = optional(list(string), [])<br/>      # 上記チェックを生成する GitHub App の ID（15368 = GitHub Actions）。<br/>      # status_check_contexts が空でない場合は必須。<br/>      status_check_integration_id = optional(number)<br/>    }), {})<br/><br/>    # github_actions_repository_permissions（actions_permissions.tf）のリポ固有値。<br/>    # 値を持たないリポは省略できる。<br/>    actions_permissions = optional(object({<br/>      # このリポジトリのワークフローが使ってよい action の追加許可パターン<br/>      # （allowed_actions_config.patterns_allowed）。github_owned_allowed /<br/>      # verified_allowed で許可される範囲を超えて使う action だけを書く<br/>      # （例: "jdx/mise-action@*"）。空リストは追加許可なし。<br/>      patterns_allowed = optional(set(string), [])<br/>    }), {})<br/>  }))</pre> | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

---

## 初期セットアップ（HCP 未経験者向け）

> 一度だけ実施。以降の運用は「運用フロー」へ。

### 1. Terraform CLI のインストール

```bash
# 例: tfenv 経由（推奨）または公式手順
# https://developer.hashicorp.com/terraform/install
terraform version   # >= 1.6 であること
```

`mise` 利用時はリポルートで `mise install` を実行すれば `terraform` / `tflint` 双方が `mise.toml` の固定バージョンで取得できる。`tflint` は v0.51 以降 `terraform-linters/tflint-ruleset-terraform` を bundled しているため、リポルートの `.tflint.hcl` 設定のみで動作し、追加の `tflint --init` は不要（カスタム plugin を増やした場合のみ実施）。

### 2. HCP Terraform アカウント・組織・ワークスペースの作成

1. https://app.terraform.io にサインアップ（無料tier）。
2. **Organization** を作成（名前は任意。例: `kuchita-el`）。← この名前を後で `terraform.tf` に記入する。
3. **Workspace** を作成:
   - Type: **CLI-Driven Workflow** を選択
   - 名前: `github-config`（`terraform.tf` の `workspaces { name = ... }` と一致させる）
4. 作成した Workspace の **Settings → General** で **Execution Mode = Remote** を確認（既定で Remote）。

### 3. GitHub App の作成・インストール・秘密鍵の生成

> PAT ではなく GitHub App で認証する。期限管理・人依存を避け、権限を最小化するため。

1. GitHub → Settings → Developer settings → **GitHub Apps** → New GitHub App。
   - 名前は任意（例: `kuchita-el-github-config`）。Homepage URL はダミー可。Webhook は **Active を OFF**。
2. **Permissions → Repository permissions**:
   - **Administration: Read and write**（Ruleset 操作に必須）
   - **Metadata: Read**（他権限付与時に自動で必須化される）
   - 他は **No access**。特に **Contents は付与しない**（漏洩時もコード改竄を構造的に遮断）。
3. App を作成後、**Install App** で自分のアカウントにインストール。
   - **Only select repositories** を選び、`terraform.tfvars` の `repositories` に載せた管理対象リポのみを指定。クレデンシャル到達範囲を管理対象セットに一致させる。新しい管理対象リポを追加したら、この画面でインストールスコープにも同じリポを追加する（CLAUDE.md §3）。
4. App 設定画面で **App ID** を控える。**Private keys → Generate a private key** で PEM をダウンロードして控える。
5. インストール画面の URL（`.../installations/<数字>`）等から **Installation ID** を控える。

控える3点: **App ID** / **Installation ID** / **PEM の内容**。PEM はリポジトリに置かない（`.gitignore` で `*.pem` を除外済、push protection も有効）。

### 4. App 認証情報を HCP Workspace の秘密変数として登録

Workspace → **Variables** → 以下3つを **Environment variable** で追加（いずれも **Sensitive: ON**）:

| Key | Value |
|---|---|
| `GITHUB_APP_ID` | 手順3の App ID |
| `GITHUB_APP_INSTALLATION_ID` | 手順3の Installation ID |
| `GITHUB_APP_PEM_FILE` | 手順3の PEM の**内容**（パスではない。複数行は `\n` で表現可） |

> Remote 実行では HCP がこれらを provider に注入し、provider が短命の installation token を生成する。`providers.tf` の空 `app_auth {}` ブロックがこの env var 読み取りを有効化する。ローカルに秘密を置かない。

### 5. organization 名を記入

`terraform.tf` の `organization = "REPLACE_WITH_YOUR_HCP_ORG"` を手順2で作った組織名に置換してコミットする。

### 6. 初期化

```bash
terraform login        # HCP Terraform へのログイン（ブラウザでトークン発行）
terraform init         # provider 取得 + HCP workspace 接続 + .terraform.lock.hcl 生成
git add .terraform.lock.hcl && git commit -m "Add provider lock file"
terraform validate     # 構文・スキーマ検証
```

---

## 既存リポの取り込み（import）

> 既に Ruleset が存在するリポを管理下に入れる手順。**新規作成（上書き）事故を防ぐ核心。**

> ⚠️ **Remote 実行では CLI の `terraform import` コマンドは使えない。** config-driven
> import（`import {}` ブロック）を使い、plan/apply 経由で取り込む。

1. 取り込みの前に、対象リポの GitHub 側の実値を調べる。類型決定値・全リポ共通値と食い違う属性は、
   [設計仕様書](docs/design/terraform-structure.md) §4「取り込み時の食い違い」に従って (a)/(b)/(c) に振り分け、所有者へ提示する。
   - **(a) 実値の変更**: import の PR より前に所有者の承認を得て GitHub 側の実値を変える。変更前の値は取り込みの Issue に記録する。
   - **(c) 方針値の見直し**: import より前の別 PR で方針値を変える。その PR の plan で他リポに生じる change を確認し、所有者の承認を得て apply する。
   - **(b) 例外台帳への登録**: 所有者の承認を得て、import の PR の中で per-repo のフィールドと例外台帳の行を追加する。
   - import の PR の plan は `0 to change` を保つ。
2. 対象リポの既存 Ruleset ID を調べる:
   ```bash
   gh api repos/<owner>/<repo>/rulesets --jq '.[] | {id, name}'
   ```
3. `terraform.tfvars` の `repositories` に対象リポを追加（リポ固有値〔status check contexts など〕を実態に合わせる）。
4. import ブロックを一時的に追加する（`import.tf` を作成。アドレスは `for_each` キー＝リポ名）:
   ```hcl
   import {
     to = github_repository_ruleset.branch_protection["<repo>"]
     id = "<repo>:<ruleset_id>"
   }
   # 例: id = "gachanuma:16492768"
   ```
   import ID の形はリソース型ごとに異なる。`github_repository.this`、
   `github_branch_default.repository`、`github_actions_repository_permissions.actions_permissions`、
   `github_workflow_repository_permissions.actions_permissions`、
   `github_repository_vulnerability_alerts.vulnerability_alerts`、
   `github_repository_dependabot_security_updates.dependabot_security_updates` はリポ名だけ
   （例: `id = "gachanuma"`）。タグ Ruleset（`github_repository_ruleset.tag_protection["<repo>"]`、
   public リポのみ対象）を既に持つリポを取り込む場合も、アドレスを `tag_protection` に変えるだけで
   ID 形式は `branch_protection` と同じ `<repo>:<ruleset_id>`（例: `id = "dependabot-triage-action:23456789"`）。
5. `terraform plan` を実行し、リポ固有値と例外台帳にそのリポを使用リポとして登録した属性の per-repo の値を実態に合わせる。
   非 public リポ、または public リポで対象リポが既にタグ Ruleset を import 済みの場合は
   **`0 to add, 0 to change, 0 to destroy`（import のみ）** に収束させる。
   public リポで対象リポにタグ Ruleset が無い場合（現状の想定ケース）は、`tag_protection.tf` の
   `github_repository_ruleset.tag_protection["<repo>"]` が新規作成されるため、
   `1 to add, 0 to change, 0 to destroy` に収束すれば import 成功（タグ Ruleset の新規作成は想定通り）。
   類型決定値・全リポ共通値と実態が食い違う属性が plan に出たら、`terraform.tfvars` や方針値を寄せずに
   手順1へ戻る（[設計仕様書](docs/design/terraform-structure.md) §4）。
   差分が出やすい箇所: `allowed_merge_methods` の順序、`required_check` の集合、`integration_id` の有無、`enforcement`。
   ```
   Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
   # public リポでタグ Ruleset が無い場合: 1 to import, 1 to add, 0 to change, 0 to destroy.
   ```
6. no-op を確認できたら、`import {}` ブロックを含む PR を main へマージする。マージで起動した HCP の run が
   plan から apply まで自動で進み（Auto apply。下記「運用フロー」）、state に取り込む（取り込むだけ＝実 Ruleset は無変更で安全に管理下入り）。
7. 取り込み完了後、追加した `import {}` ブロックを削除する PR を別に出す（state に入った後は不要）。その PR の Speculative Plan が
   `No changes` のままであることを確認。

---

## 運用フロー（通常の変更）

```bash
terraform fmt          # 整形
terraform validate     # 検証
terraform plan         # （任意）手戻り防止の自己確認
# → PR 起票後、HCP Speculative Plan が GitHub Checks に自動表示される（強制ゲート）
# → PR を main へマージすると、HCP が plan から apply まで自動で実行する（Auto apply）
```

### Speculative Plan の自動起動（VCS 連携）

HCP Workspace は `kuchita-el/github-config` リポに VCS 連携済みのため、**PR を起票・push すると HCP で Speculative Plan が自動起動**する。

- Plan 結果（成功・失敗・差分有無）は PR の "Checks" タブに表示される
- マージ前の振る舞い確認はこの自動 Plan を正とする
- ローカルの `terraform plan` は**任意習慣**（開発者の自己確認・手戻り防止用）であり、強制ゲートではない
- PR で起動する Speculative Plan は apply されない（plan のみ）
- HCP Workspace `github-config` の Apply Method は **Auto apply**。main への push とマージで起動した run は、plan が成功し差分があるとき、人手の操作なしに apply まで進む
- VCS 連携中の Workspace では CLI からのリモート apply（`terraform apply`）は実行できない。変更は main へのマージで適用する

Claude Code セッション内では `.tf` への `Edit` / `Write` / `MultiEdit` 直後に `terraform fmt`（`.claude/hooks/terraform-fmt.sh`）と `tflint`（`.claude/hooks/tflint.sh`）が PostToolUse hook で自動実行される。`tflint` は `.tflint.hcl` の `terraform-linters/tflint-ruleset-terraform` `recommended` プリセットで対象ファイルの違反のみを stderr に出力する（違反検知時もセッションはブロックされない）。手動 `terraform fmt` / `tflint` も引き続き有効。

冪等性: `apply` 直後に再度 `plan`/`apply` しても `No changes` になる。

### PR レビュー時の reviewer 併用

`.tf` 変更を含む PR では、汎用 `dev-workflow:code-reviewer`（既存）に加えて Terraform 固有設計レビュー用の `terraform-design-reviewer`（本リポ `.claude/agents/` 配下）を併用する。詳細は [`docs/agents/terraform-design-reviewer/README.md`](docs/agents/terraform-design-reviewer/README.md) を参照。

**担い手の分担**:

- `terraform-design-reviewer` は、一般的な Terraform 設計の妥当性（観点 1〜9）を、Terraform・provider・GitHub の公式ドキュメント等の一般的な出典に基づいて判定する。本リポ固有の規約への準拠は判定しない。
- 本リポ固有の規約への準拠の確認は `dev-workflow:code-reviewer` が担う。呼び出し側は、その呼び出しプロンプトに次の参照先を入れる。
  - [設計仕様書](docs/design/terraform-structure.md) §3〜§8（§4 例外台帳、§8「repository」の `lifecycle.ignore_changes` の保護対象属性を含む）
  - CLAUDE.md §2（既存リポの取り込み）・§3（App permission scope）
- 両 reviewer の出力は呼び出し側の統合段でまとめる。`terraform-design-reviewer` の観点 7（差分が要する provider 権限の列挙）は必要な権限の列挙までを行い、付与状況との照合は行わない。統合段で、観点 7 が列挙した権限を CLAUDE.md §3 が定める App の付与権限と突き合わせ、付与権限を超える場合は CLAUDE.md §3 に従い App permission scope の拡張を別 Issue とする。観点 7 の列挙は resource 型の単位で行い、引数の値によって追加で呼ぶエンドポイントの権限（属性単位の条件。provider ドキュメントの resource ページの注記にあるものなど）は列挙しないため、統合段の突き合わせもその範囲に限られる。

**validate 出力の取得**: `terraform-design-reviewer` は観点 9（provider 非推奨の新規使用）を、呼び出し側が渡す `terraform validate -json` の出力で判定する。初期化と環境変数は CI の validate ジョブ（`.github/workflows/terraform.yml`）と同じで、出力だけを `-json` にする。

- PR 適用後（HEAD）の作業ディレクトリで実行する。未初期化の作業ディレクトリでは、先に `terraform init -backend=false` で初期化する（HCP Terraform の workspace に接続せずに provider を導入する）。
- `GITHUB_APP_ID`・`GITHUB_APP_INSTALLATION_ID`・`GITHUB_APP_PEM_FILE` の3変数を設定して `terraform validate -json` を実行する。`providers.tf` の `app_auth {}` がこの3変数を読むため、設定しないと validate が失敗する。validate は provider の API（GitHub API）に接続しないため、値はダミーでよい。
- 出力（JSON）を `## validate 出力` にそのまま貼る。リポジトリのルート以外のディレクトリで実行した場合は、見出しの後の最初の行（JSON の前）に `実行ディレクトリ: <リポジトリのルートからの相対パス>`（例: `実行ディレクトリ: infra`）の1行を置き、次の行から JSON を貼る。この行が無ければ、reviewer はリポジトリのルートで実行したものとみなす（読み方の定めは reviewer 定義の「入力」節）。
- validate 出力を渡さない場合と、`-json` 形式でない出力（人間向けの出力）や validate が失敗した出力を渡した場合は、観点 9 は未評価になる。また、属性の値が validate の時点で決まらない場合（input variable や `each.value` に由来する場合など）は、非推奨の属性を新たに使っても validate が警告を出さないことがあり、その新規使用は観点 9 では検出できない（reviewer 定義の観点 9 の「判定の限界」）。

**起動例（Claude Code 内）**: `terraform-design-reviewer` は `Bash` 権限を持たないため、呼び出し側で事前に `git diff` と validate 出力を取得してプロンプトに含める。

```bash
# 呼び出し側で事前に取得（PR 適用後の作業ディレクトリで実行する）
git diff main...HEAD -- '*.tf' '*.tfvars' > /tmp/tf-diff.txt
terraform init -backend=false   # 未初期化の場合のみ
export GITHUB_APP_ID=1 GITHUB_APP_INSTALLATION_ID=1 GITHUB_APP_PEM_FILE=placeholder   # ダミー値でよい
terraform validate -json > /tmp/tf-validate.json
```

```
# 汎用レビュアー（既存）と並列起動
Agent(
  subagent_type: "dev-workflow:code-reviewer",
  prompt: """
    <通常のレビュー依頼（ベースブランチ・差分・要件情報）>

    ## 本リポ固有の規約への準拠の確認
    差分が次の規約に準拠しているかを確認する。
    - docs/design/terraform-structure.md §3〜§8（§4 例外台帳、§8「repository」の lifecycle.ignore_changes の保護対象属性を含む）
    - CLAUDE.md §2（既存リポの取り込み）
    - CLAUDE.md §3（App permission scope）
  """
)
Agent(
  subagent_type: "terraform-design-reviewer",
  prompt: """
    ベースブランチ: main

    ## git diff
    <`/tmp/tf-diff.txt` の中身を貼り付け>

    ## plan 出力（任意）
    <HCP plan 出力テキスト。未提供なら空欄>

    ## validate 出力（任意）
    実行ディレクトリ: <リポジトリのルート以外で実行した場合だけ書く。ルートで実行した場合はこの行を省く>
    <`/tmp/tf-validate.json` の中身（JSON）をそのまま貼り付け。未提供なら空欄>

    ## 要件情報
    <Issue/PR 本文の要点>
  """
)
```

両 reviewer は補完関係。重複指摘抑止ルール:

- 観点境界は `terraform-design-reviewer` の reviewer 定義に明文化（観点 5: Terraform 固有定数に限定）。
- 汎用 reviewer に上記の参照先を渡して準拠の確認を委ねるため、次の観点は準拠の指摘と同じ行に重なりうる。重なった場合は、下記の同一行・同主旨のルールに従う（観点 7 を除く）。
  - 観点 2（`variable` の `validation` ブロック不足）: 入力の検証の定め（設計仕様書 §7 の `profile` の validation など）
  - 観点 3（lifecycle 保護の縮退）: 保護する属性の定め（設計仕様書 §8「repository」）
  - 観点 6（既定値の合成と単一の置き場所）: 揃える値の置き場所や上書きの経路の定め（設計仕様書 §4・§7）
  - 観点 7（差分が要する provider 権限の列挙）: App に与える権限の定め（CLAUDE.md §3）。観点 7 の列挙は、汎用 reviewer の指摘と重なっても捨てずに両方を残す（統合段で付与権限と突き合わせる入力になるため。同一行・同主旨のルールの例外）
  - 観点 8（plan-time リスク検出）: 既存リソースの取り込みの手順の定め（CLAUDE.md §2）
- 観点 1, 4, 9 は Terraform 固有の設計の観点であり、汎用 reviewer の汎用の観点（コード重複等）とは重ならない。準拠の指摘と同じ行に重なった場合も、下記の同一行・同主旨のルールに従う。
- 同一行・同主旨の指摘が両 reviewer から出た場合は片方を採用する（重複は二重表示しない。観点 7 の列挙は上記の例外）。

---

## 手順: 新規リポを管理対象に追加する

- **既存 Ruleset があるリポ** → 上記「既存リポの取り込み（import）」に従う（import 必須）。
- **Ruleset が無いリポ**: Ruleset 以外の管理対象（`github_repository.this`・`github_branch_default.repository`・`github_actions_repository_permissions.actions_permissions`・`github_workflow_repository_permissions.actions_permissions`・`github_repository_vulnerability_alerts.vulnerability_alerts`・`github_repository_dependabot_security_updates.dependabot_security_updates`）は GitHub 側に既にあるため、上記「既存リポの取り込み（import）」の手順で import する。新規作成になるのは Ruleset だけ。
  1. 取り込みの前に、対象リポのワークフローが参照する action を SHA 参照（`uses: <owner>/<repo>@<40桁の SHA> # <バージョン>`）へ固定する。複合 action は内部の参照も SHA で固定された版を使う（[設計仕様書](docs/design/terraform-structure.md) §8「actions_permissions」）。
  2. `terraform.tfvars` の `repositories` にリポ名を追加する。`visibility` と `profile`（[設計仕様書](docs/design/terraform-structure.md) §7、必須・既定値なし）を直下に宣言し、判定根拠をコメントで残す。リポ固有値は設定種別名のキーの下に入れ子で書く（CI があれば `branch_protection = { status_check_contexts = [...], status_check_integration_id = 15368 }`、説明文があれば `repository = { description = "..." }`、`actions/*`・`github/*` 以外の action を使うなら `actions_permissions = { patterns_allowed = ["<owner>/<repo>@*"] }`）。値の無い設定種別のキーは省略する（設計仕様書 §5）。全リポ共通値（`local.<concern>_preset`）はここに書かない。
  3. Ruleset 以外の6リソースの `import {}` ブロックを追加し、`terraform plan` を実行する。**public リポの場合**、branch_protection Ruleset と tag_protection Ruleset の計2件が新規作成されるため `6 to import, 2 to add, 0 to change, 0 to destroy`（Ruleset の作成のみ）になることを確認する（他リポが recreate されないこと）。**private リポの場合**は Ruleset が対象外のため `6 to import, 0 to add, 0 to change, 0 to destroy` になることを確認する。`vulnerability_alerts` / `dependabot_security_updates` は visibility を問わず import 対象になるが、`security_and_analysis`（`repository.tf`、既存 `github_repository.this` への属性追加）は private リポでは dynamic ブロックにより送られないため import 対象にならず差分にも現れない（[設計仕様書](docs/design/terraform-structure.md) §6）。実値が全リポ共通値・類型決定値と食い違う場合は、import より前に「既存リポの取り込み（import）」手順1で [設計仕様書](docs/design/terraform-structure.md) §4「取り込み時の食い違い」に従って振り分ける。
  4. `import {}` ブロックを含む PR を main へマージする（HCP が plan から apply まで自動で進め、state に取り込む）。その後、`import {}` ブロックを削除する PR を別に出し、その Speculative Plan が `No changes` のままであることを確認する。

> `for_each` のキーはリポ名（不変）。リポ追加で既存リソースが destroy/recreate されることはない。

---

## 手順: 設定種別を追加する（branch protection 以外）

規則は [設計仕様書](docs/design/terraform-structure.md) §3〜§6 にある。ここには手順の順序だけを書く。

1. 設定種別名を [設計仕様書](docs/design/terraform-structure.md) §3・§5 で決め、`<concern>.tf` を1枚足す（例: `branch_protection.tf`）。1つの設定種別が複数のリソース型を使ってよい。
2. 属性ごとに [設計仕様書](docs/design/terraform-structure.md) §4 で値の区分（リポ固有値 / 類型決定値 / 全リポ共通値）を決め、区分ごとの置き場所（`repositories.<k>.<concern>.*` / `local.<concern>_profile_defaults` / `local.<concern>_preset`）に置く。類型決定値の表は4つの識別子すべてをキーに持ち、全類型に同じ属性を並べる（設計仕様書 §7。実例: `branch_protection.tf` の `branch_protection_profile_defaults`）。
3. 特定のリポで類型決定値・全リポ共通値から外す必要がある属性は、[設計仕様書](docs/design/terraform-structure.md) §4 の例外台帳へ登録する（登録と per-repo のフィールドの追加を同じ変更で行う）。
4. visibility で適用範囲を絞る場合は、適用対象の集合 `local.<concern>_targets` を置く（[設計仕様書](docs/design/terraform-structure.md) §6）。
5. 既存リポに既存の設定がある場合は **import → plan no-op → apply** の順（上記「既存リポの取り込み（import）」。実値の食い違いは [設計仕様書](docs/design/terraform-structure.md) §4）。

---

## 例外台帳

特定のリポで類型決定値・全リポ共通値から外すことを許した属性の一覧（例外台帳）は、登録の要件・手続きとともに [設計仕様書](docs/design/terraform-structure.md) §4「例外台帳」にある。

---

## Claude Code 連携（オプション）

本リポは Claude Code 用の MCP / skill を project スコープで設定済み。Terraform 編集を Claude Code 上で行う場合のみ必要、ローカル CLI / HCP からの `terraform plan/apply` には影響しない。

### 構成

| 種別 | 名前 | 出所 | 用途 |
|---|---|---|---|
| MCP（`.mcp.json`） | `terraform` | `hashicorp/terraform-mcp-server:1.0.0`（公式、Docker stdio） | Terraform Registry の provider 属性 live 照会 |
| skill plugin（`.claude/settings.json`） | `terraform-code-generation@hashicorp` | `hashicorp/agent-skills` marketplace | `terraform-style-guide` 等を提供 |
| skill plugin（`.claude/settings.json`） | `terraform-module-generation@hashicorp` | 同上 | `refactor-module` 等（将来モジュール分割時のケイパビリティ担保） |

### 初回セットアップ

> Claude Code 本体は別途インストール済みであることを前提とする。Docker も必要（公式 MCP サーバが Docker stdio で起動するため）。

marketplace（`hashicorp/agent-skills`）も `.claude/settings.json` の `extraKnownMarketplaces` で project スコープ宣言済みのため、手動追加は不要。

1. **プロジェクトを開いて `claude` を起動** — 初回は project スコープの `.mcp.json` および `.claude/settings.json`（marketplace / plugin 有効化）に対する信頼確認ダイアログが出るので、それぞれ承認する。
2. **動作確認**
   ```bash
   claude plugin list  # 両 plugin が ✔ enabled になっていること
   claude mcp list     # terraform / plugin:terraform-code-generation:terraform 等が ✔ Connected になっていること
   ```

承認状態を破棄してやり直す場合は `claude mcp reset-project-choices`（MCP）あるいは settings の plugin 承認リセット手順を参照。

---

## トラブルシュート

| 症状 | 原因・対処 |
|---|---|
| `403 Resource not accessible by integration` | App に対象リポの **Administration: Read and write** が無い、対象リポが **インストール対象に含まれていない**、または provider の `owner` 未設定。手順3（権限・Selected repositories）を見直す |
| `import` 後に `plan` が差分を出し続ける | HCL が API 実体と不一致。plan の差分行を読み、リポ固有値と例外台帳にそのリポを使用リポとして登録した属性の per-repo の値を実態に合わせる。類型決定値・全リポ共通値と実態が食い違う場合は、`terraform.tfvars` や方針値を寄せずに「既存リポの取り込み（import）」手順1へ戻る（[設計仕様書](docs/design/terraform-structure.md) §4） |
| Speculative Plan が PR 起票後に自動起動しない | HCP Workspace の Settings → Version Control で VCS 連携が未設定か "Automatic speculative plans on pull requests" が無効。連携 UI を確認する |
| GitHub Checks に HCP Terraform の check が現れない | GitHub App（Terraform Cloud）がリポにインストールされていないか権限が不足。HCP の VCS 設定画面の手順に従い GitHub App を再インストールする |
| Speculative Plan が `Error` / `Failed` で終わる | `.tf` 構文エラー・provider 認証失敗・変数未定義が原因のことが多い。HCP UI の Run ログで詳細を確認し、ローカルで `terraform validate` / `terraform fmt` を実施する |
| provider のスキーマエラー | provider バージョン差異。`~> 6.0` 固定と `.terraform.lock.hcl` のコミットを確認 |
| `Error: Required token could not be found` 等の認証エラー | App 変数3本（`GITHUB_APP_ID`/`GITHUB_APP_INSTALLATION_ID`/`GITHUB_APP_PEM_FILE`）が HCP workspace に未登録、または `providers.tf` の `app_auth {}` ブロック欠落。手順4を見直す |
| ローカル `terraform validate` で `app_auth` の `installation_id is required` | App 認証情報は環境変数から解決されるため、ローカル validate には `GITHUB_APP_ID`/`GITHUB_APP_INSTALLATION_ID`/`GITHUB_APP_PEM_FILE` の export が必要（Remote 実行では HCP が注入するので不要） |
| ローカルに `terraform.tfstate` ができる | `cloud {}` が効いていない。`terraform.tf` の organization/workspace 名と `terraform init` を確認 |

### PAT → App 切替・ロールバック

- **切替順序**（二重認証を避ける）: ①App 変数3本を HCP に追加 → ②`app_auth {}` を含むコードを main へ反映 → ③`terraform plan`/`apply` 成功を確認 → ④その後に PAT 変数 `GITHUB_TOKEN` を削除し、GitHub 側の旧 PAT を revoke。PAT 削除は最後に遅延させロールバック余地を残す。
- **ロールバック**: App 認証で plan/apply が失敗したら、HCP に `GITHUB_TOKEN`（PAT）を再追加し `providers.tf` の `app_auth {}` を revert する。provider は token 環境変数へフォールバックする。
