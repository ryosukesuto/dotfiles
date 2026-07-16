#!/usr/bin/env python3
"""校正対象テキストのパターン違反を機械的にカウントする。

使い方:
  python3 check.py <file>
  python3 check.py <file> --json
  python3 check.py <file> --pr-review [--json]

コードブロック・インラインコード・URL は対象外。
"""
import json
import re
import sys
from pathlib import Path


PARTICLES = "のをがはとでにへやもから"
REQUEST_CUES = re.compile(
    r"(?:お願い|もらえると|もらえますか|いただけると|いただけますか|"
    r"してほしい|したいです|いかがでしょうか|できますか)"
)


def mask_protected(content: str) -> str:
    """カウント対象から除外する箇所を空文字に置換する。"""
    content = re.sub(r"```[\s\S]*?```", "", content)
    content = re.sub(r"`[^`\n]*`", "", content)
    content = re.sub(r"https?://\S+", "", content)
    return content


def extract_review_drafts(content: str) -> list[str]:
    """レポート内のレビュー草案を抽出。単独コメントなら全文を1草案とする。"""
    drafts = re.findall(
        r"(?ms)^#{2,6}[ \t]+レビュー草案[ \t]*\n+(.*?)(?=^#{1,6}[ \t]+|\Z)",
        content,
    )
    if not drafts:
        return [content]
    return [re.sub(r"(?m)^>[ \t]?", "", draft).strip() for draft in drafts]


def count_violations(path: Path, pr_review: bool = False) -> dict:
    raw = path.read_text(encoding="utf-8")
    masked = mask_protected(raw)

    # 1) 箇条書きの「ラベル: 説明文」
    bullet_label = len(re.findall(r"(?m)^- [^:\n]+: ", masked))

    # 2) 散文中の「ラベル: 」(行頭が `- ` `#` `|` 以外)
    inline_label = len(
        re.findall(r"(?m)^[^|#\-\s][^:\n]*: [^/\n]", masked)
    )

    # 3) 日英間スペース (助詞 + 英単語)
    ja_to_en = len(re.findall(rf"[{PARTICLES}] +[A-Za-z]", masked))

    # 4) 日英間スペース (英単語/閉じ括弧 + 助詞)
    en_to_ja = len(re.findall(rf"[A-Za-z\)\]] +[{PARTICLES}]", masked))

    # 5) 「」での強調 (引用以外で多用されると違反)
    quote_emphasis = len(re.findall(r"「[^」\n]+」", masked))

    # 6) （）での補足
    paren_supplement = len(re.findall(r"（[^）\n]+）", masked))

    counts = {
        "bullet_label": bullet_label,
        "inline_label": inline_label,
        "ja_to_en_space": ja_to_en,
        "en_to_ja_space": en_to_ja,
        "quote_emphasis": quote_emphasis,
        "paren_supplement": paren_supplement,
    }

    if pr_review:
        drafts = [mask_protected(draft).strip() for draft in extract_review_drafts(raw)]
        counts.update({
            "severity_terms": len(re.findall(
                r"(?i)(?:must-fix|should-fix|\bwatch\b|\bP[0-3]\b)", masked
            )),
            "internal_process": len(re.findall(
                r"(?i)(?:review-pr|proofread|triage|dedupe|codex-baseline|opus-baseline|"
                r"review-server|security-review-(?:opus|codex)|cross-repo|finding-normalizer)",
                masked,
            )),
            "strong_directive": len(re.findall(r"ください", masked)),
            "space_before_emoji": len(re.findall(r"\s+🙏", masked)),
            "bold_emphasis": len(re.findall(r"\*\*[^*\n]+\*\*", masked)),
            "missing_request_emoji": sum(
                1 for draft in drafts
                if REQUEST_CUES.search(draft) and not draft.endswith("🙏")
            ),
            "emoji_not_at_end": sum(
                1 for draft in drafts
                if "🙏" in draft and not draft.endswith("🙏")
            ),
        })

    return counts


def render_table(counts: dict, pr_review: bool = False) -> str:
    rows = [
        ("箇条書きラベル `- xxx: 説明`", counts["bullet_label"]),
        ("散文中ラベル `xxx: 説明`", counts["inline_label"]),
        ("日英間スペース (助詞→英単語)", counts["ja_to_en_space"]),
        ("日英間スペース (英単語→助詞)", counts["en_to_ja_space"]),
        ("「」での強調", counts["quote_emphasis"]),
        ("（）での補足", counts["paren_supplement"]),
    ]
    if pr_review:
        rows.extend([
            ("内部用の優先度ラベル", counts["severity_terms"]),
            ("レビュー内部の処理名", counts["internal_process"]),
            ("強い依頼 `〜ください`", counts["strong_directive"]),
            ("`🙏`直前のスペース", counts["space_before_emoji"]),
            ("太字による強調", counts["bold_emphasis"]),
            ("お願いに対する文末`🙏`の不足", counts["missing_request_emoji"]),
            ("文末以外の`🙏`", counts["emoji_not_at_end"]),
        ])
    lines = ["| パターン | 件数 |", "|---|---|"]
    for label, count in rows:
        if pr_review and label in {
            "内部用の優先度ラベル",
            "レビュー内部の処理名",
            "強い依頼 `〜ください`",
            "`🙏`直前のスペース",
            "太字による強調",
            "お願いに対する文末`🙏`の不足",
            "文末以外の`🙏`",
        }:
            flag = " ⚠️ 要修正" if count > 0 else ""
        else:
            flag = " ⚠️ 10件超" if count > 10 else ""
        lines.append(f"| {label} | {count}{flag} |")
    return "\n".join(lines)


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print("usage: check.py <file> [--json] [--pr-review]", file=sys.stderr)
        return 1

    path = Path(args[0])
    as_json = "--json" in args
    pr_review = "--pr-review" in args

    if not path.exists():
        print(f"file not found: {path}", file=sys.stderr)
        return 1

    counts = count_violations(path, pr_review=pr_review)

    if as_json:
        print(json.dumps(counts, ensure_ascii=False, indent=2))
    else:
        print(render_table(counts, pr_review=pr_review))
        over_threshold = [k for k, v in counts.items() if v > 10]
        if over_threshold:
            print(
                "\n10 件超のパターンあり。修正前にユーザーに方針確認すること: "
                + ", ".join(over_threshold)
            )
        if pr_review:
            pr_specific = [
                k for k in (
                    "severity_terms",
                    "internal_process",
                    "strong_directive",
                    "space_before_emoji",
                    "bold_emphasis",
                    "missing_request_emoji",
                    "emoji_not_at_end",
                )
                if counts.get(k, 0) > 0
            ]
            if pr_specific:
                print(
                    "\nPRレビュー向けの除去対象あり: " + ", ".join(pr_specific)
                )

    return 0


if __name__ == "__main__":
    sys.exit(main())
