#!/bin/bash
cd "$(dirname "$0")"
[[ -f smartbot.db ]] || /usr/bin/python3 init_db.py
/usr/bin/python3 smartbot.py
