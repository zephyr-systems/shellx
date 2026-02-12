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
test_ir_validation_valid_program :: proc(t: ^testing.T) {
	if !should_run_local_test("test_ir_validation_valid_program") { return }

	arena := ir.create_arena(1024 * 16)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Fish)
	err := ir.validate_program(program)
	testing.expect(t, err.error == .None, "Valid empty program should pass validation")
}

@(test)
test_ir_validation_duplicate_function_names :: proc(t: ^testing.T) {
	if !should_run_local_test("test_ir_validation_duplicate_function_names") { return }

	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Bash)
	ir.add_function(program, ir.create_function(&arena, "dup", ir.SourceLocation{line = 1}))
	ir.add_function(program, ir.create_function(&arena, "dup", ir.SourceLocation{line = 2}))

	err := ir.validate_program(program)
	testing.expect(t, err.error == .DuplicateFunction, "Duplicate function names should fail validation")
	testing.expect(t, err.rule == "function.name.unique", "Rule should identify duplicate function constraint")
	testing.expect(t, err.location.line == 2, "Error location should point to duplicate declaration")
}

@(test)
test_ir_validation_logical_arity :: proc(t: ^testing.T) {
	if !should_run_local_test("test_ir_validation_logical_arity") { return }

	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Bash)
	stmt := ir.Statement{
		type = .Logical,
		logical = ir.LogicalChain{
			segments = make([dynamic]ir.LogicalSegment, 0, 2, context.temp_allocator),
			operators = make([dynamic]ir.LogicalOperator, 0, 0, context.temp_allocator),
			location = ir.SourceLocation{line = 4},
		},
		location = ir.SourceLocation{line = 4},
	}
	append(&stmt.logical.segments, ir.LogicalSegment{
		call = ir.Call{
			function = ir.new_variable(&arena, "echo"),
			arguments = make([dynamic]ir.Expression, 0, 1, context.temp_allocator),
			location = ir.SourceLocation{line = 4},
		},
	})
	append(&stmt.logical.segments, ir.LogicalSegment{
		call = ir.Call{
			function = ir.new_variable(&arena, "echo"),
			arguments = make([dynamic]ir.Expression, 0, 1, context.temp_allocator),
			location = ir.SourceLocation{line = 4},
		},
	})
	ir.add_statement(program, stmt)

	err := ir.validate_program(program)
	testing.expect(t, err.error == .InvalidControlFlow, "Mismatched logical operator arity should fail validation")
	testing.expect(t, err.rule == "logical.operators.arity", "Rule should identify operator arity mismatch")
}

@(test)
test_ir_validation_missing_call_function :: proc(t: ^testing.T) {
	if !should_run_local_test("test_ir_validation_missing_call_function") { return }

	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Bash)
	stmt := ir.Statement{
		type = .Call,
		call = ir.Call{
			function = nil,
			arguments = make([dynamic]ir.Expression, 0, 1, context.temp_allocator),
			location = ir.SourceLocation{line = 7},
		},
		location = ir.SourceLocation{line = 7},
	}
	ir.add_statement(program, stmt)

	err := ir.validate_program(program)
	testing.expect(t, err.error == .UndefinedVariable, "Call without command target should fail validation")
	testing.expect(t, err.rule == "call.function.non_nil", "Rule should identify missing call function")
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
