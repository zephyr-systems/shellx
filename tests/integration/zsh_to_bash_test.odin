package integration_tests

import "backend"
import "core:testing"
import "frontend"
import "ir"

@(test)
test_zsh_to_bash_variable :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_variable") { return }
	zsh_code := "x=5"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_bash_function :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_function") { return }
	zsh_code := "function hello() {\n\techo Hello\n}"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_bash_if_statement :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_if_statement") { return }
	zsh_code := "if [[ $x -eq 5 ]]; then\n\techo yes\nfi"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_bash_array :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_array") { return }
	zsh_code := "arr=(one two three)"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_bash_typeset :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_typeset") { return }
	zsh_code := "typeset x=5"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}
