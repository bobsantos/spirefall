#!/usr/bin/env bash
# Run GdUnit4 tests. Pass a test file path as argument, or omit to run all tests.
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_PATH="${1:-tests/}"

"$GODOT_BIN" --headless --path "$PROJECT_DIR" \
  -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add "$TEST_PATH" \
  --ignoreHeadlessMode
