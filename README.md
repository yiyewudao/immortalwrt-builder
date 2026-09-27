# ImmortalWrt 自动构建 (x86-64)

点几下鼠标, 自动从 ImmortalWrt 官方拉取 ImageBuilder, 组装出带常用插件的 x86-64 软路由固件。

## 怎么用

1. 打开仓库的 **Actions** → **构建 ImmortalWrt x86-64 固件** → **Run workflow**
2. 按需选择:
   - ImmortalWrt 版本 (25.12.x)
   - 固件大小 1G / 2G / 3G / 4G (Docker 需要留空间, 建议 2G 起)
   - 默认后台 IP (默认 192.168.50.2)
   - 插件开关: Nikki / OpenClash / Lucky / 应用商店 / Docker
   - 额外软件包 (可选, 空格分隔)
3. 等待约 10~30 分钟, 到 **Releases** 下载 `*-squashfs-combined-efi.img.gz`
4. 写盘启动 (支持 UEFI), 后台 `http://你设置的IP`, 用户名 root, 首次无密码

## ⬆️ 一键升级

已刷本固件的机器, 以后升级不用重装:

LuCI → **系统 → 备份/升级** → 上传新构建的固件 → 勾选 **"保留配置"** → 升级

配置、插件设置都在, 重启即用。

## 预装内容

- Argon 主题 (中文)、TTYD 终端、磁盘管理、软件包管理(中文)
- Nikki (Mihomo 透明代理, 中文界面)
- OpenClash (构建时自动打入最新 Meta 内核 + GeoIP/GeoSite)
- Lucky (动态域名 / 反向代理, 中文界面)
- 应用商店 luci-app-store
- Docker (dockerman 中文界面)
- 首次开机自动设置后台 IP、时区 Asia/Shanghai

## 致谢

构建思路与第三方 apk 仓库借鉴自 [wukongdaily/ImmortalWrt-ImageBuilder](https://github.com/wukongdaily/ImmortalWrt-ImageBuilder)。
