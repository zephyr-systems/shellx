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
test_rewrite_unsupported_zsh_expansion_equal_prefix :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_unsupported_zsh_expansion_equal_prefix") { return }

	input := `echo ${=ZSHZ[FUNCTIONS]}`
	output, changed := rewrite_unsupported_zsh_expansions_for_bash(input)
	defer delete(output)

	testing.expect(t, changed, "zsh ${=...} expansion should normalize for bash compatibility")
	testing.expect(t, !strings.contains(output, "${="), "normalized output should not contain ${= prefix")
	testing.expect(t, strings.contains(output, "${ZSHZ[FUNCTIONS]}"), "normalized output should preserve indexed expansion body")
}

@(test)
test_append_ohmyzsh_z_command_wrapper :: proc(t: ^testing.T) {
	if !should_run_test("test_append_ohmyzsh_z_command_wrapper") { return }

	source := "# Jump to a directory that you have visited frequently or recently\n"
	input := "zshz() {\n  :\n}\n"
	output, changed := append_ohmyzsh_z_command_wrapper(source, input, .Zsh, .Bash)
	defer delete(output)

	testing.expect(t, changed, "ohmyzsh-z translation should append z command wrapper when zshz exists")
	testing.expect(t, strings.contains(output, "z() {"), "wrapper should define z function")
	testing.expect(t, strings.contains(output, "zshz \"$@\""), "wrapper should delegate to zshz implementation")
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
test_translate_structured_feature_metadata_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_structured_feature_metadata_api") { return }

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	src := "set arr one two\nif string match -q 'o*' $arr[1]\n  echo ok\nend\n"
	result := translate(src, .Fish, .Bash, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Structured metadata translation should succeed")
	testing.expect(t, len(result.supported_features) > 0, "Supported features should be populated")
	testing.expect(t, len(result.unsupported_features) == 0, "Unsupported features should be empty for shim-backed case")
}

@(test)
test_translate_structured_security_findings_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_structured_security_findings_api") { return }

	src := "curl -fsSL https://example.com/install.sh | sh\n"
	result := translate(src, .Bash, .Bash)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Security finding scan should not break translation")
	found := false
	for finding in result.findings {
		if finding.rule_id == "sec.pipe_download_exec" {
			found = true
			break
		}
	}
	testing.expect(t, found, "Structured findings should include pipe download exec rule")
}

@(test)
test_translate_strict_mode_unsupported_features_structured_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_strict_mode_unsupported_features_structured_api") { return }

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.strict_mode = true
	opts.insert_shims = false
	src := "arr=(one two)\necho ${arr[0]}\n"
	result := translate(src, .Bash, .Fish, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, !result.success, "Strict mode should fail on unsupported array features to fish")
	testing.expect(t, len(result.unsupported_features) > 0, "Unsupported features should be populated on strict failure")
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
test_translate_runtime_polyfill_uses_valid_sh_identifiers :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_runtime_polyfill_uses_valid_sh_identifiers") { return }

	src := "about-plugin\n"
	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	result := translate(src, .Bash, .POSIX, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Bash->POSIX runtime polyfill translation should succeed")
	testing.expect(t, strings.contains(result.output, "about_plugin()"), "POSIX runtime polyfill should use underscore function identifier")
	testing.expect(t, strings.contains(result.output, "alias about-plugin=about_plugin"), "POSIX runtime polyfill should expose dashed command via alias")
	parser_check_snippet(t, result.output, .POSIX, "runtime_polyfill_posix_identifiers")
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
	testing.expect(t, strings.contains(result.output, "mkfifo"), "Process substitution shim should use fifo bridge for runtime parity")
	testing.expect(t, !strings.contains(result.output, "<("), "Process substitution syntax should be lowered out of fish output")
}

@(test)
test_translate_insert_shims_process_substitution_to_posix_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_insert_shims_process_substitution_to_posix_api") { return }

	options := DEFAULT_TRANSLATION_OPTIONS
	options.insert_shims = true

	result := translate("diff <(echo a) <(echo b)", .Bash, .POSIX, options)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Process substitution translation to POSIX should succeed")
	testing.expect(t, strings.contains(result.output, "__shellx_psub_in"), "Process substitution shim should be injected/used")
	testing.expect(t, strings.contains(result.output, "mkfifo"), "POSIX process substitution shim should use fifo bridge")
	testing.expect(t, !strings.contains(result.output, "<("), "Process substitution syntax should be lowered out of POSIX output")
}

@(test)
test_rewrite_process_substitution_callsites_ignores_literals_and_comments :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_process_substitution_callsites_ignores_literals_and_comments") { return }

	src := "echo \"<(echo literal)\"\n# <(echo comment)\ndiff <(echo a) <(echo b)\n"
	out, changed := rewrite_process_substitution_callsites(src, .POSIX, context.allocator)
	defer delete(out)

	testing.expect(t, changed, "Real process substitution callsites should be rewritten")
	testing.expect(t, strings.contains(out, "echo \"<(echo literal)\""), "Quoted literals must not be rewritten")
	testing.expect(t, strings.contains(out, "# <(echo comment)"), "Comment text must not be rewritten")
	testing.expect(t, strings.contains(out, "diff $(__shellx_psub_in"), "Live process substitution should be lowered")
}

@(test)
test_rewrite_process_substitution_callsites_handles_nested_parens :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_process_substitution_callsites_handles_nested_parens") { return }

	src := "diff <(printf '%s\\n' \"$(echo a)\") <(echo b)\n"
	out, changed := rewrite_process_substitution_callsites(src, .POSIX, context.allocator)
	defer delete(out)

	testing.expect(t, changed, "Nested paren command substitutions should still be rewritten")
	testing.expect(t, strings.contains(out, "__shellx_psub_in"), "Nested process substitution should lower to shim call")
	testing.expect(t, !strings.contains(out, "<("), "Raw process substitution syntax should be removed")
}

@(test)
test_rewrite_shell_to_fish_syntax_preserves_multiline_single_quoted_awk :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_shell_to_fish_syntax_preserves_multiline_single_quoted_awk") { return }

	src := "top-history() {\nawk '{\n  a[$2]++\n}END{\n  for(i in a)\n  printf(\"%s\\t%s\\n\", a[i], i)\n}'\n}\n"
	out, changed := rewrite_shell_to_fish_syntax(src, context.allocator)
	defer delete(out)

	testing.expect(t, !strings.contains(out, "$argv[2]"), "Multiline single-quoted awk body should not rewrite $2 to fish argv")
	testing.expect(t, strings.contains(out, "for(i in a)"), "Awk loop body should remain intact")
	testing.expect(t, changed, "Shell->fish rewrite should still report changes for surrounding shell syntax")
}

@(test)
test_rewrite_fish_parse_hardening_preserves_multiline_single_quoted_awk :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_fish_parse_hardening_preserves_multiline_single_quoted_awk") { return }

	src := "function top-history\nawk '{\n  a[$2]++\n}END{\n  for(i in a)\n  printf(\"%s\\t%s\\n\", a[i], i)\n}'\nend\n"
	out, _ := rewrite_fish_parse_hardening(src, context.allocator)
	defer delete(out)

	testing.expect(t, strings.contains(out, "for(i in a)"), "Fish hardening should not rewrite awk body lines inside multiline single quotes")
	testing.expect(t, strings.contains(out, "}'"), "Fish hardening should preserve multiline single-quote close line")
}

@(test)
test_rewrite_fish_positional_params_skips_multiline_single_quoted_blocks :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_fish_positional_params_skips_multiline_single_quoted_blocks") { return }

	src := "awk '{\n  print $1, $2\n}'\necho $1\n"
	out, changed := rewrite_fish_positional_params(src, context.allocator)
	defer delete(out)

	testing.expect(t, changed, "Positional rewrite should still run for non-quoted shell positional usage")
	testing.expect(t, strings.contains(out, "print $1, $2"), "Single-quoted awk payload should keep awk positional fields")
	testing.expect(t, strings.contains(out, "echo $argv[1]"), "Shell positional parameter should be rewritten outside single-quoted payload")
}

