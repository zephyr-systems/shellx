package integration_tests

import "backend"
import "core:os"
import "core:testing"
import "core:strings"
import "frontend"
import "ir"

@(test)
test_zsh_to_bash_variable :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_variable") { return }
	zsh_code := "x=5"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_bash_function :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_function") { return }
	zsh_code := "function hello() {\n\techo Hello\n}"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_bash_if_statement :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_if_statement") { return }
	zsh_code := "if [[ $x -eq 5 ]]; then\n\techo yes\nfi"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_bash_array :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_array") { return }
	zsh_code := "arr=(one two three)"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_bash_typeset :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_typeset") { return }
	zsh_code := "typeset x=5"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should produce output")
}

@(test)
test_zsh_to_bash_logical_chain :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_logical_chain") { return }
	zsh_code := "foo && ! bar || baz"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, strings.contains(result, "&&"), "Should preserve AND operator")
	testing.expect(t, strings.contains(result, "||"), "Should preserve OR operator")
	testing.expect(t, strings.contains(result, "! bar"), "Should preserve negation")
}

@(test)
test_zsh_to_bash_case_statement :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_case_statement") { return }
	zsh_code := "case \"$x\" in foo|bar) echo ok ;; baz) echo no ;; esac"
	result := translate_code(zsh_code, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, strings.contains(result, "case "), "Should emit case")
	testing.expect(t, strings.contains(result, "foo|bar)"), "Should preserve first case pattern")
	testing.expect(t, strings.contains(result, "esac"), "Should emit esac")
}

@(test)
test_zsh_to_bash_corpus_function_recovery :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_corpus_function_recovery") { return }
	path := "tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
	if !os.is_file(path) {
		return
	}

	result := translate_file(path, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should emit translated output for corpus plugin")
	testing.expect(t, strings.contains(result, "function "), "Translated output should contain recovered functions")
}

@(test)
test_zsh_to_bash_corpus_function_recovery_syntax_highlighting :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_corpus_function_recovery_syntax_highlighting") { return }
	path := "tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
	if !os.is_file(path) {
		return
	}

	result := translate_file(path, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should emit translated output for syntax-highlighting corpus plugin")
	testing.expect(t, strings.contains(result, "function "), "Translated output should contain recovered functions")
}

@(test)
test_zsh_to_bash_corpus_function_recovery_theme :: proc(t: ^testing.T) {
	if !should_run_test("test_zsh_to_bash_corpus_function_recovery_theme") { return }
	path := "tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme"
	if !os.is_file(path) {
		return
	}

	result := translate_file(path, .Zsh, .Bash)
	defer delete(result)

	testing.expect(t, len(result) > 0, "Should emit translated output for theme corpus file")
	testing.expect(t, strings.contains(result, "function "), "Translated output should contain recovered functions")
}
