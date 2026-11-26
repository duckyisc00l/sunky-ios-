#!/usr/bin/env bash
# Puts Sunky the Game 2's side art next to its data.win, named for the screens (rooms) it belongs to.
# The art was drawn for widescreen: new curtain fabric, palm silhouettes and the title's glow.
# The engine only uses a file while its screen is showing (the colours where it meets the picture
# must match). Usage: ci/sunky2_sides/install.sh <folder with data.win>
set -e
here=$(dirname "$0"); to=$1
cp "$here/warning.png" "$to/sunky_side_rm_logo.png"      # the WARNING screen after the HELLO splash
cp "$here/warning.png" "$to/sunky_side_room19.png"       # the WARNING card is shown here too (then LOONEY DUDE PRESENTS: black sides)
cp "$here/warning.need" "$to/sunky_side_room19.png.need"
cp "$here/warning.need" "$to/sunky_side_rm_logo.png.need"
cp "$here/black.png"   "$to/sunky_side_room18.png"
cp "$here/title.png"   "$to/sunky_side_rm_title.png"     # the SUNKY THE GAME 2 title
cp "$here/curtain.png" "$to/sunky_side_Curtain.png"      # the curtain screen
cp "$here/hello.png"   "$to/sunky_side_hello.png"         # the HELLO splash's purple, for its last frame as the game moves on
# every screen's art, tried in turn while the game swaps screens (it briefly shows the last one)
printf '%s\n' sunky_side_rm_title.png sunky_side_Curtain.png sunky_side_hello.png > "$to/sunky_side_all.txt"
