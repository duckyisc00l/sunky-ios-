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

# steps: <seconds>:<vk>:<hold seconds>  (13 enter, 32 space, 16 shift, 37 left, 38 up, 39 right, 40 down)
#        <seconds>:gtap:<x>:<y>  tap a game pixel      <seconds>:tap:<fx>:<fy>  tap a fraction of the screen
# Each game: tap its PLAY button on the warning screen, then start, then run right and jump.
steps_for() {
  local run="12:13:0.2,15:13:0.2,18:32:0.2,19:39:5,22:32:0.3,25:39:4,27:32:0.3"
  case $1 in
    p1)   echo "6:gtap:320:432,$run" ;;
    p2|p3) echo "6:gtap:528:393,$run" ;;
    tiff) echo "6:gtap:448:352,$run" ;;
    mpeg) echo "6:13:0.2,9:13:0.2,$run" ;;
    g2)   echo "7:tap:0.5:0.72,8:tap:0.47:0.7,12:13:0.2,15:13:0.2,18:16:0.2,19:39:5,22:16:0.3,25:39:4,27:16:0.3" ;;
  esac
}
for g in ${SIM_GAMES:-p1 p2 p3 mpeg tiff g2}; do
  keys=$(steps_for "$g")
  xcrun simctl launch --terminate-running-process "$udid" com.duckyisc00l.sunky -sunkyAutoplay "$g" -sunkyAutoKeys "$keys" >/dev/null
  for t in 5 10 16 22 30 36; do
    sleep $(( t - ${prev:-0} )); prev=$t
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