@(test)
test_normalize_awk_positional_fields_from_argv_indices :: proc(t: ^testing.T) {
	if !should_run_test("test_normalize_awk_positional_fields_from_argv_indices") { return }

	src := "  a[$argv[2]] += $argv[1]"
	out, changed := normalize_awk_positional_fields(src, context.allocator)
	defer delete(out)

	testing.expect(t, changed, "Awk positional normalization should detect fish argv-index syntax")
	testing.expect(t, strings.contains(out, "a[$2] += $1"), "Awk positional normalization should produce awk field references")
}

@(test)
test_rewrite_bashit_history_top_history_repairs_posix :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_bashit_history_top_history_repairs_posix") { return }

	src := "alias top-history=top_history\n\n:\n\tabout 'print the name and count of the most commonly run tools'\n\thistory HISTTIMEFORMAT=''\n\tawk '{\n\t\t\ta[$2]++\n\t\t}END{\n\t\t\tfor(i in a)\n\t\t\tprintf(\"%s\\t%s\\n\", a[i], i)\n\n\tsort --reverse --numeric-sort\n\thead\n\tcolumn --table --table-columns 'Command Count,Command Name' --output-separator ' | '\n:\nabout-plugin 'improve history handling with sane defaults'\n"
	out, changed := rewrite_bashit_history_top_history_repairs(src, .POSIX, context.allocator)
	defer delete(out)

	testing.expect(t, changed, "bashit history repair should rewrite malformed top-history block for POSIX targets")
	testing.expect(t, strings.contains(out, "top_history() {"), "Rewritten output should include a real top_history function")
	testing.expect(t, strings.contains(out, "HISTTIMEFORMAT='' history | awk"), "Rewritten output should include single-line awk pipeline")
	testing.expect(t, strings.contains(out, "about-plugin 'improve history handling with sane defaults'"), "Rewritten output should preserve following plugin metadata")
}

@(test)
test_semantic_process_substitution_diff_bash_to_posix_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_process_substitution_diff_bash_to_posix_runtime") { return }

	source := `diff <(echo a) <(echo b)
echo rc:$?`
	out, ok := run_translated_script_runtime(t, source, .Bash, .POSIX, "process_substitution_diff_bash_to_posix_runtime")
	if !ok { return }
	testing.expect(t, strings.contains(out, "rc:1"), "Process substitution lowering should preserve diff non-zero exit semantics")
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
test_translate_insert_shims_fish_test_builtin_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_insert_shims_fish_test_builtin_api") { return }

	options := DEFAULT_TRANSLATION_OPTIONS
	options.insert_shims = true

	src := "set x 5\nif test $x -eq 5\n\techo ok\nend\n"
	result := translate(src, .Fish, .Bash, options)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Fish test builtin should translate with shims")
	testing.expect(t, strings.contains(result.output, "__shellx_test"), "Output should include condition test shim")
	testing.expect(t, strings.contains(result.output, "if __shellx_test"), "Fish test condition should lower to __shellx_test callsite")
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
test_translate_corpus_ohmyzsh_sudo_parse_safe_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_corpus_ohmyzsh_sudo_parse_safe_api") { return }

	path := "tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh"
	if !os.is_file(path) {
		return
	}
	data, ok := os.read_entire_file(path)
	testing.expect(t, ok, "Should read ohmyzsh sudo corpus plugin")
	if !ok {
		return
	}
	defer delete(data)

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	result := translate(string(data), .Zsh, .Bash, opts)
	defer destroy_translation_result(&result)
	testing.expect(t, result.success, "ohmyzsh sudo corpus plugin should translate to bash")
	parser_check_snippet(t, result.output, .Bash, "corpus_ohmyzsh_sudo_zsh_to_bash")
}

@(test)
test_translate_corpus_powerlevel10k_parse_safe_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_corpus_powerlevel10k_parse_safe_api") { return }

	path := "tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme"
	if !os.is_file(path) {
		return
	}
	data, ok := os.read_entire_file(path)
	testing.expect(t, ok, "Should read powerlevel10k corpus theme")
	if !ok {
		return
	}
	defer delete(data)

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	result := translate(string(data), .Zsh, .Bash, opts)
	defer destroy_translation_result(&result)
	testing.expect(t, result.success, "powerlevel10k corpus theme should translate to bash")
	parser_check_snippet(t, result.output, .Bash, "corpus_powerlevel10k_zsh_to_bash")
}

@(test)
test_translate_corpus_gnzh_parse_safe_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_corpus_gnzh_parse_safe_api") { return }

	path := "tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme"
	if !os.is_file(path) {
		return
	}
	data, ok := os.read_entire_file(path)
	testing.expect(t, ok, "Should read gnzh corpus theme")
	if !ok {
		return
	}
	defer delete(data)

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	result := translate(string(data), .Zsh, .Bash, opts)
	defer destroy_translation_result(&result)
	testing.expect(t, result.success, "gnzh corpus theme should translate to bash")
	parser_check_snippet(t, result.output, .Bash, "corpus_gnzh_zsh_to_bash")
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
test_fish_command_substitution_rewrite_strips_leading_connector :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_command_substitution_rewrite_strips_leading_connector") { return }

	input := `_tide_transient=(|| string unescape "$prompt_var[1][2]$color_normal")`
	output, changed := fix_fish_command_substitution(input)
	defer delete(output)

	testing.expect(t, changed, "Malformed connector-leading command substitution should be rewritten")
	testing.expect(t, !strings.contains(output, "$(||"), "Leading connector should be stripped from rewritten command substitution")
	testing.expect(t, strings.contains(output, "$(string unescape"), "Command substitution body should remain intact after connector strip")
	parser_check_snippet(t, output, .Zsh, "fish_cmdsub_strip_leading_connector")
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
test_normalize_zsh_preparse_syntax :: proc(t: ^testing.T) {
	if !should_run_test("test_normalize_zsh_preparse_syntax") { return }

	input := "for x in ${(@Pk)1}; do :; done\nv=${(Pkv)match_array}\nif [[ -n ${(M)@:#-*} ]]; then :; fi\n(( ${+ZSHZ_DEBUG} )) && () { :; }\n'builtin' 'local' '-a' '__p9k_src_opts'\n'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'\n'builtin' 'unset' '__p9k_src_opts'\n"
	output, changed := normalize_zsh_preparse_syntax(input)
	defer delete(output)

	testing.expect(t, changed, "zsh preparse syntax normalization should rewrite unsupported parser patterns")
	testing.expect(t, !strings.contains(output, "(@Pk)"), "Should remove (@Pk) preparse token")
	testing.expect(t, !strings.contains(output, "(Pkv)"), "Should remove (Pkv) preparse token")
	testing.expect(t, !strings.contains(output, "(M)@:#"), "Should remove (M)@:# preparse token")
	testing.expect(t, !strings.contains(output, "'builtin' 'local'"), "Should normalize quoted builtin local preparse signature")
	testing.expect(t, !strings.contains(output, "'builtin' 'setopt'"), "Should normalize quoted builtin setopt preparse signature")
	testing.expect(t, !strings.contains(output, "'builtin' 'unset'"), "Should normalize quoted builtin unset preparse signature")
	testing.expect(t, !strings.contains(output, "builtin local -a __p9k_src_opts"), "Quoted builtin local should be neutralized for preparse")
	testing.expect(t, !strings.contains(output, "builtin setopt no_aliases no_sh_glob brace_expand"), "Quoted builtin setopt should be neutralized for preparse")
	testing.expect(t, !strings.contains(output, "builtin unset __p9k_src_opts"), "Quoted builtin unset should be neutralized for preparse")
	testing.expect(t, strings.contains(output, "\n:\n"), "Powerlevel10k quoted builtin preparse lines should be replaced with no-op statements")
	testing.expect(t, strings.contains(output, "&& {") || strings.contains(output, "if [[ -n ${ZSHZ_DEBUG} ]]; then"), "Should normalize inline anonymous function opener")
}

