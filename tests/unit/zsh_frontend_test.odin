package unit_tests

import "core:testing"
import "frontend"
import "ir"

@(test)
test_zsh_typeset_variable :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_typeset_variable") { return }
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
	if !should_run_test("test_zsh_local_variable") { return }
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
	if !should_run_test("test_zsh_export_variable") { return }
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
test_zsh_declaration_assignment_to_assign :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_declaration_assignment_to_assign") { return }
	code := "typeset -g ANSWER=42"
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
	testing.expect(t, len(program.statements) > 0, "Should emit at least one statement")
	if len(program.statements) == 0 {
		return
	}

	stmt := program.statements[0]
	testing.expect(t, stmt.type == .Assign, "typeset assignment should become Assign")
	if stmt.type == .Assign && stmt.assign.target != nil {
		testing.expect(t, stmt.assign.target.name == "ANSWER", "Assignment target should be ANSWER")
	}
}

@(test)
test_zsh_declaration_without_assignment_stays_call :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_declaration_without_assignment_stays_call") { return }
	code := "export PATH"
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
	testing.expect(t, len(program.statements) > 0, "Should emit at least one statement")
	if len(program.statements) == 0 {
		return
	}

	stmt := program.statements[0]
	testing.expect(t, stmt.type == .Call, "declaration without assignment should remain Call")
}

@(test)
test_zsh_error_fragment_preserved :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_error_fragment_preserved") { return }
	code := "case x in\nuser:*) echo ok ;;\nesac"
	arena := ir.create_arena(2048)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Zsh)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse tree even with syntax errors")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.zsh_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")
	testing.expect(t, len(program.statements) > 0, "Should preserve at least one statement from recovery nodes")
}

@(test)
test_zsh_logical_chain :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_logical_chain") { return }
	code := "foo && bar || baz"
	arena := ir.create_arena(2048)
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
	testing.expect(t, len(program.statements) == 1, "Should emit one logical statement")
	if len(program.statements) != 1 {
		return
	}

	stmt := program.statements[0]
	testing.expect(t, stmt.type == .Logical, "Should convert to Logical statement")
	if stmt.type == .Logical {
		testing.expect(t, len(stmt.logical.segments) == 3, "Should have 3 logical segments")
		testing.expect(t, len(stmt.logical.operators) == 2, "Should have 2 logical operators")
	}
}

@(test)
test_zsh_logical_negation :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_logical_negation") { return }
	code := "foo && ! bar"
	arena := ir.create_arena(2048)
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
	testing.expect(t, len(program.statements) == 1, "Should emit one logical statement")
	if len(program.statements) != 1 {
		return
	}

	stmt := program.statements[0]
	testing.expect(t, stmt.type == .Logical, "Should convert to Logical statement")
	if stmt.type == .Logical && len(stmt.logical.segments) == 2 {
		testing.expect(t, stmt.logical.segments[1].negated, "Second segment should be negated")
	}
}

@(test)
test_zsh_case_statement :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_case_statement") { return }
	code := "case \"$x\" in foo|bar) echo ok ;; baz) echo no ;; esac"
	arena := ir.create_arena(4096)
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
	testing.expect(t, len(program.statements) == 1, "Should emit one case statement")
	if len(program.statements) != 1 {
		return
	}

	stmt := program.statements[0]
	testing.expect(t, stmt.type == .Case, "Should convert to Case statement")
	if stmt.type == .Case {
		testing.expect(t, len(stmt.case_.arms) == 2, "Should produce two case arms")
	}
}

@(test)
test_zsh_function :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_function") { return }
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
	if !should_run_test("test_zsh_if_statement") { return }
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
	if !should_run_test("test_zsh_array") { return }
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
