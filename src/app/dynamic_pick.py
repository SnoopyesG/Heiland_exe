#!/usr/bin/env python3
import os, sys, time, glob, yaml, pathlib, random, hashlib
from collections import defaultdict

rules = yaml.safe_load(open("dynamic_rules.yaml"))
fet = pathlib.Path(rules["audio"]["fetzen_dir"])
REC_H = rules["router"]["recency_half_life_h"]
COOL = rules["router"]["cooldown_s"]
BIAS_W = float(rules["router"]["bias_weight"])
JIT = float(rules["router"]["random_jitter"])
MAXQ = int(rules["router"]["max_queue"])

# bias laden
bias = []
if os.path.exists("bias.txt"):
    bias = [l.strip().lower() for l in open("bias.txt") if l.strip()]
if rules["router"].get("bias_keywords"):
    bias += [b.lower() for b in rules["router"]["bias_keywords"]]

files = sorted(glob.glob(str(fet / "*.m4a")))
now = time.time()

# zuletzt gespielte Basen lesen (für Cooldown)
lastlog = pathlib.Path("./session/lastplay.log")
last_seen = {}
if lastlog.exists():
    for line in lastlog.read_text().splitlines():
        try:
            ts, base = line.split(" ",1)
            last_seen[base] = float(ts)
        except: pass

def basename(p):
    s = pathlib.Path(p).stem
    # Basis ohne _part_ und Nummer
    return s.split("_part_")[0]

def score(path):
    st = os.stat(path)
    age_h = max(0.0, (now - st.st_mtime)/3600.0)
    # Recency-Score (höher bei neu)
    rec = 2.0 ** (-age_h / REC_H)

    name = pathlib.Path(path).stem.lower()
    bias_s = 1.0
    for b in bias:
        if b and b in name:
            bias_s += BIAS_W

    base = basename(path)
    last_t = last_seen.get(base, 0)
    cool_s = 0.0 if (now - last_t) < COOL else 1.0

    rnd = random.random() * JIT
    return rec * bias_s * cool_s + rnd

scored = sorted(files, key=score, reverse=True)[:MAXQ]
# gib das Top-Element aus
if scored:
    print(scored[0])
else:
    print("")
