---
name: gcp-auth
description: >-
  Google Cloud サービス・API への認証と認可に関する判断ガイド。人間ユーザー、サービス ID、
  Application Default Credentials (ADC)、セキュアアクセスのベストプラクティスをカバー。
  ADC 設定、gcloud auth、Service Account Impersonation、Workload Identity Federation、
  API Key 制限、IAM ロール選定で判断に迷ったときに起動する。
---

> Adapted from [google/skills](https://github.com/google/skills) (Apache-2.0). 日本語翻訳と frontmatter 調整を加えている。原文ライセンスは同ディレクトリの `LICENSE` を参照。

# Google Cloud への認証

[認証 (Authentication)](https://docs.cloud.google.com/docs/authentication) とは「あなたが誰か」を証明するプロセス。Google Cloud では「Principal」（ユーザーやサービスといった identity）として表現される。これは [認可 (Authorization)](https://docs.cloud.google.com/iam/docs/overview) （「何ができるか」の判定）の前段にあたる。

## Authentication

### エージェントが最初に確認する質問

具体的な解を提示する前に、ユーザーに以下を確定させる:

1.  誰が・何が認証する？ （人間の開発者か、ローカルスクリプトか、本番稼働中のアプリか）
2.  コードはどこで動く？ （ローカル PC、[Compute Engine](https://docs.cloud.google.com/compute/docs)、[GKE](https://docs.cloud.google.com/kubernetes-engine/docs)、[Cloud Run](https://docs.cloud.google.com/run/docs)、AWS / Azure 等の別クラウドか）
3.  ターゲットは？ （Storage / BigQuery などの GCP API か、独自に構築したアプリか）
4.  高レベルのクライアントライブラリを使うか？ （Python / Go / Node.js 系のライブラリは通常 ADC を自動で扱う）

---

## 人間の認証

ユーザーが GCP にアクセスするには GCP 側で認識できる identity が必要。

### ユーザー identity の種類

社内のワークフォース（開発者・管理者・従業員）向けに、いくつかの identity 構成方法がある:

*   [Google-Managed Accounts](https://docs.cloud.google.com/iam/docs/user-identities#google-accounts): Cloud Identity か Google Workspace で管理ユーザーを作成する。組織がライフサイクルを完全に管理する
*   [Cloud Identity / Google Workspace による Federation](https://docs.cloud.google.com/iam/docs/user-identities#synced-federation): 外部 IdP の identity を使って GCP にサインイン。GCDS や AD / Microsoft Entra ID と同期する必要がある
*   [Workforce Identity Federation](https://docs.cloud.google.com/iam/docs/user-identities#workforce): 外部 IdP の identity を直接 IAM の attribute として使える。GCP 側への同期が不要で、属性ベースの syncless SSO に対応

### 開発者・管理者の access 手段

GCP リソース / API を開発・運用で操作するときに使う方法:

*   [Google Cloud Console](https://console.cloud.google.com/): 主な Web UI。Google アカウント（Gmail or [Google Workspace](https://workspace.google.com/)）で認証
*   [gcloud CLI](https://docs.cloud.google.com/sdk/docs/install-sdk) (`gcloud auth login`): CLI 自体の認証。`gcloud compute instances list` のような管理コマンド用。OAuth 2.0 refresh token をローカルに保存する
*   ローカル開発の [App Default Credentials (ADC)](https://docs.cloud.google.com/docs/authentication/application-default-credentials) (`gcloud auth application-default login`): これは CLI auth とは別物。GCP の Client Library（Python / Java 等）がローカルで「あなた」として振る舞うために使う JSON 認証情報をローカルに作る
*   [Service Account Impersonation](https://docs.cloud.google.com/docs/authentication/use-service-account-impersonation): セキュリティ上、開発者は Service Account Key をダウンロードするのを避けるべき。代わりに `gcloud auth login` で人間として認証したうえで Service Account を impersonate して CLI コマンドや短命の credential を生成する。ローカル開発・トラブルシュートでのベストプラクティス

### エンドユーザー / カスタマー向け

開発者ではない人間が、GCP 上にデプロイされた Web アプリにアクセスするときの方法。ワークフォース identity とは別物:

*   [Identity-Aware Proxy (IAP)](https://docs.cloud.google.com/iap/docs): Web アプリ向けの中央認可レイヤー。Google Workspace / Cloud Identity / 外部 IdP で identity を検証してからアプリに到達させる。VPN 不要の社内アプリ保護やカスタマーポータルでよく使う
*   [Identity Platform](https://docs.cloud.google.com/identity-platform/docs): カスタマー identity 管理 (CIAM) ソリューション。メール / 電話 / ソーシャルログインを自前アプリに組み込める

---

## サービス間認証

本番で動くコードは人間のアカウントではなく Service Account を使う。

### Service Account と Service Agent

*   [Service Account](https://docs.cloud.google.com/iam/docs/service-account-overview): 非人間用の特別な identity。独自のメールアドレスを持つ「ロボット identity」
*   [Service Agent](https://docs.cloud.google.com/iam/docs/service-agents): Google が管理する Service Account。Pub/Sub 等のサービスがユーザーのリソースに代理アクセスするのに使われる

### ベストプラクティス: Service Account の attach

Service Account Key（危険な JSON ファイル）を使うのではなく、GCP リソースに Service Account を attach する。リソースの実行環境がローカルのメタデータサーバー経由で短命の Token を提供する。

*   [Compute Engine](https://docs.cloud.google.com/compute/docs/access/create-enable-service-accounts-for-instances): VM 作成時に Service Account を割り当てる
*   [Cloud Run](https://docs.cloud.google.com/run/docs/securing/service-identity): サービス設定で Service Account を割り当てる

### 特殊ケース・応用

#### Kubernetes Engine (GKE)

[Workload Identity Federation for GKE](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) を使って Kubernetes identity を IAM principal にマッピングする。これにより特定の Kubernetes workload が特定の GCP API にアクセスできるようになる。[詳細はこちら](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#configure-authz-principals)

#### 外部ワークロード ([Workload Identity Federation](https://docs.cloud.google.com/iam/docs/workload-identity-federation))

GCP 外（AWS / Azure / オンプレ）で動くコードでは Key を使わない。Workload Identity Federation で外部 token（AWS IAM role 等）を短命の GCP access token と交換する。

#### [API Keys](https://docs.cloud.google.com/docs/authentication/api-keys)

API Key は暗号化された文字列で、公開データ（Google Maps 等）や [Vertex AI Express Mode](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/start/express-mode/overview) のような簡易アクセスに使う。Express Mode は複雑なセットアップなしに Gemini モデルを高速試用できる。人間でもサービス（API Key をサポートする Cloud Run ベースの AI agent 等）でも使える。

API Key は必ず [restrict](https://docs.cloud.google.com/api-keys/docs/add-restrictions-api-keys) して特定の API・プロジェクトに限定する。漏えい防止のため [Secret Manager](https://docs.cloud.google.com/secret-manager/docs) のような secrets manager に保管する。

#### OAuth 2.0 Access Scopes

現代では IAM が認可の正攻法だが、レガシーな Compute Engine VM や GKE node pool は依然として IAM と並行して Access Scopes に依存する。VM の scope が制限されていると、attach された Service Account に正しい IAM 権限があっても API 呼び出しが失敗する。Service Account が attach 済みなのに失敗するときは最初にここを確認する。

#### Short-Lived Credentials

Impersonation やセキュアなサービス間通信の基盤は IAM Service Account Credentials API。動的に短命の access token / OpenID Connect (OIDC) ID token / self-signed JWT を生成し、静的な credential を不要にする。

---

## Authorization

認証の次は [Identity and Access Management (IAM)](https://docs.cloud.google.com/iam/docs/overview) が「認証済み principal が何をできるか」を決める。

*   Allow Policy: Principal を Role と Resource に bind するレコード
*   [Predefined Roles](https://docs.cloud.google.com/iam/docs/understanding-roles): `roles/storage.objectViewer` や `roles/bigquery.dataEditor` 等の組み込み role。まずこちらを使う
*   [Custom Roles](https://docs.cloud.google.com/iam/docs/creating-custom-roles): Predefined role が大きすぎる場合に作るユーザー定義の権限集合

---

## 例

### 人間からサービスへ（ローカル Python 開発）

1.  Authn: `gcloud auth application-default login` でローカル credential (ADC) を作る
2.  Authz: 自分のメールに対象バケットの `roles/storage.objectViewer` を付与
3.  Code: Python の `storage.Client()` を使う。ADC 経由でローカル credential を自動検出する
    - ADC の検出順: 環境変数 `GOOGLE_APPLICATION_CREDENTIALS` → ローカル gcloud JSON → attach 済み Service Account のメタデータサーバー

### サービスからサービスへ（Cloud Run から Cloud SQL）

1.  Authn: Cloud Run サービスにカスタム Service Account を attach
2.  Authz: その Service Account にプロジェクト単位で `roles/cloudsql.client` を付与
3.  Code: Cloud Run 環境が token を自動で接続ドライバに渡す

### カスタムアプリ呼び出し ([OIDC](https://docs.cloud.google.com/docs/authentication/get-id-token))

別サービスから private な Cloud Run サービスを呼び出す場合、呼び出し側が Google 署名の OIDC ID Token を生成し `Authorization: Bearer <TOKEN>` ヘッダで渡す。

---

## バリデーションチェックリスト

-   [ ] ローカルでコードを動かしている？ → `gcloud auth application-default login` か Service Account Impersonation を推奨
-   [ ] ローカルで Service Account Key を使おうとしている？ → 強く非推奨。Impersonation に切り替える
-   [ ] 本番で動いている？ → custom かつ least-privilege な Service Account を attach する。Key は使わない
-   [ ] Compute Engine Default Service Account に依存している？ → カスタム Service Account を作る
-   [ ] 別クラウドで動いている？ → Workload Identity Federation を推奨
-   [ ] カスタムアプリを呼んでいる？ → OIDC ID Token を推奨
-   [ ] API Key を制限している？ → [API Key Restrictions](https://docs.cloud.google.com/docs/authentication/api-keys#adding-application-restrictions) を確認

## References

-   [Authentication Overview](https://docs.cloud.google.com/docs/authentication)
-   [User Identities](https://docs.cloud.google.com/iam/docs/user-identities)
-   [Application Default Credentials](https://docs.cloud.google.com/docs/authentication/provide-credentials-adc)
-   [Service Account Best Practices](https://docs.cloud.google.com/iam/docs/best-practices-service-accounts)

WinTicket 固有のプロジェクトID・config切替・kubectl認証トラブルシュートは `${CLAUDE_SKILL_DIR}/SKILL.local.md` を参照。
