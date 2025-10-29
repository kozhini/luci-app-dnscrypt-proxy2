include $(TOPDIR)/rules.mk

PKG_NAME:=minisign
PKG_VERSION:=0.12
PKG_RELEASE:=1

PKG_SOURCE:=minisign-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/jedisct1/minisign/releases/download/$(PKG_VERSION)
PKG_HASH:=141d8b13936997d51786576d1a6579c8846c48386a512d7c0f1882672a088514

PKG_MAINTAINER:=kozhini
PKG_LICENSE:=ISC
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=rust/host
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk

define Package/minisign
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=A simple tool to sign files and verify signatures
  URL:=https://github.com/jedisct1/minisign
  DEPENDS:=+libsodium
endef

define Package/minisign/description
  Minisign is a dead simple tool to sign files and verify signatures.
  It is portable, lightweight, and uses the highly secure Ed25519 public-key signature system.
endef

# Настройка окружения для Cargo
define Build/Compile
	cd $(PKG_BUILD_DIR) && \
	CARGO_HOME=$(STAGING_DIR_HOST)/cargo \
	$(CARGO_VARS) \
	cargo build \
		--release \
		--target=$(RUSTC_TARGET_ARCH) \
		--manifest-path=Cargo.toml
endef

define Package/minisign/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/target/$(RUSTC_TARGET_ARCH)/release/minisign $(1)/usr/bin/
endef

$(eval $(call BuildPackage,minisign))
