#!/usr/bin/env bash
# Auto install Shadowsocks-libev on Ubuntu + QR code
# Author: vinhchatgpt (tuned)

set -euo pipefail

# ======= Defaults (có thể sửa tại đây) =======
SERVER_PORT="${SERVER_PORT:-8388}"
PASSWORD="${PASSWORD:-matkhau123}"
METHOD="${METHOD:-aes-256-gcm}"

# ======= Helpers =======
need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "❌ Vui lòng chạy với quyền root: sudo $0"
    exit 1
  fi
}

check_ubuntu() {
  if ! command -v apt >/dev/null 2>&1; then
    echo "❌ Script này dành cho Ubuntu/Debian dùng apt."
    exit 1
  fi
}

detect_ip() {
  # Ưu tiên IPv4 public
  local ip=""
  # Thử qua dịch vụ public trước (nếu có mạng ra ngoài)
  if command -v curl >/dev/null 2>&1; then
    ip="$(curl -4s https://ifconfig.me || true)"
    [[ -z "$ip" ]] && ip="$(curl -4s https://api.ipify.org || true)"
  fi
  # Fallback lấy IP local đầu tiên (có thể là private)
  if [[ -z "$ip" ]]; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  echo "${ip:-127.0.0.1}"
}

b64() {
  # Base64 một dòng, tương thích GNU/BusyBox
  if echo -n | base64 -w0 >/dev/null 2>&1; then
    echo -n "$1" | base64 -w0
  else
    echo -n "$1" | base64 | tr -d '\n'
  fi
}

print_usage() {
  cat <<USAGE
Usage:
  sudo $0 [--port 8388] [--pass matkhau123] [--method aes-256-gcm]
  sudo SERVER_PORT=8388 PASSWORD=xxx METHOD=aes-256-gcm $0

Methods hay dùng:
  aes-256-gcm (mặc định), chacha20-ietf-poly1305, aes-128-gcm

Ví dụ:
  sudo $0 --port 443 --pass "mkSieuManh" --method chacha20-ietf-poly1305
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port)   SERVER_PORT="$2"; shift 2 ;;
      --pass)   PASSWORD="$2";    shift 2 ;;
      --method) METHOD="$2";      shift 2 ;;
      -h|--help) print_usage; exit 0 ;;
      *) echo "⚠️  Bỏ qua tham số không rõ: $1"; shift ;;
    esac
  done
}

install_ss() {
  echo "👉 Đang cài đặt Shadowsocks-libev + qrencode..."
  apt update -y
  apt install -y shadowsocks-libev qrencode jq curl

  mkdir -p /etc/shadowsocks-libev
  cat >/etc/shadowsocks-libev/config.json <<EOF
{
  "server": "0.0.0.0",
  "server_port": $SERVER_PORT,
  "password": "$PASSWORD",
  "timeout": 300,
  "method": "$METHOD",
  "fast_open": true,
  "mode": "tcp_and_udp"
}
EOF

  # Bật & khởi động service
  systemctl enable --now shadowsocks-libev

  # Mở UFW nếu có
  if command -v ufw >/dev/null 2>&1; then
    ufw allow ${SERVER_PORT}/tcp || true
    ufw allow ${SERVER_PORT}/udp || true
  fi
}

print_result() {
  local ip="$1"
  local ss_raw="$METHOD:$PASSWORD@$ip:$SERVER_PORT"
  local ss_b64
  ss_b64="$(b64 "$ss_raw")"
  local ss_link="ss://$ss_b64"

  echo "===================================="
  echo "✅ Shadowsocks-libev đã cài đặt xong!"
  echo ""
  echo "Server: $ip"
  echo "Port:   $SERVER_PORT"
  echo "Pass:   $PASSWORD"
  echo "Method: $METHOD"
  echo ""
  echo "👉 Link import (Shadowrocket/Outline/Clash):"
  echo "$ss_link"
  echo ""
  echo "👉 QR Code (quét bằng Shadowrocket):"
  qrencode -t ansiutf8 "$ss_link" || echo "Cài qrencode lỗi?"
  echo "===================================="
  echo "Gợi ý:"
  echo "  • Xem lại QR sau này:  qrencode -t ansiutf8 \"$ss_link\""
  echo "  • Log dịch vụ:         journalctl -u shadowsocks-libev -f"
  echo "  • Sửa cấu hình:        nano /etc/shadowsocks-libev/config.json && systemctl restart shadowsocks-libev"
}

main() {
  need_root
  check_ubuntu
  parse_args "$@"
  local ip
  ip="$(detect_ip)"
  install_ss
  print_result "$ip"
}

main "$@"
