#!/usr/bin/env python3
import os, glob, subprocess, pathlib, sys, yaml

cfg = yaml.safe_load(open("config.yaml"))
ae = cfg["auto_editor"]
out_dir = pathlib.Path(ae["out_dir"])
out_dir.mkdir(parents=True, exist_ok=True)

files = glob.glob(os.path.expanduser(ae["input_glob"]))
if not files:
    print("Keine Dateien gefunden."); sys.exit(0)

for i, f in enumerate(sorted(files), 1):
    name = pathlib.Path(f).stem + "_trimmed.m4a"
    out = out_dir / name
    cmd = [
        "auto-editor", f,
        "--audio-only" if not ae.get("video") else "",
        "--margin", str(ae["margin"]),
        "--silent-threshold", str(ae["silence_threshold"]),
        "--min-cut", str(ae["min_silence"]),
        "--export", "audio",
        "--output", str(out),
    ]
    cmd = [c for c in cmd if c != ""]
    print(f"[{i}/{len(files)}] {f} → {out}")
    subprocess.run(cmd, check=True)
print("Fertig.")
