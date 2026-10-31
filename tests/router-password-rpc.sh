#!/bin/sh
# SPDX-License-Identifier: MIT
# Run on OpenWrt with ucode/fs. Only disposable mocked credentials are used.
set -eu
source=${1:-/usr/libexec/rpcd/resilio-sync}
fixture=$(mktemp -d /tmp/resilio-password-rpc.XXXXXX)
trap 'rm -f "$fixture/rpc" "$fixture/helper" "$fixture/received" "$fixture/result"; rmdir "$fixture"' EXIT
trap 'exit 1' HUP INT TERM
sed "s|/usr/sbin/resilio-sync-password --password-stdin|$fixture/helper|" "$source" > "$fixture/rpc"
cat > "$fixture/helper" <<EOF
#!/bin/sh
cat > '$fixture/received'
exit 10
EOF
chmod 700 "$fixture/helper"
count=0
check() {
	printf '%s' "$1" | ucode "$fixture/rpc" call set_password > "$fixture/result"
	[ "$(jsonfilter -i "$fixture/result" -e '@.code')" = "$2" ] || {
		echo "Unexpected RPC result for case $count" >&2; exit 1;
	}
	count=$((count + 1))
}
check '{}' invalid_password
check '{"password":123456789012}' invalid_password
check '{"password":"short"}' invalid_password
check '{"password":"LongEnoughPassword\n"}' invalid_password
check '{"password":"LongEnough\u0000Password"}' invalid_password
check '{"password":"LongEnoughPassword\u0000"}' invalid_password
check '{"password":"LongEnough\tPassword"}' invalid_password
check 'not-json' invalid_password
[ ! -e "$fixture/received" ]
# Shell syntax must arrive at the helper literally, never run as a command.
# shellcheck disable=SC2016
check '{"password":"Literal $() ; & test 1234"}' saved
# shellcheck disable=SC2016
[ "$(cat "$fixture/received")" = 'Literal $() ; & test 1234' ]
[ "$(jsonfilter -i "$fixture/result" -e '@.reloading')" = false ]
printf 'Passed %s RPC validation and stdin transport cases\n' "$count"
