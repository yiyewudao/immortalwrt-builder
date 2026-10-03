#!/bin/sh
# 生成 files/etc/uci-defaults/99-custom (固件首次开机时执行一次)
# 环境变量: LAN_IP, LAN_GATEWAY, ENABLE_DOCKER, ROUTER_MODE (bypass/main), ENABLE_ADGUARDHOME, ENABLE_TGCHECKIN, ENABLE_NIKKI
OUT="files/etc/uci-defaults/99-custom"
mkdir -p files/etc/uci-defaults

cat > "$OUT" << EOF
#!/bin/sh
# ---- 首次开机: 后台IP / 网关 / 主机名 / 时区 ----
uci set network.lan.proto='static'
uci set network.lan.ipaddr='${LAN_IP:-192.168.50.4}'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='${LAN_GATEWAY:-192.168.50.1}'
uci set network.lan.dns='223.5.5.5'
uci set network.lan.ip6assign='60'
uci set system.@system[0].hostname='ImmortalWrt'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
uci commit network

# ---- ttyd 监听所有地址 (防 br-lan 多 IP 时绑错导致终端空白) ----
uci delete ttyd.@ttyd[0].interface 2>/dev/null
uci commit ttyd 2>/dev/null || true
EOF

# ---- 旁路由模式: 关闭 LAN 口 DHCPv4 服务 (由主路由分配, 防冲突) ----
if [ "${ROUTER_MODE:-bypass}" = "bypass" ]; then
cat >> "$OUT" << 'EOF'

# ---- 旁路由模式: DHCPv4/DHCPv6/RA 服务已关闭 (主路由负责分配) ----
uci set dhcp.lan.ignore='1'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'
uci commit dhcp

# ---- 旁路由模式: IPv6 自动获取 (DHCPv6 客户端, 挂在 lan 上) ----
uci set network.lan6='interface'
uci set network.lan6.proto='dhcpv6'
uci set network.lan6.device='@lan'
uci set network.lan6.reqaddress='try'
uci set network.lan6.reqprefix='auto'
uci set network.lan6.norelease='1'
uci commit network
EOF
fi

if [ "$ENABLE_DOCKER" = "true" ]; then
cat >> "$OUT" << 'EOF'

# ---- Docker 防火墙 ----
# 注意: ImmortalWrt 25.12 的 fw4 渲染 docker zone 的 device='docker0' 会报
# "The rendered ruleset contains errors" 导致整个防火墙无法重启，进而
# OpenClash 的 nftables 规则加不上去 (50.2 实测)。旁路由场景下 Docker 非必需，
# 故默认不创建 docker zone。如需 Docker，自行在 LuCI 防火墙里手动添加。
# (原配置已注释掉，保留备查)
# uci add firewall zone > /dev/null
# uci set firewall.@zone[-1].name='docker'
# uci set firewall.@zone[-1].input='ACCEPT'
# uci set firewall.@zone[-1].output='ACCEPT'
# uci set firewall.@zone[-1].forward='ACCEPT'
# uci set firewall.@zone[-1].device='docker0'
# uci set firewall.@zone[-1].masq='1'
# uci set firewall.@zone[-1].mtu_fix='1'
# uci add firewall forwarding > /dev/null
# uci set firewall.@forwarding[-1].src='lan'
# uci set firewall.@forwarding[-1].dest='docker'
# uci add firewall forwarding > /dev/null
# uci set firewall.@forwarding[-1].src='docker'
# uci set firewall.@forwarding[-1].dest='lan'
# uci add firewall forwarding > /dev/null
# uci set firewall.@forwarding[-1].src='docker'
# uci set firewall.@forwarding[-1].dest='wan'
# uci commit firewall
# /etc/init.d/firewall reload > /dev/null 2>&1 || true
EOF
fi

# ---- AdGuardHome 53 端口自动配置 (按路由模式) ----
# rufengsuixing 的 init 脚本 (do_redirect) 会在服务启动时自动处理
# dnsmasq 端口冲突和 iptables 重定向规则，这里只需设好 UCI 模式
if [ "$ENABLE_ADGUARDHOME" = "true" ]; then
if [ "${ROUTER_MODE:-bypass}" = "bypass" ]; then
# 旁路由: AdGuardHome 重定向53端口模式，劫持全网 DNS (含写死 8.8.8.8 的设备)
cat >> "$OUT" << 'EOF'

# ---- AdGuardHome (旁路由模式): 重定向53端口 ----
uci set AdGuardHome.@AdGuardHome[0].enabled='1'
uci set AdGuardHome.@AdGuardHome[0].redirect='redirect'
uci set AdGuardHome.@AdGuardHome[0].httpport='3000'
uci commit AdGuardHome
# dnsmasq DNS 让到 5335 端口 (53 给 AdGuardHome, 本地解析走 5335)
uci set dhcp.@dnsmasq[0].port='5335'
uci commit dhcp
# AdGuardHome 上游指向 OpenClash DNS (127.0.0.1:7874), 否则 DNS 绕过 Clash
# 等待 AdGuardHome 生成配置文件后修改 (首次启动时)
(
for _i in $(seq 1 30); do
  [ -f /etc/AdGuardHome.yaml ] && break
  sleep 10
done
[ -f /etc/AdGuardHome.yaml ] || exit 0
# 备份原配置
cp /etc/AdGuardHome.yaml /etc/AdGuardHome.yaml.bak 2>/dev/null
# 用 python3 修改 upstream_dns (如无 python3 则跳过, 需手动在 UI 里改)
python3 << 'PYEOF' 2>/dev/null || exit 0
import re
p = '/etc/AdGuardHome.yaml'
s = open(p).read()
# 替换 upstream_dns 段为 7874 + 公网 DoH
new_upstream = """  upstream_dns:
    - 127.0.0.1:7874
    - https://223.5.5.5/dns-query
    - https://doh.pub/dns-query"""
s = re.sub(r'  upstream_dns:.*?(?=\n  [a-z_]+:)', new_upstream + '\n', s, flags=re.DOTALL)
open(p, 'w').write(s)
PYEOF
# 重启 AdGuardHome 生效
/etc/init.d/AdGuardHome restart 2>/dev/null || true
) &
EOF
else
# 主路由: AdGuardHome 直接占用53替换 dnsmasq，dnsmasq 仅保留 DHCP
cat >> "$OUT" << 'EOF'

