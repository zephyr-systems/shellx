package shellx

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:testing"
import "frontend"
import "ir"
import "optimizer"

// Test: Simple variable assignment
@(test)
test_variable_assignment :: proc(t: ^testing.T) {
	if !should_run_test("test_variable_assignment") { return }
	bash_code := `x=5`
	result := translate(bash_code, .Bash, .Bash)
	defer destroy_translation_result(&result)

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
	defer destroy_translation_result(&result)

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
	defer destroy_translation_result(&result)

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
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Translation should succeed")
}

// Test: Roundtrip preservation
@(test)
test_roundtrip_preservation :: proc(t: ^testing.T) {
	if !should_run_test("test_roundtrip_preservation") { return }
	bash_code := `x=5`
	result := translate(bash_code, .Bash, .Bash)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Translation should succeed")
	testing.expect(t, result.output == "x=5\n", "Roundtrip should preserve variable assignment")
}

// Test: Command with arguments
@(test)
test_command_with_args :: proc(t: ^testing.T) {
	if !should_run_test("test_command_with_args") { return }
	bash_code := `echo hello world`
	result := translate(bash_code, .Bash, .Bash)
	defer destroy_translation_result(&result)

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

@(test)
test_error_context_generation :: proc(t: ^testing.T) {
	if !should_run_test("test_error_context_generation") { return }
	result := translate(`echo "unterminated`, .Bash, .Bash)
	defer destroy_translation_result(&result)
	testing.expect(t, !result.success, "Malformed input should fail")
	testing.expect(t, result.error == .ParseSyntaxError, "Error code should be specific")
	testing.expect(t, len(result.errors) > 0, "Error contexts should be populated")
	if len(result.errors) > 0 {
		testing.expect(
			t,
			result.errors[0].suggestion != "",
			"Error context should contain a suggestion",
		)
	}
}

@(test)
test_report_error_formatting :: proc(t: ^testing.T) {
	if !should_run_test("test_report_error_formatting") { return }
	ctx := ErrorContext{
		error = .ParseSyntaxError,
		message = "Unexpected token",
		location = ir.SourceLocation{
			file = "script.sh",
			line = 2,
			column = 4,
			length = 1,
		},
		suggestion = "Remove or escape the token",
	}
	report := report_error(ctx, "echo one\necho @two\n")
	testing.expect(t, strings.contains(report, "script.sh:2:5"), "Report should include location")
	testing.expect(t, strings.contains(report, "echo @two"), "Report should include snippet")
	testing.expect(t, strings.contains(report, "Suggestion:"), "Report should include suggestion")
}

@(test)
test_multiple_parse_errors_collected :: proc(t: ^testing.T) {
	if !should_run_test("test_multiple_parse_errors_collected") { return }
	code := "if [ ; then\nfor in ; do\necho hi\n"
	result := translate(code, .Bash, .Bash)
	defer destroy_translation_result(&result)
	testing.expect(t, len(result.errors) > 0, "Malformed input should produce parse diagnostics")

	parse_error_count := 0
	for err_ctx in result.errors {
		if err_ctx.error == .ParseSyntaxError {
			parse_error_count += 1
		}
	}
	testing.expect(
		t,
		parse_error_count >= 1,
		"At least one parse syntax error should be collected",
	)
}

@(test)
test_ir_string_interning :: proc(t: ^testing.T) {
	if !should_run_test("test_ir_string_interning") { return }
	arena := ir.create_arena(1024 * 16)
	defer ir.destroy_arena(&arena)

	a := strings.clone("var_x", context.temp_allocator)
	b := strings.clone("var_x", context.temp_allocator)
	i1 := ir.intern_string(&arena, a)
	i2 := ir.intern_string(&arena, b)

	testing.expect(t, raw_data(i1) == raw_data(i2), "Interned strings should share storage")
}

@(test)
test_frontend_uses_interned_variable_names :: proc(t: ^testing.T) {
	if !should_run_test("test_frontend_uses_interned_variable_names") { return }

	code := "x=1\nx=2"
	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(.Bash)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Parsing should succeed")
	if parse_err.error != .None {
		return
	}
	defer frontend.destroy_tree(tree)

	program, conv_err := frontend.bash_to_ir(&arena, tree, code)
	testing.expect(t, conv_err.error == .None, "Conversion should succeed")
	if conv_err.error != .None || len(program.statements) < 2 {
		return
	}

	first := program.statements[0].assign.target
	second := program.statements[1].assign.target
	testing.expect(t, first != nil && second != nil, "Assignments should have targets")
	if first != nil && second != nil {
		testing.expect(
			t,
			raw_data(first.name) == raw_data(second.name),
			"Repeated variable names should reuse interned string storage",
		)
	}
}

@(test)
test_detect_shell_from_path_api :: proc(t: ^testing.T) {
	if !should_run_test("test_detect_shell_from_path_api") { return }

	detected := detect_shell_from_path("script.zsh", "echo hello")
	testing.expect(t, detected == .Zsh, "Expected .Zsh from .zsh extension")
}

@(test)
test_translate_strict_mode_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_strict_mode_api") { return }

	options := DEFAULT_TRANSLATION_OPTIONS
	options.strict_mode = true

	result := translate("echo hello", .Bash, .Fish, options)
	defer destroy_translation_result(&result)

	testing.expect(t, !result.success, "Strict mode should fail on compatibility errors")
	testing.expect(t, result.error == .ValidationError, "Strict mode should surface validation error")
}

@(test)
test_translate_file_and_batch_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_file_and_batch_api") { return }

	test_file := "/tmp/shellx_api_translate_file_test.sh"
	content := "x=5\n"
	ok := os.write_entire_file(test_file, transmute([]byte)content)
	testing.expect(t, ok, "Expected test file to be writable")
	if !ok {
		return
	}
	defer os.remove(test_file)

	file_result := translate_file(test_file, .Bash, .Bash)
	defer destroy_translation_result(&file_result)
	testing.expect(t, file_result.success, "translate_file should succeed for valid input")
	testing.expect(t, strings.contains(file_result.output, "x=5"), "translate_file output should contain assignment")

	batch := translate_batch([]string{test_file}, .Bash, .Bash)
	defer {
		for &result in batch {
			destroy_translation_result(&result)
		}
		delete(batch)
	}
	testing.expect(t, len(batch) == 1, "translate_batch should return one result for one file")
	testing.expect(t, batch[0].success, "translate_batch item should succeed")
}

@(test)
test_get_version_api :: proc(t: ^testing.T) {
	if !should_run_test("test_get_version_api") { return }

	version := get_version()
	testing.expect(t, len(version) > 0, "get_version should return a non-empty version string")
}
