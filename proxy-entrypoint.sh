#!/bin/sh
set -e

XRAY_UID=10001
CONFIG_TEMPLATE="/etc/xray/config.template.json"
CONFIG_RUNTIME="/tmp/xray-config.json"

# --- Generate xray config from env vars ---

: "${VLESS_ADDRESS:?VLESS_ADDRESS is required}"
: "${VLESS_PORT:?VLESS_PORT is required}"
: "${VLESS_UUID:?VLESS_UUID is required}"
: "${VLESS_PUBLIC_KEY:?VLESS_PUBLIC_KEY is required}"
: "${VLESS_SHORT_ID:?VLESS_SHORT_ID is required}"
: "${VLESS_SNI:=google.com}"
: "${VLESS_FINGERPRINT:=chrome}"
: "${VLESS_SPIDER_X:=/}"

echo "[proxy] Generating xray config..."
envsubst < "$CONFIG_TEMPLATE" > "$CONFIG_RUNTIME"
chown xray "$CONFIG_RUNTIME"

# --- Set up iptables ---

echo "[proxy] Setting up iptables transparent proxy..."

iptables -t nat -F XRAY 2>/dev/null || true
iptables -t nat -X XRAY 2>/dev/null || true

iptables -t nat -N XRAY

# Skip xray process traffic by UID (prevents redirect loops)
iptables -t nat -A XRAY -m owner --uid-owner $XRAY_UID -j RETURN

# Skip local and private addresses
iptables -t nat -A XRAY -d 127.0.0.0/8 -j RETURN
iptables -t nat -A XRAY -d 10.0.0.0/8 -j RETURN
iptables -t nat -A XRAY -d 172.16.0.0/12 -j RETURN
iptables -t nat -A XRAY -d 192.168.0.0/16 -j RETURN

# Redirect all TCP to xray transparent proxy port
iptables -t nat -A XRAY -p tcp -j REDIRECT --to-ports 12345

# Apply to OUTPUT chain
iptables -t nat -A OUTPUT -j XRAY

echo "[proxy] iptables rules applied:"
iptables -t nat -L XRAY -v --line-numbers

echo "[proxy] Starting xray (uid=$XRAY_UID)..."
exec su-exec xray xray run -c "$CONFIG_RUNTIME"
