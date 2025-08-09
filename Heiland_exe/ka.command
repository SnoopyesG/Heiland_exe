# Create the fix_make_hang.command script for the user

from pathlib import Path
import os, textwrap, stat, datetime, json

base_dir = Path("/mnt/data")
script_path = base_dir / "fix_make_hang.command"

script = textwrap.dedent("""\
    #!/bin/bash
    set -euo pipefail

    # fix_make_hang.command
    # Zweck: macOS-Builds mit "make" entstören, CLT prüfen, saubere Umgebung, Logs sammeln.
    # Nutzung:
    #   1) In dein Projektverzeichnis wechseln (wo das Makefile liegt)
    #   2) Diese Datei ausführen (Doppelklick im Finder oder: ./fix_make_hang.command [make-Ziel])
    #   3) Logs liegen in ./build_support/
    #
    # Optionales Argument: make-Ziel (z. B. "all", "install", "clean"). Standard: kein Ziel.

    TARGET="${1:-}"

    timestamp() { date +"%Y-%m-%d %H:%M:%S %z"; }

    PROJECT_DIR="$(pwd)"
    LOG_DIR="${PROJECT_DIR}/build_support"
    mkdir -p "${LOG_DIR}"
    LOG_FILE="${LOG_DIR}/make_$(date +%Y%m%d_%H%M%S).log"

    echo "== fix_make_hang.command :: $(timestamp) ==" | tee -a "${LOG_FILE}"
    echo "Projekt: ${PROJECT_DIR}" | tee -a "${LOG_FILE}"
    echo "Log: ${LOG_FILE}" | tee -a "${LOG_FILE}"

    # 0) Systeminfo
    {
      echo "--- Systeminfo ---"
      sw_vers 2>/dev/null || true
      uname -a
      echo
      echo "--- Speicher/Platz ---"
      df -h /
      vm_stat | head -n 10 || true
      echo
    } >> "${LOG_FILE}"

    # 1) CLT/Xcode prüfen
    echo "[1] Prüfe Command Line Tools (CLT)..." | tee -a "${LOG_FILE}"
    CLT_PATH="$(/usr/bin/xcode-select -p 2>/dev/null || true)"
    if [[ -z "${CLT_PATH}" ]]; then
      echo "❌ CLT NICHT gefunden." | tee -a "${LOG_FILE}"
      echo "   -> Öffne Installer…" | tee -a "${LOG_FILE}"
      /usr/bin/xcode-select --install || true
      echo "Warte, bis die Installation fertig ist und starte das Skript erneut." | tee -a "${LOG_FILE}"
      exit 1
    else
      echo "✅ CLT gefunden unter: ${CLT_PATH}" | tee -a "${LOG_FILE}"
    fi

    # 1b) Sicherstellen, dass auf CLT gezeigt wird (nicht volles Xcode), falls vorhanden
    if [[ "${CLT_PATH}" != "/Library/Developer/CommandLineTools" && -d "/Library/Developer/CommandLineTools" ]]; then
      echo "ℹ️ Aktiver Dev-Pfad ist ${CLT_PATH}, setze auf CommandLineTools (erfordert sudo)..." | tee -a "${LOG_FILE}"
      if sudo -n true 2>/dev/null; then
        sudo /usr/bin/xcode-select -s /Library/Developer/CommandLineTools || true
        echo "   -> gesetzt. Neuer Pfad: $(/usr/bin/xcode-select -p)" | tee -a "${LOG_FILE}"
      else
        echo "   ⚠️ Kein sudo ohne Passwort. Falls Builds hängen: ausführen:" | tee -a "${LOG_FILE}"
        echo "      sudo xcode-select -s /Library/Developer/CommandLineTools" | tee -a "${LOG_FILE}"
      fi
    fi

    # 2) Compiler/Tools prüfen
    echo "[2] Compiler/Tools prüfen..." | tee -a "${LOG_FILE}"
    {
      echo "--- clang ---"
      which clang || true
      clang --version || true
      echo
      echo "--- make (BSD) ---"
      which make || true
      /usr/bin/make -v 2>/dev/null || echo "(macOS make zeigt keine -v)"
      echo
      echo "--- gmake (GNU make, optional) ---"
      which gmake || true
      gmake --version 2>/dev/null || true
      echo
    } >> "${LOG_FILE}"

    # 3) Störfaktoren reduzieren
    echo "[3] Saubere Build-Umgebung vorbereiten..." | tee -a "${LOG_FILE}"
    export HOMEBREW_MAKE_JOBS=1
    unset HOMEBREW_BUILD_FROM_SOURCE
    # Minimaler PATH für Clean-Env
    CLEAN_PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

    # 4) Diagnose vor dem Build
    echo "[4] Vorab-Diagnose (Dateisperren/Prozesse)..." | tee -a "${LOG_FILE}"
    {
      echo "--- laufende make/clang Prozesse ---"
      ps aux | egrep 'make|clang' | egrep -v egrep || true
      echo
      echo "--- Locks in /tmp (Top 20) ---"
      ls -lt /tmp | head -n 20 || true
      echo
    } >> "${LOG_FILE}"

    # 5) Build seriell & verbose ausführen und vollständig loggen
    echo "[5] Starte make (seriell, verbose)..." | tee -a "${LOG_FILE}"
    echo "    Ziel: '${TARGET}' (leer = Default)" | tee -a "${LOG_FILE}"
    echo | tee -a "${LOG_FILE}"

    # TTY erkennen (für Doppelklick im Finder)
    if [[ -z "${TERM:-}" ]]; then
      # Kein Terminal: eigenes aufmachen
      open -a Terminal "${PWD}"
      echo "Dieses Skript sollte aus dem Terminal gestartet werden, damit Ausgabe sichtbar ist." | tee -a "${LOG_FILE}"
    fi

    # Build
    set +e
    env -i PATH="${CLEAN_PATH}" /bin/bash -lc \
      "cd \"${PROJECT_DIR}\" && make -j1 V=1 ${TARGET}" \
      2>&1 | tee -a "${LOG_FILE}"
    BUILD_RC=${PIPESTATUS[0]}
    set -e

    echo | tee -a "${LOG_FILE}"
    if [[ ${BUILD_RC} -eq 0 ]]; then
      echo "✅ Build erfolgreich." | tee -a "${LOG_FILE}"
    else
      echo "❌ Build fehlgeschlagen (RC=${BUILD_RC}). Sammle Zusatz-Logs..." | tee -a "${LOG_FILE}"
      # 6) Homebrew-Logs einsammeln (kompakt)
      BREW_LOG_SUMMARY="${LOG_DIR}/brew_logs_summary.txt"
      echo "--- Homebrew-Logs (letzte 100 Zeilen je Datei) ---" > "${BREW_LOG_SUMMARY}"
      find "${HOME}/Library/Logs/Homebrew" -type f -name "*.log" -maxdepth 2 2>/dev/null | while read -r f; do
        echo "----- ${f} -----" >> "${BREW_LOG_SUMMARY}"
        tail -n 100 "${f}" >> "${BREW_LOG_SUMMARY}" || true
        echo >> "${BREW_LOG_SUMMARY}"
      done
      echo "Zusatz-Logs: ${BREW_LOG_SUMMARY}" | tee -a "${LOG_FILE}"
      echo "Tipp: prüfe fehlende Header/SDK-Hinweise und 'No such file or directory'-Fehler in ${LOG_FILE}." | tee -a "${LOG_FILE}"
    fi

    echo "Logs liegen in: ${LOG_DIR}" | tee -a "${LOG_FILE}"
    echo "Fertig. ($(timestamp))" | tee -a "${LOG_FILE}"
    """)

script_path.write_text(script, encoding="utf-8")
# Make it executable
script_path.chmod(script_path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

print(f"Created script at: {script_path}")
