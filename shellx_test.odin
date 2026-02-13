package shellx

import "core:fmt"
import "core:mem"
import "core:os"
import "core:os/os2"
import "core:strings"
import "core:testing"
import "frontend"
import "ir"
import "optimizer"

parser_check_snippet :: proc(
	t: ^testing.T,
	code: string,
	target: ShellDialect,
	test_name: string,
) {
	ext := "sh"
	switch target {
	case .Bash:
		ext = "bash"
	case .POSIX:
		ext = "sh"
	case .Zsh:
		ext = "zsh"
	case .Fish:
		ext = "fish"
	}
	path := fmt.tprintf("/tmp/shellx_golden_%s.%s", test_name, ext)
	ok := os.write_entire_file(path, transmute([]byte)code)
	testing.expect(t, ok, "Golden parser test should write temp file")
	if !ok {
		return
	}
	defer os.remove(path)

	cmd := make([dynamic]string, 0, 3, context.temp_allocator)
	defer delete(cmd)
	switch target {
	case .Bash, .POSIX:
		append(&cmd, "bash", "-n", path)
	case .Zsh:
		append(&cmd, "zsh", "-n", path)
	case .Fish:
		append(&cmd, "fish", "--no-execute", path)
	}
	state, _, stderr, err := os2.process_exec(os2.Process_Desc{command = cmd[:]}, context.allocator)
	defer delete(stderr)
	testing.expect(t, err == nil, "Golden parser command should execute")
	if err != nil {
		return
	}
	testing.expect(t, state.exit_code == 0, fmt.tprintf("Parser should accept rewritten output: %s", string(stderr)))
}

has_shell_binary_for_runtime_test :: proc(bin: string) -> bool {
	desc := os2.Process_Desc{command = []string{"sh", "-lc", fmt.tprintf("command -v %s >/dev/null 2>&1", bin)}}
	state, _, _, err := os2.process_exec(desc, context.temp_allocator)
	return err == nil && state.exit_code == 0
}

target_shell_runtime_cmd :: proc(target: ShellDialect) -> (string, bool) {
	switch target {
	case .Bash:
		if !has_shell_binary_for_runtime_test("bash") { return "", false }
		return "bash", true
	case .Zsh:
		if !has_shell_binary_for_runtime_test("zsh") { return "", false }
		return "zsh", true
	case .Fish:
		if !has_shell_binary_for_runtime_test("fish") { return "", false }
		return "fish", true
	case .POSIX:
		if !has_shell_binary_for_runtime_test("sh") { return "", false }
		return "sh", true
	}
	return "", false
}

runtime_file_ext_for_dialect :: proc(target: ShellDialect) -> string {
	switch target {
	case .Fish:
		return "fish"
	case .Zsh:
		return "zsh"
	case .Bash:
		return "bash"
	case .POSIX:
		return "sh"
	}
	return "sh"
}

run_translated_script_runtime :: proc(
	t: ^testing.T,
	source: string,
	from: ShellDialect,
	to: ShellDialect,
	test_name: string,
) -> (stdout: string, ok: bool) {
	shell_bin, shell_ok := target_shell_runtime_cmd(to)
	if !shell_ok {
		return "", false
	}

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	opts.source_name = test_name

	tr := translate(source, from, to, opts)
	defer destroy_translation_result(&tr)
	testing.expect(t, tr.success, "Translation should succeed")
	if !tr.success {
		return "", false
	}

	tmp_path := fmt.tprintf("/tmp/shellx_sem_%s.%s", test_name, runtime_file_ext_for_dialect(to))
	write_ok := os.write_entire_file(tmp_path, transmute([]byte)tr.output)
	testing.expect(t, write_ok, "Translated output should be writable")
	if !write_ok {
		return "", false
	}
	defer os.remove(tmp_path)

	cmd := make([dynamic]string, 0, 3, context.temp_allocator)
	defer delete(cmd)
	append(&cmd, shell_bin)
	append(&cmd, tmp_path)

	state, out, err_out, err := os2.process_exec(os2.Process_Desc{command = cmd[:]}, context.temp_allocator)
	if err != nil {
		testing.expect(t, false, "Runtime shell should execute translated script")
		return "", false
	}
	if state.exit_code != 0 {
		testing.expect(t, false, fmt.tprintf("Translated script exited non-zero: %d stderr=%s", state.exit_code, string(err_out)))
		return "", false
	}
	return strings.trim_space(string(out)), true
}

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

	result := translate("arr=(one two three)", .Bash, .Fish, options)
	defer destroy_translation_result(&result)

	testing.expect(t, !result.success, "Strict mode should fail on compatibility errors")
	testing.expect(t, result.error == .ValidationError, "Strict mode should surface validation error")
}

