#!/usr/bin/env bash
set -euo pipefail
echo "==> Heiland_exe • Install/Bootstrap (v2)"

ROOT="$(cd "$(dirname "$0")"; pwd)"; cd "$ROOT"

# --- Python/venv ---
PY="${PYTHON_BIN:-python3}"
command -v "$PY" >/dev/null || { echo "!! python3 fehlt (xcode-select --install)"; exit 1; }
MAKE_VENV=1
[ -d .venv ] || { echo "==> Erzeuge .venv"; "$PY" -m venv .venv || MAKE_VENV=0; }
[ $MAKE_VENV -eq 1 ] && source .venv/bin/activate && PY=python
$PY -m ensurepip --upgrade >/dev/null 2>&1 || true
$PY -m pip install --upgrade pip wheel setuptools

# --- Pakete ---
[ -f requirements.txt ] || printf "pyyaml\nauto-editor\n" > requirements.txt
$PY -m pip install -r requirements.txt

# --- ffmpeg ---
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "!! ffmpeg fehlt. Versuche brew..."
  if command -v brew >/dev/null 2>&1; then brew install ffmpeg || echo "!! Bitte ffmpeg manuell installieren."; else echo "!! Bitte ffmpeg manuell installieren."; fi
fi

# --- Ordner ---
mkdir -p session/trimmed session/fetzen session/playlists scripts src/app

# --- Configs, falls fehlen ---
if ! grep -q "auto_editor:" config.yaml 2>/dev/null; then
cat > config.yaml <<'YAML'
auto_editor:
  input_glob: "~/Library/Application Support/com.apple.voicememos/Recordings/*.m4a"
  out_dir: "./session/trimmed"
  margin: 0.05
  silence_threshold: -50
  min_silence: 0.30
  video: false

audio:
  trimmed_dir: "./session/trimmed"
  fetzen_dir: "./session/fetzen"
  slice_seconds: 12
  parallel: 3
  delay: 3
  threshold_db: -50
  min_silence: 0.30
  margin: 0.05
YAML
echo "==> config.yaml erstellt"
fi

[ -f dynamic_rules.yaml ] || cat > dynamic_rules.yaml <<'YAML'
audio:
  fetzen_dir: "./session/fetzen"
  parallel: 3
  delay: 3
  threshold_db: -50
  min_silence: 0.30
router:
  recency_half_life_h: 12
  cooldown_s: 60
  bias_keywords: []
  bias_weight: 2.0
  random_jitter: 0.35
  max_queue: 200
YAML

# --- Skripte automatisch erzeugen, wenn fehlen ---

