package tree_sitter

import "core:fmt"
import "core:testing"

@(test)
test_fish_grammar_loads :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_grammar_loads") { return }
	// Test that Fish grammar can be loaded
	lang := tree_sitter_fish()
	testing.expect(t, lang != nil, "Fish grammar should load successfully")
	if lang != nil {
		fmt.println("Fish grammar loaded successfully")
	}
}

@(test)
test_fish_parse_simple :: proc(t: ^testing.T) {
	if !should_run_test("test_fish_parse_simple") { return }
	// Test parsing simple Fish code
	parser := ts_parser_new()
	defer ts_parser_delete(parser)

	lang := tree_sitter_fish()
	testing.expect(t, lang != nil, "Fish language should be available")
	if lang == nil {
		return
	}

	ok := ts_parser_set_language(parser, lang)
	testing.expect(t, ok, "Should be able to set Fish language")
	if !ok {
		return
	}

	code := "echo hello"
	tree := ts_parser_parse_string(parser, nil, cstring(raw_data(code)), u32(len(code)))
	testing.expect(t, tree != nil, "Should be able to parse Fish code")
	if tree == nil {
		return
	}
	defer ts_tree_delete(tree)

	root := ts_tree_root_node(tree)
	node_type := ts_node_type(root)
	fmt.printf("Fish root node type: %s\n", node_type)

	testing.expect(t, node_type == "program", "Root should be 'program' node")
}
