include $(TOPDIR)/rules.mk

PKG_NAME:=minisign
PKG_VERSION:=0.12.0
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/jedisct1/minisign.git
PKG_SOURCE_VERSION:=ea5bcc7b8bfbee413d7956e05618e2181c411f0a
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.xz

PKG_LICENSE:=ISC
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=kozhini

# Правильная структура для CMake
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/minisign
	SECTION:=utils
	CATEGORY:=Utilities
	TITLE:=Simple tool to sign files and verify signatures
	URL:=https://github.com/jedisct1/minisign
	DEPENDS:=+libsodium +libpthread
endef

define Package/minisign/description
	Minisign is a dead simple tool to sign files and verify signatures.
	It is portable, lightweight, and uses the highly secure Ed25519 public-key signature system.
endef

# CMake опции
CMAKE_OPTIONS += \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_SHARED_LIBS=OFF

# Для статической линковки с libsodium
ifeq ($(CONFIG_MINISIGN_STATIC_LINK),y)
CMAKE_OPTIONS += -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++"
TARGET_LDFLAGS += -Wl,-Bstatic -lsodium -Wl,-Bdynamic -lpthread
endif

define Package/minisign/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/minisign $(1)/usr/bin/
endef

$(eval $(call BuildPackage,minisign))
