#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
if [ "$#" -ne 1 ] || [[ "$1" != *.icns ]]; then
    printf 'Usage: %s output.icns\n' "$0" >&2
    exit 2
fi
mkdir -p "$project_dir/work" "$(dirname -- "$1")"
staging_dir="$(mktemp -d "$project_dir/work/icon.XXXXXX")"
trap 'rm -rf -- "$staging_dir"' EXIT
iconset_dir="$staging_dir/AppIcon.iconset"
mkdir -p "$iconset_dir"
for size in 16 32 128 256 512; do
    /usr/bin/sips -z "$size" "$size" "$project_dir/Resources/AppIcon.png" \
        --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    /usr/bin/sips -z "$retina_size" "$retina_size" "$project_dir/Resources/AppIcon.png" \
        --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil --convert icns --output "$1" "$iconset_dir"
