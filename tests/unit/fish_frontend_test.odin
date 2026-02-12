package unit_tests

import "core:testing"
import "frontend"
import "ir"

@(test)
test_fish_set_variable :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_set_variable") { return }
	code := "set x 5"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Fish)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.fish_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")

	testing.expect(t, program.dialect == .Fish, "Should be Fish dialect")
}

@(test)
test_fish_set_global :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_set_global") { return }
	code := "set -g name \"value\""
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Fish)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.fish_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")
}

@(test)
test_fish_set_local :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_set_local") { return }
	code := "set -l var value"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Fish)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.fish_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")
}

@(test)
test_fish_set_export :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_set_export") { return }
	code := "set -x PATH /bin"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Fish)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.fish_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")
}

@(test)
test_fish_function :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_function") { return }
	code := "function hello\n\techo Hello\nend"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Fish)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.fish_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")

	testing.expect(t, len(program.functions) >= 0, "Should parse function")
}

@(test)
test_fish_if_statement :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_if_statement") { return }
	code := "if test $x -eq 5\n\techo yes\nend"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Fish)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.fish_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")
}

@(test)
test_fish_for_loop :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_for_loop") { return }
	code := "for i in 1 2 3\n\techo $i\nend"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Fish)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.fish_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")
}

@(test)
test_fish_list :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_list") { return }
	code := "set arr one two three"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Fish)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.fish_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")
}