@(test)
test_translate_zsh_parameter_expansion_rewrite_simple :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_zsh_parameter_expansion_rewrite_simple") { return }

	src := "echo ${(@)arr} ${(@k)map} ${name:l} ${name:u}"
	result := translate(src, .Zsh, .Bash)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Zsh->Bash translation should succeed")
	testing.expect(t, strings.contains(result.output, "${arr[@]}"), "Should rewrite ${(@)arr} to bash array expansion")
	testing.expect(t, strings.contains(result.output, "${!map[@]}"), "Should rewrite ${(@k)map} to bash key expansion")
	testing.expect(t, strings.contains(result.output, "${name,,}"), "Should rewrite :l to bash lowercase modifier")
	testing.expect(t, strings.contains(result.output, "${name^^}"), "Should rewrite :u to bash uppercase modifier")
	testing.expect(t, !strings.contains(result.output, "(@)"), "Should not leave zsh (@) modifiers in output")
}

@(test)
test_translate_zsh_parameter_expansion_rewrite_nested :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_zsh_parameter_expansion_rewrite_nested") { return }

	src := "echo ${(@)A:-${(@)B}}"
	result := translate(src, .Zsh, .Bash)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Nested zsh expansion translation should succeed")
	testing.expect(t, strings.contains(result.output, "${A[@]:-${B[@]}}"), "Should rewrite nested zsh array modifiers in default expansion")
}

@(test)
test_rewrite_zsh_parameter_expansion_advanced_tokens :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_zsh_parameter_expansion_advanced_tokens") { return }

	input := "x=${(@On)descending_list}; y=${(@on)output}; z=${(@Pk)1}; q=${~q:l}"
	output, changed := rewrite_zsh_parameter_expansion_for_bash(input)
	defer delete(output)

	testing.expect(t, changed, "Advanced zsh parameter tokens should be rewritten for bash")
	testing.expect(t, strings.contains(output, "${descending_list[@]}"), "Should rewrite (@On) array modifier")
	testing.expect(t, strings.contains(output, "${output[@]}"), "Should rewrite (@on) array modifier")
	testing.expect(t, strings.contains(output, "$(eval"), "Should rewrite (@Pk) indirect keys via bash eval expansion")
	testing.expect(t, strings.contains(output, "${q,,}"), "Should rewrite ${~q:l} to bash lowercase expansion")
	testing.expect(t, !strings.contains(output, "(@On)"), "Should not leave (@On) token in output")
	testing.expect(t, !strings.contains(output, "(@Pk)"), "Should not leave (@Pk) token in output")
	testing.expect(t, !strings.contains(output, "${~"), "Should not leave zsh ${~...} glob-interpretation token in output")
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

@(test)
test_translate_insert_shims_option_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_insert_shims_option_api") { return }

	options := DEFAULT_TRANSLATION_OPTIONS
	options.insert_shims = true

	result := translate("if [[ $x == y ]]; then echo ok; fi", .Bash, .Fish, options)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Translation should succeed with insert_shims enabled")
	testing.expect(
		t,
		len(result.required_shims) > 0,
		"Compatibility shims should be collected for Bash to Fish",
	)
	testing.expect(t, strings.contains(result.output, "__shellx_test"), "Condition shim should be injected into output")
}

@(test)
test_translate_capability_prelude_disabled_by_default :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_capability_prelude_disabled_by_default") { return }

	src := "add-zsh-hook precmd my_precmd\n"
	result := translate(src, .Zsh, .Bash, DEFAULT_TRANSLATION_OPTIONS)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Translation should succeed with default options")
	testing.expect(t, !strings.contains(result.output, "__zx_warn"), "Capability prelude should not be emitted unless insert_shims=true")
}

