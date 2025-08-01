#
# Copyright (C) 2002-2003 Erik Andersen <andersen@uclibc.org>
# Copyright (C) 2004 Manuel Novoa III <mjn3@uclibc.org>
# Copyright (C) 2005-2006 Felix Fietkau <nbd@nbd.name>
# Copyright (C) 2006-2014 OpenWrt.org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

include $(TOPDIR)/rules.mk

PKG_NAME:=gcc
GCC_VERSION:=$(call qstrip,$(CONFIG_GCC_VERSION))
PKG_VERSION:=$(firstword $(subst +, ,$(GCC_VERSION)))
GCC_MAJOR_VERSION:=$(word 1,$(subst ., ,$(PKG_VERSION)))
GCC_DIR:=$(PKG_NAME)-$(PKG_VERSION)

PKG_SOURCE_URL:=@GNU/gcc/gcc-$(PKG_VERSION)
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.xz
PKG_CPE_ID:=cpe:/a:gnu:gcc

ifeq ($(PKG_VERSION),11.3.0)
  PKG_HASH:=b47cf2818691f5b1e21df2bb38c795fac2cfbd640ede2d0a5e1c89e338a3ac39
endif

ifeq ($(PKG_VERSION),12.3.0)
  PKG_HASH:=949a5d4f99e786421a93b532b22ffab5578de7321369975b91aec97adfda8c3b
endif

ifeq ($(PKG_VERSION),13.3.0)
  PKG_HASH:=0845e9621c9543a13f484e94584a49ffc0129970e9914624235fc1d061a0c083
endif

ifeq ($(PKG_VERSION),14.3.0)
  PKG_HASH:=e0dc77297625631ac8e50fa92fffefe899a4eb702592da5c32ef04e2293aca3a
endif

ifeq ($(PKG_VERSION),15.1.0)
  PKG_HASH:=e2b09ec21660f01fecffb715e0120265216943f038d0e48a9868713e54f06cea
endif

PATCH_DIR=../patches-$(GCC_MAJOR_VERSION).x

BUGURL=http://bugs.openwrt.org/
PKGVERSION=OpenWrt GCC $(PKG_VERSION) $(REVISION)

HOST_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/toolchain-build.mk

HOST_SOURCE_DIR:=$(HOST_BUILD_DIR)
ifeq ($(GCC_VARIANT),minimal)
  GCC_BUILD_DIR:=$(HOST_BUILD_DIR)-$(GCC_VARIANT)
else
  HOST_BUILD_DIR:=$(HOST_BUILD_DIR)-$(GCC_VARIANT)
  GCC_BUILD_DIR:=$(HOST_BUILD_DIR)
endif

HOST_STAMP_PREPARED:=$(HOST_BUILD_DIR)/.prepared
HOST_STAMP_BUILT:=$(GCC_BUILD_DIR)/.built
HOST_STAMP_CONFIGURED:=$(GCC_BUILD_DIR)/.configured
HOST_STAMP_INSTALLED:=$(HOST_BUILD_PREFIX)/stamp/.gcc_$(GCC_VARIANT)_installed

SEP:=,
TARGET_LANGUAGES:="c,c++$(if $(CONFIG_INSTALL_GFORTRAN),$(SEP)fortran)$(if $(CONFIG_INSTALL_GCCGO),$(SEP)go)"

