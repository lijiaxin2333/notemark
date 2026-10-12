#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$TASK_ROOT/Packaging/app.env"
CHECK_ONLY=0
if [ "${1:-}" = '--check' ]; then CHECK_ONLY=1; shift; fi
if [ "$#" -gt 1 ]; then echo 'Usage: sh scripts/install.sh [--check] [NoteMark.app]' >&2; exit 1; fi
SOURCE_APP=${1:-"$TASK_ROOT/dist/NoteMark.app"}
INSTALL_APP=${NOTEMARK_INSTALL_PATH:-/Applications/NoteMark.app}
BACKUP_DIR="$TASK_ROOT/dist/installed-backups"
# Keep this many backups of replaced apps; 0 keeps every backup. Leading zeros
# and values over six digits are rejected: shell arithmetic reads 010 as octal.
BACKUP_LIMIT=${NOTEMARK_BACKUP_LIMIT:-10}
case "$BACKUP_LIMIT" in ''|*[!0-9]*|0?*|???????*)
    echo 'NOTEMARK_BACKUP_LIMIT must be 0 or a positive integer without leading zeros.' >&2; exit 1 ;;
esac
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

bundle_id() { /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist"; }

# Keep the newest BACKUP_LIMIT backups, counting the one this install made ($1),
# which is never removed. Backup names start with a UTC timestamp, so reverse
# name order is newest first. Best effort: a backup that cannot be removed,
# such as a locked file, is reported and kept.
prune_backups() {
    [ "$BACKUP_LIMIT" -gt 0 ] || return 0
    CURRENT_BACKUP=$(basename -- "$1")
    ls -1 "$BACKUP_DIR" | /usr/bin/grep -E '^NoteMark-[0-9]{8}T[0-9]{6}Z-[0-9]+\.zip$' |
        /usr/bin/grep -vxF "$CURRENT_BACKUP" | sort -r | tail -n +"$BACKUP_LIMIT" |
        while IFS= read -r OLD_BACKUP; do
            if rm -f -- "$BACKUP_DIR/$OLD_BACKUP" 2>/dev/null; then
                printf 'Removed old backup: %s\n' "$OLD_BACKUP"
            else
                printf 'Could not remove old backup: %s\n' "$OLD_BACKUP" >&2
            fi
        done
}

# Write the designated requirement of app $1 to file $2. codesign prints an
# explicit requirement as "designated => ..." and the implicit requirement of
# an ad-hoc signature as "# designated => cdhash ...".
designated_requirement() {
    /usr/bin/codesign -d -r- "$1" > "$2.txt" 2>&1
    sed -n 's/^[# ]*designated => //p' "$2.txt" > "$2"
}

/usr/bin/ditto "$SOURCE_APP" "$STAGE/NoteMark.app"
NEW_APP="$STAGE/NoteMark.app"
/usr/bin/codesign --verify --strict "$NEW_APP"
if [ "$(bundle_id "$NEW_APP")" != "$NOTEMARK_BUNDLE_ID" ]; then
    echo 'This is not a NoteMark app.' >&2; exit 1
fi
designated_requirement "$NEW_APP" "$STAGE/new.req"
# Updates need the explicit requirement of a certificate signature. An ad-hoc
# build only has the implicit "# designated => cdhash ..." line.
if ! /usr/bin/grep -q '^designated => ' "$STAGE/new.req.txt" || /usr/bin/grep -q 'cdhash' "$STAGE/new.req"; then
    echo 'Updates require a certificate-signed app, not an ad-hoc build.' >&2; exit 1
fi
if [ -d "$INSTALL_APP" ]; then
    if [ "$(bundle_id "$INSTALL_APP")" != "$NOTEMARK_BUNDLE_ID" ]; then
        echo 'The install destination contains a different app.' >&2; exit 1
    fi
    /usr/bin/codesign --verify --strict "$INSTALL_APP"
    designated_requirement "$INSTALL_APP" "$STAGE/old.req"
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
BACKUP=
if [ -d "$INSTALL_APP" ]; then
    mkdir -p "$BACKUP_DIR"
    BACKUP="$BACKUP_DIR/NoteMark-$(date -u +%Y%m%dT%H%M%SZ)-$$.zip"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$INSTALL_APP" "$BACKUP"
    printf 'Backup: %s\n' "$BACKUP"
fi
# Ask running copies of the installed or source app to quit. JXA calls an
# Objective-C method without arguments through property syntax, so
# `app.terminate` sends -terminate and yields its BOOL result.
PIDS=$(/usr/bin/osascript -l JavaScript - "$NOTEMARK_BUNDLE_ID" "$INSTALL_APP" "$SOURCE_APP" <<'JXA'
ObjC.import('AppKit');
function run(argv) {
    const bundleID = argv[0];
    const appPaths = argv.slice(1);
    const apps = $.NSRunningApplication.runningApplicationsWithBundleIdentifier(bundleID);
    let pids = [];
    for (let i = 0; i < apps.count; i++) {
        const app = apps.objectAtIndex(i);
        if (appPaths.indexOf(app.bundleURL.path.js) !== -1) {
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
# Old backups are removed only once the new app is installed and verified.
if [ -n "$BACKUP" ]; then prune_backups "$BACKUP"; fi
printf 'Updated: %s\n' "$INSTALL_APP"
