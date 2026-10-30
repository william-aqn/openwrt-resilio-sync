# Resilio distribution questions

Draft for the project owner to review and send to Resilio. This has not been sent.

Hello,

I am preparing a community Resilio Sync integration for OpenWrt on ARM64:
https://github.com/william-aqn/openwrt-resilio-sync

The integration includes service management and a LuCI configuration page.
It currently downloads the unmodified Sync 3.1.2.1076 application directly from
Resilio after installation. Users supply their own license and accept the
application's terms themselves. The compatibility libraries build separately
from GNU glibc and libxcrypt source; we do not redistribute the Sync executable.

Before proposing this integration to OpenWrt, could you clarify:

1. May OpenWrt distribute the unmodified ARM64 Sync executable in its public
   APK/IPK packages and mirrors? If so, what notices, license presentation,
   distribution limits and update requirements apply?
2. If binary redistribution is not permitted, is a package that downloads a
   pinned, checksum-verified application directly from your CDN acceptable?
3. Is an ARM64 musl build available or planned? This would avoid a separate
   glibc compatibility runtime on OpenWrt.

The intended use is personal, non-commercial Sync. No business-use rights or
license bypass are requested. Thank you.
