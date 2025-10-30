#
# Copyright (C) 2019 peter-tank@github.com
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=minisign
PKG_VERSION:=0.12.0
PKG_RELEASE:=1

# Используем git для получения исходников C/C++ версии minisign
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/jedisct1/minisign.git
# Используем конкретный коммит, соответствующий версии 0.12.0
PKG_SOURCE_VERSION:=ea5bcc7b8bfbee413d7956e05618e2181c411f0a
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION)
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.xz

# Убираем хеш, так как используется git-протокол

PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=peter-tank
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)/$(BUILD_VARIANT)/$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION)

CMAKE_INSTALL:=1
PKG_BUILD_PARALLEL:=1 # Увеличиваем до 1, так как 0 может быть слишком медленно
PKG_BUILD_DEPENDS:=libsodium

PKG_CONFIG_DEPENDS:= \
	CONFIG_$(PKG_NAME)_STATIC_LINK \
	CONFIG_$(PKG_NAME)_WITH_SODIUM

include $(INCLUDE_DIR)/package.mk

include $(INCLUDE_DIR)/cmake.mk

# Переносим CFLAGS и LDFLAGS в Build/Compile для чистоты
# TARGET_CXXFLAGS += -Wall -Wextra
# TARGET_CXXFLAGS += $(FPIC)
# TARGET_CXXFLAGS += -DED25519_NONDETERMINISTIC
# TARGET_CXXFLAGS := $(filter-out -O%,$(TARGET_CXXFLAGS)) -O3
# TARGET_CXXFLAGS += -ffunction-sections -fdata-sections
# TARGET_LDFLAGS += -Wl,--gc-sections

define Package/minisign
	SECTION:=utils
	CATEGORY:=Utilities
	TITLE:=A dead simple tool to sign files and verify signatures.
	URL:=https://github.com/jedisct1/minisign
	# Зависимости: libpthread и libsodium
	DEPENDS:=+libpthread +libsodium
endef

define Package/minisign/config
menu "minisign Compile Configuration"
	config $(PKG_NAME)_STATIC_LINK
		bool "enable static link libraries."
		default y

		menu "Select libraries"
			depends on $(PKG_NAME)_STATIC_LINK
			config $(PKG_NAME)_WITH_SODIUM
				bool "static link libsodium."
				default y

		endmenu
endmenu
endef

define Package/minisign/description
Minisign is a dead simple tool to sign files and verify signatures.
endef

CMAKE_OPTIONS += -DCMAKE_STRIP=$(TOOLCHAIN_DIR)/bin/$(TARGET_CROSS)strip

# Добавим патч, так как обычно для таких git-версий требуется патчинг
# define Build/Prepare
# 	$(call Build/Prepare/Default)
# 	(cd $(PKG_BUILD_DIR) && $(PATCHTOOL) apply $(PKG_NAME)*.patch)
# endef

# Переносим CXXFLAGS/LDFLAGS в Build/Compile для корректного порядка
define Build/Compile
	$(call Build/Compile/Default)
	$(MAKE_PATH) $(TARGET_CXX) $(TARGET_CXXFLAGS) $(TARGET_LDFLAGS)
endef

$(eval $(call BuildPackage,minisign))
