#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
if [ ! -d "venv" ]; then
  echo "Bitte zuerst bootstrap.command ausfuehren."
  read -n 1 -s -r -p "Taste..."
  exit 1
fi
./venv/bin/python3 src/app/cli.py menu

##Menü auschnitt
echo "7) Stille schneiden (alle)"
read -r choice
case "$choice" in
  7) ./src/app/auto_edit.py ;;
esac
