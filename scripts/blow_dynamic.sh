#!/usr/bin/env bash
set -euo pipefail

THRESHOLD="$(python3 - <<'PY'
import yaml;print(str(yaml.safe_load(open("dynamic_rules.yaml"))["audio"]["threshold_db"])+"dB")
PY
)"
MIN_SILENCE="$(python3 - <<'PY'
import yaml;print(yaml.safe_load(open("dynamic_rules.yaml"))["audio"]["min_silence"])
PY
)"
PARALLEL="$(python3 - <<'PY'
import yaml;print(yaml.safe_load(open("dynamic_rules.yaml"))["audio"]["parallel"])
PY
)"
DELAY="$(python3 - <<'PY'
import yaml;print(yaml.safe_load(open("dynamic_rules.yaml"))["audio"]["delay"])
PY
)"

mkdir -p ./session
: > ./session/lastplay.log

pids=()
trap 'echo "STOP"; kill 0 2>/dev/null || true' INT TERM

while true; do
  # Stop per Datei
  [ -f STOP ] && echo "STOP-Datei gefunden." && break

  # Hole dynamisch den nächsten Fetzen
  NEXT="$(./src/app/dynamic_pick.py)"
  [ -z "$NEXT" ] && echo "Keine Fetzen gefunden." && break

  # Merke Basename + Zeit -> Cooldown
  echo "$(date +%s) $(basename "${NEXT%.*}" | sed 's/_part_.*//')" >> ./session/lastplay.log

  # Starte mit Live-Stille-Skip
  ffmpeg -hide_banner -loglevel error -i "$NEXT" \
    -af "silenceremove=start_periods=1:start_threshold=$THRESHOLD:start_silence=$MIN_SILENCE:stop_periods=-1:stop_threshold=$THRESHOLD:stop_silence=$MIN_SILENCE" \
    -f wav - | afplay - &
  pids+=($!)

  # Parallellimit
  if [ ${#pids[@]} -ge "$PARALLEL" ]; then
    wait "${pids[0]}"; pids=("${pids[@]:1}")
  fi

  sleep "$DELAY"
done

wait || true
echo "Dynamischer Lauf beendet."
