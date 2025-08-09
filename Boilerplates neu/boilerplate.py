# Create a downloadable boilerplate zip for the user's "Sprachmemos automatisch abspielen" project

import os, json, zipfile, textwrap, pathlib

base = "/mnt/data/Sprachmemos-Boilerplate"
os.makedirs(base, exist_ok=True)

def write(path, content, mode=0o644):
    p = pathlib.Path(base) / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8")
    os.chmod(p, mode)

# README
write("README.md", textwrap.dedent("""
# Sprachmemos – Boilerplate (macOS)

Ziel: Einfach starten, ohne viel Setup. Abspielen (afplay), Aufnehmen (ffmpeg), Logging und einfache Befehle.

## Schnellstart
1) Doppelklick `bootstrap.command` (legt venv an, installiert Abhängigkeiten).
2) Doppelklick `control.command` (Menü).
3) Pfade in `config.yaml` prüfen/anpassen.

## Standard-Befehle (auch via `just` möglich)
- `./control.command` – Menü starten
- `just play` – Playback gemäß `config.yaml`
- `just record` – ffmpeg-Aufnahme starten
- `just stop` – alle `afplay`/`ffmpeg` stoppen
- `just status` – Prozess-Status
- `just logs` – Logtail

## Struktur
- `src/app/cli.py` – Typer-CLI (Python)
- `config.yaml` – Deine Pfade & Parameter
- `scripts/` – Shell-Skripte (play/record/stop)
- `.vscode/` – VS Code Tasks
- `Justfile` – Kurzbefehle
- `session/` – Logs & Artefakte

Alles lokal, kein Internet nötig.
"""))

# config
write("config.yaml", textwrap.dedent("""
# Passe diese Pfade an.
recordings_dir: "/Users/SG/Library/Application Support/com.apple.voicememos/Recordings"
session_dir: "/Users/SG/ARKHIV/SESSIONS/Sandsturm"
parallel_streams: 3          # wie viele afplay-Instanzen
stagger_seconds: 5           # Startabstand in Sekunden
output_master: "session/master_mix.aac"   # ffmpeg Aufnahme-Ziel
ffmpeg_input_device: "default"            # macOS: 'avfoundation' Gerät über 'default' (Systemaudio via Loopback/BlackHole)
max_runtime_minutes: 0       # 0 = unbegrenzt
"""))

# requirements
write("requirements.txt", "typer[all]==0.12.3\npyyaml==6.0.2\nrich==13.7.1\n")

# python CLI
write("src/app/cli.py", textwrap.dedent(r"""
import os, time, subprocess, signal, sys, yaml, pathlib
from typing import List
import typer
from rich import print
from rich.prompt import Confirm

app = typer.Typer(add_completion=False)

ROOT = pathlib.Path(__file__).resolve().parents[2]
CFG = ROOT / "config.yaml"
SESSION = ROOT / "session"
LOGS = SESSION / "logs"
PIDS = SESSION / "pids"
SCRIPTS = ROOT / "scripts"

def load_cfg():
    with open(CFG, "r") as f:
        return yaml.safe_load(f)

def ensure_dirs():
    for p in [SESSION, LOGS, PIDS, SESSION / "master", ROOT / "output"]:
        p.mkdir(parents=True, exist_ok=True)

def running_pids():
    plist = []
    for f in PIDS.glob("*.pid"):
        try:
            pid = int(f.read_text().strip())
            plist.append((f.stem, pid, f))
        except Exception:
            pass
    return plist

@app.command()
def play():
    cfg = load_cfg()
    ensure_dirs()
    recordings = sorted([p for p in pathlib.Path(cfg["recordings_dir"]).glob("**/*") if p.suffix.lower() in [".m4a",".mp3",".wav",".aac"]])
    if not recordings:
        print("[red]Keine Audiodateien gefunden.[/red]")
        raise typer.Exit(1)

    streams = int(cfg["parallel_streams"])
    stagger = int(cfg["stagger_seconds"])

    print(f"[bold]Starte Playback[/bold]: {streams} Streams, {stagger}s versetzt")
    for i in range(streams):
        cmd = [str(SCRIPTS / "play_once.sh"), str(i)]
        log = LOGS / f"afplay_{i}.log"
        with open(log, "a") as lf:
            p = subprocess.Popen(cmd, stdout=lf, stderr=lf, cwd=ROOT)
        (PIDS / f"afplay_{i}.pid").write_text(str(p.pid))
        time.sleep(stagger)

@app.command()
def record():
    cfg = load_cfg()
    ensure_dirs()
    out = ROOT / cfg["output_master"]
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [str(SCRIPTS / "record_ffmpeg.sh"), str(out)]
    log = LOGS / "ffmpeg_record.log"
    with open(log, "a") as lf:
        p = subprocess.Popen(cmd, stdout=lf, stderr=lf, cwd=ROOT)
    (PIDS / "ffmpeg_record.pid").write_text(str(p.pid))
    print(f"[green]ffmpeg Aufnahme gestartet -> {out}[/green]")

@app.command()
def stop():
    plist = running_pids()
    if not plist:
        print("[yellow]Nichts zu stoppen.[/yellow]")
        return
    if Confirm.ask("Alle Prozesse stoppen?", default=True):
        for name, pid, f in plist:
            try:
                os.kill(pid, signal.SIGTERM)
                time.sleep(0.3)
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            f.unlink(missing_ok=True)
        print("[green]Gestoppt.[/green]")

@app.command()
def status():
    plist = running_pids()
    if not plist:
        print("[yellow]Keine PIDs.[/yellow]")
        return
    for name, pid, _ in plist:
        print(f"[cyan]{name}[/cyan] -> PID {pid}")

@app.command()
def logs():
    os.system(f"tail -n 60 -f '{LOGS}'/*.log")

@app.command()
def menu():
    print("""
[bold]Sprachmemos – Control[/bold]
1) Play
2) Record
3) Stop
4) Status
5) Logs
0) Exit
""")
    choice = input("Auswahl: ").strip()
    if choice == "1": play()
    elif choice == "2": record()
    elif choice == "3": stop()
    elif choice == "4": status()
    elif choice == "5": logs()
    else: sys.exit(0)

if __name__ == "__main__":
    app()
"""))

