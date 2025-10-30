#
# Copyright (C) 2019 OpenWrt-DNSCrypt-Proxy
# Copyright (C) 2019 peter-tank
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-dnscrypt-proxy2
PKG_VERSION:=2.1.4
PKG_RELEASE:=1

PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=kozhini

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=DNSCrypt Proxy LuCI interface
	URL:=https://github.com/kozhini/luci-app-dnscrypt-proxy2
	PKGARCH:=all
	# Зависимости: dnscrypt-proxy2 из feeds, minisign из локальной сборки
	DEPENDS:=+dnscrypt-proxy2 +luci-compat +luci-lib-ip +luci-lua-runtime +minisign
endef

define Package/$(PKG_NAME)/description
	LuCI Support for dnscrypt-proxy2.
	Provides web interface for configuring DNSCrypt Proxy with resolver management,
	DNSSEC validation, domain/IP blocking, and automatic resolver list updates.
endef

define Build/Compile
	# LuCI-пакет не требует компиляции
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/dnscrypt-proxy
/etc/config/public-resolvers
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/luci/controller/dnscrypt-proxy.lua $(1)/usr/lib/lua/luci/controller/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/tools
	$(INSTALL_DATA) ./files/luci/tools/*.lua $(1)/usr/lib/lua/luci/tools/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/dnscrypt-proxy
	$(INSTALL_DATA) ./files/luci/model/cbi/dnscrypt-proxy/*.lua $(1)/usr/lib/lua/luci/model/cbi/dnscrypt-proxy/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/dnscrypt-proxy
	$(INSTALL_DATA) ./files/luci/view/dnscrypt-proxy/*.htm $(1)/usr/lib/lua/luci/view/dnscrypt-proxy/
	
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/root/etc/uci-defaults/dnscrypt-proxy $(1)/etc/uci-defaults/
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/dnscrypt-proxy_resolvers.init $(1)/etc/init.d/dnscrypt-proxy_resolvers
	$(INSTALL_BIN) ./files/dnscrypt-proxy.init $(1)/etc/init.d/dnscrypt-proxy
	
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/dnscrypt-proxy.config $(1)/etc/config/dnscrypt-proxy
	$(INSTALL_DATA) ./files/public-resolvers.config $(1)/etc/config/public-resolvers
	
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/luci-app-dnscrypt-proxy2.json $(1)/usr/share/rpcd/acl.d/
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -z "$${IPKG_INSTROOT}" ] || exit 0

# Выполняем uci-defaults скрипт
if [ -f /etc/uci-defaults/dnscrypt-proxy ]; then
	( . /etc/uci-defaults/dnscrypt-proxy ) && rm -f /etc/uci-defaults/dnscrypt-proxy
fi

# Настройка firewall правил
uci -q batch <<-EOF >/dev/null
	delete firewall.dnscrypt_proxy
	set firewall.dnscrypt_proxy=include
	set firewall.dnscrypt_proxy.type=script
	set firewall.dnscrypt_proxy.path=/var/etc/dnscrypt-proxy.include
	set firewall.dnscrypt_proxy.reload=0
	commit firewall
EOF

exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -z "$${IPKG_INSTROOT}" ] || exit 0

echo "Stopping dnscrypt-proxy service..."
/etc/init.d/dnscrypt-proxy stop 2>/dev/null || true
/etc/init.d/dnscrypt-proxy disable 2>/dev/null || true

echo "Removing firewall rule for dnscrypt-proxy..."
uci -q batch <<-EOF >/dev/null
	delete firewall.dnscrypt_proxy
	commit firewall
EOF

exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
