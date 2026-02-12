package integration_tests

import "backend"
import "core:testing"
import "frontend"
import "ir"

@(test)
test_zsh_to_fish_variable :: proc(t: ^testing.T) {
	zsh_code := "x=5"
	result := translate_code(zsh_code, .Zsh, .Fish)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_fish_typeset :: proc(t: ^testing.T) {
	zsh_code := "typeset x=5"
	result := translate_code(zsh_code, .Zsh, .Fish)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_fish_function :: proc(t: ^testing.T) {
	zsh_code := "function hello() {\n\techo Hello\n}"
	result := translate_code(zsh_code, .Zsh, .Fish)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_fish_array :: proc(t: ^testing.T) {
	zsh_code := "arr=(one two three)"
	result := translate_code(zsh_code, .Zsh, .Fish)
	defer delete(result)

	// Fish should convert array to list
	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_fish_if_statement :: proc(t: ^testing.T) {
	zsh_code := "if [[ $x -eq 5 ]]; then\n\techo yes\nfi"
	result := translate_code(zsh_code, .Zsh, .Fish)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}
