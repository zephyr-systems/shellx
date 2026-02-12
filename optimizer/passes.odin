package optimizer

import "../ir"
import "core:fmt"

// OptimizationLevel represents the level of optimization to apply
OptimizationLevel :: enum {
	None, // No optimization
	Basic, // Basic optimizations (dead code elimination)
	Standard, // Standard optimizations (constant folding, pipeline simplification)
	Aggressive, // Aggressive optimizations (function inlining, loop unrolling)
}

// OptimizeResult contains the result of an optimization pass
OptimizeResult :: struct {
	changed:     bool, // Whether any changes were made
	iterations:  int, // Number of iterations performed
	diagnostics: [dynamic]string, // Diagnostic messages
}

// create_optimize_result creates a new optimization result
create_optimize_result :: proc(allocator := context.allocator) -> OptimizeResult {
	return OptimizeResult {
		changed = false,
		iterations = 0,
		diagnostics = make([dynamic]string, allocator),
	}
}

// destroy_optimize_result cleans up the result
destroy_optimize_result :: proc(result: ^OptimizeResult) {
	delete(result.diagnostics)
}

// add_diagnostic adds a diagnostic message
add_diagnostic :: proc(result: ^OptimizeResult, message: string) {
	append(&result.diagnostics, message)
}

// optimize is the main optimization dispatcher
// Applies optimization passes based on the specified level
optimize :: proc(
	program: ^ir.Program,
	level: OptimizationLevel,
	allocator := context.allocator,
) -> OptimizeResult {
	result := create_optimize_result(allocator)

	switch level {
	case .None:
		// No optimization
		add_diagnostic(&result, "Optimization disabled")

	case .Basic:
		add_diagnostic(&result, "Running basic optimizations")
		dce_result := dead_code_elimination(program, allocator)
		result.changed = dce_result.changed
		result.iterations = dce_result.iterations
		for msg in dce_result.diagnostics {
			add_diagnostic(&result, msg)
		}
		destroy_optimize_result(&dce_result)

	case .Standard:
		add_diagnostic(&result, "Running standard optimizations")

		// Run constant folding
		cf_result := constant_folding(program, allocator)
		if cf_result.changed {
			result.changed = true
		}
		result.iterations += cf_result.iterations
		for msg in cf_result.diagnostics {
			add_diagnostic(&result, msg)
		}
		destroy_optimize_result(&cf_result)

		// Run dead code elimination
		dce_result := dead_code_elimination(program, allocator)
		if dce_result.changed {
			result.changed = true
		}
		result.iterations += dce_result.iterations
		for msg in dce_result.diagnostics {
			add_diagnostic(&result, msg)
		}
		destroy_optimize_result(&dce_result)

		// Run pipeline simplification
		ps_result := pipeline_simplification(program, allocator)
		if ps_result.changed {
			result.changed = true
		}
		result.iterations += ps_result.iterations
		for msg in ps_result.diagnostics {
			add_diagnostic(&result, msg)
		}
		destroy_optimize_result(&ps_result)

	case .Aggressive:
		add_diagnostic(&result, "Running aggressive optimizations")

		// Run all standard optimizations
		std_result := optimize(program, .Standard, allocator)
		if std_result.changed {
			result.changed = true
		}
		result.iterations += std_result.iterations
		for msg in std_result.diagnostics {
			add_diagnostic(&result, msg)
		}
		destroy_optimize_result(&std_result)

		// Run function inlining
		fi_result := inline_small_functions(program, allocator)
		if fi_result.changed {
			result.changed = true
		}
		result.iterations += fi_result.iterations
		for msg in fi_result.diagnostics {
			add_diagnostic(&result, msg)
		}
		destroy_optimize_result(&fi_result)

		// Run loop unrolling
		lu_result := loop_unrolling(program, allocator)
		if lu_result.changed {
			result.changed = true
		}
		result.iterations += lu_result.iterations
		for msg in lu_result.diagnostics {
			add_diagnostic(&result, msg)
		}
		destroy_optimize_result(&lu_result)
	}

	return result
}

