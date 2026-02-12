package shellx

import "ir"

// ScriptBuilder builds IR scripts for tests/examples with explicit cleanup.
ScriptBuilder :: struct {
	arena:   ir.Arena_IR,
	program: ^ir.Program,
	dialect: ShellDialect,
}

// create_script_builder initializes a script builder and owns a fresh arena.
create_script_builder :: proc(dialect: ShellDialect, arena_capacity := 1024 * 1024) -> ScriptBuilder {
	arena := ir.create_arena(arena_capacity)
	program := ir.create_program(&arena, dialect)
	return ScriptBuilder{
		arena = arena,
		program = program,
		dialect = dialect,
	}
}

// destroy_script_builder frees all memory owned by the builder.
destroy_script_builder :: proc(builder: ^ScriptBuilder) {
	ir.destroy_arena(&builder.arena)
	builder.program = nil
}

// script_builder_program exposes the underlying IR program for advanced usage.
script_builder_program :: proc(builder: ^ScriptBuilder) -> ^ir.Program {
	return builder.program
}

// script_add_assign appends a variable assignment statement.
script_add_assign :: proc(
	builder: ^ScriptBuilder,
	target: string,
	value: ir.Expression,
	location := ir.SourceLocation{},
) {
	stmt := ir.stmt_assign(&builder.arena, target, value, location)
	ir.add_statement(builder.program, stmt)
}

// script_add_var appends a simple literal assignment.
script_add_var :: proc(
	builder: ^ScriptBuilder,
	name: string,
	value: string,
	literal_type := ir.LiteralType.String,
	location := ir.SourceLocation{},
) {
	lit := ir.new_literal_expr(&builder.arena, value, literal_type)
	script_add_assign(builder, name, lit, location)
}

// script_add_call appends a call statement with string arguments.
script_add_call :: proc(
	builder: ^ScriptBuilder,
	command: string,
	args: ..string,
) {
	expr_args := make([dynamic]ir.Expression, 0, len(args), context.temp_allocator)
	defer delete(expr_args)
	for arg in args {
		append(&expr_args, ir.expr_string(&builder.arena, arg))
	}

	stmt := ir.stmt_call(&builder.arena, command, ..expr_args[:])
	ir.add_statement(builder.program, stmt)
}

// script_emit emits the built program for the requested target dialect.
// Caller owns the returned string and should free it with delete(...) or destroy_translation_result.
script_emit :: proc(
	builder: ^ScriptBuilder,
	target: ShellDialect,
	allocator := context.allocator,
) -> string {
	context.allocator = allocator
	result, ok := emit_program(builder.program, target)
	if !ok {
		return ""
	}
	return result
}
