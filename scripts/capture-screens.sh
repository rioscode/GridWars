#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
derived_data="$repo_dir/.build/DerivedData"
capture_dir="${1:-$repo_dir/docs/captures/swift}"

xcodebuild \
  -project "$repo_dir/GridWars.xcodeproj" \
  -scheme GridWars-macOS \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build

app="$derived_data/Build/Products/Debug/GridWars.app/Contents/MacOS/GridWars"
mkdir -p "$capture_dir"

for screen in title scores friends enemies options gameplay; do
  "$app" \
    --capture-screen "$screen" \
    --capture-output "$capture_dir/$screen.png"
done
