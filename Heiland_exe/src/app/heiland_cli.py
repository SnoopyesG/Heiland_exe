#!/usr/bin/env python3
import argparse, json, pathlib, subprocess, sys
from modules.kilogbuch import KiLogbuch
from modules.brainpower import Brainpower
from modules.regenwald import Regenwald
from modules.totenreich import Totenreich
from modules.morphisches_feld import MorphischesFeld

ROOT = pathlib.Path(__file__).resolve().parents[2]
def load_cfg():
    for p in ["config.yaml","config/master_index.yml"]:
        f = ROOT/p
        if f.exists():
            try: return json.loads(f.read_text())
            except: return {}
    return {}
CFG = load_cfg()

def _scripts():
    s = ROOT/"scripts"
    play = s/"play_skip_silence.sh" if (s/"play_skip_silence.sh").exists() else s/"play_once.sh"
    rec  = s/"record_ffmpeg.sh"
    stop = s/"stop_all.sh"
    return play, rec, stop

def cmd_init(_):
    for d in ["session","session/logs","session/models","session/tmp","session/audio","session/trimmed"]:
        (ROOT/d).mkdir(parents=True, exist_ok=True)
    print("OK init")

def cmd_status(_):
    print(json.dumps({"root": str(ROOT), "config_found": bool(CFG)}, indent=2))

def cmd_ingest(_):
    Regenwald().ingest(); KiLogbuch().capture(); MorphischesFeld().link()
    print("OK ingest")

def cmd_build_model(_):
    Brainpower().build_model(); Totenreich().archive_snapshot()
    print("OK build-model")

def cmd_play(_):
    play, _, _ = _scripts(); subprocess.run([str(play)], check=False)

def cmd_record(_):
    _, rec, _ = _scripts(); subprocess.run([str(rec)], check=False)

def cmd_stop(_):
    _, _, stop = _scripts(); subprocess.run([str(stop)], check=False)

def main():
    ap = argparse.ArgumentParser(prog="heiland")
    sub = ap.add_subparsers(dest="cmd")
    for name, func in {
        "init":cmd_init, "status":cmd_status, "ingest":cmd_ingest,
        "build-model":cmd_build_model, "play":cmd_play,
        "record":cmd_record, "stop":cmd_stop}.items():
        p = sub.add_parser(name); p.set_defaults(func=func)
    a = ap.parse_args()
    if not getattr(a,"func",None): ap.print_help(); sys.exit(1)
    a.func(a)

if __name__ == "__main__":
    main()
