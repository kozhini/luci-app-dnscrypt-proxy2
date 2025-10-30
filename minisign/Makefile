#
# Copyright (C) 2019 peter-tank@github.com
#
# This is free software, licensed under the ISC License.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=minisign
PKG_VERSION:=0.12
PKG_RELEASE:=1

# Самый простой и надежный способ - скачать tarball по тегу
PKG_SOURCE:=$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/jedisct1/minisign/archive/refs/tags/
PKG_HASH:=skip

PKG_LICENSE:=ISC
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=kozhini

# OpenWrt автоматически распакует в minisign-0.12/
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
	It is portable, lightweight, and uses the highly secure Ed25519 
	public-key signature system. Minisign is a simpler alternative to GPG.
endef

# CMake опции для правильной сборки
CMAKE_OPTIONS += \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_SHARED_LIBS=OFF \
	-DCMAKE_INSTALL_PREFIX=/usr

# Опции для оптимизации размера
TARGET_CFLAGS += -ffunction-sections -fdata-sections
TARGET_LDFLAGS += -Wl,--gc-sections

define Package/minisign/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/minisign $(1)/usr/bin/
endef

$(eval $(call BuildPackage,minisign))