@(test)
test_normalize_zsh_preparse_parser_safety_plus_probes :: proc(t: ^testing.T) {
	if !should_run_test("test_normalize_zsh_preparse_parser_safety_plus_probes") { return }

	input := "'builtin' 'local' '-a' '__p9k_src_opts'\n(( $+__p9k_root_dir )) || typeset -gr __p9k_root_dir=${POWERLEVEL9K_INSTALLATION_DIR:-${${(%):-%x}:A:h}}\nif (( ! $+__p9k_locale )); then\n  (( $+commands[locale] )) || return\nfi\n(( $+functions[_p9k_setup] )) && _p9k_setup\n"
	output, changed := normalize_zsh_preparse_parser_safety(input)
	defer delete(output)

	testing.expect(t, changed, "Parser safety pre-normalization should rewrite zsh $+ probes and unsupported nested defaults")
	testing.expect(t, !strings.contains(output, "$+__p9k_root_dir"), "Variable probe should be rewritten for parser safety")
	testing.expect(t, !strings.contains(output, "$+__p9k_locale"), "Negated variable probe should be rewritten for parser safety")
	testing.expect(t, !strings.contains(output, "$+commands[locale]"), "Indexed commands probe should be rewritten for parser safety")
	testing.expect(t, !strings.contains(output, "$+functions[_p9k_setup]"), "Functions probe should be rewritten for parser safety")
	testing.expect(t, !strings.contains(output, "${POWERLEVEL9K_INSTALLATION_DIR:-${${(%):-%x}:A:h}}"), "Nested default expansion should be rewritten for parser safety")
	testing.expect(t, strings.contains(output, "[ -n \"${commands[locale]+1}\" ] || return"), "Indexed command probe should become parser-safe test")
	testing.expect(t, strings.contains(output, "[ -n \"${functions[_p9k_setup]+1}\" ] && _p9k_setup"), "Function probe should become parser-safe test")
	testing.expect(t, strings.contains(output, "if [ -z \"${__p9k_locale+1}\" ]; then"), "Negated probe should become parser-safe if test")
	testing.expect(t, strings.contains(output, "__p9k_root_dir=$POWERLEVEL9K_INSTALLATION_DIR"), "Powerlevel10k root dir assignment should use parser-safe fallback expression")

	fe := frontend.create_frontend(.Zsh)
	defer frontend.destroy_frontend(&fe)
	tree, parse_err := frontend.parse(&fe, output)
	testing.expect(t, parse_err.error == .None && tree != nil, "Normalized parser-safety output should parse in zsh frontend")
	if parse_err.error == .None && tree != nil {
		defer frontend.destroy_tree(tree)
		diags := frontend.collect_parse_diagnostics(tree, output, "<input>")
		defer delete(diags)
		testing.expect(t, len(diags) == 0, fmt.tprintf("Expected no zsh frontend parse diagnostics after parser-safety normalization, got %d", len(diags)))
	}
}

@(test)
test_normalize_fish_preparse_parser_safety_open_paren_literal :: proc(t: ^testing.T) {
	if !should_run_test("test_normalize_fish_preparse_parser_safety_open_paren_literal") { return }

	input := "set --global autopair_left \"(\" \"[\" \"{\" '\"' \"'\"\n"
	fe := frontend.create_frontend(.Fish)
	defer frontend.destroy_frontend(&fe)

	tree_in, parse_err_in := frontend.parse(&fe, input)
	testing.expect(t, parse_err_in.error == .None && tree_in != nil, "Original fish snippet should parse to tree for diagnostics collection")
	if parse_err_in.error == .None && tree_in != nil {
		defer frontend.destroy_tree(tree_in)
		diags_in := frontend.collect_parse_diagnostics(tree_in, input, "<input>")
		defer delete(diags_in)
		testing.expect(t, len(diags_in) > 0, "Original fish snippet should reproduce parser diagnostic signature")
	}

	output, changed := normalize_fish_preparse_parser_safety(input)
	defer delete(output)
	testing.expect(t, changed, "Fish parser-safety normalization should rewrite quoted open-paren literal")
	testing.expect(t, strings.contains(output, "'('"), "Open-paren literal should be canonicalized to single-quoted form")
	testing.expect(t, !strings.contains(output, "\"(\""), "Double-quoted open-paren literal should be removed from parse source")

	tree_out, parse_err_out := frontend.parse(&fe, output)
	testing.expect(t, parse_err_out.error == .None && tree_out != nil, "Normalized fish snippet should parse to tree")
	if parse_err_out.error == .None && tree_out != nil {
		defer frontend.destroy_tree(tree_out)
		diags_out := frontend.collect_parse_diagnostics(tree_out, output, "<input>")
		defer delete(diags_out)
		testing.expect(t, len(diags_out) == 0, fmt.tprintf("Expected no fish parse diagnostics after normalization, got %d", len(diags_out)))
	}
}

@(test)
test_normalize_bash_preparse_array_literals_skips_complex_expansion :: proc(t: ^testing.T) {
	if !should_run_test("test_normalize_bash_preparse_array_literals_skips_complex_expansion") { return }

	input := `completions=("${completions[@]##complete -* * -}") # strip all but last option plus trigger(s)`
	output, changed := normalize_bash_preparse_array_literals(input)
	defer delete(output)

	testing.expect(t, !changed, "Complex/commented Bash array expansions should be left untouched by preparse normalization")
	testing.expect(t, output == input, "Normalization should preserve complex Bash completion expansion line verbatim")
}

@(test)
test_translate_bash_complex_array_expansion_no_parse_diag :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_bash_complex_array_expansion_no_parse_diag") { return }

	input := "completions=(\"${completions[@]##complete -* * -}\") # strip all but last option plus trigger(s)\n"

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.source_name = "bash_complex_array_expansion"
	opts.insert_shims = true

	tr_fish := translate(input, .Bash, .Fish, opts)
	defer destroy_translation_result(&tr_fish)
	testing.expect(t, tr_fish.success, "Bash->Fish translation should succeed for complex completion expansion line")
	for w in tr_fish.warnings {
		testing.expect(t, !strings.contains(w, "Parse diagnostic"), "Bash->Fish should not emit parse diagnostics for complex completion expansion line")
	}

	tr_posix := translate(input, .Bash, .POSIX, opts)
	defer destroy_translation_result(&tr_posix)
	testing.expect(t, tr_posix.success, "Bash->POSIX translation should succeed for complex completion expansion line")
	for w in tr_posix.warnings {
		testing.expect(t, !strings.contains(w, "Parse diagnostic"), "Bash->POSIX should not emit parse diagnostics for complex completion expansion line")
	}
}

@(test)
test_rewrite_posix_array_bridge_callsites_skips_multiline_quoted_blocks :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_posix_array_bridge_callsites_skips_multiline_quoted_blocks") { return }

	input := `echo "function _wrap {
  local compl_word=${2?}
  COMP_WORDS=("$alias_cmd" $(printf "%q " "${alias_arg_words[@]}") "${COMP_WORDS[@]:1}")
}" >> "$tmp_file"`

	output, changed := rewrite_posix_array_bridge_callsites(input)
	defer delete(output)
	testing.expect(t, !changed, "Array bridge rewrite should not touch array-like text inside multiline quoted blocks")
	testing.expect(t, output == input, "Quoted block content should remain byte-identical")
}

