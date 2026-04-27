#!/usr/bin/env python3
"""
build-bundle: triage.json → bundle.schema.json 準拠の review bundle を生成する。

Usage:
  python3 build-bundle.py --triage /tmp/triage.json --output /tmp/bundle.json
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


CONTEXT_LINES = 30  # relevant_snippets の前後行数
SYMBOL_INDEX_MAX_HITS = 30  # symbol 1 つあたりの最大保持件数（ノイズ抑制）
SYMBOL_INDEX_GLOB_DEFAULT = "!{vendor,node_modules,third_party,.git}/**"


def run_git(args: list[str], cwd: str) -> str:
    result = subprocess.run(
        ["git"] + args,
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    return result.stdout


def get_file_content_range(repo_root: str, path: str, start: int, end: int) -> str:
    """ファイルの指定行範囲を返す。存在しない場合は空文字。"""
    full_path = Path(repo_root) / path
    if not full_path.exists():
        return ""
    try:
        lines = full_path.read_text(errors="replace").splitlines()
        s = max(0, start - 1)
        e = min(len(lines), end)
        return "\n".join(lines[s:e])
    except Exception:
        return ""


def get_diff_hunks(repo_root: str, base_sha: str, head_sha: str, path: str) -> list[dict]:
    """
    git diff で変更 hunk の行範囲を取得する。
    Returns: [{start, end}] in new file coordinates
    """
    output = run_git(
        ["diff", "--unified=0", base_sha, head_sha, "--", path],
        cwd=repo_root,
    )
    hunks = []
    for line in output.splitlines():
        if line.startswith("@@"):
            # @@ -old +new,count @@
            try:
                parts = line.split(" ")
                new_part = [p for p in parts if p.startswith("+")][0]
                new_part = new_part.lstrip("+")
                if "," in new_part:
                    start, count = new_part.split(",")
                    start, count = int(start), int(count)
                else:
                    start, count = int(new_part), 1
                end = start + max(count - 1, 0)
                if count > 0:
                    hunks.append({"start": start, "end": end})
            except (ValueError, IndexError):
                pass
    return hunks


def build_review_slices(
    changed_files: list[dict],
    repo_roots: dict,
    base_sha: str,
    head_sha: str,
    selected_reviewers: list[str],
) -> dict:
    """
    reviewer_id → [{repo, path, hunk_ranges, reason}] のマップを生成。
    PoC: baseline reviewers は全ファイルを担当する。
    """
    all_slices = []
    path_reason_map = {}

    for f in changed_files:
        repo = f["repo"]
        path = f["path"]
        root = repo_roots.get(repo, "")

        hunks = []
        if root and base_sha and head_sha:
            hunks = get_diff_hunks(root, base_sha, head_sha, path)

        reason = f"status={f.get('status', 'modified')}"

        slice_entry = {
            "repo": repo,
            "path": path,
            "reason": reason,
        }
        if hunks:
            slice_entry["hunk_ranges"] = hunks

        all_slices.append(slice_entry)
        path_reason_map[f"{repo}:{path}"] = reason

    slices = {}
    for reviewer in selected_reviewers:
        slices[reviewer] = all_slices

    return slices, path_reason_map


def build_relevant_snippets(
    changed_files: list[dict],
    repo_roots: dict,
    base_sha: str,
    head_sha: str,
) -> list[dict]:
    snippets = []
    for f in changed_files:
        repo = f["repo"]
        path = f["path"]
        root = repo_roots.get(repo, "")
        if not root:
            continue

        hunks = get_diff_hunks(root, base_sha, head_sha, path) if base_sha and head_sha else []
        if not hunks:
            # 新規追加ファイルなど: 先頭60行
            content = get_file_content_range(root, path, 1, 60)
            if content:
                lines_in_file = len(content.splitlines())
                snippets.append({
                    "repo": repo,
                    "path": path,
                    "lines": {"start": 1, "end": lines_in_file},
                    "content": content,
                })
            continue

        for hunk in hunks:
            start = max(1, hunk["start"] - CONTEXT_LINES)
            end = hunk["end"] + CONTEXT_LINES
            content = get_file_content_range(root, path, start, end)
            if content:
                snippets.append({
                    "repo": repo,
                    "path": path,
                    "lines": {"start": start, "end": end},
                    "content": content,
                })

    return snippets


def build_changed_file_manifest(changed_files: list[dict]) -> list[dict]:
    return [
        {
            "repo": f["repo"],
            "path": f["path"],
            "status": f.get("status", "modified"),
            "additions": f.get("additions", 0),
            "deletions": f.get("deletions", 0),
        }
        for f in changed_files
    ]


def build_interface_changes(triage: dict) -> dict:
    return {
        "symbols": triage.get("changed_symbols", []),
        "protos": triage.get("changed_protos", []),
        "env_vars": triage.get("changed_env_vars", []),
        "schemas": triage.get("changed_schemas", []),
    }


def _rg_available() -> bool:
    try:
        subprocess.run(["rg", "--version"], capture_output=True, check=False)
        return True
    except FileNotFoundError:
        return False


def _rg_search(root: str, pattern: str) -> list[dict]:
    """
    ripgrep で pattern を検索し、[{file, line, text}] を返す。
    ファイル外・バイナリ・vendor は除外。word-boundary 固定で偽陽性を抑える。
    """
    if not Path(root).exists():
        return []
    try:
        result = subprocess.run(
            [
                "rg", "-n", "--no-heading", "--color=never",
                "--word-regexp",
                "-g", "!vendor",
                "-g", "!node_modules",
                "-g", "!third_party",
                "-g", "!.git",
                pattern,
                root,
            ],
            capture_output=True,
            text=True,
            timeout=20,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []

    hits = []
    for line in result.stdout.splitlines():
        # <file>:<line>:<text>
        parts = line.split(":", 2)
        if len(parts) < 3:
            continue
        file_abs, lineno, text = parts
        try:
            lineno_i = int(lineno)
        except ValueError:
            continue
        try:
            rel = str(Path(file_abs).resolve().relative_to(Path(root).resolve()))
        except ValueError:
            rel = file_abs
        hits.append({"file": rel, "line": lineno_i, "text": text.strip()[:200]})
    return hits


_GO_DEF_RE = re.compile(r"^\s*(func(\s*\([^)]+\))?|type|const|var)\s")


def _classify_hit(hit: dict) -> str:
    """Go の定義行っぽければ definition、そうでなければ reference。"""
    text = hit.get("text", "")
    if _GO_DEF_RE.match(text):
        return "definition"
    return "reference"


def build_symbol_index(triage: dict, repo_roots: dict) -> dict:
    """
    changed_symbols の各 symbol について、repo_roots 配下で定義・参照をインデックス化。
    ripgrep が無ければ空オブジェクトを返す。
    """
    if not _rg_available():
        return {}

    index: dict[str, list[dict]] = {}
    for sym in triage.get("changed_symbols", []) or []:
        name = sym.get("name", "")
        if not name or len(name) < 3:
            continue
        key = f"{sym.get('repo', '')}:{name}"
        for repo_name, root in repo_roots.items():
            hits = _rg_search(root, name)
            for h in hits[:SYMBOL_INDEX_MAX_HITS]:
                index.setdefault(key, []).append({
                    "repo": repo_name,
                    "file": h["file"],
                    "line": h["line"],
                    "kind": _classify_hit(h),
                    "excerpt": h["text"],
                })
    return index


def fetch_pr_metadata(pr_ref: str) -> dict:
    """pr_ref（例: github.com/org/repo#123）から gh CLI で PR title/body を取得する。"""
    m = re.match(r"github\.com/([^#]+)#(\d+)", pr_ref or "")
    if not m:
        return {}
    repo, pr_num = m.group(1), m.group(2)
    try:
        result = subprocess.run(
            ["gh", "pr", "view", pr_num, "--repo", repo, "--json", "title,body"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        if result.returncode != 0:
            return {}
        data = json.loads(result.stdout)
        return {"title": data.get("title", ""), "body": data.get("body", "")}
    except Exception:
        return {}


def load_static_analysis(path: str | None) -> dict:
    """外部生成済みの静的解析 JSON を読み込んでそのまま bundle にマージする。"""
    if not path:
        return {}
    p = Path(path)
    if not p.exists():
        print(f"WARN: static-analysis file not found: {path}", file=sys.stderr)
        return {}
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError as e:
        print(f"WARN: invalid JSON in {path}: {e}", file=sys.stderr)
        return {}


def main():
    parser = argparse.ArgumentParser(description="Build review bundle from triage output")
    parser.add_argument("--triage", required=True, help="Path to triage.json")
    parser.add_argument("--output", "-o", default="-", help="Output bundle.json path (- = stdout)")
    parser.add_argument(
        "--skip-snippets",
        action="store_true",
        help="Skip building relevant_snippets (faster, for testing)",
    )
    parser.add_argument(
        "--symbol-index",
        action="store_true",
        help="Build symbol_index using ripgrep across repo_roots (extra, PoC後の拡張項目)",
    )
    parser.add_argument(
        "--static-analysis",
        metavar="PATH",
        help="Merge pre-generated static analysis JSON into bundle.static_analysis_summary",
    )
    args = parser.parse_args()

    with open(args.triage) as f:
        triage = json.load(f)

    repo_roots = triage.get("repo_roots", {})
    base_sha = triage.get("base_sha", "")
    head_sha = triage.get("head_sha", "")
    changed_files = triage.get("changed_files", [])
    selected_reviewers = triage.get("selected_reviewers", [])
    pr_ref = triage.get("pr_ref", "")
    pr_metadata = fetch_pr_metadata(pr_ref) if pr_ref else {}

    review_slices, path_reason_map = build_review_slices(
        changed_files, repo_roots, base_sha, head_sha, selected_reviewers
    )

    if args.skip_snippets:
        snippets = []
    else:
        snippets = build_relevant_snippets(changed_files, repo_roots, base_sha, head_sha)

    bundle = {
        "schema_version": 1,
        "triage_ref": args.triage,
        "pr_metadata": pr_metadata,
        "changed_file_manifest": build_changed_file_manifest(changed_files),
        "interface_changes": build_interface_changes(triage),
        "risk_tags": triage.get("risk_tags", []),
        "relevant_snippets": snippets,
        "review_slices": review_slices,
        "path_reason_map": path_reason_map,
    }

    if args.symbol_index:
        sym_idx = build_symbol_index(triage, repo_roots)
        if sym_idx:
            bundle["symbol_index"] = sym_idx

    if args.static_analysis:
        sa = load_static_analysis(args.static_analysis)
        if sa:
            bundle["static_analysis_summary"] = sa

    output = json.dumps(bundle, ensure_ascii=False, indent=2)

    if args.output == "-":
        print(output)
    else:
        Path(args.output).write_text(output)
        print(f"Bundle written to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
