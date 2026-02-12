package optimizer

import "../ir"
import "core:fmt"

ExprAtomKind :: enum {
	None,
	Literal,
	Variable,
	Raw,
}

ExprKeyKind :: enum {
	Unary,
	Binary,
}

ExprKey :: struct {
	kind: ExprKeyKind,
	op:   int,

	left_kind:  ExprAtomKind,
	left_value: string,

	right_kind:  ExprAtomKind,
	right_value: string,
}

cse_temp_name :: proc(index: int) -> string {
	switch index {
	case 0:
		return "__cse_0"
	case 1:
		return "__cse_1"
	case 2:
		return "__cse_2"
	case 3:
		return "__cse_3"
	case 4:
		return "__cse_4"
	case 5:
		return "__cse_5"
	case 6:
		return "__cse_6"
	case 7:
		return "__cse_7"
	case:
		return fmt.tprintf("__cse_%d", index)
	}
}

expr_atom :: proc(expr: ir.Expression) -> (ExprAtomKind, string, bool) {
	if expr == nil {
		return .None, "", false
	}
	#partial switch e in expr {
	case ^ir.Literal:
		return .Literal, e.value, true
	case ^ir.Variable:
		return .Variable, e.name, true
	case ^ir.RawExpression:
		return .Raw, e.text, true
	}
	return .None, "", false
}

expr_key :: proc(expr: ir.Expression) -> (ExprKey, bool) {
	if expr == nil {
		return ExprKey{}, false
	}

	#partial switch e in expr {
	case ^ir.UnaryOp:
		operand_kind, operand_value, ok := expr_atom(e.operand)
		if !ok {
			return ExprKey{}, false
		}
		return ExprKey{
			kind = .Unary,
			op = int(e.op),
			left_kind = operand_kind,
			left_value = operand_value,
		}, true
	case ^ir.BinaryOp:
		left_kind, left_value, left_ok := expr_atom(e.left)
		right_kind, right_value, right_ok := expr_atom(e.right)
		if !left_ok || !right_ok {
			return ExprKey{}, false
		}
		return ExprKey{
			kind = .Binary,
			op = int(e.op),
			left_kind = left_kind,
			left_value = left_value,
			right_kind = right_kind,
			right_value = right_value,
		}, true
	}

	return ExprKey{}, false
}

collect_expr_counts :: proc(expr: ir.Expression, counts: ^map[ExprKey]int) {
	if expr == nil {
		return
	}

	#partial switch e in expr {
	case ^ir.BinaryOp:
		collect_expr_counts(e.left, counts)
		collect_expr_counts(e.right, counts)
	case ^ir.UnaryOp:
		collect_expr_counts(e.operand, counts)
	case ^ir.CallExpr:
		for arg in e.arguments {
			collect_expr_counts(arg, counts)
		}
	case ^ir.ArrayLiteral:
		for elem in e.elements {
			collect_expr_counts(elem, counts)
		}
	}

	if key, ok := expr_key(expr); ok {
		counts[key] += 1
	}
}

collect_stmt_counts :: proc(stmt: ir.Statement, counts: ^map[ExprKey]int) {
	switch stmt.type {
	case .Assign:
		collect_expr_counts(stmt.assign.value, counts)
	case .Call:
		for arg in stmt.call.arguments {
			collect_expr_counts(arg, counts)
		}
	case .Logical:
		for segment in stmt.logical.segments {
			for arg in segment.call.arguments {
				collect_expr_counts(arg, counts)
			}
		}
	case .Return:
		collect_expr_counts(stmt.return_.value, counts)
	case .Branch:
		collect_expr_counts(stmt.branch.condition, counts)
		for nested in stmt.branch.then_body {
			collect_stmt_counts(nested, counts)
		}
		for nested in stmt.branch.else_body {
			collect_stmt_counts(nested, counts)
		}
	case .Loop:
		collect_expr_counts(stmt.loop.items, counts)
		collect_expr_counts(stmt.loop.condition, counts)
		for nested in stmt.loop.body {
			collect_stmt_counts(nested, counts)
		}
	case .Pipeline:
		for cmd in stmt.pipeline.commands {
			for arg in cmd.arguments {
				collect_expr_counts(arg, counts)
			}
		}
	}
}

find_common_subexpressions :: proc(
	body: []ir.Statement,
	allocator := context.allocator,
) -> map[ExprKey]bool {
	counts := make(map[ExprKey]int, allocator)
	defer delete(counts)

	for stmt in body {
		collect_stmt_counts(stmt, &counts)
	}

	common := make(map[ExprKey]bool, allocator)
	for key, count in counts {
		if count > 1 {
			common[key] = true
		}
	}

	return common
}