@(test)
test_rewrite_fish_to_posix_syntax_rewrites_status_is_interactive :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_fish_to_posix_syntax_rewrites_status_is_interactive") { return }

	input := "status is-interactive || exit"
	output, changed := rewrite_fish_to_posix_syntax(input, .Bash)
	defer delete(output)

	testing.expect(t, changed, "Fish status is-interactive should be rewritten for sh-like targets")
	testing.expect(t, strings.contains(output, "if ! [ -t 1 ]; then return 0; fi"), "status is-interactive should become sourced-safe interactive-tty check")
	testing.expect(t, !strings.contains(output, "status is-interactive"), "Fish status builtin should not leak into bash/posix output")
}

@(test)
test_rewrite_fish_to_posix_syntax_status_interactive_exit_to_return :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_fish_to_posix_syntax_status_interactive_exit_to_return") { return }

	input := "status is-interactive || exit"
	output, changed := rewrite_fish_to_posix_syntax(input, .POSIX)
	defer delete(output)

	testing.expect(t, changed, "Fish interactive guard should be rewritten for sourced plugin semantics")
	testing.expect(t, strings.contains(output, "if ! [ -t 1 ]; then return 0; fi"), "status interactive exit guard should become non-fatal return for sourced sh code")
}

@(test)
test_rewrite_fish_to_posix_syntax_guards_fish_key_bindings_callsite :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_fish_to_posix_syntax_guards_fish_key_bindings_callsite") { return }

	input := "_autopair_fish_key_bindings"
	output, changed := rewrite_fish_to_posix_syntax(input, .Bash)
	defer delete(output)

	testing.expect(t, changed, "Fish key-bindings callsite should be guarded for non-interactive sh targets")
	testing.expect(t, strings.contains(output, "[ -t 1 ] && _autopair_fish_key_bindings || true"), "Key-binding callsite should be interactive-guarded without introducing block-balance side effects")
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
test_rewrite_zsh_tide_colon_structural_noops :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_zsh_tide_colon_structural_noops") { return }

	input := "if true; then\n:\nfi\n:\n"
	output, changed := rewrite_zsh_tide_colon_structural_noops(input)
	defer delete(output)

	testing.expect(t, changed, "colon structural pass should normalize colon-only lines")
	testing.expect(t, strings.contains(output, "true"), "colon-only lines inside control/function scope should become true")
	testing.expect(t, strings.contains(output, "\n:"), "top-level colon-only lines should remain shell no-op")
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
test_normalize_posix_preparse_array_literals :: proc(t: ^testing.T) {
	if !should_run_test("test_normalize_posix_preparse_array_literals") { return }

	input := "declare -a arr=(one two three)\ntypeset -a zs=(red blue)\narr2=(x y)"
	output, changed := normalize_posix_preparse_array_literals(input)
	defer delete(output)

	testing.expect(t, changed, "POSIX preparse normalization should rewrite array declarations/assignments")
	testing.expect(t, strings.contains(output, "__shellx_list_set arr one two three"), "declare -a assignment should lower to list_set shim")
	testing.expect(t, strings.contains(output, "__shellx_list_set zs red blue"), "typeset -a assignment should lower to list_set shim")
	testing.expect(t, strings.contains(output, "__shellx_list_set arr2 x y"), "plain array literal assignment should lower to list_set shim")
}

@(test)
test_rewrite_posix_array_bridge_callsites_multiline_and_append :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_posix_array_bridge_callsites_multiline_and_append") { return }

	input := "urls=(\n  google\n  github\n)\nenvironment+=( PATH=\"$HOME/bin\" )\nempty_append+=()\nempty_set=()\n[[ true ]] || opts+=('aliases')\nregion_highlight[-1]=()"
	output, changed := rewrite_posix_array_bridge_callsites(input)
	defer delete(output)

	testing.expect(t, changed, "Multiline and append array forms should lower to POSIX list bridge shims")
	testing.expect(t, strings.contains(output, "__shellx_list_set urls google github"), "Multiline array assignment should lower to list_set shim")
	testing.expect(t, strings.contains(output, "__shellx_list_append environment PATH=\"$HOME/bin\""), "Inline append should lower to list_append shim")
	testing.expect(t, strings.contains(output, "__shellx_list_append empty_append"), "Empty append should still lower to list_append shim")
	testing.expect(t, strings.contains(output, "__shellx_list_set empty_set"), "Empty assignment should lower to list_set shim")
	testing.expect(t, strings.contains(output, "[[ true ]] || __shellx_list_append opts 'aliases'"), "Conditional append segment should lower to list_append shim")
	testing.expect(t, strings.contains(output, "__shellx_list_unset_index region_highlight -1"), "Indexed unset assignment should lower to list_unset_index shim")
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
test_rewrite_parameter_expansion_callsites_to_posix_basic_forms :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_parameter_expansion_callsites_to_posix_basic_forms") { return }

	input := `echo ${v//a/b} ${v/#pre/x} ${v/%suf/y} ${v:1:2}`
	output, changed := rewrite_parameter_expansion_callsites(input, .POSIX)
	defer delete(output)

	testing.expect(t, changed, "POSIX parameter expansion rewrite should transform unsupported substitution/slice forms")
	testing.expect(t, strings.contains(output, `sed 's|a|b|g'`), "global replacement should lower to sed")
	testing.expect(t, strings.contains(output, `sed 's|^pre|x|'`), "prefix replacement should lower to anchored sed")
	testing.expect(t, strings.contains(output, `sed 's|suf$|y|'`), "suffix replacement should lower to anchored sed")
	testing.expect(t, strings.contains(output, `cut -c$((1 + 1))-$((1 + 2))`), "slice expansion should lower to cut range")
}

@(test)
test_semantic_param_replace_and_slice_bash_to_posix_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_param_replace_and_slice_bash_to_posix_runtime") { return }
	source := `v="preaabsuf"
echo ${v//a/b}
echo ${v/#pre/x}
echo ${v/%suf/y}
echo ${v:1:3}`
	out, ok := run_translated_script_runtime(t, source, .Bash, .POSIX, "param_replace_and_slice_bash_to_posix_runtime")
	if !ok { return }
	testing.expect(t, out == "prebbbsuf\nxaabsuf\npreaaby\nrea", "POSIX lowering should preserve replacement and slice semantics")
}

@(test)
test_rewrite_posix_array_parameter_expansions_bash :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_posix_array_parameter_expansions_bash") { return }

	input := `echo ${arr[1]} ${#arr[@]} ${#arr[1]} ${arr[@]}`
	output, changed := rewrite_posix_array_parameter_expansions(input, .Bash)
	defer delete(output)

	testing.expect(t, changed, "Bash array expansions should lower to POSIX list shim calls")
	testing.expect(t, strings.contains(output, "$(__shellx_list_get arr 2)"), "Bash index should shift to POSIX list index")
	testing.expect(t, strings.contains(output, "$(__shellx_list_len arr)"), "Bash array length should lower to list_len shim")
	testing.expect(t, strings.contains(output, "printf '%s' \"$(__shellx_list_get arr \"2\")\" | wc -c"), "Bash element length should lower to list_get+wc shim pipeline")
	testing.expect(t, strings.contains(output, "${arr}") || strings.contains(output, "$arr"), "Bash full array expansion should lower to scalar list text")
}

@(test)
test_rewrite_posix_array_parameter_expansions_zsh :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_posix_array_parameter_expansions_zsh") { return }

	input := `echo ${arr[2]} ${#arr[@]} ${#arr[2]}`
	output, changed := rewrite_posix_array_parameter_expansions(input, .Zsh)
	defer delete(output)

	testing.expect(t, changed, "Zsh array expansions should lower to POSIX list shim calls")
	testing.expect(t, strings.contains(output, "$(__shellx_list_get arr 2)"), "Zsh index should keep one-based semantics in POSIX shim")
	testing.expect(t, strings.contains(output, "$(__shellx_list_len arr)"), "Zsh array length should lower to list_len shim")
	testing.expect(t, strings.contains(output, "printf '%s' \"$(__shellx_list_get arr \"2\")\" | wc -c"), "Zsh element length should lower to list_get+wc shim pipeline")
}

