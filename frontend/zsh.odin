package frontend

import ts "../bindings/tree_sitter"
import "../ir"
import "core:mem"
import "core:strings"

// zsh_to_ir converts Zsh AST to ShellX IR
zsh_to_ir :: proc(
	arena: ^ir.Arena_IR,
	tree: ^ts.Tree,
	source: string,
) -> (
	^ir.Program,
	FrontendError,
) {
	program := ir.create_program(arena, .Zsh)
	root := root_node(tree)
	convert_zsh_node(arena, program, root, source)
	return program, FrontendError{}
}

convert_zsh_node :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	node_type_str := node_type(node)

	switch node_type_str {
	case "program":
		convert_zsh_program(arena, program, node, source)
		return
	case "function_definition":
		convert_zsh_function(arena, program, node, source)
		return
	case "command":
		convert_zsh_command(arena, program, node, source)
		return
	case "declaration_command":
		convert_zsh_command(arena, program, node, source)
		return
	case "variable_assignment":
		convert_zsh_assignment(arena, program, node, source)
		return
	}

	// For other node types, process children
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_zsh_node(arena, program, child, source)
		}
	}
}

convert_zsh_program :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_zsh_node(arena, program, child, source)
		}
	}
}

convert_zsh_function :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	location := node_location(node, source)
	func_name := ""

	// Extract function name
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "word" && func_name == "" {
			func_name = intern_node_text(arena, child, source)
		}
	}

	func := ir.create_function(arena, func_name, location)

	// Process body
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "compound_statement" || child_type == "body" {
			convert_zsh_body(arena, &func.body, child, source)
		}
	}

	ir.add_function(program, func)
}

convert_zsh_body :: proc(
	arena: ^ir.Arena_IR,
	body: ^[dynamic]ir.Statement,
	node: ts.Node,
	source: string,
) {
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_zsh_statement(arena, body, child, source)
		}
	}
}

convert_zsh_statement :: proc(
	arena: ^ir.Arena_IR,
	body: ^[dynamic]ir.Statement,
	node: ts.Node,
	source: string,
) {
	node_type_str := node_type(node)

	switch node_type_str {
	case "command":
		// Check if this is a typeset/local/export command
		if is_zsh_var_declaration(node) {
			stmt := convert_zsh_typeset_to_statement(arena, node, source)
			append(body, stmt)
		} else {
			stmt := convert_zsh_command_to_statement(arena, node, source)
			append(body, stmt)
		}
	case "declaration_command":
		stmt := convert_zsh_command_to_statement(arena, node, source)
		append(body, stmt)
	case "variable_assignment":
		stmt := convert_zsh_assignment_to_statement(arena, node, source)
		append(body, stmt)
	case "if_statement":
		stmt := convert_zsh_if_to_statement(arena, node, source)
		append(body, stmt)
	case "for_statement":
		stmt := convert_zsh_for_to_statement(arena, node, source)
		append(body, stmt)
	case "while_statement":
		stmt := convert_zsh_while_to_statement(arena, node, source)
		append(body, stmt)
	case "return_statement":
		stmt := convert_zsh_return_to_statement(arena, node, source)
		append(body, stmt)
	case "ERROR":
		// Preserve parse-recovery fragments as raw command lines.
		append_zsh_error_statements(arena, body, node, source)
	case:
		// Recursively traverse unhandled nodes so nested statements are not dropped.
		for i in 0 ..< child_count(node) {
			child_node := child(node, i)
			if is_named(child_node) {
				convert_zsh_statement(arena, body, child_node, source)
			}
		}
	}
}

is_zsh_argument_node :: proc(child_type: string) -> bool {
	switch child_type {
	case "string", "word", "raw_string", "simple_expansion", "expansion", "concatenation", "special_variable_name", "command_substitution", "binary_expression", "regex", "flag", "flag_name":
		return true
	}
	return false
}

