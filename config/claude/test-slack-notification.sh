#!/usr/bin/env bash
# Slack通知JSON構築の自動テストスクリプト

set -euo pipefail

# テスト結果カウンター
TESTS_PASSED=0
TESTS_FAILED=0

# テストヘルパー関数
test_json_construction() {
    local test_name="$1"
    local status_emoji="$2"
    local avg_score="$3"
    local sec_score="$4"
    local qual_score="$5"
    local eff_score="$6"
    local summary="$7"
    local issues="$8"
    local repo_info="$9"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test: $test_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Issues整形（codex-review.shと同じロジック）
    local issues_text=""
    if [[ -n "$issues" ]]; then
        local count=0
        while IFS= read -r issue && [[ $count -lt 5 ]]; do
            issues_text="${issues_text}• ${issue}"$'\n'
            count=$((count + 1))
        done <<< "$issues"
    fi

    # JSON構築（codex-review.shと同じロジック）
    local text_header="${status_emoji} Codex Review完了"
    local text_repo="📁 *${repo_info}*"
    local text_score=$'*総合スコア*\n*'"${avg_score}"$'*/100'
    local text_details=$'*詳細*\n🔒 Security: '"${sec_score}"$'\n💎 Quality: '"${qual_score}"$'\n⚡ Efficiency: '"${eff_score}"

    local slack_payload
    slack_payload=$(jq -n \
        --arg text "$text_header" \
        --arg repo "$text_repo" \
        --arg score "$text_score" \
        --arg details "$text_details" \
        '{
            "text": $text,
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": $text
                    }
                },
                {
                    "type": "context",
                    "elements": [
                        {
                            "type": "mrkdwn",
                            "text": $repo
                        }
                    ]
                },
                {
                    "type": "section",
                    "fields": [
                        {
                            "type": "mrkdwn",
                            "text": $score
                        },
                        {
                            "type": "mrkdwn",
                            "text": $details
                        }
                    ]
                }
            ]
        }')

    # サマリーブロックを追加
    if [[ -n "$summary" ]]; then
        local text_summary=$'*サマリー*\n'"${summary}"
        slack_payload=$(echo "$slack_payload" | jq \
            --arg summary "$text_summary" \
            '.blocks += [{
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": $summary
                }
            }]')
    fi

    # Issuesブロックを追加
    if [[ -n "$issues_text" ]]; then
        local text_issues=$'*Issues*\n'"${issues_text}"
        slack_payload=$(echo "$slack_payload" | jq \
            --arg issues "$text_issues" \
            '.blocks += [{
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": $issues
                }
            }]')
    fi

    # JSON妥当性検証
    if ! echo "$slack_payload" | jq empty 2>/dev/null; then
        echo "❌ FAILED: Invalid JSON generated"
        echo "Payload preview: ${slack_payload:0:200}..."
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    # 改行が正しくエスケープされているか検証
    local score_text
    score_text=$(echo "$slack_payload" | jq -r '.blocks[2].fields[0].text')
    if [[ "$score_text" != *$'\n'* ]]; then
        echo "❌ FAILED: Newlines not preserved in score text"
        echo "Got: $score_text"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    echo "✅ PASSED: Valid JSON with correct newlines"
    echo "Sample output:"
    echo "$slack_payload" | jq -C '.blocks[2].fields[0].text' 2>/dev/null || echo "$score_text"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# テストケース1: 通常の文字列
test_json_construction \
    "Normal strings" \
    "✅" "85" "90" "85" "80" \
    "良好なコード品質です。" \
    "Issue 1: test
Issue 2: another test" \
    "dotfiles"

# テストケース2: ダブルクォートを含む文字列
test_json_construction \
    "Strings with double quotes" \
    "✅" "85" "90" "85" "80" \
    "\"quotes\" を含むサマリーです。" \
    "Issue 1: contains \"quotes\"
Issue 2: more \"test\" data" \
    "dotfiles"

# テストケース3: バックスラッシュを含む文字列
test_json_construction \
    "Strings with backslashes" \
    "✅" "85" "90" "85" "80" \
    "パス \\path\\to\\file を含みます。" \
    "Issue 1: path\\to\\file
Issue 2: C:\\Windows\\System32" \
    "dotfiles"

# テストケース4: 複合的な特殊文字
test_json_construction \
    "Mixed special characters" \
    "⚠️" "65" "70" "65" "60" \
    "複雑な\"文字列\"\\nバックスラッシュ\\tタブ'シングルクォート'を含む。" \
    "Issue 1: \"quoted\" value
Issue 2: path\\to\\file
Issue 3: mixed 'quotes' and \\backslash" \
    "test-repo"

# テストケース5: 空のサマリーとIssues
test_json_construction \
    "Empty summary and issues" \
    "✅" "90" "95" "90" "85" \
    "" \
    "" \
    "empty-repo"

# テスト結果サマリー
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Results Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Passed: $TESTS_PASSED"
echo "❌ Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "⚠️  Some tests failed"
    exit 1
fi
