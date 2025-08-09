#!/usr/bin/env bash
set -e
echo "[*] Setup startet..."
if ! command -v just >/dev/null 2>&1; then
  echo "Homebrew & just pruefen..."
  if ! command -v brew >/dev/null 2>&1; then
    echo "Bitte Homebrew installieren: https://brew.sh"
    exit 1
  fi
  brew install just
fi
just setup
echo "[OK] Fertig. Starte jetzt 'control.command'."
read -n 1 -s -r -p "Weiter mit Taste..."
