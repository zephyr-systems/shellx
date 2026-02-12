package ir

import "core:fmt"
import "core:mem"
import "core:strings"

new_variable :: proc(arena: ^Arena_IR, name: string) -> ^Variable {
	variable := new(Variable, mem.arena_allocator(&arena.arena))
	variable.name = intern_string(arena, name)
	return variable
}

new_literal_expr :: proc(arena: ^Arena_IR, value: string, literal_type: LiteralType) -> Expression {
	lit := new(Literal, mem.arena_allocator(&arena.arena))
	lit.value = intern_string(arena, value)
	lit.type = literal_type
	return lit
}

new_variable_expr :: proc(arena: ^Arena_IR, name: string) -> Expression {
	return new_variable(arena, name)
}

new_raw_expr :: proc(arena: ^Arena_IR, text: string) -> Expression {
	raw := new(RawExpression, mem.arena_allocator(&arena.arena))
	raw.text = intern_string(arena, text)
	return raw
}

normalize_test_condition_text :: proc(text: string, syntax: ConditionSyntax) -> string {
	trimmed := strings.trim_space(text)
	switch syntax {
	case .DoubleBracket:
		if strings.has_prefix(trimmed, "[[") {
			trimmed = strings.trim_space(trimmed[2:])
		}
		if strings.has_suffix(trimmed, "]]") && len(trimmed) >= 2 {
			trimmed = strings.trim_space(trimmed[:len(trimmed)-2])
		}
	case .TestBuiltin:
		if strings.has_prefix(trimmed, "test ") {
			trimmed = strings.trim_space(trimmed[5:])
		}
	case .FishTest:
		if strings.has_prefix(trimmed, "test ") {
			trimmed = strings.trim_space(trimmed[5:])
		}
	case .Unknown, .Command:
	}
	return trimmed
}

new_test_condition_expr :: proc(arena: ^Arena_IR, text: string, syntax: ConditionSyntax) -> Expression {
	cond := new(TestCondition, mem.arena_allocator(&arena.arena))
	cond.text = intern_string(arena, normalize_test_condition_text(text, syntax))
	cond.syntax = syntax
	return cond
}

new_array_expr :: proc(arena: ^Arena_IR, elements: [dynamic]Expression) -> Expression {
	array := new(ArrayLiteral, mem.arena_allocator(&arena.arena))
	array.elements = elements
	return array
}

expr_to_string :: proc(expr: Expression) -> string {
	if expr == nil {
		return ""
	}

	#partial switch e in expr {
	case ^Literal:
		return e.value
	case ^Variable:
		return fmt.tprintf("$%s", e.name)
	case ^RawExpression:
		return e.text
	case ^TestCondition:
		return e.text
	case ^UnaryOp:
		op := "-"
		if e.op == .Not {
			op = "!"
		}
		return fmt.tprintf("%s%s", op, expr_to_string(e.operand))
	case ^BinaryOp:
		op := "+"
		switch e.op {
		case .Add:
			op = "+"
		case .Sub:
			op = "-"
		case .Mul:
			op = "*"
		case .Div:
			op = "/"
		case .Eq:
			op = "=="
		case .Neq:
			op = "!="
		}
		return fmt.tprintf("%s %s %s", expr_to_string(e.left), op, expr_to_string(e.right))
	case ^CallExpr:
		if e.function == nil {
			return ""
		}
		out := e.function.name
		for arg in e.arguments {
			out = fmt.tprintf("%s %s", out, expr_to_string(arg))
		}
		return out
	case ^ArrayLiteral:
		if len(e.elements) == 0 {
			return ""
		}
		out := expr_to_string(e.elements[0])
		for idx in 1 ..< len(e.elements) {
			out = fmt.tprintf("%s %s", out, expr_to_string(e.elements[idx]))
		}
		return out
	}

	return ""
}
