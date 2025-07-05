#!/usr/bin/env zsh
# ============================================================================
# obsidian-claude.zsh - Obsidian-Claude連携関数
# ============================================================================
# このファイルはObsidianとClaude Codeを連携させる関数を提供します。
# 参考: https://www.m3tech.blog/entry/2025/06/29/110000

# ============================================================================
# 共通設定
# ============================================================================
OBSIDIAN_VAULT_PATH="${OBSIDIAN_VAULT_PATH:-$HOME/src/github.com/ryosukesuto/obsidian-notes}"
OBSIDIAN_CLAUDE_DIR="$OBSIDIAN_VAULT_PATH/Claude"
OBSIDIAN_TASK_DIR="$OBSIDIAN_CLAUDE_DIR/Tasks"
OBSIDIAN_MEETING_DIR="$OBSIDIAN_CLAUDE_DIR/Meetings"

# 必要なディレクトリを作成
_ensure_obsidian_dirs() {
    mkdir -p "$OBSIDIAN_CLAUDE_DIR"
    mkdir -p "$OBSIDIAN_TASK_DIR"
    mkdir -p "$OBSIDIAN_MEETING_DIR"
}

# ============================================================================
# obsc - Claude会話を保存
# ============================================================================
# 使用方法: obsc [タイトル]
# Claude Codeの現在の会話内容をObsidianに保存します
obsc() {
    _ensure_obsidian_dirs
    
    local title="$*"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local date_human=$(date "+%Y-%m-%d %H:%M")
    
    # タイトルが指定されていない場合は対話的に入力
    if [[ -z "$title" ]]; then
        echo -n "会話のタイトルを入力してください: "
        read title
        if [[ -z "$title" ]]; then
            title="Claude会話_${timestamp}"
        fi
    fi
    
    # ファイル名を生成（スペースをアンダースコアに置換）
    local filename="${timestamp}_${title// /_}.md"
    local filepath="$OBSIDIAN_CLAUDE_DIR/$filename"
    
    # Claude Codeで実行されているか確認
    if [[ -z "$CLAUDE_CHAT_ID" ]] && [[ -z "$CLAUDE_PROJECT_PATH" ]]; then
        echo "⚠️  警告: Claude Code環境で実行されていない可能性があります"
        echo "Claude Codeで '/save' コマンドを使用することを推奨します"
    fi
    
    # マークダウンテンプレートを作成
    cat > "$filepath" << EOF
# ${title}

## 📅 メタデータ
- **日時**: ${date_human}
- **タグ**: #claude #ai-conversation
- **プロジェクト**: ${CLAUDE_PROJECT_PATH:-不明}

## 📝 概要
<!-- 会話の目的や結果を簡潔に記載 -->

## 💬 会話内容
<!-- Claude Codeから会話をエクスポートして貼り付け -->

### 質問/依頼


### Claude の回答


## 🔑 重要なポイント
<!-- 会話から得られた重要な知見やコード -->

## 📌 今後のアクション
<!-- この会話を受けて行うべきタスク -->

## 🔗 関連リンク
<!-- 参考になるリンクや関連するノート -->

---
*Created by obsc command at ${date_human}*
EOF

    echo "✅ Claude会話テンプレートを作成しました:"
    echo "   $filepath"
    echo ""
    echo "次のステップ:"
    echo "1. Claude Codeで会話をコピー"
    echo "2. Obsidianで上記ファイルを開いて内容を貼り付け"
    echo "3. 必要に応じて編集・整理"
    
    # macOSの場合、ファイルパスをクリップボードにコピー
    if command -v pbcopy &> /dev/null; then
        echo "$filepath" | pbcopy
        echo ""
        echo "💡 ファイルパスをクリップボードにコピーしました"
    fi
}

# ============================================================================
# obs-task - タスクノートを作成
# ============================================================================
# 使用方法: obs-task [タスク名]
# Claude Codeで作業するタスクのノートを作成します
obs-task() {
    _ensure_obsidian_dirs
    
    local task_name="$*"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local date_human=$(date "+%Y-%m-%d %H:%M")
    local date_only=$(date +%Y-%m-%d)
    
    # タスク名が指定されていない場合は対話的に入力
    if [[ -z "$task_name" ]]; then
        echo -n "タスク名を入力してください: "
        read task_name
        if [[ -z "$task_name" ]]; then
            echo "エラー: タスク名は必須です"
            return 1
        fi
    fi
    
    # ファイル名を生成
    local filename="${date_only}_${task_name// /_}.md"
    local filepath="$OBSIDIAN_TASK_DIR/$filename"
    
    # タスクテンプレートを作成
    cat > "$filepath" << EOF
# 🎯 ${task_name}

## 📅 基本情報
- **作成日**: ${date_human}
- **ステータス**: 🔄 進行中
- **優先度**: 🔥 高 / 🌊 中 / ❄️ 低
- **期限**: 
- **タグ**: #task #claude-task

## 🎯 目的・ゴール
<!-- このタスクで達成したいことを明確に記載 -->

## 📋 要件・制約
<!-- タスクの要件や制約条件を箇条書きで -->
- [ ] 要件1
- [ ] 要件2

## 🛠️ 実装計画
<!-- Claude Codeでの作業計画 -->
1. [ ] ステップ1
2. [ ] ステップ2
3. [ ] ステップ3

## 💻 Claude Code セッション
<!-- Claude Codeでの作業記録 -->
### セッション1 - ${date_human}
- **目的**: 
- **結果**: 
- **次回**: 

## 📝 作業ログ
<!-- 作業の進捗や重要な決定事項を記録 -->
### ${date_human}
- 

## 🐛 課題・問題点
<!-- 発生した問題と解決策 -->

## 📚 参考資料
<!-- 参考にしたドキュメントやリンク -->
- 

## ✅ 完了条件
<!-- タスクが完了したと判断する条件 -->
- [ ] 条件1
- [ ] 条件2

---
*Created by obs-task command at ${date_human}*
EOF

    echo "✅ タスクノートを作成しました:"
    echo "   $filepath"
    echo ""
    echo "💡 ヒント:"
    echo "- Claude Codeで作業開始前にこのノートを開いておくと便利です"
    echo "- 作業ログは都度更新して進捗を記録しましょう"
    echo "- 完了後は obsc コマンドで会話も保存することをお勧めします"
    
    # macOSの場合、ファイルを開く
    if command -v open &> /dev/null; then
        echo ""
        echo -n "Obsidianでファイルを開きますか？ (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            open "obsidian://open?vault=$(basename "$OBSIDIAN_VAULT_PATH")&file=$(echo "$filepath" | sed "s|$OBSIDIAN_VAULT_PATH/||")"
        fi
    fi
}

