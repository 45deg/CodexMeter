#!/bin/zsh
set -eu
setopt pipefail
cd -- "${0:A:h}"
PROJECT_ROOT="$PWD"
VERSION="$(< VERSION)"
zsh test.sh
zsh build.sh
APP="$PROJECT_ROOT/build/Codex Meter.app"
mkdir -p dist
STAGING="$(mktemp -d "$PROJECT_ROOT/build/release.XXXXXX")"
trap 'rm -rf -- "$STAGING"' EXIT
PACKAGE="Codex-Meter-$VERSION-macos-arm64"
mkdir -p "$STAGING/$PACKAGE"
ditto --norsrc --noextattr --noacl "$APP" "$STAGING/$PACKAGE/Codex Meter.app"
for DOCUMENT in README.md LICENSE; do
    cp "$DOCUMENT" "$STAGING/$PACKAGE/"
done
mkdir -p "$STAGING/$PACKAGE/assets"
cp assets/screenshot.png "$STAGING/$PACKAGE/assets/"
ditto -c -k --norsrc --noextattr --noacl --keepParent "$STAGING/$PACKAGE" "$STAGING/$PACKAGE.zip"
mv "$STAGING/$PACKAGE.zip" "$PROJECT_ROOT/dist/$PACKAGE.zip"
(cd dist && shasum -a 256 "$PACKAGE.zip" > "$PACKAGE.zip.sha256")
print "配布候補を作成しました: dist/$PACKAGE.zip"
print 'このZIPはアドホック署名です。Developer IDによる署名・Appleによる公証は未実施です。'
