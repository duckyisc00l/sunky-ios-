#!/usr/bin/env bash
# Sunky the Game 2 in the phone's shape: jumps straight to each room named (BS_START_ROOM) and
# takes screenshots there. Usage: ci/lab-g2wide.sh <butterscotch binary> <data.win> <out dir> <room>...
set -uo pipefail
bs=$(realpath "$1"); data=$(realpath "$2"); out=$(realpath -m "$3"); shift 3; mkdir -p "$out"
cd "$(dirname "$data")"
# find the game's 1113 x 512 window wherever it was put, and capture just that
shot() {
  local g; g=$(xwininfo -root -tree 2>/dev/null | grep -oE "1113x512\+[0-9]+\+[0-9]+" | head -1)
  import -window root ${g:+-crop $g} "$out/$1.png" 2>/dev/null
}
for r in "$@"; do
  BS_START_ROOM=$r timeout 30 "$bs" "$data" --disable-log-colours --widescreen-hack 2.174 --window-size 1113x512 > "$out/room$r.log" 2>&1 &
  pid=$!
  sleep 6; shot "r$r-a"
  xdotool keydown Right; sleep 3; shot "r$r-b"; xdotool keyup Right
  xdotool keydown Left; sleep 3; shot "r$r-c"; xdotool keyup Left
  kill $pid 2>/dev/null; wait $pid 2>/dev/null; sleep 1
done
