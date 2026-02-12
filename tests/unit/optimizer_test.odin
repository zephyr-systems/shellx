package unit_tests

import "core:mem"
import "core:strings"
import "core:testing"
import "../../ir"
import "../../optimizer"

LOCAL_SHELLX_TEST_NAME :: #config(LOCAL_SHELLX_TEST_NAME, "")

should_run_local_test :: proc(name: string) -> bool {
	if LOCAL_SHELLX_TEST_NAME == "" {
		return true
	}
	return strings.contains(name, LOCAL_SHELLX_TEST_NAME)
}

make_assign_int :: proc(arena: ^ir.Arena_IR, name, value: string) -> ir.Statement {
	return ir.stmt_assign(arena, name, ir.expr_int(arena, value))
}

make_binary_add :: proc(arena: ^ir.Arena_IR, left, right: string) -> ir.Expression {
	a := ir.expr_int(arena, left)
	b := ir.expr_int(arena, right)
	op := new(ir.BinaryOp, mem.arena_allocator(&arena.arena))
	op.op = .Add
	op.left = a
	op.right = b
	return op
}

make_call_stmt :: proc(
	arena: ^ir.Arena_IR,
	command: string,
	args: ..string,
) -> ir.Statement {
	call := ir.Call{
		function = ir.new_variable(arena, command),
		arguments = make([dynamic]ir.Expression, 0, len(args), mem.arena_allocator(&arena.arena)),
	}
	for arg in args {
		append(&call.arguments, ir.expr_string(arena, arg))
	}
	return ir.Statement{type = .Call, call = call}
}

make_pipeline_stmt :: proc(
	arena: ^ir.Arena_IR,
	left_command: string,
	left_args: []string,
	right_command: string,
	right_args: []string,
) -> ir.Statement {
	left := ir.Call{
		function = ir.new_variable(arena, left_command),
		arguments = make([dynamic]ir.Expression, 0, len(left_args), mem.arena_allocator(&arena.arena)),
	}
	for arg in left_args {
		append(&left.arguments, ir.expr_string(arena, arg))
	}

	right := ir.Call{
		function = ir.new_variable(arena, right_command),
		arguments = make([dynamic]ir.Expression, 0, len(right_args), mem.arena_allocator(&arena.arena)),
	}
	for arg in right_args {
		append(&right.arguments, ir.expr_string(arena, arg))
	}

	pipeline := ir.Pipeline{commands = make([dynamic]ir.Call, 0, 2, mem.arena_allocator(&arena.arena))}
	append(&pipeline.commands, left)
	append(&pipeline.commands, right)

	return ir.Statement{type = .Pipeline, pipeline = pipeline}
}

@(test)
test_optimizer_constant_folding :: proc(t: ^testing.T) {
	if !should_run_local_test("test_optimizer_constant_folding") { return }

	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Bash)
	fn := ir.create_function(&arena, "main", ir.SourceLocation{})
	append(&fn.body, ir.stmt_assign(&arena, "x", make_binary_add(&arena, "2", "3")))
	ir.add_function(program, fn)

	res := optimizer.constant_folding(program)
	defer optimizer.destroy_optimize_result(&res)

	testing.expect(t, res.changed, "Constant folding should change program")
	lit, ok := program.functions[0].body[0].assign.value.(^ir.Literal)
	testing.expect(t, ok, "Folded value should become literal")
	if ok {
		testing.expect(t, lit.value == "5", "2 + 3 should fold to 5")
	}
}

@(test)
test_optimizer_dead_code_elimination :: proc(t: ^testing.T) {
	if !should_run_local_test("test_optimizer_dead_code_elimination") { return }

	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Bash)
	fn := ir.create_function(&arena, "main", ir.SourceLocation{})
	append(&fn.body, ir.stmt_return(ir.expr_int(&arena, "0")))
	append(&fn.body, make_assign_int(&arena, "x", "9"))
	ir.add_function(program, fn)

	res := optimizer.dead_code_elimination(program)
	defer optimizer.destroy_optimize_result(&res)

	testing.expect(t, res.changed, "DCE should remove unreachable statement")
	testing.expect(t, len(program.functions[0].body) == 1, "Function body should be reduced to 1 stmt")
}

