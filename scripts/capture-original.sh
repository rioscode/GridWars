#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Original captures currently require macOS." >&2
  exit 1
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 /path/to/BlitzMax [output-directory]" >&2
  exit 1
fi

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
blitzmax_root=$1
output_dir=${2:-"$repo_dir/docs/captures/original"}
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
cp -R "$repo_dir/gfx" "$repo_dir/music" "$repo_dir/sounds" "$capture_work/"

# BlitzMax NG has a Max2D Rect symbol and rejects the duplicate legacy Linux
# framework selection. These two compatibility edits do not alter rendering.
perl -pi -e 's/\brect\b/LegacyRect/ig' \
  "$capture_work/control.bmx" "$capture_work/utils.bmx"
perl -0pi -e 's/\?Linux\n\?OpenGLES\nFramework SDL\.GL2SDLMax2D\n\?not OpenGLES\nFramework BRL\.GLMax2D\n\?\n/?\n/' \
  "$capture_work/gridwars.bmx"

(
  cd "$capture_work"
  patch -p0 < "$repo_dir/scripts/original-capture.patch"
  "$bmk" makeapp -t gui -r -w gridwars.bmx
)

app="$capture_work/gridwars.app"
plist="$app/Contents/Info.plist"
binary="$app/Contents/MacOS/gridwars"

# The 2006 renderer is expressed in logical pixels. Disabling Retina backing
# prevents GrabPixmap from returning only one quadrant of a 2x framebuffer.
/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool false' "$plist"
codesign --force --deep --sign - "$app"

for screen in title scores friends enemies options; do
  "$binary" "$screen" "$output_dir"
done

echo "Original captures written to $output_dir"
