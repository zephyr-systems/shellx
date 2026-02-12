package unit_tests

import "../../compat"
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
test_compatibility_check_warning_generation :: proc(t: ^testing.T) {
	if !should_run_local_test("test_compatibility_check_warning_generation") { return }

	arena := ir.create_arena(1024 * 16)
	defer ir.destroy_arena(&arena)
	program := ir.create_program(&arena, .Bash)
	cond := ir.new_raw_expr(&arena, "[[ $x == y ]]")
	branch := ir.Statement{
		type = .Branch,
		branch = ir.Branch{
			condition = cond,
			then_body = make([dynamic]ir.Statement, 0, 0, context.temp_allocator),
			else_body = make([dynamic]ir.Statement, 0, 0, context.temp_allocator),
		},
	}
	ir.add_statement(program, branch)

	res := compat.check_compatibility(.Bash, .Fish, program)
	defer compat.destroy_compatibility_result(&res)

	testing.expect(t, len(res.warnings) > 0, "Bash to Fish should produce compatibility warnings")
	testing.expect(t, compat.has_warnings(&res) || compat.has_errors(&res), "Result should indicate warnings/errors")
}

@(test)
test_compatibility_format_result :: proc(t: ^testing.T) {
	if !should_run_local_test("test_compatibility_format_result") { return }

	arena := ir.create_arena(1024 * 16)
	defer ir.destroy_arena(&arena)
	program := ir.create_program(&arena, .Bash)

	res := compat.check_compatibility(.Bash, .Fish, program)
	defer compat.destroy_compatibility_result(&res)

	formatted := compat.format_result(&res)
	testing.expect(t, strings.contains(formatted, "Compatibility"), "Formatted result should contain heading")
}

@(test)
test_shim_registry_and_param_process_shims :: proc(t: ^testing.T) {
	if !should_run_local_test("test_shim_registry_and_param_process_shims") { return }

	registry := compat.create_shim_registry()
	defer compat.destroy_shim_registry(&registry)

	shim := compat.Shim{name = "array_shim", type = .ArrayToList, code = "set arr a b", description = "test"}
	compat.add_shim(&registry, shim)
	testing.expect(t, len(registry.shims) == 1, "Registry should contain added shim")

	param := compat.generate_parameter_expansion_shim(compat.ParameterExpansionData{
		variable = "x",
		modifier = .Length,
	})
	testing.expect(t, strings.contains(param, "string length"), "Length shim should use string length")

	proc_shim := compat.generate_process_substitution_shim("echo hi", .Input)
	testing.expect(t, strings.contains(proc_shim, "mktemp"), "Process shim should allocate temp file")
}

@(test)
test_build_shim_prelude :: proc(t: ^testing.T) {
	if !should_run_local_test("test_build_shim_prelude") { return }

	required := []string{"condition_semantics", "hooks_events", "arrays_lists"}
	prelude := compat.build_shim_prelude(required, .Bash, .Fish)
	defer delete(prelude)

	testing.expect(t, strings.contains(prelude, "__shellx_test"), "Condition shim should be present")
	testing.expect(t, strings.contains(prelude, "__shellx_register_hook"), "Hook shim should be present")
	testing.expect(t, strings.contains(prelude, "__shellx_array_set"), "Array/list shim should be present")
}
