#!/usr/bin/env bash
# Runs each game in OpenGMK under a virtual screen, with screenshots and some key presses.
# Usage: ci/lab.sh <out dir> [games...]
set -uo pipefail
out=$1; shift
games=${*:-p1 p2 p3 mpeg tiff g2}
emu=$PWD/ogmk/target/release/gm8emulator
mkdir -p "$out"
for g in $games; do
  d=$out/$g; mkdir -p "$d"; exe=$PWD/games/$g.exe
  [ "$g" = g2 ] && exe=$(ls $PWD/games/g2x/*.exe 2>/dev/null | head -1)
  [ -f "$exe" ] || { echo "no exe for $g" > "$d/log.txt"; continue; }
  run=$(mktemp -d); cp "$exe" "$run/game.exe"; cd "$run"
  timeout 75 "$emu" game.exe > "$d/log.txt" 2>&1 &
  pid=$!
  shot() { import -window root "$d/$1.png" 2>/dev/null; }
  key() { xdotool key --clearmodifiers "$@" 2>/dev/null; }
  sleep 6; shot 01-start
  sleep 6; shot 02-12s
  key Return; sleep 3; shot 03-enter
  key z; sleep 3; shot 04-z
  key space; sleep 3; shot 05-space
  xdotool keydown Right; sleep 4; shot 06-right; xdotool keyup Right
  key Up; key x; sleep 2; shot 07-jump
  sleep 15; shot 08-late
  if kill -0 $pid 2>/dev/null; then echo "STILL RUNNING at end" >> "$d/log.txt"; kill $pid; else wait $pid; echo "EXITED code $?" >> "$d/log.txt"; fi
  cd - >/dev/null
  for f in "$d"/*.png; do convert "$f" -trim +repage "$f" 2>/dev/null; done
  echo "== $g: $(tail -1 "$d/log.txt")"
done
