#!/bin/sh
# SPDX-License-Identifier: MIT
set -eu
sdk=$(CDPATH='' cd -- "${1:?Pass the SDK directory}" && pwd)
output=${2:?Pass the output executable path}
tests=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
toolchain=$(find "$sdk/staging_dir" -maxdepth 1 -type d -name 'toolchain-aarch64*_musl' -print -quit)
target=$(find "$sdk/staging_dir" -maxdepth 1 -type d -name 'target-aarch64*_musl' -print -quit)
[ -n "$toolchain" ] && [ -n "$target" ]
cc="$toolchain/bin/aarch64-openwrt-linux-musl-gcc"
sysroot="$target/usr/lib/glibc-compat/sysroot"
lib="$sysroot/usr/lib/glibc-compat"
[ -f "$sysroot/usr/include/gnu/stubs-lp64.h" ]
export STAGING_DIR="$target"
"$cc" -static-libgcc --sysroot="$sysroot" -B"$lib/" \
	-O2 -Wall -Wextra -Werror -nostdinc \
	-isystem "$sysroot/usr/include" -isystem "$("$cc" -print-file-name=include)" \
	-isystem "$toolchain/include" -L"$lib" -Wl,-rpath-link,"$lib" \
	-o "$output" "$tests/runtime_abi.c" -pthread
