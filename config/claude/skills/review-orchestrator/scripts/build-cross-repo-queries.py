#!/usr/bin/env python3
"""
build-cross-repo-queries: triage.must_check_interfaces から cross-repo クエリを生成する。

各 interface につき、candidate_repos ごとに 1つの pinpoint または scoped クエリを発行。
pinpoint: symbol が分かっている場合（RPC名・関数名）→ Grep + Read で解決
scoped:   path パターンで探す場合（proto パッケージなど）

Usage:
  python3 build-cross-repo-queries.py --triage /tmp/triage.json -o /tmp/cross-repo-queries.json
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path


def sha6(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()[:6]


def build_pattern(iface: dict) -> str:
    """symbol から grep 用パターンを組む。RPC/関数名は word-boundary で囲む。"""
    symbol = iface.get("source_symbol", "") or iface.get("name", "")
    if not symbol:
        path = iface.get("source_path", "")
        return Path(path).stem if path else ""
    # RPC は Client suffix も含めて検索するとヒット率が上がる
    kind = iface.get("type", "")
    if kind == "rpc":
        return f"{symbol}|{symbol}Client|{symbol}Request|{symbol}Response"
    return symbol


def classify_query_type(iface: dict) -> str:
    """
    symbol が明確なら pinpoint、ディレクトリ単位なら scoped。
    proto パッケージパス（末尾が / か *）は scoped。
    """
    sym = iface.get("source_symbol", "") or iface.get("name", "")
    src_path = iface.get("source_path", "")
    if sym and not src_path.endswith("/"):
        return "pinpoint"
    return "scoped"


def build_query(iface: dict, repo: str, max_queries: int = 5) -> dict:
    qtype = classify_query_type(iface)
    src_repo = iface.get("source_repo", "")
    src_path = iface.get("source_path", "")
    src_symbol = iface.get("source_symbol", "") or iface.get("name", "")

    query_id = f"xrq-{sha6(f'{repo}:{src_repo}:{src_path}:{src_symbol}')}"

    source: dict = {"repo": src_repo, "file": src_path}
    if src_symbol:
        source["symbol"] = src_symbol

    target_desc = _describe_target(iface)
    pattern = build_pattern(iface)

    query: dict = {
        "schema_version": 1,
        "query_id": query_id,
        "repo": repo,
        "query_type": qtype,
        "source": source,
        "target": target_desc,
        "reason": _describe_reason(iface),
        "max_queries": max_queries,
        "stop_if_found": True,
        "allow_survey": False,
        "expected_output": "file:line + 前後コンテキスト（呼び出し・参照箇所）",
    }
    if pattern:
        query["search_pattern"] = pattern
    return query


def _describe_target(iface: dict) -> str:
    kind = iface.get("type", "interface")
    name = iface.get("source_symbol", "") or iface.get("name", "") or iface.get("source_path", "")
    if kind == "rpc":
        return f"{name} RPC の consumer 参照箇所"
    if kind == "proto":
        return f"{name} の import / 使用箇所"
    if kind == "env_var":
        return f"環境変数 {name} の読み込み箇所"
    if kind == "schema":
        return f"schema {name} の参照・migration 連動箇所"
    return f"{name} の参照箇所"


def _describe_reason(iface: dict) -> str:
    kind = iface.get("type", "interface")
    if kind == "rpc":
        return "RPC 変更によりシリアライズ互換性・クライアント側の呼び出し引数を確認"
    if kind == "proto":
        return "proto 変更により consumer 側の生成コード再生成が必要か確認"
    if kind == "env_var":
        return "環境変数の追加/リネームにより設定投入漏れがないか確認"
    if kind == "schema":
        return "schema 変更により migration / ORM 定義との整合性を確認"
    return "interface 変更の consumer 側影響範囲を確認"


def main() -> int:
    parser = argparse.ArgumentParser(description="Build cross-repo queries from triage.must_check_interfaces")
    parser.add_argument("--triage", required=True)
    parser.add_argument("--output", "-o", default="-")
    parser.add_argument("--max-queries", type=int, default=5, help="per-interface query budget")
    args = parser.parse_args()

    with open(args.triage) as f:
        triage = json.load(f)

    interfaces = triage.get("must_check_interfaces", []) or []
    queries = []
    for iface in interfaces:
        for repo in iface.get("candidate_repos", []) or []:
            queries.append(build_query(iface, repo, max_queries=args.max_queries))

    output = {
        "schema_version": 1,
        "pr_ref": triage.get("pr_ref", ""),
        "queries": queries,
    }

    text = json.dumps(output, ensure_ascii=False, indent=2)
    if args.output == "-":
        print(text)
    else:
        Path(args.output).write_text(text)
        print(f"Cross-repo queries written to: {args.output} ({len(queries)} queries)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