@(test)
test_optimizer_pipeline_simplification :: proc(t: ^testing.T) {
	if !should_run_local_test("test_optimizer_pipeline_simplification") { return }

	arena := ir.create_arena(1024 * 64)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Bash)
	fn := ir.create_function(&arena, "main", ir.SourceLocation{})

	echo_call := ir.Call{function = ir.new_variable(&arena, "echo"), arguments = make([dynamic]ir.Expression, mem.arena_allocator(&arena.arena))}
	append(&echo_call.arguments, ir.expr_string(&arena, "hello"))
	cat_call := ir.Call{function = ir.new_variable(&arena, "cat"), arguments = make([dynamic]ir.Expression, mem.arena_allocator(&arena.arena))}
	pipeline := ir.Pipeline{commands = make([dynamic]ir.Call, mem.arena_allocator(&arena.arena))}
	append(&pipeline.commands, echo_call)
	append(&pipeline.commands, cat_call)
	append(&fn.body, ir.Statement{type = .Pipeline, pipeline = pipeline})
	ir.add_function(program, fn)

	res := optimizer.pipeline_simplification(program)
	defer optimizer.destroy_optimize_result(&res)

	testing.expect(t, res.changed, "Pipeline simplification should simplify echo|cat")
	testing.expect(t, program.functions[0].body[0].type == .Call, "Pipeline should become call")
}

@(test)
test_optimizer_pipeline_simplification_sort_uniq :: proc(t: ^testing.T) {
	if !should_run_local_test("test_optimizer_pipeline_simplification_sort_uniq") { return }

	arena := ir.create_arena(1024 * 64)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Bash)
	fn := ir.create_function(&arena, "main", ir.SourceLocation{})
	append(&fn.body, make_pipeline_stmt(&arena, "sort", []string{}, "uniq", []string{}))
	ir.add_function(program, fn)

	res := optimizer.pipeline_simplification(program)
	defer optimizer.destroy_optimize_result(&res)

	testing.expect(t, res.changed, "sort|uniq should simplify")
	if optimizer.metrics_enabled() {
		testing.expect(t, res.metrics.forks_eliminated >= 1, "sort|uniq should save at least one fork")
		testing.expect(
			t,
			res.metrics.patterns_applied["sort_uniq_to_sort_u"] == 1,
			"Metrics should track sort|uniq optimization",
		)
	}
	testing.expect(t, program.functions[0].body[0].type == .Call, "Pipeline should become call")
	if program.functions[0].body[0].type == .Call {
		call := program.functions[0].body[0].call
		testing.expect(t, call.function != nil && call.function.name == "sort", "Call should remain sort")
		testing.expect(t, len(call.arguments) > 0, "sort call should gain arguments")
		if len(call.arguments) > 0 {
			testing.expect(t, ir.expr_to_string(call.arguments[0]) == "-u", "sort should receive -u")
		}
	}
}

