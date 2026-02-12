package integration_tests

import "backend"
import "core:testing"
import "frontend"
import "ir"

@(test)
test_bash_to_fish_variable :: proc(t: ^testing.T) {
	if !should_run_test("test_bash_to_fish_variable") { return }
	bash_code := "x=5"
	result := translate_code(bash_code, .Bash, .Fish)
	defer delete(result)

	// Fish should convert to 'set x 5'
	testing.expect(t, result == "set x 5\n", "Variable assignment should convert to set")
}

@(test)
test_bash_to_fish_function :: proc(t: ^testing.T) {
	if !should_run_test("test_bash_to_fish_function") { return }
	bash_code := `function hello() {
	echo "Hello, World!"
}`
	result := translate_code(bash_code, .Bash, .Fish)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_bash_to_fish_if_statement :: proc(t: ^testing.T) {
	if !should_run_test("test_bash_to_fish_if_statement") { return }
	bash_code := `if [ "$x" = "5" ]; then
	echo "x is 5"
fi`
	result := translate_code(bash_code, .Bash, .Fish)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_bash_to_fish_for_loop :: proc(t: ^testing.T) {
	if !should_run_test("test_bash_to_fish_for_loop") { return }
	bash_code := `for i in 1 2 3; do
	echo $i
done`
	result := translate_code(bash_code, .Bash, .Fish)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_bash_to_fish_while_loop :: proc(t: ^testing.T) {
	if !should_run_test("test_bash_to_fish_while_loop") { return }
	bash_code := `while [ $x -lt 10 ]; do
	echo $x
done`
	result := translate_code(bash_code, .Bash, .Fish)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_bash_to_fish_pipeline :: proc(t: ^testing.T) {
	if !should_run_test("test_bash_to_fish_pipeline") { return }
	bash_code := "echo 'hello' | grep 'h' | wc -l"
	result := translate_code(bash_code, .Bash, .Fish)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}
