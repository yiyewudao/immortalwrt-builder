# ImmortalWrt 自动构建 (x86-64)

点几下鼠标, 自动从 ImmortalWrt 官方拉取 ImageBuilder, 组装出带常用插件的 x86-64 软路由固件。

## 怎么用

1. 打开仓库的 **Actions** → **构建 ImmortalWrt x86-64 固件** → **Run workflow**
2. 按需选择:
   - ImmortalWrt 版本 (默认 latest = 自动用官方最新版, 也可指定如 25.12.2 / 25.12.1 / 25.12.0)
   - 固件大小 1G / 2G / 3G / 4G (Docker 需要留空间, 建议 2G 起)
   - 默认后台 IP (默认 192.168.50.2)
   - 插件开关: Nikki / OpenClash / PassWall / PassWall2 / Lucky / 应用商店 / Docker / QuickFile / TG 打卡依赖
   - 额外软件包 (可选, 空格分隔)
3. 等待约 10~30 分钟, 到 **Releases** 下载 `*-squashfs-combined-efi.img.gz`
4. 写盘启动 (支持 UEFI), 后台 `http://你设置的IP`, 用户名 root, 首次无密码

## 🔄 新版本自动构建

每天 11:00 (北京时间) 自动检查官方 ImageBuilder 是否有新版本:
- 有新版 (含大版本, 如 25.12.x → 26.x) 自动触发构建, 固件进 Releases
- 自动构建用默认配置: 2G / 插件全开 / 后台 192.168.50.2
- 构建成功后自动更新版本记录, 下次只追踪更新的

注意: GitHub 会在仓库 60 天无活动时停掉定时任务, 到时手动点一次"检查 ImmortalWrt 新版本"即可恢复。

## ⬆️ 一键升级

已刷本固件的机器, 以后升级不用重装:

LuCI → **系统 → 备份/升级** → 上传新构建的固件 → 勾选 **"保留配置"** → 升级

配置、插件设置都在, 重启即用。

## 预装内容

- Argon 主题 (中文)、TTYD 终端、磁盘管理、软件包管理(中文)
- Nikki (Mihomo 透明代理, 中文界面)
- OpenClash (构建时自动打入最新 Meta 内核 + GeoIP/GeoSite)
- PassWall / PassWall2 (中文界面, 自带 xray/sing-box 内核)
- Lucky (动态域名 / 反向代理, 中文界面)
- 应用商店 luci-app-store
- Docker (dockerman 中文界面, 构建时自动配好防火墙: LAN 可访问容器、容器可上网)
- QuickFile (文件管理)

> 代理类插件 (Nikki / OpenClash / PassWall / PassWall2) 装多个没问题, 实际使用时只启用一个做透明代理即可。
- IPv6: 官方底包自带, 开机即用 (未做任何精简)
- 首次开机自动设置后台 IP、时区 Asia/Shanghai

## 📲 配套项目: TG 自动打卡

本固件可勾选 **TG 打卡依赖** (python3/pip)，配合配套项目使用，打卡在固件"保留配置"升级后自动恢复：

**[yiyewudao/tg-checkin](https://github.com/yiyewudao/tg-checkin)** —— 软路由 / 服务器 Telegram 自动打卡一键包：
- 多账号、每天定时打卡，打卡后机器人推送成功/失败清单
- 按账号分别设置打卡目标，支持统一 + 额外叠加模式
- 一键安装、交互式加号、近 7 天记录查询、打卡后可手动补打
- 备份一键恢复 (`restore.sh`)，固件升级后依赖自愈

> 固件里的 TG 打卡依赖选项为本人专用；其他人需要请直接去 tg-checkin 项目页学习使用。

## 致谢

构建思路与第三方 apk 仓库借鉴自 [wukongdaily/ImmortalWrt-ImageBuilder](https://github.com/wukongdaily/ImmortalWrt-ImageBuilder)。