@(test)
test_optimizer_pipeline_simplification_grep_wc_count :: proc(t: ^testing.T) {
	if !should_run_local_test("test_optimizer_pipeline_simplification_grep_wc_count") { return }

	arena := ir.create_arena(1024 * 64)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Bash)
	fn := ir.create_function(&arena, "main", ir.SourceLocation{})
	append(&fn.body, make_pipeline_stmt(&arena, "grep", []string{"needle", "file.txt"}, "wc", []string{"-l"}))
	ir.add_function(program, fn)

	res := optimizer.pipeline_simplification(program)
	defer optimizer.destroy_optimize_result(&res)

	testing.expect(t, res.changed, "grep|wc -l should simplify")
	if optimizer.metrics_enabled() {
		testing.expect(t, res.metrics.forks_eliminated >= 1, "grep|wc should save at least one fork")
		testing.expect(
			t,
			res.metrics.patterns_applied["grep_wc_count_to_grep_c"] == 1,
			"Metrics should track grep|wc optimization",
		)
	}
	testing.expect(t, program.functions[0].body[0].type == .Call, "Pipeline should become call")
	if program.functions[0].body[0].type == .Call {
		call := program.functions[0].body[0].call
		testing.expect(t, call.function != nil && call.function.name == "grep", "Call should remain grep")
		testing.expect(t, len(call.arguments) > 0, "grep call should gain arguments")
		if len(call.arguments) > 0 {
			testing.expect(t, ir.expr_to_string(call.arguments[0]) == "-c", "grep should receive -c")
		}
	}
}

@(test)
test_optimizer_pipeline_simplification_tee_devnull :: proc(t: ^testing.T) {
	if !should_run_local_test("test_optimizer_pipeline_simplification_tee_devnull") { return }

	arena := ir.create_arena(1024 * 64)
	defer ir.destroy_arena(&arena)

	program := ir.create_program(&arena, .Bash)
	fn := ir.create_function(&arena, "main", ir.SourceLocation{})
	append(&fn.body, make_pipeline_stmt(&arena, "echo", []string{"ok"}, "tee", []string{"/dev/null"}))
	ir.add_function(program, fn)

	res := optimizer.pipeline_simplification(program)
	defer optimizer.destroy_optimize_result(&res)

	testing.expect(t, res.changed, "cmd|tee /dev/null should simplify")
	if optimizer.metrics_enabled() {
		testing.expect(
			t,
			res.metrics.patterns_applied["tee_devnull_elision"] == 1,
			"Metrics should track tee /dev/null optimization",
		)
	}
	testing.expect(t, program.functions[0].body[0].type == .Call, "Pipeline should become call")
}

@(test)
test_optimizer_metrics_aggregated_in_optimize :: proc(t: ^testing.T) {
	if !should_run_local_test("test_optimizer_metrics_aggregated_in_optimize") { return }

	arena := ir.create_arena(1024 * 64)
	defer ir.destroy_arena(&arena)
	program := ir.create_program(&arena, .Bash)
	fn := ir.create_function(&arena, "main", ir.SourceLocation{})
	append(&fn.body, make_pipeline_stmt(&arena, "sort", []string{}, "uniq", []string{}))
	append(&fn.body, make_pipeline_stmt(&arena, "echo", []string{"ok"}, "tee", []string{"/dev/null"}))
	ir.add_function(program, fn)

	res := optimizer.optimize(program, .Standard)
	defer optimizer.destroy_optimize_result(&res)

	testing.expect(t, res.changed, "Standard optimize should apply pipeline simplifications")
	if optimizer.metrics_enabled() {
		testing.expect(t, res.metrics.forks_eliminated >= 2, "Aggregate metrics should include fork savings")
		testing.expect(t, len(res.metrics.patterns_applied) >= 1, "Aggregate metrics should include applied patterns")
	}
}

@(test)
test_optimizer_levels_dispatch :: proc(t: ^testing.T) {
	if !should_run_local_test("test_optimizer_levels_dispatch") { return }

	arena := ir.create_arena(1024 * 64)
	defer ir.destroy_arena(&arena)
	program := ir.create_program(&arena, .Bash)
	main_fn := ir.create_function(&arena, "main", ir.SourceLocation{})
	append(&main_fn.body, make_assign_int(&arena, "x", "1"))
	ir.add_function(program, main_fn)

	levels := [4]optimizer.OptimizationLevel{.None, .Basic, .Standard, .Aggressive}
	for level in levels {
		res := optimizer.optimize(program, level)
		optimizer.destroy_optimize_result(&res)
	}

	testing.expect(t, true, "All optimization levels should execute")
}
