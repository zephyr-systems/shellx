package unit_tests

import "core:strings"
import "core:testing"
import "../../backend"
import "../../ir"

LOCAL_SHELLX_TEST_NAME :: #config(LOCAL_SHELLX_TEST_NAME, "")

should_run_local_test :: proc(name: string) -> bool {
	if LOCAL_SHELLX_TEST_NAME == "" {
		return true
	}
	return strings.contains(name, LOCAL_SHELLX_TEST_NAME)
}

build_basic_program :: proc(arena: ^ir.Arena_IR, dialect: ir.ShellDialect) -> ^ir.Program {
	program := ir.create_program(arena, dialect)
	ir.add_statement(program, ir.stmt_assign(arena, "x", ir.expr_int(arena, "5")))
	ir.add_statement(program, ir.stmt_call(arena, "echo", ir.expr_var(arena, "x")))
	return program
}

@(test)
test_backend_emit_bash :: proc(t: ^testing.T) {
	if !should_run_local_test("test_backend_emit_bash") { return }

	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)

	program := build_basic_program(&arena, .Bash)
	be := backend.create_backend(.Bash)
	defer backend.destroy_backend(&be)
	out := backend.emit(&be, program)
	defer delete(out)

	testing.expect(t, strings.contains(out, "x=5"), "Bash output should contain assignment")
	testing.expect(t, strings.contains(out, "echo x"), "Bash output should contain call")
}

@(test)
test_backend_emit_zsh :: proc(t: ^testing.T) {
	if !should_run_local_test("test_backend_emit_zsh") { return }

	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)

	program := build_basic_program(&arena, .Zsh)
	be := backend.create_zsh_backend()
	defer backend.destroy_zsh_backend(&be)
	out := backend.emit_zsh(&be, program)

	testing.expect(t, strings.contains(out, "x=5"), "Zsh output should contain assignment")
	testing.expect(t, strings.contains(out, "echo x"), "Zsh output should contain call")
}

@(test)
test_backend_emit_fish :: proc(t: ^testing.T) {
	if !should_run_local_test("test_backend_emit_fish") { return }

	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)

	program := build_basic_program(&arena, .Fish)
	be := backend.create_fish_backend()
	defer backend.destroy_fish_backend(&be)
	out := backend.emit_fish(&be, program)

	testing.expect(t, strings.contains(out, "set x 5"), "Fish output should contain set assignment")
	testing.expect(t, strings.contains(out, "echo x"), "Fish output should contain call")
}

@(test)
test_backend_formatting_helpers :: proc(t: ^testing.T) {
	if !should_run_local_test("test_backend_formatting_helpers") { return }

	arena := ir.create_arena(1024 * 32)
	defer ir.destroy_arena(&arena)
	program := ir.create_program(&arena, .Bash)
	ir.add_statement(program, ir.stmt_call(&arena, "echo", ir.expr_string(&arena, "hello world")))

	be := backend.create_backend(.Bash)
	defer backend.destroy_backend(&be)
	backend.set_indent_style(&be, .Spaces)
	backend.set_indent_width(&be, 2)

	out := backend.emit(&be, program)
	defer delete(out)
	testing.expect(t, strings.contains(out, "echo hello world"), "Formatted output should contain call text")
}
