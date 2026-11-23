#!/usr/bin/env bash
# Makes one single-game IPA per game from the all-in-one Sunky.app. Run from ios/ on the Mac.
# Usage: ../ci/split.sh <path to Sunky.app> <out dir>
set -euo pipefail
src=$1; out=$2; mkdir -p "$out"
work=$(mktemp -d)
while IFS='|' read -r file name; do
  [ -z "$file" ] && continue
  [ -f "$src/Games/$file.exe" ] || { echo "skip $file (not in app)"; continue; }
  d=$work/$file; mkdir -p "$d/Payload"; cp -R "$src" "$d/Payload/Sunky.app"; app=$d/Payload/Sunky.app
  find "$app/Games" -type f ! -name "$file.exe" ! -name "$file.png" -delete
  pl=$app/Info.plist
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.duckyisc00l.sunky.$file" "$pl"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $name" "$pl"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $name" "$pl"
  /usr/libexec/PlistBuddy -c "Add :SunkyOnly string $file" "$pl"
  # its own icon, from the game's icon
  ic=$work/icons-$file/Assets.xcassets; mkdir -p "$ic/AppIcon.appiconset"
  echo '{"info":{"author":"xcode","version":1}}' > "$ic/Contents.json"
  /tmp/venv/bin/python ../ci/icons.py --single "$app/Games/$file.png" "$ic/AppIcon.appiconset"
  rm -f "$app"/AppIcon*.png "$app/Assets.car"
  xcrun actool "$ic" --compile "$app" --platform iphoneos --minimum-deployment-target 14.0 \
    --app-icon AppIcon --target-device iphone --target-device ipad \
    --output-partial-info-plist "$work/partial-$file.plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIcons" "$pl" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIcons~ipad" "$pl" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Merge $work/partial-$file.plist" "$pl"
  plutil -convert xml1 "$pl"
  (cd "$d" && zip -qry "$out/$(echo "$name" | tr -d ' .')".ipa Payload)
  echo "made $name: $(du -h "$out/$(echo "$name" | tr -d ' .')".ipa | cut -f1)"
done <<'LIST'
p1|Sunky 1
p2|Sunky 2
p3|Sunky 3
mpeg|Sunky.MPEG
tiff|Silly.TIFF
LIST