# shell scripts
write("scripts/play_once.sh", textwrap.dedent(r"""
#!/usr/bin/env bash
set -euo pipefail
IDX="${1:-0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="$ROOT/config.yaml"

# minimal YAML read (requires python available)
REC_DIR=$(python3 - <<'PY'
import yaml,sys
print(yaml.safe_load(open(sys.argv[1]))["recordings_dir"])
PY
"$CFG"
)

LOG_DIR="$ROOT/session/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/afplay_${IDX}.log"

# simple round-robin playlist
mapfile -t FILES < <(find "$REC_DIR" -type f \( -iname "*.m4a" -o -iname "*.mp3" -o -iname "*.wav" -o -iname "*.aac" \) | sort)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "Keine Dateien im $REC_DIR" | tee -a "$LOG"
  exit 1
fi

echo "Starte afplay-Loop IDX=$IDX" | tee -a "$LOG"
i=$IDX
while true; do
  f="${FILES[$(( i % ${#FILES[@]} ))]}"
  echo "[$(date '+%F %T')] afplay -> $f" | tee -a "$LOG"
  afplay "$f" 2>>"$LOG" || true
  ((i++))
done
"""), mode=0o755)

write("scripts/record_ffmpeg.sh", textwrap.dedent(r"""
#!/usr/bin/env bash
set -euo pipefail
OUT="$1"
mkdir -p "$(dirname "$OUT")"
# Hinweis: Für Systemaudio braucht man z.B. BlackHole (Loopback). Input ggf. anpassen.
# Beispiel: ffmpeg -f avfoundation -i ":0"  ...
ffmpeg -y -f avfoundation -i ":0" -ac 2 -ar 44100 -c:a aac "$OUT"
"""), mode=0o755)

write("scripts/stop_all.sh", textwrap.dedent(r"""
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_DIR="$ROOT/session/pids"

if [ ! -d "$PID_DIR" ]; then
  echo "Keine PID-Dir."
  exit 0
fi

for f in "$PID_DIR"/*.pid; do
  [ -e "$f" ] || continue
  pid=$(cat "$f" || echo "")
  if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null || true
    sleep 0.2
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$f"
done
echo "Gestoppt."
"""), mode=0o755)

# justfile
write("Justfile", textwrap.dedent(r"""
# Kurzbefehle: `just <task>`
set shell := ["bash", "-cu"]

venv := "venv"
py := "{{venv}}/bin/python3"
pip := "{{venv}}/bin/pip"

default:
  @echo "Befehle: setup, play, record, stop, status, logs, menu"

setup:
  python3 -m venv {{venv}}
  {{pip}} install -r requirements.txt

play:
  {{py}} src/app/cli.py play

record:
  {{py}} src/app/cli.py record

stop:
  {{py}} src/app/cli.py stop

status:
  {{py}} src/app/cli.py status

logs:
  {{py}} src/app/cli.py logs

menu:
  {{py}} src/app/cli.py menu
"""))

# VS Code tasks
write(".vscode/tasks.json", textwrap.dedent("""
{
  "version": "2.0.0",
  "tasks": [
    { "label": "Setup venv", "type": "shell", "command": "just setup", "problemMatcher": [] },
    { "label": "Play", "type": "shell", "command": "just play", "problemMatcher": [] },
    { "label": "Record", "type": "shell", "command": "just record", "problemMatcher": [] },
    { "label": "Stop", "type": "shell", "command": "just stop", "problemMatcher": [] },
    { "label": "Status", "type": "shell", "command": "just status", "problemMatcher": [] },
    { "label": "Logs", "type": "shell", "command": "just logs", "problemMatcher": [] }
  ]
}
"""))

# mac helper scripts
write("bootstrap.command", textwrap.dedent(r"""
#!/usr/bin/env bash
set -e
echo "[*] Setup..."
if ! command -v just >/dev/null 2>&1; then
  echo "Homebrew & just prüfen..."
  if ! command -v brew >/dev/null 2>&1; then
    echo "Bitte Homebrew installieren: https://brew.sh"
    exit 1
  fi
  brew install just
fi
just setup
echo "[✓] Fertig. Starte jetzt 'control.command'."
read -n 1 -s -r -p "Weiter mit Taste..."
"""), mode=0o755)

write("control.command", textwrap.dedent(r"""
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
if [ ! -d "venv" ]; then
  echo "Bitte zuerst bootstrap.command ausführen."
  read -n 1 -s -r -p "Taste..."
  exit 1
fi
./venv/bin/python3 src/app/cli.py menu
"""), mode=0o755)

# Create zip
zip_path = "/mnt/data/Sprachmemos-Boilerplate.zip"
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(base):
        for f in files:
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, base))

zip_path
