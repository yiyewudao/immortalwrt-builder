#!/bin/sh
# 生成 files/etc/uci-defaults/99-custom (固件首次开机时执行一次)
# 环境变量: LAN_IP, LAN_GATEWAY, ENABLE_DOCKER, ROUTER_MODE (bypass/main), ENABLE_ADGUARDHOME, ENABLE_TGCHECKIN
OUT="files/etc/uci-defaults/99-custom"
mkdir -p files/etc/uci-defaults

cat > "$OUT" << EOF
#!/bin/sh
# ---- 首次开机: 后台IP / 网关 / 主机名 / 时区 ----
uci set network.lan.proto='static'
uci set network.lan.ipaddr='${LAN_IP:-192.168.50.4}'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='${LAN_GATEWAY:-192.168.50.1}'
uci set system.@system[0].hostname='ImmortalWrt'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
uci commit network
EOF

# ---- 旁路由模式: 关闭 LAN 口 DHCPv4 服务 (由主路由分配, 防冲突) ----
if [ "${ROUTER_MODE:-bypass}" = "bypass" ]; then
cat >> "$OUT" << 'EOF'

# ---- 旁路由模式: DHCPv4/DHCPv6/RA 服务已关闭 (主路由负责分配) ----
uci set dhcp.lan.ignore='1'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'
uci commit dhcp
EOF
fi

if [ "$ENABLE_DOCKER" = "true" ]; then
cat >> "$OUT" << 'EOF'

# ---- Docker 防火墙 (fw4, v4+v6): LAN 可访问容器, 容器可上网 ----
uci add firewall zone > /dev/null
uci set firewall.@zone[-1].name='docker'
uci set firewall.@zone[-1].input='ACCEPT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='ACCEPT'
uci set firewall.@zone[-1].device='docker0'
uci set firewall.@zone[-1].masq='1'
uci set firewall.@zone[-1].mtu_fix='1'
uci add firewall forwarding > /dev/null
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest='docker'
uci add firewall forwarding > /dev/null
uci set firewall.@forwarding[-1].src='docker'
uci set firewall.@forwarding[-1].dest='lan'
uci add firewall forwarding > /dev/null
uci set firewall.@forwarding[-1].src='docker'
uci set firewall.@forwarding[-1].dest='wan'
uci commit firewall
/etc/init.d/firewall reload > /dev/null 2>&1 || true
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
# dnsmasq 的 DNS 端口由 AdGuardHome init 脚本自动让位，无需手动处理
EOF
else
# 主路由: AdGuardHome 直接占用53替换 dnsmasq，dnsmasq 仅保留 DHCP
cat >> "$OUT" << 'EOF'

# ---- AdGuardHome (主路由模式): 53端口替换 dnsmasq ----
uci set AdGuardHome.@AdGuardHome[0].enabled='1'
uci set AdGuardHome.@AdGuardHome[0].redirect='exchange'
uci set AdGuardHome.@AdGuardHome[0].httpport='3000'
uci commit AdGuardHome
# dnsmasq 保留 DHCP 功能，DNS 由 AdGuardHome 接管 (init 脚本自动处理端口)
EOF
fi
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
