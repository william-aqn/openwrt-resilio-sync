# Official OpenWrt package status

This repository is an external community feed. It has **not** been accepted
into `openwrt/packages`, and no official OpenWrt pkgdata entry has been created.

The goal is a package users can discover and install in the same way as
[Syncthing](https://openwrt.org/packages/pkgdata/syncthing). A wiki page by itself
would not deliver that: the package recipe needs review and acceptance, build
coverage, a maintainer and ongoing security updates.

## Which branch?

New packages belong on **master**. The packages repository's release branches,
including **openwrt-25.12**, accept security and bug fixes; its contribution guide
explicitly says not to add new packages to them. Forking master is correct.

Package submission target and installed firmware are separate choices. This
community integration is built with the **25.12.5 mediatek/filogic SDK** for the
existing Flint firmware. The router does not need a development snapshot merely
because a future upstream proposal would target master. Conversely, acceptance
on master would not automatically put a new package in the official 25.12 feed.

The local contribution fork was checked on 2026-10-29: master matched upstream
master at `6307bdf3b7`; upstream/openwrt-25.12 was available at `017f7ee81c`.
On 2026-10-30, local branch `resilio-sync-native-runtime` was created in the
contribution fork with `libs/glibc-compat`, `libs/libxcrypt-glibc-compat` and
`net/resilio-sync`. These are uncommitted review drafts. No public PR has been
created. The companion LuCI application stays in this community feed; proposing
it upstream would normally involve the separate `openwrt/luci` repository.

## Current blockers

The Debian library dependency was removed in integration 1.1.0. GNU glibc 2.44
and libxcrypt 4.5.2 now build from pinned upstream sources as native packages;
both are declared dependencies. Installation and hardware checks passed on
Flint 2; see [the native runtime record](NATIVE-RUNTIME.md).

The design is still **not ready to claim official acceptance**. Those new library
packages must themselves be reviewed and accepted, including their maintenance
cost, ARM64 libgcc interoperability and locale build. A fresh snapshot SDK build
with GCC 14.4.0 passed on 2026-10-30. Long-running synchronization, an independent
transfer test on the new runtime and snapshot hardware still need testing.

The proprietary application remains a separate issue. Resilio's published
[Terms of Use](https://www.resilio.com/legal/terms-of-use/) restrict copying and
redistribution, subject to the applicable software license. No separate grant
for OpenWrt binary redistribution has been obtained. Do not bundle the executable
in public APKs or assume that an installer downloading it makes the package
acceptable to maintainers. A vendor-supported musl build with clear distribution
permission would remove much of this compatibility burden.
The [vendor questions](VENDOR-REQUEST.md) are a short draft for the human project
owner; no message has been sent.

Upstream also requires disclosure of LLM usage and human understanding and
review. Its AI policy says: "Do not use autonomous agents for contributing to
our projects." The human contributor must review the implementation and write
or review communications; no automated PR submission or invented DCO sign-off
is part of this work.

## Already provided

- Native package Makefile, dependency metadata and conffiles.
- UCI/procd integration and a dedicated unprivileged account.
- Companion LuCI package with restricted configuration ACL.
- Pinned source-built library packages and a checksummed vendor downloader.
- SDK build workflow, local safety tests, hardware validation record.
- Installation, removal, licensing and maintenance documentation.

## Still required before proposing upstream inclusion

1. Review and accept the source-built library packages. Discuss proprietary
   downloader packaging and redistribution with
   maintainers and the vendor. Do not imply the MIT wrapper makes the
   proprietary application open source.
2. Resolve long-term maintenance: maintainer name/email, upstream update tracking,
   glibc/libcrypt security updates and testing on supported OpenWrt versions.
3. Obtain any required distribution permissions if reviewers require a bundled
   application. Current package artifacts contain no Resilio or Debian binaries.
4. Expand the completed licensed LAN transfer test with prolonged operation,
   selective retrieval, cold boot and disk removal tests; expand beyond the
   single tested ARM64 router only when actual validation is available.
5. Adapt the patch to current feed conventions and submit it with the real
   author's Developer Certificate of Origin sign-off. The maintainer field is
   deliberately blank rather than filled with an invented identity.

See [OpenWrt packages contribution requirements](https://github.com/openwrt/packages/blob/master/CONTRIBUTING.md).
This repository does not submit a PR, sign a DCO, create a public release or add
an official catalog entry automatically.
