package integration_tests

import shellx "../.."
import "core:strings"
import "core:testing"

LOCAL_SHELLX_TEST_NAME :: #config(LOCAL_SHELLX_TEST_NAME, "")

should_run_local_test :: proc(name: string) -> bool {
	if LOCAL_SHELLX_TEST_NAME == "" {
		return true
	}
	return strings.contains(name, LOCAL_SHELLX_TEST_NAME)
}

@(test)
test_options_strict_mode_integration :: proc(t: ^testing.T) {
	if !should_run_local_test("test_options_strict_mode_integration") { return }

	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.strict_mode = true

	result := shellx.translate("arr=(one two three)", .Bash, .Fish, opts)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, !result.success, "Strict mode should fail on Bash->Fish compatibility errors")
}

@(test)
test_options_insert_shims_integration :: proc(t: ^testing.T) {
	if !should_run_local_test("test_options_insert_shims_integration") { return }

	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true

	result := shellx.translate("if [[ $x == y ]]; then echo ok; fi", .Bash, .Fish, opts)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, len(result.required_shims) > 0, "Insert shims should collect required shims")
	testing.expect(t, strings.contains(result.output, "__shellx_test"), "Shim prelude should be injected")
	testing.expect(t, strings.contains(result.output, "if __shellx_test"), "Condition callsite should be rewritten to shim wrapper")
}

@(test)
test_options_insert_shims_hook_rewrite_integration :: proc(t: ^testing.T) {
	if !should_run_local_test("test_options_insert_shims_hook_rewrite_integration") { return }

	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true

	result := shellx.translate("add-zsh-hook precmd my_precmd", .Zsh, .Bash, opts)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, result.success, "Translation should succeed with hook rewrite")
	testing.expect(t, strings.contains(result.output, "__shellx_register_hook"), "Hook callsite should be rewritten to shim wrapper")
}

@(test)
test_options_optimization_level_integration :: proc(t: ^testing.T) {
	if !should_run_local_test("test_options_optimization_level_integration") { return }

	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.optimization_level = .Aggressive

	result := shellx.translate("x=1\ny=1\n", .Bash, .Bash, opts)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, result.success, "Aggressive optimization path should run")
}

@(test)
test_options_insert_shims_fish_string_match_to_bash :: proc(t: ^testing.T) {
	if !should_run_local_test("test_options_insert_shims_fish_string_match_to_bash") { return }

	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true

	src := "if string match -q 'foo*' $x\n\techo ok\nend"
	result := shellx.translate(src, .Fish, .Bash, opts)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, result.success, "Fish string match condition should translate with shims")
	testing.expect(t, strings.contains(result.output, "__shellx_match"), "String match should be rewritten to __shellx_match")
	testing.expect(t, !strings.contains(result.output, "if string match"), "Raw fish string match should not remain in bash condition")
}

@(test)
test_options_insert_shims_fish_string_match_to_zsh :: proc(t: ^testing.T) {
	if !should_run_local_test("test_options_insert_shims_fish_string_match_to_zsh") { return }

	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true

	src := "if string match -q 'foo*' $x\n\techo ok\nend"
	result := shellx.translate(src, .Fish, .Zsh, opts)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, result.success, "Fish string match condition should translate to zsh with shims")
	testing.expect(t, strings.contains(result.output, "__shellx_match"), "String match should be rewritten to __shellx_match")
}

@(test)
test_options_zsh_to_bash_parameter_expansion_rewrite_simple :: proc(t: ^testing.T) {
	if !should_run_local_test("test_options_zsh_to_bash_parameter_expansion_rewrite_simple") { return }

	src := "echo ${(@)arr} ${(@k)map} ${name:l} ${name:u}"
	result := shellx.translate(src, .Zsh, .Bash, shellx.DEFAULT_TRANSLATION_OPTIONS)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, result.success, "Zsh->Bash translation should succeed for parameter expansion rewrite")
	testing.expect(t, strings.contains(result.output, "${arr[@]}"), "Should rewrite ${(@)arr} to bash array expansion")
	testing.expect(t, strings.contains(result.output, "${!map[@]}"), "Should rewrite ${(@k)map} to bash assoc-key expansion")
	testing.expect(t, strings.contains(result.output, "${name,,}"), "Should rewrite :l modifier to bash lowercase modifier")
	testing.expect(t, strings.contains(result.output, "${name^^}"), "Should rewrite :u modifier to bash uppercase modifier")
	testing.expect(t, !strings.contains(result.output, "(@)"), "Should not leave zsh array modifier syntax in output")
	testing.expect(t, !strings.contains(result.output, ":l}"), "Should not leave zsh lowercase modifier syntax in output")
	testing.expect(t, !strings.contains(result.output, ":u}"), "Should not leave zsh uppercase modifier syntax in output")
}

@(test)
test_options_zsh_to_bash_parameter_expansion_rewrite_nested :: proc(t: ^testing.T) {
	if !should_run_local_test("test_options_zsh_to_bash_parameter_expansion_rewrite_nested") { return }

	src := "echo ${(@)A:-${(@)B}}"
	result := shellx.translate(src, .Zsh, .Bash, shellx.DEFAULT_TRANSLATION_OPTIONS)
	defer shellx.destroy_translation_result(&result)
	testing.expect(t, result.success, "Nested zsh array expansion should translate to bash")
	testing.expect(t, strings.contains(result.output, "${A[@]:-${B[@]}}"), "Should rewrite nested zsh array modifiers inside default expansion")
}
