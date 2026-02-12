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
test_parse_error_handling_integration :: proc(t: ^testing.T) {
	if !should_run_local_test("test_parse_error_handling_integration") { return }

	bad := "if [ ; then\necho hi\n"
	result := shellx.translate(bad, .Bash, .Zsh)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, !result.success, "Malformed code should not translate cleanly")
	testing.expect(t, len(result.errors) > 0, "Malformed code should include error contexts")
}

@(test)
test_conversion_error_path_integration :: proc(t: ^testing.T) {
	if !should_run_local_test("test_conversion_error_path_integration") { return }

	result := shellx.translate_file("/tmp/definitely_missing_shellx_script.sh", .Bash, .Bash)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, !result.success, "Missing file should fail translation")
	testing.expect(t, result.error == .IOError, "Missing file should produce IOError")
}
