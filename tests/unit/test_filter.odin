package unit_tests

import "core:strings"

SHELLX_TEST_NAME :: #config(SHELLX_TEST_NAME, "")

should_run_test :: proc(name: string) -> bool {
	if SHELLX_TEST_NAME == "" {
		return true
	}
	return strings.contains(name, SHELLX_TEST_NAME)
}
