#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
backup_label=${1:-milestone}
source_pptx=${2:-"$repo_dir/GridWars_Presentation.pptx"}
backup_dir="$repo_dir/presentation-backups"

if [ ! -f "$source_pptx" ]; then
  echo "Presentation not found: $source_pptx" >&2
  exit 1
fi

safe_label=$(printf '%s' "$backup_label" \
  | tr '[:upper:] ' '[:lower:]_' \
  | tr -cd 'a-z0-9._-')
if [ -z "$safe_label" ]; then
  safe_label=milestone
fi

timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
commit_id=$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || printf 'no-git')
presentation_name=$(basename "$source_pptx" .pptx)
destination="$backup_dir/${presentation_name}_${timestamp}_${safe_label}_${commit_id}.pptx"

mkdir -p "$backup_dir"
if [ -e "$destination" ]; then
  echo "Backup already exists: $destination" >&2
  exit 1
fi

cp -p "$source_pptx" "$destination"
printf '%s\n' "$destination"
