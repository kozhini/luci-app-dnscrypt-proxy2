include $(TOPDIR)/rules.mk

PKG_NAME:=minisign
PKG_VERSION:=0.12
PKG_RELEASE:=1

PKG_SOURCE:=minisign-linux-$(PKG_VERSION)-$(ARCH).tar.gz
PKG_SOURCE_URL:=https://github.com/jedisct1/minisign/releases/download/$(PKG_VERSION)

PKG_MAINTAINER:=kozhini
PKG_LICENSE:=ISC

include $(INCLUDE_DIR)/package.mk

define Package/minisign
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=A simple tool to sign files and verify signatures
  URL:=https://github.com/jedisct1/minisign
  DEPENDS:=+libsodium
  PKGARCH:=all
endef

define Build/Compile
	# Нет компиляции - используем предкомпилированный бинарник
endef

define Package/minisign/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/minisign $(1)/usr/bin/
endef

$(eval $(call BuildPackage,minisign))
