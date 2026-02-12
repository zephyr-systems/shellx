package unit_tests

import "core:strings"
import "core:testing"
import "../../frontend"
import "../../ir"

LOCAL_SHELLX_TEST_NAME :: #config(LOCAL_SHELLX_TEST_NAME, "")

should_run_local_test :: proc(name: string) -> bool {
	if LOCAL_SHELLX_TEST_NAME == "" {
		return true
	}
	return strings.contains(name, LOCAL_SHELLX_TEST_NAME)
}

@(test)
test_frontend_parse_diagnostics_collection :: proc(t: ^testing.T) {
	if !should_run_local_test("test_frontend_parse_diagnostics_collection") { return }

	code := "if [ ; then\necho hi\n"
	fe := frontend.create_frontend(.Bash)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, code)
	testing.expect(t, parse_err.error == .None, "Tree-sitter parse should return tree")
	if tree == nil {
		return
	}
	defer frontend.destroy_tree(tree)

	diags := frontend.collect_parse_diagnostics(tree, code, "bad.sh")
	defer delete(diags)
	testing.expect(t, len(diags) > 0, "Malformed code should produce diagnostics")
}

@(test)
test_frontend_parse_all_dialects :: proc(t: ^testing.T) {
	if !should_run_local_test("test_frontend_parse_all_dialects") { return }

	cases := []struct {
		dialect: ir.ShellDialect,
		code:    string,
	} {
		{.Bash, "x=1\necho $x"},
		{.Zsh, "typeset x=1\necho $x"},
		{.Fish, "set x 1\necho $x"},
	}

	for c in cases {
		fe := frontend.create_frontend(c.dialect)
		tree, parse_err := frontend.parse(&fe, c.code)
		testing.expect(t, parse_err.error == .None, "Parsing should succeed for dialect")
		if tree != nil {
			frontend.destroy_tree(tree)
		}
		frontend.destroy_frontend(&fe)
	}
}
