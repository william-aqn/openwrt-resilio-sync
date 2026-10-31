include $(TOPDIR)/rules.mk

PKG_NAME:=resilio-sync
PKG_VERSION:=1.1.0
PKG_RELEASE:=2
PKG_LICENSE:=MIT
PKG_MAINTAINER:=

include $(INCLUDE_DIR)/package.mk

define Package/resilio-sync
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=File Transfer
  TITLE:=Resilio Sync 3 integration (external runtime)
  URL:=https://github.com/william-aqn/openwrt-resilio-sync
  DEPENDS:=@aarch64 +glibc-compat +libxcrypt-glibc-compat +ca-bundle +curl +xz-utils +tar +openssl-util +jshn +block-mount +flock
  USERID:=rslsync:rslsync
endef

define Package/resilio-sync/description
 OpenWrt service integration for the proprietary Resilio Sync 3 application.
 Includes UCI settings, disk guards and an explicit, checksummed runtime
 downloader. The vendor executable is not included. ARM64 only.
endef

define Package/resilio-sync/conffiles
/etc/config/resilio-sync
/etc/resilio-sync/
endef

define Build/Compile
endef

define Package/resilio-sync/install
	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d $(1)/etc/hotplug.d/block
	$(INSTALL_DIR) $(1)/usr/bin $(1)/usr/sbin $(1)/usr/lib/resilio-sync
	$(INSTALL_DIR) $(1)/usr/libexec $(1)/etc/resilio-sync
	$(INSTALL_DIR) $(1)/usr/share/licenses/resilio-sync
	$(INSTALL_DATA) ./LICENSE $(1)/usr/share/licenses/resilio-sync/LICENSE
	$(INSTALL_CONF) ./files/resilio-sync.config $(1)/etc/config/resilio-sync
	$(INSTALL_BIN) ./files/resilio-sync.init $(1)/etc/init.d/resilio-sync
	$(INSTALL_BIN) ./files/resilio-sync.hotplug $(1)/etc/hotplug.d/block/95-resilio-sync
	$(INSTALL_BIN) ./files/rslsync $(1)/usr/bin/rslsync
	$(INSTALL_BIN) ./files/resilio-sync-runtime $(1)/usr/sbin/resilio-sync-runtime
	$(INSTALL_BIN) ./files/resilio-sync-setup $(1)/usr/sbin/resilio-sync-setup
	$(INSTALL_BIN) ./files/resilio-sync-password $(1)/usr/sbin/resilio-sync-password
	$(INSTALL_BIN) ./files/resilio-sync-config $(1)/usr/libexec/resilio-sync-config
	$(INSTALL_DATA) ./files/common.sh $(1)/usr/lib/resilio-sync/common.sh
	$(INSTALL_DATA) ./files/runtime.conf $(1)/usr/lib/resilio-sync/runtime.conf
endef

$(eval $(call BuildPackage,resilio-sync))
