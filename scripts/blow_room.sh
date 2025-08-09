#!/usr/bin/env bash
set -euo pipefail

FOLDER="./session/fetzen"
DELAY=3   # Sekunden zwischen Start der nächsten Spur
MAX_PARALLEL=3

shopt -s nullglob
files=("$FOLDER"/*.m4a)
[ ${#files[@]} -eq 0 ] && echo "Keine Fetzen gefunden." && exit 1

# mischen
files=($(printf "%s\n" "${files[@]}" | shuf))

pids=()
for f in "${files[@]}"; do
    # Starte Spur
    afplay "$f" &
    pids+=($!)

    # Wenn max. parallel erreicht → warten
    if [ ${#pids[@]} -ge $MAX_PARALLEL ]; then
        wait "${pids[0]}"
        pids=("${pids[@]:1}")
    fi

    sleep $DELAY
done

wait
echo "Hörraum komplett durchgeblasen."
