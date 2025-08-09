#!/usr/bin/env bash
set -euo pipefail
./scripts./scripts./scripts./scripts./scripts./ay_skip_silence.sh

# 4) record_ffmpeg.sh (Mic-Aufnahme; für Systemaudio später BlackHole)
cat > scripts/record_ffmpeg.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p session/audio session/logs
OUT="session/audio/rec_$(date '+%Y%m%d_%H%M%S').m4a"
echo "[INFO] Aufnahme (Mikrofon). Für Systemaudio BlackHole als Ausgabegerät setzen."
ffmpeg -hide_banner -loglevel error -f avfoundation -i ":0" -c:a aac -b:a 192k "$OUT"
echo "[OK] Gespeichert: $OUT"
