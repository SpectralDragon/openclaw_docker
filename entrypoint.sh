#!/bin/sh
set -e

# Optional: start redsocks + iptables if proxy is configured via env
if [ -n "${REDSOCKS_PROXY_IP}" ]; then
    REDSOCKS_PROXY_PORT="${REDSOCKS_PROXY_PORT:-1080}"
    REDSOCKS_PROXY_TYPE="${REDSOCKS_PROXY_TYPE:-socks5}"
    REDSOCKS_LOCAL_PORT="${REDSOCKS_LOCAL_PORT:-12345}"

    # Resolve proxy hostname to IP for iptables exclude (avoid redirect loop)
    PROXY_IP=$(getent hosts "${REDSOCKS_PROXY_IP}" 2>/dev/null | head -1 | awk '{print $1}')
    [ -z "${PROXY_IP}" ] && PROXY_IP="${REDSOCKS_PROXY_IP}"

    cat > /etc/redsocks.conf << EOF
base {
    log_info = on;
    log = stderr;
    daemon = off;
    redirector = iptables;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = ${REDSOCKS_LOCAL_PORT};
    ip = ${REDSOCKS_PROXY_IP};
    port = ${REDSOCKS_PROXY_PORT};
    type = ${REDSOCKS_PROXY_TYPE};
EOF
    if [ -n "${REDSOCKS_LOGIN}" ]; then
        echo "    login = \"${REDSOCKS_LOGIN}\";" >> /etc/redsocks.conf
    fi
    if [ -n "${REDSOCKS_PASSWORD}" ]; then
        echo "    password = \"${REDSOCKS_PASSWORD}\";" >> /etc/redsocks.conf
    fi
    echo "}" >> /etc/redsocks.conf

    echo "Starting redsocks (transparent) on 127.0.0.1:${REDSOCKS_LOCAL_PORT} -> ${REDSOCKS_PROXY_IP}:${REDSOCKS_PROXY_PORT} (${REDSOCKS_PROXY_TYPE})"
    redsocks -c /etc/redsocks.conf &

    echo "Setting up iptables: redirect TCP to redsocks, exclude 127.0.0.0/8 and proxy ${PROXY_IP}"
    iptables -t nat -N REDSOCKS 2>/dev/null || iptables -t nat -F REDSOCKS
    iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -p tcp -j RETURN
    iptables -t nat -A REDSOCKS -d "${PROXY_IP}" -p tcp -j RETURN
    iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports "${REDSOCKS_LOCAL_PORT}"
    iptables -t nat -C OUTPUT -p tcp -j REDSOCKS 2>/dev/null || iptables -t nat -A OUTPUT -p tcp -j REDSOCKS
fi

# Ensure /root/.ssh exists for SSH login (volume may be empty)
mkdir -p /root/.ssh
chmod 700 /root/.ssh
[ -f /root/.ssh/authorized_keys ] && chmod 600 /root/.ssh/authorized_keys

# Start SSH server (ssh-keygen, ssh available; connect with ssh -p 2222 root@localhost)
mkdir -p /run/sshd
echo "Starting sshd on port 22"
/usr/sbin/sshd

# Copy gitconfig from persisted volume if present
cp ~/.gitcfg/.gitconfig ~/.gitconfig 2>/dev/null || true

exec "$@"
