#!/usr/bin/env bash
set -e

# CONFIGURATION
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

# Activate Python venv (optional)
source ~/librealsense/venv/bin/activate

# RTSP Configuration
HOST_IP=$(hostname -I | awk '{print $1}')
DEFAULT_RTSP_URL="rtsp://publisher:s3cr3t@${HOST_IP}:8554/realsense"
RTSP_URL=${2:-$DEFAULT_RTSP_URL}

# Video parameters (tune for performance)
WIDTH=1280       # Lower resolution to reduce bandwidth and decoding errors
HEIGHT=720
FPS=15           # Lower frame rate is more stable on weaker networks
BITRATE=3000k    # Reasonable bitrate for 720p30 (use 5000k+ for 1080p)

# Ensure rtsp-simple-server is running
if ! pgrep -f "rtsp-simple-server" >/dev/null; then
  echo "Starting rtsp-simple-server service..."
  sudo systemctl start rtsp-simple-server
  sleep 2
fi

# Verify device exists
if [ ! -c "$VIDEO_DEVICE" ]; then
  echo "Error: Video device $VIDEO_DEVICE not found." >&2
  exit 1
fi

echo "Streaming $VIDEO_DEVICE → $RTSP_URL"
echo "Resolution: ${WIDTH}x${HEIGHT} @ ${FPS} FPS, Bitrate: $BITRATE"
echo "Press Ctrl+C to stop."

# FFmpeg RTSP Streaming
ffmpeg \
  -hide_banner -loglevel warning \
  -f v4l2 -input_format yuyv422 -video_size ${WIDTH}x${HEIGHT} -framerate ${FPS} -i "$VIDEO_DEVICE" \
  -fflags nobuffer -analyzeduration 0 -probesize 32 \
  -c:v libx264 -preset ultrafast -tune zerolatency -g $((FPS*2)) -b:v $BITRATE \
  -f rtsp -rtsp_transport tcp "$RTSP_URL"
