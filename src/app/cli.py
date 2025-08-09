
import os, time, subprocess, signal, sys, yaml, pathlib
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
    recordings = sorted([p for p in pathlib.Path(cfg["recordings_dir"]).glob("**/*")
                         if p.suffix.lower() in [".m4a",".mp3",".wav",".aac"]])
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
[Sprachmemos - Control]
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
