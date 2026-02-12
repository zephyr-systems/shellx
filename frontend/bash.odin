package frontend

import ts "../bindings/tree_sitter"
import "../ir"
import "core:fmt"
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
	fmt.println("bash_to_ir: Starting conversion.")
	program := ir.create_program(arena, .Bash)
	root := root_node(tree)

	fmt.println("bash_to_ir: Calling convert_bash_node for root.")
	convert_bash_node(arena, program, root, source)
	fmt.println("bash_to_ir: Finished convert_bash_node for root.")

	return program, FrontendError{}
}

convert_bash_node :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	node_type_str := node_type(node)
	fmt.printf("convert_bash_node: Processing node type '%s'\n", node_type_str)

	// Process specific node types
	switch node_type_str {
	case "program":
		fmt.println("convert_bash_node: Calling convert_bash_program.")
		convert_bash_program(arena, program, node, source)
		return // Don't process children again
	case "function_definition":
		fmt.println("convert_bash_node: Calling convert_bash_function.")
		convert_bash_function(arena, program, node, source)
		return // Don't process children again
	case "command":
		fmt.println("convert_bash_node: Calling convert_bash_command.")
		convert_bash_command(arena, program, node, source)
		return // Don't process children again
	case "variable_assignment":
		fmt.println("convert_bash_node: Calling convert_bash_assignment.")
		convert_bash_assignment(arena, program, node, source)
		return // Don't process children again
	}

	// For other node types, process children
	fmt.printf("convert_bash_node: Iterating children for node type '%s'\n", node_type_str)
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_bash_node(arena, program, child, source)
		}
	}
	fmt.printf(
		"convert_bash_node: Finished iterating children for node type '%s'\n",
		node_type_str,
	)
}

convert_bash_program :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	fmt.println("convert_bash_program: Starting.")
	fmt.printf("convert_bash_program: Raw node value: %p\n", node)
	fmt.printf(
		"convert_bash_program: Root node type: '%s', child count: %d\n",
		node_type(node),
		child_count(node),
	)
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_bash_node(arena, program, child, source)
		}
	}
	fmt.println("convert_bash_program: Finished.")
}

convert_bash_function :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	fmt.println("convert_bash_function: Starting.")
	location := node_location(node, source)
	func_name := ""

	// First pass: extract function name
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "word" && func_name == "" {
			func_name = node_text(mem.arena_allocator(&arena.arena), child, source) // Pass allocator
			fmt.printf("convert_bash_function: Found function name '%s'\n", func_name)
		}
	}

	// Create function with the extracted name
	func := ir.create_function(arena, func_name, location)

	// Second pass: process body
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "compound_statement" || child_type == "body" {
			fmt.println("convert_bash_function: Processing function body")
			convert_bash_body(arena, &func.body, child, source) // Pass arena
		}
	}

	ir.add_function(program, func)
	fmt.println("convert_bash_function: Finished.")
}

convert_bash_body :: proc(
	arena: ^ir.Arena_IR,
	body: ^[dynamic]ir.Statement,
	node: ts.Node,
	source: string,
) {
	fmt.println("convert_bash_body: Starting.")
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			convert_bash_statement(arena, body, child, source) // Pass arena
		}
	}
	fmt.println("convert_bash_body: Finished.")
}

convert_bash_statement :: proc(
	arena: ^ir.Arena_IR,
	body: ^[dynamic]ir.Statement,
	node: ts.Node,
	source: string,
) {
	node_type_str := node_type(node)
	fmt.printf("convert_bash_statement: Processing node type '%s'\n", node_type_str)

	switch node_type_str {
	case "command":
		fmt.println("convert_bash_statement: Calling convert_bash_command_to_statement.")
		stmt := convert_bash_command_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	case "variable_assignment":
		fmt.println("convert_bash_statement: Calling convert_bash_assignment_to_statement.")
		stmt := convert_bash_assignment_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	case "if_statement":
		fmt.println("convert_bash_statement: Calling convert_bash_if_to_statement.")
		stmt := convert_bash_if_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	case "for_statement":
		fmt.println("convert_bash_statement: Calling convert_bash_for_to_statement.")
		stmt := convert_bash_for_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	case "while_statement":
		fmt.println("convert_bash_statement: Calling convert_bash_while_to_statement.")
		stmt := convert_bash_while_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	case "return_statement":
		fmt.println("convert_bash_statement: Calling convert_bash_return_to_statement.")
		stmt := convert_bash_return_to_statement(arena, node, source) // Pass arena
		append(body, stmt)
	}
	fmt.printf("convert_bash_statement: Finished processing node type '%s'\n", node_type_str)
}

convert_bash_command :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	fmt.println("convert_bash_command: Starting.")
	stmt := convert_bash_command_to_statement(arena, node, source) // Pass arena
	ir.add_statement(program, stmt)
	fmt.println("convert_bash_command: Finished.")
}

