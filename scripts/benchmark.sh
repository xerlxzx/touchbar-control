#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
if [ "$#" -gt 2 ]; then
    printf 'Usage: %s [baseline-git-ref] [paired-runs]\n' "$0" >&2
    exit 2
fi
baseline_ref="${1:-HEAD}"
runs="${2:-5}"
if ! [[ "$runs" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Paired runs must be a positive integer.\n' >&2
    exit 2
fi
mkdir -p "$project_dir/work"
output_dir="$(mktemp -d "$project_dir/work/benchmark.XXXXXX")"
mkdir -p "$output_dir/baseline"
git -C "$project_dir" archive "$baseline_ref" | tar -x -C "$output_dir/baseline"
compile_benchmark() {
    local source_dir="$1" destination="$2" optimization="$3"
    local sources=() source
    for source in "$source_dir"/Sources/*.m; do
        [[ "$source" == */main.m ]] || sources+=("$source")
    done
    xcrun clang "$optimization" -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=12.0 \
        -framework Cocoa -framework IOKit -framework CoreGraphics -framework ServiceManagement \
        -I "$source_dir/Sources" "$project_dir/Tests/performance_benchmark.m" "${sources[@]}" -o "$destination"
}
# The baseline release build had no optimization flag (Clang's -O0 default).
compile_benchmark "$output_dir/baseline" "$output_dir/before" -O0
compile_benchmark "$project_dir" "$output_dir/after" -O2
for ((run = 1; run <= runs; run++)); do
    if ((run % 2)); then order=(before after); else order=(after before); fi
    for variant in "${order[@]}"; do
        "$output_dir/$variant" >> "$output_dir/$variant.jsonl" 2>> "$output_dir/$variant.log"
        printf 'Completed pair %d/%d: %s\n' "$run" "$runs" "$variant"
    done
done
python3 - "$output_dir" <<'PY'
import json, statistics, sys
from pathlib import Path
folder = Path(sys.argv[1])
samples = {v: [json.loads(line) for line in (folder / f'{v}.jsonl').read_text().splitlines()]
           for v in ('before', 'after')}
summary = {}
for workload in samples['before'][0]:
    metric = 'cpu_us_per_iteration' if workload == 'paced_read_loop' else 'wall_us_per_iteration'
    values = {v: [s[workload][metric] for s in samples[v]] for v in samples}
    medians = {v: statistics.median(values[v]) for v in values}
    change = 100 * (1 - medians['after'] / medians['before'])
    summary[workload] = {'metric': metric, 'before_median': medians['before'],
                         'after_median': medians['after'], 'reduction_percent': change,
                         'before_range': [min(values['before']), max(values['before'])],
                         'after_range': [min(values['after']), max(values['after'])]}
    print(f"{workload:18s} {medians['before']:9.2f} -> {medians['after']:9.2f} us  ({change:+.1f}% reduction)")
(folder / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(f'Raw results and summary: {folder}')
PY
