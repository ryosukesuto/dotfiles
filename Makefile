.PHONY: help install uninstall backup update test clean

# デフォルトターゲット
help:
	@echo "使用可能なコマンド:"
	@echo "  make install    - dotfilesをインストール"
	@echo "  make uninstall  - dotfilesをアンインストール"
	@echo "  make backup     - 現在の設定をバックアップ"
	@echo "  make update     - リポジトリを更新して再インストール"
	@echo "  make test       - インストールスクリプトのテスト（ドライラン）"
	@echo "  make clean      - バックアップファイルを削除"

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