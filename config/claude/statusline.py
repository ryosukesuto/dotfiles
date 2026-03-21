#!/usr/bin/env python3
"""Claude Code statusline script.

Reads session JSON from stdin and outputs a formatted status line.
Uses built-in rate_limits field (v2.1.80+) instead of OAuth API calls.
"""

import json
import os
import subprocess
import sys
import time

# ── Colors (TokyoNight Night palette) ───────────────────
R = "\033[0m"
DIM = "\033[2m"
BLUE = "\033[38;2;122;162;247m"      # #7aa2f7
GREEN = "\033[38;2;158;206;106m"     # #9ece6a
CYAN = "\033[38;2;125;207;255m"      # #7dcfff
RED = "\033[38;2;247;118;142m"       # #f7768e
FG = "\033[38;2;192;202;245m"        # #c0caf5
PURPLE = "\033[38;2;187;154;247m"    # #bb9af7
YELLOW = "\033[38;2;224;175;104m"    # #e0af68
COMMENT = "\033[38;2;65;72;104m"     # #414868

SEP = f" {COMMENT}|{R} "

# TokyoNight palette RGB tuples for gradient interpolation
_GREEN = (158, 206, 106)   # #9ece6a
_YELLOW = (224, 175, 104)  # #e0af68
_RED = (247, 118, 142)     # #f7768e


# ── Helpers ─────────────────────────────────────────────
def _lerp(a: tuple, b: tuple, t: float) -> tuple:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(pct: float) -> str:
    if pct < 50:
        r, g, b = _lerp(_GREEN, _YELLOW, pct / 50)
    else:
        r, g, b = _lerp(_YELLOW, _RED, (pct - 50) / 50)
    return f"\033[38;2;{r};{g};{b}m"


def bar(pct: float, width: int = 20) -> str:
    pct = min(max(pct, 0), 100)
    filled = round(pct * width / 100)
    return "\u2500" * filled + f"{COMMENT}" + "\u2500" * (width - filled) + f"{R}"


def format_tokens(num: int) -> str:
    if num >= 1_000_000:
        return f"{num / 1_000_000:.1f}m"
    elif num >= 1_000:
        return f"{num / 1_000:.0f}k"
    return str(num)


def format_reset_time(ts, style: str = "time") -> str:
    if ts is None or ts == 0:
        return ""
    t = time.localtime(ts)
    if style == "time":
        h = t.tm_hour % 12 or 12
        ampm = "am" if t.tm_hour < 12 else "pm"
        return f"{h}:{t.tm_min:02d}{ampm}"
    elif style == "datetime":
        months = ["jan", "feb", "mar", "apr", "may", "jun",
                  "jul", "aug", "sep", "oct", "nov", "dec"]
        h = t.tm_hour % 12 or 12
        ampm = "am" if t.tm_hour < 12 else "pm"
        return f"{months[t.tm_mon - 1]} {t.tm_mday}, {h}:{t.tm_min:02d}{ampm}"
    return ""


def format_duration(seconds: int) -> str:
    if seconds >= 3600:
        return f"{seconds // 3600}h{(seconds % 3600) // 60}m"
    elif seconds >= 60:
        return f"{seconds // 60}m"
    return f"{seconds}s"


def fmt_rate(label: str, pct: float, reset_str: str = "", label_width: int = 7) -> str:
    p = round(pct)
    padded = label.ljust(label_width)
    result = f"{FG}{padded}{R} {gradient(pct)}{bar(pct)} {gradient(pct)}{p:>3d}%{R}"
    if reset_str:
        result += f" {COMMENT}\u27f3{R} {FG}{reset_str}{R}"
    return result


# ── Main ────────────────────────────────────────────────
def main():
    raw = sys.stdin.read()
    if not raw.strip():
        print("Claude", end="")
        return

    data = json.loads(raw)

    # Model
    model_name = data.get("model", {}).get("display_name", "Claude")

    # Context window
    ctx = data.get("context_window", {})
    size = ctx.get("context_window_size", 200_000) or 200_000
    usage = ctx.get("current_usage", {})
    current = (
        usage.get("input_tokens", 0)
        + usage.get("cache_creation_input_tokens", 0)
        + usage.get("cache_read_input_tokens", 0)
    )
    pct_used = current * 100 // size if size > 0 else 0

    # Directory + git branch
    cwd = data.get("cwd") or os.getcwd()
    dirname = os.path.basename(cwd)

    git_branch = ""
    git_dirty = ""
    try:
        branch = subprocess.run(
            ["git", "-C", cwd, "symbolic-ref", "--short", "HEAD"],
            capture_output=True, text=True, timeout=2,
        )
        if branch.returncode == 0:
            git_branch = branch.stdout.strip()
        status = subprocess.run(
            ["git", "-C", cwd, "status", "--porcelain"],
            capture_output=True, text=True, timeout=2,
        )
        if status.stdout.strip():
            git_dirty = "*"
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    # Session duration
    session_duration = ""
    session_start = data.get("session", {}).get("start_time")
    if session_start:
        try:
            from datetime import datetime, timezone
            if isinstance(session_start, str):
                st = session_start.replace("Z", "+00:00")
                start_dt = datetime.fromisoformat(st)
                elapsed = int(time.time() - start_dt.timestamp())
            else:
                elapsed = int(time.time() - session_start)
            if elapsed > 0:
                session_duration = format_duration(elapsed)
        except (ValueError, TypeError):
            pass

    # Thinking status
    thinking_on = False
    settings_path = os.path.expanduser("~/.claude/settings.json")
    try:
        with open(settings_path) as f:
            settings = json.load(f)
            thinking_on = settings.get("alwaysThinkingEnabled", False)
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    # ── LINE 1: Model | Directory (branch) | Session | Thinking ──
    parts = [f"{BLUE}{model_name}{R}"]

    dir_part = f"{CYAN}{dirname}{R}"
    if git_branch:
        dir_part += f" {GREEN}({git_branch}{RED}{git_dirty}{GREEN}){R}"
    parts.append(dir_part)

    if session_duration:
        parts.append(f"{FG}{session_duration}{R}")

    if thinking_on:
        parts.append(f"{PURPLE}thinking{R}")
    else:
        parts.append(f"{COMMENT}thinking{R}")

    line1 = SEP.join(parts)

    # ── LINE 2: Context + Rate limits (aligned bars) ────
    rl = data.get("rate_limits", {})
    five = rl.get("five_hour", {})
    seven = rl.get("seven_day", {})
    five_pct = five.get("used_percentage")
    seven_pct = seven.get("used_percentage")

    bar_lines = []
    bar_lines.append(fmt_rate("context", pct_used))
    if five_pct is not None:
        reset = format_reset_time(five.get("resets_at"), "time")
        bar_lines.append(fmt_rate("current", five_pct, reset))
    if seven_pct is not None:
        reset = format_reset_time(seven.get("resets_at"), "datetime")
        bar_lines.append(fmt_rate("weekly", seven_pct, reset))

    # ── Output ──────────────────────────────────────────
    print(line1, end="")
    if bar_lines:
        print(f"\n\n" + "\n".join(bar_lines), end="")


if __name__ == "__main__":
    main()
