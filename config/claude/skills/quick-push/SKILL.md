---
name: quick-push
description: 変更を素早くコミット＆プッシュして日常作業を効率化。「push」「プッシュ」「コミットして」「上げといて」「反映して」「pushして」等で起動。
user-invocable: true
disable-model-invocation: true
allowed-tools:
  - Bash(git:*)
  - Bash(gh:*)
---

# /quick-push - 変更を素早くコミット＆プッシュ

## 目的
現在の変更を素早くコミットしてリモートにプッシュします。日常的な作業の効率化に最適です。

## 動作
1. `git status`で現在の変更を表示
2. このセッションで自分が変更・作成したファイルのみを対象にする（会話履歴から判断）
   - セッション前から存在するunstaged変更は対象外
   - 判断に迷う場合はユーザーに確認する
3. main/masterブランチの場合は `wt.allowDirectCommit` を確認（詳細は下記「main直コミット判定」）
4. 危険なファイル（.env、secrets、credentials等）を除外
5. 対象ファイルのみを`git add`
6. シークレットスキャン: ステージ済み diff に機密情報パターンが含まれていないか確認（詳細は下記「シークレットスキャン」）
7. private情報チェック: 会社ドメインメアド・社内プロジェクトIDなど、publicリポに残してはいけない情報が含まれていないか警告（詳細は下記「private情報チェック」）
8. 変更内容を分析して適切なprefixを選択：
   - `feat:` 新機能追加
   - `fix:` バグ修正
   - `docs:` ドキュメント変更
   - `style:` フォーマット修正
   - `refactor:` リファクタリング
   - `test:` テスト追加・修正
   - `chore:` その他の変更
9. コミットメッセージを表示して確認
10. PRマージ済みチェック（push前）
11. 現在のブランチをリモートにプッシュ
12. dotfilesリポからの実行時は dotfiles-private の変更も確認・push（詳細は下記「dotfiles-private 連動push」）
13. mainブランチ以外の場合、PR作成を提案

## main直コミット判定

現在のブランチが`main`/`master`だった場合、worktree作成やブランチ切り替えを提案する前に必ず以下を確認する。

```bash
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" == "main" ]] || [[ "$current_branch" == "master" ]]; then
    allow=$(git config --get wt.allowDirectCommit 2>/dev/null)
    if [[ "$allow" == "true" ]]; then
        # そのまま直コミット可。worktree作成/ブランチ切替は提案しない
        :
    else
        # worktree作成を提案する（CLAUDE.mdのworktree必須ルール）
        echo "main直コミットはブロックされています。worktreeを作成します"
    fi
fi
```

なぜこのチェックが必要か: CLAUDE.mdは「ブランチ作業はworktree必須」と書かれているが、dotfilesなど個人リポジトリでは `wt.allowDirectCommit=true` でopt-outされている。ルールの禁止側だけ見てworktree作成に進むと、opt-outされたリポジトリで無駄なworktreeを作ってユーザーを待たせる。**worktreeフローに入る前に必ずこの設定を確認する**。

## シークレットスキャン

`git add` 後、コミット前に追加行（`+` 行）のみを対象に簡易シークレット検出を行う。`git/hooks/pre-commit` のシークレットスキャンは main/master ブランチでしか動かないため、feature ブランチでの保護はここで担保する。

```bash
patterns='AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9_]{82}|xox[bp]-[0-9]+-[a-zA-Z0-9]+|hooks\.slack\.com/services/T[A-Z0-9]+|ya29\.[0-9A-Za-z_-]+|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----|password\s*[:=]\s*["\x27][^"\x27]{8,}|secret\s*[:=]\s*["\x27][^"\x27]{8,}'

# diff の追加行のみ対象（先頭 + で始まり、+++ ヘッダは除く）
matches=$(git diff --cached -U0 | grep -nE "^\+[^+].*($patterns)" 2>/dev/null || true)

if [[ -n "$matches" ]]; then
    echo "シークレットらしき文字列を検出しました。push を中止します:"
    echo "$matches" | head -10
    # ユーザーに「誤検知なのでそのまま進めるか」確認する
    # 続行する場合のみ次のステップへ
fi
```

検出時は必ずユーザーに確認を取る。誤検知の場合だけ進める。`--no-verify` は提案しない（pre-commit がバイパスされるため）。

## private情報チェック

publicリポジトリ（dotfilesなど）に会社・組織固有の情報が混入することを防ぐ。シークレットスキャンと違い誤検知が多いため**警告のみで続行可能**にする。検出されたらユーザーに「このまま進めるか」を確認する。

対象パターンは `dotfiles-security-check` の項目7（private情報の混入チェック）と同じ。

