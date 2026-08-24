#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 ORIGINAL-CAPTURE-DIRECTORY SWIFT-CAPTURE-DIRECTORY" >&2
  exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required (the 'magick' command was not found)." >&2
  exit 1
fi

original_dir=$1
swift_dir=$2
count=0

compare_capture() {
  original_name=$1
  swift_name=$2
  original_path="$original_dir/$original_name.png"
  swift_path="$swift_dir/$swift_name.png"

  if [ ! -f "$original_path" ] || [ ! -f "$swift_path" ]; then
    echo "Missing capture pair: $original_path / $swift_path" >&2
    exit 1
  fi

  original_size=$(magick identify -format '%wx%h' "$original_path")
  swift_size=$(magick identify -format '%wx%h' "$swift_path")
  if [ "$original_size" != "1024x768" ] || [ "$swift_size" != "1024x768" ]; then
    echo "Unexpected size for $swift_name: original=$original_size swift=$swift_size" >&2
    exit 1
  fi

  difference=$(magick "$original_path" "$swift_path" \
    -compose difference -composite -colorspace Gray \
    -format '%[fx:mean]' info:)
  printf '%s,%s\n' "$swift_name" "$difference"
  count=$((count + 1))
}

echo "capture,normalized_mean_absolute_difference"
compare_capture title-600 title
compare_capture scores-600 scores
compare_capture friends-600 friends
compare_capture enemies-600 enemies
compare_capture options-20 options

LC_ALL=C
export LC_ALL
for original_path in "$original_dir"/*.png; do
  original_name=${original_path##*/}
  original_name=${original_name%.png}
  case "$original_name" in
    title-600|scores-600|friends-600|enemies-600|options-20) continue ;;
  esac
  compare_capture "$original_name" "$original_name"
done

echo "Compared $count capture pairs at 1024x768." >&2
