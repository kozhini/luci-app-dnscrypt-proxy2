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

include $(INCLUDE_DIR)/package.mk

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

TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include
TARGET_LDFLAGS += -L$(STAGING_DIR)/usr/lib -lsodium -lpthread

define Build/Compile
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_CPPFLAGS) \
		-o $(PKG_BUILD_DIR)/minisign \
		$(PKG_BUILD_DIR)/src/*.c \
		$(TARGET_LDFLAGS)
endef

define Package/minisign/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/minisign $(1)/usr/bin/
endef

$(eval $(call BuildPackage,minisign))
