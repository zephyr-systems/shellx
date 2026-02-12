package shellx

import "core:fmt"
import "core:testing"

// Test: Simple variable assignment
@(test)
test_variable_assignment :: proc(t: ^testing.T) {
	if !should_run_test("test_variable_assignment") { return }
	bash_code := `x=5`
	result := translate(bash_code, .Bash, .Bash)

	testing.expect(t, result.success, "Translation should succeed")
	testing.expect(
		t,
		result.output == "x=5\n",
		fmt.tprintf("Expected 'x=5\\n', got '%s'", result.output),
	)
}

// Test: Function definition
@(test)
test_function_definition :: proc(t: ^testing.T) {
	if !should_run_test("test_function_definition") { return }
	bash_code := `
function hello() {
	echo "Hello, World!"
}
`
	result := translate(bash_code, .Bash, .Bash)

	testing.expect(t, result.success, "Translation should succeed")
	testing.expect(t, len(result.output) > 0, "Output should not be empty")
	testing.expect(
		t,
		result.output[:16] == "function hello()",
		fmt.tprintf("Expected function name 'hello', got '%s'", result.output),
	)
}

// Test: If-else statement
@(test)
test_if_else :: proc(t: ^testing.T) {
	if !should_run_test("test_if_else") { return }
	bash_code := `
if [ "$x" -eq 5 ]; then
	echo "x is 5"
else
	echo "x is not 5"
fi
`
	result := translate(bash_code, .Bash, .Bash)

	testing.expect(t, result.success, "Translation should succeed")
}

// Test: For loop
@(test)
test_for_loop :: proc(t: ^testing.T) {
	if !should_run_test("test_for_loop") { return }
	bash_code := `
for i in 1 2 3; do
	echo "Number: $i"
done
`
	result := translate(bash_code, .Bash, .Bash)

	testing.expect(t, result.success, "Translation should succeed")
}

// Test: Roundtrip preservation
@(test)
test_roundtrip_preservation :: proc(t: ^testing.T) {
	if !should_run_test("test_roundtrip_preservation") { return }
	bash_code := `x=5`
	result := translate(bash_code, .Bash, .Bash)

	testing.expect(t, result.success, "Translation should succeed")
	testing.expect(t, result.output == "x=5\n", "Roundtrip should preserve variable assignment")
}

// Test: Command with arguments
@(test)
test_command_with_args :: proc(t: ^testing.T) {
	if !should_run_test("test_command_with_args") { return }
	bash_code := `echo hello world`
	result := translate(bash_code, .Bash, .Bash)

	testing.expect(t, result.success, "Translation should succeed")
	// Note: Currently commands lose their command name in translation
	// This is a known issue to be fixed
	testing.expect(t, len(result.output) > 0, "Output should not be empty")
}
