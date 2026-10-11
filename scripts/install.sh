#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHECK_ONLY=0
if [ "${1:-}" = '--check' ]; then CHECK_ONLY=1; shift; fi
if [ "$#" -gt 1 ]; then echo 'Usage: sh scripts/install.sh [--check] [NoteMark.app]' >&2; exit 1; fi
SOURCE_APP=${1:-"$TASK_ROOT/dist/NoteMark.app"}
INSTALL_APP=${NOTEMARK_INSTALL_PATH:-/Applications/NoteMark.app}
case "$INSTALL_APP" in /*/NoteMark.app) ;; *) echo 'Install path must be absolute and end in /NoteMark.app.' >&2; exit 1 ;; esac
SOURCE_PARENT=$(CDPATH= cd -- "$(dirname -- "$SOURCE_APP")" && pwd)
SOURCE_APP="$SOURCE_PARENT/$(basename -- "$SOURCE_APP")"
if [ "$SOURCE_APP" = "$INSTALL_APP" ]; then echo 'Source and installed app must be different paths.' >&2; exit 1; fi
PARENT=$(dirname -- "$INSTALL_APP")
if [ ! -d "$PARENT" ] || [ ! -w "$PARENT" ]; then echo 'The install directory must exist and be writable.' >&2; exit 1; fi
STAGE=$(mktemp -d "$PARENT/.notemark-update.XXXXXX")
cleanup() {
    # Recover the previous app if replacement failed between the two renames.
    if [ -d "$STAGE/previous.app" ] && [ ! -e "$INSTALL_APP" ]; then
        mv "$STAGE/previous.app" "$INSTALL_APP"
    fi
    rm -rf "$STAGE"
}
trap cleanup 0
trap 'exit 1' 1 2 15
/usr/bin/ditto "$SOURCE_APP" "$STAGE/NoteMark.app"
NEW_APP="$STAGE/NoteMark.app"
/usr/bin/codesign --verify --strict "$NEW_APP"
if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$NEW_APP/Contents/Info.plist")" != 'dev.local.notemark' ]; then
    echo 'This is not a NoteMark app.' >&2; exit 1
fi
/usr/bin/codesign -d -r- "$NEW_APP" > "$STAGE/new-signature.txt" 2>&1
sed -n 's/^designated => //p' "$STAGE/new-signature.txt" > "$STAGE/new.req"
if [ ! -s "$STAGE/new.req" ] || /usr/bin/grep -q 'cdhash' "$STAGE/new.req"; then
    echo 'Updates require a certificate-signed app, not an ad-hoc build.' >&2; exit 1
fi
if [ -d "$INSTALL_APP" ]; then
    if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INSTALL_APP/Contents/Info.plist")" != 'dev.local.notemark' ]; then
        echo 'The install destination contains a different app.' >&2; exit 1
    fi
    /usr/bin/codesign --verify --strict "$INSTALL_APP"
    /usr/bin/codesign -d -r- "$INSTALL_APP" > "$STAGE/old-signature.txt" 2>&1
    sed -n 's/^[# ]*designated => //p' "$STAGE/old-signature.txt" > "$STAGE/old.req"
    if [ ! -s "$STAGE/old.req" ]; then echo 'Cannot identify the installed app signature.' >&2; exit 1; fi
    if /usr/bin/grep -q 'cdhash' "$STAGE/old.req"; then
        echo 'Migrating from ad-hoc signing: grant permissions once after this update.'
    elif ! /usr/bin/codesign --verify --strict -R "$STAGE/old.req" "$NEW_APP" 2>/dev/null ||
         ! /usr/bin/codesign --verify --strict -R "$STAGE/new.req" "$INSTALL_APP" 2>/dev/null; then
        if [ "${NOTEMARK_ALLOW_IDENTITY_CHANGE:-0}" != 1 ]; then
            echo 'Signing identity changed. Update stopped to avoid losing permissions.' >&2
            echo 'For an intentional certificate migration, set NOTEMARK_ALLOW_IDENTITY_CHANGE=1.' >&2
            exit 1
        fi
        echo 'Intentional signing identity migration: permissions may need to be granted again.'
    else
        echo 'Signing identities are compatible with the installed app.'
    fi
fi
if [ "$CHECK_ONLY" = 1 ]; then echo 'Update check passed; installed app was not changed.'; exit 0; fi
"$NEW_APP/Contents/MacOS/NoteMark" --self-check
if [ -d "$INSTALL_APP" ]; then
    mkdir -p "$TASK_ROOT/dist/installed-backups"
    BACKUP="$TASK_ROOT/dist/installed-backups/NoteMark-$(date -u +%Y%m%dT%H%M%SZ)-$$.zip"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$INSTALL_APP" "$BACKUP"
    printf 'Backup: %s\n' "$BACKUP"
fi
PIDS=$(/usr/bin/osascript -l JavaScript - "$INSTALL_APP" "$SOURCE_APP" <<'JXA'
ObjC.import('AppKit');
function run(argv) {
    const apps = $.NSRunningApplication.runningApplicationsWithBundleIdentifier('dev.local.notemark');
    let pids = [];
    for (let i = 0; i < apps.count; i++) {
        const app = apps.objectAtIndex(i);
        if (argv.indexOf(app.bundleURL.path.js) !== -1) {
            const pid = app.processIdentifier;
            if (!app.terminate) throw new Error('NoteMark did not accept the quit request.');
            pids.push(pid);
        }
    }
    return pids.join(' ');
}
JXA
)
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    STILL_RUNNING=0
    for pid in $PIDS; do if kill -0 "$pid" 2>/dev/null; then STILL_RUNNING=1; fi; done
    if [ "$STILL_RUNNING" = 0 ]; then break; fi
    sleep 0.2
done
if [ "$STILL_RUNNING" != 0 ]; then echo 'NoteMark is still running; update stopped.' >&2; exit 1; fi
if [ -d "$INSTALL_APP" ]; then mv "$INSTALL_APP" "$STAGE/previous.app"; fi
mv "$NEW_APP" "$INSTALL_APP"
if ! /usr/bin/codesign --verify --strict "$INSTALL_APP"; then
    mv "$INSTALL_APP" "$STAGE/failed.app"
    echo 'Installed signature verification failed; restoring the previous app.' >&2
    exit 1
fi
/usr/bin/open -g "$INSTALL_APP"
printf 'Updated: %s\n' "$INSTALL_APP"
