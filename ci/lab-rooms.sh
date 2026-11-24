#!/usr/bin/env bash
# Widescreen sweep: starts each game straight in every room that has a camera (SUNKY_START_ROOM),
# with a phone-shaped screen (SUNKY_WIDE), and takes screenshots over the first seconds, so
# intros, cutscenes and overlays can be checked in widescreen without playing through.
# Usage: ci/lab-rooms.sh <info dir> <out dir> [games...]
set -uo pipefail
info=$(realpath "$1"); out=$(realpath -m "$2"); shift 2
games=${*:-p1 p2 p3 mpeg tiff}
emu=$(realpath "${EMU:-engine/ogmk/target-gles/release/gm8emulator}")
mkdir -p "$out"
for g in $games; do
  exe=$PWD/games/$g.exe; [ -f "$exe" ] || continue
  rooms=$(grep -E "^ROOM [0-9]+ .* views true" "$info/$g/summary.txt" | awk '{print $2}')
  for r in $rooms; do
    run=$(mktemp -d); cp "$exe" "$run/game.exe"
    ( cd "$run" && SUNKY_START_ROOM=$r timeout 14 "$emu" game.exe > "$out/$g-$r.log" 2>&1 ) &
    pid=$!
    wid=$(timeout 10 xdotool search --sync --class OpenGMK 2>/dev/null | head -1)
    for t in 1 3 6 10; do
      sleep $(( t - ${prev:-0} )); prev=$t
      [ -n "$wid" ] && import -window "$wid" "$out/$g-$r-$t.png" 2>/dev/null
    done
    prev=0
    kill $pid 2>/dev/null; wait $pid 2>/dev/null
    echo "$g room $r: $(tail -1 "$out/$g-$r.log" | cut -c1-120)"
  done
done
