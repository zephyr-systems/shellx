package frontend

import ts "../bindings/tree_sitter"
import "../ir"
import "core:fmt"
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
	case "if_statement":
		stmt := convert_fish_if_to_statement(arena, node, source)
		ir.add_statement(program, stmt)
		return
	case "for_statement":
		stmt := convert_fish_for_to_statement(arena, node, source)
		ir.add_statement(program, stmt)
		return
	case "while_statement":
		stmt := convert_fish_while_to_statement(arena, node, source)
		ir.add_statement(program, stmt)
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
	func_name := extract_fish_function_name(arena, node, source)
	if func_name == "" {
		func_name = "shellx_fish_fn"
	}
	if !is_fish_basic_name(func_name) {
		func_name = "shellx_fish_fn_dynamic"
	}
	func_name = ensure_unique_function_name(program, func_name)

	func := ir.create_function(arena, func_name, location)

	// Process body. In tree-sitter-fish, function_definition often exposes body
	// statements directly as children rather than wrapping in a dedicated body node.
	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "compound_statement" || child_type == "body" || child_type == "block" {
			convert_fish_body(arena, &func.body, child, source)
		} else if child_type == "command" || child_type == "if_statement" || child_type == "for_statement" || child_type == "while_statement" || child_type == "return_statement" {
			convert_fish_statement(arena, &func.body, child, source)
		}
	}

	ir.add_function(program, func)
}

extract_fish_function_name :: proc(arena: ^ir.Arena_IR, node: ts.Node, source: string) -> string {
	// Prefer structural extraction from function_definition children.
	for i in 0 ..< child_count(node) {
		ch := child(node, i)
		if !is_named(ch) {
			continue
		}
		ch_type := node_type(ch)
		if ch_type == "name" || ch_type == "word" || ch_type == "identifier" {
			candidate := strings.trim_space(intern_node_text(arena, ch, source))
			if candidate != "" && candidate != "function" && !strings.has_prefix(candidate, "-") {
				return candidate
			}
		}
	}

	raw := intern_node_text(arena, node, source)
	line := strings.trim_space(raw)
	nl := strings.index(line, "\n")
	if nl >= 0 {
		line = strings.trim_space(line[:nl])
	}
	if strings.has_prefix(line, "function ") {
		line = strings.trim_space(line[len("function "):])
	}
	tokens := strings.split(line, " ")
	defer delete(tokens)
	expect_arg_for_flag := false
	candidate := ""
	for tok in tokens {
		t := strings.trim_space(tok)
		if t == "" {
			continue
		}
		if expect_arg_for_flag {
			expect_arg_for_flag = false
			continue
		}
		if strings.has_prefix(t, "-") {
			// function flags that consume one following argument.
			if t == "-d" || t == "--description" ||
				t == "-a" || t == "--argument" ||
				t == "-v" || t == "--on-variable" ||
				t == "-w" || t == "--wraps" ||
				t == "-e" || t == "--on-event" ||
				t == "-j" || t == "--on-job-exit" ||
				t == "-p" || t == "--on-process-exit" ||
				t == "-s" || t == "--on-signal" ||
				t == "-V" || t == "--inherit-variable" {
				expect_arg_for_flag = true
			}
			continue
		}
		candidate = t
		break
	}
	return candidate
}

ensure_unique_function_name :: proc(program: ^ir.Program, name: string) -> string {
	if name == "" {
		return "shellx_fish_fn"
	}
	base := name
	candidate := base
	suffix := 2
	for {
		exists := false
		for fn in program.functions {
			if fn.name == candidate {
				exists = true
				break
			}
		}
		if !exists {
			return candidate
		}
		candidate = fmt.tprintf("%s__%d", base, suffix)
		suffix += 1
	}
}

is_fish_basic_name :: proc(s: string) -> bool {
	if s == "" {
		return false
	}
	first := s[0]
	if !((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z') || first == '_') {
		return false
	}
	for i in 1 ..< len(s) {
		c := s[i]
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_') {
			return false
		}
	}
	return true
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
	case:
		// Recursively traverse unhandled nodes so nested statements are not dropped.
		for i in 0 ..< child_count(node) {
			child_node := child(node, i)
			if is_named(child_node) {
				convert_fish_statement(arena, body, child_node, source)
			}
		}
	}
}

