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
  if [ -n "${ROOM_LIST:-}" ]; then rooms=$(echo "$ROOM_LIST" | tr ' ,' '\n\n' | sed -n "s/^$g://p")
  elif [ -n "${ALL_ROOMS:-}" ]; then rooms=$(grep -E "^ROOM [0-9]+ " "$info/$g/summary.txt" | awk '{print $2}')
  else rooms=$(grep -E "^ROOM [0-9]+ .* views true" "$info/$g/summary.txt" | awk '{print $2}'); fi
  for r in $rooms; do
    run=$(mktemp -d); cp "$exe" "$run/game.exe"
    ( cd "$run" && SUNKY_LAB_TRACE=1 SUNKY_START_ROOM=$r exec timeout -s KILL 17 "$emu" game.exe > "$out/$g-$r.log" 2>&1 ) &
    start=$(date +%s)
    wid=$(timeout 10 xdotool search --sync --class OpenGMK 2>/dev/null | head -1)
    # PLAY=1: also play the room (hold right, jump now and then, press Enter once)
    if [ -n "${PLAY:-}" ] && [ -n "$wid" ]; then
      ( sleep 1.5; timeout 2 xdotool key --window "$wid" Return; sleep 0.5
        timeout 2 xdotool keydown --window "$wid" Right
        for j in 1 2 3 4 5 6; do sleep 1; timeout 2 xdotool key --window "$wid" space; done
        timeout 2 xdotool keyup --window "$wid" Right ) &
    fi
    for t in 1 3 6 10; do
      while [ $(( $(date +%s) - start )) -lt $t ]; do sleep 0.2; done
      [ -n "$wid" ] && timeout 4 import -window "$wid" "$out/$g-$r-$t.png" 2>/dev/null
    done
    pkill -KILL -f gm8emulator 2>/dev/null; wait 2>/dev/null; rm -rf "$run"
    # wait for the old window to be gone, or the next room finds it and gets no shots
    for k in $(seq 1 25); do [ -z "$(xdotool search --class OpenGMK 2>/dev/null)" ] && break; sleep 0.2; done
    echo "$g room $r: $(ls "$out"/$g-$r-*.png 2>/dev/null | wc -l) shots; $(grep -m1 -iE 'panic|error' "$out/$g-$r.log" | cut -c1-120)"
  done
done
