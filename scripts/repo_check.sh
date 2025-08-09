#!/usr/bin/env bash
set -euo pipefail
RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; NC=$'\e[0m'
ok(){ echo "${GRN}[OK]${NC} $*"; }
bad(){ echo "${RED}[FAIL]${NC} $*"; FAIL=1; }
warn(){ echo "${YLW}[WARN]${NC} $*"; }

FAIL=0

# 1) Grundstruktur
[ -f AGENTS.md ]        && ok "AGENTS.md vorhanden" || bad "AGENTS.md fehlt"
[ -d docs ]             && ok "docs/ vorhanden"      || bad "docs/ fehlt"
[ -f scripts/test.sh ]  && ok "scripts/test.sh da"   || bad "scripts/test.sh fehlt"
[ -x scripts/test.sh ]  && ok "test.sh ist ausführbar" || bad "test.sh nicht ausführbar (chmod +x)"

# 2) Git-Repo & Status
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  ok "Git-Repo erkannt (Branch: $BRANCH)"
  if ! git diff --quiet || ! git diff --cached --quiet; then
    warn "Es gibt uncommitted Änderungen → 'git add . && git commit -m \"repo setup\"'"
  else
    ok "Arbeitsverzeichnis sauber"
  fi
else
  bad "Kein Git-Repo (git init?)"
fi

# 3) Remote prüfen
if git remote get-url origin >/dev/null 2>&1; then
  REMOTE=$(git remote get-url origin)
  ok "origin gesetzt: $REMOTE"
  if git push -n origin HEAD >/dev/null 2>&1; then
    ok "Push-Rechte OK (Dry-Run)"
  else
    warn "Push-Dry-Run fehlgeschlagen → Auth/Permission prüfen"
  fi
else
  bad "Kein 'origin' gesetzt → 'git remote add origin <URL>'"
fi

# 4) Tests
if ./scripts/test.sh >/dev/null 2>&1; then
  ok "Tests GRÜN (Exit 0)"
else
  bad "Tests ROT (Exit≠0) → scripts/test.sh prüfen"
fi

# Ergebnis
if [ "${FAIL:-0}" = "1" ]; then
  echo
  echo "${RED}Gesamtstatus: FEHLER${NC}"
  exit 1
else
  echo
  echo "${GRN}Gesamtstatus: OK${NC}"
fi
