#!/usr/bin/env bash
set -e

# Configuration: pick device from argument or auto-detect
if [ -n "$1" ]; then
  VIDEO_DEVICE="$1"
else
  DEVICE=$(v4l2-ctl --list-devices | awk '/Intel RealSense D435I/{getline; print $1; exit}')
  if [ -n "$DEVICE" ]; then
    VIDEO_DEVICE="$DEVICE"
  else
    echo "Warning: Could not auto-detect RealSense device; defaulting to /dev/video4"
    VIDEO_DEVICE="/dev/video4"
  fi
fi

INPUT_FORMAT="yuyv422"
WIDTH=1280
HEIGHT=720
FPS=15
BITRATE=3000k

# Activate Python venv if present
source ~/librealsense/venv/bin/activate 2>/dev/null || :

# RTSP URL configuration
HOST_IP=$(hostname -I | awk '{print $1}')
DEFAULT_RTSP_URL="rtsp://${HOST_IP}:8554/realsense"
RTSP_URL=${2:-$DEFAULT_RTSP_URL}

# Start RTSP server if needed
if ! pgrep -f "mediamtx" >/dev/null && ! pgrep -f "rtsp-simple-server" >/dev/null; then
  sudo systemctl start rtsp-simple-server
  sleep 2
fi

# Verify device exists
if [ ! -c "$VIDEO_DEVICE" ]; then
  echo "Error: Video device $VIDEO_DEVICE not found." >&2
  exit 1
fi

echo "Streaming from $VIDEO_DEVICE to $RTSP_URL"
echo "Resolution: ${WIDTH}x${HEIGHT} @ ${FPS} FPS"
echo "Bitrate: $BITRATE, Format: $INPUT_FORMAT"
echo "Press Ctrl+C to stop."

# FFmpeg RTSP Streaming with pixel-format conversion and Annex B bitstream filter
ffmpeg \
  -hide_banner -loglevel warning \
  -f v4l2 -input_format ${INPUT_FORMAT} -video_size ${WIDTH}x${HEIGHT} -framerate ${FPS} -i "${VIDEO_DEVICE}" \
  -pix_fmt yuv420p \
  -c:v libx264 -preset ultrafast -tune zerolatency -g $((FPS*2)) -b:v ${BITRATE} \
  -bsf:v h264_mp4toannexb \
  -f rtsp -rtsp_transport tcp "${RTSP_URL}"