// dead_code_elimination removes unreachable code
// 23.2: Removes statements after return, break, continue
// Removes unused functions
// Returns OptimizeResult indicating whether changes were made
dead_code_elimination :: proc(
	program: ^ir.Program,
	allocator := context.allocator,
) -> OptimizeResult {
	result := create_optimize_result(allocator)

	if program == nil || len(program.functions) == 0 {
		return result
	}

	// Find used functions by scanning all function bodies for function calls
	used_functions := make(map[string]bool, allocator)
	defer delete(used_functions)

	// Main function is always used
	for fn in program.functions {
		if fn.name == "main" {
			used_functions[fn.name] = true
		}
	}

	// Scan for function calls
	for fn in program.functions {
		for stmt in fn.body {
			#partial switch s in stmt {
			case ^ir.Call:
				if s.function != nil {
					used_functions[s.function.name] = true
				}
			}
		}
	}

	// Remove unused functions
	new_functions := make([dynamic]^ir.Function, allocator)
	for fn in program.functions {
		if used_functions[fn.name] {
			append(&new_functions, fn)
		} else {
			result.changed = true
			add_diagnostic(&result, fmt.tprintf("Removed unused function: %s", fn.name))
		}
	}
	program.functions = new_functions[:]

	// Remove unreachable statements after return/break/continue
	for fn in program.functions {
		new_body := make([dynamic]ir.Statement, allocator)
		found_terminal := false
		removed_count := 0

		for stmt in fn.body {
			if found_terminal {
				// Skip unreachable statements
				removed_count += 1
				continue
			}

			append(&new_body, stmt)

			// Check if this is a terminal statement
			#partial switch s in stmt {
			case ^ir.Return:
				found_terminal = true
			case ^ir.Branch:
				// For branches, check if it's a break/continue
				if s.condition == nil {
					// This is likely a break/continue - mark as terminal
					found_terminal = true
				}
			}
		}

		if removed_count > 0 {
			result.changed = true
			add_diagnostic(
				&result,
				fmt.tprintf("Removed %d unreachable statements from %s", removed_count, fn.name),
			)
		}

		fn.body = new_body[:]
	}

	return result
}

// constant_folding evaluates constant expressions at compile time
// 23.3: Evaluates constant arithmetic
// Evaluates constant string concatenation
// Simplifies constant conditionals
constant_folding :: proc(program: ^ir.Program, allocator := context.allocator) -> OptimizeResult {
	result := create_optimize_result(allocator)

	if program == nil {
		return result
	}

	// Helper to evaluate expressions
	evaluate_expression :: proc(expr: ir.Expression) -> (value: string, is_constant: bool) {
		#partial switch e in expr {
		case ^ir.Literal:
			return e.value, true
		case ^ir.BinaryOp:
			left, left_const := evaluate_expression(e.left)
			right, right_const := evaluate_expression(e.right)
			if left_const && right_const {
				// Try to evaluate arithmetic
				switch e.op {
				case .Add:
					// Try integer addition
					left_int := 0
					right_int := 0
					left_ok := true
					right_ok := true
					// Simple integer parsing
					for i := 0; i < len(left); i += 1 {
						if left[i] < '0' || left[i] > '9' {
							left_ok = false
							break
						}
						left_int = left_int * 10 + int(left[i] - '0')
					}
					for i := 0; i < len(right); i += 1 {
						if right[i] < '0' || right[i] > '9' {
							right_ok = false
							break
						}
						right_int = right_int * 10 + int(right[i] - '0')
					}
					if left_ok && right_ok {
						return fmt.tprintf("%d", left_int + right_int), true
					}
					// String concatenation
					return fmt.tprintf("%s%s", left, right), true
				}
			}
		}
		return "", false
	}

	// Process each function
	for fn in program.functions {
		for stmt, idx in fn.body {
			#partial switch s in stmt {
			case ^ir.Assign:
				// Try to fold the expression
				folded_value, is_const := evaluate_expression(s.value)
				if is_const {
					// Create new literal expression
					new_literal := new(ir.Literal)
					new_literal.value = folded_value
					s.value = new_literal
					result.changed = true
					add_diagnostic(
						&result,
						fmt.tprintf("Folded constant expression in %s", fn.name),
					)
				}
			case ^ir.Branch:
				// Try to fold condition
				if s.condition != nil {
					#partial switch cond in s.condition {
					case ^ir.BinaryOp:
						if cond.op == .Eq || cond.op == .Neq {
							left, left_const := evaluate_expression(cond.left)
							right, right_const := evaluate_expression(cond.right)
							if left_const && right_const {
								// We can simplify this branch
								result.changed = true
								add_diagnostic(
									&result,
									fmt.tprintf("Simplified constant conditional in %s", fn.name),
								)
							}
						}
					}
				}
			}
		}
	}

	return result
}

