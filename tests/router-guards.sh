#!/bin/sh
# SPDX-License-Identifier: MIT
# Run on an installed router: sh router-guards.sh /mnt/storage EXT4-UUID
# Read-only checks; no service configuration or user data is changed.
set -e
. /usr/lib/resilio-sync/common.sh
storage_mount=${1:?Pass an existing ext4 mount point}
storage_uuid=${2:?Pass its actual UUID}
user=rslsync
enabled=0
state_dir="$storage_mount/.resilio-guard-test"
directory_root="$storage_mount/resilio-guard-test"
webui_address=127.0.0.1
webui_port=8888
webui_login='admin'
listening_port=55555
use_upnp=0
download_limit=0
upload_limit=0
resilio_validate
resilio_mount_ready
original_uuid=$storage_uuid
storage_uuid=00000000-0000-0000-0000-000000000000
if resilio_mount_ready; then echo 'FAIL: wrong UUID accepted'; exit 1; fi
storage_uuid=$original_uuid
original_mount=$storage_mount
storage_mount=/tmp
if resilio_mount_ready; then echo 'FAIL: internal tmpfs accepted'; exit 1; fi
storage_mount=$original_mount
original_state=$state_dir
state_dir="$directory_root/private"
if resilio_validate 2>/dev/null; then echo 'FAIL: state inside shared root accepted'; exit 1; fi
state_dir=$original_state
user=root
if resilio_validate 2>/dev/null; then echo 'FAIL: root service accepted'; exit 1; fi
user=rslsync
webui_port=22
if resilio_validate 2>/dev/null; then echo 'FAIL: privileged port accepted'; exit 1; fi
webui_port=8888
webui_address='127.0.0.1;id'
if resilio_validate 2>/dev/null; then echo 'FAIL: command in address accepted'; exit 1; fi
echo 'PASS: actual mount, wrong UUID, wrong filesystem, state isolation, root, port and address guards'
