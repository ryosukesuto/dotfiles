# Subagent への prompt はコンテキストの境界を明示する

Explore / Plan / 一般 Agent などの subagent は会話履歴を持たず、与えた prompt の情報のみで動く。メイン会話で得た「前提条件」「直前の作業結果」「対象ファイルの実体形式」を prompt に書き忘れると、agent が無理筋の前提で動いて失敗する。

## 必ず明記する 4 項目

1. ファイル形式の前提: Google Sheet（ネイティブ）か xlsx かなど。形式が不確かなら「両方の可能性に対応する手順を取れ」と指示
2. DB / コードベースの最新状態: 直前の PR で追加された Q 番号範囲・関数名・ファイル等。agent が古い main を見ている可能性がある
3. 既出の参照リソース: 関連する Kibela URL、ADR、Linear Issue、過去 PR 番号。agent はリポ内 grep でしか見つけられない
4. 作業の境界: read-only か write OK か、コミット可か、外部 API 呼び出しの許容範囲

## なぜ必要か

- subagent はメイン会話の context を読まないため、「直前のやりとり」「TodoList」「memory」が見えない
- 並列で複数 subagent を起動した場合、各 agent への情報伝達ミスが連鎖して全並列が失敗する
- 失敗してもエラーメッセージはメイン会話に来るが、原因特定にラウンドトリップが発生する

## 失敗パターンの例

- 2026-06-03 4 銀行並列 pull 検証: spreadsheetId が Drive 上は spreadsheet 表示でも実体は xlsx 形式のままだったケースで、agent が `gws sheets get` で 404 を踏んで全 4 並列が失敗。「xlsx 可能性があるなら `scripts/xlsx_to_rows.py` を使え」と明記していれば 1 段省略できた
- 2026-06-03 みずほ突合: 私が直前の PR #12 で Q613-Q615 を追加していたが、agent への prompt にその情報を入れなかったため、agent が「No.70.0 (1月取引回数上限) は new」と判定。実は Q613 と同一質問で existing。私のチェックでリカバー

## チェックリスト（prompt 作成時）

- [ ] 対象ファイル / リソースの実体形式を明記したか（拡張子で判断していないか）
- [ ] 直前のセッションで変更した範囲（PR / コミット）を agent に伝えたか
- [ ] 既出の参照リソース（Kibela / ADR / 過去 PR）を列挙したか
- [ ] write 操作の可否・コミット可否・破壊的操作の範囲を明示したか

## 関連

- `~/.claude/rules/model-selection.md`: subagent のモデル使い分け
- `~/.claude/CLAUDE.md` の「Subagent委譲ルール」節
