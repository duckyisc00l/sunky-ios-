#!/usr/bin/env bash
# Sunky the Game 2 in the phone's shape: plays through the same steps as the Simulator check and
# takes screenshots. Usage: ci/lab-g2wide.sh <butterscotch binary> <data.win> <out dir>
set -uo pipefail
bs=$(realpath "$1"); data=$(realpath "$2"); out=$(realpath -m "$3"); mkdir -p "$out"
cd "$(dirname "$data")"
timeout 110 "$bs" "$data" --disable-log-colours --widescreen-hack 2.174 --window-size 1113x512 > "$out/log.txt" 2>&1 &
pid=$!
wid=$(timeout 20 xdotool search --sync --onlyvisible --name "" 2>/dev/null | tail -1)
geo() { eval "$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null)"; }
shot() { [ -n "$wid" ] && import -window "$wid" "$out/$1.png" 2>/dev/null; }
tap() { geo; xdotool mousemove --window "$wid" $(python3 -c "print(int($WIDTH*$1), int($HEIGHT*$2))") click 1 2>/dev/null; }
key() { xdotool windowfocus "$wid" 2>/dev/null; xdotool key --clearmodifiers "$@" 2>/dev/null; }
hold() { xdotool windowfocus "$wid" 2>/dev/null; xdotool keydown "$1"; sleep "$2"; xdotool keyup "$1"; }
sleep 4; shot 01-logo
for i in 1 2 3 4 5 6; do tap 0.5 0.72; sleep 2; done; shot 02-after-play
for i in 1 2 3 4; do key Return; sleep 2; done; shot 03-after-enter
sleep 3; shot 04-level
xdotool windowfocus "$wid" 2>/dev/null; xdotool keydown Control_L
hold Right 4; shot 05-right
key Up; sleep 0.3; hold Right 4; shot 06-more
xdotool keyup Control_L
sleep 4; shot 07-late
for i in 1 2 3; do key Return; sleep 2; done; hold Right 6; shot 08-later
geo; echo "window ${WIDTH}x${HEIGHT}" >> "$out/log.txt"
kill $pid 2>/dev/null; wait $pid 2>/dev/null
