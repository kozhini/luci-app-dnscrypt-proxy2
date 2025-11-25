#
# Copyright (C) 2025 luci-app-dnscrypt-proxy2
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-dnscrypt-proxy2
PKG_VERSION:=0.2.2.1
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
	TITLE:=DNSCrypt Proxy v2 LuCI interface
	URL:=https://github.com/kozhini/luci-app-dnscrypt-proxy2
	PKGARCH:=all
	DEPENDS:=+dnscrypt-proxy2 +luci-base +luci-lib-jsonc
endef

define Package/$(PKG_NAME)/description
	Modern LuCI interface for dnscrypt-proxy2.
	Supports DNSCrypt, DoH, ODoH protocols with direct TOML editing.
	Features: resolver management, anonymization, filtering, and statistics.
endef

define Build/Compile
	# No compilation needed for LuCI package
endef

define Package/$(PKG_NAME)/conffiles
/etc/dnscrypt-proxy2/dnscrypt-proxy.toml
/etc/dnscrypt-proxy2/allowed-names.txt
/etc/dnscrypt-proxy2/blocked-names.txt
/etc/dnscrypt-proxy2/blocked-ips.txt
/etc/dnscrypt-proxy2/cloaking-rules.txt
/etc/dnscrypt-proxy2/forwarding-rules.txt
endef

define Package/$(PKG_NAME)/install
	# LuCI controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/luci/controller/dnscrypt-proxy.lua $(1)/usr/lib/lua/luci/controller/
	
	# LuCI models
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/dnscrypt-proxy
	$(INSTALL_DATA) ./files/luci/model/cbi/dnscrypt-proxy/*.lua $(1)/usr/lib/lua/luci/model/cbi/dnscrypt-proxy/
	
	# Helper scripts
	$(INSTALL_DIR) $(1)/usr/libexec/dnscrypt-proxy
	$(INSTALL_BIN) ./files/dnscrypt-helper.sh $(1)/usr/libexec/dnscrypt-proxy/helper
	
	# RPCD ACL
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/luci-app-dnscrypt-proxy2.json $(1)/usr/share/rpcd/acl.d/
	
	# Default configs (only if not exist)
	$(INSTALL_DIR) $(1)/etc/dnscrypt-proxy2
	$(INSTALL_DATA) ./files/dnscrypt-proxy.toml $(1)/etc/dnscrypt-proxy2/dnscrypt-proxy.toml.example
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -z "$${IPKG_INSTROOT}" ] || exit 0

# Copy example config if not exists
if [ ! -f /etc/dnscrypt-proxy2/dnscrypt-proxy.toml ]; then
	cp /etc/dnscrypt-proxy2/dnscrypt-proxy.toml.example /etc/dnscrypt-proxy2/dnscrypt-proxy.toml
fi

# Create empty filter files if not exist
touch /etc/dnscrypt-proxy2/allowed-names.txt
touch /etc/dnscrypt-proxy2/blocked-names.txt
touch /etc/dnscrypt-proxy2/blocked-ips.txt
touch /etc/dnscrypt-proxy2/cloaking-rules.txt
touch /etc/dnscrypt-proxy2/forwarding-rules.txt

# Reload LuCI
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/*

exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -z "$${IPKG_INSTROOT}" ] || exit 0

echo "Stopping dnscrypt-proxy2 service..."
/etc/init.d/dnscrypt-proxy2 stop 2>/dev/null || true

exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
