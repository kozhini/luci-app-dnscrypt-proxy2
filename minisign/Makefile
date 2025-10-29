include $(TOPDIR)/rules.mk

PKG_NAME:=minisign
PKG_VERSION:=0.12
PKG_RELEASE:=1

PKG_SOURCE:=minisign-$(PKG_VERSION)-linux.tar.gz
PKG_SOURCE_URL:=https://github.com/jedisct1/minisign/releases/download/$(PKG_VERSION)/
PKG_HASH:=skip

PKG_MAINTAINER:=kozhini
PKG_LICENSE:=ISC
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/minisign
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=A simple tool to sign files and verify signatures
  URL:=https://github.com/jedisct1/minisign
  DEPENDS:=
endef

define Package/minisign/description
  Minisign is a dead simple tool to sign files and verify signatures.
  It is portable, lightweight, and uses the highly secure Ed25519 
  public-key signature system.
  
  Note: This package uses a precompiled x86_64 binary which may not 
  work on all architectures. For non-x86_64 systems, compilation from 
  source is required.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1 2>/dev/null || \
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) 2>/dev/null || \
	true
	# Если архив содержит бинарник напрямую
	if [ ! -f "$(PKG_BUILD_DIR)/minisign" ] && [ -f "$(DL_DIR)/$(PKG_SOURCE)" ]; then \
		cd $(PKG_BUILD_DIR) && tar -xzf $(DL_DIR)/$(PKG_SOURCE); \
	fi
endef

define Build/Configure
	# Нет конфигурации для предкомпилированного бинарника
endef

define Build/Compile
	# Нет компиляции для предкомпилированного бинарника
endef

define Package/minisign/install
	$(INSTALL_DIR) $(1)/usr/bin
	# Пробуем найти бинарник в разных местах
	if [ -f "$(PKG_BUILD_DIR)/minisign" ]; then \
		$(INSTALL_BIN) $(PKG_BUILD_DIR)/minisign $(1)/usr/bin/; \
	elif [ -f "$(PKG_BUILD_DIR)/x86_64-linux/minisign" ]; then \
		$(INSTALL_BIN) $(PKG_BUILD_DIR)/x86_64-linux/minisign $(1)/usr/bin/; \
	else \
		echo "ERROR: minisign binary not found!"; \
		find $(PKG_BUILD_DIR) -name "minisign" -o -name "minisign*"; \
		exit 1; \
	fi
	chmod +x $(1)/usr/bin/minisign
endef

define Package/minisign/postinst
#!/bin/sh
# Проверяем, работает ли бинарник на целевой системе
if [ -z "$${IPKG_INSTROOT}" ]; then
	if ! /usr/bin/minisign -v >/dev/null 2>&1; then
		echo "WARNING: minisign binary may not be compatible with your architecture"
		echo "Architecture compatibility issue detected. Please compile from source."
	fi
fi
exit 0
endef

$(eval $(call BuildPackage,minisign))
