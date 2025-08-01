#!/usr/bin/env bash
set -e

# Configuration
WIDTH=1280
HEIGHT=720
FPS=15
BITRATE=3000k
INPUT_FORMAT="yuyv422"

# Activate Python venv if present
source ~/librealsense/venv/bin/activate 2>/dev/null || :

# Determine host IP for RTSP URL
HOST_IP=$(hostname -I | awk '{print $1}')
BASE_RTSP_PORT=8554

# Detect all RGB-compatible RealSense video devices
REALCAM_DEVICES=()
for dev in /dev/video{4..9}; do
  if v4l2-ctl -d "$dev" --list-formats 2>/dev/null | grep -E 'YUYV|MJPG|RGB3' >/dev/null; then
    REALCAM_DEVICES+=("$dev")
  fi
done

if [ ${#REALCAM_DEVICES[@]} -eq 0 ]; then
  echo "❌ No compatible RealSense RGB cameras found."
  exit 1
fi

# Start RTSP server if not running
if ! pgrep -f "mediamtx" >/dev/null && ! pgrep -f "rtsp-simple-server" >/dev/null; then
  echo "📡 Starting RTSP server..."
  sudo systemctl start rtsp-simple-server
  sleep 2
fi

echo "🎥 Detected ${#REALCAM_DEVICES[@]} RealSense RGB-compatible camera(s)."

# Start streaming from each camera
for idx in "${!REALCAM_DEVICES[@]}"; do
  VIDEO_DEVICE="${REALCAM_DEVICES[$idx]}"
  RTSP_URL="rtsp://${HOST_IP}:${BASE_RTSP_PORT}/realsense${idx}"

  echo "🔁 Starting stream from $VIDEO_DEVICE"
  echo "    → $RTSP_URL"
  echo "    Resolution: ${WIDTH}x${HEIGHT} @ ${FPS} FPS | Bitrate: ${BITRATE}"

  ffmpeg \
    -hide_banner -loglevel warning \
    -f v4l2 -input_format ${INPUT_FORMAT} -video_size ${WIDTH}x${HEIGHT} -framerate ${FPS} -i "${VIDEO_DEVICE}" \
    -pix_fmt yuv420p \
    -c:v libx264 -preset ultrafast -tune zerolatency -g $((FPS*2)) -b:v ${BITRATE} \
    -bsf:v h264_mp4toannexb \
    -f rtsp -rtsp_transport tcp "${RTSP_URL}" &

done

echo "✅ All camera streams are now running. Press Ctrl+C to stop."
wait