@(test)
test_translate_capability_prelude_with_insert_shims :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_capability_prelude_with_insert_shims") { return }

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true

	src := "add-zsh-hook precmd my_precmd\n"
	result := translate(src, .Zsh, .Bash, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Translation should succeed with insert_shims")
	testing.expect(t, len(result.required_caps) > 0, "Capabilities should be collected for compatibility gaps")
	testing.expect(t, strings.contains(result.output, "# shellx capability prelude"), "Capability prelude header should be emitted")
	testing.expect(t, strings.contains(result.output, "__zx_warn"), "Capability helper should be emitted")
}

@(test)
test_translate_fish_lowering_test_and_source_callsites :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_fish_lowering_test_and_source_callsites") { return }

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true

	src := "if test -f \"$HOME/.zshrc\"; then source \"$HOME/.zshrc\"; fi\n"
	result := translate(src, .Bash, .Fish, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Translation should succeed for test/source lowering")
	testing.expect(t, strings.contains(result.output, "__zx_test"), "Fish output should lower test callsites to __zx_test")
	testing.expect(t, strings.contains(result.output, "__zx_source"), "Fish output should lower source callsites to __zx_source")
}

@(test)
test_translate_fish_lowering_assignment_callsite :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_fish_lowering_assignment_callsite") { return }

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true

	src := "name=world\necho \"$name\"\n"
	result := translate(src, .Bash, .Fish, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Translation should succeed for assignment lowering")
	testing.expect(t, strings.contains(result.output, "__zx_set name"), "Fish output should lower simple assignments to __zx_set")
}

@(test)
test_translate_insert_shims_parameter_expansion_to_fish_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_insert_shims_parameter_expansion_to_fish_api") { return }

	options := DEFAULT_TRANSLATION_OPTIONS
	options.insert_shims = true

	result := translate("echo ${name:-world} ${#name}", .Bash, .Fish, options)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Parameter expansion translation to fish should succeed")
	testing.expect(t, strings.contains(result.output, "__shellx_param_default"), "Parameter default shim should be injected")
	testing.expect(t, strings.contains(result.output, "__shellx_param_length"), "Parameter length shim should be injected")
	testing.expect(t, strings.contains(result.output, "(__shellx_param_default name"), "Default expansion should be rewritten")
	testing.expect(t, strings.contains(result.output, "(__shellx_param_length name)"), "Length expansion should be rewritten")
}

@(test)
test_translate_insert_shims_process_substitution_to_fish_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_insert_shims_process_substitution_to_fish_api") { return }

	options := DEFAULT_TRANSLATION_OPTIONS
	options.insert_shims = true

	result := translate("cat <(echo hi)", .Bash, .Fish, options)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Process substitution translation to fish should succeed")
	testing.expect(t, strings.contains(result.output, "__shellx_psub_in"), "Process substitution shim should be injected/used")
}

@(test)
test_translate_insert_shims_fish_string_match_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_insert_shims_fish_string_match_api") { return }

	options := DEFAULT_TRANSLATION_OPTIONS
	options.insert_shims = true

	src := "if string match -q 'foo*' $x\n\techo ok\nend\n"
	result := translate(src, .Fish, .Bash, options)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Fish string match condition should translate with shims")
	testing.expect(t, strings.contains(result.output, "__shellx_match"), "Output should use __shellx_match shim")
	testing.expect(t, !strings.contains(result.output, "if string match"), "Output should not contain raw fish string match in condition")
}

@(test)
test_translate_corpus_fisher_to_bash_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_corpus_fisher_to_bash_api") { return }

	path := "tests/corpus/repos/fish/fisher/functions/fisher.fish"
	if !os.is_file(path) {
		return
	}
	data, ok := os.read_entire_file(path)
	testing.expect(t, ok, "Should read fisher corpus plugin")
	if !ok {
		return
	}
	defer delete(data)

	options := DEFAULT_TRANSLATION_OPTIONS
	options.insert_shims = true

	result := translate(string(data), .Fish, .Bash, options)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Fisher corpus plugin should translate to bash")
	testing.expect(t, len(result.output) > 0, "Translated output should not be empty")
	testing.expect(t, strings.contains(result.output, "__shellx_match"), "Fisher translation should include string-match shim usage")
}

