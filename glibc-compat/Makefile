include $(TOPDIR)/rules.mk

PKG_NAME:=glibc-compat
PKG_VERSION:=2.44
PKG_RELEASE:=1
PKG_SOURCE:=glibc-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=@GNU/libc
PKG_HASH:=37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667
PKG_BUILD_DIR:=$(BUILD_DIR)/glibc-$(PKG_VERSION)
PKG_LICENSE:=LGPL-2.1-or-later
PKG_LICENSE_FILES:=COPYING.LIB LICENSES
PKG_MAINTAINER:=
PKG_CPE_ID:=cpe:/a:gnu:glibc
PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

GLIBC_COMPAT_DIR:=/usr/lib/glibc-compat
GLIBC_BISON?=bison
GLIBC_LOCALEDEF?=localedef

define Package/glibc-compat
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Isolated GNU C library for ARM64 binaries
  URL:=https://www.gnu.org/software/libc/
  DEPENDS:=@aarch64 @USE_MUSL +libgcc
endef

define Package/glibc-compat/description
 GNU libc built from source into an isolated directory. Does not replace musl
 or install a system ELF interpreter. Applications must opt in explicitly.
 Experimental ARM64 integration; requires separate upstream review.
endef

define Build/Configure
	command -v $(GLIBC_BISON) >/dev/null
	command -v $(GLIBC_LOCALEDEF) >/dev/null
	mkdir -p $(PKG_BUILD_DIR)/build
	(cd $(PKG_BUILD_DIR)/build; \
		$(TARGET_CONFIGURE_OPTS) \
		CC="$(TARGET_CC) -static-libgcc" CFLAGS="-O2 -pipe" \
		BISON="$(GLIBC_BISON)" \
		libc_cv_slibdir=$(GLIBC_COMPAT_DIR) \
		libc_cv_rtlddir=$(GLIBC_COMPAT_DIR) \
		../configure \
			--build=$(GNU_HOST_NAME) --host=aarch64-openwrt-linux-gnu \
			--prefix=/usr --libdir=$(GLIBC_COMPAT_DIR) \
			--with-headers=$(TOOLCHAIN_DIR)/include --enable-kernel=5.15 \
			--disable-werror --disable-nscd --disable-timezone-tools \
			--disable-fortify-source --enable-bind-now \
	)
endef

define Build/Compile
	+$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR)/build lib BISON="$(GLIBC_BISON)"
	+subdirs=$$$$(sed -n 's/^sorted-subdirs := //p' $(PKG_BUILD_DIR)/build/sysd-sorted | sed 's/ support / /'); \
	$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR)/build all subdirs="$$$$subdirs" BISON="$(GLIBC_BISON)"
endef

define Build/Install
	# The support directory contains test helpers with IFUNC C attributes that
	# musl-configured GCC rejects. Runtime libraries are built by the lib target.
	+subdirs=$$$$(sed -n 's/^sorted-subdirs := //p' $(PKG_BUILD_DIR)/build/sysd-sorted | sed 's/ support / /'); \
	$(MAKE) -C $(PKG_BUILD_DIR)/build install subdirs="$$$$subdirs" \
		BISON="$(GLIBC_BISON)" install_root=$(PKG_INSTALL_DIR)
	mkdir -p $(PKG_INSTALL_DIR)$(GLIBC_COMPAT_DIR)/locale
	I18NPATH=$(PKG_BUILD_DIR)/localedata $(GLIBC_LOCALEDEF) \
		--no-archive --little-endian \
		-i $(PKG_BUILD_DIR)/localedata/locales/C \
		-f $(PKG_BUILD_DIR)/localedata/charmaps/UTF-8 \
		$(PKG_INSTALL_DIR)$(GLIBC_COMPAT_DIR)/locale/C.utf8
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)$(GLIBC_COMPAT_DIR)/sysroot/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/include $(1)$(GLIBC_COMPAT_DIR)/sysroot/usr/
	$(CP) $(PKG_INSTALL_DIR)$(GLIBC_COMPAT_DIR) $(1)$(GLIBC_COMPAT_DIR)/sysroot/usr/lib/
endef

define Package/glibc-compat/install
	$(INSTALL_DIR) $(1)$(GLIBC_COMPAT_DIR) $(1)/usr/share/licenses/glibc-compat
	for lib in ld-linux-aarch64.so.1 libc.so.6 libm.so.6 libpthread.so.0 \
		libdl.so.2 librt.so.1 libresolv.so.2 libnss_dns.so.2 libnss_files.so.2; do \
		$(CP) $(PKG_INSTALL_DIR)$(GLIBC_COMPAT_DIR)/$$$$lib $(1)$(GLIBC_COMPAT_DIR)/; \
	done
	$(CP) $(PKG_INSTALL_DIR)$(GLIBC_COMPAT_DIR)/gconv $(1)$(GLIBC_COMPAT_DIR)/
	$(CP) $(PKG_INSTALL_DIR)$(GLIBC_COMPAT_DIR)/locale $(1)$(GLIBC_COMPAT_DIR)/
	# OpenWrt libgcc uses libc.so; resolve that name to this process's glibc.
	$(LN) libc.so.6 $(1)$(GLIBC_COMPAT_DIR)/libc.so
	$(LN) /lib/libgcc_s.so.1 $(1)$(GLIBC_COMPAT_DIR)/libgcc_s.so.1
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/COPYING.LIB $(PKG_BUILD_DIR)/LICENSES $(1)/usr/share/licenses/glibc-compat/
endef

$(eval $(call BuildPackage,glibc-compat))
