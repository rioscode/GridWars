#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
derived_data="$repo_dir/.build/DerivedData"

xcodebuild \
  -project "$repo_dir/GridWars.xcodeproj" \
  -scheme GridWars-macOS \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build

exec "$derived_data/Build/Products/Debug/GridWars.app/Contents/MacOS/GridWars"
