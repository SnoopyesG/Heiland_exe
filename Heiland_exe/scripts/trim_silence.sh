#!/usr/bin/env bash
set -euo pipefail

CFG="${1:-config.yaml}"
IN="${2:-}"
OUT="${3:-}"

threshold=$(python3 - <<'PY'
import sys, yaml
c=yaml.safe_load(open(sys.argv[1]))
print(c['auto_editor']['silence_threshold'])
PY
"$CFG")

margin=$(python3 - <<'PY'
import sys, yaml
c=yaml.safe_load(open(sys.argv[1]))
print(c['auto_editor']['margin'])
PY
"$CFG")

min_silence=$(python3 - <<'PY'
import sys, yaml
c=yaml.safe_load(open(sys.argv[1]))
print(c['auto_editor']['min_silence'])
PY
"$CFG")

video=$(python3 - <<'PY'
import sys, yaml
c=yaml.safe_load(open(sys.argv[1]))
print('' if c['auto_editor']['video'] else '--audio-only')
PY
"$CFG")

[ -z "$IN" ] && echo "Usage: scripts/trim_silence.sh config.yaml <input> [output]" && exit 1
[ -z "${OUT}" ] && OUT="${IN%.*}_trimmed.m4a"

auto-editor "$IN" $video \
  --margin "$margin" \
  --silent-threshold "$threshold" \
  --min-cut "$min_silence" \
  --export audio \
  --output "$OUT"
echo "OK → $OUT"
