#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
if [ "$#" -gt 0 ]; then
    printf 'Usage: %s\n' "$0" >&2
    exit 2
fi
mkdir -p "$project_dir/work/releases"
staging_dir="$(mktemp -d "$project_dir/work/package.XXXXXX")"
trap 'rm -rf -- "$staging_dir"' EXIT
app_dir="$staging_dir/Touch Bar Control.app"
"$project_dir/test.sh"
"$project_dir/build.sh" "$app_dir"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_dir/Contents/Info.plist")"
architecture="$(/usr/bin/lipo -archs "$app_dir/Contents/MacOS/Touch Bar Control")"
archive_name="Touch-Bar-Control-$version-$architecture.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$project_dir/work/releases/$archive_name"
(
    cd "$project_dir/work/releases"
    /usr/bin/shasum -a 256 "$archive_name" > "$archive_name.sha256"
)
printf 'Packaged %s/work/releases/%s\n' "$project_dir" "$archive_name"
printf 'Local ad-hoc signature only; this archive is not notarized.\n'