# ============================================================================
# obs-meeting - 会議メモを作成
# ============================================================================
# 使用方法: obs-meeting [会議名]
# 技術的な議論やペアプロのメモを作成します
obs-meeting() {
    _ensure_obsidian_dirs
    
    local meeting_name="$*"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local date_human=$(date "+%Y-%m-%d %H:%M")
    local date_only=$(date +%Y-%m-%d)
    
    # 会議名が指定されていない場合は対話的に入力
    if [[ -z "$meeting_name" ]]; then
        echo -n "会議名を入力してください: "
        read meeting_name
        if [[ -z "$meeting_name" ]]; then
            meeting_name="技術相談_${timestamp}"
        fi
    fi
    
    # ファイル名を生成
    local filename="${date_only}_${meeting_name// /_}.md"
    local filepath="$OBSIDIAN_MEETING_DIR/$filename"
    
    # 会議テンプレートを作成
    cat > "$filepath" << EOF
# 📅 ${meeting_name}

## 🔍 基本情報
- **日時**: ${date_human}
- **参加者**: 自分、Claude
- **種類**: 🧑‍💻 ペアプロ / 💬 技術相談 / 📊 設計レビュー
- **タグ**: #meeting #claude-pair-programming

## 🎯 アジェンダ・目的
<!-- 会議の目的や議論したいトピック -->
1. 
2. 

## 💡 議論内容
<!-- 主要な議論ポイントと結論 -->

### トピック1: 
- **課題**: 
- **提案**: 
- **結論**: 

### トピック2: 
- **課題**: 
- **提案**: 
- **結論**: 

## 💻 コード・技術的詳細
<!-- 議論で出たコードや技術的な詳細 -->
\`\`\`language
// コードサンプル
\`\`\`

## 🎬 アクションアイテム
<!-- 会議後に実行すべきタスク -->
- [ ] タスク1 - 担当: 自分 - 期限: 
- [ ] タスク2 - 担当: Claude支援 - 期限: 

## 📝 メモ・備考
<!-- その他のメモや気づき -->

## 🔗 関連リソース
<!-- 参考資料やリンク -->
- 

## 📊 振り返り
<!-- 会議の効果や改善点 -->
- **良かった点**: 
- **改善点**: 
- **次回への申し送り**: 

---
*Created by obs-meeting command at ${date_human}*
EOF

    echo "✅ 会議メモを作成しました:"
    echo "   $filepath"
    echo ""
    echo "💡 使い方のヒント:"
    echo "- ペアプロ開始前に作成して、リアルタイムで記録"
    echo "- 技術的な決定事項は必ず記録"
    echo "- コードスニペットは後で参照できるように保存"
    
    # macOSの場合、ファイルパスをクリップボードにコピー
    if command -v pbcopy &> /dev/null; then
        echo "$filepath" | pbcopy
        echo ""
        echo "💡 ファイルパスをクリップボードにコピーしました"
    fi
}

# ============================================================================
# ヘルパー: 最近のClaude関連ノートを表示
# ============================================================================
obs-claude-recent() {
    echo "📚 最近のClaude関連ノート:"
    echo ""
    
    if [[ -d "$OBSIDIAN_CLAUDE_DIR" ]]; then
        echo "## 会話ログ:"
        ls -lt "$OBSIDIAN_CLAUDE_DIR"/*.md 2>/dev/null | head -5 | awk '{print "  - " $9}'
    fi
    
    if [[ -d "$OBSIDIAN_TASK_DIR" ]]; then
        echo ""
        echo "## タスク:"
        ls -lt "$OBSIDIAN_TASK_DIR"/*.md 2>/dev/null | head -5 | awk '{print "  - " $9}'
    fi
    
    if [[ -d "$OBSIDIAN_MEETING_DIR" ]]; then
        echo ""
        echo "## 会議メモ:"
        ls -lt "$OBSIDIAN_MEETING_DIR"/*.md 2>/dev/null | head -5 | awk '{print "  - " $9}'
    fi
}

# エイリアスを設定
alias obs-recent=obs-claude-recent