@(test)
test_rewrite_posix_array_parameter_expansions_string_context :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_posix_array_parameter_expansions_string_context") { return }

	input := `echo "X${arr[1]}Y"`
	output, changed := rewrite_posix_array_parameter_expansions(input, .Bash)
	defer delete(output)

	testing.expect(t, changed, "Indexed expansion inside string context should lower to list_get shim")
	testing.expect(t, strings.contains(output, `echo "X$(__shellx_list_get arr 2)Y"`), "String-context indexed expansion should preserve index-aware list_get call")
}

@(test)
test_rewrite_posix_array_parameter_expansions_zsh_subscript_r :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_posix_array_parameter_expansions_zsh_subscript_r") { return }

	input := `if [[ -n ${ZSH_AUTOSUGGEST_CLEAR_WIDGETS[(r)$widget]} ]]; then :; fi`
	output, changed := rewrite_posix_array_parameter_expansions(input, .Zsh)
	defer delete(output)

	testing.expect(t, changed, "Zsh (r) subscript flags should lower to POSIX shim call")
	testing.expect(t, strings.contains(output, "__shellx_zsh_subscript_r ZSH_AUTOSUGGEST_CLEAR_WIDGETS \"$widget\""), "Zsh (r) array lookup should canonicalize to subscript shim")
	testing.expect(t, !strings.contains(output, "(r)$widget"), "Raw zsh subscript flags should not remain in POSIX output")
}

@(test)
test_rewrite_posix_array_parameter_expansions_zsh_subscript_Ib :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_posix_array_parameter_expansions_zsh_subscript_Ib") { return }

	input := `(( min = ${BUFFER[(Ib:min:)$needle]} ))`
	output, changed := rewrite_posix_array_parameter_expansions(input, .Zsh)
	defer delete(output)

	testing.expect(t, changed, "Zsh (Ib:...:) subscript flags should lower to POSIX shim call")
	testing.expect(t, strings.contains(output, "__shellx_zsh_subscript_Ib BUFFER \"$needle\" \"min\""), "Zsh (Ib:min:) lookup should canonicalize to Ib shim")
	testing.expect(t, !strings.contains(output, "(Ib:min:)$needle"), "Raw zsh Ib subscript flags should not remain in POSIX output")
}

@(test)
test_rewrite_posix_array_parameter_expansions_zsh_plus_probes :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_posix_array_parameter_expansions_zsh_plus_probes") { return }

	input := `(( ${commands[fzf]+1} )) && (( $+commands[brew] )) && (( ${+commands[apt]} ))`
	output, changed := rewrite_posix_array_parameter_expansions(input, .Zsh)
	defer delete(output)

	testing.expect(t, changed, "Zsh +1 / $+ probes should lower to list_has shim calls")
	testing.expect(t, strings.contains(output, "$(__shellx_list_has commands \"fzf\")"), "${commands[fzf]+1} should lower to list_has")
	testing.expect(t, strings.contains(output, "$(__shellx_list_has commands \"brew\")"), "$+commands[brew] should lower to list_has")
	testing.expect(t, strings.contains(output, "$(__shellx_list_has commands \"apt\")"), "${+commands[apt]} should lower to list_has")
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
test_semantic_array_list_fish_to_zsh_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_array_list_fish_to_zsh_runtime") { return }
	source := `set arr one two three
echo $arr[2]`
	out, ok := run_translated_script_runtime(t, source, .Fish, .Zsh, "array_list_fish_to_zsh_runtime")
	if !ok { return }
	testing.expect(t, out == "two", "Fish list indexing should preserve semantic value in Zsh output")
}

@(test)
test_semantic_array_list_fish_dynamic_index_to_bash_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_array_list_fish_dynamic_index_to_bash_runtime") { return }
	source := `set arr red blue green
set i (echo 2)
echo $arr[$i]`
	out, ok := run_translated_script_runtime(t, source, .Fish, .Bash, "array_list_fish_dynamic_index_to_bash_runtime")
	if !ok { return }
	testing.expect(t, out == "blue", "Fish dynamic list indexing should preserve semantic value in Bash output")
}

@(test)
test_translate_bash_indexed_array_to_posix_uses_shim_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_bash_indexed_array_to_posix_uses_shim_api") { return }
	source := `arr=(one two three)
echo ${arr[1]}
echo ${#arr[@]}`
	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	result := translate(source, .Bash, .POSIX, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Bash indexed arrays should translate to POSIX with shim bridge")
	testing.expect(t, strings.contains(result.output, "__shellx_list_set arr one two three"), "Bash array assignment should lower to list_set shim")
	testing.expect(t, strings.contains(result.output, "$(__shellx_list_get arr 2)"), "Bash indexed expansion should lower to list_get shim")
	testing.expect(t, strings.contains(result.output, "$(__shellx_list_len arr)"), "Bash array length should lower to list_len shim")
	for w in result.warnings {
		testing.expect(t, !strings.contains(w, "Compat[indexed_arrays]"), "indexed_arrays warning should be resolved for shim-backed POSIX output")
	}
}

@(test)
test_semantic_array_list_bash_to_posix_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_array_list_bash_to_posix_runtime") { return }
	source := `arr=(one two three)
echo ${arr[1]}
echo ${#arr[1]}
echo ${#arr[@]}`
	out, ok := run_translated_script_runtime(t, source, .Bash, .POSIX, "array_list_bash_to_posix_runtime")
	if !ok { return }
	testing.expect(t, out == "two\n3\n3", "Bash indexed arrays should preserve semantic index/length behavior in POSIX output")
}

@(test)
test_semantic_array_list_zsh_to_posix_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_array_list_zsh_to_posix_runtime") { return }
	source := `arr=(one two three)
echo ${arr[2]}
echo ${#arr[2]}
echo ${#arr[@]}`
	out, ok := run_translated_script_runtime(t, source, .Zsh, .POSIX, "array_list_zsh_to_posix_runtime")
	if !ok { return }
	testing.expect(t, out == "two\n3\n3", "Zsh indexed arrays should preserve semantic index/length behavior in POSIX output")
}

@(test)
test_semantic_array_empty_index_set_bash_to_posix_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_array_empty_index_set_bash_to_posix_runtime") { return }
	source := `arr=(one two)
arr[1]=
echo "<${arr[1]}>"
echo ${#arr[@]}`
	out, ok := run_translated_script_runtime(t, source, .Bash, .POSIX, "array_empty_index_set_bash_to_posix_runtime")
	if !ok { return }
	testing.expect(t, out == "<>\n2", "Empty indexed assignment should preserve empty element semantics in POSIX output")
}

@(test)
test_semantic_array_append_zsh_to_posix_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_array_append_zsh_to_posix_runtime") { return }
	source := `arr=(one)
arr+=(two)
echo ${arr[2]}`
	out, ok := run_translated_script_runtime(t, source, .Zsh, .POSIX, "array_append_zsh_to_posix_runtime")
	if !ok { return }
	testing.expect(t, out == "two", "Zsh array append should preserve element semantics in POSIX output via list bridge")
}

@(test)
test_semantic_array_unset_index_zsh_to_posix_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_array_unset_index_zsh_to_posix_runtime") { return }
	source := `arr=(one two three)
arr[-1]=()
echo ${arr[2]}
echo ${#arr[@]}`
	out, ok := run_translated_script_runtime(t, source, .Zsh, .POSIX, "array_unset_index_zsh_to_posix_runtime")
	if !ok { return }
	testing.expect(t, out == "two\n2", "Zsh indexed unset should preserve list element and length behavior in POSIX output")
}

