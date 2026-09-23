#!/usr/bin/env bash
# Render the spoken phrases into Resources/Speech/ with Gemini TTS through the
# laldinsoft-studio tool (needs that repo, its venv and its Vertex credentials).
# The rendered files are committed, so building the app never needs this.
#   sounds/speak.sh            -> every phrase
#   sounds/speak.sh range_15   -> one phrase
set -euo pipefail
cd "$(dirname "$0")"
source lib/peak.sh
STUDIO=${STUDIO:-../../laldinsoft-studio}
PY="$STUDIO/tools/.venv/bin/python"
VOICE=${VOICE:-Charon}
STYLE=${STYLE:-"calm, clear, natural and slightly quick pace, matter-of-fact, no drama"}
OUT=../Resources/Speech
mkdir -p "$OUT" out

declare -A PHRASES=(
  [premarket_open]="Pre-market open."
  [market_open]="Market open."
  [range_5]="Five minutes."
  [range_10]="Ten minutes."
  [range_15]="Fifteen minute range set."
  [range_30]="Thirty minutes."
  [market_close]="Market close."
  [day_close]="After-hours close."
)
keys=("$@"); [ ${#keys[@]} -eq 0 ] && keys=("${!PHRASES[@]}")
for key in "${keys[@]}"; do
  echo "== $key: ${PHRASES[$key]}"
  "$PY" "$STUDIO/tools/tts.py" --text "${PHRASES[$key]}" --voice "$VOICE" --style "$STYLE" --out "out/speech_$key.wav"
  # Trim leading and trailing silence, 44.1 kHz mono, peaks at -16 dBFS (a touch under the chimes).
  ffmpeg -y -loglevel error -i "out/speech_$key.wav" -ac 1 -ar 44100 -sample_fmt s16 \
    -af "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse,apad=pad_dur=0.08" "$OUT/$key.wav"
  peak_normalise "$OUT/$key.wav" -16
  printf "   %s  %.2fs\n" "$OUT/$key.wav" "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/$key.wav")"
done
