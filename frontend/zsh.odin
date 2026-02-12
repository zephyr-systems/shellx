package frontend

import ts "../bindings/tree_sitter"
import "../ir"
import "core:fmt"
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
			func_name = node_text(mem.arena_allocator(&arena.arena), child, source)
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
	value := ""

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "word" {
			text := node_text(mem.arena_allocator(&arena.arena), child, source)
			// Skip flags like -i, -r, -x
			if strings.has_prefix(text, "-") {
				continue
			}
			// First non-flag word is variable name
			if variable_name == "" {
				variable_name = text
			} else if value == "" {
				// Second non-flag word is value
				value = text
			}
		}
	}

	assign := ir.Assign {
		variable = variable_name,
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
	arguments := make([dynamic]string, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "command_name" {
			for j in 0 ..< child_count(child) {
				name_child_node := ts.ts_node_child(child, u32(j))
				if node_type(name_child_node) == "word" {
					cmd_name = node_text(
						mem.arena_allocator(&arena.arena),
						name_child_node,
						source,
					)
					break
				}
			}
		} else if child_type == "string" || child_type == "word" {
			arg_text := node_text(mem.arena_allocator(&arena.arena), child, source)
			append(&arguments, arg_text)
		}
	}

	call := ir.Call {
		command   = cmd_name,
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
	value := ""

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "variable_name" {
			variable_name = node_text(mem.arena_allocator(&arena.arena), child, source)
		} else if child_type == "word" || child_type == "number" {
			value = node_text(mem.arena_allocator(&arena.arena), child, source)
		}
	}

	assign := ir.Assign {
		variable = variable_name,
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
	condition := ""
	then_body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena))
	else_body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "condition" {
			condition = extract_zsh_condition(arena, child, source)
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
			text := node_text(mem.arena_allocator(&arena.arena), child, source)
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
	iterable := ""
	body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "variable_name" {
			variable_name = node_text(mem.arena_allocator(&arena.arena), child, source)
		} else if child_type == "word" {
			if iterable == "" {
				iterable = node_text(mem.arena_allocator(&arena.arena), child, source)
			}
		} else if child_type == "body" || child_type == "c_style_consequence" {
			convert_zsh_body(arena, &body, child, source)
		}
	}

	loop := ir.Loop {
		kind     = .ForIn,
		variable = variable_name,
		iterable = iterable,
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
	condition := ""
	body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "condition" {
			condition = extract_zsh_condition(arena, child, source)
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
	value := ""

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if node_type(child) == "word" {
			value = node_text(mem.arena_allocator(&arena.arena), child, source)
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
	values := make([dynamic]string, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "variable_name" {
			array_name = node_text(mem.arena_allocator(&arena.arena), child, source)
		} else if child_type == "array" || child_type == "compound_statement" {
			// Extract array elements
			for j in 0 ..< child_count(child) {
				elem_node := ts.ts_node_child(child, u32(j))
				if node_type(elem_node) == "word" || node_type(elem_node) == "string" {
					elem_text := node_text(mem.arena_allocator(&arena.arena), elem_node, source)
					append(&values, elem_text)
				}
			}
		}
	}

	// Store as comma-separated values for now
	result: strings.Builder
	strings.builder_init(&result)
	for idx in 0 ..< len(values) {
		if idx > 0 {
			strings.write_string(&result, ", ")
		}
		strings.write_string(&result, values[idx])
	}

	assign := ir.Assign {
		variable = array_name,
		value    = strings.to_string(result),
		location = location,
	}

	return ir.Statement{type = .Assign, assign = assign, location = location}
}