@(test)
test_translate_corpus_bashit_theme_to_fish_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_corpus_bashit_theme_to_fish_api") { return }

	path := "tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash"
	if !os.is_file(path) {
		return
	}
	data, ok := os.read_entire_file(path)
	testing.expect(t, ok, "Should read bash-it theme corpus file")
	if !ok {
		return
	}
	defer delete(data)

	options := DEFAULT_TRANSLATION_OPTIONS
	options.insert_shims = true

	result := translate(string(data), .Bash, .Fish, options)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Bash-it theme should translate to fish")
	testing.expect(t, len(result.output) > 0, "Theme translation output should not be empty")
}

@(test)
test_translate_preserve_comments_option_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_preserve_comments_option_api") { return }

	options := DEFAULT_TRANSLATION_OPTIONS
	options.preserve_comments = true

	result := translate("# comment\necho hello\n", .Bash, .Bash, options)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Translation should succeed with preserve_comments enabled")
	found_hint := false
	for warning in result.warnings {
		if strings.contains(warning, "preserve_comments") {
			found_hint = true
			break
		}
	}
	testing.expect(t, found_hint, "Result should include preserve_comments lifecycle warning")
}

@(test)
test_translate_optimization_level_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_optimization_level_api") { return }

	options := DEFAULT_TRANSLATION_OPTIONS
	options.optimization_level = .Standard

	result := translate("x=1\ny=1\n", .Bash, .Bash, options)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Translation should succeed with optimization enabled")
}

@(test)
test_script_builder_api :: proc(t: ^testing.T) {
	if !should_run_test("test_script_builder_api") { return }

	builder := create_script_builder(.Bash)
	defer destroy_script_builder(&builder)

	script_add_var(&builder, "name", "world")
	script_add_call(&builder, "echo", "hello", "$name")

	output := script_emit(&builder, .Bash)
	defer delete(output)

	testing.expect(t, len(output) > 0, "script_emit should return generated script")
	testing.expect(t, strings.contains(output, "name="), "Output should contain assignment")
	testing.expect(t, strings.contains(output, "echo"), "Output should contain command call")
}

@(test)
test_golden_structured_block_rebuilds_split_function_decl :: proc(t: ^testing.T) {
	if !should_run_test("test_golden_structured_block_rebuilds_split_function_decl") { return }

	input := "_zsh_highlight()\n{\n  :\n}\n"
	output, changed := normalize_shell_structured_blocks(input, .Bash)
	defer delete(output)

	testing.expect(t, changed, "Structured block normalizer should rewrite split function declaration")
	testing.expect(t, strings.contains(output, "_zsh_highlight() {"), "Should rewrite split function declaration to single-line opener")
	testing.expect(t, !strings.contains(output, "\n{\n"), "Should not keep standalone opening brace line for split declaration")
	parser_check_snippet(t, output, .Bash, "split_fn_decl")
}

@(test)
test_golden_parse_hardening_preserves_case_arms_like_user_star :: proc(t: ^testing.T) {
	if !should_run_test("test_golden_parse_hardening_preserves_case_arms_like_user_star") { return }

	input := "case $widgets[$widget] in\n  user:*)\n    bind_count=1\n    ;;\n  *)\n    bind_count=0\n    ;;\nesac\n"
	output, _ := rewrite_shell_parse_hardening(input, .Bash)
	defer delete(output)

	testing.expect(t, !strings.contains(output, "user:*)"), "Widget case arms should be neutralized for parser-safe non-zsh output")
	testing.expect(t, !strings.contains(output, "*)"), "Fallback case arms from zsh widget dispatch should be neutralized")
	parser_check_snippet(t, output, .Bash, "case_user_star")
}

@(test)
test_golden_parse_hardening_neutralizes_extract_case_arm_pattern :: proc(t: ^testing.T) {
	if !should_run_test("test_golden_parse_hardening_neutralizes_extract_case_arm_pattern") { return }

	input := `      (*.gz) (( $+commands[pigz] )) && pigz -cdk "$full_path" > "$(__shellx_zsh_expand "\${file:t:r})" || gunzip -ck "$full_path" > "$(__shellx_zsh_expand "\${file:t:r})" ;;`
	output, _ := rewrite_shell_parse_hardening(input, .Bash)
	defer delete(output)

	testing.expect(t, strings.trim_space(output) == ":", "Should neutralize zsh extract case-arm pattern that is invalid in bash/posix")
}

