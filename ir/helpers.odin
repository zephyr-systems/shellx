package ir

import "core:mem"

// expr_var creates a variable expression.
expr_var :: proc(arena: ^Arena_IR, name: string) -> Expression {
	return new_variable_expr(arena, name)
}

// expr_string creates a string literal expression.
expr_string :: proc(arena: ^Arena_IR, value: string) -> Expression {
	return new_literal_expr(arena, value, .String)
}

// expr_int creates an integer literal expression.
expr_int :: proc(arena: ^Arena_IR, value: string) -> Expression {
	return new_literal_expr(arena, value, .Int)
}

// expr_bool creates a boolean literal expression.
expr_bool :: proc(arena: ^Arena_IR, value: bool) -> Expression {
	if value {
		return new_literal_expr(arena, "true", .Bool)
	}
	return new_literal_expr(arena, "false", .Bool)
}

// expr_raw creates a raw expression from source text.
expr_raw :: proc(arena: ^Arena_IR, text: string) -> Expression {
	return new_raw_expr(arena, text)
}

// expr_test_condition creates a structured test-condition expression.
expr_test_condition :: proc(
	arena: ^Arena_IR,
	text: string,
	syntax: ConditionSyntax,
) -> Expression {
	return new_test_condition_expr(arena, text, syntax)
}

// stmt_assign creates an assignment statement.
stmt_assign :: proc(
	arena: ^Arena_IR,
	target: string,
	value: Expression,
	location := SourceLocation{},
) -> Statement {
	assign := Assign{
		target = new_variable(arena, target),
		value = value,
		location = location,
	}
	return Statement{
		type = .Assign,
		assign = assign,
		location = location,
	}
}

// stmt_call creates a call statement.
stmt_call :: proc(
	arena: ^Arena_IR,
	command: string,
	args: ..Expression,
) -> Statement {
	location := SourceLocation{}
	arguments := make([dynamic]Expression, 0, len(args), mem.arena_allocator(&arena.arena))
	for arg in args {
		append(&arguments, arg)
	}
	call := Call{
		function = new_variable(arena, command),
		arguments = arguments,
		location = location,
	}
	return Statement{
		type = .Call,
		call = call,
		location = location,
	}
}

// stmt_return creates a return statement.
stmt_return :: proc(
	value: Expression,
	location := SourceLocation{},
) -> Statement {
	ret := Return{
		value = value,
		location = location,
	}
	return Statement{
		type = .Return,
		return_ = ret,
		location = location,
	}
}
