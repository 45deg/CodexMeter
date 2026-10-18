#!/bin/zsh
set -eu
cd -- "${0:A:h}"
APP_TARGET="$HOME/Applications/Codex Meter.app"
AGENT_TARGET="$HOME/Library/LaunchAgents/local.codex.meter.autostart.plist"
test -x 'build/Codex Meter.app/Contents/MacOS/CodexMeter'
mkdir -p "$HOME/Applications"
# Retire the old registration so macOS Login Items is the only startup method.
if [[ -f "$AGENT_TARGET" ]]; then
    launchctl bootout "gui/$UID/local.codex.meter.autostart" 2>/dev/null || true
    AGENT_BACKUP="$(mktemp "$AGENT_TARGET.disabled.XXXXXX")"
    mv "$AGENT_TARGET" "$AGENT_BACKUP"
    print "旧LaunchAgentを無効化し、退避しました: $AGENT_BACKUP"
fi
killall -TERM CodexMeter 2>/dev/null || true
ditto 'build/Codex Meter.app' "$APP_TARGET"
open "$APP_TARGET"
echo "配置・起動完了: $APP_TARGET"
print '自動起動する場合は「システム設定 → 一般 → ログイン項目」でアプリを追加してください。'
