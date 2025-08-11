#!/usr/bin/env bash
set -euo pipefail

# Auto-get the primary hostname IP
HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
PORT=8554
FPS=30

# Devices for fisheye cams
DEVICES=(/dev/video2 /dev/video6)

# Kill background ffmpeg processes on exit
PIDS=()
cleanup() {
    echo "🛑 Stopping streams..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
}
trap cleanup EXIT

i=0
for dev in "${DEVICES[@]}"; do
    stream="fisheye_${i}"
    url="rtsp://${HOST_IP}:${PORT}/${stream}"
    echo "🚀 Starting stream from $dev → $url"

    ffmpeg -hide_banner -nostdin \
        -fflags +genpts -use_wallclock_as_timestamps 1 \
        -f v4l2 -input_format h264 -framerate "${FPS}" -i "${dev}" \
        -c:v copy -flags low_delay -muxdelay 0 -muxpreload 0 \
        -f rtsp -rtsp_transport tcp "${url}" \
        >/dev/null 2>&1 &

    PIDS+=("$!")
    i=$((i+1))
done

echo
echo "✅ Streams running:"
for j in $(seq 0 $((i-1))); do
    echo "  rtsp://${HOST_IP}:${PORT}/fisheye_${j}"
done
echo "Press Ctrl+C to stop."
wait