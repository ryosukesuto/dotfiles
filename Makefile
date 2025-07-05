.PHONY: help install uninstall backup update test clean check-deps dry-run status diff

# デフォルトターゲット
help:
	@echo "使用可能なコマンド:"
	@echo ""
	@echo "  インストール関連:"
	@echo "    make install       - dotfilesをインストール"
	@echo "    make install-force - 確認なしでインストール"
	@echo "    make dry-run       - インストールのドライラン（変更なし）"
	@echo "    make uninstall     - dotfilesをアンインストール"
	@echo ""
	@echo "  メンテナンス:"
	@echo "    make update        - リポジトリを更新して再インストール"
	@echo "    make backup        - 現在の設定をバックアップ"
	@echo "    make clean         - バックアップファイルを削除"
	@echo ""
	@echo "  診断・確認:"
	@echo "    make check-deps    - 依存関係をチェック"
	@echo "    make status        - インストール状況を確認"
	@echo "    make diff          - 現在の設定との差分を表示"
	@echo "    make test          - スクリプトの構文チェック"

# インストール
install:
	@echo "dotfilesをインストールしています..."
	@./install.sh

# 強制インストール（確認なし）
install-force:
	@echo "dotfilesを強制インストールしています..."
	@./install.sh --force

# アンインストール
uninstall:
	@echo "dotfilesをアンインストールしています..."
	@./uninstall.sh

# バックアップから復元してアンインストール
uninstall-restore:
	@echo "dotfilesをアンインストールして、バックアップから復元しています..."
	@./uninstall.sh --restore

# 現在の設定をバックアップ
backup:
	@echo "現在の設定をバックアップしています..."
	@mkdir -p backups
	@tar -czf backups/dotfiles_backup_$$(date +%Y%m%d_%H%M%S).tar.gz \
		--exclude='.git' \
		--exclude='backups' \
		--exclude='*.swp' \
		.
	@echo "バックアップが backups/ に保存されました"

# リポジトリを更新して再インストール
update:
	@echo "リポジトリを更新しています..."
	@git pull
	@echo "dotfilesを再インストールしています..."
	@./install.sh --force

# インストールスクリプトのテスト（ドライラン）
test:
	@echo "インストールスクリプトのテストを実行しています..."
	@bash -n install.sh
	@bash -n uninstall.sh
	@echo "構文エラーはありません"

# バックアップファイルを削除
clean:
	@echo "バックアップファイルを削除しています..."
	@find ~ -name "*.backup.*" -type f -print -delete
	@echo "バックアップファイルの削除が完了しました"

# 依存関係をチェック
check-deps:
	@echo "依存関係をチェックしています..."
	@./install.sh --check-deps

# ドライラン（実際には変更を加えない）
dry-run:
	@echo "インストールのドライランを実行しています..."
	@./install.sh --dry-run

# インストール状況を確認
status:
	@echo "=== dotfiles インストール状況 ==="
	@echo ""
	@echo "シンボリックリンク:"
	@for link in ~/.zshrc ~/.zprofile ~/.gitconfig ~/.tmux.conf ~/.vimrc; do \
		if [ -L "$$link" ]; then \
			echo "  ✓ $$link -> $$(readlink $$link)"; \
		else \
			echo "  ✗ $$link"; \
		fi; \
	done
	@echo ""
	@echo "設定ディレクトリ:"
	@for dir in ~/.config/gh ~/.config/claude ~/.ssh/config ~/.claude; do \
		if [ -e "$$dir" ]; then \
			echo "  ✓ $$dir"; \
		else \
			echo "  ✗ $$dir"; \
		fi; \
	done
	@echo ""
	@echo "ローカル設定ファイル:"
	@for file in ~/.zshrc.local ~/.gitconfig.local ~/.env.local; do \
		if [ -f "$$file" ]; then \
			echo "  ✓ $$file"; \
		else \
			echo "  - $$file (未作成)"; \
		fi; \
	done

# 現在の設定との差分を表示
diff:
	@echo "=== 現在の設定との差分 ==="
	@for file in zsh/00-core.zsh zsh/30-aliases.zsh config/git/gitconfig; do \
		target="$$HOME/.$$(basename $$file)"; \
		if [ -f "$$target" ] && [ ! -L "$$target" ]; then \
			echo ""; \
			echo "--- $$file ---"; \
			diff -u "$$target" "$$file" || true; \
		fi; \
	done