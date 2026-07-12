---
name: aws-cli-sandbox
description: >-
  sandbox環境でAWS CLIコマンドを叩いたときの認証エラー対処と、SAMLフェデレーション認証の時間制限を扱う。
  「Unable to locate credentials」「aws sts」「aws-bastion」「assume-role-with-saml」
  「SAMLアサーション」「ExpiredTokenException」「Token must be redeemed」等のキーワード、
  またはAWS CLIコマンドの実行に失敗した場面で起動する。
user-invocable: false
allowed-tools:
  - Bash
---

# aws-cli-sandbox - AWS CLIとsandbox制限

## 症状

sandbox環境で `aws` コマンドを叩くと、認証情報が実在するのに以下のエラーになる。

```
Unable to locate credentials. You can configure credentials by running "aws login".
```

## 原因

sandboxのファイル読み取り制限で `~/.aws/credentials` が明示的に deny 対象になっている。AWS API へのネットワークアクセス（`sts.amazonaws.com` 等）も既定の許可リストに含まれていないため、通常の sandbox 実行では認証情報の読み取りとAPI疎通の両方が失敗しうる。

`gcloud` / `gh` 等と違い、AWS CLI はこの制限に無条件で引っかかる。sandbox が原因の失敗であって、認証情報そのものが壊れているわけではない、と判断する材料として記録する。

対処は毎回そのコマンド固有の状況を見て判断する。上記のエラーメッセージが出た時点でsandbox起因と判定し、必要なら `dangerouslyDisableSandbox: true` での再実行を検討する。

## SAML フェデレーション認証の時間制限

`aws sts assume-role-with-saml` で使う SAML アサーションは、発行 (`IssueInstant`) から概ね5分以内に redeem しないと `ExpiredTokenException: Token must be redeemed within 5 minutes of issuance` になる。

- ユーザーがSAMLアサーションを生成してからチャットに貼るまでに数分かかると、その時点で期限切れになっていることがある
- 期限切れの場合は「もう一度SAMLログインをやり直して新しいアサーションを発行してほしい」とすぐ伝える。古いアサーションのリトライは無意味
- `assume-role-with-saml` で得た一時credentialsは `--duration-seconds` で指定した秒数（例: 900秒 = 15分）は有効。アサーション自体の5分制限とは別物

## 実例

WinTicket Wiz HIGH特権コンテナの実態確認でAWS IAM/EC2をread-onlyで確認する際に発生。

1. `aws sts get-caller-identity` が sandbox内で `Unable to locate credentials` → エラーメッセージからsandbox起因と判断し、都度確認のうえ `dangerouslyDisableSandbox: true` で再実行して解決
2. ユーザーが貼った `assume-role-with-saml` コマンドのSAMLアサーションが発行から時間が経っていて `ExpiredTokenException` → 再ログインを依頼し、新しいアサーションで再実行して解決

## Gotchas

- 認証情報をチャットに貼る運用そのものについては、短命トークン（5分限定のアサーション、15分程度のセッション）かつ read-only ロール限定であれば実害は小さいが、可能なら「認証した」とだけ伝えてもらい、資格情報の中身は貼らせない方が望ましい
- WinTicket AWSアカウントの構成（account ID・SAML provider・role名）は `${CLAUDE_SKILL_DIR}/SKILL.local.md` を参照
