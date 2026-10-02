#!/bin/sh
# 生成 files/etc/uci-defaults/99-custom (固件首次开机时执行一次)
# 环境变量: LAN_IP, ENABLE_DOCKER
OUT="files/etc/uci-defaults/99-custom"
mkdir -p files/etc/uci-defaults

cat > "$OUT" << EOF
#!/bin/sh
# ---- 首次开机: 后台IP / 主机名 / 时区 ----
uci set network.lan.ipaddr='${LAN_IP:-192.168.50.4}'
uci set system.@system[0].hostname='ImmortalWrt'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
uci commit network
EOF

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

echo 'exit 0' >> "$OUT"
chmod +x "$OUT"
echo "已生成 $OUT (Docker 防火墙规则: $ENABLE_DOCKER)"
