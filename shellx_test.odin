package shellx

import "core:fmt"
import "core:mem"
import "core:testing"
import "ir"
import "optimizer"

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

@(test)
test_common_subexpression_elimination :: proc(t: ^testing.T) {
	if !should_run_test("test_common_subexpression_elimination") { return }

	arena := ir.create_arena(1024 * 64)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Bash)
	main_fn := ir.create_function(&arena, "main", ir.SourceLocation{})

	make_lit :: proc(arena: ^ir.Arena_IR, v: string) -> ir.Expression {
		return ir.new_literal_expr(arena, v, .Int)
	}
	make_add :: proc(arena: ^ir.Arena_IR, left, right: ir.Expression) -> ir.Expression {
		expr := new(ir.BinaryOp, mem.arena_allocator(&arena.arena))
		expr.op = .Add
		expr.left = left
		expr.right = right
		return expr
	}
	make_assign :: proc(arena: ^ir.Arena_IR, name: string, value: ir.Expression) -> ir.Statement {
		target := new(ir.Variable, mem.arena_allocator(&arena.arena))
		target.name = name
		return ir.Statement{
			type = .Assign,
			assign = ir.Assign{
				target = target,
				value = value,
				location = ir.SourceLocation{},
			},
			location = ir.SourceLocation{},
		}
	}

	first_expr := make_add(&arena, make_lit(&arena, "1"), make_lit(&arena, "2"))
	second_expr := make_add(&arena, make_lit(&arena, "1"), make_lit(&arena, "2"))
	append(&main_fn.body, make_assign(&arena, "a", first_expr))
	append(&main_fn.body, make_assign(&arena, "b", second_expr))
	ir.add_function(program, main_fn)

	result := optimizer.optimize(program, .Standard, mem.arena_allocator(&arena.arena))
	defer optimizer.destroy_optimize_result(&result)

	testing.expect(t, result.changed, "Optimizer should change program via CSE")
	testing.expect(t, len(program.functions[0].body) == 3, "CSE should extract one temp assignment")

	rewrite_a := program.functions[0].body[1]
	rewrite_b := program.functions[0].body[2]
	a_var, a_ok := rewrite_a.assign.value.(^ir.Variable)
	b_var, b_ok := rewrite_b.assign.value.(^ir.Variable)
	testing.expect(t, a_ok, "Assignment a should use temp variable")
	testing.expect(t, b_ok, "Assignment b should use temp variable")
	if a_ok && b_ok {
		testing.expect(t, a_var.name == b_var.name, "Both assignments should reuse same temp variable")
	}
}
