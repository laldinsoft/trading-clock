#!/usr/bin/env bash
# Render the chimes headlessly with SuperCollider into Resources/Sounds/.
#   sounds/render.sh                    -> every piece
#   sounds/render.sh pieces/range_5.scd -> one piece
# Needs SuperCollider.app in /Applications and ffmpeg (to trim and convert).
set -euo pipefail
cd "$(dirname "$0")"
source lib/peak.sh
SCLANG=${SCLANG:-/Applications/SuperCollider.app/Contents/MacOS/sclang}
OUT=../Resources/Sounds
files=("$@"); [ ${#files[@]} -eq 0 ] && files=(pieces/*.scd)
mkdir -p "$OUT" out
for f in "${files[@]}"; do
  name=$(basename "$f" .scd)
  tmp=$(mktemp -t "sc_${name}").scd
  cat lib/nrt.scd lib/instruments.scd "$f" > "$tmp"
  echo "== $name"
  "$SCLANG" "$tmp" "$PWD/out/$name.wav" 2>&1 | grep -E 'RENDER_DONE|ERROR|WARNING|line [0-9]+ char' || true
  rm -f "$tmp"
  # 44.1 kHz 16-bit mono, silence trimmed from the tail, peaks at -14 dBFS.
  ffmpeg -y -loglevel error -i "out/$name.wav" -ac 1 -ar 44100 -sample_fmt s16 \
    -af "areverse,silenceremove=start_periods=1:start_threshold=-60dB,areverse,apad=pad_dur=0.05" "$OUT/$name.wav"
  peak_normalise "$OUT/$name.wav" -14
  printf "   %s  %.2fs\n" "$OUT/$name.wav" "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/$name.wav")"
done
