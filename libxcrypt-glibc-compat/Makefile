include $(TOPDIR)/rules.mk

PKG_NAME:=libxcrypt-glibc-compat
PKG_VERSION:=4.5.2
PKG_RELEASE:=1
PKG_SOURCE:=libxcrypt-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=https://github.com/besser82/libxcrypt/releases/download/v$(PKG_VERSION)
PKG_HASH:=71513a31c01a428bccd5367a32fd95f115d6dac50fb5b60c779d5c7942aec071
PKG_BUILD_DIR:=$(BUILD_DIR)/libxcrypt-$(PKG_VERSION)
PKG_LICENSE:=LGPL-2.1-or-later
PKG_LICENSE_FILES:=COPYING.LIB LICENSING
PKG_MAINTAINER:=
PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

COMPAT_SYSROOT:=$(STAGING_DIR)/usr/lib/glibc-compat/sysroot
COMPAT_LIB:=$(COMPAT_SYSROOT)/usr/lib/glibc-compat
COMPAT_CC:=$(TARGET_CC) -static-libgcc --sysroot=$(COMPAT_SYSROOT) -B$(COMPAT_LIB)/

define Package/libxcrypt-glibc-compat
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=libcrypt ABI for isolated GNU libc
  URL:=https://github.com/besser82/libxcrypt
  DEPENDS:=@aarch64 @USE_MUSL +glibc-compat
endef

define Build/Prepare
	$(call Build/Prepare/Default)
endef

define Build/Configure
	mkdir -p $(PKG_BUILD_DIR)/build
	(cd $(PKG_BUILD_DIR)/build; \
		$(TARGET_CONFIGURE_OPTS) CC="$(COMPAT_CC)" \
		CFLAGS="-O2 -nostdinc -isystem $(COMPAT_SYSROOT)/usr/include -isystem $$$$($(TARGET_CC) -print-file-name=include) -isystem $(TOOLCHAIN_DIR)/include" \
		LDFLAGS="-L$(COMPAT_LIB) -Wl,-rpath-link,$(COMPAT_LIB)" \
		../configure --build=$(GNU_HOST_NAME) --host=aarch64-openwrt-linux-gnu \
			--prefix=/usr --libdir=/usr/lib/glibc-compat \
			--disable-static --disable-werror --enable-obsolete-api=glibc \
	)
endef

define Build/Compile
	+$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR)/build
endef

define Build/Install
	+$(MAKE) -C $(PKG_BUILD_DIR)/build DESTDIR=$(PKG_INSTALL_DIR) install
endef

define Package/libxcrypt-glibc-compat/install
	$(INSTALL_DIR) $(1)/usr/lib/glibc-compat $(1)/usr/share/licenses/libxcrypt-glibc-compat
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/glibc-compat/libcrypt.so.1* $(1)/usr/lib/glibc-compat/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/COPYING.LIB $(PKG_BUILD_DIR)/LICENSING $(1)/usr/share/licenses/libxcrypt-glibc-compat/
endef

$(eval $(call BuildPackage,libxcrypt-glibc-compat))
