#!/usr/bin/env bash
set -euo pipefail

FOLDER="./session/fetzen"
DELAY=3          # Sekunden zwischen Start der nächsten Spur
MAX_PARALLEL=3   # wie viele Fetzen gleichzeitig laufen
THRESHOLD="-50dB"
MIN_SILENCE="0.30"
MARGIN="0.05"

shopt -s nullglob
files=("$FOLDER"/*.m4a)
[ ${#files[@]} -eq 0 ] && echo "Keine Fetzen gefunden." && exit 1

# Mischen
files=($(printf "%s\n" "${files[@]}" | shuf))

pids=()
for f in "${files[@]}"; do
    ffmpeg -hide_banner -loglevel error -i "$f" \
      -af "silenceremove=start_periods=1:start_threshold=$THRESHOLD:start_silence=$MIN_SILENCE:stop_periods=-1:stop_threshold=$THRESHOLD:stop_silence=$MIN_SILENCE" \
      -f wav - | afplay - &
    pids+=($!)

    # Wenn max. parallel erreicht → ältesten beenden lassen
    if [ ${#pids[@]} -ge $MAX_PARALLEL ]; then
        wait "${pids[0]}"
        pids=("${pids[@]:1}")
    fi

    sleep $DELAY
done

wait
echo "Papagei ohne Leerlauf fertig."
