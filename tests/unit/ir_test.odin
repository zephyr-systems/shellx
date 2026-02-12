package unit_tests

import "core:strings"
import "core:testing"
import "../../ir"

LOCAL_SHELLX_TEST_NAME :: #config(LOCAL_SHELLX_TEST_NAME, "")

should_run_local_test :: proc(name: string) -> bool {
	if LOCAL_SHELLX_TEST_NAME == "" {
		return true
	}
	return strings.contains(name, LOCAL_SHELLX_TEST_NAME)
}

@(test)
test_ir_builders_and_helpers :: proc(t: ^testing.T) {
	if !should_run_local_test("test_ir_builders_and_helpers") { return }

	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Bash)
	stmt_assign := ir.stmt_assign(&arena, "x", ir.expr_int(&arena, "42"))
	stmt_call := ir.stmt_call(&arena, "echo", ir.expr_string(&arena, "hello"))
	ir.add_statement(program, stmt_assign)
	ir.add_statement(program, stmt_call)

	testing.expect(t, program.dialect == .Bash, "Program dialect should be Bash")
	testing.expect(t, len(program.statements) == 2, "Program should contain two statements")
	testing.expect(t, program.statements[0].type == .Assign, "First statement should be assign")
	testing.expect(t, program.statements[1].type == .Call, "Second statement should be call")
}

@(test)
test_ir_function_construction :: proc(t: ^testing.T) {
	if !should_run_local_test("test_ir_function_construction") { return }

	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Zsh)
	fn := ir.create_function(&arena, "main", ir.SourceLocation{line = 1, column = 0})
	append(&fn.body, ir.stmt_return(ir.expr_bool(&arena, true)))
	ir.add_function(program, fn)

	testing.expect(t, len(program.functions) == 1, "Program should contain one function")
	testing.expect(t, program.functions[0].name == "main", "Function should be named main")
	testing.expect(t, len(program.functions[0].body) == 1, "Function should contain one statement")
	testing.expect(t, program.functions[0].body[0].type == .Return, "Statement should be return")
}

@(test)
test_ir_validation_placeholder :: proc(t: ^testing.T) {
	if !should_run_local_test("test_ir_validation_placeholder") { return }

	arena := ir.create_arena(1024 * 16)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Fish)
	err := ir.validate_program(program)
	testing.expect(t, err.error == .None, "Validator placeholder should return no error")
}

@(test)
test_ir_string_interning_in_builder :: proc(t: ^testing.T) {
	if !should_run_local_test("test_ir_string_interning_in_builder") { return }

	arena := ir.create_arena(1024 * 16)
	defer ir.destroy_arena(&arena)

	s1 := ir.intern_string(&arena, "alpha")
	s2 := ir.intern_string(&arena, "alpha")
	testing.expect(t, raw_data(s1) == raw_data(s2), "Interned strings should share storage")
}
