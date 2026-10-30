#!/bin/sh
# SPDX-License-Identifier: MIT
# Pure validation tests. No router, credentials or writable disks required.
set -eu
repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo/resilio-sync/files/common.sh"
count=0
accept() { resilio_path_valid "$1" || { echo "Unexpected rejection: $1" >&2; exit 1; }; count=$((count + 1)); }
reject() { if resilio_path_valid "$1"; then echo "Unexpected acceptance: $1" >&2; exit 1; fi; count=$((count + 1)); }
accept /mnt/storage
accept /mnt/storage/.resilio-sync
accept /mnt/storage/data/Resilio-3
reject /
reject relative/path
reject /mnt/storage/
reject /mnt//storage
reject /mnt/storage/../overlay
reject /mnt/storage/..
reject /mnt/./storage
reject /mnt/storage/.
reject '/mnt/storage/a b'
# shellcheck disable=SC2016 # Test literal shell syntax; never execute it.
reject '/mnt/storage/$(touch /tmp/injection)'
reject '/mnt/storage/a;echo'
reject '/mnt/storage/*'
printf 'Passed %s path safety cases\n' "$count"