replace_common_expr :: proc(
	expr: ir.Expression,
	common: map[ExprKey]bool,
	names: ^map[ExprKey]string,
	extracted: ^map[ExprKey]bool,
	insert_before: ^[dynamic]ir.Statement,
	location: ir.SourceLocation,
	allocator := context.allocator,
) -> (ir.Expression, bool) {
	if expr == nil {
		return nil, false
	}

	changed := false
	#partial switch e in expr {
	case ^ir.BinaryOp:
		left, left_changed := replace_common_expr(
			e.left,
			common,
			names,
			extracted,
			insert_before,
			location,
			allocator,
		)
		right, right_changed := replace_common_expr(
			e.right,
			common,
			names,
			extracted,
			insert_before,
			location,
			allocator,
		)
		if left_changed {
			e.left = left
			changed = true
		}
		if right_changed {
			e.right = right
			changed = true
		}
	case ^ir.UnaryOp:
		operand, operand_changed := replace_common_expr(
			e.operand,
			common,
			names,
			extracted,
			insert_before,
			location,
			allocator,
		)
		if operand_changed {
			e.operand = operand
			changed = true
		}
	case ^ir.CallExpr:
		for &arg, idx in e.arguments {
			repl, arg_changed := replace_common_expr(
				arg,
				common,
				names,
				extracted,
				insert_before,
				location,
				allocator,
			)
			if arg_changed {
				e.arguments[idx] = repl
				changed = true
			}
		}
	case ^ir.ArrayLiteral:
		for &elem, idx in e.elements {
			repl, elem_changed := replace_common_expr(
				elem,
				common,
				names,
				extracted,
				insert_before,
				location,
				allocator,
			)
			if elem_changed {
				e.elements[idx] = repl
				changed = true
			}
		}
	}

	if key, ok := expr_key(expr); ok && common[key] {
		temp_name, has_name := names^[key]
		if !has_name {
			temp_name = cse_temp_name(len(names^))
			names^[key] = temp_name
		}

		if !extracted^[key] {
			temp_var := new(ir.Variable, allocator)
			temp_var.name = temp_name

			extract_stmt := ir.Statement{
				type = .Assign,
				assign = ir.Assign{
					target = temp_var,
					value = expr,
					location = location,
				},
				location = location,
			}
			append(insert_before, extract_stmt)
			extracted^[key] = true
		}

		repl_var := new(ir.Variable, allocator)
		repl_var.name = temp_name
		return repl_var, true
	}

	return expr, changed
}

cse_block :: proc(body: ^[dynamic]ir.Statement, allocator := context.allocator) -> bool {
	common := find_common_subexpressions(body[:], allocator)
	defer delete(common)

	if len(common) == 0 {
		return false
	}

	names := make(map[ExprKey]string, allocator)
	defer delete(names)
	extracted := make(map[ExprKey]bool, allocator)
	defer delete(extracted)

	new_body := make([dynamic]ir.Statement, 0, len(body), allocator)
	changed := false

	for &stmt in body {
		insert_before := make([dynamic]ir.Statement, 0, 2, allocator)
		#partial switch stmt.type {
		case .Assign:
			repl, repl_changed := replace_common_expr(
				stmt.assign.value,
				common,
				&names,
				&extracted,
				&insert_before,
				stmt.location,
				allocator,
			)
			if repl_changed {
				stmt.assign.value = repl
				changed = true
			}
		case .Call:
			for &arg, idx in stmt.call.arguments {
				repl, repl_changed := replace_common_expr(
					arg,
					common,
					&names,
					&extracted,
				&insert_before,
					stmt.location,
					allocator,
				)
				if repl_changed {
					stmt.call.arguments[idx] = repl
					changed = true
				}
			}
		case .Return:
			repl, repl_changed := replace_common_expr(
				stmt.return_.value,
				common,
				&names,
				&extracted,
				&insert_before,
				stmt.location,
				allocator,
			)
			if repl_changed {
				stmt.return_.value = repl
				changed = true
			}
		case .Logical:
			for &segment, seg_idx in stmt.logical.segments {
				for &arg, arg_idx in segment.call.arguments {
					repl, repl_changed := replace_common_expr(
						arg,
						common,
						&names,
						&extracted,
						&insert_before,
						stmt.location,
						allocator,
					)
					if repl_changed {
						stmt.logical.segments[seg_idx].call.arguments[arg_idx] = repl
						changed = true
					}
				}
			}
		case .Branch:
			repl, repl_changed := replace_common_expr(
				stmt.branch.condition,
				common,
				&names,
				&extracted,
				&insert_before,
				stmt.location,
				allocator,
			)
			if repl_changed {
				stmt.branch.condition = repl
				changed = true
			}
			if cse_block(&stmt.branch.then_body, allocator) {
				changed = true
			}
			if cse_block(&stmt.branch.else_body, allocator) {
				changed = true
			}
		case .Loop:
			items_repl, items_changed := replace_common_expr(
				stmt.loop.items,
				common,
				&names,
				&extracted,
				&insert_before,
				stmt.location,
				allocator,
			)
			if items_changed {
				stmt.loop.items = items_repl
				changed = true
			}

			cond_repl, cond_changed := replace_common_expr(
				stmt.loop.condition,
				common,
				&names,
				&extracted,
				&insert_before,
				stmt.location,
				allocator,
			)
			if cond_changed {
				stmt.loop.condition = cond_repl
				changed = true
			}

			if cse_block(&stmt.loop.body, allocator) {
				changed = true
			}
		case .Pipeline:
			for &cmd, cmd_idx in stmt.pipeline.commands {
				for &arg, arg_idx in cmd.arguments {
					repl, repl_changed := replace_common_expr(
						arg,
						common,
						&names,
						&extracted,
				&insert_before,
						stmt.location,
						allocator,
					)
					if repl_changed {
						stmt.pipeline.commands[cmd_idx].arguments[arg_idx] = repl
						changed = true
					}
				}
			}
		}

		for inserted in insert_before {
			append(&new_body, inserted)
		}
		append(&new_body, stmt)
	}

	if changed {
		delete(body^)
		body^ = new_body
	} else {
		delete(new_body)
	}
	return changed
}

common_subexpression_elimination :: proc(
	program: ^ir.Program,
	allocator := context.allocator,
) -> OptimizeResult {
	result := create_optimize_result(allocator)
	if program == nil {
		return result
	}

	for &fn in program.functions {
		if cse_block(&fn.body, allocator) {
			result.changed = true
			add_diagnostic(&result, "Eliminated common subexpressions")
		}
	}

	return result
}
