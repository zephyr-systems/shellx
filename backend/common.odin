package backend

import "../ir"
import "core:strings"

// IndentStyle represents the indentation style
IndentStyle :: enum {
	Tabs,
	Spaces,
}

// FormatOptions contains formatting configuration
FormatOptions :: struct {
	indent_style: IndentStyle,
	indent_width: int, // Number of spaces (if using spaces) or tab width
	use_spaces:   bool, // true for spaces, false for tabs
}

// Default format options
DEFAULT_FORMAT_OPTIONS :: FormatOptions {
	indent_style = .Tabs,
	indent_width = 4,
	use_spaces   = false,
}

Backend :: struct {
	dialect:        ir.ShellDialect,
	builder:        strings.Builder,
	indent_level:   int,
	format_options: FormatOptions,
}

create_backend :: proc(dialect: ir.ShellDialect, options := DEFAULT_FORMAT_OPTIONS) -> Backend {
	builder := strings.builder_make()
	return Backend {
		dialect = dialect,
		builder = builder,
		indent_level = 0,
		format_options = options,
	}
}

destroy_backend :: proc(b: ^Backend) {
	strings.builder_destroy(&b.builder)
}

// write_indent writes the current indentation based on format options
write_indent :: proc(b: ^Backend) {
	for _ in 0 ..< b.indent_level {
		if b.format_options.use_spaces {
			for _ in 0 ..< b.format_options.indent_width {
				strings.write_byte(&b.builder, ' ')
			}
		} else {
			strings.write_byte(&b.builder, '\t')
		}
	}
}

// write_newline writes a newline character
write_newline :: proc(b: ^Backend) {
	strings.write_byte(&b.builder, '\n')
}

// escape_string escapes special characters in a string for shell output
// Handles: quotes, backslashes, dollar signs, backticks
escape_string :: proc(s: string) -> string {
	if s == "" {
		return ""
	}

	// Check if we need to escape
	needs_escape := false
	for c in s {
		if c == '"' || c == '\\' || c == '$' || c == '`' {
			needs_escape = true
			break
		}
	}

	if !needs_escape {
		return s
	}

	// Build escaped string
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	for c in s {
		switch c {
		case '"', '\\', '$', '`':
			strings.write_byte(&builder, '\\')
			strings.write_byte(&builder, u8(c))
		case:
			strings.write_byte(&builder, u8(c))
		}
	}

	return strings.to_string(builder)
}

// quote_string quotes a string if it contains spaces or special characters
quote_string :: proc(s: string) -> string {
	if s == "" {
		return "\"\""
	}

	// Check if we need quotes
	needs_quotes := false
	for c in s {
		if c == ' ' || c == '\t' || c == '\n' || c == '*' || c == '?' || c == '[' {
			needs_quotes = true
			break
		}
	}

	if !needs_quotes {
		return s
	}

	// Escape and quote
	escaped := escape_string(s)
	return strings.concatenate([]string{"\"", escaped, "\""})
}

// format_arguments formats command arguments with proper quoting
format_arguments :: proc(args: []string) -> string {
	if len(args) == 0 {
		return ""
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	for idx in 0 ..< len(args) {
		if idx > 0 {
			strings.write_byte(&builder, ' ')
		}
		quoted := quote_string(args[idx])
		strings.write_string(&builder, quoted)
	}

	return strings.to_string(builder)
}

// indent increases the indentation level
indent :: proc(b: ^Backend) {
	b.indent_level += 1
}

// dedent decreases the indentation level
dedent :: proc(b: ^Backend) {
	if b.indent_level > 0 {
		b.indent_level -= 1
	}
}

// set_indent_style changes the indentation style
set_indent_style :: proc(b: ^Backend, style: IndentStyle) {
	b.format_options.indent_style = style
	b.format_options.use_spaces = (style == .Spaces)
}

// set_indent_width changes the indentation width (for spaces)
set_indent_width :: proc(b: ^Backend, width: int) {
	b.format_options.indent_width = width
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
	if assign.target != nil {
		strings.write_string(&b.builder, assign.target.name)
	}
	strings.write_byte(&b.builder, '=')
	strings.write_string(&b.builder, ir.expr_to_string(assign.value))
}

emit_call :: proc(b: ^Backend, call: ir.Call) {
	if call.function != nil {
		strings.write_string(&b.builder, call.function.name)
	}

	if len(call.arguments) > 0 {
		strings.write_byte(&b.builder, ' ')
		for idx in 0 ..< len(call.arguments) {
			if idx > 0 {
				strings.write_byte(&b.builder, ' ')
			}
			strings.write_string(&b.builder, ir.expr_to_string(call.arguments[idx]))
		}
	}
}

emit_return :: proc(b: ^Backend, ret: ir.Return) {
	strings.write_string(&b.builder, "return")
	if ret.value != nil {
		strings.write_byte(&b.builder, ' ')
		strings.write_string(&b.builder, ir.expr_to_string(ret.value))
	}
}

emit_branch :: proc(b: ^Backend, branch: ir.Branch) {
	strings.write_string(&b.builder, "if ")
	strings.write_string(&b.builder, ir.expr_to_string(branch.condition))
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
		if loop.iterator != nil {
			strings.write_string(&b.builder, loop.iterator.name)
		}
		strings.write_string(&b.builder, " in ")
		strings.write_string(&b.builder, ir.expr_to_string(loop.items))
		strings.write_string(&b.builder, "; do\n")

	case .ForC:
		strings.write_string(&b.builder, "for (( ")
		strings.write_string(&b.builder, ir.expr_to_string(loop.condition))
		strings.write_string(&b.builder, " )); do\n")

	case .While:
		strings.write_string(&b.builder, "while ")
		strings.write_string(&b.builder, ir.expr_to_string(loop.condition))
		strings.write_string(&b.builder, "; do\n")

	case .Until:
		strings.write_string(&b.builder, "until ")
		strings.write_string(&b.builder, ir.expr_to_string(loop.condition))
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
