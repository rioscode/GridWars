#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Original captures currently require macOS." >&2
  exit 1
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 /path/to/BlitzMax [output-directory] [capture-name]" >&2
  exit 1
fi

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
blitzmax_root=$1
output_dir=${2:-"$repo_dir/docs/captures/original"}
capture_name=${3:-}
bmk="$blitzmax_root/bin/bmk"

if [ ! -x "$bmk" ]; then
  echo "BlitzMax compiler not found: $bmk" >&2
  exit 1
fi

mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd)
capture_work=$(mktemp -d "${TMPDIR:-/tmp}/gridwars-original-capture.XXXXXX")
trap 'rm -rf -- "$capture_work"' EXIT HUP INT TERM

cp "$repo_dir"/*.bmx "$capture_work/"
cp "$repo_dir/scripts/original-catalog.bmx" "$capture_work/"
cp -R "$repo_dir/gfx" "$repo_dir/music" "$repo_dir/sounds" "$capture_work/"

# BlitzMax NG has a Max2D Rect symbol and rejects the duplicate legacy Linux
# framework selection. These two compatibility edits do not alter rendering.
perl -pi -e 's/\brect\b/LegacyRect/ig' \
  "$capture_work/control.bmx" "$capture_work/utils.bmx"
perl -0pi -e 's/\?Linux\n\?OpenGLES\nFramework SDL\.GL2SDLMax2D\n\?not OpenGLES\nFramework BRL\.GLMax2D\n\?\n/?\n/' \
  "$capture_work/gridwars.bmx"
perl -0pi -e 's/\z/\nInclude "original-catalog.bmx"\n/' \
  "$capture_work/gridwars.bmx"

(
  cd "$capture_work"
  patch -p0 < "$repo_dir/scripts/original-capture.patch"
  perl -0pi -e 's/(^\s*DrawTarget\([^\n]+\)\n)/$1\t\tCaptureOriginalMenuFrame(cnt)\n/gm' \
    control.bmx
  perl -0pi -e 's/(\t\t\tpart\.DrawParticles\(\)\n)(\t\t\tFlip 1)/$1\t\t\tIf captureMode = "high-score-entry"\n\t\t\t\tSaveScreenshot(captureDir+"\/high-score-entry.png")\n\t\t\t\tEnd\n\t\t\tEndIf\n$2/; s/(\t\tUpdateAll\(count\)\n\t\tdrawall\(\)\n)(\t\tFlip)/$1\t\tIf captureMode = "death" And count = 0\n\t\t\tSaveScreenshot(captureDir+"\/death.png")\n\t\t\tEnd\n\t\tEndIf\n$2/' \
    gridwars.bmx
  "$bmk" makeapp -t gui -r -w gridwars.bmx
)

app="$capture_work/gridwars.app"
plist="$app/Contents/Info.plist"
binary="$app/Contents/MacOS/gridwars"

# The 2006 renderer is expressed in logical pixels. Disabling Retina backing
# prevents GrabPixmap from returning only one quadrant of a 2x framebuffer.
/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool false' "$plist"
codesign --force --deep --sign - "$app"

if [ -n "$capture_name" ]; then
  "$binary" "$capture_name" "$output_dir"
else
  for screen in \
    title scores friends enemies options gameplay \
    get-ready-title get-ready-rings death game-over high-score-entry \
    hud-default hud-upgraded power-up-message \
    enemy-pinwheel enemy-diamond enemy-green-square enemy-cube enemy-seeker \
    enemy-black-hole enemy-triangle enemy-snake enemy-interceptor enemy-butterfly \
    motion-pinwheel motion-diamond motion-green-square motion-cube motion-seeker \
    motion-butterfly \
    black-hole-motion black-hole-shrink black-hole-explosion \
    snake-motion snake-tail-hit snake-cascade \
  interceptor-motion interceptor-shield interceptor-block \
  triangle-motion triangle-bond triangle-hit triangle-black-hole \
    player-motion player-boundary player-shield \
    weapon-cannon-1 weapon-cannon-2 weapon-cannon-3 weapon-cannon-4 \
    weapon-reverse-side \
    generator-pinwheel generator-diamond generator-green-square generator-cube \
    generator-seeker generator-black-hole generator-triangle generator-snake \
    generator-interceptor generator-butterfly \
    powerup-reverse powerup-side powerup-cannon powerup-faster powerup-player \
    powerup-bomb powerup-shield powerup-super powerup-bouncy \
    particle-0 particle-1 particle-2 particle-3 \
    graphics-solid graphics-low graphics-medium graphics-high graphics-user \
    options-game confirm-exit confirm-end-game confirm-keep-video \
    confirm-keep-game settings video game audio controller hybrid mouse keyboard \
    joypad dual-analog; do
    "$binary" "$screen" "$output_dir"
  done

  for grid in \
    00 01 02 03 04 05 06 07 08 09 10 \
    11 12 13 14 15 16 17 18 19 20; do
    "$binary" "grid-$grid" "$output_dir"
  done
fi

(
  cd "$output_dir"
  for image in *.png; do
    shasum -a 256 "$image"
  done > SHA256SUMS
)

echo "Original captures written to $output_dir"
