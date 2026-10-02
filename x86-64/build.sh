#!/bin/bash
# 在 immortalwrt/imagebuilder 容器内执行, 工作目录为 ImageBuilder 根目录
set -e
cd /home/build/immortalwrt

source shell/packages.sh
echo "=============================="
echo "软件包列表: $PACKAGES"
echo "ROOTFS 大小: ${ROOTFS_SIZE}MB"
echo "=============================="

# 第三方插件 (nikki/lucky/passwall2/quickfile/应用商店): 从 apk 仓库取预编译好的 apk
THIRD_PARTY="false"
[ "$ENABLE_NIKKI" = "true" ] && THIRD_PARTY="true"
[ "$ENABLE_LUCKY" = "true" ] && THIRD_PARTY="true"
[ "$ENABLE_STORE" = "true" ] && THIRD_PARTY="true"
[ "$ENABLE_PASSWALL2" = "true" ] && THIRD_PARTY="true"
[ "$ENABLE_QUICKFILE" = "true" ] && THIRD_PARTY="true"
if [ "$THIRD_PARTY" = "true" ]; then
  echo "🔄 同步第三方插件仓库..."
  rm -rf /tmp/apk-repo
  git clone --depth=1 https://github.com/wukongdaily/apk.git /tmp/apk-repo
  mkdir -p extra-packages
  [ "$ENABLE_NIKKI" = "true" ] && cp -r /tmp/apk-repo/run/x86/nikki extra-packages/
  [ "$ENABLE_LUCKY" = "true" ] && cp -r /tmp/apk-repo/run/x86/lucky extra-packages/
  [ "$ENABLE_PASSWALL2" = "true" ] && cp -r /tmp/apk-repo/run/x86/passwall2 extra-packages/
  [ "$ENABLE_QUICKFILE" = "true" ] && cp -r /tmp/apk-repo/run/x86/quickfile extra-packages/
  if [ "$ENABLE_STORE" = "true" ]; then
    cp /tmp/apk-repo/run/x86/luci-app-store-*.run extra-packages/ 2>/dev/null || true
  fi
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

# AdGuard Home (去广告 DNS): LuCI 管理界面 + 官方二进制预置
if [ "$ENABLE_ADGUARDHOME" = "true" ]; then
  echo "🔄 准备 AdGuard Home..."
  mkdir -p /tmp/agh-dl files/usr/bin/AdGuardHome
  # LuCI 管理界面 (rufengsuixing/luci-app-adguardhome): 取最新版 ipk，解包 data.tar.gz 到 files/
  AGH_IPK_URL="$(wget -qO- https://api.github.com/repos/rufengsuixing/luci-app-adguardhome/releases/latest | grep -o 'https://[^"]*\.ipk' | head -1)"
  [ -z "$AGH_IPK_URL" ] && AGH_IPK_URL="https://github.com/rufengsuixing/luci-app-adguardhome/releases/download/1.8-9/luci-app-adguardhome_1.8-9_all.ipk"
  wget -q "$AGH_IPK_URL" -O /tmp/agh-dl/app.ipk.gz || { echo "❌ AdGuardHome LuCI 包下载失败"; exit 1; }
  gunzip -c /tmp/agh-dl/app.ipk.gz > /tmp/agh-dl/app.tar
  tar -xf /tmp/agh-dl/app.tar -C /tmp/agh-dl/ ./data.tar.gz
  # 注：files/ 属主是 runner（容器内 build 用户非属主），tar 直接解到 files/
  # 会因 utime/chmod 已存在目录而失败；先解到临时目录再 cp 进去
  # （用 --preserve=mode 只保留权限位：cp -p 会尝试保留时间戳，同样会失败）
  mkdir -p /tmp/agh-data
  tar -xzf /tmp/agh-dl/data.tar.gz -C /tmp/agh-data/
  cp -r --preserve=mode /tmp/agh-data/. files/
  rm -rf /tmp/agh-dl /tmp/agh-data
  # 官方二进制 (预置到 LuCI 默认 binpath，开箱即用，无需首次运行时下载)
  wget -qO- "https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_amd64.tar.gz" \
    | tar xOz ./AdGuardHome/AdGuardHome > files/usr/bin/AdGuardHome/AdGuardHome \
    || { echo "❌ AdGuardHome 二进制下载失败"; exit 1; }
  chmod +x files/usr/bin/AdGuardHome/AdGuardHome
  [ -s files/usr/bin/AdGuardHome/AdGuardHome ] || { echo "❌ AdGuardHome 二进制为空"; exit 1; }
  echo "✅ AdGuard Home 就绪"
fi

# 生成镜像自带软件包清单 files/usr/share/yyd-image-pkgs.list
# （供 fw-upgrade 区分"用户后装包"；放 /usr/share 而非 /etc，避免 sysupgrade 恢复旧配置时覆盖）
apk_name_from_file() {
    local base="${1##*/}"
    base="${base%.apk}"
    local name="" part
    local IFS='-'
    for part in $base; do
        case "$part" in
            [0-9]*) break ;;  # 版本号开始，后面都是版本
            *) name="${name:+$name-}$part" ;;
        esac
    done
    printf '%s\n' "$name"
}
mkdir -p files/usr/share
{
    for _p in $PACKAGES; do
        case "$_p" in
            -*) continue ;;  # 显式移除的包不计入
            *) printf '%s\n' "$_p" ;;
        esac
    done
    # 第三方 .apk（覆盖仅作为依赖装入、PACKAGES 里没写的包，如 nikki/luci-app-nikki）
    for _f in packages/*.apk; do
        [ -e "$_f" ] || continue
        apk_name_from_file "$_f"
    done
} | sort -u > files/usr/share/yyd-image-pkgs.list
echo "📦 镜像自带包清单: $(wc -l < files/usr/share/yyd-image-pkgs.list) 个"

echo "🔨 开始构建固件..."
make image PROFILE="generic" PACKAGES="$PACKAGES" FILES="files" ROOTFS_PARTSIZE=$ROOTFS_SIZE

echo "✅ 构建完成:"
ls -lh bin/targets/x86/64/*ext4-combined-efi.img.gz
