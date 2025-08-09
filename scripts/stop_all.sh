#!/usr/bin/env bash
set -euo pipefail
PIDDIR="session/pids"
LOG="session/logs/stop.log"
mkdir -p "$(dirname "$LOG")"
echo "---- $(date '+%F %T') STOP ----" | tee -a "$LOG"

if [ -f "$PIDDIR/afplay.pids" ]; then
  while read -r p; do
    [ -n "${p:-}" ] && kill "$p" 2>/dev/null || true
  done < "$PIDDIR/afplay.pids"
  : > "$PIDDIR/afplay.pids"
  echo "[OK] afplay gestoppt" | tee -a "$LOG"
fi

pkill -f 'ffmpeg.*avfoundation' 2>/dev/null && echo "[OK] ffmpeg gestoppt" | tee -a "$LOG" || true
