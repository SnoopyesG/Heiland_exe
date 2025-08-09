#!/usr/bin/env bash
set -euo pipefail
IDX="${1:-0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="$ROOT/config.yaml"

REC_DIR=$(python3 - <<'PY'
import yaml,sys
print(yaml.safe_load(open(sys.argv[1]))["recordings_dir"])
PY
"$CFG"
)

LOG_DIR="$ROOT/session/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/afplay_${IDX}.log"

mapfile -t FILES < <(find "$REC_DIR" -type f \( -iname "*.m4a" -o -iname "*.mp3" -o -iname "*.wav" -o -iname "*.aac" \) | sort)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "Keine Dateien im $REC_DIR" | tee -a "$LOG"
  exit 1
fi

i=$IDX
while true; do
  f="${FILES[$(( i % ${#FILES[@]} ))]}"
  echo "[$(date '+%F %T')] afplay -> $f" | tee -a "$LOG"
  afplay "$f" 2>>"$LOG" || true
  ((i++))
done