@(test)
test_golden_parse_hardening_keeps_multiline_if_balance :: proc(t: ^testing.T) {
	if !should_run_test("test_golden_parse_hardening_keeps_multiline_if_balance") { return }

	input := "f() {\n  if cond_a &&\n     cond_b\n  then\n    return 0\n  else\n    return 1\n  fi\n}\n"
	output, _ := rewrite_shell_parse_hardening(input, .Bash)
	defer delete(output)

	testing.expect(t, strings.contains(output, "fi"), "Should preserve fi in multiline if blocks")
	parser_check_snippet(t, output, .Bash, "multiline_if_balance")
}

@(test)
test_shim_rewrite_fish_set_list_bridge_is_scoped :: proc(t: ^testing.T) {
	if !should_run_test("test_shim_rewrite_fish_set_list_bridge_is_scoped") { return }

	input := "set arr one two three\nset -gx PATH /tmp/bin $PATH\necho \"set arr one two\""
	output, changed := rewrite_fish_set_list_bridge_callsites(input)
	defer delete(output)

	testing.expect(t, changed, "Simple fish list assignment should be rewritten")
	testing.expect(t, strings.contains(output, "__shellx_list_to_array arr one two three"), "List assignment should lower to shim call")
	testing.expect(t, strings.contains(output, "set -gx PATH /tmp/bin $PATH"), "Flagged fish set should remain untouched")
	testing.expect(t, strings.contains(output, "echo \"set arr one two\""), "Quoted string content should remain untouched")
}

@(test)
test_shim_rewrite_declare_array_is_line_scoped :: proc(t: ^testing.T) {
	if !should_run_test("test_shim_rewrite_declare_array_is_line_scoped") { return }

	input := "declare -a arr=(one two)\necho \"declare -a arr=(x y)\""
	output, changed := rewrite_declare_array_callsites(input)
	defer delete(output)

	testing.expect(t, changed, "declare -a line should be rewritten")
	testing.expect(t, strings.contains(output, "__shellx_array_set arr=(one two)"), "declare -a should be rewritten to shim call")
	testing.expect(t, strings.contains(output, "echo \"declare -a arr=(x y)\""), "Inline string content should remain untouched")
}

@(test)
test_fish_command_substitution_rewrite_keeps_array_literal_but_rewrites_comparison :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_command_substitution_rewrite_keeps_array_literal_but_rewrites_comparison") { return }

	input := "arr=(one two)\nif [ \"$x\" = (my_fn) ]; then\n  :\nfi"
	output, changed := fix_fish_command_substitution(input)
	defer delete(output)

	testing.expect(t, changed, "Comparison command substitution should be rewritten")
	testing.expect(t, strings.contains(output, "arr=(one two)"), "Array literal assignment should stay unchanged")
	testing.expect(t, strings.contains(output, "[ \"$x\" = $(my_fn) ]"), "Comparison command substitution should become POSIX form")
}

@(test)
test_repair_fish_malformed_command_substitutions_signatures :: proc(t: ^testing.T) {
	if !should_run_test("test_repair_fish_malformed_command_substitutions_signatures") { return }

	input := "set -l _commit (git; set -l log \"\"\nset -g __p9k_dump_file (__shellx_param_default; set -g XDG_CACHE_HOME \"\""
	output, changed := repair_fish_malformed_command_substitutions(input)
	defer delete(output)

	testing.expect(t, changed, "Known malformed command-substitution signatures should be repaired")
	testing.expect(t, strings.contains(output, "set -l _commit (git log \"\")"), "git-log malformed substitution should be repaired")
	testing.expect(t, strings.contains(output, "set -g __p9k_dump_file (__shellx_param_default XDG_CACHE_HOME \"\")"), "param-default malformed substitution should be repaired")
}

@(test)
test_normalize_zsh_preparse_local_cmdsubs :: proc(t: ^testing.T) {
	if !should_run_test("test_normalize_zsh_preparse_local_cmdsubs") { return }

	input := "f() {\n  local _commit=$(echo abc)\n  typeset -g root=$(pwd)\n}"
	output, changed := normalize_zsh_preparse_local_cmdsubs(input)
	defer delete(output)

	testing.expect(t, changed, "zsh local/typeset command substitutions should be normalized for parse")
	testing.expect(t, strings.contains(output, "  _commit=$(echo abc)"), "local cmdsub should drop local keyword in preparse normalization")
	testing.expect(t, strings.contains(output, "  root=$(pwd)"), "typeset cmdsub should drop typeset keyword in preparse normalization")
}

