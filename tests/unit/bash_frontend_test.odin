package unit_tests

import "core:testing"
import "frontend"
import "frontend/common"
import "ir"

@(test)
test_bash_simple_variable :: proc(t: ^testing.T) {
	code := "x=5"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Bash)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.bash_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")

	// Verify program structure
	testing.expect(t, program.dialect == .Bash, "Should be Bash dialect")
	testing.expect(t, len(program.statements) == 1, "Should have 1 statement")

	// Verify the assignment
	stmt := program.statements[0]
	testing.expect(t, stmt.type == .Assign, "Should be assignment")
	testing.expect(t, stmt.assign.target != nil, "Assignment target should exist")
	if stmt.assign.target != nil {
		testing.expect(t, stmt.assign.target.name == "x", "Variable should be 'x'")
	}
	testing.expect(t, ir.expr_to_string(stmt.assign.value) == "5", "Value should be '5'")
}

@(test)
test_bash_function :: proc(t: ^testing.T) {
	code := `function hello() {
	echo "Hello, World!"
}`
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Bash)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.bash_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")

	// Verify function
	testing.expect(t, len(program.functions) == 1, "Should have 1 function")
	func := program.functions[0]
	testing.expect(t, func.name == "hello", "Function name should be 'hello'")
	testing.expect(t, len(func.body) == 1, "Function body should have 1 statement")

	// Verify the echo command
	stmt := func.body[0]
	testing.expect(t, stmt.type == .Call, "Should be function call")
	testing.expect(t, stmt.call.function != nil, "Function should be present")
	if stmt.call.function != nil {
		testing.expect(t, stmt.call.function.name == "echo", "Command should be 'echo'")
	}
}

@(test)
test_bash_if_statement :: proc(t: ^testing.T) {
	code := `if [ "$x" = "5" ]; then
	echo "x is 5"
fi`
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Bash)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.bash_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")

	// Verify the if statement
	testing.expect(t, len(program.statements) == 1, "Should have 1 statement")
	stmt := program.statements[0]
	testing.expect(t, stmt.type == .Branch, "Should be branch (if)")
}

@(test)
test_bash_for_loop :: proc(t: ^testing.T) {
	code := `for i in 1 2 3; do
	echo $i
done`
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Bash)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.bash_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")

	// Verify the for loop
	testing.expect(t, len(program.statements) == 1, "Should have 1 statement")
	stmt := program.statements[0]
	testing.expect(t, stmt.type == .Loop, "Should be loop")
}

@(test)
test_bash_while_loop :: proc(t: ^testing.T) {
	code := `while [ $x -lt 10 ]; do
	echo $x
	x=$((x + 1))
done`
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Bash)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.bash_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")

	// Verify the while loop
	testing.expect(t, len(program.statements) == 1, "Should have 1 statement")
	stmt := program.statements[0]
	testing.expect(t, stmt.type == .Loop, "Should be loop")
}

@(test)
test_bash_pipeline :: proc(t: ^testing.T) {
	code := "echo 'hello' | grep 'h' | wc -l"
	arena := ir.create_arena(1024)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Bash)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Should parse successfully")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.bash_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Should convert to IR")

	// Verify pipeline exists (will be in statements or as call)
	testing.expect(t, len(program.statements) > 0, "Should have statements")
}