@(test)
test_translate_zsh_subscript_flags_to_posix_parse_safe :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_zsh_subscript_flags_to_posix_parse_safe") { return }
	source := `arr=(alpha beta gamma)
widget='*ta*'
needle=ta
echo ${arr[(r)$widget]}
echo ${arr[(Ib:min:)$needle]}`
	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	result := translate(source, .Zsh, .POSIX, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Zsh subscript flags should translate to POSIX")
	testing.expect(t, strings.contains(result.output, "__shellx_zsh_subscript_r arr"), "POSIX output should include r-subscript shim callsite")
	testing.expect(t, strings.contains(result.output, "__shellx_zsh_subscript_Ib arr"), "POSIX output should include Ib-subscript shim callsite")
	parser_check_snippet(t, result.output, .POSIX, "zsh_subscript_flags_to_posix_parse_safe")
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
test_translate_zsh_assoc_lookup_to_fish_uses_array_get_shim :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_zsh_assoc_lookup_to_fish_uses_array_get_shim") { return }
	source := `typeset -A m
m[foo]=bar
echo ${m[$k]}`
	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	result := translate(source, .Zsh, .Fish, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Translation should succeed for zsh assoc lookup to fish")
	testing.expect(t, strings.contains(result.output, "__shellx_array_get m"), "Assoc-style index lookup should lower to array_get shim call")
	testing.expect(t, strings.contains(result.output, "function __shellx_array_get"), "Fish shim prelude should include array_get helper")
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
test_semantic_hook_multi_precmd_zsh_to_bash_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_hook_multi_precmd_zsh_to_bash_runtime") { return }
	source := `h1() { echo one; }
h2() { echo two; }
add-zsh-hook precmd h1
add-zsh-hook precmd h2
__shellx_run_precmd`
	out, ok := run_translated_script_runtime(t, source, .Zsh, .Bash, "hook_multi_precmd_zsh_to_bash_runtime")
	if !ok { return }
	testing.expect(t, out == "one\ntwo", "Hook bridge should preserve multiple precmd registrations in order")
}

@(test)
test_semantic_hook_fish_prompt_event_to_bash_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_hook_fish_prompt_event_to_bash_runtime") { return }
	source := `function __evt_prompt --on-event fish_prompt
  echo prompt
end
__shellx_run_precmd`
	out, ok := run_translated_script_runtime(t, source, .Fish, .Bash, "hook_fish_prompt_event_to_bash_runtime")
	if !ok { return }
	testing.expect(t, out == "prompt", "Fish prompt event handlers should register as precmd hooks in Bash output")
}

@(test)
test_semantic_hook_fish_preexec_event_to_bash_runtime :: proc(t: ^testing.T) {
	if !should_run_test("test_semantic_hook_fish_preexec_event_to_bash_runtime") { return }
	source := `function __evt_preexec --on-event fish_preexec
  echo preexec
end
__shellx_run_preexec cmd`
	out, ok := run_translated_script_runtime(t, source, .Fish, .Bash, "hook_fish_preexec_event_to_bash_runtime")
	if !ok { return }
	testing.expect(t, strings.contains(out, "preexec"), "Fish preexec event handlers should register as preexec hooks in Bash output")
}

@(test)
test_translate_fish_prompt_event_to_posix_shim_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_fish_prompt_event_to_posix_shim_api") { return }

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	src := `function __evt_prompt --on-event fish_prompt
  echo prompt
end
__shellx_run_precmd`

	result := translate(src, .Fish, .POSIX, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Fish prompt event should translate to POSIX with hook shim")
	testing.expect(t, strings.contains(result.output, "__shellx_register_precmd __evt_prompt"), "POSIX output should register prompt hook callback")
	testing.expect(t, strings.contains(result.output, "__shellx_run_precmd"), "POSIX output should include precmd dispatcher")
	for w in result.warnings {
		testing.expect(t, !strings.contains(w, "Compat[prompt_hooks]"), "Prompt hook compatibility warning should be resolved by shim bridge")
	}
}

@(test)
test_translate_fish_prompt_function_to_posix_shim_api :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_fish_prompt_function_to_posix_shim_api") { return }

	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	src := `function fish_prompt
  echo prompt
end
__shellx_run_precmd`

	result := translate(src, .Fish, .POSIX, opts)
	defer destroy_translation_result(&result)

	testing.expect(t, result.success, "Fish prompt function should translate to POSIX with hook shim")
	testing.expect(t, strings.contains(result.output, "fish_prompt() {"), "POSIX output should preserve fish_prompt function body as callable hook function")
	testing.expect(t, strings.contains(result.output, "__shellx_run_precmd"), "POSIX output should include precmd dispatcher")
	for w in result.warnings {
		testing.expect(t, !strings.contains(w, "Compat[prompt_hooks]"), "Prompt hook compatibility warning should be resolved by shim-backed prompt function dispatch")
	}
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
test_translate_fish_zsh_prompt_bridge_polyfill :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_fish_zsh_prompt_bridge_polyfill") { return }

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
	testing.expect(t, !strings.contains(result.output, "fish_prompt() { :; }"), "Output should not replace fish_prompt with no-op")
	testing.expect(t, strings.contains(result.output, "__shellx_run_precmd"), "Hook bridge shim should be present")
	testing.expect(t, strings.contains(result.output, "command -v fish_prompt"), "Hook bridge should call fish_prompt when available")
}

@(test)
test_lowering_validator_rejects_zsh_split_args_non_zsh :: proc(t: ^testing.T) {
	if !should_run_test("test_lowering_validator_rejects_zsh_split_args_non_zsh") { return }

	output := "for entry in ${@s/\\n/line}; do\n  :\ndone\n"
	issue, has := validate_lowered_output_structure(output, .Bash, "<test>")
	testing.expect(t, has, "Lowering validator should reject leaked zsh split-args syntax in bash output")
	if has {
		testing.expect(t, issue.rule_id == "lowering.zsh.split_args_non_zsh", "Rule id should identify zsh split-args leak")
	}
}

@(test)
test_lowering_validator_rejects_fish_setq_in_bash_output :: proc(t: ^testing.T) {
	if !should_run_test("test_lowering_validator_rejects_fish_setq_in_bash_output") { return }

	output := "if set -q async_prompt_functions; then\n  :\nfi\n"
	issue, has := validate_lowered_output_structure(output, .Bash, "<test>")
	testing.expect(t, has, "Lowering validator should reject leaked fish set -q syntax in bash output")
	if has {
		testing.expect(t, issue.rule_id == "lowering.fish.setq_non_fish", "Rule id should identify fish set -q leak")
	}
}

@(test)
test_rewrite_final_nonfish_structural_safety_case_labels :: proc(t: ^testing.T) {
	if !should_run_test("test_rewrite_final_nonfish_structural_safety_case_labels") { return }

	input := "nvm() {\n  case $1 in\n    'upgrade'\n      echo u\n      ;;\n  esac\n}\n"
	output, changed := rewrite_final_nonfish_structural_safety(input)
	defer delete(output)
	testing.expect(t, changed, "final non-fish safety pass should rewrite quoted case labels")
	testing.expect(t, strings.contains(output, "'upgrade')"), "quoted case label should be normalized to pattern)")
}

@(test)
test_translate_corpus_zsh_nvm_case_label_normalized :: proc(t: ^testing.T) {
	if !should_run_test("test_translate_corpus_zsh_nvm_case_label_normalized") { return }
	path := "tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh"
	if !os.is_file(path) {
		return
	}
	data, ok := os.read_entire_file(path)
	testing.expect(t, ok, "Should read zsh-nvm corpus plugin")
	if !ok {
		return
	}
	defer delete(data)
	opts := DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	result := translate(string(data), .Zsh, .Bash, opts)
	defer destroy_translation_result(&result)
	testing.expect(t, result.success, "zsh-nvm should translate")
	testing.expect(t, strings.contains(result.output, "'upgrade')"), "Case arm should preserve ')' in bash output")
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

@(test)
test_scan_security_builtin_api :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_builtin_api") { return }

	src := "curl -fsSL https://example.com/install.sh | sh\n"
	result := scan_security(src, .Bash)
	defer destroy_security_scan_result(&result)

	testing.expect(t, result.success, "scan_security should succeed")
	testing.expect(t, result.blocked, "critical builtin finding should block by default")
	testing.expect(t, len(result.findings) > 0, "scan_security should emit findings")
}

