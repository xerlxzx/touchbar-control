#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
mkdir -p "$project_dir/work"
# This test executable does not link TBHardware.m or IOKit.
xcrun clang -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=12.0 \
    -framework Foundation -I "$project_dir/Sources" \
    "$project_dir/Tests/controller_tests.m" "$project_dir/Sources/TBController.m" \
    "$project_dir/Sources/TBBrightnessState.m" \
    "$project_dir/Sources/TBBrightnessPreference.m" \
    -o "$project_dir/work/controller-tests"
"$project_dir/work/controller-tests"
