#!/bin/sh
# SPDX-License-Identifier: MIT
# shellcheck disable=SC2154 # OpenWrt config_get assigns the named variables.
# Paths intentionally exclude whitespace and shell metacharacters.

resilio_error() { echo "resilio-sync: $*" >&2; return 1; }

resilio_load() {
	. /lib/functions.sh
	config_load resilio-sync
	config_get enabled main enabled 0
	config_get user main user rslsync
	config_get device_name main device_name OpenWrt
	config_get storage_mount main storage_mount /mnt/storage
	config_get storage_uuid main storage_uuid
	config_get state_dir main state_dir /mnt/storage/.resilio-sync
	config_get directory_root main directory_root /mnt/storage/data/Resilio
	config_get webui_address main webui_address 127.0.0.1
	config_get webui_port main webui_port 8888
	config_get webui_login main webui_login admin
	config_get listening_port main listening_port 55555
	config_get use_upnp main use_upnp 0
	config_get download_limit main download_limit 0
	config_get upload_limit main upload_limit 0
}

resilio_path_valid() {
	case "$1" in
		/*) ;;
		*) return 1 ;;
	esac
	case "$1" in
		/|*/|*//*|*/../*|*/..|*/./*|*/.|*[!a-zA-Z0-9_./-]*) return 1 ;;
	esac
}

resilio_validate() {
	case "$user" in ''|*[!a-zA-Z0-9_-]*) resilio_error 'Invalid service user'; return 1 ;; esac
	[ "$(id -u "$user" 2>/dev/null)" -gt 0 ] 2>/dev/null || {
		resilio_error 'A non-root service user is required'; return 1;
	}
	for path in "$storage_mount" "$state_dir" "$directory_root"; do
		resilio_path_valid "$path" || { resilio_error "Invalid path: $path"; return 1; }
	done
	case "$state_dir" in "$storage_mount"/*) ;; *) resilio_error 'State must be below the storage mount'; return 1 ;; esac
	case "$directory_root" in "$storage_mount"/*) ;; *) resilio_error 'Shared folders must be below the storage mount'; return 1 ;; esac
	case "$state_dir/" in "$directory_root/"*) resilio_error 'State must not be inside the shared root'; return 1 ;; esac
	case "$directory_root/" in "$state_dir/"*) resilio_error 'Shared root must not be inside state'; return 1 ;; esac
	case "$storage_uuid" in ''|*[!a-fA-F0-9-]*) resilio_error 'Set the ext4 filesystem UUID'; return 1 ;; esac
	case "$webui_address" in ''|*[!0-9.]*) resilio_error 'Web UI address must be an IPv4 address'; return 1 ;; esac
	printf '%s\n' "$webui_address" | awk -F. 'NF != 4 {exit 1} {for(i=1;i<=4;i++) if($i=="" || $i>255) exit 1}' || return 1
	for port in "$webui_port" "$listening_port"; do
		case "$port" in ''|*[!0-9]*) resilio_error 'Invalid port'; return 1 ;; esac
		[ "$port" -ge 1024 ] && [ "$port" -le 65535 ] || { resilio_error 'Ports must be between 1024 and 65535'; return 1; }
	done
	[ "$webui_port" != "$listening_port" ] || { resilio_error 'Web UI and transfer ports must differ'; return 1; }
	for limit in "$download_limit" "$upload_limit"; do
		case "$limit" in ''|*[!0-9]*) resilio_error 'Invalid speed limit'; return 1 ;; esac
		[ "$limit" -le 2147483647 ] || return 1
	done
	case "$use_upnp:$enabled" in [01]:[01]) ;; *) resilio_error 'Invalid boolean option'; return 1 ;; esac
	[ -n "$webui_login" ] || { resilio_error 'Web UI login is required'; return 1; }
}

resilio_mount_ready() {
	[ "$(readlink -f "$storage_mount")" = "$storage_mount" ] || return 1
	device=$(awk -v point="$storage_mount" '$2 == point && $3 == "ext4" && $4 ~ /(^|,)rw(,|$)/ {print $1; exit}' /proc/mounts)
	[ -n "$device" ] || return 1
	/sbin/block info "$device" 2>/dev/null | grep -Fq "UUID=\"$storage_uuid\"" || return 1
}

resilio_paths_ready() {
	resilio_mount_ready || { resilio_error 'Expected writable ext4 filesystem is not mounted'; return 1; }
	for path in "$state_dir" "$directory_root"; do
		[ -d "$path" ] && [ "$(readlink -f "$path")" = "$path" ] || {
			resilio_error "Missing directory or symlink path: $path (run resilio-sync-setup)"; return 1;
		}
	done
}
