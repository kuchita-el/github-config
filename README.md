# github-config

個人アカウントの GitHub リポジトリ設定（branch protection 等）を **Terraform で宣言的に管理**する基盤。

設定を Single Source of Truth として版管理し、全リポへ統一的に投入・更新する。冪等・適用前確認（`terraform plan`）・drift 検出は Terraform が標準提供する。

- **state / 実行**: HCP Terraform（旧 Terraform Cloud）無料tier、Remote 実行
- **provider**: `integrations/github` `~> 6.0`
- **認証**: fine-grained PAT（将来 GitHub App へ移行予定）
- **最初の設定種別**: branch protection（Repository Ruleset）

---

## アーキテクチャ

```
terraform.tfvars (管理対象リポ + リポ別override)
        │
        ▼
locals.tf  base_branch_protection(全リポ共通の既定) + coalesce で override 合成
        │
        ▼
branch_protection.tf  github_repository_ruleset を for_each でリポ単位に展開
        │
        ▼
GitHub API (PAT 認証)        state ⇄ HCP Terraform workspace
```

| ファイル | 役割 |
|---|---|
| `versions.tf` | Terraform / provider バージョン固定、HCP `cloud {}` バックエンド |
| `providers.tf` | GitHub provider（owner のみ。token は環境変数） |
| `variables.tf` | `github_owner`、`repositories`（管理対象 + override）の型定義 |
| `locals.tf` | ベース設定とリポ別 override の合成ロジック |
| `branch_protection.tf` | Ruleset リソース（`for_each` 展開） |
| `terraform.tfvars` | 管理対象リポの実データ（秘密なし、コミット対象） |

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

### 3. GitHub fine-grained PAT の発行

1. GitHub → Settings → Developer settings → **Fine-grained tokens** → Generate new token。
2. **Repository access**: 管理対象リポ（まずは `gachanuma`）を選択。
3. **Permissions → Repository permissions → Administration: Read and Write**（Ruleset 操作に必須）。
4. 有効期限を設定し、発行されたトークン（`github_pat_...`）を控える。

### 4. PAT を HCP Workspace の秘密変数として登録

Workspace → **Variables** → Add variable:

- Category: **Environment variable**
- Key: `GITHUB_TOKEN`
- Value: 手順3の PAT
- **Sensitive: ON**（必須。値がログ・state に出ない）

> Remote 実行では HCP がこの env var を provider に注入する。ローカルに秘密を置かない。

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
   `terraform.tfvars` / `locals.tf` を実態へ寄せる。
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

冪等性: `apply` 直後に再度 `plan`/`apply` しても `No changes` になる。

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
2. 全リポ共通の既定値は `locals.tf` にベースとして定義。
3. リポ別差分は `variables.tf` の `repositories` object に optional 属性を足し、`terraform.tfvars` で注入。
4. リソースは `for_each = local.<新設定>` でリポ単位に展開（1設定種別 = 1リソース）。
5. 既存リポに既存の設定がある場合は **import → plan no-op → apply** の順（branch protection と同じ）。

---

## トラブルシュート

| 症状 | 原因・対処 |
|---|---|
| `403 Resource not accessible by personal access token` | PAT に対象リポの **Administration: Read and Write** が無い。手順3を見直す |
| `import` 後に `plan` が差分を出し続ける | HCL が API 実体と不一致。plan の差分行を読み `terraform.tfvars`/`locals.tf` を実態へ寄せる |
| provider のスキーマエラー | provider バージョン差異。`~> 6.0` 固定と `.terraform.lock.hcl` のコミットを確認 |
| `Error: Required token could not be found` | `GITHUB_TOKEN`（Sensitive env var）が HCP workspace に未登録。手順4を見直す |
| ローカルに `terraform.tfstate` ができる | `cloud {}` が効いていない。`versions.tf` の organization/workspace 名と `terraform init` を確認 |

---

## スコープ外（将来検討）

- merge settings / labels / dependabot 等の追加設定種別
- `plan` 定期実行による drift 検出の CI 自動化
- GitHub App への認証移行
- 複数 Org への展開
