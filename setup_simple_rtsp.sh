#!/usr/bin/env bash
set -e

echo "🎞️ Installing FFmpeg..."
sudo apt update
sudo apt install -y ffmpeg

# CONFIGURATION
VERSION="v1.13.0"
FILENAME="mediamtx_${VERSION}_linux_amd64.tar.gz"
URL="https://github.com/bluenviron/mediamtx/releases/download/${VERSION}/${FILENAME}"

echo "📦 Downloading mediamtx $VERSION ..."
wget -q --show-progress "$URL"

echo "📂 Extracting..."
tar -xzf "$FILENAME"

echo "🚚 Installing mediamtx to /usr/local/bin ..."
sudo mv mediamtx /usr/local/bin/
sudo chmod +x /usr/local/bin/mediamtx

echo "🧹 Cleaning up..."
rm "$FILENAME"

echo "🛠️ Creating systemd service for rtsp-simple-server..."

sudo tee /etc/systemd/system/rtsp-simple-server.service > /dev/null <<EOF
[Unit]
Description=RTSP Simple Server (mediamtx)
After=network.target

[Service]
ExecStart=/usr/local/bin/mediamtx
Restart=on-failure
User=root
WorkingDirectory=/usr/local/bin

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Reloading systemd and enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable rtsp-simple-server
sudo systemctl start rtsp-simple-server

echo "✅ mediamtx and FFmpeg installed and running!"
ffmpeg -version
sudo systemctl status rtsp-simple-server --no-pager
