#!/usr/bin/env bash
# Downloads every game listed in ci/games.txt from Game Jolt into games/<name>.exe
set -euo pipefail
mkdir -p games
grep -v '^#' ci/games.txt | while read -r name build title; do
  [ -z "$name" ] && continue
  if [ -s "games/$name.exe" ]; then echo "have $name"; continue; fi
  url=$(curl -fsS -X POST -H 'Content-Type: application/json' -d '{}' \
    "https://gamejolt.com/site-api/web/discover/games/builds/get-download-url/$build" \
    | python3 -c 'import json,sys;print(json.load(sys.stdin)["payload"]["url"])')
  curl -fsSL --retry 3 "$url" -o "games/$name.exe"
  echo "got $name $(stat -c %s games/$name.exe) bytes ($title)"
done
