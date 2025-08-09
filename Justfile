
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


// auto-editor
trim file=:
    ./scripts/trim_silence.sh config.yaml {{file}}

trim-all:
    ./src/app/auto_edit.py

play-trimmed file=:
    afplay ./session/trimmed/{{file}}

play-skip file=:
    ./scripts/play_skip_silence.sh {{file}}

blow-room:
    ./scripts/blow_room.sh


blow-room-skip:
    ./scripts/blow_room_skip.sh


just parrot-run


parrot-dynamic:
    ./scripts/blow_dynamic.sh
