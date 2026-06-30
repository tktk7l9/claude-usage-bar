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

ポーリング間隔（秒、最小 30、既定 60）:

```sh
defaults write com.tktk7l9.claude-usage-bar pollInterval 90
```

## テスト

純粋ロジック（整形・パース・しきい値）のセルフテスト。XCTest/Swift Testing は
Command Line Tools のみの環境では動かないため、依存ゼロのセルフテストにしている:

```sh
swift run ClaudeUsageBar --selftest   # 失敗時は非ゼロ終了
swift run ClaudeUsageBar --once       # Keychain+APIまで通す疎通確認
```

## Keychain ダイアログを再表示させたくない場合

アドホック署名は再ビルドのたびに署名が変わるため Keychain 許可が再要求される。
固定したい場合は自己署名のコード署名証明書を一度だけ作成する:

```sh
./scripts/create-signing-cert.sh     # 自己署名証明書を作成（sudo不要）
./scripts/package-app.sh --install   # 以後この証明書で署名（自動検出）
```

証明書がある場合 `package-app.sh` は自動でそれを使う（なければアドホック）。
署名が安定するので、最初の1回「常に許可」を押せば以後の再ビルドで再要求されない。

## 状態表示（メニューバー / ポップオーバー）

- `S 47%` / `W 5%`（2行）— 通常。最大使用率に応じて緑 / 黄(70%+) / 赤(90%+)。
- `⚠︎` — トークン失効（401）。Claude Code で一度コマンドを実行するとトークンが更新される。
- 一時的な 429・通信エラー中は直前の数値を保持（`–` にしない）。
- ポップオーバー: セッション/週間（+あれば Opus/Sonnet）のメーターとリセット時刻、
  プラン・モデル・effort、組織名・メール、上限警告を表示。

Not affiliated with Anthropic. 個人用ツール。
