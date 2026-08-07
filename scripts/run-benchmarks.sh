#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly PROJECT_ROOT="${SCRIPT_DIR:h}"
readonly BENCHMARK_BINARY="${PROJECT_ROOT}/.build/release/TildeBenchmark"
readonly EDITOR_SIZES=(10240 102400 1048576 5242880 10485760 52428800 104857600)
readonly MARKDOWN_SIZES=(1048576 5242880 10485760)

cd "${PROJECT_ROOT}"
swift build -c release --product TildeBenchmark

print "environment_key,value"
"${BENCHMARK_BINARY}" environment

print "editor_bytes,encoding,line_count,longest_line_utf16,open_ms,typing_p50_ms,typing_p95_ms,cursor_p95_ms,find_ms,save_ms,open_rss_mb,peak_rss_mb,saved_bytes"
for byte_count in "${EDITOR_SIZES[@]}"; do
  "${BENCHMARK_BINARY}" editor "${byte_count}"
done

print "markdown_bytes,app_textual_ms,quicklook_swift_markdown_ms,quicklook_output_bytes,peak_rss_mb"
for byte_count in "${MARKDOWN_SIZES[@]}"; do
  "${BENCHMARK_BINARY}" markdown "${byte_count}"
done
