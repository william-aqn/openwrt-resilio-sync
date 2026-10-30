# Native compatibility libraries

Integration 1.1.0 replaces downloaded Debian libraries with two source-built
OpenWrt packages: `glibc-compat` 2.44-r1 and `libxcrypt-glibc-compat` 4.5.2-r1.
Both were built with the OpenWrt 25.12.5 mediatek/filogic SDK and installed on
the Flint 2 on 2026-10-30. All four packages also built with the fresh snapshot
SDK using GCC 14.4.0. The running Flint uses the 25.12.5 builds.
This resolves the Debian runtime dependency; it does not establish upstream
acceptance or permission to redistribute the proprietary application.

## Runtime layout

Libraries, the GNU loader, conversion modules and C.UTF-8 locale are installed
under `/usr/lib/glibc-compat`. The application remains under
`/usr/lib/resilio-sync/vendor/3.1.2.1076`. The wrapper invokes the private loader
explicitly, disables its cache and sets its library and locale paths. There is
no system-wide `/lib/ld-linux-aarch64.so.1` installation or musl replacement.

OpenWrt's existing `libgcc` package supplies the unwinder. Two private links,
`libgcc_s.so.1` to `/lib/libgcc_s.so.1` and `libc.so` to `libc.so.6`, allow it to
resolve its C API references within the glibc process. This is a deliberately
tested ARM64 compatibility choice, not a claim that arbitrary musl libraries
can be loaded into glibc. The cancellation test verifies both unwinding and the
absence of a musl mapping. Other toolchain versions require this test again.

## Reproducible inputs and build

| Component | Source | SHA-256 |
| --- | --- | --- |
| glibc 2.44 | `https://ftp.gnu.org/gnu/libc/glibc-2.44.tar.xz` | `37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667` |
| libxcrypt 4.5.2 | `https://github.com/besser82/libxcrypt/releases/download/v4.5.2/libxcrypt-4.5.2.tar.xz` | `71513a31c01a428bccd5367a32fd95f115d6dac50fb5b60c779d5c7942aec071` |

The SDK compiles both libraries; it does not repack distribution binaries.
libxcrypt builds against a separate glibc development sysroot, keeping those
headers out of OpenWrt's normal musl staging include directory. The resulting
libcrypt has `libc.so.6` as its ELF dependency.

GNU bison and localedef are build-host prerequisites. C.UTF-8 data is compiled
from the pinned glibc source with explicit little-endian output; localedef 2.43
was used for the validated ARM64 build. No host ELF library enters an APK.
glibc's `support` directory is excluded from the auxiliary-tools build and
installation because its test helpers use an IFUNC attribute rejected by the
musl-configured GCC. Runtime libraries are built normally; the glibc upstream
test suite is not claimed as passed.

```sh
JOBS=8 sh scripts/build-sdk.sh /path/to/openwrt-sdk
sh tests/build-runtime-abi.sh /path/to/openwrt-sdk ./runtime-abi
```

The snapshot check used `openwrt-sdk-mediatek-filogic_gcc-14.4.0_musl.Linux-x86_64.tar.zst`,
SHA-256 `62fb66294da46bba2fdd7e49a4b1832279e4c1c9e2af0e0b2e24f471ad5456cd`,
downloaded from the official mediatek/filogic snapshot directory on 2026-10-30.
Its base revision was `e262b0263dca09ce43b99b65ba348e29c74e025d` and packages feed
revision `4cc338143c547d663ac9d431a8a2121a0a639e1f`. Snapshot outputs are stored
separately under `dist/snapshot` using `DIST_DIR`; they were not installed on
the 25.12 router. Snapshot URLs roll forward, so check the recorded hash before
attempting to reproduce that exact build.

Copy the test executable to a router with both compatibility packages installed:

```sh
chmod 755 /tmp/runtime-abi
export LOCPATH=/usr/lib/glibc-compat/locale
export GCONV_PATH=/usr/lib/glibc-compat/gconv
/usr/lib/glibc-compat/ld-linux-aarch64.so.1 --inhibit-cache \
  --library-path /usr/lib/glibc-compat /tmp/runtime-abi
```

The probe checks the glibc version, C.UTF-8 conversion, DNS lookup of the vendor
download host, thread cancellation and process mappings. It creates no shared
files and reads no credentials. DNS requires working network access.

## Hardware results

- All four APKs built through the SDK and installed through apk.
- The vendor downloader fetched only the pinned Resilio archive and checked its
  SHA-256. No Debian archive was fetched by the new installer.
- The ABI probe passed UTF-8 conversion, DNS, cancellation and the no-musl check
  using the installed packages and OpenWrt GCC 14.3.0 libgcc.
- An isolated unprivileged Resilio instance served its GUI using the new source
  libraries. The existing service was then stopped, its state and credentials
  backed up privately, and the integration upgraded to 1.1.0-r1.
- The production process mapped glibc and libcrypt from `/usr/lib/glibc-compat`,
  with no Debian or musl library mapping. HTTPS authentication returned 200
  through both LAN and the user's Amnezia tunnel. Device identity, folder list
  and the configured full-copy mode were preserved; the app reported no error.

The earlier three-file transfer and checksum test used the previous Debian
runtime. It has not yet been repeated with an independent client against this
native runtime. Long-duration synchronization, selective retrieval, reboot,
physical disk removal and runtime testing on a snapshot firmware still require
validation. Snapshot SDK compilation passed; it is not a snapshot hardware test.

## Rejected gcompat experiment

Unmodified gcompat 1.1.0 plus OpenWrt libucontext 1.3.2 failed to load Resilio:
`mallopt` and `pthread_attr_setaffinity_np` were missing. Diagnostic functions
reporting unsupported operations allowed `--help`, but an isolated real start
aborted with `std::system_error` before the GUI became available. Those probes
are not shipped and production was never switched to gcompat.

## Remaining upstream decisions

The library packages themselves need maintainer review, security-update
ownership, ongoing master CI coverage and acceptance into the feed. The
private-libgcc compatibility approach and locale build must be reviewed.
The vendor application's redistribution terms and the acceptability of a
downloader package are separate unresolved decisions. See [UPSTREAM](UPSTREAM.md).