convert_bash_command_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	fmt.println("convert_bash_command_to_statement: Starting.")
	location := node_location(node, source)
	cmd_name := ""
	arguments := make([dynamic]string, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		// Command name is inside a "command_name" node
		if child_type == "command_name" {
			// Get the word inside command_name
			for j in 0 ..< child_count(child) {
				name_child_node := ts.ts_node_child(child, u32(j))
				if node_type(name_child_node) == "word" {
					cmd_name = node_text(
						mem.arena_allocator(&arena.arena),
						name_child_node,
						source,
					)
					fmt.printf(
						"convert_bash_command_to_statement: Found command name '%s'\n",
						cmd_name,
					)
					break
				}
			}
		} else if child_type == "string" || child_type == "word" {
			// Arguments can be strings or words
			arg_text := node_text(mem.arena_allocator(&arena.arena), child, source)
			append(&arguments, arg_text)
			fmt.printf("convert_bash_command_to_statement: Found argument '%s'\n", arg_text)
		}
	}

	call := ir.Call {
		command   = cmd_name,
		arguments = arguments,
		location  = location,
	}

	fmt.printf(
		"convert_bash_command_to_statement: Command='%s', Args=%d\n",
		cmd_name,
		len(arguments),
	)
	fmt.println("convert_bash_command_to_statement: Finished.")
	return ir.Statement{type = .Call, call = call, location = location}
}

convert_bash_assignment :: proc(
	arena: ^ir.Arena_IR,
	program: ^ir.Program,
	node: ts.Node,
	source: string,
) {
	fmt.println("convert_bash_assignment: Starting.")
	stmt := convert_bash_assignment_to_statement(arena, node, source) // Pass arena
	ir.add_statement(program, stmt)
	fmt.println("convert_bash_assignment: Finished.")
}

convert_bash_assignment_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	fmt.println("convert_bash_assignment_to_statement: Starting.")
	location := node_location(node, source)
	variable_name := ""
	value := ""

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "variable_name" {
			variable_name = node_text(mem.arena_allocator(&arena.arena), child, source) // Pass allocator
		} else if child_type == "word" || child_type == "number" {
			value = node_text(mem.arena_allocator(&arena.arena), child, source) // Pass allocator
		}
	}

	assign := ir.Assign {
		variable = variable_name,
		value    = value,
		location = location,
	}

	fmt.println("convert_bash_assignment_to_statement: Finished.")
	return ir.Statement{type = .Assign, assign = assign, location = location}
}

convert_bash_if_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	fmt.println("convert_bash_if_to_statement: Starting.")
	location := node_location(node, source)
	condition := ""
	then_body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena)) // Use mem.arena_allocator(&arena.arena)
	else_body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena)) // Use mem.arena_allocator(&arena.arena)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "condition" {
			condition = extract_condition(arena, child, source)
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

	fmt.println("convert_bash_if_to_statement: Finished.")
	return ir.Statement{type = .Branch, branch = branch, location = location}
}

extract_condition :: proc(arena: ^ir.Arena_IR, node: ts.Node, source: string) -> string {
	fmt.println("extract_condition: Starting.")
	result: strings.Builder
	strings.builder_init(&result)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if is_named(child) {
			text := node_text(mem.arena_allocator(&arena.arena), child, source) // Pass allocator
			if strings.builder_len(result) > 0 {
				strings.write_byte(&result, ' ')
			}
			strings.write_string(&result, text)
		}
	}

	fmt.println("extract_condition: Finished.")
	return strings.to_string(result)
}

convert_bash_for_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	fmt.println("convert_bash_for_to_statement: Starting.")
	location := node_location(node, source)
	variable_name := ""
	iterable := ""
	body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena)) // Use mem.arena_allocator(&arena.arena)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "variable_name" {
			variable_name = node_text(mem.arena_allocator(&arena.arena), child, source) // Pass allocator
		} else if child_type == "word" {
			if iterable == "" {
				iterable = node_text(mem.arena_allocator(&arena.arena), child, source) // Pass allocator
			}
		} else if child_type == "body" || child_type == "c_style_consequence" {
			convert_bash_body(arena, &body, child, source) // Pass arena
		}
	}

	is_c_style := node_type(node) == "for_statement"

	loop := ir.Loop {
		kind     = .ForIn if !is_c_style else .ForC,
		variable = variable_name,
		iterable = iterable,
		body     = body,
		location = location,
	}

	fmt.println("convert_bash_for_to_statement: Finished.")
	return ir.Statement{type = .Loop, loop = loop, location = location}
}

convert_bash_while_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	fmt.println("convert_bash_while_to_statement: Starting.")
	location := node_location(node, source)
	condition := ""
	body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena)) // Use mem.arena_allocator(&arena.arena)

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "condition" {
			condition = extract_condition(arena, child, source)
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

	fmt.println("convert_bash_while_to_statement: Finished.")
	return ir.Statement{type = .Loop, loop = loop, location = location}
}

convert_bash_return_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	fmt.println("convert_bash_return_to_statement: Starting.")
	location := node_location(node, source)
	value := ""

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		if node_type(child) == "word" {
			value = node_text(mem.arena_allocator(&arena.arena), child, source) // Pass allocator
			break
		}
	}

	ret := ir.Return {
		value    = value,
		location = location,
	}

	fmt.println("convert_bash_return_to_statement: Finished.")
	return ir.Statement{type = .Return, return_ = ret, location = location}
}
