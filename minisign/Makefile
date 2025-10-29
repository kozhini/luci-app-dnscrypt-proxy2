# Этот файл должен находиться в папке 'minisign/' в корне вашего репозитория.

include $(TOPDIR)/rules.mk

PKG_NAME:=minisign
PKG_VERSION:=0.10
PKG_RELEASE:=1
PKG_SOURCE:=minisign-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/jedisct1/minisign/archive/$(PKG_VERSION).tar.gz
# PKG_HASH для версии 0.10
PKG_HASH:=e47307996f014e7a0033d5512b23616616e1e69a37e54efd0c73335048180d5b

PKG_MAINTAINER:=kozhini
PKG_LICENSE:=ISC
PKG_LICENSE_FILES:=LICENSE
PKG_BUILD_PARALLEL:=1

# Minisign написан на Rust. Зависимости для сборки.
PKG_BUILD_DEPENDS:=+rust
PKG_BUILD_DEPENDS+=+cargo

include $(INCLUDE_DIR)/package.mk

# Minisign зависит от библиотеки libsodium.
define Package/minisign
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=A simple tool to sign files and verify signatures
  URL:=https://github.com/jedisct1/minisign
  DEPENDS:=+libsodium
endef

# Сборка Minisign с помощью cargo
define Build/Compile
	$(MAKE_PATH) \
		cargo build --release --target=$(TARGET_ARCH)
endef

# Установка: копируем исполняемый файл в /usr/bin.
define Package/minisign/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/target/release/minisign $(1)/usr/bin/
endef

$(eval $(call BuildPackage,minisign))
