package integration_tests

import shellx "../.."
import "core:strings"
import "core:testing"

LOCAL_SHELLX_TEST_NAME :: #config(LOCAL_SHELLX_TEST_NAME, "")

should_run_local_test :: proc(name: string) -> bool {
	if LOCAL_SHELLX_TEST_NAME == "" {
		return true
	}
	return strings.contains(name, LOCAL_SHELLX_TEST_NAME)
}

@(test)
test_options_strict_mode_integration :: proc(t: ^testing.T) {
	if !should_run_local_test("test_options_strict_mode_integration") { return }

	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.strict_mode = true

	result := shellx.translate("echo hello", .Bash, .Fish, opts)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, !result.success, "Strict mode should fail on Bash->Fish compatibility errors")
}

@(test)
test_options_insert_shims_integration :: proc(t: ^testing.T) {
	if !should_run_local_test("test_options_insert_shims_integration") { return }

	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true

	result := shellx.translate("echo hello", .Bash, .Fish, opts)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, len(result.required_shims) > 0, "Insert shims should collect required shims")
}

@(test)
test_options_optimization_level_integration :: proc(t: ^testing.T) {
	if !should_run_local_test("test_options_optimization_level_integration") { return }

	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.optimization_level = .Aggressive

	result := shellx.translate("x=1\ny=1\n", .Bash, .Bash, opts)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, result.success, "Aggressive optimization path should run")
}