# ---- AdGuardHome (主路由模式): 53端口替换 dnsmasq ----
uci set AdGuardHome.@AdGuardHome[0].enabled='1'
uci set AdGuardHome.@AdGuardHome[0].redirect='exchange'
uci set AdGuardHome.@AdGuardHome[0].httpport='3000'
uci commit AdGuardHome
# dnsmasq DNS 让到 5335 端口 (53 给 AdGuardHome, 本地解析走 5335)
uci set dhcp.@dnsmasq[0].port='5335'
uci commit dhcp
# AdGuardHome 上游指向 OpenClash DNS (127.0.0.1:7874), 否则 DNS 绕过 Clash
# 等待 AdGuardHome 生成配置文件后修改 (首次启动时)
(
for _i in $(seq 1 30); do
  [ -f /etc/AdGuardHome.yaml ] && break
  sleep 10
done
[ -f /etc/AdGuardHome.yaml ] || exit 0
cp /etc/AdGuardHome.yaml /etc/AdGuardHome.yaml.bak 2>/dev/null
python3 << 'PYEOF' 2>/dev/null || exit 0
import re
p = '/etc/AdGuardHome.yaml'
s = open(p).read()
new_upstream = """  upstream_dns:
    - 127.0.0.1:7874
    - https://223.5.5.5/dns-query
    - https://doh.pub/dns-query"""
s = re.sub(r'  upstream_dns:.*?(?=\n  [a-z_]+:)', new_upstream + '\n', s, flags=re.DOTALL)
open(p, 'w').write(s)
PYEOF
/etc/init.d/AdGuardHome restart 2>/dev/null || true
) &
EOF
fi
fi

# ---- dnsmasq: router.local 指向网关 (修 192.168.0.1 残留) ----
# 注意: dnsmasq 自带的 "DNS 重定向" 保持关闭, DNS 劫持只由 AdGuardHome 做;
# AdGuardHome 上游自动设为 127.0.0.1:7874 (OpenClash DNS 的 listen 端口, 见你的
# Clash YAML 里 dns.listen 字段, 本例为 7874; redir-host 模式下返回真实 IP,
# AGH 可放心开缓存), 链路: 客户端→AdGuardHome(53)→OpenClash DNS(7874)→上游。
# 另加 127.0.0.1:5335 做本地解析 (router.local 等走 dnsmasq)。
cat >> "$OUT" << EOF
uci delete dhcp.@dnsmasq[0].address 2>/dev/null
uci add_list dhcp.@dnsmasq[0].address='/router.local/router.lan/${LAN_GATEWAY:-192.168.50.1}'
uci commit dhcp
EOF

# ---- Nikki 旁路由模式预置 (不启用, 备用) ----
# 如安装了 luci-app-nikki, 按旁路由优化配置但保持关闭 (OpenClash 为主用)
# 关键: Nikki 自身 IPv6 关闭 / TUN 关闭 / DNS 劫持关闭 (AdGuardHome 接管 DNS)
if [ "$ENABLE_NIKKI" = "true" ]; then
cat >> "$OUT" << 'EOF'

# ---- Nikki (旁路由模式, 默认不启用) ----
uci set nikki.config.enabled='0'
uci set nikki.mixin.ipv6='0'
uci set nikki.mixin.tun_enabled='0'
uci set nikki.mixin.dns_ipv6='0'
uci set nikki.mixin.dns_mode='redir-host'
uci set nikki.proxy.udp_mode='redirect'
uci set nikki.proxy.ipv4_dns_hijack='0'
uci set nikki.proxy.ipv6_dns_hijack='0'
uci commit nikki
EOF
fi

if [ "$ENABLE_TGCHECKIN" = "true" ]; then
cat >> "$OUT" << 'EOF'

# ---- TG 打卡定时任务 (每天 8:30 北京时间; 脚本已预置在 /root/tg-checkin/, 权限正确) ----
grep -q 'tg-checkin/run.sh' /etc/crontabs/root 2>/dev/null || \
  echo '30 8 * * * /root/tg-checkin/run.sh' >> /etc/crontabs/root
/etc/init.d/cron restart > /dev/null 2>&1 || true
EOF
fi

echo 'exit 0' >> "$OUT"
chmod +x "$OUT"
echo "已生成 $OUT (Docker: $ENABLE_DOCKER, 路由模式: ${ROUTER_MODE:-bypass}, AdGuardHome: $ENABLE_ADGUARDHOME)"
