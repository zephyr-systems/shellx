package backend

import "../ir"
import "core:strings"

// FishBackend emits Fish code from IR
FishBackend :: struct {
	builder:      strings.Builder,
	indent_level: int,
}

// create_fish_backend creates a new Fish backend
create_fish_backend :: proc() -> FishBackend {
	return FishBackend{builder = strings.builder_make(), indent_level = 0}
}

// destroy_fish_backend cleans up the Fish backend
destroy_fish_backend :: proc(be: ^FishBackend) {
	strings.builder_destroy(&be.builder)
}

// emit_fish emits Fish code from an IR program
emit_fish :: proc(be: ^FishBackend, program: ^ir.Program) -> string {
	strings.builder_reset(&be.builder)

	// Emit functions first
	for func in program.functions {
		emit_fish_function(be, func)
		strings.write_byte(&be.builder, '\n')
		strings.write_byte(&be.builder, '\n')
	}

	// Emit statements
	for stmt in program.statements {
		emit_fish_statement(be, stmt)
		strings.write_byte(&be.builder, '\n')
	}

	return strings.to_string(be.builder)
}

// emit_fish_function emits a function definition
// Fish: function name
//     body
// end
emit_fish_function :: proc(be: ^FishBackend, func: ir.Function) {
	strings.write_string(&be.builder, "function ")
	strings.write_string(&be.builder, func.name)
	strings.write_byte(&be.builder, '\n')

	be.indent_level += 1
	for stmt in func.body {
		emit_fish_statement(be, stmt)
		strings.write_byte(&be.builder, '\n')
	}
	be.indent_level -= 1

	write_fish_indent(be)
	strings.write_string(&be.builder, "end")
}

// emit_fish_statement emits a statement
emit_fish_statement :: proc(be: ^FishBackend, stmt: ir.Statement) {
	write_fish_indent(be)

	switch stmt.type {
	case .Assign:
		emit_fish_assign(be, stmt.assign)
	case .Call:
		emit_fish_call(be, stmt.call)
	case .Logical:
		emit_fish_logical(be, stmt.logical)
	case .Case:
		emit_fish_case_statement(be, stmt.case_)
	case .Return:
		emit_fish_return(be, stmt.return_)
	case .Branch:
		emit_fish_branch(be, stmt.branch)
	case .Loop:
		emit_fish_loop(be, stmt.loop)
	case .Pipeline:
		emit_fish_pipeline(be, stmt.pipeline)
	}
}

emit_fish_logical :: proc(be: ^FishBackend, logical: ir.LogicalChain) {
	for idx in 0 ..< len(logical.segments) {
		segment := logical.segments[idx]
		if idx > 0 {
			if logical.operators[idx-1] == .And {
				strings.write_string(&be.builder, "; and ")
			} else {
				strings.write_string(&be.builder, "; or ")
			}
		}
		if segment.negated {
			strings.write_string(&be.builder, "not ")
		}
		emit_fish_call(be, segment.call)
	}
}

emit_fish_case_statement :: proc(be: ^FishBackend, case_stmt: ir.CaseStatement) {
	strings.write_string(&be.builder, "switch ")
	strings.write_string(&be.builder, ir.expr_to_string(case_stmt.value))
	strings.write_byte(&be.builder, '\n')

	be.indent_level += 1
	for arm in case_stmt.arms {
		write_fish_indent(be)
		strings.write_string(&be.builder, "case ")
		for idx in 0 ..< len(arm.patterns) {
			if idx > 0 {
				strings.write_byte(&be.builder, ' ')
			}
			strings.write_string(&be.builder, arm.patterns[idx])
		}
		strings.write_byte(&be.builder, '\n')

		be.indent_level += 1
		for stmt in arm.body {
			emit_fish_statement(be, stmt)
			strings.write_byte(&be.builder, '\n')
		}
		be.indent_level -= 1
	}
	be.indent_level -= 1
	write_fish_indent(be)
	strings.write_string(&be.builder, "end")
}