make_fish_raw_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	raw := strings.trim_space(intern_node_text(arena, node, source))
	if raw == "" {
		raw = ":"
	}
	call := ir.Call{
		function = ir.new_variable(arena, raw),
		arguments = make([dynamic]ir.Expression, 0, 0, mem.arena_allocator(&arena.arena)),
		location = location,
	}
	return ir.Statement{type = .Call, call = call, location = location}
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
	values := make([dynamic]ir.Expression, 0, 4, mem.arena_allocator(&arena.arena))

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "word" || child_type == "string" || child_type == "double_quote_string" || child_type == "single_quote_string" || child_type == "raw_string" || child_type == "concatenation" || child_type == "simple_expansion" || child_type == "expansion" || child_type == "variable_expansion" {
			text := intern_node_text(arena, child, source)
			// Skip 'set' command itself
			if text == "set" {
				continue
			}
			// Skip flags like -g, -l, -x, -U
			if strings.has_prefix(text, "-") {
				continue
			}
			// First non-flag word is variable name
			if variable_name == "" && child_type == "word" {
				variable_name = text
			} else {
				append(&values, text_to_expression(arena, text))
			}
		}
	}

	value := ir.Expression(nil)
	if len(values) == 1 {
		value = values[0]
	} else if len(values) > 1 {
		value = ir.new_array_expr(arena, values)
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
				if is_named(name_child_node) {
					cmd_name = node_text(
						mem.arena_allocator(&arena.arena),
						name_child_node,
						source,
					)
					break
				}
			}
		} else if child_type == "string" || child_type == "word" || child_type == "double_quote_string" || child_type == "single_quote_string" || child_type == "raw_string" || child_type == "concatenation" || child_type == "simple_expansion" || child_type == "expansion" || child_type == "variable_expansion" || child_type == "command_substitution" || child_type == "number" {
			arg_text := intern_node_text(arena, child, source)
			append(&arguments, text_to_expression(arena, arg_text))
		}
	}
	if cmd_name == "" && len(arguments) > 0 {
		cmd_name = strings.trim_space(ir.expr_to_string(arguments[0]))
		if len(arguments) > 1 {
			remaining := make([dynamic]ir.Expression, 0, len(arguments)-1, mem.arena_allocator(&arena.arena))
			for i in 1 ..< len(arguments) {
				append(&remaining, arguments[i])
			}
			arguments = remaining
		} else {
			clear(&arguments)
		}
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

convert_fish_if_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	condition := ir.Expression(nil)
	then_body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena))
	else_body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena))
	in_else := false

	for i in 0 ..< child_count(node) {
		child_node := child(node, i)
		child_type := node_type(child_node)

		if child_type == "condition" {
			condition = new_fish_condition_expr(arena, child_node, source)
		} else if child_type == "consequence" {
			convert_fish_body(arena, &then_body, child_node, source)
		} else if child_type == "alternative" {
			convert_fish_body(arena, &else_body, child_node, source)
		} else if child_type == "command" {
			if condition == nil {
				condition = new_fish_condition_expr(arena, child_node, source)
			} else if in_else {
				convert_fish_statement(arena, &else_body, child_node, source)
			} else {
				convert_fish_statement(arena, &then_body, child_node, source)
			}
		} else if child_type == "else_clause" {
			in_else = true
			for j in 0 ..< child_count(child_node) {
				n := child(child_node, j)
				if is_named(n) {
					convert_fish_statement(arena, &else_body, n, source)
				}
			}
		} else if child_type == "else_if_clause" {
			in_else = true
			nested := convert_fish_if_to_statement(arena, child_node, source)
			append(&else_body, nested)
		}
	}
	if condition == nil && len(then_body) == 0 && len(else_body) == 0 {
		return make_fish_raw_statement(arena, node, source)
	}

	branch := ir.Branch {
		condition = condition,
		then_body = then_body,
		else_body = else_body,
		location  = location,
	}

	return ir.Statement{type = .Branch, branch = branch, location = location}
}

new_fish_condition_expr :: proc(arena: ^ir.Arena_IR, node: ts.Node, source: string) -> ir.Expression {
	text := extract_fish_condition(arena, node, source)
	trimmed := strings.trim_space(text)
	syntax := ir.ConditionSyntax.Unknown
	if strings.has_prefix(trimmed, "test ") {
		syntax = .FishTest
	}
	return ir.new_test_condition_expr(arena, text, syntax)
}

extract_fish_condition :: proc(arena: ^ir.Arena_IR, node: ts.Node, source: string) -> string {
	result := strings.builder_make()
	defer strings.builder_destroy(&result)

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

	return ir.intern_string(arena, strings.to_string(result))
}

convert_fish_for_to_statement :: proc(
	arena: ^ir.Arena_IR,
	node: ts.Node,
	source: string,
) -> ir.Statement {
	location := node_location(node, source)
	variable_name := ""
	iter_builder := strings.builder_make()
	defer strings.builder_destroy(&iter_builder)
	body := make([dynamic]ir.Statement, 0, 4, mem.arena_allocator(&arena.arena))
	in_header := true

	for i in 0 ..< child_count(node) {
		child := child(node, i)
		child_type := node_type(child)

		if child_type == "variable_name" {
			variable_name = intern_node_text(arena, child, source)
		} else if child_type == "word" {
			if in_header {
				word := strings.trim_space(intern_node_text(arena, child, source))
				if word != "" && word != "in" {
					if strings.builder_len(iter_builder) > 0 {
						strings.write_byte(&iter_builder, ' ')
					}
					strings.write_string(&iter_builder, word)
				}
			}
		} else if child_type == "body" {
			in_header = false
			convert_fish_body(arena, &body, child, source)
		} else if child_type == "command" || child_type == "if_statement" || child_type == "for_statement" || child_type == "while_statement" || child_type == "return_statement" {
			in_header = false
			convert_fish_statement(arena, &body, child, source)
		}
	}
	iterable_text := strings.clone(strings.to_string(iter_builder), context.temp_allocator)
	if variable_name == "" && len(body) == 0 {
		return make_fish_raw_statement(arena, node, source)
	}
	if iterable_text == "" {
		iterable_text = "\"\""
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
			condition = new_fish_condition_expr(arena, child, source)
		} else if child_type == "body" {
			convert_fish_body(arena, &body, child, source)
		} else if child_type == "command" {
			if condition == nil {
				condition = new_fish_condition_expr(arena, child, source)
			} else {
				convert_fish_statement(arena, &body, child, source)
			}
		} else if child_type == "if_statement" || child_type == "for_statement" || child_type == "while_statement" || child_type == "return_statement" {
			convert_fish_statement(arena, &body, child, source)
		}
	}
	if condition == nil && len(body) == 0 {
		return make_fish_raw_statement(arena, node, source)
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