@(test)
test_scan_security_custom_rules_api :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_custom_rules_api") { return }

	rules := []SecurityScanRule{
		{
			rule_id = "zephyr.custom.source_tmp",
			severity = .High,
			pattern = "/tmp/",
			message = "Sourcing from temporary path detected",
			suggestion = "Use a trusted immutable module path",
		},
	}
	policy := DEFAULT_SECURITY_SCAN_POLICY
	policy.custom_rules = rules

	result := scan_security("source /tmp/plugin.sh\n", .Bash, policy)
	defer destroy_security_scan_result(&result)

	testing.expect(t, result.success, "custom scan should succeed")
	testing.expect(t, result.blocked, "custom high-severity rule should block")
	testing.expect(t, len(result.findings) >= 1, "custom rule should produce findings")
}

@(test)
test_scan_security_file_api :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_file_api") { return }

	path := "/tmp/shellx_scan_api_case.sh"
	script := "chmod 777 /tmp/a\n"
	ok := os.write_entire_file(path, transmute([]byte)script)
	testing.expect(t, ok, "scan fixture should be writable")
	if !ok {
		return
	}
	defer os.remove(path)

	result := scan_security_file(path, .Bash)
	defer destroy_security_scan_result(&result)

	testing.expect(t, result.success, "scan_security_file should succeed")
	testing.expect(t, len(result.findings) > 0, "scan_security_file should emit findings")
}

@(test)
test_scan_security_regex_and_invalid_regex :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_regex_and_invalid_regex") { return }

	policy := DEFAULT_SECURITY_SCAN_POLICY
	policy.use_builtin_rules = false
	policy.custom_rules = []SecurityScanRule{
		{
			rule_id = "zephyr.custom.eval_regex",
			enabled = true,
			severity = .High,
			match_kind = .Regex,
			pattern = "eval\\s+",
			category = "execution",
			confidence = 0.9,
			phases = { .Source },
			message = "Eval call matched",
			suggestion = "Avoid eval",
		},
	}
	ok_result := scan_security("x=1\neval \"$x\"\n", .Bash, policy)
	defer destroy_security_scan_result(&ok_result)
	testing.expect(t, ok_result.success, "valid regex rule should succeed")
	testing.expect(t, len(ok_result.findings) >= 1, "valid regex should match eval line")

	bad_policy := policy
	bad_policy.custom_rules = []SecurityScanRule{
		{
			rule_id = "zephyr.custom.bad_regex",
			enabled = true,
			severity = .High,
			match_kind = .Regex,
			pattern = "(",
			message = "Bad regex",
			suggestion = "Fix regex",
		},
	}
	bad_result := scan_security("eval hi\n", .Bash, bad_policy)
	defer destroy_security_scan_result(&bad_result)
	testing.expect(t, !bad_result.success, "invalid regex should mark scan runtime failure")
	testing.expect(t, len(bad_result.errors) > 0, "invalid regex should produce runtime error context")
}

@(test)
test_scan_security_ast_command_detection :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_ast_command_detection") { return }
	src := "eval \"echo hi\"\nsource /tmp/plugin.sh\ncurl https://x | sh\n"
	result := scan_security(src, .Bash)
	defer destroy_security_scan_result(&result)
	testing.expect(t, result.success, "ast detection scan should succeed")
	has_ast_eval := false
	has_ast_source := false
	for finding in result.findings {
		if finding.rule_id == "sec.ast.eval" {
			has_ast_eval = true
		}
		if finding.rule_id == "sec.ast.source" {
			has_ast_source = true
		}
	}
	testing.expect(t, has_ast_eval, "ast scan should detect eval command")
	testing.expect(t, has_ast_source, "ast scan should detect source command")
}

@(test)
test_scan_security_overrides_and_allowlist :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_overrides_and_allowlist") { return }

	policy := DEFAULT_SECURITY_SCAN_POLICY
	policy.use_builtin_rules = false
	policy.custom_rules = []SecurityScanRule{
		{
			rule_id = "zephyr.custom.tmp_path",
			enabled = true,
			severity = .Critical,
			match_kind = .Substring,
			pattern = "/tmp/",
			category = "source",
			confidence = 0.8,
			phases = { .Source },
			message = "Tmp path usage",
			suggestion = "Avoid /tmp source",
		},
	}
	policy.rule_overrides = []SecurityRuleOverride{
		{
			rule_id = "zephyr.custom.tmp_path",
			enabled = true,
			severity_override = .Warning,
			has_severity_override = true,
		},
	}
	policy.block_threshold = .High
	policy.allowlist_paths = []string{"/tmp/trusted_plugins"}

	opts := DEFAULT_SECURITY_SCAN_OPTIONS
	result := scan_security("source /tmp/plugin.sh\n", .Bash, policy, "/tmp/trusted_plugins/demo.sh", opts)
	defer destroy_security_scan_result(&result)
	testing.expect(t, result.success, "allowlisted path scan should succeed")
	testing.expect(t, len(result.findings) == 0, "allowlisted path should suppress findings")

	result2 := scan_security("source /tmp/plugin.sh\n", .Bash, policy, "/tmp/untrusted/demo.sh", opts)
	defer destroy_security_scan_result(&result2)
	testing.expect(t, result2.success, "non-allowlisted scan should succeed")
	testing.expect(t, len(result2.findings) >= 1, "non-allowlisted path should keep findings")
	testing.expect(t, !result2.blocked, "severity override to warning should not block at high threshold")
}

@(test)
test_scan_security_options_and_batch_and_json :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_options_and_batch_and_json") { return }
	opts := DEFAULT_SECURITY_SCAN_OPTIONS
	opts.max_file_size = 8
	too_large := scan_security("curl https://x | sh\n", .Bash, DEFAULT_SECURITY_SCAN_POLICY, "<input>", opts)
	defer destroy_security_scan_result(&too_large)
	testing.expect(t, !too_large.success, "max_file_size should fail runtime scan")
	testing.expect(t, too_large.error == .ScanMaxFileSizeExceeded, "max_file_size should set dedicated scan error")

	file1 := "/tmp/shellx_scan_batch_1.sh"
	file2 := "/tmp/shellx_scan_batch_2.sh"
	content1 := "curl https://x | sh\n"
	content2 := "echo safe\n"
	ok1 := os.write_entire_file(file1, transmute([]byte)content1)
	ok2 := os.write_entire_file(file2, transmute([]byte)content2)
	testing.expect(t, ok1 && ok2, "batch fixtures should be writable")
	if !ok1 || !ok2 {
		return
	}
	defer os.remove(file1)
	defer os.remove(file2)

	batch := scan_security_batch([]string{file1, file2}, .Bash)
	defer destroy_security_scan_batch(&batch)
	testing.expect(t, len(batch) == 2, "scan_security_batch should return item per file")
	testing.expect(t, batch[0].result.stats.files_scanned == 1, "batch item should include per-file stats")

	blob := format_security_scan_json(batch[0].result, true)
	defer delete(blob)
	testing.expect(t, strings.contains(blob, "\"ruleset_version\""), "json formatter should include ruleset_version")
	blob_batch := format_security_scan_batch_json(batch[:], true)
	defer delete(blob_batch)
	testing.expect(t, strings.contains(blob_batch, "\"filepath\""), "batch json formatter should include file paths")
}

