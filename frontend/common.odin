package frontend

import "../ir"
import ts "../bindings/tree_sitter"
import "core:strings"
import "core:fmt"
import "core:mem" // Add this import

FrontendError :: struct {
	error: Error,
	message: string,
	location: ir.SourceLocation,
}

ParseDiagnostic :: struct {
	message:    string,
	location:   ir.SourceLocation,
	suggestion: string,
	snippet:    string,
}

Error :: enum {
	None,
	ParseError,
	ConversionError,
}

Frontend :: struct {
	dialect: ir.ShellDialect,
	parser: ^ts.Parser,
}

create_frontend :: proc(dialect: ir.ShellDialect) -> Frontend {
	parser := ts.ts_parser_new()
	lang := get_language(dialect)
	ts.ts_parser_set_language(parser, lang)

	return Frontend{
		dialect = dialect,
		parser = parser,
	}
}

destroy_frontend :: proc(f: ^Frontend) {
	if f.parser != nil {
		ts.ts_parser_delete(f.parser)
		f.parser = nil
	}
}

get_language :: proc(dialect: ir.ShellDialect) -> ^ts.Language {
	switch dialect {
	case .Bash:
		return ts.tree_sitter_bash()
	case .Zsh:
		return ts.tree_sitter_zsh()
	case .Fish:
		return ts.tree_sitter_fish()
	case .POSIX:
		return ts.tree_sitter_bash()
	}
	return nil
}

parse :: proc(f: ^Frontend, source: string) -> (^ts.Tree, FrontendError) {
	tree := ts.ts_parser_parse_string(
		f.parser,
		nil,
		cstring(raw_data(source)),
		u32(len(source)),
	)

	if tree == nil {
		return nil, FrontendError{
			error = .ParseError,
			message = "Failed to parse source",
		}
	}

	return tree, FrontendError{}
}

collect_parse_diagnostics :: proc(
	tree: ^ts.Tree,
	source: string,
	source_name := "<input>",
	allocator := context.allocator,
) -> [dynamic]ParseDiagnostic {
	diagnostics := make([dynamic]ParseDiagnostic, allocator)
	if tree == nil {
		return diagnostics
	}

	root := root_node(tree)

	walk :: proc(
		node: ts.Node,
		source: string,
		source_name: string,
		diagnostics: ^[dynamic]ParseDiagnostic,
		allocator: mem.Allocator,
	) {
		if node_type(node) == "ERROR" {
			loc := node_location(node, source)
			loc.file = source_name
			append(
				diagnostics,
				ParseDiagnostic{
					message = "Syntax error",
					location = loc,
					suggestion = "Check shell syntax near this location",
				},
			)
		}
		for i in 0 ..< child_count(node) {
			walk(child(node, i), source, source_name, diagnostics, allocator)
		}
	}

	walk(root, source, source_name, &diagnostics, allocator)

	if len(diagnostics) == 0 && has_error(root) {
		loc := node_location(root, source)
		loc.file = source_name
		append(
			&diagnostics,
			ParseDiagnostic{
				message = "Parse tree contains syntax errors",
				location = loc,
				suggestion = "Fix malformed statements and retry translation",
			},
		)
	}

	return diagnostics
}

destroy_tree :: proc(tree: ^ts.Tree) {
	if tree != nil {
		ts.ts_tree_delete(tree)
	}
}

node_location :: proc(node: ts.Node, source: string) -> ir.SourceLocation {
	start := int(ts.ts_node_start_byte(node))
	end := int(ts.ts_node_end_byte(node))
	start_point := ts.ts_node_start_point(node)
	end_point := ts.ts_node_end_point(node)

	lines := 0
	col := 0
	for i in 0..<start {
		if source[i] == '\n' {
			lines += 1
			col = 0
		} else {
			col += 1
		}
	}

	return ir.SourceLocation{
		line = int(start_point.row) + 1,
		column = int(start_point.column),
		length = end - start,
	}
}

node_type :: proc(node: ts.Node) -> string {
	cstr := ts.ts_node_type(node)
	if cstr == nil {
		return ""
	}
	return string(cstr)
}

child_count :: proc(node: ts.Node) -> int {
	return int(ts.ts_node_child_count(node))
}

named_child_count :: proc(node: ts.Node) -> int {
	return int(ts.ts_node_named_child_count(node))
}

child :: proc(node: ts.Node, index: int) -> ts.Node {
	return ts.ts_node_child(node, u32(index))
}

named_child :: proc(node: ts.Node, index: int) -> ts.Node {
	return ts.ts_node_named_child(node, u32(index))
}

is_named :: proc(node: ts.Node) -> bool {
	return ts.ts_node_is_named(node)
}

has_error :: proc(node: ts.Node) -> bool {
	return ts.ts_node_has_error(node)
}

root_node :: proc(tree: ^ts.Tree) -> ts.Node {
	return ts.ts_tree_root_node(tree)
}

node_text :: proc(allocator: mem.Allocator, node: ts.Node, source: string) -> string {
	start := int(ts.ts_node_start_byte(node))
	end := int(ts.ts_node_end_byte(node))
	if start >= 0 && end <= len(source) && start <= end {
		text_slice := source[start:end]
		buffer := make([]byte, len(text_slice), allocator)
		copy(buffer, text_slice)
		return string(buffer)
	}
	return ""
}

text_to_expression :: proc(arena: ^ir.Arena_IR, text: string) -> ir.Expression {
	if text == "" {
		return nil
	}

	if text[0] == '$' && len(text) > 1 {
		return ir.new_variable_expr(arena, text[1:])
	}

	is_integer := true
	for i in 0 ..< len(text) {
		if text[i] < '0' || text[i] > '9' {
			is_integer = false
			break
		}
	}
	if is_integer {
		return ir.new_literal_expr(arena, text, .Int)
	}

	if text == "true" || text == "false" {
		return ir.new_literal_expr(arena, text, .Bool)
	}

	return ir.new_literal_expr(arena, text, .String)
}
