# worktree 横断作業では絶対 path を使う

## ルール

`git-wt` で新規 worktree を作って作業する場合、`grep` / `sed` / `ls` / `find` 等の検索系コマンドには **絶対 path を渡す**。相対 path は使わない。

## なぜ

`git-wt suto-ryosuke/pf-XXXX origin/main` でブランチを作っても、Claude Code の cwd は元の場所 (多くはメインリポジトリ) のまま。Edit / Write は絶対 path 指定なので新 worktree 側に効くが、後から相対 path で grep / sed すると **メインリポジトリ側のファイル** を見続ける。

これにより:
- `Edit が反映されていない` と誤判定して同じ編集を繰り返す
- 確認用 grep が古いファイルを返してずっとクリーンにならない
- main の最新版と worktree の編集中ファイルが乖離していることに気付かない

## 推奨

```bash
# Bad: cwd のメインリポジトリ側を見ている可能性
grep -n "pattern" docs/plans/foo.md

# Good: 絶対 path で worktree 側を明示
grep -n "pattern" /Users/s32943/gh/github.com/<org>/<repo>/.worktrees/<branch>/docs/plans/foo.md
```

git コマンドも安全ではない。git は「cwd から見つかる worktree」に対して動くため、cwd がメインリポジトリのままなら `git status` / `git diff` / `git add` / `git commit` はすべてメインリポジトリ側を対象にする。worktree 側のファイルを絶対 path で `git add` しても、そのファイルはメインリポジトリの index には無関係な変更（多くは差分なし）なので **エラーにならず黙って空振りする**。

```bash
# Bad: cwd がメインリポジトリなら、絶対 path でもメインリポジトリ側の git が動く
git add /Users/s32943/gh/github.com/<org>/<repo>/.worktrees/<branch>/path/to/file.tf

# Good: worktree に cd してから git を叩く
cd /Users/s32943/gh/github.com/<org>/<repo>/.worktrees/<branch> && git add path/to/file.tf
```

`git add` の空振りは exit 0 で返るため気付きにくい。`git status --short` で staged 表示を必ず確認する。ステージ済みのはずのファイルが出てこなければ cwd を疑う。

誤判定が起きる範囲をまとめると、**シェルの cwd を起点にするコマンド全て** (grep / sed / find / cat / ls / git)。

## 例外

- `cd <worktree>` してからコマンドを叩く場合は相対 path で OK。ただし Claude Code 上の cwd 変更は session 内に閉じるため、新 Bash 呼び出しごとに `cd && grep` の形にするか、絶対 path を渡す方が安全
- Read tool は絶対 path 指定が必須なので影響を受けない

## 過去の事例

2026-07-27、CyberAgentCard/processing-infrastructure PFIF-123 の作業中。worktree `pfif-123-tier2-retrigger` で Edit した 2 ファイルを、`cd` せず絶対 path で `git add` した。cwd がメインリポジトリだったため main 側の git が動き、当該ファイルに差分が無いので exit 0 で何も起きなかった。`git status --short` が空だったことで気付き、メインリポジトリが clean であることを確認してから `cd <worktree> && git add` で再実行した。被害はなかったが確認に 2 往復かかった。

2026-04-30、PF-1956 (Phase 1 plan 改訂) の作業中。worktree `suto-ryosuke/pf-1956` で `Edit` が成功 (`successfully updated`) するのに、その後の grep `docs/plans/phase-1-infra-bootstrap.md` で旧記述が表示され続けた。実体は cwd (メインリポジトリ) 側の plan を grep していたためで、Edit は worktree 側に正しく反映されていた。Edit を何度も再実行して無駄に時間を費やした。
