include $(TOPDIR)/rules.mk

PKG_NAME:=minisign
PKG_VERSION:=0.12
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/jedisct1/minisign/archive/refs/tags/
PKG_HASH:=skip

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_LICENSE:=ISC
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=kozhini

PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/minisign
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Simple tool to sign and verify files
  URL:=https://github.com/jedisct1/minisign
  DEPENDS:=+libsodium +libpthread
endef

define Package/minisign/description
  Minisign is a simple and fast tool to sign and verify files.
  It uses the secure Ed25519 signature system and libsodium.
endef

CMAKE_OPTIONS += \
	-DCMAKE_BUILD_TYPE=MinSizeRel

TARGET_CFLAGS += -ffunction-sections -fdata-sections

define Package/minisign/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/minisign $(1)/usr/bin/
endef

$(eval $(call BuildPackage,minisign))