append_zsh_error_statements :: proc(
	arena: ^ir.Arena_IR,
	body: ^[dynamic]ir.Statement,
	node: ts.Node,
	source: string,
) {
	location := node_location(node, source)
	raw := strings.trim_space(intern_node_text(arena, node, source))
	if raw == "" {
		return
	}

	lines := strings.split_lines(raw)
	defer delete(lines)

	for line in lines {
		trimmed := strings.trim_space(line)
		if trimmed == "" || strings.has_prefix(trimmed, "#") {
			continue
		}
		stmt := ir.Statement{
			type = .Call,
			call = ir.Call{
				function = ir.new_variable(arena, trimmed),
				arguments = make([dynamic]ir.Expression, 0, 0, mem.arena_allocator(&arena.arena)),
				location = location,
			},
			location = location,
		}
		append(body, stmt)
	}
}

// Check if command is typeset, local, or export
is_zsh_var_declaration :: proc(node: ts.Node) -> bool {
	for i in 0 ..< child_count(node) {
		child_node := child(node, i)
		child_type := node_type(child_node)

		if child_type == "command_name" {
			for j in 0 ..< child_count(child_node) {
				name_child := ts.ts_node_child(child_node, u32(j))
				if node_type(name_child) == "word" {
					cmd_name := node_text(context.temp_allocator, name_child, "")
					if cmd_name == "typeset" || cmd_name == "local" || cmd_name == "export" {
						return true
					}
				}
			}
		}
	}
	return false
}

// Convert typeset/local/export to assignment statement
convert_zsh_typeset_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	variable_name := ""
	value := ir.Expression(nil)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "word" {
			text := intern_node_text(arena, child, source)
			// Skip flags like -i, -r, -x
			if strings.has_prefix(text, "-") {
				continue
			}
			// First non-flag word is variable name
			if variable_name == "" {
				variable_name = text
			} else if value == nil {
				// Second non-flag word is value
				value = text_to_expression(arena, text)
			}
		}
	}

	assign := ir.Assign {
		target   = ir.new_variable(arena, variable_name),
		value    = value,
		location = location,
	}

	return ir.Statement{type = .Assign, assign = assign, location = location}
}

convert_zsh_command :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	stmt := convert_zsh_command_to_statement(arena, node, source)
	ir.add_statement(program, stmt)
}

convert_zsh_command_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	cmd_name := ""
	arguments := make([dynamic]ir.Expression, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "command_name" {
			for j in 0 ..< child_count(child) {
				name_child_node := ts.ts_node_child(child, u32(j))
				if is_named(name_child_node) {
					cmd_name = strings.trim_space(intern_node_text(arena, name_child_node, source))
					if cmd_name != "" {
						break
					}
				}
			}
		} else if is_zsh_argument_node(child_type) {
			arg_text := strings.trim_space(intern_node_text(arena, child, source))
			if arg_text != "" {
				append(&arguments, text_to_expression(arena, arg_text))
			}
		}
	}

	// Fallback: treat the first argument as command name when parser omits command_name.
	if cmd_name == "" && len(arguments) > 0 {
		cmd_name = ir.expr_to_string(arguments[0])
		delete(arguments[0])
		arguments = arguments[1:]
	}
	if cmd_name == "" {
		cmd_name = ":"
	}

	call := ir.Call {
		function  = ir.new_variable(arena, cmd_name),
		arguments = arguments,
		location  = location,
	}

	return ir.Statement{type = .Call, call = call, location = location}
}

convert_zsh_assignment :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	stmt := convert_zsh_assignment_to_statement(arena, node, source)
	ir.add_statement(program, stmt)
}

convert_zsh_assignment_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	variable_name := ""
	value := ir.Expression(nil)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "variable_name" {
			variable_name = intern_node_text(arena, child, source)
		} else if child_type == "word" || child_type == "number" {
			value = text_to_expression(
				arena,
				intern_node_text(arena, child, source),
			)
		}
	}

	assign := ir.Assign {
		target   = ir.new_variable(arena, variable_name),
		value    = value,
		location = location,
	}

	return ir.Statement{type = .Assign, assign = assign, location = location}
}

