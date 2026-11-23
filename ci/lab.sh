#!/usr/bin/env bash
# Runs each game in OpenGMK under a virtual screen, with screenshots and some key presses.
# Usage: ci/lab.sh <out dir> [games...]
set -uo pipefail
out=$(realpath -m "$1"); shift
games=${*:-p1 p2 p3 mpeg tiff}
emu=$(realpath "${EMU:-engine/ogmk/target/release/gm8emulator}")
mkdir -p "$out"
for g in $games; do
  d=$out/$g; mkdir -p "$d"; exe=$PWD/games/$g.exe
  [ -f "$exe" ] || { echo "no exe for $g" > "$d/log.txt"; continue; }
  run=$(mktemp -d); cp "$exe" "$run/game.exe"; cd "$run"
  timeout 75 "$emu" game.exe > "$d/log.txt" 2>&1 &
  pid=$!
  shot() { [ -n "$wid" ] && import -window "$wid" "$d/$1.png" 2>/dev/null; }
  wid=$(timeout 20 xdotool search --sync --class OpenGMK 2>/dev/null | head -1)
  echo "window: $wid" >> "$d/lab.txt"
  focus() { [ -n "$wid" ] && xdotool windowfocus "$wid" 2>/dev/null; }
  key() { focus; xdotool key --clearmodifiers "$@" 2>/dev/null; }
  hold() { focus; xdotool keydown "$1"; sleep "$2"; xdotool keyup "$1"; }
  click() { [ -n "$wid" ] && xdotool mousemove --window "$wid" "$1" "$2" mousedown 1 sleep 0.2 mouseup 1 2>/dev/null; }
  sleep 6; shot 01-start
  # each game's PLAY button on its warning screen (centre of the Play object, from the room data)
  case $g in p1) click 320 432;; p3) click 528 393;; tiff) click 448 352;; esac
  sleep 3; shot 02-click-play
  sleep 3; shot 03-after-play
  key Return; sleep 3; shot 04-enter
  key Return; sleep 3; shot 05-enter2
  key space; sleep 2; hold Right 4; shot 06-right
  key space; sleep 1; shot 07-jump
  hold Right 5; key space; sleep 2; shot 08-run
  key Return; sleep 3; shot 09-enter3
  if kill -0 $pid 2>/dev/null; then echo "STILL RUNNING at end" >> "$d/log.txt"; kill $pid; else wait $pid; echo "EXITED code $?" >> "$d/log.txt"; fi
  cd - >/dev/null
  echo "== $g: $(tail -1 "$d/log.txt")"
done
