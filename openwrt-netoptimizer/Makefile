include $(TOPDIR)/rules.mk

PKG_NAME:=openwrt-netoptimizer
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=OpenWrt-NetOptimizer Maintainers
PKG_LICENSE:=GPL-3.0-only

include $(INCLUDE_DIR)/package.mk

define Package/openwrt-netoptimizer
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Integrated network monitoring and link optimization suite
  URL:=https://github.com/your-org/openwrt-netoptimizer
  PKGARCH:=all
  DEPENDS:= \
	+nlbwmon \
	+luci-app-nlbwmon \
	+dnsmasq-full \
	+v2ray-geoip \
	+v2ray-geosite \
	+pbr \
	+luci-app-pbr \
	+sqm-scripts \
	+luci-app-sqm \
	+kmod-sched-cake \
	+kmod-sched-bpf \
	+kmod-veth \
	+kmod-xdp-sockets-diag \
	+kmod-nft-tproxy \
	+dae \
	+daed \
	+luci-app-daede
endef

define Package/openwrt-netoptimizer/description
	Meta package integrating traffic accounting (nlbwmon), policy routing
	(pbr), adaptive bandwidth management (SQM/CAKE) and eBPF transparent
	proxy (dae/daed) into a single installable suite.
	Requires a kernel with CONFIG_DEBUG_INFO_BTF enabled, otherwise
	dae/daed will fail to start.
endef

define Package/openwrt-netoptimizer/conffiles
/etc/config/netoptimizer
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/openwrt-netoptimizer/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/netoptimizer $(1)/etc/config/netoptimizer
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-netoptimizer $(1)/etc/uci-defaults/99-netoptimizer
endef

$(eval $(call BuildPackage,openwrt-netoptimizer))