@(test)
test_repair_fish_split_echo_param_default :: proc(t: ^testing.T) {
	if !should_run_test("test_repair_fish_split_echo_param_default") { return }

	input := "set XDG_CACHE_HOME \necho\n__shellx_param_default XDG_CACHE_HOME \"/tmp/cache\""
	output, changed := repair_fish_split_echo_param_default(input)
	defer delete(output)

	testing.expect(t, changed, "split echo + param-default should be repaired")
	testing.expect(t, strings.contains(output, "echo (__shellx_param_default XDG_CACHE_HOME \"/tmp/cache\")"), "repair should combine echo and shim call into fish command substitution form")
}

@(test)
test_repair_fish_quoted_param_default_echo :: proc(t: ^testing.T) {
	if !should_run_test("test_repair_fish_quoted_param_default_echo") { return }

	input := `echo "(__shellx_param_default v "fallback")"`
	output, changed := repair_fish_quoted_param_default_echo(input)
	defer delete(output)

	testing.expect(t, changed, "quoted param-default echo should be repaired")
	testing.expect(t, strings.contains(output, "echo (__shellx_param_default v \"fallback\")"), "repair should remove outer quotes around command substitution")
}

@(test)
test_repair_shell_split_echo_param_expansion :: proc(t: ^testing.T) {
	if !should_run_test("test_repair_shell_split_echo_param_expansion") { return }

	input := "name=\necho\n${name:-fallback}"
	output, changed := repair_shell_split_echo_param_expansion(input)
	defer delete(output)

	testing.expect(t, changed, "split shell echo + parameter expansion should be repaired")
	testing.expect(t, strings.contains(output, "echo ${name:-fallback}"), "repair should merge echo and parameter expansion line")
}

@(test)
test_repair_shell_case_arms :: proc(t: ^testing.T) {
	if !should_run_test("test_repair_shell_case_arms") { return }

	input := "case \"$x\" in\n  one) echo yes\n  *) echo no\nesac"
	output, changed := repair_shell_case_arms(input)
	defer delete(output)

	testing.expect(t, changed, "inline case arms should be terminated")
	testing.expect(t, strings.contains(output, "one) echo yes ;;"), "first arm should include ;;")
	testing.expect(t, strings.contains(output, "*) echo no ;;"), "fallback arm should include ;;")
}

@(test)
test_rewrite_fish_positional_params :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_fish_positional_params") { return }

	input := `echo "$1-${2}"`
	output, changed := rewrite_fish_positional_params(input)
	defer delete(output)

	testing.expect(t, changed, "positional params should be rewritten for fish output")
	testing.expect(t, strings.contains(output, `$argv[1]-$argv[2]`), "positional params should map to fish argv indexing")
}

@(test)
test_normalize_bash_preparse_array_literals :: proc(t: ^testing.T) {
	if !should_run_test("test_normalize_bash_preparse_array_literals") { return }

	input := "arr=(one two three)\necho ${arr[1]}"
	output, changed := normalize_bash_preparse_array_literals(input)
	defer delete(output)

	testing.expect(t, changed, "simple bash array literal should be normalized for fish target parsing")
	testing.expect(t, strings.contains(output, "set arr one two three"), "array assignment should be rewritten to fish-style set")
}

@(test)
test_rewrite_parameter_expansion_callsites_bash_index_to_fish :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_parameter_expansion_callsites_bash_index_to_fish") { return }

	input := `echo ${arr[1]}`
	output, changed := rewrite_parameter_expansion_callsites(input, .Fish)
	defer delete(output)

	testing.expect(t, changed, "bash indexed parameter expansion should be rewritten for fish")
	testing.expect(t, strings.contains(output, "$arr[2]"), "bash index 1 should map to fish index 2")
}

@(test)
test_semantic_array_list_fish_to_bash_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_array_list_fish_to_bash_runtime") { return }
	source := `set arr one two three
echo $arr[2]`
	out, ok := run_translated_script_runtime(t, source, .Fish, .Bash, "array_list_fish_to_bash_runtime")
	if !ok { return }
	testing.expect(t, out == "two", "Fish list indexing should preserve semantic value in Bash output")
}

