# claude-usage-bar

macOS のメニューバーに Claude プランの使用率を常時表示する常駐アプリ。
Claude Code の `/usage` と同じ数値（セッション制限 / 週間制限）をリアルタイムにグランスできる。

```
┌─────────────┐
│ S 47% · W 5% │   S=セッション(5時間) / W=週間
└─────────────┘
   ↓ クリック
┌──────────────────────────┐
│ Claude 使用状況            │
│ セッション         47%  ▓▓▓░ │
│   リセット 約2時間後        │
│ 週間               5%   ▓░░░ │
│   リセット 6日後           │
│ 更新: 1分前   [更新] [終了]  │
└──────────────────────────┘
```

## 仕組み

- macOS Keychain の `Claude Code-credentials`（Claude Code が保存・自動リフレッシュ）から OAuth アクセストークンを読む。
- `GET https://api.anthropic.com/api/oauth/usage` を 60 秒ごとにポーリングし、`five_hour`（セッション）と `seven_day`（週間）の `utilization`（0–100%）と `resets_at` を表示する。
- このエンドポイントはメタデータ取得でプラン使用量を消費しない。

> ⚠️ `/api/oauth/usage` は公開 API ではなく Claude Code 内部の OAuth エンドポイント。CLI のバージョン更新で仕様が変わる可能性がある。その場合は `Sources/ClaudeUsageBar/UsageClient.swift` と `Models.swift` のみ修正すれば追従できる。

## 必要環境

- macOS 14+（Observation / MenuBarExtra `.window` スタイル）
- Swift 6 系ツールチェーン（`swift build`）
- Claude Code でログイン済み（Keychain にトークンが存在すること）

## 開発実行

```sh
swift run
```

初回起動時に「ClaudeUsageBar が Keychain の機密情報を使おうとしています」というダイアログが出る → **「常に許可」**。

## .app として常駐させる

```sh
./scripts/package-app.sh --install   # /Applications にインストール
open /Applications/ClaudeUsageBar.app
```

ログイン時に自動起動したい場合は、システム設定 → 一般 → ログイン項目に `ClaudeUsageBar.app` を追加。

## 設定

ポーリング間隔（秒、最小 15、既定 60）:

```sh
defaults write com.tktk7l9.claude-usage-bar pollInterval 30
```

## Keychain ダイアログを再表示させたくない場合

アドホック署名（`codesign --sign -`）は再ビルドのたびに署名が変わるため、Keychain 許可が再要求される。固定したい場合は自己署名証明書を作成し、`scripts/package-app.sh` の `--sign -` をその証明書名に置き換える:

1. キーチェーンアクセス → 証明書アシスタント → 自分に証明書を作成（コード署名用）
2. `codesign --force --deep --sign "<証明書名>" ClaudeUsageBar.app`

## 状態表示

- `S 47% · W 5%` — 通常。最大使用率に応じて緑 / 黄(70%+) / 赤(90%+)。
- `⚠︎ 再認証` — トークン失効（401）。Claude Code で一度コマンドを実行するとトークンが更新される。
- `S – · W –` — ネットワーク等の一時エラー。次のポーリングで自動復帰。

Not affiliated with Anthropic. 個人用ツール。