convert_zsh_if_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	condition := ir.Expression(nil)
	then_body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena))
	else_body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "condition" {
			condition = ir.new_raw_expr(arena, extract_zsh_condition(arena, child, source))
		} else if child_type == "consequence" {
			convert_zsh_body(arena, &then_body, child, source)
		} else if child_type == "alternative" {
			convert_zsh_body(arena, &else_body, child, source)
		}
	}

	branch := ir.Branch {
		condition = condition,
		then_body = then_body,
		else_body = else_body,
		location  = location,
	}

	return ir.Statement{type = .Branch, branch = branch, location = location}
}

extract_zsh_condition :: proc(arena: ^ir.Arena_IR, node: ts.Node, source: string) -> string {
	// Zsh uses [[ ]] syntax, handled similarly to Bash
	result: strings.Builder
	strings.builder_init(&result)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			text := intern_node_text(arena, child, source)
			if strings.builder_len(result) > 0 {
				strings.write_byte(&result, ' ')
			}
			strings.write_string(&result, text)
		}
	}

	return strings.to_string(result)
}

convert_zsh_for_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	variable_name := ""
	iterable_text := ""
	body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "variable_name" {
			variable_name = intern_node_text(arena, child, source)
		} else if child_type == "word" {
			if iterable_text == "" {
				iterable_text = intern_node_text(arena, child, source)
			}
		} else if child_type == "body" || child_type == "c_style_consequence" {
			convert_zsh_body(arena, &body, child, source)
		}
	}

	loop := ir.Loop {
		kind     = .ForIn,
		iterator = ir.new_variable(arena, variable_name),
		items    = text_to_expression(arena, iterable_text),
		body     = body,
		location = location,
	}

	return ir.Statement{type = .Loop, loop = loop, location = location}
}

convert_zsh_while_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	condition := ir.Expression(nil)
	body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "condition" {
			condition = ir.new_raw_expr(arena, extract_zsh_condition(arena, child, source))
		} else if child_type == "body" {
			convert_zsh_body(arena, &body, child, source)
		}
	}

	loop := ir.Loop {
		kind      = .While,
		condition = condition,
		body      = body,
		location  = location,
	}

	return ir.Statement{type = .Loop, loop = loop, location = location}
}

convert_zsh_return_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	value := ir.Expression(nil)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if node_type(child) == "word" {
			value = text_to_expression(
				arena,
				intern_node_text(arena, child, source),
			)
			break
		}
	}

	ret := ir.Return {
		value    = value,
		location = location,
	}

	return ir.Statement{type = .Return, return_ = ret, location = location}
}

// Zsh Array Support (Task 10.6)
// Handles Zsh array syntax: arr=(one two), ${arr[1]}, ${arr[@]}

convert_zsh_array_assignment :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	stmt := convert_zsh_array_to_statement(arena, node, source)
	ir.add_statement(program, stmt)
}

convert_zsh_array_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	array_name := ""
	values := make([dynamic]ir.Expression, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "variable_name" {
			array_name = intern_node_text(arena, child, source)
		} else if child_type == "array" || child_type == "compound_statement" {
			// Extract array elements
			for j in 0 ..< child_count(child) {
				elem_node := ts.ts_node_child(child, u32(j))
				if node_type(elem_node) == "word" || node_type(elem_node) == "string" {
					elem_text := intern_node_text(arena, elem_node, source)
					append(&values, text_to_expression(arena, elem_text))
				}
			}
		}
	}

	assign := ir.Assign {
		target   = ir.new_variable(arena, array_name),
		value    = ir.new_array_expr(arena, values),
		location = location,
	}

	return ir.Statement{type = .Assign, assign = assign, location = location}
}
