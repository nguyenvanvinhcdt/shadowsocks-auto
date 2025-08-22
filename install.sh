#!/bin/bash
# Auto install Shadowsocks-libev on Ubuntu + QR code
# Author: vinhchatgpt

# ==============================
# Cấu hình mặc định (có thể sửa ở đây)
# ==============================
SERVER_PORT=8388
PASSWORD="matkhau123"
METHOD="aes-256-gcm"

# Lấy IP VPS
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "👉 Đang cài đặt Shadowsocks-libev..."
sudo apt update -y
sudo apt install -y shadowsocks-libev qrencode

# Tạo thư mục config
sudo mkdir -p /etc/shadowsocks-libev

# Ghi file cấu hình JSON
cat <<EOF | sudo tee /etc/shadowsocks-libev/config.json
{
  "server":"0.0.0.0",
  "server_port":$SERVER_PORT,
  "password":"$PASSWORD",
  "timeout":300,
  "method":"$METHOD"
}
EOF

# Khởi động dịch vụ
sudo systemctl enable shadowsocks-libev
sudo systemctl restart shadowsocks-libev

# Mở port trên firewall nếu dùng UFW
if command -v ufw >/dev/null; then
  sudo ufw allow $SERVER_PORT/tcp
  sudo ufw allow $SERVER_PORT/udp
fi

# Tạo link ss:// (Base64 chuẩn)
SS_RAW="$METHOD:$PASSWORD@$SERVER_IP:$SERVER_PORT"
SS_LINK="ss://$(echo -n "$SS_RAW" | base64 | tr -d '\n')"

echo "===================================="
echo "✅ Shadowsocks đã được cài đặt thành công!"
echo ""
echo "Server: $SERVER_IP"
echo "Port:   $SERVER_PORT"
echo "Pass:   $PASSWORD"
echo "Method: $METHOD"
echo ""
echo "👉 Link để import vào Shadowrocket:"
echo "$SS_LINK"
echo ""
echo "👉 QR Code (quét bằng Shadowrocket):"
qrencode -t ansiutf8 "$SS_LINK"
echo "===================================="
