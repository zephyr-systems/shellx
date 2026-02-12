package frontend

import ts "../bindings/tree_sitter"
import "../ir"
import "core:mem"
import "core:strings" // Import mem for mem.Allocator

bash_to_ir :: proc(
	arena: ^ir.Arena_IR,
	tree: ^ts.Tree,
	source: string,
) -> (
	^ir.Program,
	FrontendError,
) {
	program := ir.create_program(arena, .Bash)
	root := root_node(tree)
	convert_bash_node(arena, program, root, source)
	return program, FrontendError{}
}

convert_bash_node :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	node_type_str := node_type(node)
	// Process specific node types
	switch node_type_str {
	case "program":
		convert_bash_program(arena, program, node, source)
		return // Don't process children again
	case "function_definition":
		convert_bash_function(arena, program, node, source)
		return // Don't process children again
	case "command":
		convert_bash_command(arena, program, node, source)
		return // Don't process children again
	case "variable_assignment":
		convert_bash_assignment(arena, program, node, source)
		return // Don't process children again
	}

	// For other node types, process children
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_bash_node(arena, program, child, source)
		}
	}
}

convert_bash_program :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_bash_node(arena, program, child, source)
		}
	}
}

convert_bash_function :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	location := node_location(node, source)
	func_name := ""

	// First pass: extract function name
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "word" && func_name == "" {
			func_name = intern_node_text(arena, child, source) // Pass allocator
		}
	}

	// Create function with the extracted name
	func := ir.create_function(arena, func_name, location)

	// Second pass: process body
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "compound_statement" || child_type == "body" {
			convert_bash_body(arena, &func.body, child, source) // Pass arena
		}
	}

	ir.add_function(program, func)
}

convert_bash_body :: proc(
	arena: ^ir.Arena_IR,
	body: ^[dynamic]ir.Statement,
	node: ts.Node,
	source: string,
) {
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_bash_statement(arena, body, child, source) // Pass arena
		}
	}
}

convert_bash_statement :: proc(
	arena: ^ir.Arena_IR,
	body: ^[dynamic]ir.Statement,
	node: ts.Node,
	source: string,
) {
	node_type_str := node_type(node)
	switch node_type_str {
	case "command":
		stmt := convert_bash_command_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	case "variable_assignment":
		stmt := convert_bash_assignment_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	case "if_statement":
		stmt := convert_bash_if_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	case "for_statement":
		stmt := convert_bash_for_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	case "while_statement":
		stmt := convert_bash_while_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	case "return_statement":
		stmt := convert_bash_return_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	case:
		// Recursively traverse unhandled nodes so nested statements are not dropped.
		for i in 0 ..< child_count(node) {
			child_node := child(node, i)
			if is_named(child_node) {
				convert_bash_statement(arena, body, child_node, source)
			}
		}
	}
}

convert_bash_command :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	stmt := convert_bash_command_to_statement(arena, node, source) // Pass arena
	ir.add_statement(program, stmt)
}

convert_bash_command_to_statement :: proc(
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

		// Command name is inside a "command_name" node
		if child_type == "command_name" {
			// Get the word inside command_name
			for j in 0 ..< child_count(child) {
				name_child_node := ts.ts_node_child(child, u32(j))
				if node_type(name_child_node) == "word" {
					cmd_name = intern_node_text(arena, name_child_node, source)
					break
				}
			}
		} else if child_type == "string" || child_type == "word" {
			// Arguments can be strings or words
			arg_text := intern_node_text(arena, child, source)
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

convert_bash_assignment :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	stmt := convert_bash_assignment_to_statement(arena, node, source) // Pass arena
	ir.add_statement(program, stmt)
}

convert_bash_assignment_to_statement :: proc(
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
			variable_name = intern_node_text(arena, child, source) // Pass allocator
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

convert_bash_if_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	condition := ir.Expression(nil)
	then_body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena)) // Use mem.arena_allocator(&arena.arena)
	else_body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena)) // Use mem.arena_allocator(&arena.arena)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "condition" {
			condition = ir.new_raw_expr(arena, extract_condition(arena, child, source))
		} else if child_type == "consequence" {
			convert_bash_body(arena, &then_body, child, source) // Pass arena
		} else if child_type == "alternative" {
			convert_bash_body(arena, &else_body, child, source) // Pass arena
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

extract_condition :: proc(arena: ^ir.Arena_IR, node: ts.Node, source: string) -> string {
	result: strings.Builder
	strings.builder_init(&result)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			text := intern_node_text(arena, child, source) // Pass allocator
			if strings.builder_len(result) > 0 {
				strings.write_byte(&result, ' ')
			}
			strings.write_string(&result, text)
		}
	}
	return strings.to_string(result)
}

convert_bash_for_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	variable_name := ""
	iterable_text := ""
	body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena)) // Use mem.arena_allocator(&arena.arena)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "variable_name" {
			variable_name = intern_node_text(arena, child, source) // Pass allocator
		} else if child_type == "word" {
			if iterable_text == "" {
				iterable_text = intern_node_text(arena, child, source) // Pass allocator
			}
		} else if child_type == "body" || child_type == "c_style_consequence" {
			convert_bash_body(arena, &body, child, source) // Pass arena
		}
	}

	is_c_style := node_type(node) == "for_statement"

	loop := ir.Loop {
		kind     = .ForIn if !is_c_style else .ForC,
		iterator = ir.new_variable(arena, variable_name),
		items    = text_to_expression(arena, iterable_text),
		body     = body,
		location = location,
	}
	return ir.Statement{type = .Loop, loop = loop, location = location}
}

convert_bash_while_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	condition := ir.Expression(nil)
	body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena)) // Use mem.arena_allocator(&arena.arena)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "condition" {
			condition = ir.new_raw_expr(arena, extract_condition(arena, child, source))
		} else if child_type == "body" {
			convert_bash_body(arena, &body, child, source) // Pass arena
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

convert_bash_return_to_statement :: proc(
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
