#!/usr/bin/env bash
# Builds the app for the iPhone Simulator, runs each game for a bit with scripted key presses,
# and saves screenshots and logs to ios/sim/. Run from ios/.
set -uo pipefail
out=$PWD/sim; mkdir -p "$out"
xcodebuild -project Sunky.xcodeproj -scheme Sunky -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build-sim ARCHS=${SIM_ARCH:-arm64} ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO build > "$out/sim-build.log" 2>&1 || { grep -E "error:" "$out/sim-build.log" | head -30; exit 1; }
app=$PWD/build-sim/Build/Products/Release-iphonesimulator/Sunky.app
codesign --force --sign - --timestamp=none "$app"

rt=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys;r=[x for x in json.load(sys.stdin)["runtimes"] if x["platform"]=="iOS" and x["isAvailable"]];print(r[-1]["identifier"])')
dev=$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys;d=[x for x in json.load(sys.stdin)["devicetypes"] if x["name"].startswith("iPhone")];print(next((x for x in d if x["name"] in ("iPhone 16","iPhone 17","iPhone 15")),d[-1])["identifier"])')
udid=$(xcrun simctl create sunky "$dev" "$rt")
echo "simulator $dev $rt $udid" | tee "$out/sim.md"
xcrun simctl boot "$udid"; sleep 20
xcrun simctl install "$udid" "$app"
# the menu on its own first (landscape)
xcrun simctl launch "$udid" com.duckyisc00l.sunky >/dev/null; sleep 12
xcrun simctl io "$udid" screenshot "$out/menu.png" >/dev/null 2>&1
# and with some games marked finished (launch arguments only; nothing is saved)
xcrun simctl launch --terminate-running-process "$udid" com.duckyisc00l.sunky -finished.p1 YES -finished.mpeg YES -finished.tiff YES >/dev/null; sleep 10
xcrun simctl io "$udid" screenshot "$out/menu-finished.png" >/dev/null 2>&1

# steps: <seconds>:<vk>:<hold seconds>  (13 enter, 32 space, 16 shift, 37 left, 38 up, 39 right, 40 down)
#        <seconds>:gtap:<x>:<y>  tap a game pixel      <seconds>:tap:<fx>:<fy>  tap a fraction of the screen
# The Simulator is slow to start a game, so each tap/key is repeated until the screen it's for has
# surely come up. Then: through the title screens, and running and jumping for a good while.
rep() { # rep <from> <to> <every> <what>  ->  "<t>:<what>,..." for t = from, from+every, ... to
  local t=$1 out=""; while [ "$t" -le "$2" ]; do out="$out$t:$4,"; t=$((t + $3)); done; echo "${out%,}"
}
play_ogmk() { # run right and jump, over and over, from <start>
  local a=${1:-60}
  echo "$(rep $a 140 8 39:5),$(rep $((a + 2)) 140 8 32:0.3),$(rep $((a + 5)) 140 8 32:0.3)"
}
steps_for() {
  case $1 in
    p1)   echo "$(rep 6 21 3 gtap:320:432),$(rep 30 90 3 13:0.3),$(play_ogmk 94)" ;;
    p2)   echo "$(rep 6 15 3 gtap:528:393),$(rep 18 30 4 gtap:320:224),$(rep 36 56 4 13:0.2),$(play_ogmk)" ;;
    p3)   echo "$(rep 6 15 3 gtap:528:393),$(rep 18 30 4 gtap:320:224),$(rep 36 56 4 13:0.2),$(play_ogmk)" ;;
    mpeg) echo "$(rep 6 12 3 13:0.2),$(rep 15 30 3 gtap:113:249),$(rep 36 56 4 13:0.2),$(play_ogmk)" ;;
    tiff) echo "$(rep 6 21 3 gtap:448:352),$(rep 30 56 4 13:0.2),$(play_ogmk)" ;;
    g2)   echo "$(rep 8 32 3 tap:0.5:0.72),$(rep 36 56 4 13:0.2),$(rep 60 140 8 39:5),$(rep 62 140 8 16:0.3),$(rep 65 140 8 16:0.3)" ;;
  esac
}
answer_for() { case $1 in p2) echo SUNK ;; p3) echo FINAL ;; *) echo OK ;; esac; }
for g in ${SIM_GAMES:-p1 p2 p3 mpeg tiff g2}; do
  keys=$(steps_for "$g")
  xcrun simctl launch --terminate-running-process "$udid" com.duckyisc00l.sunky -sunkyAutoplay "$g" -sunkyAutoKeys "$keys" -sunkyDialogAnswer "$(answer_for "$g")" >/dev/null
  start=$(date +%s)  # screenshots on the clock (taking one is slow, so plain sleeps drift)
  for t in 10 20 30 40 50 60 70 80 90 100 110 120 130 140; do
    while [ $(( $(date +%s) - start )) -lt $t ]; do sleep 1; done
    xcrun simctl io "$udid" screenshot "$out/$g-$t.png" >/dev/null 2>&1
  done
  prev=0
  running=$(xcrun simctl spawn "$udid" launchctl list | grep -c "UIKitApplication:com.duckyisc00l.sunky" || true)
  data=$(xcrun simctl get_app_container "$udid" com.duckyisc00l.sunky data)
  cp "$data/Documents/log.txt" "$out/$g-log.txt" 2>/dev/null
  echo "- $g: running at end: $running; last log lines:" >> "$out/sim.md"
  tail -5 "$out/$g-log.txt" 2>/dev/null | sed 's/^/    /' >> "$out/sim.md"
  ls ~/Library/Logs/DiagnosticReports/ 2>/dev/null | grep -i sunky | head -3 | sed 's/^/    crash report: /' >> "$out/sim.md"
done
xcrun simctl terminate "$udid" com.duckyisc00l.sunky 2>/dev/null
cp ~/Library/Logs/DiagnosticReports/Sunky* "$out/" 2>/dev/null
# shrink screenshots
for f in "$out"/*.png; do sips -Z 900 "$f" >/dev/null 2>&1; done
cat "$out/sim.md"
