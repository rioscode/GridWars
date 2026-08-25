#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 ORIGINAL-CAPTURE-DIRECTORY SWIFT-CAPTURE-DIRECTORY OUTPUT-DIRECTORY" >&2
  exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required (the 'magick' command was not found)." >&2
  exit 1
fi

original_dir=$1
swift_dir=$2
output_dir=$3

if [ -e "$output_dir" ]; then
  echo "Output directory already exists: $output_dir" >&2
  exit 1
fi

if [ -f /System/Library/Fonts/Helvetica.ttc ]; then
  review_font=/System/Library/Fonts/Helvetica.ttc
elif [ -f /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf ]; then
  review_font=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
else
  echo "No supported review font was found." >&2
  exit 1
fi

mkdir "$output_dir"
count=0
page=0
set --

make_page() {
  page=$((page + 1))
  page_serial=$(printf '%02d' "$page")
  magick montage -font "$review_font" "$@" \
    -tile 3x3 -geometry +8+8 -background '#080808' \
    "$output_dir/page-$page_serial.png"
}

LC_ALL=C
export LC_ALL
for original_path in "$original_dir"/*.png; do
  original_name=${original_path##*/}
  original_name=${original_name%.png}
  swift_name=$original_name
  case "$original_name" in
    title-600) swift_name=title ;;
    scores-600) swift_name=scores ;;
    friends-600) swift_name=friends ;;
    enemies-600) swift_name=enemies ;;
    options-20) swift_name=options ;;
  esac

  swift_path="$swift_dir/$swift_name.png"
  if [ ! -f "$swift_path" ]; then
    echo "Missing Swift capture: $swift_path" >&2
    exit 1
  fi

  count=$((count + 1))
  serial=$(printf '%03d' "$count")
  tile="$output_dir/tile-$serial.png"
  magick "$original_path" "$swift_path" \
    -resize '400x300!' +append \
    -background '#202020' -fill white -gravity north -splice 0x34 \
    -font "$review_font" -pointsize 20 \
    -annotate +0+6 "$swift_name — Original | Swift" \
    "$tile"
  set -- "$@" "$tile"

  if [ $((count % 9)) -eq 0 ]; then
    make_page "$@"
    set --
  fi
done

if [ "$#" -gt 0 ]; then
  make_page "$@"
fi

printf 'Created %d paired tiles across %d review pages in %s\n' \
  "$count" "$page" "$output_dir"
