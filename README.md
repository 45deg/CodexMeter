# Codex Meter

![Codex Meterの実際のメニュー画面（表示値は撮影用サンプル）](assets/screenshot.png)

Codexの利用枠をメニューバーに表示する非公式macOSアプリです。残量、回復までの時間、リセットチケットの枚数・有効期限を確認できます。

## 対応環境

- Apple Silicon搭載Mac、macOS 15 Sequoia以降
- ChatGPTアカウントでログイン済みのCodex CLI（APIキーのみのログインは対象外）

動作確認済み：macOS 27.0.1。macOS 15での実機確認は未実施です。

## インストール

1. ZIPを展開し、`Codex Meter.app`を`~/Applications`に移します。
2. CLIが未ログインの場合は、ターミナルで`codex login`を実行します。
3. アプリを開き、通知を使う場合は通知を許可します。

Developer IDによる署名・Appleによる公証は未実施のため、macOSで起動が制限される場合があります。

自動起動する場合は「システム設定 → 一般 → ログイン項目」に追加してください。

## 使い方

- 5分ごと・スリープ復帰時に自動更新します。手動更新は⌘R、終了は⌘Qです。
- 「設定 → 表示」で残量／使用量を切り替えます。二重リングの外側は5時間枠、内側は週間枠です。
- 「リセットチケット」で有効期限を確認できます。利用枠の回復とチケットの追加は通知でも知らせます。
- 取得エラーは`!`で表示します。メニューの「接続エラー…」から詳細を確認できます。

CLI側のアカウントの利用状況を表示します。サーバーが返さない枠やチケットの詳細は表示できず、アプリ終了中は監視しません。

## プライバシー

Codex CLIを通じてOpenAIから利用状況を取得します。アプリ独自に認証情報を読み取ったり複製したりせず、会話・モデル実行・リセットチケットの消費は行いません。

アカウント識別用メールアドレス、利用枠、チケットの情報、取得日時、表示・通知設定をMacのUserDefaults（`local.codex.meter`）に保存します。開発者への送信やアクセス解析は行いません。

## アンインストール

アプリを終了し、ログイン項目から解除してアプリ本体を削除します。保存情報も削除する場合は、終了後に`defaults delete local.codex.meter`を実行してください。CLIのログイン情報は削除されません。

## ソースからビルド

Xcode Command Line ToolsまたはXcodeが必要です。

```sh
zsh build.sh    # build/Codex Meter.app を生成
zsh test.sh     # テスト
zsh install.sh  # ~/Applicationsへ配置・起動
zsh release.sh  # dist/へ配布ZIPとSHA-256を生成
```

`install.sh`は同名アプリを更新し、旧版のLaunchAgentがあれば無効化・退避します。自動起動は登録しません。

[MIT License](LICENSE)
