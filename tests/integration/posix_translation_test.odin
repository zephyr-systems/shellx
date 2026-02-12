package integration_tests

import "core:testing"

@(test)
test_posix_to_bash_variable :: proc(t: ^testing.T) {
	if !should_run_test("test_posix_to_bash_variable") { return }
	posix_code := "x=5"
	result := translate_code(posix_code, .POSIX, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "POSIX to Bash should produce output")
}

@(test)
test_bash_to_posix_variable :: proc(t: ^testing.T) {
	if !should_run_test("test_bash_to_posix_variable") { return }
	bash_code := "x=5"
	result := translate_code(bash_code, .Bash, .POSIX)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Bash to POSIX should produce output")
}

@(test)
test_posix_to_fish_simple_call :: proc(t: ^testing.T) {
	if !should_run_test("test_posix_to_fish_simple_call") { return }
	posix_code := "echo hello"
	result := translate_code(posix_code, .POSIX, .Fish)
	defer delete(result)

	testing.expect(t, len(result) > 0, "POSIX to Fish should produce output")
}
