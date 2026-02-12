package tree_sitter

import "core:fmt"
import "core:testing"

@(test)
test_zsh_grammar_loads :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_grammar_loads") { return }
	// Test that Zsh grammar can be loaded
	lang := tree_sitter_zsh()
	testing.expect(t, lang != nil, "Zsh grammar should load successfully")
	if lang != nil {
		fmt.println("Zsh grammar loaded successfully")
	}
}

@(test)
test_zsh_parse_simple :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_parse_simple") { return }
	// Test parsing simple Zsh code
	parser := ts_parser_new()
	defer ts_parser_delete(parser)

	lang := tree_sitter_zsh()
	testing.expect(t, lang != nil, "Zsh language should be available")
	if lang == nil {
		return
	}

	ok := ts_parser_set_language(parser, lang)
	testing.expect(t, ok, "Should be able to set Zsh language")
	if !ok {
		return
	}

	code := "echo hello"
	tree := ts_parser_parse_string(parser, nil, cstring(raw_data(code)), u32(len(code)))
	testing.expect(t, tree != nil, "Should be able to parse Zsh code")
	if tree == nil {
		return
	}
	defer ts_tree_delete(tree)

	root := ts_tree_root_node(tree)
	node_type := ts_node_type(root)
	fmt.printf("Zsh root node type: %s\n", node_type)

	testing.expect(t, node_type == "program", "Root should be 'program' node")
}
