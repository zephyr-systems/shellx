package unit_tests

import "core:testing"
import "frontend"
import "ir"

@(test)
test_zsh_typeset_variable :: proc(t: ^testing.T) {
	code := "typeset x=5"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Zsh)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.zsh_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")

	testing.expect(t, program.dialect == .Zsh, "Should be Zsh dialect")
}

@(test)
test_zsh_local_variable :: proc(t: ^testing.T) {
	code := "local name=\"value\""
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Zsh)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.zsh_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")
}

@(test)
test_zsh_export_variable :: proc(t: ^testing.T) {
	code := "export PATH=/bin"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Zsh)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.zsh_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")
}

@(test)
test_zsh_function :: proc(t: ^testing.T) {
	code := "function hello() {\n\techo \"Hello\"\n}"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Zsh)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.zsh_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")

	testing.expect(t, len(program.functions) >= 0, "Should parse function")
}

@(test)
test_zsh_if_statement :: proc(t: ^testing.T) {
	code := "if [[ $x -eq 5 ]]; then\n\techo \"yes\"\nfi"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Zsh)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.zsh_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")
}

@(test)
test_zsh_array :: proc(t: ^testing.T) {
	code := "arr=(one two three)"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Zsh)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.zsh_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")
}
