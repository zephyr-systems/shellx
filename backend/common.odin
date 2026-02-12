package backend

import "../ir"
import "core:strings"

Backend :: struct {
	dialect:      ir.ShellDialect,
	builder:      strings.Builder,
	indent_level: int,
}

create_backend :: proc(dialect: ir.ShellDialect) -> Backend {
	builder := strings.builder_make()
	return Backend{dialect = dialect, builder = builder, indent_level = 0}
}

destroy_backend :: proc(b: ^Backend) {
	strings.builder_destroy(&b.builder)
}

emit :: proc(b: ^Backend, program: ^ir.Program, allocator := context.allocator) -> string {
	strings.builder_reset(&b.builder)

	for func in program.functions {
		emit_function(b, func)
		strings.write_byte(&b.builder, '\n')
	}

	for stmt in program.statements {
		emit_statement(b, stmt)
		strings.write_byte(&b.builder, '\n')
	}

	// Copy string to the provided allocator (arena in translate())
	result := strings.to_string(b.builder)
	return strings.clone(result, allocator)
}

emit_function :: proc(b: ^Backend, func: ir.Function) {
	write_indent(b)
	strings.write_string(&b.builder, "function ")
	strings.write_string(&b.builder, func.name)
	strings.write_string(&b.builder, "() {\n")

	b.indent_level += 1

	for stmt in func.body {
		emit_statement(b, stmt)
		strings.write_byte(&b.builder, '\n')
	}

	b.indent_level -= 1
	write_indent(b)
	strings.write_string(&b.builder, "}")
}

emit_statement :: proc(b: ^Backend, stmt: ir.Statement) {
	write_indent(b)

	switch stmt.type {
	case .Assign:
		emit_assign(b, stmt.assign)
	case .Call:
		emit_call(b, stmt.call)
	case .Return:
		emit_return(b, stmt.return_)
	case .Branch:
		emit_branch(b, stmt.branch)
	case .Loop:
		emit_loop(b, stmt.loop)
	case .Pipeline:
		emit_pipeline(b, stmt.pipeline)
	}
}

emit_assign :: proc(b: ^Backend, assign: ir.Assign) {
	strings.write_string(&b.builder, assign.variable)
	strings.write_byte(&b.builder, '=')
	strings.write_string(&b.builder, assign.value)
}

emit_call :: proc(b: ^Backend, call: ir.Call) {
	strings.write_string(&b.builder, call.command)

	if len(call.arguments) > 0 {
		strings.write_byte(&b.builder, ' ')
		for idx in 0 ..< len(call.arguments) {
			if idx > 0 {
				strings.write_byte(&b.builder, ' ')
			}
			strings.write_string(&b.builder, call.arguments[idx])
		}
	}
}

emit_return :: proc(b: ^Backend, ret: ir.Return) {
	strings.write_string(&b.builder, "return ")
	strings.write_string(&b.builder, ret.value)
}

emit_branch :: proc(b: ^Backend, branch: ir.Branch) {
	strings.write_string(&b.builder, "if ")
	strings.write_string(&b.builder, branch.condition)
	strings.write_string(&b.builder, "; then\n")

	b.indent_level += 1
	for stmt in branch.then_body {
		emit_statement(b, stmt)
		strings.write_byte(&b.builder, '\n')
	}
	b.indent_level -= 1

	write_indent(b)
	strings.write_string(&b.builder, "fi")
}

emit_loop :: proc(b: ^Backend, loop: ir.Loop) {
	switch loop.kind {
	case .ForIn:
		strings.write_string(&b.builder, "for ")
		strings.write_string(&b.builder, loop.variable)
		strings.write_string(&b.builder, " in ")
		strings.write_string(&b.builder, loop.iterable)
		strings.write_string(&b.builder, "; do\n")

	case .ForC:
		strings.write_string(&b.builder, "for (( ")
		strings.write_string(&b.builder, loop.condition)
		strings.write_string(&b.builder, " )); do\n")

	case .While:
		strings.write_string(&b.builder, "while ")
		strings.write_string(&b.builder, loop.condition)
		strings.write_string(&b.builder, "; do\n")

	case .Until:
		strings.write_string(&b.builder, "until ")
		strings.write_string(&b.builder, loop.condition)
		strings.write_string(&b.builder, "; do\n")
	}

	b.indent_level += 1
	for stmt in loop.body {
		emit_statement(b, stmt)
		strings.write_byte(&b.builder, '\n')
	}
	b.indent_level -= 1

	write_indent(b)
	strings.write_string(&b.builder, "done")
}

emit_pipeline :: proc(b: ^Backend, pipeline: ir.Pipeline) {
	for idx in 0 ..< len(pipeline.commands) {
		if idx > 0 {
			strings.write_string(&b.builder, " | ")
		}
		emit_call(b, pipeline.commands[idx])
	}
}

write_indent :: proc(b: ^Backend) {
	for _ in 0 ..< b.indent_level {
		strings.write_byte(&b.builder, '\t')
	}
}
