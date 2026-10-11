#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ "$#" -ne 1 ]; then
    echo 'Usage: sh scripts/configure-signing.sh CERTIFICATE_SHA1' >&2
    /usr/bin/security find-identity -v -p codesigning
    exit 1
fi
IDENTITY=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
case "$IDENTITY" in ''|*[!0-9A-F]*) echo 'Use the 40-character certificate SHA-1 shown by security find-identity.' >&2; exit 1 ;; esac
if [ "${#IDENTITY}" -ne 40 ] || ! /usr/bin/security find-identity -v -p codesigning | awk -v hash="$IDENTITY" '$2 == hash { found = 1 } END { exit !found }'; then
    echo 'The requested signing identity is not available in this keychain.' >&2
    exit 1
fi
umask 077
printf '%s\n' "$IDENTITY" > "$TASK_ROOT/.signing-identity"
echo 'Saved the signing identity locally. Use this same identity for future updates.'
