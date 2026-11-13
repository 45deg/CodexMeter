#!/bin/zsh
# Tests and builds the app, then packages it with both READMEs and a ZIP checksum.
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
for DOCUMENT in README.md README_ja.md LICENSE; do
    cp "$DOCUMENT" "$STAGING/$PACKAGE/"
done
ditto -c -k --norsrc --noextattr --noacl --keepParent "$STAGING/$PACKAGE" "$STAGING/$PACKAGE.zip"
mv "$STAGING/$PACKAGE.zip" "$PROJECT_ROOT/dist/$PACKAGE.zip"
(cd dist && shasum -a 256 "$PACKAGE.zip" > "$PACKAGE.zip.sha256")
print "Created release archive: dist/$PACKAGE.zip"
print 'The app has an ad hoc signature and is not Developer ID signed or notarized.'
