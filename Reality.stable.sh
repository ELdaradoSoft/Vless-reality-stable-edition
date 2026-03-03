cat > reality-fixed.sh << 'EOF'
#!/bin/bash
set -e

XRAY="/usr/local/bin/xray"
CONFIG="/usr/local/etc/xray/config.json"
SNI="www.cloudflare.com"

install_all() {
apt update -y
apt install -y curl openssl qrencode uuid-runtime jq
bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) install
}

generate_keys() {
$XRAY x25519 > /tmp/keys.txt
PRIVATE=$(sed -n '1p' /tmp/keys.txt | awk '{print $NF}')
PUBLIC=$(sed -n '2p' /tmp/keys.txt | awk '{print $NF}')
SHORTID=$(openssl rand -hex 8)

if [ -z "$PUBLIC" ]; then
echo "❌ Ошибка генерации PublicKey"
cat /tmp/keys.txt
exit 1
fi
}

create_config() {
UUID=$(uuidgen)

cat > $CONFIG <<EOL
{
"log": {"loglevel": "warning"},
"inbounds": [{
"port": 443,
"protocol": "vless",
"settings": {
"clients": [{
"id": "$UUID",
"flow": "xtls-rprx-vision"
}],
"decryption": "none"
},
"streamSettings": {
"network": "tcp",
"security": "reality",
"realitySettings": {
"show": false,
"dest": "$SNI:443",
"xver": 0,
"serverNames": ["$SNI"],
"privateKey": "$PRIVATE",
"shortIds": ["$SHORTID"]
}
}
}],
"outbounds": [{"protocol": "freedom"}]
}
EOL

systemctl restart xray

IP=$(curl -4 -s https://api.ipify.org)

LINK="vless://${UUID}@${IP}:443?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC}&sid=${SHORTID}&type=tcp&flow=xtls-rprx-vision#REALITY"

echo ""
echo "===== ГОТОВО ====="
echo "$LINK"
echo ""
qrencode -t ANSIUTF8 "$LINK"
}

install_all
generate_keys
create_config
EOF

chmod +x reality-fixed.sh
sudo bash reality-fixed.sh
