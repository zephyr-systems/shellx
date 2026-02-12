#!/usr/bin/env bash
set -euo pipefail

ODIN_BIN="${ODIN_BIN:-odin}"
SHELLX_TEST_PATH="${SHELLX_TEST_PATH:-.}"
SHELLX_TEST_ALL_PACKAGES="${SHELLX_TEST_ALL_PACKAGES:-1}"
SHELLX_TEST_VERBOSE="${SHELLX_TEST_VERBOSE:-0}"
SHELLX_TEST_NAME="${SHELLX_TEST_NAME:-}"
SHELLX_TEST_INCLUDE_EDGE_CASES="${SHELLX_TEST_INCLUDE_EDGE_CASES:-1}"
SHELLX_EDGE_CASES_TEST_FILE="${SHELLX_EDGE_CASES_TEST_FILE:-tests/unit/edge_cases_test.odin}"
SHELLX_TEST_EXTENDED="${SHELLX_TEST_EXTENDED:-0}"

base_flags=()
if [[ "$SHELLX_TEST_VERBOSE" == "1" ]]; then
	base_flags+=("-v")
fi

define_flag=()
if [[ -n "$SHELLX_TEST_NAME" ]]; then
	escaped_test_name="${SHELLX_TEST_NAME//\"/\\\"}"
	define_flag=("-define:SHELLX_TEST_NAME=\"${escaped_test_name}\"")
fi

cmd=("$ODIN_BIN" "test" "$SHELLX_TEST_PATH")
if [[ "$SHELLX_TEST_ALL_PACKAGES" == "1" ]]; then
	cmd+=("-all-packages")
fi
cmd+=("${base_flags[@]}")
cmd+=("${define_flag[@]}")

echo "Running: ${cmd[*]}"
"${cmd[@]}"

if [[ "$SHELLX_TEST_INCLUDE_EDGE_CASES" == "1" ]]; then
	edge_cmd=("$ODIN_BIN" "test" "$SHELLX_EDGE_CASES_TEST_FILE" "-file")
	edge_cmd+=("${base_flags[@]}")
	edge_cmd+=("${define_flag[@]}")
	echo "Running: ${edge_cmd[*]}"
	"${edge_cmd[@]}"
fi

if [[ "$SHELLX_TEST_EXTENDED" == "1" ]]; then
	extended_files=(
		"tests/unit/ir_test.odin"
		"tests/unit/backend_test.odin"
		"tests/unit/optimizer_test.odin"
		"tests/unit/detection_test.odin"
		"tests/unit/frontend_test.odin"
		"tests/unit/compatibility_extra_test.odin"
		"tests/integration/roundtrip_test.odin"
		"tests/integration/error_handling_test.odin"
		"tests/integration/options_test.odin"
	)

	for test_file in "${extended_files[@]}"; do
		extended_cmd=("$ODIN_BIN" "test" "$test_file" "-file")
		if [[ -n "$SHELLX_TEST_NAME" ]]; then
			extended_cmd+=("-define:LOCAL_SHELLX_TEST_NAME=\"${escaped_test_name}\"")
		fi
		echo "Running: ${extended_cmd[*]}"
		"${extended_cmd[@]}"
	done
fi
