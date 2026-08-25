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

capture() {
  screen="$1"
  "$app" \
    --capture-screen "$screen" \
    --capture-output "$capture_dir/$screen.png"
}

for screen in \
  title scores friends enemies gameplay \
  get-ready-title get-ready-rings death game-over high-score-entry \
  hud-default hud-upgraded power-up-message \
  enemy-pinwheel enemy-diamond enemy-green-square enemy-cube enemy-seeker \
  enemy-black-hole enemy-triangle enemy-snake enemy-interceptor enemy-butterfly \
  motion-pinwheel motion-diamond motion-green-square motion-cube motion-seeker \
  motion-butterfly \
  generator-pinwheel generator-diamond generator-green-square generator-cube \
  generator-seeker generator-black-hole generator-triangle generator-snake \
  generator-interceptor generator-butterfly \
  powerup-reverse powerup-side powerup-cannon powerup-faster powerup-player \
  powerup-bomb powerup-shield powerup-super powerup-bouncy \
  particle-0 particle-1 particle-2 particle-3 \
  graphics-solid graphics-low graphics-medium graphics-high graphics-user \
  options options-game confirm-exit confirm-end-game confirm-keep-video \
  confirm-keep-game settings video game audio controller hybrid mouse keyboard \
  joypad dual-analog; do
  capture "$screen"
done

for grid in \
  00 01 02 03 04 05 06 07 08 09 10 \
  11 12 13 14 15 16 17 18 19 20; do
  capture "grid-$grid"
done

find "$capture_dir" -type f -name '*.png' -print | LC_ALL=C sort | xargs shasum -a 256 > "$capture_dir/SHA256SUMS"
