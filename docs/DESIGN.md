# Design and provenance

## Why a private runtime

The publisher supplies an ARM64 ELF binary linked against glibc and libcrypt.
OpenWrt uses musl. An ARM64 CPU alone is therefore insufficient: the requested
ELF interpreter and several shared libraries are absent.

The wrapper explicitly invokes a private `ld-linux-aarch64.so.1` with a private
library search path and the system loader cache disabled. It clears loader
environment overrides. No file is installed to OpenWrt's `/lib`, no libc symlink
is replaced, and Docker/Entware are not required. The vendor executable stays
unmodified and root-owned, while the service runs unprivileged.

This is a packaging/integration port, not a source build of Resilio. Package
version 1.1.0 identifies the integration; application version is 3.1.2.1076.

## Inputs

The application URL and hash live in
[`runtime.conf`](../resilio-sync/files/runtime.conf). Library sources and hashes
are pinned in their package Makefiles:

| Component | Pinned version | Publisher |
| --- | --- | --- |
| Resilio Sync ARM64 | 3.1.2.1076 | Resilio download CDN |
| GNU glibc | 2.44 | GNU source archive |
| libxcrypt | 4.5.2 | Upstream release archive |
| libgcc | Firmware toolchain version | OpenWrt official package |

The Resilio URL includes the complete upstream version and build number.
The mutable `stable` URL is not used by the installer. Libraries are compiled by
the OpenWrt SDK from upstream archives checked against `PKG_HASH`. There is no
Debian archive extraction or library download on the router.
The Resilio hash pins the reviewed download; it is not an upstream signature.

All downloads must verify before extraction. Installation uses a temporary
directory on the same filesystem and renames the complete payload into place
only after the executable reports the expected version. An exclusive lock
prevents simultaneous runtime installers. Existing runtime versions are kept.

The glibc package includes conversion modules and a compiled C.UTF-8 locale.
The wrapper sets `LC_ALL`, `GCONV_PATH` and `LOCPATH`. Libraries live under
`/usr/lib/glibc-compat`; no system interpreter or musl file is replaced.
Private links allow glibc to use OpenWrt's libgcc unwinder without loading musl
into the same process. This requires architecture-specific testing; see
[native runtime validation](NATIVE-RUNTIME.md). GNU libc security updates now
require rebuilding its package; upgrading musl alone still does not update it.

## State and trust boundaries

- `/usr/lib/resilio-sync/vendor/`: downloaded, root-owned application.
- `/usr/lib/glibc-compat/`: package-managed compatibility libraries and locale.
- `/etc/resilio-sync/`: root-only password hash and TLS source files.
- `/var/run/resilio-sync/`: generated JSON and TLS files readable by the service.
- External `state_dir`: identity, databases, logs and application settings.
- External `directory_root`: root of the folder picker and allowed shared folders.

UCI values are serialized with OpenWrt's JSON library, not interpolated into
JSON or shell commands. Paths are restricted and symlink traversal during setup
is rejected. The private state and shared root cannot contain each other.
The UI's folder restriction is not an operating-system sandbox: Unix ownership
is still the boundary for filesystem access by the process.

The generated JSON deliberately omits `shared_folders`: upstream disables its
web UI when that setting is supplied. Shared folders are maintained in the
application's own external state. The default service keeps two indexing
workers, limits direct-torrent memory to 64 MiB and uses low CPU priority. These
are tuning values, not a hard cap on total process memory.

## Licensing and distribution

The integration is MIT licensed. The library packages contain GNU glibc and
libxcrypt under their upstream licenses, including the installed license notices.
The proprietary Resilio executable is excluded from APKs and CI artifacts;
its downloaded `LICENSE.TXT` is retained. The repository's MIT license does not
relicense any of these upstream components.

The vendor license link currently redirects to Nasuni's legal site. This
project does not interpret that redirect as permission to redistribute the
Resilio executable. Any future bundled distribution needs a separate licensing
review. The integration does not accept the first-run terms or obtain a license
on the user's behalf.

Library source archives are fetched by the SDK from the immutable locations in
the recipes. Any public binary release must provide the corresponding sources
and build instructions in accordance with the applicable licenses.
