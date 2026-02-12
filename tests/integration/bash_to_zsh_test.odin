package integration_tests

import "backend"
import "core:testing"
import "detection"
import "frontend"
import "ir"

// Helper function to translate from one dialect to another
translate_code :: proc(
	from_code: string,
	from_dialect: ir.ShellDialect,
	to_dialect: ir.ShellDialect,
	allocator := context.allocator,
) -> string {
	// Create arena for IR
	arena := ir.create_arena(1024 * 1024)
	defer ir.destroy_arena(&arena)

	// Parse the source code
	fe := frontend.create_frontend(from_dialect)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, from_code)
	if parse_err.error != .None {
		return "PARSE_ERROR"
	}
	defer frontend.destroy_tree(tree)

	// Convert to IR
	program: ^ir.Program
	conv_err: frontend.FrontendError

	switch from_dialect {
	case .Bash:
		program, conv_err = frontend.bash_to_ir(&arena, tree, from_code)
	case .Zsh:
		program, conv_err = frontend.zsh_to_ir(&arena, tree, from_code)
	case .Fish:
		program, conv_err = frontend.fish_to_ir(&arena, tree, from_code)
	case:
		return "UNSUPPORTED_DIALECT"
	}

	if conv_err.error != .None {
		return "CONVERSION_ERROR"
	}

	// Emit to target dialect
	result: string
	switch to_dialect {
	case .Bash:
		be := backend.create_backend(.Bash)
		defer backend.destroy_backend(&be)
		result = backend.emit(&be, program, allocator)
	case .Zsh:
		zsh_be := backend.create_zsh_backend()
		defer backend.destroy_zsh_backend(&zsh_be)
		result = backend.emit_zsh(&zsh_be, program)
	case .Fish:
		fish_be := backend.create_fish_backend()
		defer backend.destroy_fish_backend(&fish_be)
		result = backend.emit_fish(&fish_be, program)
	case:
		return "UNSUPPORTED_TARGET"
	}

	return result
}

@(test)
test_bash_to_zsh_variable :: proc(t: ^testing.T) {
	bash_code := "x=5"
	result := translate_code(bash_code, .Bash, .Zsh)
	defer delete(result)

	// Zsh should preserve the simple assignment
	testing.expect(t, result == "x=5\n", "Variable assignment should be preserved")
}

@(test)
test_bash_to_zsh_function :: proc(t: ^testing.T) {
	bash_code := `function hello() {
	echo "Hello, World!"
}`
	result := translate_code(bash_code, .Bash, .Zsh)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
	testing.expect(
		t,
		result[:len("function hello")] == "function hello",
		"Should emit Zsh function",
	)
}

@(test)
test_bash_to_zsh_if_statement :: proc(t: ^testing.T) {
	bash_code := `if [ "$x" = "5" ]; then
	echo "x is 5"
fi`
	result := translate_code(bash_code, .Bash, .Zsh)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_bash_to_zsh_for_loop :: proc(t: ^testing.T) {
	bash_code := `for i in 1 2 3; do
	echo $i
done`
	result := translate_code(bash_code, .Bash, .Zsh)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_bash_to_zsh_while_loop :: proc(t: ^testing.T) {
	bash_code := `while [ $x -lt 10 ]; do
	echo $x
done`
	result := translate_code(bash_code, .Bash, .Zsh)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_bash_to_zsh_pipeline :: proc(t: ^testing.T) {
	bash_code := "echo 'hello' | grep 'h' | wc -l"
	result := translate_code(bash_code, .Bash, .Zsh)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}
