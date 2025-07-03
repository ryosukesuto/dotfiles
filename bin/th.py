#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
th.py - Obsidianデイリーノート記録ツール（Python版）
環境変数に依存しない、より高度な機能を持つ実装
"""

import os
import sys
import re
from datetime import datetime
from pathlib import Path
import argparse


class ObsidianDaily:
    def __init__(self, vault_path=None):
        """初期化"""
        if vault_path:
            self.vault_path = Path(vault_path)
        else:
            self.vault_path = Path.home() / "src/github.com/ryosukesuto/obsidian-notes"
        
        self.daily_dir = self.vault_path / "01_Daily"
        self.today = datetime.now()
        self.daily_note = self.daily_dir / f"{self.today.strftime('%Y-%m-%d')}.md"
    
    def ensure_vault_exists(self):
        """Vaultディレクトリの存在確認"""
        if not self.vault_path.exists():
            raise FileNotFoundError(f"Obsidian vaultが見つかりません: {self.vault_path}")
        
        # 01_Dailyディレクトリを作成
        self.daily_dir.mkdir(parents=True, exist_ok=True)
    
    def create_daily_note(self):
        """デイリーノートの作成"""
        if not self.daily_note.exists():
            content = f"""# {self.today.strftime('%Y-%m-%d')}

## 📝 メモ
"""
            self.daily_note.write_text(content, encoding='utf-8')
    
    def add_memo(self, memo_text):
        """メモを追加"""
        timestamp = self.today.strftime("%Y/%m/%d %H:%M:%S")
        new_memo = f"- {timestamp}: {memo_text}"
        
        # ファイルを読み込む
        content = self.daily_note.read_text(encoding='utf-8')
        lines = content.splitlines()
        
        # メモセクションを探す
        memo_section_index = None
        last_memo_index = None
        in_memo_section = False
        
        for i, line in enumerate(lines):
            if line.strip() == "## 📝 メモ":
                memo_section_index = i
                in_memo_section = True
            elif in_memo_section:
                if line.startswith("- "):
                    last_memo_index = i
                elif line.startswith("## ") or (line.strip() == "" and last_memo_index):
                    in_memo_section = False
        
        # メモセクションが存在しない場合は追加
        if memo_section_index is None:
            lines.append("")
            lines.append("## 📝 メモ")
            lines.append(new_memo)
        else:
            # 適切な位置にメモを挿入
            if last_memo_index is not None:
                lines.insert(last_memo_index + 1, new_memo)
            else:
                lines.insert(memo_section_index + 1, new_memo)
        
        # ファイルに書き戻す
        self.daily_note.write_text('\n'.join(lines) + '\n', encoding='utf-8')
        
        return new_memo
    
    def list_memos(self):
        """今日のメモを一覧表示"""
        if not self.daily_note.exists():
            return []
        
        content = self.daily_note.read_text(encoding='utf-8')
        lines = content.splitlines()
        memos = []
        in_memo_section = False
        
        for line in lines:
            if line.strip() == "## 📝 メモ":
                in_memo_section = True
            elif in_memo_section:
                if line.startswith("- "):
                    memos.append(line)
                elif line.startswith("## "):
                    break
        
        return memos


def main():
    """メイン関数"""
    parser = argparse.ArgumentParser(description='Obsidianデイリーノートにメモを追加')
    parser.add_argument('memo', nargs='*', help='追加するメモの内容')
    parser.add_argument('--vault', '-v', help='Obsidian vaultのパス')
    parser.add_argument('--list', '-l', action='store_true', help='今日のメモを一覧表示')
    
    args = parser.parse_args()
    
    try:
        # Obsidianインスタンスを作成
        daily = ObsidianDaily(vault_path=args.vault)
        daily.ensure_vault_exists()
        
        if args.list:
            # メモ一覧表示
            daily.create_daily_note()
            memos = daily.list_memos()
            if memos:
                print(f"📝 {daily.today.strftime('%Y-%m-%d')} のメモ:")
                for memo in memos:
                    print(memo)
            else:
                print("今日のメモはまだありません。")
        else:
            # メモ追加
            if not args.memo:
                print("使用方法: th <メモ内容>")
                print("または: th --list で今日のメモを一覧表示")
                sys.exit(1)
            
            memo_text = ' '.join(args.memo)
            daily.create_daily_note()
            daily.add_memo(memo_text)
            print(f"✅ メモを追加しました: {memo_text}")
    
    except FileNotFoundError as e:
        print(f"エラー: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"予期しないエラー: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()