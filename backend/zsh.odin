package backend

import "../ir"
import "core:strings"

// ZshBackend emits Zsh code from IR
ZshBackend :: struct {
	builder:      strings.Builder,
	indent_level: int,
}

// create_zsh_backend creates a new Zsh backend
create_zsh_backend :: proc() -> ZshBackend {
	return ZshBackend{builder = strings.builder_make(), indent_level = 0}
}

// destroy_zsh_backend cleans up the Zsh backend
destroy_zsh_backend :: proc(be: ^ZshBackend) {
	strings.builder_destroy(&be.builder)
}

// emit_zsh emits Zsh code from an IR program
emit_zsh :: proc(be: ^ZshBackend, program: ^ir.Program) -> string {
	strings.builder_reset(&be.builder)

	// Emit functions first
	for func in program.functions {
		emit_zsh_function(be, func)
		strings.write_byte(&be.builder, '\n')
		strings.write_byte(&be.builder, '\n')
	}

	// Emit statements
	for stmt in program.statements {
		emit_zsh_statement(be, stmt)
		strings.write_byte(&be.builder, '\n')
	}

	return strings.to_string(be.builder)
}

// emit_zsh_function emits a function definition
emit_zsh_function :: proc(be: ^ZshBackend, func: ir.Function) {
	// Zsh supports both syntaxes: function name() { } and function name { }
	// Using the more common: function name() { }
	strings.write_string(&be.builder, "function ")
	strings.write_string(&be.builder, func.name)
	strings.write_string(&be.builder, "() {\n")

	be.indent_level += 1
	for stmt in func.body {
		emit_zsh_statement(be, stmt)
		strings.write_byte(&be.builder, '\n')
	}
	be.indent_level -= 1

	strings.write_byte(&be.builder, '}')
}

// emit_zsh_statement emits a statement
emit_zsh_statement :: proc(be: ^ZshBackend, stmt: ir.Statement) {
	write_zsh_indent(be)

	switch stmt.type {
	case .Assign:
		emit_zsh_assign(be, stmt.assign)
	case .Call:
		emit_zsh_call(be, stmt.call)
	case .Return:
		emit_zsh_return(be, stmt.return_)
	case .Branch:
		emit_zsh_branch(be, stmt.branch)
	case .Loop:
		emit_zsh_loop(be, stmt.loop)
	case .Pipeline:
		emit_zsh_pipeline(be, stmt.pipeline)
	}
}

// emit_zsh_assign emits a variable assignment
// Zsh supports: x=5, typeset x=5, local x=5, export x=5
emit_zsh_assign :: proc(be: ^ZshBackend, assign: ir.Assign) {
	// Simple assignment is most common in Zsh
	strings.write_string(&be.builder, assign.variable)
	strings.write_byte(&be.builder, '=')
	strings.write_string(&be.builder, assign.value)
}

// emit_zsh_call emits a command call
emit_zsh_call :: proc(be: ^ZshBackend, call: ir.Call) {
	strings.write_string(&be.builder, call.command)

	if len(call.arguments) > 0 {
		strings.write_byte(&be.builder, ' ')
		for idx in 0 ..< len(call.arguments) {
			if idx > 0 {
				strings.write_byte(&be.builder, ' ')
			}
			strings.write_string(&be.builder, call.arguments[idx])
		}
	}
}

// emit_zsh_return emits a return statement
emit_zsh_return :: proc(be: ^ZshBackend, ret: ir.Return) {
	strings.write_string(&be.builder, "return")
	if ret.value != "" {
		strings.write_byte(&be.builder, ' ')
		strings.write_string(&be.builder, ret.value)
	}
}

// emit_zsh_branch emits if/else statement
// Zsh uses: if [[ condition ]]; then ... elif ... else ... fi
emit_zsh_branch :: proc(be: ^ZshBackend, branch: ir.Branch) {
	strings.write_string(&be.builder, "if [[ ")
	strings.write_string(&be.builder, branch.condition)
	strings.write_string(&be.builder, " ]]; then\n")

	be.indent_level += 1
	for stmt in branch.then_body {
		emit_zsh_statement(be, stmt)
		strings.write_byte(&be.builder, '\n')
	}
	be.indent_level -= 1

	if len(branch.else_body) > 0 {
		write_zsh_indent(be)
		strings.write_string(&be.builder, "else\n")
		be.indent_level += 1
		for stmt in branch.else_body {
			emit_zsh_statement(be, stmt)
			strings.write_byte(&be.builder, '\n')
		}
		be.indent_level -= 1
	}

	write_zsh_indent(be)
	strings.write_string(&be.builder, "fi")
}

// emit_zsh_loop emits for/while loops
emit_zsh_loop :: proc(be: ^ZshBackend, loop: ir.Loop) {
	switch loop.kind {
	case .ForIn:
		// Zsh: for var in iterable; do ... done
		strings.write_string(&be.builder, "for ")
		strings.write_string(&be.builder, loop.variable)
		strings.write_string(&be.builder, " in ")
		strings.write_string(&be.builder, loop.iterable)
		strings.write_string(&be.builder, "; do\n")

		be.indent_level += 1
		for stmt in loop.body {
			emit_zsh_statement(be, stmt)
			strings.write_byte(&be.builder, '\n')
		}
		be.indent_level -= 1

		write_zsh_indent(be)
		strings.write_string(&be.builder, "done")

	case .While:
		// Zsh: while [[ condition ]]; do ... done
		strings.write_string(&be.builder, "while [[ ")
		strings.write_string(&be.builder, loop.condition)
		strings.write_string(&be.builder, " ]]; do\n")

		be.indent_level += 1
		for stmt in loop.body {
			emit_zsh_statement(be, stmt)
			strings.write_byte(&be.builder, '\n')
		}
		be.indent_level -= 1

		write_zsh_indent(be)
		strings.write_string(&be.builder, "done")

	case .ForC:
		// C-style for loop: for (( ... )); do ... done
		strings.write_string(&be.builder, "for (( ")
		strings.write_string(&be.builder, loop.condition)
		strings.write_string(&be.builder, " )); do\n")

		be.indent_level += 1
		for stmt in loop.body {
			emit_zsh_statement(be, stmt)
			strings.write_byte(&be.builder, '\n')
		}
		be.indent_level -= 1

		write_zsh_indent(be)
		strings.write_string(&be.builder, "done")

	case .Until:
		// Zsh: until [[ condition ]]; do ... done
		strings.write_string(&be.builder, "until [[ ")
		strings.write_string(&be.builder, loop.condition)
		strings.write_string(&be.builder, " ]]; do\n")

		be.indent_level += 1
		for stmt in loop.body {
			emit_zsh_statement(be, stmt)
			strings.write_byte(&be.builder, '\n')
		}
		be.indent_level -= 1

		write_zsh_indent(be)
		strings.write_string(&be.builder, "done")
	}
}

// emit_zsh_pipeline emits a pipeline
emit_zsh_pipeline :: proc(be: ^ZshBackend, pipeline: ir.Pipeline) {
	for idx in 0 ..< len(pipeline.commands) {
		if idx > 0 {
			strings.write_string(&be.builder, " | ")
		}
		emit_zsh_call(be, pipeline.commands[idx])
	}
}

// write_zsh_indent writes the current indentation
write_zsh_indent :: proc(be: ^ZshBackend) {
	for _ in 0 ..< be.indent_level {
		strings.write_byte(&be.builder, '\t')
	}
}
