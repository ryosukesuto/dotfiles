#!/usr/bin/env python3
"""
build-bundle: triage.json → bundle.schema.json 準拠の review bundle を生成する。

Usage:
  python3 build-bundle.py --triage /tmp/triage.json --output /tmp/bundle.json
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


CONTEXT_LINES = 30  # relevant_snippets の前後行数


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


def main():
    parser = argparse.ArgumentParser(description="Build review bundle from triage output")
    parser.add_argument("--triage", required=True, help="Path to triage.json")
    parser.add_argument("--output", "-o", default="-", help="Output bundle.json path (- = stdout)")
    parser.add_argument(
        "--skip-snippets",
        action="store_true",
        help="Skip building relevant_snippets (faster, for testing)",
    )
    args = parser.parse_args()

    with open(args.triage) as f:
        triage = json.load(f)

    repo_roots = triage.get("repo_roots", {})
    base_sha = triage.get("base_sha", "")
    head_sha = triage.get("head_sha", "")
    changed_files = triage.get("changed_files", [])
    selected_reviewers = triage.get("selected_reviewers", [])

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
        "changed_file_manifest": build_changed_file_manifest(changed_files),
        "interface_changes": build_interface_changes(triage),
        "risk_tags": triage.get("risk_tags", []),
        "relevant_snippets": snippets,
        "review_slices": review_slices,
        "path_reason_map": path_reason_map,
    }

    output = json.dumps(bundle, ensure_ascii=False, indent=2)

    if args.output == "-":
        print(output)
    else:
        Path(args.output).write_text(output)
        print(f"Bundle written to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