TAR_OPTIONS += \
	--exclude-from='$(CURDIR)/../exclude-testsuite' --exclude=gcc/ada/*.ad* \
	--exclude=libjava

# this needs to be without -L/-lzstd flags or other parts fail to build
# use an absolute path to ensure it really picks up our version
export ac_cv_search_ZSTD_compress=$(STAGING_DIR_HOST)/lib/libzstd.a -pthread
export libgcc_cv_fixed_point=no
ifdef CONFIG_INSTALL_GCCGO
  export libgo_cv_c_split_stack_supported=no
endif

ifdef CONFIG_GCC_USE_GRAPHITE
  GRAPHITE_CONFIGURE:= --with-isl=$(STAGING_DIR_HOST)
else
  GRAPHITE_CONFIGURE:= --without-isl --without-cloog
endif

GCC_CONFIGURE:= \
	SHELL="$(BASH)" \
	$(HOST_SOURCE_DIR)/configure \
		--with-bugurl=$(BUGURL) \
		--with-pkgversion="$(PKGVERSION)" \
		--prefix=$(TOOLCHAIN_DIR) \
		--build=$(GNU_HOST_NAME) \
		--host=$(GNU_HOST_NAME) \
		--target=$(REAL_GNU_TARGET_NAME) \
		--with-gnu-ld \
		--enable-target-optspace \
		--disable-libgomp \
		--disable-libmudflap \
		--disable-multilib \
		--disable-libmpx \
		--disable-nls \
		--disable-libssp \
		$(GRAPHITE_CONFIGURE) \
		--with-host-libstdcxx=-lstdc++ \
		$(SOFT_FLOAT_CONFIG_OPTION) \
		$(call qstrip,$(CONFIG_EXTRA_GCC_CONFIG_OPTIONS)) \
		$(if $(CONFIG_mips64)$(CONFIG_mips64el),--with-arch=mips64 \
			--with-abi=$(call qstrip,$(CONFIG_MIPS64_ABI))) \
		$(if $(CONFIG_arc),--with-cpu=$(CONFIG_CPU_TYPE)) \
		$(if $(CONFIG_powerpc64), $(if $(CONFIG_USE_MUSL),--with-abi=elfv2)) \
		--with-system-zlib=$(STAGING_DIR_HOST) \
		--with-zstd=$(STAGING_DIR_HOST) \
		--with-gmp=$(STAGING_DIR_HOST) \
		--with-mpfr=$(STAGING_DIR_HOST) \
		--with-mpc=$(STAGING_DIR_HOST) \
		--disable-decimal-float \
		--with-diagnostics-color=auto-if-env \
		--enable-__cxa_atexit \
		--enable-libstdcxx-dual-abi \
		--with-default-libstdcxx-abi=new
ifneq ($(CONFIG_mips)$(CONFIG_mipsel),)
  GCC_CONFIGURE += --with-mips-plt
endif

ifneq ($(CONFIG_GCC_DEFAULT_PIE),)
  GCC_CONFIGURE+= \
		--enable-default-pie
endif

ifneq ($(CONFIG_GCC_DEFAULT_SSP),)
  GCC_CONFIGURE+= \
		--enable-default-ssp
endif

ifneq ($(CONFIG_EXTRA_TARGET_ARCH),)
  GCC_CONFIGURE+= \
		--enable-biarch \
		--enable-targets=$(call qstrip,$(CONFIG_EXTRA_TARGET_ARCH_NAME))-linux-$(TARGET_SUFFIX)
endif

ifdef CONFIG_sparc
  GCC_CONFIGURE+= \
		--enable-targets=all \
		--with-long-double-128
endif

ifneq ($(GCC_ARCH),)
  GCC_CONFIGURE+= --with-arch=$(GCC_ARCH)
endif

ifeq ($(CONFIG_arm),y)
  GCC_CONFIGURE+= \
	--with-cpu=$(word 1, $(subst +," ,$(CONFIG_CPU_TYPE)))

  ifneq ($(CONFIG_SOFT_FLOAT),y)
    GCC_CONFIGURE+= \
		--with-fpu=$(word 2, $(subst +, ",$(CONFIG_CPU_TYPE))) \
		--with-float=hard
  endif

  # Do not let TARGET_CFLAGS get poisoned by extra CPU optimization flags
  # that do not belong here. The cpu,fpu type should be specified via
  # --with-cpu and --with-fpu for ARM and not CFLAGS.
  TARGET_CFLAGS:=$(filter-out -m%,$(call qstrip,$(TARGET_CFLAGS)))
endif

ifeq ($(CONFIG_TARGET_x86)$(CONFIG_USE_GLIBC)$(CONFIG_INSTALL_GCCGO),yyy)
  TARGET_CFLAGS+=-fno-split-stack
endif

CFLAGS:=$(HOST_CFLAGS) -pipe
ifneq ($(shell gcc --version 2>&1 | grep -E "Apple.(LLVM|clang)"),)
  CFLAGS+= -fbracket-depth=512
endif

GCC_CONFIGURE+= \
	CFLAGS="$(CFLAGS)" \
	CXXFLAGS="$(CFLAGS)" \
	CFLAGS_FOR_TARGET="$(TARGET_CFLAGS)" \
	CXXFLAGS_FOR_TARGET="$(TARGET_CFLAGS)" \
	GOCFLAGS_FOR_TARGET="$(TARGET_CFLAGS)"

GCC_MAKE:= \
	export SHELL="$(BASH)"; \
	$(MAKE)

define Host/SetToolchainInfo
	$(SED) 's,TARGET_CROSS=.*,TARGET_CROSS=$(REAL_GNU_TARGET_NAME)-,' $(TOOLCHAIN_DIR)/info.mk
	$(SED) 's,GCC_VERSION=.*,GCC_VERSION=$(GCC_VERSION),' $(TOOLCHAIN_DIR)/info.mk
endef


ifeq ($(GCC_MAJOR_VERSION),11)
	GCC_VERSION_FILE:=gcc/version.c
else
	GCC_VERSION_FILE:=gcc/genversion.cc
endif

ifneq ($(GCC_PREPARE),)
  define Host/Prepare
	$(call Host/SetToolchainInfo)
	$(call Host/Prepare/Default)
	ln -snf $(GCC_DIR) $(BUILD_DIR_TOOLCHAIN)/$(PKG_NAME)
	$(CP) $(SCRIPT_DIR)/config.{guess,sub} $(HOST_SOURCE_DIR)/
	$(SED) 's,^MULTILIB_OSDIRNAMES,# MULTILIB_OSDIRNAMES,' $(HOST_SOURCE_DIR)/gcc/config/*/t-*
	$(SED) 'd' $(HOST_SOURCE_DIR)/gcc/DEV-PHASE
	$(SED) 's, DATESTAMP,,' $(HOST_SOURCE_DIR)/$(GCC_VERSION_FILE)
	$(SED) 's,gcc_no_link=yes,gcc_no_link=no,' $(HOST_SOURCE_DIR)/libstdc++-v3/configure
	mkdir -p $(GCC_BUILD_DIR)
  endef
else
  define Host/Prepare
	mkdir -p $(GCC_BUILD_DIR)
  endef
endif

define Host/Configure
	(cd $(GCC_BUILD_DIR) && rm -f config.cache; \
		$(GCC_CONFIGURE) \
	);
endef

define Host/Clean
	rm -rf $(if $(GCC_PREPARE),$(HOST_SOURCE_DIR)) \
		$(HOST_BUILD_PREFIX)/stamp/.gcc_* \
		$(HOST_BUILD_PREFIX)/stamp/.binutils_* \
		$(GCC_BUILD_DIR) \
		$(BUILD_DIR_TOOLCHAIN)/$(PKG_NAME) \
		$(TOOLCHAIN_DIR)/$(REAL_GNU_TARGET_NAME) \
		$(TOOLCHAIN_DIR)/bin/$(REAL_GNU_TARGET_NAME)-gc* \
		$(TOOLCHAIN_DIR)/bin/$(REAL_GNU_TARGET_NAME)-c*
endef
