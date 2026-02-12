package integration_tests

import "backend"
import "core:testing"
import "frontend"
import "ir"

@(test)
test_fish_to_zsh_set :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_to_zsh_set") { return }
	fish_code := "set x 5"
	result := translate_code(fish_code, .Fish, .Zsh)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_fish_to_zsh_set_global :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_to_zsh_set_global") { return }
	fish_code := "set -g name \"value\""
	result := translate_code(fish_code, .Fish, .Zsh)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_fish_to_zsh_function :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_to_zsh_function") { return }
	fish_code := "function hello\n\techo Hello\nend"
	result := translate_code(fish_code, .Fish, .Zsh)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_fish_to_zsh_list :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_to_zsh_list") { return }
	fish_code := "set arr one two three"
	result := translate_code(fish_code, .Fish, .Zsh)
	defer delete(result)

	// Zsh should convert list to array
	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_fish_to_zsh_if_statement :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_to_zsh_if_statement") { return }
	fish_code := "if test $x -eq 5\n\techo yes\nend"
	result := translate_code(fish_code, .Fish, .Zsh)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}
