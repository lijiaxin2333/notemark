#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$TASK_ROOT"
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
<key>CFBundleShortVersionString</key><string>0.1.2</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSInputMonitoringUsageDescription</key><string>NoteMark 需要在 Apple 备忘录中识别 Markdown 输入并转换格式。</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier dev.local.notemark "$APP"
codesign --verify --strict "$APP"
"$APP/Contents/MacOS/NoteMark" --self-check
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
ARCHIVE="$TASK_ROOT/dist/NoteMark-$VERSION.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
printf 'Built: %s\n' "$APP"
printf 'Archive: %s\n' "$ARCHIVE"
