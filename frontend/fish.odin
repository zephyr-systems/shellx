package frontend

import ts "../bindings/tree_sitter"
import "../ir"
import "core:mem"
import "core:strings"

// fish_to_ir converts Fish AST to ShellX IR
fish_to_ir :: proc(
	arena: ^ir.Arena_IR,
	tree: ^ts.Tree,
	source: string,
) -> (
	^ir.Program,
	FrontendError,
) {
	program := ir.create_program(arena, .Fish)
	root := root_node(tree)
	convert_fish_node(arena, program, root, source)
	return program, FrontendError{}
}

convert_fish_node :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	node_type_str := node_type(node)

	switch node_type_str {
	case "program":
		convert_fish_program(arena, program, node, source)
		return
	case "function_definition":
		convert_fish_function(arena, program, node, source)
		return
	case "command":
		convert_fish_command(arena, program, node, source)
		return
	}

	// For other node types, process children
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_fish_node(arena, program, child, source)
		}
	}
}

convert_fish_program :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_fish_node(arena, program, child, source)
		}
	}
}

convert_fish_function :: proc(
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
			convert_fish_body(arena, &func.body, child, source)
		}
	}

	ir.add_function(program, func)
}

convert_fish_body :: proc(
	arena: ^ir.Arena_IR,
	body: ^[dynamic]ir.Statement,
	node: ts.Node,
	source: string,
) {
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_fish_statement(arena, body, child, source)
		}
	}
}

convert_fish_statement :: proc(
	arena: ^ir.Arena_IR,
	body: ^[dynamic]ir.Statement,
	node: ts.Node,
	source: string,
) {
	node_type_str := node_type(node)

	switch node_type_str {
	case "command":
		// Check if this is a 'set' command (Fish variable assignment)
		if is_fish_set_command(node) {
			stmt := convert_fish_set_to_statement(arena, node, source)
			append(body, stmt)
		} else {
			stmt := convert_fish_command_to_statement(arena, node, source)
			append(body, stmt)
		}
	case "if_statement":
		stmt := convert_fish_if_to_statement(arena, node, source)
		append(body, stmt)
	case "for_statement":
		stmt := convert_fish_for_to_statement(arena, node, source)
		append(body, stmt)
	case "while_statement":
		stmt := convert_fish_while_to_statement(arena, node, source)
		append(body, stmt)
	case "return_statement":
		stmt := convert_fish_return_to_statement(arena, node, source)
		append(body, stmt)
	}
}

// Check if command is 'set' (Fish variable assignment)
is_fish_set_command :: proc(node: ts.Node) -> bool {
	for i in 0 ..< child_count(node) {
		child_node := child(node, i)
		child_type := node_type(child_node)

		if child_type == "command_name" {
			for j in 0 ..< child_count(child_node) {
				name_child := ts.ts_node_child(child_node, u32(j))
				if node_type(name_child) == "word" {
					cmd_name := node_text(context.temp_allocator, name_child, "")
					if cmd_name == "set" {
						return true
					}
				}
			}
		}
	}
	return false
}

// Convert Fish 'set' command to assignment statement
convert_fish_set_to_statement :: proc(
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
			text := node_text(mem.arena_allocator(&arena.arena), child, source)
			// Skip 'set' command itself
			if text == "set" {
				continue
			}
			// Skip flags like -g, -l, -x, -U
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

convert_fish_command :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	stmt := convert_fish_command_to_statement(arena, node, source)
	ir.add_statement(program, stmt)
}

convert_fish_command_to_statement :: proc(
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
			append(&arguments, text_to_expression(arena, arg_text))
		}
	}

	call := ir.Call {
		function  = ir.new_variable(arena, cmd_name),
		arguments = arguments,
		location  = location,
	}

	return ir.Statement{type = .Call, call = call, location = location}
}

convert_fish_if_to_statement :: proc(
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
			condition = ir.new_raw_expr(arena, extract_fish_condition(arena, child, source))
		} else if child_type == "consequence" {
			convert_fish_body(arena, &then_body, child, source)
		} else if child_type == "alternative" {
			convert_fish_body(arena, &else_body, child, source)
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

extract_fish_condition :: proc(arena: ^ir.Arena_IR, node: ts.Node, source: string) -> string {
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

convert_fish_for_to_statement :: proc(
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
			variable_name = node_text(mem.arena_allocator(&arena.arena), child, source)
		} else if child_type == "word" {
			if iterable_text == "" {
				iterable_text = node_text(mem.arena_allocator(&arena.arena), child, source)
			}
		} else if child_type == "body" {
			convert_fish_body(arena, &body, child, source)
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

convert_fish_while_to_statement :: proc(
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
			condition = ir.new_raw_expr(arena, extract_fish_condition(arena, child, source))
		} else if child_type == "body" {
			convert_fish_body(arena, &body, child, source)
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

convert_fish_return_to_statement :: proc(
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
				node_text(mem.arena_allocator(&arena.arena), child, source),
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
