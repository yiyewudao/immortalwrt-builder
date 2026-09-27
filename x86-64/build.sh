#!/bin/bash
# 在 immortalwrt/imagebuilder 容器内执行, 工作目录为 ImageBuilder 根目录
set -e
cd /home/build/immortalwrt

source shell/packages.sh
echo "=============================="
echo "软件包列表: $PACKAGES"
echo "ROOTFS 大小: ${ROOTFS_SIZE}MB"
echo "=============================="

# 第三方插件 (应用商店 / Lucky): 从 apk 仓库取预编译好的 apk
if [ "$ENABLE_STORE" = "true" ] || [ "$ENABLE_LUCKY" = "true" ]; then
  echo "🔄 同步第三方插件仓库..."
  rm -rf /tmp/apk-repo
  git clone --depth=1 https://github.com/wukongdaily/apk.git /tmp/apk-repo
  mkdir -p extra-packages
  cp -r /tmp/apk-repo/run/x86/* extra-packages/ 2>/dev/null || true
  sh shell/apk-prepare-packages.sh
  ls packages/ | head -20
fi

# OpenClash 内核与规则数据 (ImageBuilder 不自带, 构建时下载打包进去)
if [ "$ENABLE_OPENCLASH" = "true" ]; then
  echo "🔄 下载 OpenClash 内核..."
  mkdir -p files/etc/openclash/core
  wget -qO- https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64-v1.tar.gz \
    | tar xOvz > files/etc/openclash/core/clash_meta
  chmod +x files/etc/openclash/core/clash_meta
  wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat \
    -O files/etc/openclash/GeoIP.dat
  wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat \
    -O files/etc/openclash/GeoSite.dat
  echo "✅ OpenClash 内核就绪"
fi

echo "🔨 开始构建固件..."
make image PROFILE="generic" PACKAGES="$PACKAGES" FILES="files" ROOTFS_PARTSIZE=$ROOTFS_SIZE

echo "✅ 构建完成:"
ls -lh bin/targets/x86/64/*squashfs-combined-efi.img.gz
