#!/usr/bin/env bash
set -euo pipefail
OUT="$1"
mkdir -p "$(dirname "$OUT")"
# Hinweis: Liste Eingabegeraete: ffmpeg -f avfoundation -list_devices true -i ""
ffmpeg -y -f avfoundation -i ":0" -ac 2 -ar 44100 -c:a aac "$OUT"
