#!/bin/sh
# SPDX-License-Identifier: MIT
# Run from Linux/WSL: ./scripts/build-sdk.sh /absolute/path/to/openwrt-sdk
set -eu
glibc_bison=${GLIBC_BISON:-$(command -v bison || true)}
glibc_localedef=${GLIBC_LOCALEDEF:-$(command -v localedef || true)}
if [ ! -x "$glibc_bison" ] || [ ! -x "$glibc_localedef" ]; then
	echo 'Install GNU bison and localedef on the build host' >&2; exit 1;
fi
repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
sdk=$(CDPATH='' cd -- "${1:?Pass the OpenWrt SDK directory}" && pwd)
dist=${DIST_DIR:-"$repo/dist"}
case "$dist" in /*) ;; *) echo 'DIST_DIR must be an absolute path' >&2; exit 1 ;; esac
if [ ! -f "$sdk/rules.mk" ] || [ ! -x "$sdk/scripts/feeds" ]; then
	echo 'Not an OpenWrt SDK directory' >&2; exit 1;
fi
cd "$sdk"
./scripts/feeds update base packages luci
./scripts/feeds install xz tar curl openssl jshn block-mount flock luci-base
packages='glibc-compat libxcrypt-glibc-compat resilio-sync luci-app-resilio-sync'
for package in $packages; do
	mkdir -p "package/$package"
	cp -a "$repo/$package/." "package/$package/"
done
# SDKs ship with ALL/ALL_KMODS enabled. Keep target selection, but build only
# these packages and their dependencies rather than every dependency variant.
if [ -f .config ]; then
	cp .config .config.before-resilio
	grep '^CONFIG_TARGET' .config.before-resilio > .config || true
else
	: > .config
fi
printf '\n# CONFIG_ALL is not set\n# CONFIG_ALL_KMODS is not set\n# CONFIG_ALL_NONSHARED is not set\n# CONFIG_LUCI_JSMIN is not set\n# CONFIG_LUCI_CSSTIDY is not set\nCONFIG_PACKAGE_resilio-sync=m\nCONFIG_PACKAGE_luci-app-resilio-sync=m\n' >> .config
make defconfig
for package in $packages; do
	grep -Eq "^CONFIG_PACKAGE_$package=[my]$" .config
done
# NO_DEPS skips the SDK's normal key-generation prerequisite. Keep one local
# signing identity per SDK; never replace an existing key or copy it to dist.
if grep -q '^CONFIG_USE_APK=y$' .config; then
	if [ ! -s private-key.pem ]; then
		(umask 077; openssl ecparam -name prime256v1 -genkey -noout -out private-key.pem)
	fi
	if [ ! -s public-key.pem ]; then
		openssl ec -in private-key.pem -pubout -out public-key.pem
	fi
fi
# Build our native dependencies in order. Other runtime dependencies are
# resolved from the matching OpenWrt feed when packages are installed.
for package in $packages; do
	make -j"${JOBS:-2}" "package/$package/compile" NO_DEPS=1 V=s \
		GLIBC_BISON="$glibc_bison" GLIBC_LOCALEDEF="$glibc_localedef"
done
mkdir -p "$dist"
# Retire only this helper's package outputs, so install wildcards never select
# an obsolete release left by a previous build.
for package in $packages; do
	find "$dist" -maxdepth 1 -type f \( -name "$package-*.apk" -o -name "${package}_*.ipk" \) -delete
	version=$(sed -n 's/^PKG_VERSION:=//p' "$repo/$package/Makefile")
	release=$(sed -n 's/^PKG_RELEASE:=//p' "$repo/$package/Makefile")
	artifact=$(find bin/packages -type f \( -name "$package-$version-r$release.apk" -o -name "${package}_${version}-${release}_*.ipk" -o -name "${package}_${version}-r${release}_*.ipk" \) -print -quit)
	[ -n "$artifact" ] || { echo "Package output missing: $package" >&2; exit 1; }
	cp "$artifact" "$dist/"
done
cd "$dist"
sha256sum ./*.apk > SHA256SUMS 2>/dev/null || sha256sum ./*.ipk > SHA256SUMS