@(test)
test_semantic_assoc_map_zsh_to_bash_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_assoc_map_zsh_to_bash_runtime") { return }
	source := `typeset -A m
m[foo]=bar
echo ${m[foo]}`
	out, ok := run_translated_script_runtime(t, source, .Zsh, .Bash, "assoc_map_zsh_to_bash_runtime")
	if !ok { return }
	testing.expect(t, out == "bar", "Associative map lookup should preserve semantic value")
}

@(test)
test_semantic_hook_precmd_zsh_to_bash_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_hook_precmd_zsh_to_bash_runtime") { return }
	source := `my_precmd() { echo hook; }
add-zsh-hook precmd my_precmd
__shellx_run_precmd`
	out, ok := run_translated_script_runtime(t, source, .Zsh, .Bash, "hook_precmd_zsh_to_bash_runtime")
	if !ok { return }
	testing.expect(t, out == "hook", "Hook registration shim should dispatch precmd function")
}

@(test)
test_semantic_condition_string_match_fish_to_bash_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_condition_string_match_fish_to_bash_runtime") { return }
	source := `set x foobar
if string match -q 'foo*' $x
	echo ok
end`
	out, ok := run_translated_script_runtime(t, source, .Fish, .Bash, "condition_string_match_fish_to_bash_runtime")
	if !ok { return }
	testing.expect(t, out == "ok", "Fish string-match condition should preserve truth semantics")
}

@(test)
test_semantic_param_modifiers_zsh_to_bash_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_param_modifiers_zsh_to_bash_runtime") { return }
	source := `name=HeLLo
echo ${name:l}
echo ${name:u}`
	out, ok := run_translated_script_runtime(t, source, .Zsh, .Bash, "param_modifiers_zsh_to_bash_runtime")
	if !ok { return }
	testing.expect(t, out == "hello\nHELLO", "Zsh lower/upper parameter modifiers should preserve output semantics in Bash")
}

@(test)
test_semantic_param_default_zsh_to_fish_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_param_default_zsh_to_fish_runtime") { return }
	source := `XDG_CACHE_HOME=""
echo ${XDG_CACHE_HOME:-/tmp/cache}`
	out, ok := run_translated_script_runtime(t, source, .Zsh, .Fish, "param_default_zsh_to_fish_runtime")
	if !ok { return }
	testing.expect(t, out == "/tmp/cache", "Zsh :- default should use fallback when variable is empty")
}

@(test)
test_posix_output_likely_degraded_detection :: proc(t: ^testing.T) {
	if !should_run_test("test_posix_output_likely_degraded_detection") { return }

	src_case := "x=a\ncase \"$x\" in\n  a) echo match ;;\n  *) echo miss ;;\nesac\n"
	out_case_bad := "x=a\necho match\necho miss\n"
	testing.expect(t, posix_output_likely_degraded(src_case, out_case_bad), "should detect degraded case translation")

	src_param := "name=\"\"\necho \"${name:-alt}\"\n"
	out_param_bad := "name=\n:\n"
	testing.expect(t, posix_output_likely_degraded(src_param, out_param_bad), "should detect degraded param expansion translation")
}

@(test)
test_translate_warns_on_fish_zsh_prompt_noop_fallback :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_warns_on_fish_zsh_prompt_noop_fallback") { return }

	source := `function fish_prompt
    set -g _tide_x 1
    if test "$_tide_x" = "1"
        echo ok
    end
end
fish_prompt`
	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	result := translate(source, .Fish, .Zsh, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Translation should succeed")
	testing.expect(t, strings.contains(result.output, "fish_prompt() { :; }"), "Output should contain prompt no-op fallback when applied")
	has_warning := false
	for w in result.warnings {
		if strings.contains(w, "prompt no-op fallback") {
			has_warning = true
			break
		}
	}
	testing.expect(t, has_warning, "Fallback should be surfaced via warnings")
}

@(test)
test_semantic_corpus_pattern_fish_gitnow_branch_compare :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_corpus_pattern_fish_gitnow_branch_compare") { return }
	source := `function __gitnow_current_branch_name
    echo main
end
set v_branch main
if test "$v_branch" = (__gitnow_current_branch_name)
    echo SAME
end`
	out, ok := run_translated_script_runtime(t, source, .Fish, .Bash, "corpus_pattern_fish_gitnow_branch_compare")
	if !ok { return }
	testing.expect(t, out == "SAME", "Fish gitnow-like branch compare should preserve runtime behavior")
}
