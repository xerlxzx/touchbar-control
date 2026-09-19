#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
if [ "$#" -gt 1 ]; then
    printf 'Usage: %s [output-app-path]\n' "$0" >&2
    exit 2
fi
app_dir="${1:-$project_dir/Touch Bar Control.app}"
if [[ "$app_dir" != *.app ]]; then
    printf 'Output path must end in .app\n' >&2
    exit 2
fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
xcrun clang -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=12.0 \
    -framework Cocoa -framework IOKit -framework CoreGraphics -framework ServiceManagement \
    "$project_dir/Sources/main.m" "$project_dir/Sources/TBHardware.m" \
    "$project_dir/Sources/TBController.m" "$project_dir/Sources/TBBrightnessState.m" \
    "$project_dir/Sources/TBBrightnessPreference.m" \
    "$project_dir/Sources/TBLoginItem.m" \
    -o "$app_dir/Contents/MacOS/Touch Bar Control"
cp "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
"$project_dir/scripts/build-icon.sh" "$app_dir/Contents/Resources/AppIcon.icns"
/usr/bin/plutil -lint "$app_dir/Contents/Info.plist"
/usr/bin/codesign --force --sign - --timestamp=none "$app_dir"
/usr/bin/codesign --verify --strict "$app_dir"
printf 'Built %s\n' "$app_dir"