@(test)
test_scan_security_adversarial_corpus_samples :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_adversarial_corpus_samples") { return }
	cases := []string{
		"tests/corpus/security/escaped_pipe.sh",
		"tests/corpus/security/nested_cmdsub.sh",
		"tests/corpus/security/obfuscated_eval.sh",
		"tests/corpus/security/multiline_mutation.sh",
		"tests/corpus/security/string_concat_payload.sh",
		"tests/corpus/security/escaped_heredoc_exec.sh",
		"tests/corpus/security/split_eval_tokens.sh",
		"tests/corpus/security/source_process_subst.sh",
		"tests/corpus/security/shell_dash_c_dynamic.sh",
	}
	for p in cases {
		result := scan_security_file(p, .Bash)
		testing.expect(t, result.success, fmt.tprintf("adversarial sample should scan successfully: %s", p))
		testing.expect(t, len(result.findings) > 0, fmt.tprintf("adversarial sample should produce findings: %s", p))
		destroy_security_scan_result(&result)
	}
}

@(test)
test_scan_security_ast_parse_fallback_modes :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_ast_parse_fallback_modes") { return }
	src := "<<<\n"
	open_opts := DEFAULT_SECURITY_SCAN_OPTIONS
	open_opts.ast_parse_failure_mode = .FailOpen
	open_result := scan_security(src, .Bash, DEFAULT_SECURITY_SCAN_POLICY, "<input>", open_opts)
	defer destroy_security_scan_result(&open_result)
	testing.expect(t, open_result.success, "fail-open ast parse should keep success=true")
	testing.expect(t, len(open_result.errors) > 0, "fail-open ast parse should append runtime error context")

	closed_opts := DEFAULT_SECURITY_SCAN_OPTIONS
	closed_opts.ast_parse_failure_mode = .FailClosed
	closed_result := scan_security(src, .Bash, DEFAULT_SECURITY_SCAN_POLICY, "<input>", closed_opts)
	defer destroy_security_scan_result(&closed_result)
	testing.expect(t, !closed_result.success, "fail-closed ast parse should set success=false")
	testing.expect(t, len(closed_result.errors) > 0, "fail-closed ast parse should append runtime error context")
}

@(test)
test_scan_security_policy_validate_and_load :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_policy_validate_and_load") { return }
	p := DEFAULT_SECURITY_SCAN_POLICY
	p.custom_rules = []SecurityScanRule{
		{
			rule_id = "",
			enabled = true,
			severity = .High,
			match_kind = .Regex,
			pattern = "(",
			confidence = 1.5,
			message = "bad",
		},
	}
	errs := validate_security_policy(p)
	defer {
		for e in errs {
			delete(e.rule_id)
			delete(e.message)
			delete(e.suggestion)
			delete(e.snippet)
		}
		delete(errs)
	}
	testing.expect(t, len(errs) >= 2, "policy validator should return multiple actionable errors")

	json_data := `{
		"use_builtin_rules": true,
		"block_threshold": "High",
		"ruleset_version": "zephyr-policy-test",
		"custom_rules": [{
			"rule_id": "zephyr.r1",
			"enabled": true,
			"severity": "High",
			"match_kind": "Substring",
			"pattern": "eval ",
			"category": "execution",
			"confidence": 0.9,
			"phases": ["Source"],
			"message": "m",
			"suggestion": "s"
		}]
	}`
	loaded_policy, load_errs, ok := load_security_policy_json(json_data)
	defer {
		for e in load_errs {
			delete(e.rule_id)
			delete(e.message)
			delete(e.suggestion)
			delete(e.snippet)
		}
		delete(load_errs)
		for s in loaded_policy.allowlist_paths {
			delete(s)
		}
		delete(loaded_policy.allowlist_paths)
		for s in loaded_policy.allowlist_commands {
			delete(s)
		}
		delete(loaded_policy.allowlist_commands)
		for r in loaded_policy.custom_rules {
			delete(r.rule_id)
			delete(r.pattern)
			delete(r.category)
			delete(r.command_name)
			delete(r.arg_pattern)
			delete(r.message)
			delete(r.suggestion)
		}
		delete(loaded_policy.custom_rules)
		for o in loaded_policy.rule_overrides {
			delete(o.rule_id)
		}
		delete(loaded_policy.rule_overrides)
		if loaded_policy.ruleset_version != "" {
			delete(loaded_policy.ruleset_version)
		}
	}
	testing.expect(t, ok, "valid policy JSON should load and validate")
	testing.expect(t, len(load_errs) == 0, "valid policy JSON should not produce validation errors")
}

@(test)
test_scan_security_fingerprint_contract :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_fingerprint_contract") { return }
	loc := ir.SourceLocation{file = "<input>", line = 1, column = 0, length = 6}
	fp1 := scanner_fingerprint("sec.ast.eval", loc, "eval", "source")
	defer delete(fp1)
	fp2 := scanner_fingerprint("sec.ast.eval", loc, "eval", "source")
	defer delete(fp2)
	testing.expect(t, fp1 == fp2, "fingerprint should be stable across repeated calls")
	testing.expect(t, fp1 == "28b0c697cf9e0772", "fingerprint algorithm contract changed unexpectedly")
}

@(test)
test_scan_security_allowlist_path_normalization :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_allowlist_path_normalization") { return }
	policy := DEFAULT_SECURITY_SCAN_POLICY
	policy.use_builtin_rules = false
	policy.custom_rules = []SecurityScanRule{
		{
			rule_id = "zephyr.tmp",
			enabled = true,
			severity = .High,
			match_kind = .Substring,
			pattern = "/tmp/",
			message = "tmp",
			suggestion = "avoid tmp",
		},
	}
	policy.allowlist_paths = []string{"/tmp/allowroot"}
	opts := DEFAULT_SECURITY_SCAN_OPTIONS
	allowed := scan_security("source /tmp/x\n", .Bash, policy, "/tmp/allowroot/plugin.sh", opts)
	defer destroy_security_scan_result(&allowed)
	testing.expect(t, len(allowed.findings) == 0, "allowlist should match canonical in-root path")

	bypass := scan_security("source /tmp/x\n", .Bash, policy, "/tmp/allowroot/../escape/plugin.sh", opts)
	defer destroy_security_scan_result(&bypass)
	testing.expect(t, len(bypass.findings) > 0, "allowlist should not match traversal-escaped path")
}

@(test)
test_scan_security_batch_guardrails_and_ast_signatures :: proc(t: ^testing.T) {
	if !should_run_test("test_scan_security_batch_guardrails_and_ast_signatures") { return }
	f1 := "/tmp/shellx_batch_guard_1.sh"
	f2 := "/tmp/shellx_batch_guard_2.sh"
	c1 := "bash -c \"$CMD\"\n"
	c2 := "source <(echo hi)\n"
	ok1 := os.write_entire_file(f1, transmute([]byte)c1)
	ok2 := os.write_entire_file(f2, transmute([]byte)c2)
	testing.expect(t, ok1 && ok2, "guardrail fixtures should be writable")
	if !ok1 || !ok2 { return }
	defer os.remove(f1)
	defer os.remove(f2)

	opts := DEFAULT_SECURITY_SCAN_OPTIONS
	opts.max_files = 1
	guard := scan_security_batch([]string{f1, f2}, .Bash, DEFAULT_SECURITY_SCAN_POLICY, opts)
	defer destroy_security_scan_batch(&guard)
	testing.expect(t, len(guard) == 2, "max_files guard should still return deterministic batch items")
	testing.expect(t, !guard[0].result.success, "max_files guard should mark items as runtime failures")

	opts2 := DEFAULT_SECURITY_SCAN_OPTIONS
	sig := scan_security_file(f1, .Bash, DEFAULT_SECURITY_SCAN_POLICY, opts2)
	defer destroy_security_scan_result(&sig)
	has_dash_c := false
	for finding in sig.findings {
		if finding.rule_id == "sec.ast.shell_dash_c" || finding.rule_id == "sec.ast.shell_dash_c_dynamic" {
			has_dash_c = true
		}
	}
	testing.expect(t, has_dash_c, "ast signature scan should detect shell -c dynamic risk")
}
