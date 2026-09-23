# peak_normalise FILE TARGET_DBFS — rewrite FILE so its loudest sample sits at TARGET_DBFS.
# Sourced by render.sh and speak.sh so chimes and speech land at a known level.
peak_normalise() {
  local file="$1" target="$2" peak gain
  peak=$(ffmpeg -i "$file" -af volumedetect -f null - 2>&1 | awk '/max_volume/ {print $5}')
  gain=$(awk -v t="$target" -v p="$peak" 'BEGIN { printf "%.2f", t - p }')
  ffmpeg -y -loglevel error -i "$file" -af "volume=${gain}dB" -sample_fmt s16 "$file.tmp.wav" && mv "$file.tmp.wav" "$file"
}
