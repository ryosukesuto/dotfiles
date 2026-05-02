# Terraform で IAM binding / log sink を destroy する時のチェック

`google_*_iam_member` (non-authoritative) や `google_logging_project_sink` を destroy する Terraform PR では、共有所有問題で他 stack を巻き込む事故が起きやすい。plan を読む段階で必ず以下を確認する。

## 共有 IAM binding の destroy 巻き込み

`google_project_iam_member` などの non-authoritative リソースは「同じ `(project, role, member)` tuple を複数 module / stack で管理する」と、いずれかが destroy された時に GCP 側の binding 1 個が消えて、他 stack が依存していた権限が一斉に失われる。

### 確認手順

1. plan 出力で destroy 対象の `google_*_iam_member` の `member` を抽出
2. その member 文字列を terraform/ 配下で grep:

```bash
grep -rn "<member 文字列の特徴的部分>" --include='*.tf' terraform/
```

3. 複数箇所でヒット → 共有所有状態。destroy で消えると他 sink / Cloud Run / KSA が PERMISSION_DENIED で停止する
4. 対応:
   - 「権威的な所有者を 1 stack に集約」する PR を先に出してから destroy
   - または destroy する PR で binding を独立 stack に明示的に保持してから消す

### 特に注意する member パターン

- GCP default service agent (`service-{project_number}@gcp-sa-*.iam.gserviceaccount.com`) — 複数機能で共有されやすい
- log sink の writer identity — `unique_writer_identity = true` でも既存 sink は legacy default SA のままの drift がよくある
- GitHub Actions / Workload Identity 系 principal — 複数 stack で同じ principal を使う

## log sink の writer identity drift

`google_logging_project_sink.unique_writer_identity` を `true` に変更しても、既存 sink の writerIdentity は GCP API では rotate されない（新規作成時のみ反映）。terraform state では `true` だが GCP 上では legacy default SA のままという drift が発生する。

実態を見るには `gcloud logging sinks describe <name>` で実 `writerIdentity` を確認する。コードの設定を信用しない。

## 過去の事故 (2026-05-01)

ops#7047 で `module.purge_failed_log_sink` を destroy したところ、log sink 6 種 (mine-log / spanner-backup-log / request-replication / cashless-replication / bigquery-audit-log / wiz-audit-logs) の publish が `topic_permission_denied` で停止した。

原因: `module.purge_failed_log_sink.google_project_iam_member.default` が `service-{project_number}@gcp-sa-logging` への `roles/pubsub.publisher` を管理していたが、同じ default SA に依存する他の log sink module が複数あった共有状態で、destroy で binding が消えた。

復旧: ops#7056 で `terraform/gcp/server/iam/common/iam.tf` に独立 binding を追加。

## 関連 Issue

- WinTicket/ops PF-1977: log sink の writer identity 集約と unique_writer_identity 化（恒久対応）
