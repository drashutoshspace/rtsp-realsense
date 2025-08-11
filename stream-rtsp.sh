#!/usr/bin/env bash
set -e

# Config
WIDTH=1280
HEIGHT=720
FPS=15
BITRATE=3000k
INPUT_FORMAT="yuyv422"
BASE_RTSP_PORT=8554

# Get IP
HOST_IP=$(hostname -I | awk '{print $1}')

# Detect RealSense RGB cameras
REALCAM_DEVICES=()
for dev in /dev/video*; do
  if v4l2-ctl -d "$dev" --list-formats-ext 2>/dev/null | grep -qE 'YUYV|MJPG|RGB3'; then
    if v4l2-ctl -d "$dev" --all 2>/dev/null | grep -q "RealSense"; then
      REALCAM_DEVICES+=("$dev")
    fi
  fi
done

if [ ${#REALCAM_DEVICES[@]} -eq 0 ]; then
  echo "❌ No RealSense RGB cameras found."
  exit 1
fi

# Prompt user to choose camera
echo "🎥 Detected RealSense cameras:"
for idx in "${!REALCAM_DEVICES[@]}"; do
  echo "[$idx] ${REALCAM_DEVICES[$idx]}"
done

read -rp "Select camera to stream (index): " CHOICE
if [[ -z "${REALCAM_DEVICES[$CHOICE]}" ]]; then
  echo "❌ Invalid selection."
  exit 1
fi

SELECTED_DEVICE="${REALCAM_DEVICES[$CHOICE]}"
RTSP_PATH="realsense$CHOICE"
RTSP_URL="rtsp://localhost:${BASE_RTSP_PORT}/${RTSP_PATH}"

# Start RTSP server if not running
if ! pgrep -f "mediamtx" >/dev/null && ! pgrep -f "rtsp-simple-server" >/dev/null; then
  echo "📡 Starting RTSP server..."
  sudo systemctl start mediamtx || sudo systemctl start rtsp-simple-server
  sleep 2
fi

echo "🚀 Streaming from $SELECTED_DEVICE → $RTSP_URL"
ffmpeg \
  -hide_banner \
  -f v4l2 -input_format ${INPUT_FORMAT} -video_size ${WIDTH}x${HEIGHT} -framerate ${FPS} -i "${SELECTED_DEVICE}" \
  -pix_fmt yuv420p \
  -c:v libx264 -preset ultrafast -tune zerolatency -g $((FPS*2)) -b:v ${BITRATE} \
  -bsf:v h264_mp4toannexb \
  -f rtsp -rtsp_transport tcp "${RTSP_URL}"
