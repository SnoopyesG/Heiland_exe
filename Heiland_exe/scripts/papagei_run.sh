#!/usr/bin/env bash
set -euo pipefail
SRC="${HOME}/Library/Application Support/com.apple.voicememos/Recordings"
LOG="session/logs/playback.log"
PIDDIR="session/pids"
N=3
DELAY=5
mkdir -p "$(dirname "$LOG")" "$PIDDIR"

# Liste zufällig mischen (ohne 'shuf', nur Python nötig)
mapfile -d '' FILES < <(python3 - <<'PY'
import os, sys, random
src=os.path.expanduser(os.environ.get('SRC',''))
paths=[]
for root,_,files in os.walk(src):
    for f in files:
        fl=f.lower()
        if fl.endswith(('.m4a','.mp3','.wav')):
            paths.append(os.path.join(root,f))
random.shuffle(paths)
sys.stdout.write('\0'.join(paths))
PY
)

if (( ${#FILES[@]} == 0 )); then
  echo "[ERR] Keine Audiodateien in: $SRC" | tee -a "$LOG"; exit 1
fi

echo "---- $(date '+%F %T') START Papagei-Hurricane ----" | tee -a "$LOG"
: > "$PIDDIR/afplay.pids"

for i in $(seq 1 $N); do
  f="${FILES[$((i-1))]:-}"
  [ -z "$f" ] && break
  echo "[RUN] afplay: $f" | tee -a "$LOG"
  (afplay "$f" >/dev/null 2>&1 &)
  echo $! >> "$PIDDIR/afplay.pids"
  sleep "$DELAY"
done
echo "[OK] Gestartet: $(wc -l < "$PIDDIR/afplay.pids") Prozesse" | tee -a "$LOG"
