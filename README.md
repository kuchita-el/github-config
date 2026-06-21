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
terraform.tfvars (管理対象リポ + リポ別override)
        │
        ▼
branch_protection.tf  branch_protection_preset(全リポ共通の既定) + セレクター式（!= null ? : ）で override 合成
                      github_repository_ruleset を for_each でリポ単位に展開
        │
        ▼
GitHub API (App 認証)        state ⇄ HCP Terraform workspace
```

| ファイル | 役割 |
|---|---|
| `versions.tf` | Terraform / provider バージョン固定、HCP `cloud {}` バックエンド |
| `providers.tf` | GitHub provider（owner + 空 `app_auth {}`。App 認証情報は環境変数） |
| `variables.tf` | `github_owner`、`repositories`（管理対象 + override）の型定義 |
| `branch_protection.tf` | `branch_protection_preset`（既定）とリポ別 override の合成ロジック + Ruleset リソース（`for_each` 展開） |
| `terraform.tfvars` | 管理対象リポの実データ（秘密なし、コミット対象） |
| `docs/adr/` | 設計判断記録（ADR）。リソース構造・属性方針等の重要決定を `NNNN-<slug>.md` 形式で残す |

### 設計思想（重要）

**TF 管理下の設定は「あるべき状態」を強制する。** GitHub UI で手動変更しても、次回 `terraform plan` で drift として検出され、`apply` で宣言値へ revert される。

- リポ個別のカスタマイズは UI で行わず、**`terraform.tfvars` の override として記述**する。
- 既存リポを管理対象に入れるときは、**必ず `import` → `plan` で no-op 確認**してから `apply` する（いきなり apply すると既存設定を上書き新規作成する事故になる）。

---

## 初期セットアップ（HCP 未経験者向け）

> 一度だけ実施。以降の運用は「運用フロー」へ。

### 1. Terraform CLI のインストール

```bash
# 例: tfenv 経由（推奨）または公式手順
# https://developer.hashicorp.com/terraform/install
terraform version   # >= 1.6 であること
```

### 2. HCP Terraform アカウント・組織・ワークスペースの作成

1. https://app.terraform.io にサインアップ（無料tier）。
2. **Organization** を作成（名前は任意。例: `kuchita-el`）。← この名前を後で `versions.tf` に記入する。
3. **Workspace** を作成:
   - Type: **CLI-Driven Workflow** を選択
   - 名前: `github-config`（`versions.tf` の `workspaces { name = ... }` と一致させる）
4. 作成した Workspace の **Settings → General** で **Execution Mode = Remote** を確認（既定で Remote）。

### 3. GitHub App の作成・インストール・秘密鍵の生成

> PAT ではなく GitHub App で認証する。期限管理・人依存を避け、権限を最小化するため。

1. GitHub → Settings → Developer settings → **GitHub Apps** → New GitHub App。
   - 名前は任意（例: `kuchita-el-github-config`）。Homepage URL はダミー可。Webhook は **Active を OFF**。
2. **Permissions → Repository permissions**:
   - **Administration: Read and write**（Ruleset 操作に必須）
   - **Metadata: Read**（他権限付与時に自動で必須化される）
   - 他は **No access**。特に **Contents は付与しない**（漏洩時もコード改竄を構造的に遮断）。
   - ラベル管理（Issue #5）着手時に **Issues: Read and write** を増分追加する。
3. App を作成後、**Install App** で自分のアカウントにインストール。
   - **Only select repositories** を選び、**管理対象リポのみ**（現状 `gachanuma` / `github-config`）を指定。クレデンシャル到達範囲を管理対象セットに一致させる。
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

`versions.tf` の `organization = "REPLACE_WITH_YOUR_HCP_ORG"` を手順2で作った組織名に置換してコミットする。

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

1. 対象リポの既存 Ruleset ID を調べる:
   ```bash
   gh api repos/<owner>/<repo>/rulesets --jq '.[] | {id, name}'
   ```
2. `terraform.tfvars` の `repositories` に対象リポを追加（status check contexts 等を実態に合わせる）。
3. import ブロックを一時的に追加する（`import.tf` を作成。アドレスは `for_each` キー＝リポ名）:
   ```hcl
   import {
     to = github_repository_ruleset.branch_protection["<repo>"]
     id = "<repo>:<ruleset_id>"
   }
   # 例: id = "gachanuma:16492768"
   ```
4. `terraform plan` を実行し、**`0 to add, 0 to change, 0 to destroy`（import のみ）** になるまで
   `terraform.tfvars` / `branch_protection.tf` を実態へ寄せる。
   差分が出やすい箇所: `allowed_merge_methods` の順序、`required_check` の集合、`integration_id` の有無、`enforcement`。
   ```
   Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
   ```
5. no-op を確認できたら `terraform apply`（state に取り込むだけ＝実 Ruleset は無変更で安全に管理下入り）。
6. 取り込み完了後、追加した `import {}` ブロックを削除する（state に入った後は不要）。`plan` が
   `No changes` のままであることを確認。

---

## 運用フロー（通常の変更）

```bash
terraform fmt          # 整形
terraform validate     # 検証
terraform plan         # 変更内容を事前確認（レビュー）
terraform apply        # 適用
```

Claude Code セッション内では `.tf` への `Edit` / `Write` / `MultiEdit` 直後に `terraform fmt` が PostToolUse hook (`.claude/hooks/terraform-fmt.sh`) で自動実行される。手動 `terraform fmt` も引き続き有効。

冪等性: `apply` 直後に再度 `plan`/`apply` しても `No changes` になる。

### PR レビュー時の reviewer 併用

`.tf` 変更を含む PR では、汎用 `dev-workflow:code-reviewer`（既存）に加えて Terraform 固有設計レビュー用の `terraform-design-reviewer`（本リポ `.claude/agents/` 配下）を併用する。詳細は [`docs/agents/terraform-design-reviewer/README.md`](docs/agents/terraform-design-reviewer/README.md) を参照。

`terraform-design-reviewer` は `Bash` 権限を持たないため、呼び出し側で事前に `git diff` を取得してプロンプトに含める。起動例（Claude Code 内）:

```bash
# 呼び出し側で事前に取得
git diff main...HEAD -- '*.tf' '*.tfvars' > /tmp/tf-diff.txt
```

```
# 汎用レビュアー（既存）と並列起動
Agent(subagent_type: "dev-workflow:code-reviewer", prompt: "...")
Agent(
  subagent_type: "terraform-design-reviewer",
  prompt: """
    ベースブランチ: main

    ## git diff
    <`/tmp/tf-diff.txt` の中身を貼り付け>

    ## plan 出力（任意）
    <HCP plan 出力テキスト。未提供なら空欄>

    ## 要件情報
    <Issue/PR 本文の要点>
  """
)
```

両 reviewer は補完関係。重複指摘抑止ルール:

- 観点境界は `terraform-design-reviewer` の reviewer 定義に明文化（観点 5: Terraform 固有定数に限定）。
- 同一行・同主旨の指摘が両 reviewer から出た場合は片方を採用する（重複は二重表示しない）。

---

## 手順: 新規リポを管理対象に追加する

- **既存 Ruleset があるリポ** → 上記「既存リポの取り込み（import）」に従う（import 必須）。
- **Ruleset が無い新規リポ**:
  1. `terraform.tfvars` の `repositories` にリポ名を追加（CI があれば `status_check_contexts` も）。
  2. `terraform plan` で「1 to add」になることを確認（他リポが recreate されないこと）。
  3. `terraform apply`。

> `for_each` のキーはリポ名（不変）。リポ追加で既存リソースが destroy/recreate されることはない。

---

## 手順: 設定種別を追加する（branch protection 以外）

将来 labels / dependabot / merge settings 等を足すときのパターン:

1. 新しい設定種別ごとに `*.tf` ファイルを1枚追加（例: `repository_labels.tf`）。
2. 全リポ共通の既定値は当該 `*.tf` 冒頭に `local.<resource>_preset` として定義（ADR 0001）。
3. リポ別差分は `variables.tf` の `repositories` object に optional 属性を足し、`terraform.tfvars` で注入。
4. リソースは `for_each = local.<新設定>` でリポ単位に展開（1設定種別 = 1リソース）。
5. 既存リポに既存の設定がある場合は **import → plan no-op → apply** の順（branch protection と同じ）。

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
| `import` 後に `plan` が差分を出し続ける | HCL が API 実体と不一致。plan の差分行を読み `terraform.tfvars`/`branch_protection.tf` を実態へ寄せる |
| provider のスキーマエラー | provider バージョン差異。`~> 6.0` 固定と `.terraform.lock.hcl` のコミットを確認 |
| `Error: Required token could not be found` 等の認証エラー | App 変数3本（`GITHUB_APP_ID`/`GITHUB_APP_INSTALLATION_ID`/`GITHUB_APP_PEM_FILE`）が HCP workspace に未登録、または `providers.tf` の `app_auth {}` ブロック欠落。手順4を見直す |
| ローカル `terraform validate` で `app_auth` の `installation_id is required` | App 認証情報は環境変数から解決されるため、ローカル validate には `GITHUB_APP_ID`/`GITHUB_APP_INSTALLATION_ID`/`GITHUB_APP_PEM_FILE` の export が必要（Remote 実行では HCP が注入するので不要） |
| ローカルに `terraform.tfstate` ができる | `cloud {}` が効いていない。`versions.tf` の organization/workspace 名と `terraform init` を確認 |

### PAT → App 切替・ロールバック

- **切替順序**（二重認証を避ける）: ①App 変数3本を HCP に追加 → ②`app_auth {}` を含むコードを main へ反映 → ③`terraform plan`/`apply` 成功を確認 → ④その後に PAT 変数 `GITHUB_TOKEN` を削除し、GitHub 側の旧 PAT を revoke。PAT 削除は最後に遅延させロールバック余地を残す。
- **ロールバック**: App 認証で plan/apply が失敗したら、HCP に `GITHUB_TOKEN`（PAT）を再追加し `providers.tf` の `app_auth {}` を revert する。provider は token 環境変数へフォールバックする。

---

## スコープ外（将来検討）

- merge settings / labels / dependabot 等の追加設定種別
- `plan` 定期実行による drift 検出の CI 自動化
- 複数 Org への展開
