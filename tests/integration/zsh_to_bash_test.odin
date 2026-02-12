package integration_tests

import "backend"
import "core:testing"
import "core:strings"
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

@(test)
test_zsh_to_bash_logical_chain :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_logical_chain") { return }
	zsh_code := "foo && ! bar || baz"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, strings.contains(result, "&&"), "Should preserve AND operator")
	testing.expect(t, strings.contains(result, "||"), "Should preserve OR operator")
	testing.expect(t, strings.contains(result, "! bar"), "Should preserve negation")
}