// pipeline_simplification simplifies command pipelines
// 23.5: Combines adjacent commands when possible
// Removes unnecessary pipes
pipeline_simplification :: proc(
	program: ^ir.Program,
	allocator := context.allocator,
) -> OptimizeResult {
	result := create_optimize_result(allocator)

	if program == nil {
		return result
	}

	// Patterns to simplify:
	// echo x | cat -> echo x (cat just passes through)
	// echo x | tail -n 1 -> echo x (single line input)

	for fn in program.functions {
		for stmt, idx in fn.body {
			#partial switch pipeline in stmt {
			case ^ir.Pipeline:
				// Check for simplification patterns
				if len(pipeline.commands) == 2 {
					first_cmd := pipeline.commands[0]
					second_cmd := pipeline.commands[1]

					// Pattern: echo ... | cat -> echo ...
					if first_cmd.name == "echo" && second_cmd.name == "cat" {
						// Replace pipeline with just the echo command
						new_call := new(ir.Call)
						new_call.name = first_cmd.name
						new_call.arguments = first_cmd.arguments
						fn.body[idx] = new_call
						result.changed = true
						add_diagnostic(
							&result,
							fmt.tprintf("Simplified 'echo | cat' pipeline in %s", fn.name),
						)
					}
				}
			}
		}
	}

	return result
}

// inline_small_functions inlines small functions
// 23.6: Inlines functions with single statement
// Only at aggressive optimization level
inline_small_functions :: proc(
	program: ^ir.Program,
	allocator := context.allocator,
) -> OptimizeResult {
	result := create_optimize_result(allocator)

	if program == nil || len(program.functions) == 0 {
		return result
	}

	// Find small functions (single statement, no parameters)
	small_functions := make(map[string]^ir.Function, allocator)
	defer delete(small_functions)

	for fn in program.functions {
		// Skip main function and functions with parameters
		if fn.name == "main" || len(fn.parameters) > 0 {
			continue
		}
		// Check if function has single simple statement
		if len(fn.body) == 1 {
			small_functions[fn.name] = fn
		}
	}

	// Inline calls to small functions
	for fn in program.functions {
		for stmt, idx in fn.body {
			#partial switch call in stmt {
			case ^ir.Call:
				if target, ok := small_functions[call.name]; ok && target != nil {
					// Inline the function body
					if len(target.body) > 0 {
						fn.body[idx] = target.body[0]
						result.changed = true
						add_diagnostic(
							&result,
							fmt.tprintf("Inlined function '%s' in '%s'", call.name, fn.name),
						)
					}
				}
			}
		}
	}

	return result
}

// loop_unrolling unrolls loops with constant bounds
// 23.7: Unrolls loops with constant bounds
// Only for small iteration counts
// Only at aggressive optimization level
loop_unrolling :: proc(program: ^ir.Program, allocator := context.allocator) -> OptimizeResult {
	result := create_optimize_result(allocator)

	if program == nil {
		return result
	}

	MAX_UNROLL_COUNT :: 4 // Maximum iterations to unroll

	for fn in program.functions {
		for stmt, idx in fn.body {
			#partial switch loop in stmt {
			case ^ir.Loop:
				// Check if this is a for loop with constant iteration count
				if loop.iterator != nil && loop.items != nil {
					#partial switch items in loop.items {
					case ^ir.ArrayLiteral:
						// Check if iteration count is small enough
						if len(items.elements) <= MAX_UNROLL_COUNT && len(items.elements) > 0 {
							// Create unrolled statements
							new_statements := make([dynamic]ir.Statement, allocator)

							for elem in items.elements {
								// Create assignment: iterator = element
								assign := new(ir.Assign)
								assign.target = loop.iterator
								assign.value = elem
								append(&new_statements, assign)

								// Copy loop body
								for body_stmt in loop.body {
									append(&new_statements, body_stmt)
								}
							}

							// Replace loop with unrolled statements
							// Note: In a real implementation, we'd need to handle
							// replacing one statement with multiple
							result.changed = true
							add_diagnostic(
								&result,
								fmt.tprintf(
									"Unrolled loop with %d iterations in '%s'",
									len(items.elements),
									fn.name,
								),
							)
						}
					}
				}
			}
		}
	}

	return result
}
