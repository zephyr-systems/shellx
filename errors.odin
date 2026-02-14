package shellx

import "core:fmt"
import "core:strings"
import "ir"

ErrorContext :: struct {
	error:      Error,
	rule_id:    string,
	message:    string,
	location:   ir.SourceLocation,
	suggestion: string,
	snippet:    string,
}

error_to_string :: proc(err: Error) -> string {
	switch err {
	case .None:
		return "none"
	case .ParseError:
		return "parse error"
	case .ParseSyntaxError:
		return "parse syntax error"
	case .ConversionError:
		return "conversion error"
	case .ConversionUnsupportedDialect:
		return "unsupported dialect"
	case .ValidationError:
		return "validation error"
	case .ValidationUndefinedVariable:
		return "validation undefined variable"
	case .ValidationDuplicateFunction:
		return "validation duplicate function"
	case .ValidationInvalidControlFlow:
		return "validation invalid control flow"
	case .EmissionError:
		return "emission error"
	case .IOError:
		return "io error"
	case .InternalError:
		return "internal error"
	}
	return "unknown error"
}

line_from_source :: proc(source: string, line_number: int) -> string {
	if line_number <= 0 || source == "" {
		return ""
	}

	current_line := 1
	start := 0
	for i := 0; i < len(source); i += 1 {
		if current_line == line_number {
			start = i
			break
		}
		if source[i] == '\n' {
			current_line += 1
		}
	}

	if current_line != line_number {
		return ""
	}

	end := len(source)
	for i := start; i < len(source); i += 1 {
		if source[i] == '\n' {
			end = i
			break
		}
	}
	return source[start:end]
}

report_error :: proc(ctx: ErrorContext, source_code := "") -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	strings.write_string(&builder, fmt.tprintf("[%s] %s", error_to_string(ctx.error), ctx.message))

	if ctx.location.line > 0 {
		file := ctx.location.file
		if file == "" {
			file = "<input>"
		}
		strings.write_string(
			&builder,
			fmt.tprintf(" at %s:%d:%d", file, ctx.location.line, ctx.location.column+1),
		)
	}

	code_line := ctx.snippet
	if code_line == "" && source_code != "" && ctx.location.line > 0 {
		code_line = line_from_source(source_code, ctx.location.line)
	}
	if code_line != "" {
		strings.write_string(&builder, "\n")
		strings.write_string(&builder, code_line)
		if ctx.location.column >= 0 {
			strings.write_string(&builder, "\n")
			for _ in 0 ..< ctx.location.column {
				strings.write_byte(&builder, ' ')
			}
			strings.write_byte(&builder, '^')
		}
	}

	if ctx.suggestion != "" {
		strings.write_string(&builder, fmt.tprintf("\nSuggestion: %s", ctx.suggestion))
	}

	return strings.to_string(builder)
}

add_error_context :: proc(
	result: ^TranslationResult,
	err: Error,
	message: string,
	location: ir.SourceLocation,
	suggestion := "",
	snippet := "",
	rule_id := "",
) {
	if result.error == .None {
		result.error = err
	}
	append(
		&result.errors,
		ErrorContext{
			error = err,
			rule_id = strings.clone(rule_id, context.allocator),
			message = strings.clone(message, context.allocator),
			location = location,
			suggestion = strings.clone(suggestion, context.allocator),
			snippet = strings.clone(snippet, context.allocator),
		},
	)
}

// destroy_translation_result releases all heap-owned fields in TranslationResult.
// Call this for every result returned by translate/translate_file/translate_batch elements.
destroy_translation_result :: proc(result: ^TranslationResult) {
	if result.output != "" {
		delete(result.output)
		result.output = ""
	}
	delete(result.warnings)
	delete(result.required_caps)
	delete(result.required_shims)
	delete(result.supported_features)
	delete(result.degraded_features)
	delete(result.unsupported_features)
	for finding in result.findings {
		delete(finding.rule_id)
		delete(finding.message)
		delete(finding.suggestion)
		delete(finding.phase)
	}
	delete(result.findings)
	for ctx in result.errors {
		delete(ctx.rule_id)
		delete(ctx.message)
		delete(ctx.suggestion)
		delete(ctx.snippet)
	}
	delete(result.errors)
}

// destroy_security_scan_result releases all heap-owned fields in SecurityScanResult.
destroy_security_scan_result :: proc(result: ^SecurityScanResult) {
	for finding in result.findings {
		delete(finding.rule_id)
		delete(finding.message)
		delete(finding.suggestion)
		delete(finding.phase)
	}
	delete(result.findings)
	for ctx in result.errors {
		delete(ctx.rule_id)
		delete(ctx.message)
		delete(ctx.suggestion)
		delete(ctx.snippet)
	}
	delete(result.errors)
}
