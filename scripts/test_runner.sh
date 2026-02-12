#!/usr/bin/env bash
set -euo pipefail

ODIN_BIN="${ODIN_BIN:-odin}"
SHELLX_TEST_PATH="${SHELLX_TEST_PATH:-.}"
SHELLX_TEST_ALL_PACKAGES="${SHELLX_TEST_ALL_PACKAGES:-1}"
SHELLX_TEST_VERBOSE="${SHELLX_TEST_VERBOSE:-0}"
SHELLX_TEST_NAME="${SHELLX_TEST_NAME:-}"

cmd=("$ODIN_BIN" "test" "$SHELLX_TEST_PATH")

if [[ "$SHELLX_TEST_ALL_PACKAGES" == "1" ]]; then
	cmd+=("-all-packages")
fi

if [[ "$SHELLX_TEST_VERBOSE" == "1" ]]; then
	cmd+=("-v")
fi

if [[ -n "$SHELLX_TEST_NAME" ]]; then
	escaped_test_name="${SHELLX_TEST_NAME//\"/\\\"}"
	cmd+=("-define:SHELLX_TEST_NAME=\"${escaped_test_name}\"")
fi

echo "Running: ${cmd[*]}"
exec "${cmd[@]}"