```bash
private_patterns='[a-zA-Z0-9._%+-]+@(cyberagent|winticket|cloud-identity|perman)\.[a-zA-Z.]+|\b(billioon-[a-zA-Z0-9-]+|winticket-(stg|dev|workspace|firebase|shared|dev-firebase))\b|[a-zA-Z0-9-]+\.(kibe\.la|cybozu\.com|atlassian\.net|backlog\.com)|\b[CG][A-Z0-9]{8,11}\b|[a-z0-9-]+\.slack\.com/archives/|arn:aws:[a-z0-9-]+::[0-9]{12}:|https?://[a-zA-Z0-9.-]+\.(internal|local|corp|cyberagent\.co\.jp|winticket\.co\.jp)'

private_matches=$(git diff --cached -U0 | grep -nE "^\+[^+].*($private_patterns)" 2>/dev/null || true)

if [[ -n "$private_matches" ]]; then
    echo "private情報の可能性がある記述を検出しました（誤検知の可能性あり）:"
    echo "$private_matches" | head -10
    # ユーザーに「このまま進めるか / 該当箇所を修正するか」を確認
    # 修正案: メアドは @example.com、プロジェクトIDや組織固有の値は private/local ファイルに移す
fi
```

判断基準:
- 公式公開URL（`https://www.cyberagent.co.jp/corporate/...` 等）や組織名のみの言及（`WinTicket org`）は許容
- 実在のメアド・GCPプロジェクトID・SlackチャンネルID・内部ホストは要対応
- privateリポ（`dotfiles-private` 等）への commit ではこのチェックは不要だが、誤って動作しても警告のみなので無害

## PRマージ済みチェックの実装手順

コミット後、push前に以下のチェックを必ず実行：

```bash
current_branch=$(git rev-parse --abbrev-ref HEAD)

if [[ "$current_branch" != "main" ]] && [[ "$current_branch" != "master" ]]; then
    pr_info=$(gh pr list --head "$current_branch" --state all --json number,state,title 2>/dev/null)

    if [[ -n "$pr_info" ]] && [[ "$pr_info" != "[]" ]]; then
        pr_state=$(echo "$pr_info" | jq -r '.[0].state')
        pr_number=$(echo "$pr_info" | jq -r '.[0].number')
        pr_title=$(echo "$pr_info" | jq -r '.[0].title')

        if [[ "$pr_state" == "MERGED" ]]; then
            echo "Warning: このブランチのPRはすでにマージ済みです"
            echo "  ブランチ: $current_branch"
            echo "  PR #$pr_number: $pr_title"
            # ユーザーに確認を求める
        fi
    fi
fi
```

## 安全機能
- 機密ファイルの自動除外
- mainブランチへの直接プッシュ時は警告
- PRマージ済みブランチへのpush防止
- force pushが必要な場合は確認
- 大量のファイル変更時は要確認

## 使用例
```
/quick-push
```

## worktree環境での動作

worktree内で実行した場合、PRマージ済みチェック後に以下を提案:

```bash
# 現在のディレクトリがworktreeか確認
current_dir=$(pwd)
wt_info=$(git worktree list | grep "^$current_dir ")

if [[ -n "$wt_info" ]] && [[ "$pr_state" == "MERGED" ]]; then
    echo "このworktreeを削除しますか？"
    echo "  git-wt remove $(basename $current_dir)"
fi
```

## dotfiles-private 連動push

dotfiles リポからの quick-push 完了後、`~/gh/github.com/ryosukesuto/dotfiles-private` に未コミット変更があれば、同じフローで連動 push する。dotfiles の rules/skill を編集すると、対応する `*.local.md` を private 側に置くことが多いため、片側だけ push してもう片方を忘れる事故を防ぐ。

```bash
repo_root=$(git rev-parse --show-toplevel)
if [[ "$(basename "$repo_root")" == "dotfiles" ]]; then
    private_dir="$HOME/gh/github.com/ryosukesuto/dotfiles-private"
    if [[ -d "$private_dir/.git" ]]; then
        private_changes=$(git -C "$private_dir" status --porcelain)
        if [[ -n "$private_changes" ]]; then
            echo "dotfiles-private にも未コミット変更があります:"
            git -C "$private_dir" status --short
            # ユーザーに「連動して push するか」を確認
        fi
    fi
fi
```

連動 push する場合の方針:
- private repo 内で同じフロー（危険ファイル除外 → `git add` → シークレットスキャン → コミット → push）を適用する
- private情報チェックは**スキップ**（private repo なので原理的に不要）
- main 直 push は OK（dotfiles-private は `wt.allowDirectCommit=true` 想定の個人リポ）
- コミットメッセージは dotfiles 側と同じ語彙で揃える（同一の作業文脈なので）
- private 側の push に失敗しても、dotfiles 側の push は完了済みなのでロールバックは不要。失敗内容だけユーザーに伝える

## 注意事項
PRマージ後にエラーが発生した場合:
- マージ済みのブランチにはpushしない
- 新しいブランチを作成して、そこで修正を行う
- worktree環境の場合は、worktreeを削除してから新しいworktreeを作成

## Gotchas

- `wt.allowDirectCommit=true` のリポジトリ（dotfiles等）でworktree作成を提案しない。CLAUDE.mdの「worktree必須」はopt-out前提のルール。main/masterブランチに入ったら即座に worktree を作ろうとせず、先に `git config --get wt.allowDirectCommit` を確認する
