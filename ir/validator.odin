package ir

import "core:strings"
import "core:fmt"

make_validation_error :: proc(
	error: ValidatorErrorType,
	rule: string,
	message: string,
	location := SourceLocation{},
) -> ValidatorError {
	return ValidatorError{
		error = error,
		rule = rule,
		message = message,
		location = location,
	}
}

validate_expression :: proc(expr: Expression, location: SourceLocation) -> ValidatorError {
	if expr == nil {
		_ = location
		return ValidatorError{error = .None}
	}

	#partial switch e in expr {
	case ^Literal:
		return ValidatorError{error = .None}
	case ^Variable:
		return ValidatorError{error = .None}
	case ^RawExpression:
		return ValidatorError{error = .None}
	case ^TestCondition:
		if strings.trim_space(e.text) == "" {
			return make_validation_error(
				.InvalidControlFlow,
				"condition.text.non_empty",
				"Condition text cannot be empty",
				location,
			)
		}
		return ValidatorError{error = .None}
	case ^UnaryOp:
		return validate_expression(e.operand, location)
	case ^BinaryOp:
		left_err := validate_expression(e.left, location)
		if left_err.error != .None {
			return left_err
		}
		return validate_expression(e.right, location)
	case ^CallExpr:
		if e.function == nil {
			return make_validation_error(
				.UndefinedVariable,
				"call_expr.function.non_nil",
				"Call expression must have a function target",
				location,
			)
		}
		for arg in e.arguments {
			err := validate_expression(arg, location)
			if err.error != .None {
				return err
			}
		}
		return ValidatorError{error = .None}
	case ^ArrayLiteral:
		for elem in e.elements {
			err := validate_expression(elem, location)
			if err.error != .None {
				return err
			}
		}
		return ValidatorError{error = .None}
	}

	return ValidatorError{error = .None}
}

validate_call :: proc(call: Call, location: SourceLocation) -> ValidatorError {
	if call.function == nil {
		return make_validation_error(
			.UndefinedVariable,
			"call.function.non_nil",
			"Command/function call must have a function target",
			location,
		)
	}
	for arg in call.arguments {
		err := validate_expression(arg, location)
		if err.error != .None {
			return err
		}
	}
	return ValidatorError{error = .None}
}

validate_statement :: proc(stmt: Statement) -> ValidatorError {
	switch stmt.type {
	case .Assign:
		if stmt.assign.target == nil {
			return make_validation_error(
				.UndefinedVariable,
				"assign.target.non_nil",
				"Assignment target must have a variable target",
				stmt.assign.location,
			)
		}
		return validate_expression(stmt.assign.value, stmt.assign.location)
	case .Call:
		return validate_call(stmt.call, stmt.call.location)
	case .Logical:
		if len(stmt.logical.segments) == 0 {
			return make_validation_error(
				.InvalidControlFlow,
				"logical.segment.non_empty",
				"Logical chain must contain at least one segment",
				stmt.logical.location,
			)
		}
		if len(stmt.logical.operators) != len(stmt.logical.segments)-1 {
			return make_validation_error(
				.InvalidControlFlow,
				"logical.operators.arity",
				"Logical chain operators must be exactly segments-1",
				stmt.logical.location,
			)
		}
		for seg in stmt.logical.segments {
			err := validate_call(seg.call, seg.call.location)
			if err.error != .None {
				return err
			}
		}
	case .Case:
		err := validate_expression(stmt.case_.value, stmt.case_.location)
		if err.error != .None {
			return err
		}
		for arm in stmt.case_.arms {
			if len(arm.patterns) == 0 {
				return make_validation_error(
					.InvalidControlFlow,
					"case.arm.patterns.non_empty",
					"Case arm must include at least one pattern",
					arm.location,
				)
			}
			for nested in arm.body {
				nested_err := validate_statement(nested)
				if nested_err.error != .None {
					return nested_err
				}
			}
		}
	case .Return:
		if stmt.return_.value != nil {
			return validate_expression(stmt.return_.value, stmt.return_.location)
		}
	case .Branch:
		err := validate_expression(stmt.branch.condition, stmt.branch.location)
		if err.error != .None {
			return err
		}
		for nested in stmt.branch.then_body {
			nested_err := validate_statement(nested)
			if nested_err.error != .None {
				return nested_err
			}
		}
		for nested in stmt.branch.else_body {
			nested_err := validate_statement(nested)
			if nested_err.error != .None {
				return nested_err
			}
		}
	case .Loop:
		switch stmt.loop.kind {
		case .ForIn:
			if stmt.loop.iterator == nil {
				return make_validation_error(
					.UndefinedVariable,
					"loop.forin.iterator.non_nil",
					"For-in loop iterator must exist",
					stmt.loop.location,
				)
			}
			err := validate_expression(stmt.loop.items, stmt.loop.location)
			if err.error != .None {
				return err
			}
		case .ForC, .While, .Until:
			err := validate_expression(stmt.loop.condition, stmt.loop.location)
			if err.error != .None {
				return err
			}
		}
		for nested in stmt.loop.body {
			nested_err := validate_statement(nested)
			if nested_err.error != .None {
				return nested_err
			}
		}
	case .Pipeline:
		if len(stmt.pipeline.commands) == 0 {
			return make_validation_error(
				.InvalidControlFlow,
				"pipeline.commands.non_empty",
				"Pipeline must contain at least one command",
				stmt.pipeline.location,
			)
		}
		for cmd in stmt.pipeline.commands {
			err := validate_call(cmd, cmd.location)
			if err.error != .None {
				return err
			}
		}
	}

	return ValidatorError{error = .None}
}

validate_program :: proc(program: ^Program) -> ValidatorError {
	if program == nil {
		return make_validation_error(
			.InvalidControlFlow,
			"program.non_nil",
			"Program cannot be nil",
		)
	}

	seen_functions := make(map[string]SourceLocation, context.temp_allocator)
	defer delete(seen_functions)

	for fn in program.functions {
		if fn.name != "" {
			if prev, ok := seen_functions[fn.name]; ok {
				return make_validation_error(
					.DuplicateFunction,
					"function.name.unique",
					fmt.tprintf(
						"Duplicate function name '%s' (previous declaration at line %d)",
						fn.name,
						prev.line,
					),
					fn.location,
				)
			}
			seen_functions[fn.name] = fn.location
		}

		param_seen := make(map[string]bool, context.temp_allocator)
		for param in fn.parameters {
			if param == "" {
				continue
			}
			if param_seen[param] {
				return make_validation_error(
					.DuplicateFunction,
					"function.param.unique",
					"Function parameters must be unique",
					fn.location,
				)
			}
			param_seen[param] = true
		}
		delete(param_seen)

		for stmt in fn.body {
			err := validate_statement(stmt)
			if err.error != .None {
				return err
			}
		}
	}

	for stmt in program.statements {
		err := validate_statement(stmt)
		if err.error != .None {
			return make_validation_error(
				err.error,
				err.rule,
				err.message,
				err.location,
			)
		}
	}

	return ValidatorError{error = .None}
}
