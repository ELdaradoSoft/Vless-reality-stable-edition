#!/bin/bash
set -e

# ===== Проверка root =====
if [ "$EUID" -ne 0 ]; then
  echo "❌ Запусти от root"
  exit 1
fi

echo "🚀 Установка Xray..."
bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) install

# ===== Генерация UUID =====
UUID=$(cat /proc/sys/kernel/random/uuid)

# ===== Получение IP (СТАБИЛЬНО) =====
IP=$(curl -4 -s https://api.ipify.org | tr -d '\n')

if [[ ! $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Ошибка определения IP"
  exit 1
fi

# ===== Генерация Reality ключей =====
KEYS=$(/usr/local/bin/xray x25519)

PRIVATE=$(echo "$KEYS" | awk '/Private/ {print $NF}')
PUBLIC=$(echo "$KEYS" | awk '/Public/ {print $NF}')

if [ -z "$PRIVATE" ] || [ -z "$PUBLIC" ]; then
  echo "❌ Ошибка генерации ключей"
  echo "$KEYS"
  exit 1
fi

# ===== Генерация ShortID =====
SHORTID=$(openssl rand -hex 8)

# ===== Выбор SNI =====
SNI_LIST=("www.cloudflare.com" "www.microsoft.com" "www.amazon.com" "www.google.com" "www.github.com")
SNI=${SNI_LIST[$RANDOM % ${#SNI_LIST[@]}]}

echo "📡 Используется SNI: $SNI"

# ===== Создание конфигурации =====
mkdir -p /usr/local/etc/xray

cat > /usr/local/etc/xray/config.json <<EOF
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
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

# ===== Валидация =====
echo "🔎 Проверка конфига..."
/usr/local/bin/xray validate -config /usr/local/etc/xray/config.json

# ===== Запуск =====
systemctl enable xray
systemctl restart xray

sleep 2

if ! systemctl is-active --quiet xray; then
  echo "❌ Xray не запустился"
  journalctl -u xray --no-pager -n 20
  exit 1
fi

# ===== Формирование ссылки =====
LINK="vless://${UUID}@${IP}:443?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC}&sid=${SHORTID}&type=tcp&flow=xtls-rprx-vision#VLESS-REALITY"

echo ""
echo "══════════════════════════════════"
echo "✅ ГОТОВО"
echo "══════════════════════════════════"
echo "UUID: $UUID"
echo "PublicKey: $PUBLIC"
echo "ShortID: $SHORTID"
echo "SNI: $SNI"
echo ""
echo "🔗 Ссылка:"
echo "$LINK"