# 1) play_skip_silence
[ -f scripts/play_skip_silence.sh ] || cat > scripts/play_skip_silence.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
[ $# -ge 1 ] || { echo "Usage: play_skip_silence.sh <file>"; exit 1; }
IN="$1"; THRESHOLD="-50dB"; MIN_SILENCE="0.30"
ffmpeg -hide_banner -loglevel error -i "$IN" \
  -af "silenceremove=start_periods=1:start_threshold=$THRESHOLD:start_silence=$MIN_SILENCE:stop_periods=-1:stop_threshold=$THRESHOLD:stop_silence=$MIN_SILENCE" \
  -f wav - | afplay -
BASH

# 2) slice_to_fetzen
[ -f scripts/slice_to_fetzen.sh ] || cat > scripts/slice_to_fetzen.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
CFG="${1:-config.yaml}"
read_py(){ python3 - "$CFG" <<'PY'
import sys,yaml; c=yaml.safe_load(open(sys.argv[1])); print(eval(sys.stdin.read()))
PY
}
TRIM="$(echo "yaml.safe_load(open(sys.argv[1]))['audio']['trimmed_dir']" | read_py)"
FETZ="$(echo "yaml.safe_load(open(sys.argv[1]))['audio']['fetzen_dir']"  | read_py)"
SLICE="$(echo "yaml.safe_load(open(sys.argv[1]))['audio']['slice_seconds']" | read_py)"
mkdir -p "$FETZ"; rm -f "$FETZ"/*.m4a 2>/dev/null || true
shopt -s nullglob
for f in "$TRIM"/*.m4a; do
  base="$(basename "${f%.*}")"
  ffmpeg -hide_banner -loglevel error -i "$f" \
    -f segment -segment_time "$SLICE" -reset_timestamps 1 \
    -map 0:a -c:a aac -b:a 192k \
    "$FETZ/${base}_part_%03d.m4a"
done
echo "Fetzen fertig in $FETZ"
BASH

# 3) blow_room_skip
[ -f scripts/blow_room_skip.sh ] || cat > scripts/blow_room_skip.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
FOLDER="./session/fetzen"; DELAY=3; MAX_PARALLEL=3; THRESHOLD="-50dB"; MIN_SILENCE="0.30"
shopt -s nullglob
files=("$FOLDER"/*.m4a); [ ${#files[@]} -gt 0 ] || { echo "Keine Fetzen."; exit 1; }
files=($(printf "%s\n" "${files[@]}" | shuf))
pids=()
for f in "${files[@]}"; do
  ffmpeg -hide_banner -loglevel error -i "$f" \
    -af "silenceremove=start_periods=1:start_threshold=$THRESHOLD:start_silence=$MIN_SILENCE:stop_periods=-1:stop_threshold=$THRESHOLD:stop_silence=$MIN_SILENCE" \
    -f wav - | afplay - &
  pids+=($!)
  if [ ${#pids[@]} -ge $MAX_PARALLEL ]; then wait "${pids[0]}"; pids=("${pids[@]:1}"); fi
  sleep $DELAY
done
wait; echo "Papagei ohne Leerlauf fertig."
BASH

# 4) dynamic_pick
[ -f src/app/dynamic_pick.py ] || cat > src/app/dynamic_pick.py <<'PY'
#!/usr/bin/env python3
import os, time, glob, yaml, pathlib, random
rules = yaml.safe_load(open("dynamic_rules.yaml"))
fet = pathlib.Path(rules["audio"]["fetzen_dir"])
REC_H = rules["router"]["recency_half_life_h"]; COOL = rules["router"]["cooldown_s"]
BIAS_W = float(rules["router"]["bias_weight"]); JIT = float(rules["router"]["random_jitter"])
bias = []
if os.path.exists("bias.txt"): bias=[l.strip().lower() for l in open("bias.txt") if l.strip()]
if rules["router"].get("bias_keywords"): bias += [b.lower() for b in rules["router"]["bias_keywords"]]
files = sorted(glob.glob(str(fet / "*.m4a"))); now=time.time()
last_seen={}
lp=pathlib.Path("./session/lastplay.log")
if lp.exists():
  for line in lp.read_text().splitlines():
    try: ts, base = line.split(" ",1); last_seen[base]=float(ts)
    except: pass
def base(p): return pathlib.Path(p).stem.split("_part_")[0]
def score(p):
  st=os.stat(p); age_h=max(0.0,(now-st.st_mtime)/3600.0); rec=2.0**(-age_h/REC_H)
  name=pathlib.Path(p).stem.lower(); b=1.0
  for w in bias:
    if w and w in name: b+=BIAS_W
  cool=0.0 if (now-last_seen.get(base(p),0))<COOL else 1.0
  return rec*b*cool + random.random()*JIT
scored=sorted(files, key=score, reverse=True)[:200]
print(scored[0] if scored else "")
PY

# 5) blow_dynamic
[ -f scripts/blow_dynamic.sh ] || cat > scripts/blow_dynamic.sh <<'BASH'
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
mkdir -p ./session; : > ./session/lastplay.log
pids=(); trap 'kill 0 2>/dev/null || true' INT TERM
while true; do
  [ -f STOP ] && echo "STOP"; break
  NEXT="$(./src/app/dynamic_pick.py)"; [ -n "$NEXT" ] || { echo "Keine Fetzen."; break; }
  echo "$(date +%s) $(basename "${NEXT%.*}" | sed 's/_part_.*//')" >> ./session/lastplay.log
  ffmpeg -hide_banner -loglevel error -i "$NEXT" \
    -af "silenceremove=start_periods=1:start_threshold=$THRESHOLD:start_silence=$MIN_SILENCE:stop_periods=-1:stop_threshold=$THRESHOLD:stop_silence=$MIN_SILENCE" \
    -f wav - | afplay - &
  pids+=($!)
  if [ ${#pids[@]} -ge "$PARALLEL" ]; then wait "${pids[0]}"; pids=("${pids[@]:1}"); fi
  sleep "$DELAY"
done
wait || true; echo "Dynamischer Lauf beendet."
BASH

# 6) papagei_run (trim -> slice -> blow)
[ -f scripts/papagei_run.sh ] || cat > scripts/papagei_run.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
CFG="${1:-config.yaml}"
./src/app/auto_edit.py
./scripts/slice_to_fetzen.sh "$CFG"
./scripts/blow_room_skip.sh
BASH

# 7) auto_edit (nur anlegen, falls komplett fehlt)
[ -f src/app/auto_edit.py ] || cat > src/app/auto_edit.py <<'PY'
#!/usr/bin/env python3
import os, glob, subprocess, pathlib, sys, yaml
cfg = yaml.safe_load(open("config.yaml"))
ae = cfg["auto_editor"]
out_dir = pathlib.Path(ae["out_dir"]); out_dir.mkdir(parents=True, exist_ok=True)
files = glob.glob(os.path.expanduser(ae["input_glob"]))
if not files: print("Keine Dateien gefunden."); sys.exit(0)
for i, f in enumerate(sorted(files), 1):
    name = pathlib.Path(f).stem + "_trimmed.m4a"
    out = out_dir / name
    cmd = ["auto-editor", f, "--audio-only" if not ae.get("video") else "",
           "--margin", str(ae["margin"]), "--silent-threshold", str(ae["silence_threshold"]),
           "--min-cut", str(ae["min_silence"]), "--export", "audio", "--output", str(out)]
    cmd=[c for c in cmd if c]
    print(f"[{i}/{len(files)}] {f} → {out}")
    subprocess.run(cmd, check=True)
print("Fertig.")
PY

# --- Rechte & Smoke-Tests ---
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x src/app/*.py 2>/dev/null || true

$PY - <<'PY'
import yaml; print("PyYAML OK", yaml.__version__)
PY
command -v auto-editor >/dev/null 2>&1 && auto-editor --version || echo "Hinweis: 'auto-editor' ggf. in .venv/bin/"
echo "==> Bootstrap fertig."
echo "Start:"
echo "  ./scripts/papagei_run.sh      # trim -> slice -> blow (Skip)"
echo "  ./scripts/blow_dynamic.sh     # dynamischer Raum"
