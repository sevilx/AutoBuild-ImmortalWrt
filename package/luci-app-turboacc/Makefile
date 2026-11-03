# SPDX-License-Identifier: MIT
# ============================================================================
#  luci-app-turboacc —— 轻量版 Turbo ACC
#  一个页面搞定：BBR 拥塞控制 / 软件流量分载 / 硬件流量分载(HW NAT) / FullCone NAT
#  不需要第三方 feed，全部逻辑内置，仅依赖 ImmortalWrt 已有的 kmod 与 firewall4
# ============================================================================
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-turboacc
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=Ben <sevilxiong@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-turboacc
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Turbo ACC (BBR / Flow Offloading / FullCone NAT)
  URL:=https://github.com/sevilx/AutoBuild-ImmortalWrt
  DEPENDS:=+luci-base +firewall4 +kmod-tcp-bbr +kmod-nft-fullcone
  PKGARCH:=all
endef

define Package/luci-app-turboacc/description
 Lightweight Turbo ACC for ImmortalWrt.

 One LuCI page to toggle:
   - BBR congestion control (fq + bbr)
   - software flow offloading (netfilter flowtable)
   - hardware flow offloading (HW NAT)
   - FullCone NAT (nft-fullcone expression, needs kmod-nft-fullcone)

 It only writes the standard fw4 options (flow_offloading,
 flow_offloading_hw, fullcone) and a sysctl drop-in, so it plays nice
 with upstream ImmortalWrt and survives sysupgrade.
endef

define Package/luci-app-turboacc/conffiles
/etc/config/turboacc
endef

# No source, nothing to compile. Without this the default Build/Compile
# runs make inside an empty PKG_BUILD_DIR and fails.
define Build/Compile
endef

define Package/luci-app-turboacc/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/turboacc $(1)/etc/config/turboacc

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/turboacc $(1)/etc/init.d/turboacc

	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./root/usr/sbin/turboacc-apply $(1)/usr/sbin/turboacc-apply

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-turboacc.json $(1)/usr/share/luci/menu.d/luci-app-turboacc.json

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-turboacc.json $(1)/usr/share/rpcd/acl.d/luci-app-turboacc.json

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/turboacc
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/turboacc/overview.js $(1)/www/luci-static/resources/view/turboacc/overview.js
endef

define Package/luci-app-turboacc/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/turboacc enable
	/etc/init.d/turboacc start >/dev/null 2>&1
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-turboacc))
