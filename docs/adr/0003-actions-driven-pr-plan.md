# ADR 0003: PR の Plan トリガーを GitHub Actions 主導へ移行する案（棄却）

## ステータス

棄却（2026-06-28、[#67](https://github.com/kuchita-el/github-config/issues/67)）

当初は「採用」として GitHub Actions 主導の HCP Remote Plan へ移行する方針で着手したが、実装の過程で認証経路に関する2つの構造的制約（後述）が判明し、費用対効果が当初想定を大きく下回ると判断した。本 ADR は **VCS 連携 Speculative Plan を維持する**（移行しない）という決定の記録として残す。将来同じ移行を再検討する際に、同じ制約へ再び突き当たらないための記録である。

## コンテキスト

本リポ `kuchita-el/github-config` は HCP Workspace `github-config` に VCS 連携済みであり（PR #56）、PR 起票時に HCP が Speculative Plan を自動実行する。Plan 結果は GitHub Checks 欄に HCP へのリンクとして表示される。

Issue #62（Plan に含まれる destroy 対象リソースを PR コメントで可視化する）の実装を検討する過程で、以下の課題が挙がった。

- **VCS Plan の制御余地がほぼ無い**: plan の stdout を直接取得できず、PR コメント整形には HCP Run API を自前で叩く必要がある。
- **将来の拡張に制約**: Plan 前段の lint・条件分岐・複数 Workspace 並列等の制御を Actions に寄せたい場合、VCS 連携経由の Speculative Plan が制約となる。

これらを解決するため、PR の Plan トリガーを「HCP VCS 連携の Speculative Plan」から「GitHub Actions 経由の HCP Remote Plan」へ切り替える案を検討した。

## 決定

**移行しない。VCS 連携 Speculative Plan を現状のまま維持する。**

GitHub Actions 主導 Plan の採用を見送る理由は、Actions から HCP を駆動するために必要な認証が、本環境（HCP Terraform Free プラン）では「**フル admin 権限の長命静的トークンを GitHub Secrets に常駐させる**」以外に手段が無く、credential ゼロで既に機能している VCS Speculative Plan を置き換えるコストに見合わないため。

## 根拠（棄却理由）

### 制約 1: Actions → HCP Terraform API に OIDC / 短命トークンが存在しない

`terraform init` が `cloud {}` ブロックで app.terraform.io に接続する認証は、`.terraformrc`（または `TF_TOKEN_app_terraform_io` 環境変数）に置いた**静的 API トークン**しか受け付けない。GitHub OIDC トークンを HCP トークンへ交換する native な機構は存在しない。

HCP/Terraform 文脈で「OIDC」と呼ばれる機能は本件の認証方向（Actions runner → HCP Terraform API）では一つも使えない。

| OIDC 機能 | 認証の方向 | 本件への適用 |
|---|---|---|
| Dynamic Provider Credentials | HCP Run → AWS/GCP/Azure | 不可（Run が外部クラウドへ認証する機能） |
| HCP Platform Workload Identity Federation（`hcp-auth-action`） | Actions → HCP Platform（Vault Secrets 等） | 不可（app.terraform.io の API とは別系統のトークン） |
| CLI/API → app.terraform.io | Actions → HCP Terraform | **静的トークンのみ。OIDC 不在** |

一次情報: [Manage API tokens for HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs/users-teams-organizations/api-tokens) — 列挙される全トークン種別（User / Team / Organization / Agent 等）が静的トークンであり、OIDC / Workload Identity Federation による短命トークン発行の記述は無い。

### 制約 2: Free プランでは最小権限トークンを発行できない

HCP Terraform Free プランは team management（追加チーム作成・granular 権限）を含まない。組織には既定の `owners` チームのみが存在し、これはフル API アクセス権を持つ。したがって Issue #67 が前提とした「Workspace 単位の最小権限 Team トークン」は発行不可能であり、利用可能なトークンは以下のいずれも**実効フル admin 権限**となる。

- **User API token**: ユーザーに紐づく。owner ユーザーのトークンは組織全体への admin 権限を持つ。
- **Owners Team token**: ユーザー非依存だが owners チームの権限 = 組織全体 admin。

一次情報: [Permission model in HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs/users-teams-organizations/permissions) — teams entitlement が無い組織は owners チームのみを持ち、これは HCP Terraform API へのフルアクセスを持つ。

### 帰結

制約 1・2 より、Actions 主導 Plan を採用すると「漏洩時のブラスト半径が組織全体 admin に等しい長命静的トークン」を GitHub Secrets に常駐させることになる。一方、現行の VCS Speculative Plan は **GitHub 側の credential を一切必要とせず**（HCP が VCS 連携経由でリポジトリを pull する）、漏洩リスクのある秘密が存在しない。

CLAUDE.md §4 が示す秘密管理方針（秘密の Git/CI 常駐を最小化する）に照らしても、credential ゼロの現状を full admin トークン常駐へ置き換える積極的理由は乏しい。#62 の PR コメント要件が必須でない限り、移行は割に合わない。

## 代替案

### 案 A: 静的トークンを許容して Actions 主導 Plan を採用（不採用）

User または Owners Team の静的トークンを短い有効期限付きで発行し、`TF_TOKEN_app_terraform_io: ${{ secrets.TF_API_TOKEN }}` で Actions から HCP Remote Plan を駆動する案。

**不採用の理由**: 上述のとおり Free プランではトークンが必ずフル admin 権限になる。有効期限を短くしても、有効期間中は組織全体への admin 権限が GitHub Secrets に存在する。credential ゼロの VCS Plan を置き換えるリスク増分が、得られる制御柔軟性に見合わない。

### 案 B: HCP Run Notification（generic webhook）で plan 結果を外部へ押し出す（不採用）

VCS Speculative Plan を維持したまま、HCP のワークスペース通知（generic webhook）で run イベントを GitHub 側へ送り、PR コメント等に反映する案。GitHub 側に HCP トークンを置かずに済む点が魅力。

**不採用の理由**: generic webhook の payload は `run_url` / `run_id` / `run_message` / status 等の**メタデータとリンクのみ**であり、plan の差分・destroy 対象リソースの内容を含まない（一次情報: [Notification configurations API reference](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/notification-configurations)）。#62 が必要とする destroy 可視化には plan 内容の取得が必須で、それには結局 HCP Run API 呼び出し = フル admin 静的トークンが必要になる。通知単体では目的を満たさない。

### 案 C: 有料 Standard プランへ昇格して最小権限 Team トークンを使う（保留）

Standard プランは team management を解禁し、`github-config` Workspace に対する最小権限（Plan レベル）の Team トークンを発行できる。これにより制約 2 が解消され、ブラスト半径を Plan 権限に限定した上で Actions 主導 Plan を採用できる。

**保留の理由**: 課金を伴う判断であり、本 Issue のスコープを超える。後述「再評価の条件」に該当する。

## 影響

- **コード変更なし**: `.github/workflows/terraform.yml` への plan ジョブ追加は撤回した。`fmt` / `validate` / `tflint` の3ジョブは従来どおり。
- **HCP 設定変更なし**: `speculative-enabled` は `true` のまま維持する（VCS Speculative Plan を継続）。
- **CLAUDE.md / README**: VCS 連携 Speculative Plan 前提の記述を維持する（変更なし）。
- **Issue #62 への含意**: Free プランの制約下では、plan 内容を PR コメント化するにはフル admin 静的トークンの常駐が前提となる。#62 の実装可否・方式はこのトレードオフを踏まえて別途判断する。

## 再評価の条件

以下のいずれかが成立した場合、本 ADR の棄却判断を再評価する余地がある。

- HCP Terraform Standard 以上へ昇格し、Workspace 単位の最小権限 Team トークンが発行可能になった場合（案 C）。
- HCP Terraform の CLI/API 認証に OIDC / Workload Identity Federation 経路が追加され、短命トークンで Actions から HCP を駆動できるようになった場合（制約 1 の解消）。
