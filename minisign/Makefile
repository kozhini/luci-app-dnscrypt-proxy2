# Файл: minisign/Makefile

include $(TOPDIR)/rules.mk

PKG_NAME:=minisign
PKG_VERSION:=0.12
PKG_RELEASE:=1

# 🔥 ГЛАВНОЕ ИСПРАВЛЕНИЕ: Используем прямую ссылку на релиз
PKG_SOURCE:=minisign-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/jedisct1/minisign/releases/download/$(PKG_VERSION)

# Хеш для minisign-0.12.tar.gz (подтвержден)
PKG_HASH:=141d8b13936997d51786576d1a6579c8846c48386a512d7c0f1882672a088514

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

define Build/Compile
	$(MAKE_PATH) \
		cargo build --release --target=$(TARGET_ARCH)
endef

define Package/minisign/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/target/release/minisign $(1)/usr/bin/
endef

$(eval $(call BuildPackage,minisign))