// emit_fish_assign emits a variable assignment
// Fish uses: set variable value
emit_fish_assign :: proc(be: ^FishBackend, assign: ir.Assign) {
	strings.write_string(&be.builder, "set ")
	if assign.target != nil {
		strings.write_string(&be.builder, assign.target.name)
	}
	strings.write_byte(&be.builder, ' ')
	strings.write_string(&be.builder, ir.expr_to_string(assign.value))
}

// emit_fish_call emits a command call
emit_fish_call :: proc(be: ^FishBackend, call: ir.Call) {
	if call.function != nil {
		strings.write_string(&be.builder, call.function.name)
	}

	if len(call.arguments) > 0 {
		strings.write_byte(&be.builder, ' ')
		for idx in 0 ..< len(call.arguments) {
			if idx > 0 {
				strings.write_byte(&be.builder, ' ')
			}
			strings.write_string(&be.builder, ir.expr_to_string(call.arguments[idx]))
		}
	}
}

// emit_fish_return emits a return statement
emit_fish_return :: proc(be: ^FishBackend, ret: ir.Return) {
	strings.write_string(&be.builder, "return")
	if ret.value != nil {
		strings.write_byte(&be.builder, ' ')
		strings.write_string(&be.builder, ir.expr_to_string(ret.value))
	}
}

// emit_fish_branch emits if/else statement
// Fish: if test condition
//     then_body
// else
//     else_body
// end
emit_fish_branch :: proc(be: ^FishBackend, branch: ir.Branch) {
	strings.write_string(&be.builder, "if test ")
	strings.write_string(&be.builder, ir.expr_to_string(branch.condition))
	strings.write_byte(&be.builder, '\n')

	be.indent_level += 1
	for stmt in branch.then_body {
		emit_fish_statement(be, stmt)
		strings.write_byte(&be.builder, '\n')
	}
	be.indent_level -= 1

	if len(branch.else_body) > 0 {
		write_fish_indent(be)
		strings.write_string(&be.builder, "else\n")
		be.indent_level += 1
		for stmt in branch.else_body {
			emit_fish_statement(be, stmt)
			strings.write_byte(&be.builder, '\n')
		}
		be.indent_level -= 1
	}

	write_fish_indent(be)
	strings.write_string(&be.builder, "end")
}

// emit_fish_loop emits for/while loops
emit_fish_loop :: proc(be: ^FishBackend, loop: ir.Loop) {
	switch loop.kind {
	case .ForIn:
		// Fish: for var in iterable
		//     body
		// end
		strings.write_string(&be.builder, "for ")
		if loop.iterator != nil {
			strings.write_string(&be.builder, loop.iterator.name)
		}
		strings.write_string(&be.builder, " in ")
		strings.write_string(&be.builder, ir.expr_to_string(loop.items))
		strings.write_byte(&be.builder, '\n')

		be.indent_level += 1
		for stmt in loop.body {
			emit_fish_statement(be, stmt)
			strings.write_byte(&be.builder, '\n')
		}
		be.indent_level -= 1

		write_fish_indent(be)
		strings.write_string(&be.builder, "end")

	case .While:
		// Fish: while test condition
		//     body
		// end
		strings.write_string(&be.builder, "while test ")
		strings.write_string(&be.builder, ir.expr_to_string(loop.condition))
		strings.write_byte(&be.builder, '\n')

		be.indent_level += 1
		for stmt in loop.body {
			emit_fish_statement(be, stmt)
			strings.write_byte(&be.builder, '\n')
		}
		be.indent_level -= 1

		write_fish_indent(be)
		strings.write_string(&be.builder, "end")

	case .ForC, .Until:
		// Fish doesn't support C-style for or until loops
		// Emit a comment for now
		strings.write_string(&be.builder, "# Unsupported loop type in Fish")
	}
}

// emit_fish_pipeline emits a pipeline
emit_fish_pipeline :: proc(be: ^FishBackend, pipeline: ir.Pipeline) {
	for idx in 0 ..< len(pipeline.commands) {
		if idx > 0 {
			strings.write_string(&be.builder, " | ")
		}
		emit_fish_call(be, pipeline.commands[idx])
	}
}

// write_fish_indent writes the current indentation
write_fish_indent :: proc(be: ^FishBackend) {
	for _ in 0 ..< be.indent_level {
		strings.write_byte(&be.builder, '\t')
	}
}
