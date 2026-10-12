#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$TASK_ROOT"
. "$TASK_ROOT/Packaging/app.env"
SIGNING_IDENTITY=${NOTEMARK_SIGNING_IDENTITY:-}
if [ -z "$SIGNING_IDENTITY" ] && [ -f "$TASK_ROOT/.signing-identity" ]; then
    SIGNING_IDENTITY=$(cat "$TASK_ROOT/.signing-identity")
fi
if [ -z "$SIGNING_IDENTITY" ]; then
    echo 'Configure a stable signing identity first: sh scripts/configure-signing.sh CERTIFICATE_SHA1' >&2
    echo 'For a temporary ad-hoc test build only, set NOTEMARK_SIGNING_IDENTITY=-.' >&2
    exit 1
fi
# Unit tests cover the rules in depth; the release binary's --self-check below
# only confirms that the packaged build runs.
if [ "${NOTEMARK_SKIP_TESTS:-0}" != 1 ]; then swift test; fi
swift build -c release
APP="$TASK_ROOT/dist/NoteMark.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$TASK_ROOT/.build/release/NoteMark" "$APP/Contents/MacOS/NoteMark"
sed -e "s/@NOTEMARK_BUNDLE_ID@/$NOTEMARK_BUNDLE_ID/" \
    -e "s/@NOTEMARK_VERSION@/$NOTEMARK_VERSION/" \
    -e "s/@NOTEMARK_BUILD@/$NOTEMARK_BUILD/" \
    "$TASK_ROOT/Packaging/Info.plist" > "$APP/Contents/Info.plist"
/usr/bin/plutil -lint -s "$APP/Contents/Info.plist"
codesign --force --sign "$SIGNING_IDENTITY" --identifier "$NOTEMARK_BUNDLE_ID" --options runtime "$APP"
codesign --verify --strict "$APP"
codesign -d -r- "$APP" > "$TASK_ROOT/dist/signing-requirement.txt" 2>&1
"$APP/Contents/MacOS/NoteMark" --self-check
ARCHIVE="$TASK_ROOT/dist/NoteMark-$NOTEMARK_VERSION.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
printf 'Built: %s\n' "$APP"
printf 'Archive: %s\n' "$ARCHIVE"
