#!/usr/bin/env bash
# Runs Sunky the Game 2 (GameMaker Studio, bytecode 13) on Butterscotch under a virtual screen.
# Usage: ci/lab-g2.sh <butterscotch binary> <data.win> <out dir>
set -uo pipefail
bs=$(realpath "$1"); data=$(realpath "$2"); out=$(realpath -m "$3"); mkdir -p "$out"
"$bs" "$data" --print-unknown-functions > "$out/unknown-functions.txt" 2>&1
"$bs" "$data" --print-rooms > "$out/rooms.txt" 2>&1
python3 "$(dirname "$0")/strings.py" "$data" > "$out/strings.txt" 2>&1
cd "$(dirname "$data")"
timeout 60 "$bs" "$data" --disable-log-colours > "$out/log.txt" 2>&1 &
pid=$!
wid=$(timeout 20 xdotool search --sync --onlyvisible --name "" 2>/dev/null | tail -1)
shot() { import -window root -crop 1000x600+0+0 "$out/$1.png" 2>/dev/null; }
key() { [ -n "$wid" ] && xdotool windowfocus "$wid" 2>/dev/null; xdotool key --clearmodifiers "$@" 2>/dev/null; }
hold() { [ -n "$wid" ] && xdotool windowfocus "$wid" 2>/dev/null; xdotool keydown "$1"; sleep "$2"; xdotool keyup "$1"; }
sleep 5; shot 01-start
key Return; sleep 3; shot 02-enter
key z; sleep 2; key space; sleep 2; shot 03-z-space
hold Right 4; shot 04-right
key Up; key z; key x; key space; sleep 1; shot 05-jump
hold Right 5; shot 06-run
sleep 5; shot 07-late
if kill -0 $pid 2>/dev/null; then echo "STILL RUNNING at end" >> "$out/log.txt"; kill $pid; else wait $pid; echo "EXITED code $?" >> "$out/log.txt"; fi
tail -3 "$out/log.txt"
