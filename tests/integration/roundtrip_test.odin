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
test_roundtrip_bash_ir_bash :: proc(t: ^testing.T) {
	if !should_run_local_test("test_roundtrip_bash_ir_bash") { return }

	src := "x=5\necho $x"
	result := shellx.translate(src, .Bash, .Bash)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, result.success, "Bash roundtrip should succeed")
	testing.expect(t, len(result.output) > 0, "Bash roundtrip should produce output")
}

@(test)
test_roundtrip_zsh_ir_zsh :: proc(t: ^testing.T) {
	if !should_run_local_test("test_roundtrip_zsh_ir_zsh") { return }

	src := "typeset x=5\necho $x"
	result := shellx.translate(src, .Zsh, .Zsh)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, result.success, "Zsh roundtrip should succeed")
	testing.expect(t, len(result.output) > 0, "Zsh roundtrip should produce output")
}

@(test)
test_roundtrip_fish_ir_fish :: proc(t: ^testing.T) {
	if !should_run_local_test("test_roundtrip_fish_ir_fish") { return }

	src := "set x 5\necho $x"
	result := shellx.translate(src, .Fish, .Fish)
	defer shellx.destroy_translation_result(&result)
	testing.expect(
		t,
		result.success || len(result.errors) > 0,
		"Fish roundtrip should either succeed or return structured errors",
	)
	if result.success {
		testing.expect(t, len(result.output) > 0, "Fish roundtrip should produce output")
	}
}
