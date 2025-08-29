#!/usr/bin/env bash
set -euo pipefail

HOST_IP="$(hostname -I 2>/dev/null | awk '{print $2}')"
PORT=8554
IN_FPS=30

OUT_SIZE="1280:-2"
OUT_FPS=15
CRF=28
MAXRATE="1500k"
BUFSIZE="3000k"
GOP_MULT=2

DEVICES=(/dev/video2 /dev/video6)

PIDS=()
cleanup() {
  echo "🛑 Stopping streams..."
  for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT

i=0
for dev in "${DEVICES[@]}"; do
  stream="fisheye_${i}"
  url="rtsp://${HOST_IP}:${PORT}/${stream}"
  echo "🚀 Starting stream from $dev → $url"
  
    ffmpeg -hide_banner -nostdin \
      -fflags +genpts -use_wallclock_as_timestamps 1 \
      -f v4l2 -input_format h264 -framerate "${IN_FPS}" -i "${dev}" \
      -vf "scale=${OUT_SIZE},fps=${OUT_FPS}" \
      -c:v libx264 -preset ultrafast -tune zerolatency \
      -x264-params "bframes=0:rc-lookahead=0:keyint=$((OUT_FPS))\
    :min-keyint=$((OUT_FPS)):scenecut=0:ref=1:aq-mode=0" \
      -crf "${CRF}" -maxrate "${MAXRATE}" -bufsize "$(( ${MAXRATE%k} / 2 ))k" \
      -g $((OUT_FPS)) -pix_fmt yuv420p \
      -fflags nobuffer -flags low_delay -flush_packets 1 \
      -muxdelay 0 -muxpreload 0 \
      -f rtsp -rtsp_transport udp "${url}" \
      >/dev/null 2>&1 &

  PIDS+=("$!")
  i=$((i+1))
done

echo
echo "✅ Streams running:"
for j in $(seq 0 $((i-1))); do
   echo "Run 'gst-launch-1.0 rtspsrc location=rtsp://${HOST_IP}:${PORT}/fisheye_${j} latency=0 ! rtph264depay ! h264parse ! avdec_h264 ! autovideosink sync=false'"

done
echo "Press Ctrl+C to stop."
wait
