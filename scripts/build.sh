#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$TASK_ROOT"
SIGNING_IDENTITY=${NOTEMARK_SIGNING_IDENTITY:-}
if [ -z "$SIGNING_IDENTITY" ] && [ -f "$TASK_ROOT/.signing-identity" ]; then
    SIGNING_IDENTITY=$(cat "$TASK_ROOT/.signing-identity")
fi
if [ -z "$SIGNING_IDENTITY" ]; then
    echo 'Configure a stable signing identity first: sh scripts/configure-signing.sh CERTIFICATE_SHA1' >&2
    echo 'For a temporary ad-hoc test build only, set NOTEMARK_SIGNING_IDENTITY=-.' >&2
    exit 1
fi
swift build -c release
APP="$TASK_ROOT/dist/NoteMark.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$TASK_ROOT/.build/release/NoteMark" "$APP/Contents/MacOS/NoteMark"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.local.notemark</string>
<key>CFBundleName</key><string>NoteMark</string>
<key>CFBundleDisplayName</key><string>NoteMark</string>
<key>CFBundleExecutable</key><string>NoteMark</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.5</string>
<key>CFBundleVersion</key><string>6</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSInputMonitoringUsageDescription</key><string>NoteMark 需要在 Apple 备忘录中识别 Markdown 输入并转换格式。</string>
</dict></plist>
PLIST
codesign --force --sign "$SIGNING_IDENTITY" --identifier dev.local.notemark --options runtime "$APP"
codesign --verify --strict "$APP"
codesign -d -r- "$APP" > "$TASK_ROOT/dist/signing-requirement.txt" 2>&1
"$APP/Contents/MacOS/NoteMark" --self-check
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
ARCHIVE="$TASK_ROOT/dist/NoteMark-$VERSION.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
printf 'Built: %s\n' "$APP"
printf 'Archive: %s\n' "$ARCHIVE"
