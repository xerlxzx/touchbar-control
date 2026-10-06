#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
mkdir -p "$project_dir/work"
# Cached service ownership and invalidation use fake IOKit functions only.
xcrun clang -O2 -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=12.0 \
    -framework Foundation -I "$project_dir/Sources" \
    "$project_dir/Tests/service_cache_tests.m" -o "$project_dir/work/service-cache-tests"
"$project_dir/work/service-cache-tests"
# The wake API boundary is exercised using fake Objective-C clients only.
xcrun clang -O2 -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=12.0 \
    -framework Foundation -I "$project_dir/Sources" \
    "$project_dir/Tests/wake_tests.m" "$project_dir/Sources/TBWakeRequest.m" \
    -o "$project_dir/work/wake-tests"
"$project_dir/work/wake-tests"
# This test executable does not link TBHardware.m or IOKit.
xcrun clang -O2 -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=12.0 \
    -framework Foundation -I "$project_dir/Sources" \
    "$project_dir/Tests/controller_tests.m" "$project_dir/Sources/TBController.m" \
    "$project_dir/Sources/TBBrightnessState.m" \
    "$project_dir/Sources/TBBrightnessPreference.m" \
    -o "$project_dir/work/controller-tests"
"$project_dir/work/controller-tests"
# App lifecycle tests compile the real delegate with preview hardware and aborting
# TBRealHardware stubs; no private frameworks or device provider are linked.
xcrun clang -O2 -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=12.0 \
    -framework Cocoa -framework ServiceManagement -I "$project_dir/Sources" \
    "$project_dir/Tests/app_tests.m" "$project_dir/Sources/TBController.m" \
    "$project_dir/Sources/TBBrightnessState.m" "$project_dir/Sources/TBBrightnessPreference.m" \
    "$project_dir/Sources/TBLoginItem.m" \
    -o "$project_dir/work/app-tests"
"$project_dir/work/app-tests"
