package integration_tests

import "backend"
import "core:testing"
import "frontend"
import "ir"

@(test)
test_fish_to_bash_set :: proc(t: ^testing.T) {
	fish_code := "set x 5"
	result := translate_code(fish_code, .Fish, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_fish_to_bash_function :: proc(t: ^testing.T) {
	fish_code := "function hello\n\techo Hello\nend"
	result := translate_code(fish_code, .Fish, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_fish_to_bash_if_statement :: proc(t: ^testing.T) {
	fish_code := "if test $x -eq 5\n\techo yes\nend"
	result := translate_code(fish_code, .Fish, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_fish_to_bash_for_loop :: proc(t: ^testing.T) {
	fish_code := "for i in 1 2 3\n\techo $i\nend"
	result := translate_code(fish_code, .Fish, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_fish_to_bash_list :: proc(t: ^testing.T) {
	fish_code := "set arr one two three"
	result := translate_code(fish_code, .Fish, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}
