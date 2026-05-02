#!/usr/bin/env python3
"""校正対象テキストのパターン違反を機械的にカウントする。

使い方:
  python3 check.py <file>
  python3 check.py <file> --json

コードブロック・インラインコード・URL は対象外。
"""
import json
import re
import sys
from pathlib import Path


PARTICLES = "のをがはとでにへやもから"


def mask_protected(content: str) -> str:
    """カウント対象から除外する箇所を空文字に置換する。"""
    content = re.sub(r"```[\s\S]*?```", "", content)
    content = re.sub(r"`[^`\n]*`", "", content)
    content = re.sub(r"https?://\S+", "", content)
    return content


def count_violations(path: Path) -> dict:
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

    return {
        "bullet_label": bullet_label,
        "inline_label": inline_label,
        "ja_to_en_space": ja_to_en,
        "en_to_ja_space": en_to_ja,
        "quote_emphasis": quote_emphasis,
        "paren_supplement": paren_supplement,
    }


def render_table(counts: dict) -> str:
    rows = [
        ("箇条書きラベル `- xxx: 説明`", counts["bullet_label"]),
        ("散文中ラベル `xxx: 説明`", counts["inline_label"]),
        ("日英間スペース (助詞→英単語)", counts["ja_to_en_space"]),
        ("日英間スペース (英単語→助詞)", counts["en_to_ja_space"]),
        ("「」での強調", counts["quote_emphasis"]),
        ("（）での補足", counts["paren_supplement"]),
    ]
    lines = ["| パターン | 件数 |", "|---|---|"]
    for label, count in rows:
        flag = " ⚠️ 10件超" if count > 10 else ""
        lines.append(f"| {label} | {count}{flag} |")
    return "\n".join(lines)


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print("usage: check.py <file> [--json]", file=sys.stderr)
        return 1

    path = Path(args[0])
    as_json = "--json" in args

    if not path.exists():
        print(f"file not found: {path}", file=sys.stderr)
        return 1

    counts = count_violations(path)

    if as_json:
        print(json.dumps(counts, ensure_ascii=False, indent=2))
    else:
        print(render_table(counts))
        over_threshold = [k for k, v in counts.items() if v > 10]
        if over_threshold:
            print(
                "\n10 件超のパターンあり。修正前にユーザーに方針確認すること: "
                + ", ".join(over_threshold)
            )

    return 0


if __name__ == "__main__":
    sys.exit(main())
