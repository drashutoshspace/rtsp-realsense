#!/usr/bin/env bash
set -euo pipefail

echo "Installing dependencies: curl, tar, ffmpeg, v4l-utils..."
sudo apt-get update
sudo apt-get install -y curl tar ffmpeg v4l-utils

# Setup variables
VERSION="v1.13.0"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/mediamtx"
SERVICE_FILE="/etc/systemd/system/rtsp-simple-server.service"

echo "Downloading and installing MediaMTX (rtsp-simple-server)..."
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
curl -L -o mediamtx.tar.gz "https://github.com/bluenviron/mediamtx/releases/download/${VERSION}/mediamtx_${VERSION}_linux_amd64.tar.gz"
tar -xzf mediamtx.tar.gz
sudo mv mediamtx "${INSTALL_DIR}/mediamtx"
sudo chmod +x "${INSTALL_DIR}/mediamtx"

echo "Creating config directory at $CONFIG_DIR"
sudo mkdir -p "$CONFIG_DIR"

echo "Writing MediaMTX configuration to $CONFIG_DIR/mediamtx.yml"
cat <<EOF | sudo tee "${CONFIG_DIR}/mediamtx.yml" > /dev/null
logLevel: info

rtsp: yes
rtspAddress: :8554
rtspTransports: [udp, multicast, tcp]
rtspEncryption: "no"

paths:
  all:
    source: publisher
EOF

echo "Writing systemd service file to $SERVICE_FILE"
cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=RTSP Simple Server (mediamtx)
After=network.target

[Service]
ExecStart=${INSTALL_DIR}/mediamtx ${CONFIG_DIR}/mediamtx.yml
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd and enabling rtsp-simple-server..."
sudo systemctl daemon-reload
sudo systemctl enable rtsp-simple-server
sudo systemctl restart rtsp-simple-server

echo "RTSP Simple Server setup complete."
sudo systemctl status rtsp-simple-server --no-pager
