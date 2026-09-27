#!/bin/bash
# 根据 workflow 传入的环境变量拼接软件包列表
# 官方源内的包直接写名字; 第三方包由 build.sh 先放入 packages/ 目录

# ---- 基础 (每次都带) ----
PACKAGES="curl"
PACKAGES="$PACKAGES luci-theme-argon luci-app-argon-config luci-i18n-argon-config-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn luci-i18n-ttyd-zh-cn luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn luci-i18n-attendedsysupgrade-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
PACKAGES="$PACKAGES python3 python3-pip"

# ---- 可选插件 ----
if [ "$ENABLE_NIKKI" = "true" ]; then
  PACKAGES="$PACKAGES luci-i18n-nikki-zh-cn"
fi

if [ "$ENABLE_OPENCLASH" = "true" ]; then
  PACKAGES="$PACKAGES luci-app-openclash luci-compat kmod-tun kmod-inet-diag kmod-nft-tproxy bash ip-full unzip"
fi

if [ "$ENABLE_LUCKY" = "true" ]; then
  PACKAGES="$PACKAGES luci-app-lucky lucky luci-i18n-lucky-zh-cn"
fi

if [ "$ENABLE_PASSWALL" = "true" ]; then
  PACKAGES="$PACKAGES geoview xray-core sing-box hysteria luci-i18n-passwall-zh-cn"
fi

if [ "$ENABLE_PASSWALL2" = "true" ]; then
  PACKAGES="$PACKAGES geoview xray-core sing-box hysteria kmod-nft-socket kmod-nft-tproxy luci-app-passwall2 luci-i18n-passwall2-zh-cn"
fi

if [ "$ENABLE_QUICKFILE" = "true" ]; then
  PACKAGES="$PACKAGES bash quickfile luci-app-quickfile luci-i18n-quickfile-zh-cn"
fi

if [ "$ENABLE_STORE" = "true" ]; then
  PACKAGES="$PACKAGES luci-app-store"
fi

if [ "$ENABLE_DOCKER" = "true" ]; then
  PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
fi

# ---- 用户额外指定的包 ----
if [ -n "$EXTRA_PACKAGES" ]; then
  PACKAGES="$PACKAGES $EXTRA_PACKAGES"
fi
