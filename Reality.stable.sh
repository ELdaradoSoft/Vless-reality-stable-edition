#!/bin/bash
set -e

# ===== Цвета =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

XRAY_BIN="/usr/local/bin/xray"
CONFIG="/usr/local/etc/xray/config.json"

print_header() {
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║        XRAY VLESS REALITY • ULTRA MENU EDITION           ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
}

check_root() {
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Запусти от root${NC}"
  exit 1
fi
}

install_deps() {
apt update -y >/dev/null 2>&1
apt install -y curl openssl lsof qrencode >/dev/null 2>&1
}

install_xray() {
bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) install >/dev/null 2>&1
}

generate_config() {
UUID=$(cat /proc/sys/kernel/random/uuid)
IP=$(curl -4 -s https://api.ipify.org | tr -d '\n')

if [[ ! $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo -e "${RED}❌ Ошибка определения IP${NC}"
  exit 1
fi

KEYS=$($XRAY_BIN x25519)
PRIVATE=$(echo "$KEYS" | awk '/PrivateKey:/ {print $2}')
PUBLIC=$(echo "$KEYS" | awk '/Password:/ {print $2}')

if [ -z "$PRIVATE" ] || [ -z "$PUBLIC" ]; then
  echo -e "${RED}❌ Ошибка генерации ключей${NC}"
  exit 1
fi

SHORTID=$(openssl rand -hex 8)

SNI_LIST=("www.cloudflare.com" "www.microsoft.com" "www.amazon.com" "www.google.com" "www.github.com")
SNI=${SNI_LIST[$RANDOM % ${#SNI_LIST[@]}]}

mkdir -p /usr/local/etc/xray

cat > $CONFIG <<EOF
{
  "log": { "loglevel": "warning" },
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
        "dest": "$SNI:443",
        "serverNames": ["$SNI"],
        "privateKey": "$PRIVATE",
        "shortIds": ["$SHORTID"]
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

if ! $XRAY_BIN run -test -config $CONFIG >/dev/null 2>&1; then
  echo -e "${RED}❌ Ошибка в конфиге${NC}"
  exit 1
fi

systemctl enable xray >/dev/null 2>&1
systemctl restart xray

LINK="vless://${UUID}@${IP}:443?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC}&sid=${SHORTID}&type=tcp&flow=xtls-rprx-vision#VLESS-REALITY"

echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}          УСТАНОВКА ЗАВЕРШЕНА       ${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════${NC}"
echo -e "${YELLOW}UUID:${NC}      $UUID"
echo -e "${YELLOW}PublicKey:${NC} $PUBLIC"
echo -e "${YELLOW}ShortID:${NC}   $SHORTID"
echo -e "${YELLOW}SNI:${NC}       $SNI"
echo ""
echo -e "${CYAN}🔗 VLESS ссылка:${NC}"
echo -e "${GREEN}$LINK${NC}"
echo ""

if command -v qrencode >/dev/null 2>&1; then
  echo -e "${CYAN}📱 QR-код:${NC}"
  qrencode -t ANSIUTF8 "$LINK"
fi
}

show_link() {
IP=$(curl -4 -s https://api.ipify.org | tr -d '\n')
UUID=$(grep '"id"' $CONFIG | head -1 | cut -d '"' -f4)
PUBLIC=$(grep '"privateKey"' -n $CONFIG >/dev/null 2>&1 && $XRAY_BIN x25519 2>/dev/null | awk '/Password:/ {print $2}' || echo "")
echo "UUID: $UUID"
echo "IP: $IP"
}

main_menu() {
clear
print_header
echo -e "${BOLD}1) 🚀 Установить / переустановить${NC}"
echo -e "${BOLD}2) 🔄 Перезапустить Xray${NC}"
echo -e "${BOLD}3) 📄 Показать конфиг${NC}"
echo -e "${BOLD}0) ❌ Выход${NC}"
echo ""
read -p "Выбери пункт: " opt

case $opt in
1) generate_config ;;
2) systemctl restart xray && echo "Перезапущено" ;;
3) cat $CONFIG ;;
0) exit 0 ;;
*) echo "Неверный выбор" ;;
esac
}

check_root
install_deps
install_xray
main_menu
