#!/usr/bin/env bash
# Puts Sunky the Game 2's side art next to its data.win, named for the screens (rooms) it belongs to.
# The art was drawn for widescreen (see ci/sunky2_sides): new curtain fabric, palm silhouettes and
# the title's glow. Usage: ci/sunky2_sides/install.sh <folder with data.win>
set -e
here=$(dirname "$0"); to=$1
cp "$here/warning.png" "$to/sunky_side_rm_logo.png"      # the WARNING screen after the HELLO splash
cp "$here/title.png"   "$to/sunky_side_room18.png"       # the SUNKY THE GAME 2 title
cp "$here/curtain.png" "$to/sunky_side_rm_title.png"     # the curtain screen
cp "$here/curtain.png" "$to/sunky_side_Curtain.png"
