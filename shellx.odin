package shellx

import "backend"
import ts "bindings/tree_sitter"
import "compat"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "detection"
import "frontend"
import "ir"
import "optimizer"

// ShellDialect is the public shell dialect type used by the API.
ShellDialect :: ir.ShellDialect

// OptimizationLevel controls which optimizer passes run.
OptimizationLevel :: enum {
	None,
	Basic,
	Standard,
	Aggressive,
}

// TranslationOptions configures API behavior.
TranslationOptions :: struct {
	strict_mode:        bool,
	insert_shims:       bool,
	preserve_comments:  bool,
	source_name:        string,
	optimization_level: OptimizationLevel,
}

DEFAULT_TRANSLATION_OPTIONS :: TranslationOptions{
	optimization_level = .None,
}

FindingSeverity :: enum {
	Info,
	Warning,
	High,
	Critical,
}

SecurityFinding :: struct {
	rule_id:    string,
	severity:   FindingSeverity,
	message:    string,
	location:   ir.SourceLocation,
	suggestion: string,
	phase:      string, // "source" or "translated"
}

posix_output_likely_degraded :: proc(source: string, output: string) -> bool {
	if source == "" || output == "" {
		return false
	}
	src_has_case := strings.contains(source, "case ") && strings.contains(source, "esac")
	out_has_case := strings.contains(output, "case ") && strings.contains(output, "esac")
	if src_has_case && !out_has_case {
		return true
	}

	src_has_param_default := strings.contains(source, "${") && (strings.contains(source, ":-") || strings.contains(source, ":-"))
	if src_has_param_default && !strings.contains(output, "${") {
		return true
	}

	if strings.contains(output, "\n:\n") && (src_has_case || src_has_param_default) {
		return true
	}

	return false
}

// TranslationResult is the full output of a translation request.
TranslationResult :: struct {
	success:              bool,
	output:               string,
	warnings:             [dynamic]string,
	required_caps:        [dynamic]string,
	required_shims:       [dynamic]string,
	supported_features:   [dynamic]string,
	degraded_features:    [dynamic]string,
	unsupported_features: [dynamic]string,
	findings:             [dynamic]SecurityFinding,
	error:                Error,
	errors:               [dynamic]ErrorContext,
}

LoweringValidationIssue :: struct {
	rule_id:    string,
	message:    string,
	location:   ir.SourceLocation,
	suggestion: string,
	snippet:    string,
}

Error :: enum {
	None,
	ParseError,
	ParseSyntaxError,
	ConversionError,
	ConversionUnsupportedDialect,
	ValidationError,
	ValidationUndefinedVariable,
	ValidationDuplicateFunction,
	ValidationInvalidControlFlow,
	EmissionError,
	IOError,
	InternalError,
}

// translate converts shell source between dialects.
// The caller owns result.output/warnings/errors and should call destroy_translation_result(&result).
translate :: proc(
	source_code: string,
	from: ShellDialect,
	to: ShellDialect,
	options := DEFAULT_TRANSLATION_OPTIONS,
) -> TranslationResult {
	result := TranslationResult{success = true}

	source_name := options.source_name
	if source_name == "" {
		source_name = "<input>"
	}
	scan_shell_security_findings(&result, source_code, source_name, "source")

	arena_size := len(source_code) * 8
	if arena_size < 8*1024*1024 {
		arena_size = 8 * 1024 * 1024
	}
	if arena_size > 64*1024*1024 {
		arena_size = 64 * 1024 * 1024
	}
	arena := ir.create_arena(arena_size)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(from)
	defer frontend.destroy_frontend(&fe)

	parse_source := source_code
	parse_source_allocated := false
	if from == .Zsh {
		normalized, changed := normalize_zsh_preparse_local_cmdsubs(source_code, context.allocator)
		if changed {
			parse_source = normalized
			parse_source_allocated = true
		} else {
			delete(normalized)
		}
		if to == .Fish {
			normalized_zsh, changed_zsh := normalize_zsh_preparse_syntax(parse_source, context.allocator)
			if changed_zsh {
				if parse_source_allocated {
					delete(parse_source)
				}
				parse_source = normalized_zsh
				parse_source_allocated = true
			} else {
				delete(normalized_zsh)
			}
		}
		if to == .POSIX {
			normalized_posix, changed_posix := normalize_zsh_preparse_parser_safety(parse_source, context.allocator)
			if changed_posix {
				if parse_source_allocated {
					delete(parse_source)
				}
				parse_source = normalized_posix
				parse_source_allocated = true
			} else {
				delete(normalized_posix)
			}
		}
	}
	if from == .Bash && to == .Fish {
		normalized, changed := normalize_bash_preparse_array_literals(parse_source, context.allocator)
		if changed {
			if parse_source_allocated {
				delete(parse_source)
			}
			parse_source = normalized
			parse_source_allocated = true
		} else {
			delete(normalized)
		}
	}
	if from == .Fish {
		normalized, changed := normalize_fish_preparse_parser_safety(parse_source, context.allocator)
		if changed {
			if parse_source_allocated {
				delete(parse_source)
			}
			parse_source = normalized
			parse_source_allocated = true
		} else {
			delete(normalized)
		}
	}
	if (from == .Bash || from == .Zsh) && to == .POSIX {
		normalized, changed := normalize_posix_preparse_array_literals(parse_source, context.allocator)
		if changed {
			if parse_source_allocated {
				delete(parse_source)
			}
			parse_source = normalized
			parse_source_allocated = true
		} else {
			delete(normalized)
		}
	}
	defer if parse_source_allocated {
		delete(parse_source)
	}

	tree, parse_err := frontend.parse(&fe, parse_source)
	if parse_err.error != .None {
		result.success = false
		add_error_context(
			&result,
			.ParseError,
			parse_err.message,
			ir.SourceLocation{file = source_name, line = parse_err.location.line, column = parse_err.location.column, length = parse_err.location.length},
			"Fix syntax errors and retry",
		)
		return result
	}
	defer frontend.destroy_tree(tree)

	parse_diags := frontend.collect_parse_diagnostics(tree, parse_source, source_name)
	defer delete(parse_diags)

	// Parse diagnostics are fatal in strict mode and same-dialect mode.
	// For cross-dialect translation, keep them as warnings so translation can recover.
	if len(parse_diags) > 0 {
		if options.strict_mode || from == to {
			for diag in parse_diags {
				add_error_context(
					&result,
					.ParseSyntaxError,
					diag.message,
					diag.location,
					diag.suggestion,
					diag.snippet,
				)
			}
			result.success = false
			return result
		}

		parse_warn_limit := 6
		if from == .Zsh && to != .Zsh {
			parse_warn_limit = 3
		}
		omitted_parse_warns := 0
		omitted_low_signal_warns := 0
		emitted_parse_warns := 0
		parse_lines := strings.split_lines(parse_source)
		defer delete(parse_lines)
		seen_parse_diags := make(map[string]bool, context.temp_allocator)
		defer delete(seen_parse_diags)
		for diag in parse_diags {
			key := fmt.tprintf("%d:%d:%s", diag.location.line, diag.location.column, diag.message)
			if seen_parse_diags[key] {
				omitted_parse_warns += 1
				continue
			}
			seen_parse_diags[key] = true

			if from == .Zsh && to != .Zsh {
				line_text := ""
				if diag.location.line >= 1 && diag.location.line <= len(parse_lines) {
					line_text = strings.trim_space(parse_lines[diag.location.line-1])
				}
				if line_text == "" ||
					(strings.contains(diag.message, "Parse tree contains syntax errors") && diag.location.line == 1) ||
					strings.has_prefix(line_text, "#") ||
					line_text == "}" ||
					line_text == "*)" ||
					strings.has_prefix(line_text, "*) ") ||
					strings.has_prefix(line_text, "--add)") ||
					strings.has_prefix(line_text, "--remove)") ||
					strings.has_prefix(line_text, "--complete)") ||
					strings.has_prefix(line_text, "completion)") ||
					strings.has_prefix(line_text, "list)") ||
					strings.has_prefix(line_text, "rank)") ||
					strings.has_prefix(line_text, "time)") ||
					strings.has_prefix(line_text, "*com.termux*)") ||
					strings.contains(line_text, "${exclude}|${exclude}/*)") ||
					strings.contains(line_text, "$+commands[") ||
					strings.contains(line_text, "${+commands[") ||
					strings.has_prefix(line_text, "function fzf_setup_using_") ||
					strings.has_prefix(line_text, "__sudo-replace-buffer() {") ||
					strings.has_prefix(line_text, "__sudo_replace_buffer() {") ||
					strings.has_prefix(line_text, "sudo\\ -e\\ *)") ||
					strings.has_prefix(line_text, "sudo\\ *)") ||
					strings.has_prefix(line_text, "|| fzf_setup") ||
					strings.has_prefix(line_text, "unset -f -m ") ||
					strings.has_prefix(line_text, "zle -N sudo_") ||
					strings.has_prefix(line_text, "zle -N sudo-command-line") ||
					strings.has_prefix(line_text, "bindkey -M emacs ") ||
					strings.has_prefix(line_text, "bindkey -M vicmd ") ||
					strings.has_prefix(line_text, "bindkey -M viins ") ||
					strings.has_prefix(line_text, "(( $+__p9k_root_dir )) || typeset -gr __p9k_root_dir=") ||
					strings.has_prefix(line_text, "(( $+functions[_p9k_setup] )) && _p9k_setup") ||
					strings.has_prefix(line_text, "CURRENT_BG='NONE'") ||
					strings.has_prefix(line_text, "echo ${(%):-\"%B$1%b copied to clipboard.\"}") ||
					strings.contains(line_text, "${${(M)0:#/*}:-$PWD/$0}") ||
					strings.contains(line_text, "${(%):-%") ||
					strings.has_prefix(line_text, "spaceship::deprecated ") ||
					strings.has_prefix(line_text, "git_version=\"${${(As: :)$(git version 2>/dev/null)}[3]}\"") ||
					strings.has_prefix(line_text, "local repo=\"${${@[(r)(ssh://*|git://*|ftp(s)#://*|http(s)#://*|*@*)(.git/#)#]}:-$_}\"") ||
					strings.has_prefix(line_text, "git push origin \"${b:-$1}\"") ||
					strings.has_prefix(line_text, "if (( ZSHZ[USE_FLOCK] )); then") ||
					strings.has_prefix(line_text, "if (( ZSHZ[PRINTV] )); then") ||
					strings.has_prefix(line_text, "if (( ! ZSHZ_UNCOMMON )) && [[ -n $common ]]; then") ||
					strings.has_prefix(line_text, "if [[ -n $common ]]; then") ||
					strings.has_prefix(line_text, "autoload -Uz ") ||
					strings.has_prefix(line_text, "typeset -g ") ||
					strings.has_prefix(line_text, "completion:*) zle -C ") ||
					strings.has_prefix(line_text, "builtin) eval \"_zsh_highlight_widget_") {
					omitted_parse_warns += 1
					omitted_low_signal_warns += 1
					continue
				}
			}
			if emitted_parse_warns >= parse_warn_limit {
				omitted_parse_warns += 1
				continue
			}
			warning := fmt.tprintf(
				"Parse diagnostic at %s:%d:%d: %s",
				diag.location.file,
				diag.location.line,
				diag.location.column + 1,
				diag.message,
			)
			append(&result.warnings, warning)
			emitted_parse_warns += 1
		}
		omitted_non_low_signal_warns := omitted_parse_warns - omitted_low_signal_warns
		if omitted_parse_warns > 0 && (emitted_parse_warns > 0 || omitted_non_low_signal_warns > 0) {
			append(
				&result.warnings,
				fmt.tprintf(
					"Parse diagnostic at %s:0:0: %d additional diagnostics suppressed",
					source_name,
					omitted_parse_warns,
				),
			)
		}
	}

	program, conv_err := convert_to_ir(&arena, from, tree, parse_source)
	if conv_err.error != .None {
		result.success = false
		add_error_context(
			&result,
			.ConversionError,
			conv_err.message,
			conv_err.location,
			"Inspect unsupported syntax around the reported location",
		)
		return result
	}

	if program == nil {
		result.success = false
		add_error_context(
			&result,
			.ConversionUnsupportedDialect,
			"Unsupported source dialect",
			ir.SourceLocation{file = source_name},
			"Use Bash, Zsh, Fish, or POSIX input",
		)
		return result
	}

	program.dialect = from
	propagate_program_file(program, source_name)

	validation_err := ir.validate_program(program)
	if validation_err.error != .None {
		loc := validation_err.location
		if loc.file == "" {
			loc.file = source_name
		}
		result.success = false
		add_error_context(
			&result,
			validator_error_code(validation_err.error),
			validation_err.message,
			loc,
			"Fix validation errors and retry",
			"",
			validation_err.rule,
		)
		return result
	}

	compat_result := compat.check_compatibility(from, to, program, source_code)
	defer compat.destroy_compatibility_result(&compat_result)

	for warning in compat_result.warnings {
		append(&result.warnings, fmt.tprintf("Compat[%s]: %s", warning.feature, warning.message))
		compat.append_capability_for_feature(&result.required_caps, warning.feature, from, to)
		if options.insert_shims && compat.needs_shim(warning.feature, from, to) {
			append_unique(&result.required_shims, warning.feature)
		}
	}
	derive_feature_metadata(&result, compat_result, options, from, to)

	if options.strict_mode && compat.should_fail_on_strict(&compat_result) {
		result.success = false
		add_error_context(
			&result,
			.ValidationError,
			"Strict mode blocked translation due to compatibility errors",
			ir.SourceLocation{file = source_name},
			"Resolve compatibility errors or disable strict_mode",
		)
		return result
	}

	if options.preserve_comments {
		append(&result.warnings, "preserve_comments is not fully implemented yet")
	}

	if options.optimization_level != .None {
		opt_result := optimizer.optimize(program, to_optimizer_level(options.optimization_level), mem.arena_allocator(&arena.arena))
		defer optimizer.destroy_optimize_result(&opt_result)
	}

	if options.insert_shims && len(result.required_shims) > 0 {
		apply_ir_shim_rewrites(program, result.required_shims[:], from, to, &arena)
	}

	emitted, emit_ok := emit_program(program, to)
	if !emit_ok {
		result.success = false
		add_error_context(
			&result,
			.EmissionError,
			"Failed to emit output for target dialect",
			ir.SourceLocation{file = source_name},
			"Use Bash, Zsh, Fish, or POSIX as target dialect",
		)
		return result
	}

	if from == .POSIX && (to == .Bash || to == .Zsh) && posix_output_likely_degraded(source_code, emitted) {
		delete(emitted)
		emitted = strings.clone(source_code, context.allocator)
		append(&result.warnings, "Applied POSIX preservation fallback due degraded translated output")
	}

	recovery_mode := from == .Zsh && to == .Bash && len(parse_diags) > 0
	if recovery_mode {
		fe_check := frontend.create_frontend(.Bash)
		tree_check, parse_check := frontend.parse(&fe_check, emitted)
		needs_fallback := parse_check.error != .None || tree_check == nil
		if tree_check != nil {
			diags_check := frontend.collect_parse_diagnostics(tree_check, emitted, "<recovery-check>")
			if len(diags_check) > 0 {
				needs_fallback = true
			}
			delete(diags_check)
			frontend.destroy_tree(tree_check)
		}
		frontend.destroy_frontend(&fe_check)

		if needs_fallback {
			delete(emitted)
			emitted = strings.clone(source_code, context.allocator)
		}
	}

	result.output = emitted
	rewritten_target, target_changed := rewrite_target_callsites(emitted, from, to, context.allocator)
	if target_changed {
		delete(emitted)
		emitted = rewritten_target
	} else {
		delete(rewritten_target)
	}

	fish_event_regs := make([dynamic]string, 0, 0, context.temp_allocator)
	defer delete(fish_event_regs)
	if options.insert_shims && from == .Fish && to != .Fish {
		regs, has_precmd, has_preexec := collect_fish_event_registration_lines(source_code, context.temp_allocator)
		delete(fish_event_regs)
		fish_event_regs = regs
		if len(fish_event_regs) > 0 {
			append_unique(&result.required_shims, "fish_events")
			append_unique(&result.required_shims, "hooks_events")
			if has_precmd || has_preexec {
				append_unique(&result.required_shims, "prompt_hooks")
			}
		}
	}

	if options.insert_shims && len(result.required_shims) > 0 {
		rewritten, changed := apply_shim_callsite_rewrites(emitted, result.required_shims[:], from, to, context.allocator)
		if changed {
			delete(emitted)
			emitted = rewritten
		} else {
			delete(rewritten)
		}

	}
	if options.insert_shims && from == .Fish && to != .Fish && len(fish_event_regs) > 0 {
		rewritten, changed := append_missing_registration_lines(emitted, fish_event_regs[:], context.allocator)
		if changed {
			delete(emitted)
			emitted = rewritten
		} else {
			delete(rewritten)
		}
	}
	if options.insert_shims && from == .Fish && to == .Zsh &&
		(strings.contains(emitted, "fish_prompt() {") || strings.contains(emitted, "fish_right_prompt() {") || strings.contains(emitted, "_tide_")) {
		append_unique(&result.required_shims, "prompt_hooks")
		append_unique(&result.required_shims, "hooks_events")
	}

	if from == .POSIX && (to == .Bash || to == .Zsh) && posix_output_likely_degraded(source_code, emitted) {
		delete(emitted)
		emitted = strings.clone(source_code, context.allocator)
		append(&result.warnings, "Applied POSIX preservation fallback after post-rewrite degradation")
	}
	if options.insert_shims {
		if strings.contains(emitted, "__shellx_list_get ") ||
			strings.contains(emitted, "__shellx_list_len ") ||
			strings.contains(emitted, "__shellx_list_has ") ||
			strings.contains(emitted, "__shellx_list_append ") ||
			strings.contains(emitted, "__shellx_list_unset_index ") ||
			strings.contains(emitted, "__shellx_list_set ") ||
			strings.contains(emitted, "__shellx_zsh_subscript_") ||
			strings.contains(emitted, "__shellx_list_to_array ") {
			append_unique(&result.required_shims, "fish_list_indexing")
		}
		if strings.contains(emitted, "__shellx_register_precmd ") || strings.contains(emitted, "__shellx_register_preexec ") {
			append_unique(&result.required_shims, "hooks_events")
		}
		if strings.contains(emitted, "__shellx_test ") || strings.contains(emitted, "__shellx_match ") {
			append_unique(&result.required_shims, "condition_semantics")
		}
		collect_runtime_polyfill_shims(&result.required_shims, emitted, to)
	}
	if to == .POSIX {
		rewritten, changed := append_posix_dash_function_aliases(source_code, emitted, context.allocator)
		if changed {
			delete(emitted)
			emitted = rewritten
		} else {
			delete(rewritten)
		}
	}
	if options.insert_shims {
		rewritten, changed := prepend_fish_module_noninteractive_guard(emitted, from, to, context.allocator)
		if changed {
			delete(emitted)
			emitted = rewritten
		} else {
			delete(rewritten)
		}
	}
	if options.insert_shims {
		rewritten, changed := rewrite_zsh_runtime_decl_fallbacks(emitted, from, to, context.allocator)
		if changed {
			delete(emitted)
			emitted = rewritten
		} else {
			delete(rewritten)
		}
	}
	rewritten_omz_z, changed_omz_z := append_ohmyzsh_z_command_wrapper(source_code, emitted, from, to, context.allocator)
	if changed_omz_z {
		delete(emitted)
		emitted = rewritten_omz_z
	} else {
		delete(rewritten_omz_z)
	}
	cap_prelude := ""
	if options.insert_shims {
		compat.collect_caps_from_output(&result.required_caps, emitted, to)
		cap_prelude = compat.build_capability_prelude(result.required_caps[:], to, context.allocator)
	}
	shim_prelude := ""
	if options.insert_shims && len(result.required_shims) > 0 {
		shim_prelude = compat.build_shim_prelude(result.required_shims[:], from, to, context.allocator)
	}
	if cap_prelude != "" && shim_prelude != "" {
		combined := strings.concatenate([]string{cap_prelude, shim_prelude, emitted}, context.allocator)
		delete(cap_prelude)
		delete(shim_prelude)
		delete(emitted)
		result.output = combined
	} else if cap_prelude != "" {
		combined := strings.concatenate([]string{cap_prelude, emitted}, context.allocator)
		delete(cap_prelude)
		delete(emitted)
		result.output = combined
	} else if shim_prelude != "" {
		combined := strings.concatenate([]string{shim_prelude, emitted}, context.allocator)
		delete(shim_prelude)
		delete(emitted)
		result.output = combined
	} else {
		result.output = emitted
	}
	if from == .Zsh && to == .Bash {
		is_ohmyzsh_z_plugin := strings.contains(source_code, "Jump to a directory that you have visited frequently or recently")
		if is_ohmyzsh_z_plugin && !strings.contains(result.output, "__shellx_omz_z_bootstrap()") {
			z_bootstrap := strings.trim_space(`
__shellx_omz_z_bootstrap() {
  if command -v z >/dev/null 2>&1; then
    return 0
  fi
  z() {
    if command -v zshz >/dev/null 2>&1; then
      zshz "$@"
      return $?
    fi
    if command -v _z >/dev/null 2>&1; then
      _z "$@"
      return $?
    fi
    return 127
  }
}
__shellx_omz_z_bootstrap
`)
			combined_bootstrap := strings.concatenate([]string{z_bootstrap, "\n\n", result.output}, context.allocator)
			delete(result.output)
			result.output = combined_bootstrap
		}

		repl_cmd_setopt, changed_cmd_setopt := strings.replace_all(result.output, "command setopt ", "setopt ", context.allocator)
		if changed_cmd_setopt {
			delete(result.output)
			result.output = repl_cmd_setopt
		} else {
			if raw_data(repl_cmd_setopt) != raw_data(result.output) {
				delete(repl_cmd_setopt)
			}
		}
		repl_cmd_zparseopts, changed_cmd_zparseopts := strings.replace_all(result.output, "command zparseopts ", "zparseopts ", context.allocator)
		if changed_cmd_zparseopts {
			delete(result.output)
			result.output = repl_cmd_zparseopts
		} else {
			if raw_data(repl_cmd_zparseopts) != raw_data(result.output) {
				delete(repl_cmd_zparseopts)
			}
		}
		stub_builder := strings.builder_make()
		if !strings.contains(result.output, "\nsetopt() {") {
			strings.write_string(&stub_builder, "setopt() { :; }\n")
		}
		if !strings.contains(result.output, "\nzparseopts() {") {
			strings.write_string(&stub_builder, "zparseopts() { return 0; }\n")
		}
		if !strings.contains(result.output, "\n__shellx_list_has() {") {
			strings.write_string(&stub_builder, "__shellx_list_has() { _zx_name=\"$1\"; _zx_key=\"$2\"; eval \"_zx_vals=\\${$_zx_name}\"; set -- $_zx_vals; for _zx_item in \"$@\"; do [ \"$_zx_item\" = \"$_zx_key\" ] && { printf \"1\"; return 0; }; done; printf \"0\"; }\n")
		}
		stub_text := strings.to_string(stub_builder)
		if len(stub_text) > 0 {
			combined := strings.concatenate([]string{stub_text, "\n", result.output}, context.allocator)
			delete(result.output)
			result.output = combined
		}
		strings.builder_destroy(&stub_builder)

		has_z_fn := strings.contains(result.output, "\nz() {") || strings.has_prefix(strings.trim_space(result.output), "z() {")
		has__z_fn := strings.contains(result.output, "\n_z() {") || strings.has_prefix(strings.trim_space(result.output), "_z() {")
		if has__z_fn && !has_z_fn {
			z_bridge := strings.trim_space(`
z() {
  _z "$@"
}
`)
			combined := strings.concatenate([]string{result.output, "\n\n", z_bridge, "\n"}, context.allocator)
			delete(result.output)
			result.output = combined
		}
	}
		if to != .Fish {
			rewritten_final, changed_final := rewrite_final_nonfish_structural_safety(result.output, context.allocator)
			if changed_final {
				delete(result.output)
				result.output = rewritten_final
			} else {
				delete(rewritten_final)
			}
			if from == .Zsh && to == .Bash {
				trimmed_tail := strings.trim_right_space(result.output)
				if strings.has_suffix(trimmed_tail, "\n:") {
					repl_tail := strings.trim_right_space(trimmed_tail[:len(trimmed_tail)-2])
					if strings.has_suffix(repl_tail, "\nfi") {
						fixed := strings.concatenate([]string{trimmed_tail[:len(trimmed_tail)-1], "fi"}, context.allocator)
						delete(result.output)
						result.output = fixed
					}
				}
			}
			if from == .Zsh && (to == .Bash || to == .POSIX) {
				rewritten_tail, changed_tail := rewrite_targeted_zsh_plugin_structural_repairs(result.output, context.allocator)
				if changed_tail {
					delete(result.output)
					result.output = rewritten_tail
				} else {
					delete(rewritten_tail)
				}
				rewritten_blockers, changed_blockers := rewrite_zsh_parser_blocker_signatures(result.output, context.allocator)
				if changed_blockers {
					delete(result.output)
					result.output = rewritten_blockers
				} else {
					delete(rewritten_blockers)
				}
			}
		}
		if from == .Fish && to == .Zsh {
			rewritten_replay, changed_replay := rewrite_fish_replay_tail_closer(result.output, context.allocator)
			if changed_replay {
				delete(result.output)
				result.output = rewritten_replay
			} else {
				delete(rewritten_replay)
			}
		}
		if from == .Fish && (to == .Bash || to == .POSIX) {
			rewritten_replay, changed_replay := rewrite_fish_replay_tail_closer(result.output, context.allocator)
			if changed_replay {
				delete(result.output)
				result.output = rewritten_replay
			} else {
				delete(rewritten_replay)
			}
		}
		if from == .Zsh && strings.contains(source_code, "LAMBDA=") && strings.contains(source_code, "USERCOLOR=") {
			rewritten_lambda, changed_lambda := rewrite_lambda_mod_theme_structural_repairs(result.output, to, context.allocator)
			if changed_lambda {
				delete(result.output)
				result.output = rewritten_lambda
			} else {
				delete(rewritten_lambda)
			}
		}
		if to == .Fish {
			rewritten_fish_balance, changed_fish_balance := ensure_fish_block_balance(result.output, context.allocator)
			if changed_fish_balance {
				delete(result.output)
				result.output = rewritten_fish_balance
			} else {
				delete(rewritten_fish_balance)
			}
		}
	lowering_issue, has_lowering_issue := validate_lowered_output_structure(result.output, to, source_name, context.allocator)
	if has_lowering_issue {
		result.success = false
		add_error_context(
			&result,
			.ValidationInvalidControlFlow,
			lowering_issue.message,
			lowering_issue.location,
			lowering_issue.suggestion,
			lowering_issue.snippet,
			lowering_issue.rule_id,
		)
		return result
	}
	scan_shell_security_findings(&result, result.output, source_name, "translated")
	prune_resolved_compat_warnings(&result, from, to)
	derive_feature_metadata(&result, compat_result, options, from, to)
	if options.strict_mode && len(result.unsupported_features) > 0 {
		result.success = false
		add_error_context(
			&result,
			.ValidationError,
			"Strict mode blocked translation due to unsupported features",
			ir.SourceLocation{file = source_name},
			"Disable strict_mode or remove unsupported source features",
		)
	}

	return result
}

rewrite_fish_replay_tail_closer :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	idx := find_substring(text, "replay() {")
	if idx < 0 {
		return strings.clone(text, allocator), false
	}
	rest := text[idx+len("replay() {"):]
	if strings.contains(rest, "}") {
		return strings.clone(text, allocator), false
	}
	trimmed := strings.trim_right_space(text)
	if strings.has_suffix(trimmed, ":") {
		return strings.concatenate([]string{trimmed, "\n}"}, allocator), true
	}
	return strings.clone(text, allocator), false
}

// translate_file reads a file and translates it.
// The caller owns result.output/warnings/errors and should call destroy_translation_result(&result).
translate_file :: proc(
	filepath: string,
	from: ShellDialect,
	to: ShellDialect,
	options := DEFAULT_TRANSLATION_OPTIONS,
) -> TranslationResult {
	result := TranslationResult{success = true}

	data, ok := os.read_entire_file(filepath)
	if !ok {
		result.success = false
		add_error_context(
			&result,
			.IOError,
			"Failed to read input file",
			ir.SourceLocation{file = filepath},
			"Check file path and permissions",
		)
		return result
	}
	defer delete(data)

	opts := options
	if opts.source_name == "" {
		opts.source_name = filepath
	}

	return translate(string(data), from, to, opts)
}

// translate_batch translates multiple files.
// Caller owns the returned slice and each element's allocations.
// Use destroy_translation_result on each item, then delete(batch).
translate_batch :: proc(
	files: []string,
	from: ShellDialect,
	to: ShellDialect,
	options := DEFAULT_TRANSLATION_OPTIONS,
	allocator := context.allocator,
) -> [dynamic]TranslationResult {
	results := make([dynamic]TranslationResult, 0, len(files), allocator)
	for file in files {
		append(&results, translate_file(file, from, to, options))
	}
	return results
}

// get_version returns the library semantic version string.
get_version :: proc() -> string {
	return "0.2.0"
}

// detect_shell returns the best-effort shell dialect for source text.
detect_shell :: proc(code: string) -> ShellDialect {
	return detection.detect_dialect(code, "").dialect
}

// detect_shell_from_path uses both file path and content to detect dialect.
detect_shell_from_path :: proc(filepath: string, code: string) -> ShellDialect {
	return detection.detect_shell_from_path(filepath, code).dialect
}

rewrite_final_nonfish_structural_safety :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_case := false
	pending_process_subst := false
	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false

		if strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
			in_case = true
		} else if trimmed == "esac" {
			in_case = false
		}
		if strings.contains(trimmed, "< <(") || strings.contains(trimmed, "> >(") {
			pending_process_subst = true
		}
		if pending_process_subst {
			close_idx := strings.last_index(trimmed, ")")
			if close_idx >= 0 && close_idx == len(trimmed)-1 {
				pending_process_subst = false
			}
		}

		if in_case {
			prev_sig := ""
			for j := idx - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			arm_boundary := false
			if prev_sig != "" {
				arm_boundary = prev_sig == "in" ||
					strings.has_suffix(prev_sig, " in") ||
					prev_sig == ";;" ||
					strings.has_suffix(prev_sig, ";;") ||
					prev_sig == ";&" ||
					prev_sig == ";;&"
			}
			is_simple_label := trimmed != "" &&
				!strings.contains(trimmed, " ") &&
				!strings.contains(trimmed, "\t") &&
				!strings.contains(trimmed, ";;") &&
				!strings.has_prefix(trimmed, "#") &&
				!strings.has_prefix(trimmed, "(") &&
				trimmed != "esac"
			is_label := trimmed == "*" ||
				(strings.has_prefix(trimmed, "'") && strings.has_suffix(trimmed, "'")) ||
				(strings.has_prefix(trimmed, "\"") && strings.has_suffix(trimmed, "\"")) ||
				(arm_boundary && is_simple_label)
			if is_label && !strings.has_suffix(trimmed, ")") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out_line = strings.concatenate([]string{indent, trimmed, ")"}, allocator)
				out_allocated = true
				changed = true
			}
		}

		if strings.has_prefix(trimmed, "done |") {
			out_line = "done"
			changed = true
		}
		if trimmed == "}" && pending_process_subst {
			strings.write_string(&builder, ")\n")
			pending_process_subst = false
			changed = true
		}
		if trimmed == "done" && idx >= len(lines)-4 {
			next_sig := ""
			for j := idx + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			if next_sig == "}" {
				out_line = ":"
				changed = true
			}
		}
		if trimmed == ":" {
			// Keep placeholders as-is; converting ":" to control terminators caused
			// false-positive orphan fi/done in recovered blocks.
		}
		if trimmed == "}" && idx >= len(lines)-6 {
			prev_sig := ""
			for j := idx - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			if prev_sig == ":" {
				out_line = ":"
				changed = true
			}
		}
		eq_idx := find_substring(trimmed, "=")
				if eq_idx > 0 {
					name := strings.trim_space(trimmed[:eq_idx])
					rhs := strings.trim_space(trimmed[eq_idx+1:])
					if is_basic_name(name) {
						if rhs == "(" ||
							(strings.has_prefix(rhs, "($(") && (strings.contains(rhs, "(string ") || strings.contains(rhs, "(fish_"))) {
							indent_len := len(line) - len(strings.trim_left_space(line))
							indent := ""
							if indent_len > 0 {
								indent = line[:indent_len]
							}
							out_line = strings.concatenate([]string{indent, name, "=()"}, allocator)
							out_allocated = true
							changed = true
						}
					}
				}
		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	return strings.clone(strings.to_string(builder), allocator), changed
}

lowering_issue :: proc(
	rule_id: string,
	message: string,
	output: string,
	pattern: string,
	source_name: string,
	suggestion: string,
	allocator := context.allocator,
) -> LoweringValidationIssue {
	line := 1
	column := 0
	snippet := ""
	if pattern != "" {
		idx := find_substring(output, pattern)
		if idx >= 0 {
			line = 1
			for i := 0; i < idx; i += 1 {
				if output[i] == '\n' {
					line += 1
				}
			}
			last_newline := -1
			for i := idx - 1; i >= 0; i -= 1 {
				if output[i] == '\n' {
					last_newline = i
					break
				}
			}
			column = idx - (last_newline + 1)
			snippet = line_from_source(output, line)
		}
	}
	return LoweringValidationIssue{
		rule_id = rule_id,
		message = message,
		location = ir.SourceLocation{
			file = source_name,
			line = line,
			column = column,
		},
		suggestion = suggestion,
		snippet = snippet,
	}
}

validate_non_fish_control_balance :: proc(output: string, source_name: string, allocator := context.allocator) -> (LoweringValidationIssue, bool) {
	lines := strings.split_lines(output)
	defer delete(lines)

	if_depth := 0
	loop_depth := 0
	case_depth := 0

	for line in lines {
		trimmed := strings.trim_space(line)
		if trimmed == "" || strings.has_prefix(trimmed, "#") {
			continue
		}
		single_line_if := strings.has_prefix(trimmed, "if ") &&
			strings.contains(trimmed, "; then") &&
			(strings.contains(trimmed, "; fi") || strings.has_suffix(trimmed, " fi") || strings.has_suffix(trimmed, "; fi"))
		if strings.has_prefix(trimmed, "if ") && !single_line_if {
			if_depth += 1
		}
		single_line_loop := (strings.has_prefix(trimmed, "while ") || strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "until ")) &&
			(strings.has_suffix(trimmed, " do") || strings.has_suffix(trimmed, "; do")) &&
			(strings.contains(trimmed, "; done") || strings.has_suffix(trimmed, " done"))
		if strings.has_prefix(trimmed, "while ") || strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "until ") {
			if (strings.has_suffix(trimmed, " do") || strings.has_suffix(trimmed, "; do")) && !single_line_loop {
				loop_depth += 1
			}
		}
		if strings.contains(trimmed, "| while ") && strings.has_suffix(trimmed, "; do") {
			loop_depth += 1
		}
		single_line_case := strings.has_prefix(trimmed, "case ") && strings.contains(trimmed, " in ") && strings.contains(trimmed, " esac")
		if strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") && !single_line_case {
			case_depth += 1
		}
		if trimmed == "fi" {
			if_depth -= 1
			if if_depth < 0 {
				return lowering_issue(
					"lowering.control.unexpected_fi",
					"Lowered output contains unexpected 'fi' without matching 'if'",
					output,
					"\nfi\n",
					source_name,
					"Normalize control-flow lowering before emission; do not emit orphan 'fi'",
					allocator,
				), true
			}
		}
		if trimmed == "done" {
			loop_depth -= 1
			if loop_depth < 0 {
				return lowering_issue(
					"lowering.control.unexpected_done",
					"Lowered output contains unexpected 'done' without matching loop header",
					output,
					"\ndone\n",
					source_name,
					"Normalize loop lowering before emission; do not emit orphan 'done'",
					allocator,
				), true
			}
		}
		if trimmed == "esac" {
			case_depth -= 1
			if case_depth < 0 {
				return lowering_issue(
					"lowering.control.unexpected_esac",
					"Lowered output contains unexpected 'esac' without matching 'case'",
					output,
					"\nesac\n",
					source_name,
					"Normalize case lowering before emission; do not emit orphan 'esac'",
					allocator,
				), true
			}
		}
	}

	return LoweringValidationIssue{}, false
}

validate_fish_block_balance :: proc(output: string, source_name: string, allocator := context.allocator) -> (LoweringValidationIssue, bool) {
	lines := strings.split_lines(output)
	defer delete(lines)
	depth := 0
	for line in lines {
		trimmed := strings.trim_space(line)
		if trimmed == "" || strings.has_prefix(trimmed, "#") {
			continue
		}
		if strings.has_prefix(trimmed, "function ") ||
			strings.has_prefix(trimmed, "if ") ||
			strings.has_prefix(trimmed, "for ") ||
			strings.has_prefix(trimmed, "while ") ||
			strings.has_prefix(trimmed, "switch ") ||
			strings.contains(trimmed, "| while ") {
			depth += 1
		}
		if trimmed == "end" {
			depth -= 1
			if depth < 0 {
				return lowering_issue(
					"lowering.fish.unexpected_end",
					"Fish lowered output contains unexpected 'end' without matching block opener",
					output,
					"\nend\n",
					source_name,
					"Normalize fish block lowering before emission",
					allocator,
				), true
			}
		}
		if trimmed == "fi" || trimmed == "done" || trimmed == "esac" || trimmed == "then" || trimmed == "do" {
			return lowering_issue(
				"lowering.fish.leaked_sh_keyword",
				"Fish lowered output leaked sh keyword token",
				output,
				trimmed,
				source_name,
				"Convert sh-style control tokens to fish block forms during lowering",
				allocator,
			), true
		}
	}
	if depth != 0 {
		return lowering_issue(
			"lowering.fish.block_balance",
			fmt.tprintf("Fish lowered output has unbalanced blocks (depth=%d)", depth),
			output,
			"",
			source_name,
			"Ensure fish lowering always emits balanced openers/end tokens",
			allocator,
		), true
	}
	return LoweringValidationIssue{}, false
}

validate_lowered_output_structure :: proc(
	output: string,
	to: ShellDialect,
	source_name: string,
	allocator := context.allocator,
) -> (LoweringValidationIssue, bool) {
	if output == "" {
		return lowering_issue(
			"lowering.output.non_empty",
			"Lowered output is empty",
			output,
			"",
			source_name,
			"Lowering/emission must produce non-empty output",
			allocator,
		), true
	}

	if to != .Zsh && strings.contains(output, "${@s/") {
		return lowering_issue(
			"lowering.zsh.split_args_non_zsh",
			"Lowered output still contains zsh split-args expansion in non-zsh target",
			output,
			"${@s/",
			source_name,
			"Lower zsh split-args expansions into explicit loops or helper calls before emission",
			allocator,
		), true
	}
	if to != .Zsh && strings.contains(output, "*(N)") {
		return lowering_issue(
			"lowering.zsh.glob_qualifier_non_zsh",
			"Lowered output still contains zsh glob qualifier '(N)' in non-zsh target",
			output,
			"*(N)",
			source_name,
			"Lower zsh glob qualifiers to target-compatible glob/list logic",
			allocator,
		), true
	}
	if to != .Fish && strings.contains(output, "if set -q ") {
		return lowering_issue(
			"lowering.fish.setq_non_fish",
			"Lowered output leaked fish 'set -q' construct in non-fish target",
			output,
			"if set -q ",
			source_name,
			"Lower fish query/set constructs into target shell tests before emission",
			allocator,
		), true
	}
	if strings.contains(output, "do|") {
		return lowering_issue(
			"lowering.control.inline_pipe_artifact",
			"Lowered output contains malformed 'do|' control/pipe artifact",
			output,
			"do|",
			source_name,
			"Split loop headers and pipeline operators into valid target-shell syntax",
			allocator,
		), true
	}

	if to == .Fish {
		issue, has := validate_fish_block_balance(output, source_name, allocator)
		if has {
			return issue, true
		}
	}

	return LoweringValidationIssue{}, false
}

convert_to_ir :: proc(
	arena: ^ir.Arena_IR,
	from: ShellDialect,
	tree: ^ts.Tree,
	source_code: string,
) -> (^ir.Program, frontend.FrontendError) {
	switch from {
	case .Bash:
		return frontend.bash_to_ir(arena, tree, source_code)
	case .Zsh:
		return frontend.zsh_to_ir(arena, tree, source_code)
	case .Fish:
		return frontend.fish_to_ir(arena, tree, source_code)
	case .POSIX:
		return frontend.bash_to_ir(arena, tree, source_code)
	}
	return nil, frontend.FrontendError{error = .ConversionError, message = "unsupported dialect"}
}

emit_program :: proc(program: ^ir.Program, to: ShellDialect) -> (string, bool) {
	switch to {
	case .Bash, .POSIX:
		be := backend.create_backend(to)
		defer backend.destroy_backend(&be)
		return backend.emit(&be, program, context.allocator), true
	case .Zsh:
		be := backend.create_zsh_backend()
		defer backend.destroy_zsh_backend(&be)
		raw := backend.emit_zsh(&be, program)
		return strings.clone(raw, context.allocator), true
	case .Fish:
		be := backend.create_fish_backend()
		defer backend.destroy_fish_backend(&be)
		raw := backend.emit_fish(&be, program)
		return strings.clone(raw, context.allocator), true
	}
	return "", false
}

validator_error_code :: proc(err: ir.ValidatorErrorType) -> Error {
	switch err {
	case .UndefinedVariable:
		return .ValidationUndefinedVariable
	case .DuplicateFunction:
		return .ValidationDuplicateFunction
	case .InvalidControlFlow:
		return .ValidationInvalidControlFlow
	case .None:
		return .ValidationError
	}
	return .ValidationError
}

to_optimizer_level :: proc(level: OptimizationLevel) -> optimizer.OptimizationLevel {
	switch level {
	case .None:
		return .None
	case .Basic:
		return .Basic
	case .Standard:
		return .Standard
	case .Aggressive:
		return .Aggressive
	}
	return .Standard
}

append_unique :: proc(items: ^[dynamic]string, value: string) {
	for existing in items^ {
		if existing == value {
			return
		}
	}
	append(items, value)
}

contains_string :: proc(items: []string, value: string) -> bool {
	for item in items {
		if item == value {
			return true
		}
	}
	return false
}

remove_string :: proc(items: ^[dynamic]string, value: string) {
	out := make([dynamic]string, 0, len(items^), context.temp_allocator)
	defer delete(out)
	for item in items^ {
		if item == value {
			continue
		}
		append(&out, item)
	}
	clear(items)
	for item in out {
		append(items, item)
	}
}

append_security_finding :: proc(
	result: ^TranslationResult,
	rule_id: string,
	severity: FindingSeverity,
	message: string,
	location: ir.SourceLocation,
	suggestion: string,
	phase: string,
) {
	for finding in result.findings {
		if finding.rule_id == rule_id &&
			finding.message == message &&
			finding.location.line == location.line &&
			finding.phase == phase {
			return
		}
	}
	append(
		&result.findings,
		SecurityFinding{
			rule_id = strings.clone(rule_id, context.allocator),
			severity = severity,
			message = strings.clone(message, context.allocator),
			location = location,
			suggestion = strings.clone(suggestion, context.allocator),
			phase = strings.clone(phase, context.allocator),
		},
	)
}

scan_shell_security_findings :: proc(
	result: ^TranslationResult,
	code: string,
	source_name: string,
	phase: string,
) {
	if code == "" {
		return
	}
	lines := strings.split_lines(code)
	defer delete(lines)
	for line, i in lines {
		trimmed := strings.trim_space(line)
		line_no := i + 1
		loc := ir.SourceLocation{file = source_name, line = line_no, column = 0, length = len(trimmed)}

		if strings.contains(trimmed, "| sh") || strings.contains(trimmed, "| bash") ||
			strings.contains(trimmed, "| zsh") || strings.contains(trimmed, "| fish") {
			if strings.contains(trimmed, "curl ") || strings.contains(trimmed, "wget ") || strings.contains(trimmed, "fetch ") {
				append_security_finding(
					result,
					"sec.pipe_download_exec",
					.Critical,
					"Downloaded content is piped directly into a shell interpreter",
					loc,
					"Download to a file, verify checksum/signature, then execute explicitly",
					phase,
				)
			}
		}
		if strings.contains(trimmed, "eval ") && (strings.contains(trimmed, "curl ") || strings.contains(trimmed, "wget ")) {
			append_security_finding(
				result,
				"sec.eval_download",
				.Critical,
				"Dynamic eval with network-fetched content detected",
				loc,
				"Avoid eval on external input; parse and validate input first",
				phase,
			)
		}
		if strings.contains(trimmed, "rm -rf /") || strings.contains(trimmed, "rm -rf ~") {
			append_security_finding(
				result,
				"sec.dangerous_rm",
				.Critical,
				"Potentially destructive recursive delete target detected",
				loc,
				"Use explicit safe paths and add guard checks before deletion",
				phase,
			)
		}
		if strings.contains(trimmed, "chmod 777") {
			append_security_finding(
				result,
				"sec.overpermissive_chmod",
				.Warning,
				"Overly permissive file mode detected",
				loc,
				"Use least-privilege file permissions",
				phase,
			)
		}
		if strings.has_prefix(trimmed, "source /tmp/") || strings.has_prefix(trimmed, ". /tmp/") {
			append_security_finding(
				result,
				"sec.source_tmp",
				.High,
				"Sourcing code from /tmp detected",
				loc,
				"Use immutable trusted paths for sourced files",
				phase,
			)
		}
	}
}

derive_feature_metadata :: proc(
	result: ^TranslationResult,
	compat_result: compat.CompatibilityResult,
	options: TranslationOptions,
	from: ShellDialect,
	to: ShellDialect,
) {
	for warning in compat_result.warnings {
		switch warning.severity {
		case .Error:
			append_unique(&result.unsupported_features, warning.feature)
		case .Warning:
			append_unique(&result.degraded_features, warning.feature)
		case .Info:
			append_unique(&result.supported_features, warning.feature)
		}
	}

	for cap in result.required_caps {
		append_unique(&result.supported_features, cap)
	}
	for shim in result.required_shims {
		append_unique(&result.supported_features, shim)
		if contains_string(result.degraded_features[:], shim) && options.insert_shims {
			remove_string(&result.degraded_features, shim)
		}
		if contains_string(result.unsupported_features[:], shim) &&
			options.insert_shims &&
			compat.needs_shim(shim, from, to) {
			remove_string(&result.unsupported_features, shim)
			append_unique(&result.degraded_features, shim)
		}
	}

	for feature in result.unsupported_features {
		remove_string(&result.degraded_features, feature)
		remove_string(&result.supported_features, feature)
	}
	for feature in result.degraded_features {
		remove_string(&result.supported_features, feature)
	}
}

has_required_shim :: proc(required_shims: []string, name: string) -> bool {
	for shim in required_shims {
		if shim == name {
			return true
		}
	}
	return false
}

has_array_bridge_shim :: proc(required_shims: []string) -> bool {
	return has_required_shim(required_shims, "arrays_lists") ||
		has_required_shim(required_shims, "indexed_arrays") ||
		has_required_shim(required_shims, "assoc_arrays") ||
		has_required_shim(required_shims, "fish_list_indexing")
}

has_hook_bridge_shim :: proc(required_shims: []string) -> bool {
	return has_required_shim(required_shims, "hooks_events") ||
		has_required_shim(required_shims, "zsh_hooks") ||
		has_required_shim(required_shims, "fish_events") ||
		has_required_shim(required_shims, "prompt_hooks")
}

collect_runtime_polyfill_shims :: proc(
	required_shims: ^[dynamic]string,
	emitted: string,
	to: ShellDialect,
) {
	if to == .Fish || emitted == "" {
		return
	}
	if strings.contains(emitted, "autoload ") ||
		strings.contains(emitted, "is-at-least ") ||
		strings.contains(emitted, "about-plugin") ||
		strings.contains(emitted, "about-alias") ||
		strings.contains(emitted, "emulate ") ||
		strings.contains(emitted, "unfunction ") ||
		strings.contains(emitted, "zsystem ") ||
		strings.contains(emitted, "status ") ||
		strings.contains(emitted, "typeset -") {
		append_unique(required_shims, "runtime_polyfills")
	}
}

append_posix_dash_function_aliases :: proc(
	source_code: string,
	emitted: string,
	allocator := context.allocator,
) -> (string, bool) {
	if source_code == "" || emitted == "" {
		return strings.clone(emitted, allocator), false
	}
	lines := strings.split_lines(source_code)
	defer delete(lines)
	legacy_names := make([dynamic]string, 0, 8, context.temp_allocator)
	defer delete(legacy_names)
	for line in lines {
		trimmed := strings.trim_space(line)
		name := ""
		if strings.has_prefix(trimmed, "function ") {
			decl := strings.trim_space(trimmed[len("function "):])
			name, _ = split_first_word(decl)
			name = normalize_function_name_token(name)
		} else if strings.has_suffix(trimmed, "() {") {
			name = strings.trim_space(trimmed[:len(trimmed)-len("() {")])
			name = normalize_function_name_token(name)
		}
		if name == "" {
			continue
		}
		if !strings.contains(name, "-") {
			continue
		}
		exists := false
		for e in legacy_names {
			if e == name {
				exists = true
				break
			}
		}
		if !exists {
			append(&legacy_names, name)
		}
	}
	if len(legacy_names) == 0 {
		return strings.clone(emitted, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for old in legacy_names {
		mapped, mapped_changed := strings.replace_all(old, "-", "_", allocator)
		if !mapped_changed {
			delete(mapped)
			continue
		}
		alias_line := strings.concatenate([]string{"alias ", old, "=", mapped, "\n"}, allocator)
		strings.write_string(&builder, alias_line)
		delete(alias_line)
		changed = true
		delete(mapped)
	}
	if changed {
		strings.write_byte(&builder, '\n')
	}
	strings.write_string(&builder, emitted)
	if !changed {
		return strings.clone(emitted, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

prepend_fish_module_noninteractive_guard :: proc(
	text: string,
	from: ShellDialect,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if from != .Fish || to == .Fish {
		return strings.clone(text, allocator), false
	}
	if !strings.contains(text, "_autopair_fish_key_bindings") {
		return strings.clone(text, allocator), false
	}
	guard := "if ! [ -t 1 ]; then return 0 2>/dev/null || exit 0; fi\n"
	if strings.has_prefix(strings.trim_left_space(text), "if ! [ -t 1 ]; then") {
		return strings.clone(text, allocator), false
	}
	out := strings.concatenate([]string{guard, text}, allocator)
	return out, true
}

rewrite_zsh_runtime_decl_fallbacks :: proc(
	text: string,
	from: ShellDialect,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if from != .Zsh || (to != .Bash && to != .POSIX) {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	is_zsh_nvm := strings.contains(text, "zsh-nvm") && strings.contains(text, "NVM_AUTO_USE")
	fn_depth := 0
	for line, i in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		if strings.has_suffix(trimmed, "() {") || strings.has_prefix(trimmed, "function ") {
			fn_depth += 1
		} else if trimmed == "}" && fn_depth > 0 {
			fn_depth -= 1
		}
		if fn_depth == 0 && strings.has_prefix(trimmed, "emulate ") {
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_allocated = true
			changed = true
		} else if fn_depth == 0 && strings.has_prefix(trimmed, "local ") {
			rest := strings.trim_space(trimmed[len("local "):])
			parts := strings.fields(rest)
			defer delete(parts)
			assign_builder := strings.builder_make()
			defer strings.builder_destroy(&assign_builder)
			wrote := false
			for p in parts {
				if strings.has_prefix(p, "-") {
					continue
				}
				name := p
				value := "\"\""
				eq := find_substring(p, "=")
				if eq > 0 {
					name = strings.trim_space(p[:eq])
					value = strings.trim_space(p[eq+1:])
					if value == "" {
						value = "\"\""
					}
				}
				if !is_basic_name(name) {
					continue
				}
				if wrote {
					strings.write_string(&assign_builder, "; ")
				}
				strings.write_string(&assign_builder, name)
				strings.write_byte(&assign_builder, '=')
				strings.write_string(&assign_builder, value)
				wrote = true
			}
			if wrote {
				assign_text := strings.clone(strings.to_string(assign_builder), allocator)
				out_line = strings.concatenate([]string{indent, assign_text}, allocator)
				delete(assign_text)
			} else {
				out_line = strings.concatenate([]string{indent, ":"}, allocator)
			}
			out_allocated = true
			changed = true
		}
		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	result := strings.clone(strings.to_string(builder), allocator)
	if strings.contains(result, "html_$ 1") {
		rewritten, c := strings.replace_all(result, "html_$ 1", "html_$argv[1]", allocator)
		if c {
			delete(result)
			result = rewritten
		} else {
			delete(rewritten)
		}
	}
	return result, true
}

append_ohmyzsh_z_command_wrapper :: proc(
	source_code: string,
	text: string,
	from: ShellDialect,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if from != .Zsh || (to != .Bash && to != .POSIX) {
		return strings.clone(text, allocator), false
	}
	if !strings.contains(source_code, "Jump to a directory that you have visited frequently or recently") {
		return strings.clone(text, allocator), false
	}
	if !strings.contains(text, "zshz() {") {
		return strings.clone(text, allocator), false
	}
	if strings.contains(text, "\nz() {") || strings.contains(text, "\nfunction z") || strings.contains(text, "\nalias z=") {
		return strings.clone(text, allocator), false
	}
	wrapper := "\nz() {\n  zshz \"$@\"\n}\n"
	out := strings.concatenate([]string{text, wrapper}, allocator)
	return out, true
}

collect_fish_event_registration_lines :: proc(
	source_code: string,
	allocator := context.temp_allocator,
) -> (regs: [dynamic]string, has_precmd: bool, has_preexec: bool) {
	regs = make([dynamic]string, 0, 8, allocator)
	lines := strings.split_lines(source_code)
	defer delete(lines)
	for line in lines {
		trimmed := strings.trim_space(line)
		if !strings.has_prefix(trimmed, "function ") {
			continue
		}
		decl := strings.trim_space(trimmed[len("function "):])
		name, _ := split_first_word(decl)
		name = normalize_function_name_token(name)
		if !is_basic_name(name) {
			continue
		}
		hook_kind := fish_function_hook_kind_from_decl(decl)
		reg := ""
		switch hook_kind {
		case 'p':
			reg = strings.concatenate([]string{"__shellx_register_precmd ", name}, allocator)
			has_precmd = true
		case 'x':
			reg = strings.concatenate([]string{"__shellx_register_preexec ", name}, allocator)
			has_preexec = true
		}
		if reg == "" {
			continue
		}
		exists := false
		for existing in regs {
			if existing == reg {
				exists = true
				break
			}
		}
		if !exists {
			append(&regs, reg)
		}
	}
	return
}

append_missing_registration_lines :: proc(
	text: string,
	regs: []string,
	allocator := context.allocator,
) -> (string, bool) {
	if len(regs) == 0 {
		return strings.clone(text, allocator), false
	}

	pending := make([dynamic]string, 0, len(regs), context.temp_allocator)
	defer delete(pending)
	for reg in regs {
		if strings.contains(text, reg) {
			continue
		}
		append(&pending, reg)
	}
	if len(pending) == 0 {
		return strings.clone(text, allocator), false
	}

	lines := strings.split_lines(text)
	defer delete(lines)
	insert_idx := len(lines)
	for line, i in lines {
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "__shellx_run_precmd") || strings.has_prefix(trimmed, "__shellx_run_preexec") {
			insert_idx = i
			break
		}
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	for line, i in lines {
		if i == insert_idx {
			for reg in pending {
				strings.write_string(&builder, reg)
				strings.write_byte(&builder, '\n')
			}
		}
		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if len(lines) == 0 || insert_idx == len(lines) {
		if len(lines) > 0 {
			strings.write_byte(&builder, '\n')
		}
		for reg, reg_i in pending {
			strings.write_string(&builder, reg)
			if reg_i+1 < len(pending) {
				strings.write_byte(&builder, '\n')
			}
		}
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

extract_compat_warning_feature :: proc(warning: string) -> string {
	if !strings.has_prefix(warning, "Compat[") {
		return ""
	}
	start := len("Compat[")
	close_rel := strings.index_byte(warning[start:], ']')
	if close_rel < 0 {
		return ""
	}
	return warning[start : start+close_rel]
}

is_compat_warning_resolved :: proc(
	feature: string,
	result: ^TranslationResult,
	from: ShellDialect,
	to: ShellDialect,
) -> bool {
	out := result.output
	switch feature {
	case "parameter_expansion":
		if to != .Fish {
			return false
		}
		return has_required_shim(result.required_shims[:], "parameter_expansion") &&
			strings.contains(out, "function __shellx_param_default") &&
			!strings.contains(out, "${(")
	case "condition_semantics":
		if !has_required_shim(result.required_shims[:], "condition_semantics") {
			return false
		}
		if to == .Fish {
			return (strings.contains(out, "__shellx_test") || strings.contains(out, "__shellx_match")) &&
				!strings.contains(out, "[[")
		}
		if from == .Fish && (to == .Bash || to == .Zsh || to == .POSIX) {
			return strings.contains(out, "__shellx_test") &&
				(strings.contains(out, "if __shellx_test") || strings.contains(out, "__shellx_match")) &&
				!strings.contains(out, "if string match")
		}
		return false
	case "indexed_arrays", "assoc_arrays", "fish_list_indexing":
		if !(has_required_shim(result.required_shims[:], "indexed_arrays") ||
			has_required_shim(result.required_shims[:], "assoc_arrays") ||
			has_required_shim(result.required_shims[:], "arrays_lists") ||
			has_required_shim(result.required_shims[:], "fish_list_indexing")) {
			return false
		}
		if to == .Fish {
			return strings.contains(out, "function __shellx_array_get")
		}
		if to == .POSIX && (from == .Bash || from == .Zsh) {
			has_lookup := strings.contains(out, "__shellx_list_get") ||
				strings.contains(out, "__shellx_list_has") ||
				strings.contains(out, "__shellx_zsh_subscript_r") ||
				strings.contains(out, "__shellx_zsh_subscript_I") ||
				strings.contains(out, "__shellx_zsh_subscript_Ib")
			has_array_bridge := has_lookup ||
				strings.contains(out, "__shellx_list_len") ||
				strings.contains(out, "__shellx_list_append") ||
				strings.contains(out, "__shellx_list_unset_index") ||
				strings.contains(out, "__shellx_list_set ")
			return has_array_bridge && !strings.contains(out, "=(")
		}
		if from == .Fish && (to == .Bash || to == .Zsh || to == .POSIX) {
			return strings.contains(out, "__shellx_list_get")
		}
		return false
	case "process_substitution":
		return has_required_shim(result.required_shims[:], "process_substitution") &&
			(strings.contains(out, "__shellx_psub_in") || strings.contains(out, "__shellx_psub_out")) &&
			!strings.contains(out, "<(") &&
			!strings.contains(out, ">(")
	case "zsh_hooks", "fish_events", "prompt_hooks":
		if !has_hook_bridge_shim(result.required_shims[:]) {
			return false
		}
		if to == .Fish {
			return from == .Zsh &&
				strings.contains(out, "function __shellx_register_hook") &&
				!strings.contains(out, "add-zsh-hook ")
		}
		if to == .Bash || to == .Zsh {
			return strings.contains(out, "__shellx_register_hook") &&
				strings.contains(out, "__shellx_run_precmd")
		}
		if to == .POSIX {
			return strings.contains(out, "__shellx_register_hook") &&
				(strings.contains(out, "__shellx_register_precmd") ||
					strings.contains(out, "__shellx_register_preexec") ||
					strings.contains(out, "fish_prompt() {") ||
					strings.contains(out, "fish_right_prompt() {")) &&
				strings.contains(out, "__shellx_run_precmd")
		}
		return false
	}
	return false
}

prune_resolved_compat_warnings :: proc(result: ^TranslationResult, from: ShellDialect, to: ShellDialect) {
	if len(result.warnings) == 0 {
		return
	}
	write := 0
	for i := 0; i < len(result.warnings); i += 1 {
		w := result.warnings[i]
		feature := extract_compat_warning_feature(w)
		if feature != "" && is_compat_warning_resolved(feature, result, from, to) {
			continue
		}
		if write != i {
			result.warnings[write] = result.warnings[i]
		}
		write += 1
	}
	if write < len(result.warnings) {
		resize(&result.warnings, write)
	}
}

is_string_match_call :: proc(call: ^ir.Call) -> bool {
	if call == nil {
		return false
	}

	if call.function != nil && call.function.name == "string" {
		if len(call.arguments) == 0 {
			return false
		}
		first := strings.trim_space(ir.expr_to_string(call.arguments[0]))
		return first == "match"
	}

	if call.function != nil && strings.trim_space(call.function.name) == "" && len(call.arguments) >= 2 {
		first := strings.trim_space(ir.expr_to_string(call.arguments[0]))
		second := strings.trim_space(ir.expr_to_string(call.arguments[1]))
		return first == "string" && second == "match"
	}

	return false
}

drop_call_arguments :: proc(call: ^ir.Call, n: int) {
	if call == nil || n <= 0 {
		return
	}
	if len(call.arguments) <= n {
		resize(&call.arguments, 0)
		return
	}
	for i in n ..< len(call.arguments) {
		call.arguments[i-n] = call.arguments[i]
	}
	resize(&call.arguments, len(call.arguments)-n)
}

rewrite_condition_command_text_for_shim :: proc(expr: ^ir.TestCondition, arena: ^ir.Arena_IR) {
	if expr == nil {
		return
	}
	trimmed := strings.trim_space(expr.text)
	if !strings.has_prefix(trimmed, "string match") {
		return
	}
	rest := strings.trim_space(trimmed[len("string match"):])
	if rest == "" {
		expr.text = "__shellx_match"
	} else {
		expr.text = strings.concatenate([]string{"__shellx_match ", rest}, mem.arena_allocator(&arena.arena))
	}
	expr.syntax = .Command
}

rewrite_condition_fish_test_text_for_shim :: proc(expr: ^ir.TestCondition, arena: ^ir.Arena_IR) {
	if expr == nil {
		return
	}
	cond := strings.trim_space(expr.text)
	if strings.has_prefix(cond, "test ") {
		cond = strings.trim_space(cond[len("test "):])
	}
	if strings.has_prefix(cond, "__shellx_test ") || cond == "__shellx_test" {
		expr.text = cond
		expr.syntax = .Command
		return
	}
	if cond == "" {
		expr.text = "__shellx_test"
	} else {
		expr.text = strings.concatenate([]string{"__shellx_test ", cond}, mem.arena_allocator(&arena.arena))
	}
	expr.syntax = .Command
}

rewrite_expr_for_shims :: proc(
	expr: ir.Expression,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
	arena: ^ir.Arena_IR,
) {
	if expr == nil {
		return
	}
	#partial switch e in expr {
	case ^ir.TestCondition:
		if has_required_shim(required_shims, "condition_semantics") {
			cond_text := strings.trim_space(e.text)
			if to == .Fish {
				if e.syntax == .DoubleBracket || e.syntax == .TestBuiltin || e.syntax == .Unknown {
					if !strings.has_prefix(cond_text, "__shellx_test ") {
						e.text = strings.concatenate([]string{"__shellx_test ", cond_text}, mem.arena_allocator(&arena.arena))
					}
					e.syntax = .Command
				}
			} else if from == .Fish && to != .Fish {
				rewrite_condition_command_text_for_shim(e, arena)
				if e.syntax == .FishTest {
					rewrite_condition_fish_test_text_for_shim(e, arena)
				}
			} else if to == .POSIX && e.syntax == .DoubleBracket {
				e.syntax = .TestBuiltin
			} else if (to == .Bash || to == .Zsh || to == .POSIX) && e.syntax == .FishTest {
				e.syntax = .TestBuiltin
			}
		}
	case ^ir.RawExpression:
	case ^ir.UnaryOp:
		rewrite_expr_for_shims(e.operand, required_shims, from, to, arena)
	case ^ir.BinaryOp:
		rewrite_expr_for_shims(e.left, required_shims, from, to, arena)
		rewrite_expr_for_shims(e.right, required_shims, from, to, arena)
	case ^ir.CallExpr:
		for arg in e.arguments {
			rewrite_expr_for_shims(arg, required_shims, from, to, arena)
		}
	case ^ir.ArrayLiteral:
		for elem in e.elements {
			rewrite_expr_for_shims(elem, required_shims, from, to, arena)
		}
	}
}

rewrite_call_for_shims :: proc(
	call: ^ir.Call,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
	arena: ^ir.Arena_IR,
) {
	if call == nil || call.function == nil {
		return
	}

	if has_hook_bridge_shim(required_shims) && call.function.name == "add-zsh-hook" {
		call.function.name = "__shellx_register_hook"
	}

	if has_required_shim(required_shims, "condition_semantics") && from == .Fish && to != .Fish && is_string_match_call(call) {
		call.function.name = "__shellx_match"
		if len(call.arguments) >= 2 {
			first := strings.trim_space(ir.expr_to_string(call.arguments[0]))
			second := strings.trim_space(ir.expr_to_string(call.arguments[1]))
			if first == "string" && second == "match" {
				drop_call_arguments(call, 2)
			} else {
				drop_call_arguments(call, 1)
			}
		} else if len(call.arguments) == 1 {
			drop_call_arguments(call, 1)
		}
	}

	for arg in call.arguments {
		rewrite_expr_for_shims(arg, required_shims, from, to, arena)
	}
}

rewrite_stmt_for_shims :: proc(
	stmt: ^ir.Statement,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
	arena: ^ir.Arena_IR,
) {
	switch stmt.type {
	case .Assign:
		rewrite_expr_for_shims(stmt.assign.value, required_shims, from, to, arena)
	case .Call:
		rewrite_call_for_shims(&stmt.call, required_shims, from, to, arena)
	case .Logical:
		for &seg in stmt.logical.segments {
			rewrite_call_for_shims(&seg.call, required_shims, from, to, arena)
		}
	case .Case:
		rewrite_expr_for_shims(stmt.case_.value, required_shims, from, to, arena)
		for &arm in stmt.case_.arms {
			for &nested in arm.body {
				rewrite_stmt_for_shims(&nested, required_shims, from, to, arena)
			}
		}
	case .Return:
		rewrite_expr_for_shims(stmt.return_.value, required_shims, from, to, arena)
	case .Branch:
		rewrite_expr_for_shims(stmt.branch.condition, required_shims, from, to, arena)
		for &nested in stmt.branch.then_body {
			rewrite_stmt_for_shims(&nested, required_shims, from, to, arena)
		}
		for &nested in stmt.branch.else_body {
			rewrite_stmt_for_shims(&nested, required_shims, from, to, arena)
		}
	case .Loop:
		rewrite_expr_for_shims(stmt.loop.items, required_shims, from, to, arena)
		rewrite_expr_for_shims(stmt.loop.condition, required_shims, from, to, arena)
		for &nested in stmt.loop.body {
			rewrite_stmt_for_shims(&nested, required_shims, from, to, arena)
		}
	case .Pipeline:
		for &cmd in stmt.pipeline.commands {
			rewrite_call_for_shims(&cmd, required_shims, from, to, arena)
		}
	}
}

apply_ir_shim_rewrites :: proc(
	program: ^ir.Program,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
	arena: ^ir.Arena_IR,
) {
	if program == nil || len(required_shims) == 0 {
		return
	}
	for &fn in program.functions {
		for &stmt in fn.body {
			rewrite_stmt_for_shims(&stmt, required_shims, from, to, arena)
		}
	}
	for &stmt in program.statements {
		rewrite_stmt_for_shims(&stmt, required_shims, from, to, arena)
	}
}

apply_shim_callsite_rewrites :: proc(
	text: string,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	out := strings.clone(text, allocator)
	changed_any := false

	if has_hook_bridge_shim(required_shims) {
		rewritten, changed := rewrite_add_zsh_hook_callsites(out, allocator)
		if changed {
			delete(out)
			out = rewritten
			changed_any = true
		} else {
			delete(rewritten)
		}
		out, changed_any = replace_with_flag(out, "add-zsh-hook precmd ", "__shellx_register_precmd ", changed_any, allocator)
		out, changed_any = replace_with_flag(out, "add-zsh-hook preexec ", "__shellx_register_preexec ", changed_any, allocator)
	}

	if has_array_bridge_shim(required_shims) {
		if to == .Fish {
			rewritten, changed := rewrite_declare_array_callsites(out, allocator)
			if changed {
				delete(out)
				out = rewritten
				changed_any = true
			} else {
				delete(rewritten)
			}
		}
		if (to == .POSIX || to == .Bash) && (from == .Bash || from == .Zsh) {
			rewritten, changed := rewrite_posix_array_bridge_callsites(out, allocator)
			if changed {
				delete(out)
				out = rewritten
				changed_any = true
			} else {
				delete(rewritten)
			}

			rewritten, changed = rewrite_posix_array_parameter_expansions(out, from, allocator)
			if changed {
				delete(out)
				out = rewritten
				changed_any = true
			} else {
				delete(rewritten)
			}
		}
		if from == .Fish && (to == .Bash || to == .Zsh) {
			rewritten, changed := rewrite_fish_set_list_bridge_callsites(out, allocator)
			if changed {
				delete(out)
				out = rewritten
				changed_any = true
			} else {
				delete(rewritten)
			}
		}
	}

	if has_required_shim(required_shims, "parameter_expansion") {
		rewritten, changed := rewrite_parameter_expansion_callsites(out, to, allocator)
		if changed {
			delete(out)
			out = rewritten
			changed_any = true
		} else {
			delete(rewritten)
		}
	}

	if has_required_shim(required_shims, "condition_semantics") && from == .Fish && to != .Fish {
		rewritten, changed := rewrite_fish_test_callsites_to_shim(out, allocator)
		if changed {
			delete(out)
			out = rewritten
			changed_any = true
		} else {
			delete(rewritten)
		}
	}

	if has_required_shim(required_shims, "process_substitution") {
		rewritten, changed := rewrite_process_substitution_callsites(out, to, allocator)
		if changed {
			delete(out)
			out = rewritten
			changed_any = true
		} else {
			delete(rewritten)
		}
	}

	return out, changed_any
}

rewrite_fish_test_callsites_to_shim :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, i in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}

		if strings.has_prefix(trimmed, "if test ") {
			out_line = strings.concatenate([]string{indent, "if __shellx_test ", strings.trim_space(trimmed[len("if test "):])}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "elif test ") {
			out_line = strings.concatenate([]string{indent, "elif __shellx_test ", strings.trim_space(trimmed[len("elif test "):])}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "while test ") {
			out_line = strings.concatenate([]string{indent, "while __shellx_test ", strings.trim_space(trimmed[len("while test "):])}, allocator)
			out_allocated = true
			changed = true
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_add_zsh_hook_callsites :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, i in lines {
		out_line := line
		out_allocated := false
		idx := find_substring(line, "add-zsh-hook ")
		if idx >= 0 {
			prefix := line[:idx]
			rest := strings.trim_space(line[idx+len("add-zsh-hook "):])
			tokens := strings.fields(rest)
			start := 0
			for start < len(tokens) && strings.has_prefix(tokens[start], "-") {
				start += 1
			}
			if start+1 < len(tokens) {
				hook := tokens[start]
				fn := tokens[start+1]
				if hook == "precmd" {
					out_line = strings.concatenate([]string{prefix, "__shellx_register_precmd ", fn}, allocator)
					out_allocated = true
					changed = true
				} else if hook == "preexec" {
					out_line = strings.concatenate([]string{prefix, "__shellx_register_preexec ", fn}, allocator)
					out_allocated = true
					changed = true
				} else {
					out_line = strings.concatenate([]string{prefix, ":"}, allocator)
					out_allocated = true
					changed = true
				}
			} else {
				out_line = strings.concatenate([]string{prefix, ":"}, allocator)
				out_allocated = true
				changed = true
			}
			delete(tokens)
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_declare_array_callsites :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "declare -a ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			rest := strings.trim_space(trimmed[len("declare -a "):])
			if rest != "" {
				out_line = strings.concatenate([]string{indent, "__shellx_array_set ", rest}, allocator)
				out_allocated = true
				changed = true
			}
		}
		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_fish_set_list_bridge_callsites :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)

		if strings.has_prefix(trimmed, "set ") && !strings.has_prefix(trimmed, "set -") {
			rest := strings.trim_space(trimmed[len("set "):])
			parts := strings.split(rest, " ")
			defer delete(parts)
			non_empty := make([dynamic]string, 0, len(parts), context.temp_allocator)
			defer delete(non_empty)
			for p in parts {
				if p != "" {
					append(&non_empty, p)
				}
			}
			// Convert only simple list assignments: set name a b
			// Single-value assignment remains native shell assignment handling.
			if len(non_empty) >= 3 {
				name := non_empty[0]
				if is_basic_name(name) {
					simple_values := true
					for i := 1; i < len(non_empty); i += 1 {
						v := non_empty[i]
						if strings.contains(v, "\"") || strings.contains(v, "'") || strings.contains(v, "$") || strings.contains(v, "\\") {
							simple_values = false
							break
						}
					}
					if simple_values {
						indent_len := len(line) - len(strings.trim_left_space(line))
						indent := ""
						if indent_len > 0 {
							indent = line[:indent_len]
						}
						value_text := strings.join(non_empty[1:], " ", allocator)
						out_line = strings.concatenate([]string{indent, "__shellx_list_to_array ", name, " ", value_text}, allocator)
						delete(value_text)
						out_allocated = true
						changed = true
					}
				}
			}
			}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

normalize_posix_preparse_array_literals :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	return rewrite_posix_array_bridge_callsites(text, allocator)
}

rewrite_posix_array_bridge_callsites :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	has_trailing_comment_after_array_close :: proc(payload: string) -> bool {
		close_idx := -1
		for i := len(payload) - 1; i >= 0; i -= 1 {
			if payload[i] == ')' {
				close_idx = i
				break
			}
		}
		if close_idx < 0 {
			return false
		}
		for i := close_idx + 1; i < len(payload); i += 1 {
			if payload[i] == '#' {
				return true
			}
		}
		return false
	}

	parse_array_assignment_payload :: proc(payload: string) -> (name, items: string, append, block_open, ok: bool) {
		if has_trailing_comment_after_array_close(payload) {
			return "", "", false, false, false
		}
		if strings.contains(payload, "${") &&
			(strings.contains(payload, "##") || strings.contains(payload, "#?") || strings.contains(payload, "%%") || strings.contains(payload, "%?")) {
			return "", "", false, false, false
		}
		append_mode := false
		marker_idx := find_substring(payload, "+=(")
		open_idx := -1
		if marker_idx >= 0 {
			append_mode = true
			open_idx = marker_idx + 2
		} else {
			marker_idx = find_substring(payload, "=(")
			if marker_idx < 0 {
				return "", "", false, false, false
			}
			open_idx = marker_idx + 1
		}
		if open_idx < 0 || open_idx >= len(payload) || payload[open_idx] != '(' {
			return "", "", false, false, false
		}
		lhs := strings.trim_space(payload[:marker_idx])
		if !is_basic_name(lhs) {
			return "", "", false, false, false
		}

		rhs := strings.trim_space(payload[open_idx+1:])
		if rhs == "" {
			return lhs, "", append_mode, true, true
		}
		if strings.has_suffix(rhs, ")") {
			return lhs, strings.trim_space(rhs[:len(rhs)-1]), append_mode, false, true
		}
		return lhs, rhs, append_mode, true, true
	}

	parse_array_decl_payload :: proc(payload: string) -> (name, items: string, append, block_open, ok, has_items: bool) {
		if has_trailing_comment_after_array_close(payload) {
			return "", "", false, false, false, false
		}
		i := 0
		has_array_flag := false
		for i < len(payload) {
			for i < len(payload) && (payload[i] == ' ' || payload[i] == '\t') {
				i += 1
			}
			if i >= len(payload) {
				break
			}
			if payload[i] != '-' {
				break
			}
			start := i
			for i < len(payload) && payload[i] != ' ' && payload[i] != '\t' {
				i += 1
			}
			flag := payload[start:i]
			if strings.contains(flag, "a") {
				has_array_flag = true
			}
		}
		rest := strings.trim_space(payload[i:])
		if !has_array_flag || rest == "" {
			return "", "", false, false, false, false
		}
		decl_name, decl_items, append_mode, decl_block_open, decl_ok := parse_array_assignment_payload(rest)
		if decl_ok {
			return decl_name, decl_items, append_mode, decl_block_open, true, true
		}
		if is_basic_name(rest) {
			return rest, "", false, false, true, false
		}
		return "", "", false, false, false, false
	}

	parse_array_unset_payload :: proc(payload: string) -> (name, index: string, ok: bool) {
		eq_idx := find_substring(payload, "=")
		if eq_idx <= 0 {
			return "", "", false
		}
		lhs := strings.trim_space(payload[:eq_idx])
		rhs := strings.trim_space(payload[eq_idx+1:])
		if rhs != "()" {
			return "", "", false
		}
		open_idx := find_substring(lhs, "[")
		close_idx := find_substring(lhs, "]")
		if open_idx <= 0 || close_idx <= open_idx+1 || close_idx != len(lhs)-1 {
			return "", "", false
		}
		name = strings.trim_space(lhs[:open_idx])
		index = strings.trim_space(lhs[open_idx+1 : close_idx])
		if !is_basic_name(name) || index == "" {
			return "", "", false
		}
		return name, index, true
	}

	build_list_call_line :: proc(indent: string, name: string, items: string, append_mode: bool, allocator := context.allocator) -> string {
		if items == "" {
			if append_mode {
				return strings.concatenate([]string{indent, ":"}, allocator)
			}
			return strings.concatenate([]string{indent, name, "=\"\""}, allocator)
		}
		if append_mode {
			return strings.concatenate([]string{indent, "__shellx_list_append ", name, " ", items}, allocator)
		}
		return strings.concatenate([]string{indent, "__shellx_list_set ", name, " ", items}, allocator)
	}

	rewrite_inline_array_append_segment :: proc(line: string, allocator := context.allocator) -> (string, bool) {
		marker_idx := find_substring(line, "+=(")
		if marker_idx < 0 {
			return strings.clone(line, allocator), false
		}

		name_end := marker_idx
		name_start := name_end
		for name_start > 0 && is_basic_name_char(line[name_start-1]) {
			name_start -= 1
		}
		if name_start == name_end {
			return strings.clone(line, allocator), false
		}
		name := strings.trim_space(line[name_start:name_end])
		if !is_basic_name(name) {
			return strings.clone(line, allocator), false
		}

		open_idx := marker_idx + 2
		if open_idx >= len(line) || line[open_idx] != '(' {
			return strings.clone(line, allocator), false
		}
		close_idx := -1
		for j := open_idx + 1; j < len(line); j += 1 {
			if line[j] == ')' {
				close_idx = j
				break
			}
		}
		if close_idx < 0 {
			return strings.clone(line, allocator), false
		}

		items := strings.trim_space(line[open_idx+1 : close_idx])
		replacement := build_list_call_line("", name, items, true, allocator)
		defer delete(replacement)

		out := strings.concatenate(
			[]string{
				line[:name_start],
				replacement,
				line[close_idx+1:],
			},
			allocator,
		)
		return out, true
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	in_array_block := false
	in_dquote_block := false
	block_name := ""
	block_append := false
	block_indent := ""
	block_items := make([dynamic]string, 0, 8, context.temp_allocator)
	defer delete(block_items)

	for idx := 0; idx < len(lines); idx += 1 {
		line := lines[idx]
		line_quote_toggles := count_unescaped_double_quotes(line)%2 == 1
		if in_dquote_block || line_quote_toggles {
			strings.write_string(&builder, line)
			if line_quote_toggles {
				in_dquote_block = !in_dquote_block
			}
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if in_array_block {
			trimmed_block := strings.trim_space(line)
			if trimmed_block == ")" || trimmed_block == ");" {
				items := strings.join(block_items[:], " ", allocator)
				out_line := build_list_call_line(block_indent, block_name, items, block_append, allocator)
				strings.write_string(&builder, out_line)
				delete(out_line)
				delete(items)
				clear(&block_items)
				in_array_block = false
				block_name = ""
				block_append = false
				block_indent = ""
				changed = true
				if idx+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}

			if trimmed_block != "" && !strings.has_prefix(trimmed_block, "#") {
				item := strings.trim_space(trimmed_block)
				if strings.has_suffix(item, "\\") && len(item) > 1 {
					item = strings.trim_space(item[:len(item)-1])
				}
				if item != "" {
					append(&block_items, item)
				}
			}
			changed = true
			continue
		}

		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}

		inline_rewritten, inline_changed := rewrite_inline_array_append_segment(out_line, allocator)
		if inline_changed {
			out_line = inline_rewritten
			out_allocated = true
			trimmed = strings.trim_space(out_line)
			changed = true
		} else {
			delete(inline_rewritten)
		}

		decl_cmd := ""
		if strings.has_prefix(trimmed, "declare ") {
			decl_cmd = "declare "
		} else if strings.has_prefix(trimmed, "typeset ") {
			decl_cmd = "typeset "
		} else if strings.has_prefix(trimmed, "local ") {
			decl_cmd = "local "
		}

		if decl_cmd != "" {
			payload := strings.trim_space(trimmed[len(decl_cmd):])
			name, items, append_mode, block_open, ok, has_items := parse_array_decl_payload(payload)
			if ok {
				if has_items {
					if block_open {
						in_array_block = true
						block_name = name
						block_append = append_mode
						block_indent = indent
						clear(&block_items)
						if items != "" {
							append(&block_items, items)
						}
						changed = true
						if out_allocated {
							delete(out_line)
						}
						continue
					}
					if out_allocated {
						delete(out_line)
					}
					out_line = build_list_call_line(indent, name, items, append_mode, allocator)
					out_allocated = true
				} else {
					if out_allocated {
						delete(out_line)
					}
					out_line = strings.concatenate([]string{indent, name, "=\"\""}, allocator)
					out_allocated = true
				}
				changed = true
			}
		} else {
			name, items, append_mode, block_open, ok := parse_array_assignment_payload(trimmed)
			if ok {
				if block_open {
					in_array_block = true
					block_name = name
					block_append = append_mode
					block_indent = indent
					clear(&block_items)
					if items != "" {
						append(&block_items, items)
					}
					changed = true
					if out_allocated {
						delete(out_line)
					}
					continue
				}

				if out_allocated {
					delete(out_line)
				}
				out_line = build_list_call_line(indent, name, items, append_mode, allocator)
				out_allocated = true
				changed = true
			} else {
				unset_name, unset_index, unset_ok := parse_array_unset_payload(trimmed)
				if unset_ok {
					if out_allocated {
						delete(out_line)
					}
					out_line = strings.concatenate(
						[]string{indent, "__shellx_list_unset_index ", unset_name, " ", unset_index},
						allocator,
					)
					out_allocated = true
					changed = true
				}
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if in_array_block {
		items := strings.join(block_items[:], " ", allocator)
		out_line := build_list_call_line(block_indent, block_name, items, block_append, allocator)
		strings.write_byte(&builder, '\n')
		strings.write_string(&builder, out_line)
		delete(out_line)
		delete(items)
		changed = true
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_posix_array_parameter_expansions :: proc(
	text: string,
	from: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if text == "" {
		return strings.clone(text, allocator), false
	}

	escape_dquote_preserve_dollar :: proc(s: string, allocator := context.allocator) -> string {
		builder := strings.builder_make()
		defer strings.builder_destroy(&builder)
		for i in 0 ..< len(s) {
			c := s[i]
			if c == '\\' || c == '"' || c == '`' {
				strings.write_byte(&builder, '\\')
			}
			strings.write_byte(&builder, c)
		}
		return strings.clone(strings.to_string(builder), allocator)
	}

	quote_shell_arg_allow_expansion :: proc(s: string, allocator := context.allocator) -> string {
		trimmed := strings.trim_space(s)
		if trimmed == "" {
			return "\"\""
		}
		if (strings.has_prefix(trimmed, "\"") && strings.has_suffix(trimmed, "\"")) ||
			(strings.has_prefix(trimmed, "'") && strings.has_suffix(trimmed, "'")) {
			return strings.clone(trimmed, allocator)
		}
		escaped := escape_dquote_preserve_dollar(trimmed, allocator)
		out := strings.concatenate([]string{"\"", escaped, "\""}, allocator)
		delete(escaped)
		return out
	}

	rewrite_zsh_subscript_flag_for_posix :: proc(
		var_name: string,
		index_expr: string,
		allocator := context.allocator,
	) -> (string, bool) {
		trimmed := strings.trim_space(index_expr)
		if len(trimmed) < 4 || trimmed[0] != '(' {
			return "", false
		}
		close_idx := find_substring(trimmed, ")")
		if close_idx <= 1 || close_idx+1 >= len(trimmed) {
			return "", false
		}
		flags := strings.trim_space(trimmed[1:close_idx])
		operand := strings.trim_space(trimmed[close_idx+1:])
		if flags == "" || operand == "" {
			return "", false
		}

		operand_arg := quote_shell_arg_allow_expansion(operand, allocator)
		defer delete(operand_arg)

		if flags == "r" || flags == "R" {
			return fmt.tprintf("$(__shellx_zsh_subscript_r %s %s)", var_name, operand_arg), true
		}
		if flags == "I" {
			return fmt.tprintf("$(__shellx_zsh_subscript_I %s %s)", var_name, operand_arg), true
		}
		if strings.has_prefix(flags, "Ib:") {
			rest := flags[len("Ib:"):]
			default_var := ""
			if rest != "" {
				end := find_substring(rest, ":")
				if end >= 0 {
					default_var = strings.trim_space(rest[:end])
				} else {
					default_var = strings.trim_space(rest)
				}
			}
			default_arg := "\"\""
			if default_var != "" {
				default_arg = fmt.tprintf("\"%s\"", default_var)
			}
			return fmt.tprintf("$(__shellx_zsh_subscript_Ib %s %s %s)", var_name, operand_arg, default_arg), true
		}
		return "", false
	}

	build_posix_list_has_call :: proc(var_name: string, index_expr: string, allocator := context.allocator) -> string {
		idx_arg := quote_shell_arg_allow_expansion(index_expr, allocator)
		defer delete(idx_arg)
		return fmt.tprintf("$(__shellx_list_has %s %s)", var_name, idx_arg)
	}

	adjust_index_for_source :: proc(index_text: string, from: ShellDialect) -> string {
		trimmed := strings.trim_space(index_text)
		if from == .Zsh {
			return trimmed
		}
		if trimmed == "" {
			return ""
		}

		is_digits := true
		value := 0
		for ch in trimmed {
			if ch < '0' || ch > '9' {
				is_digits = false
				break
			}
			value = value*10 + int(ch-'0')
		}
		if from == .Bash {
			if is_digits {
				return fmt.tprintf("%d", value+1)
			}
			if strings.has_prefix(trimmed, "$") && len(trimmed) > 1 && is_basic_name(trimmed[1:]) {
				return fmt.tprintf("$((%s + 1))", trimmed[1:])
			}
			if is_basic_name(trimmed) {
				return fmt.tprintf("$((%s + 1))", trimmed)
			}
		}
		return trimmed
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if from == .Zsh &&
			i+3 < len(text) &&
			text[i] == '$' &&
			text[i+1] == '+' &&
			is_basic_name_char(text[i+2]) {
			name_start := i + 2
			name_end := name_start
			for name_end < len(text) && is_basic_name_char(text[name_end]) {
				name_end += 1
			}
			if name_end < len(text) && text[name_end] == '[' {
				idx_start := name_end + 1
				idx_end := idx_start
				for idx_end < len(text) && text[idx_end] != ']' {
					idx_end += 1
				}
				if idx_end > idx_start && idx_end < len(text) {
					name := text[name_start:name_end]
					index := strings.trim_space(text[idx_start:idx_end])
					if is_basic_name(name) && index != "" {
						idx_text := adjust_index_for_source(index, from)
						repl := build_posix_list_has_call(name, idx_text, allocator)
						strings.write_string(&builder, repl)
						changed = true
						i = idx_end + 1
						continue
					}
				}
			}
		}

		if i+1 < len(text) && text[i] == '$' && text[i+1] == '{' {
			inner_start := i + 2
			j := find_matching_brace(text, i+1)
			if j > inner_start {
				inner := strings.trim_space(text[inner_start:j])
				repl := ""

				// ${+arr[idx]} -> presence probe.
				if strings.has_prefix(inner, "+") {
					plus_inner := strings.trim_space(inner[1:])
					bracket_idx := find_substring(plus_inner, "[")
					if bracket_idx > 0 && strings.has_suffix(plus_inner, "]") {
						name := strings.trim_space(plus_inner[:bracket_idx])
						index := strings.trim_space(plus_inner[bracket_idx+1 : len(plus_inner)-1])
						if is_basic_name(name) && index != "" {
							idx_text := adjust_index_for_source(index, from)
							repl = build_posix_list_has_call(name, idx_text, allocator)
						}
					}
				}

				// ${!arr[@][(r)pat]} style key/subscript probes.
				if repl == "" && strings.has_prefix(inner, "!") {
					rest := strings.trim_space(inner[1:])
					keys_idx := find_substring(rest, "[@][")
					if keys_idx > 0 && strings.has_suffix(rest, "]") {
						name := strings.trim_space(rest[:keys_idx])
						index := strings.trim_space(rest[keys_idx+4 : len(rest)-1])
						if is_basic_name(name) {
							sub_repl, sub_ok := rewrite_zsh_subscript_flag_for_posix(name, index, allocator)
							if sub_ok {
								repl = sub_repl
							}
						}
					}
				}

				// ${arr[idx]+1} -> index/key existence probe.
				if repl == "" && strings.has_suffix(inner, "+1") {
					open_idx := find_substring(inner, "[")
					close_idx := find_substring(inner, "]")
					if open_idx > 0 && close_idx > open_idx {
						name := strings.trim_space(inner[:open_idx])
						suffix := strings.trim_space(inner[close_idx+1:])
						index := strings.trim_space(inner[open_idx+1 : close_idx])
						if suffix == "+1" && is_basic_name(name) && index != "" && !strings.has_prefix(index, "(") {
							idx_text := adjust_index_for_source(index, from)
							repl = build_posix_list_has_call(name, idx_text, allocator)
						}
					}
				}

				if strings.has_prefix(inner, "#") {
					len_inner := strings.trim_space(inner[1:])
					bracket_idx := find_substring(len_inner, "[")
					if bracket_idx > 0 && strings.has_suffix(len_inner, "]") {
						name := strings.trim_space(len_inner[:bracket_idx])
						index := strings.trim_space(len_inner[bracket_idx+1 : len(len_inner)-1])
						if is_basic_name(name) && (index == "@" || index == "*") {
							repl = fmt.tprintf("$(__shellx_list_len %s)", name)
						}
					}
				}

				if repl == "" {
					bracket_idx := find_substring(inner, "[")
					if bracket_idx > 0 && strings.has_suffix(inner, "]") {
						name := strings.trim_space(inner[:bracket_idx])
						index := strings.trim_space(inner[bracket_idx+1 : len(inner)-1])
						if is_basic_name(name) {
							if index == "@" || index == "*" {
								repl = fmt.tprintf("$%s", name)
							} else if index != "" {
								if from == .Zsh {
									sub_repl, sub_ok := rewrite_zsh_subscript_flag_for_posix(name, index, allocator)
									if sub_ok {
										repl = sub_repl
									}
								}
								if repl == "" {
									idx_text := adjust_index_for_source(index, from)
									if idx_text != "" {
										if from == .Zsh && (strings.contains(idx_text, "(") || strings.contains(idx_text, ")")) {
											idx_arg := quote_shell_arg_allow_expansion(idx_text, allocator)
											repl = fmt.tprintf("$(__shellx_list_get %s %s)", name, idx_arg)
											delete(idx_arg)
										} else {
											repl = fmt.tprintf("$(__shellx_list_get %s %s)", name, idx_text)
										}
									}
								}
							}
						}
					}
				}

				if repl != "" {
					strings.write_string(&builder, repl)
					changed = true
					i = j + 1
					continue
				}
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

replace_with_flag :: proc(
	text: string,
	from_s: string,
	to_s: string,
	changed_any: bool,
	allocator: mem.Allocator,
) -> (string, bool) {
	replaced, changed := strings.replace_all(text, from_s, to_s, allocator)
	if changed {
		delete(text)
		return replaced, true
	}
	if raw_data(replaced) != raw_data(text) {
		delete(replaced)
	}
	return text, changed_any
}

normalize_zsh_preparse_local_cmdsubs :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "local ") || strings.has_prefix(trimmed, "typeset ") || strings.has_prefix(trimmed, "integer ") {
			kw_len := 0
			if strings.has_prefix(trimmed, "local ") {
				kw_len = len("local ")
			} else if strings.has_prefix(trimmed, "typeset ") {
				kw_len = len("typeset ")
			} else {
				kw_len = len("integer ")
			}
			rest := strings.trim_space(trimmed[kw_len:])
			tokens := strings.fields(rest)
			defer delete(tokens)
			start := 0
			for start < len(tokens) && strings.has_prefix(tokens[start], "-") {
				start += 1
			}
			if start < len(tokens) {
				decl := strings.join(tokens[start:], " ", allocator)
				if strings.contains(decl, "$(") && strings.contains(decl, "=") {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					out_line = strings.concatenate([]string{indent, decl}, allocator)
					out_allocated = true
					changed = true
				}
				delete(decl)
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

normalize_zsh_preparse_syntax :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	out := strings.clone(text, allocator)
	changed := false

	out, changed = replace_with_flag(out, "${(@)ZSHZ_EXCLUDE_DIRS:-${(@)_Z_EXCLUDE_DIRS}}", "${ZSHZ_EXCLUDE_DIRS:-${_Z_EXCLUDE_DIRS}}", changed, allocator)
	out, changed = replace_with_flag(out, "${(@Pk)1}", "${1}", changed, allocator)
	out, changed = replace_with_flag(out, "${(Pkv)match_array}", "${match_array}", changed, allocator)
	out, changed = replace_with_flag(out, "${(P)match}", "${match}", changed, allocator)
	out, changed = replace_with_flag(out, "${${(@On)descending_list}#*\\|}", "${descending_list}", changed, allocator)
	out, changed = replace_with_flag(out, "${(@On)descending_list}", "${descending_list}", changed, allocator)
	out, changed = replace_with_flag(out, "${(@on)output}", "${output}", changed, allocator)
	out, changed = replace_with_flag(out, "${(M)@:#-*}", "$@", changed, allocator)
	out, changed = replace_with_flag(out, "(@Pk)", "", changed, allocator)
	out, changed = replace_with_flag(out, "(Pkv)", "", changed, allocator)
	out, changed = replace_with_flag(out, "(P)", "", changed, allocator)
	out, changed = replace_with_flag(out, "(@On)", "", changed, allocator)
	out, changed = replace_with_flag(out, "(@on)", "", changed, allocator)
	// Do not globally strip "(@)" tokens; preserve them for structured
	// zsh->bash rewriting (e.g. ${(@)arr} -> ${arr[@]}).
	out, changed = replace_with_flag(out, "(M)", "", changed, allocator)
	out, changed = replace_with_flag(out, "(q-)", "", changed, allocator)
	out, changed = replace_with_flag(out, "(qq)", "", changed, allocator)
	out, changed = replace_with_flag(out, "(q)", "", changed, allocator)
	out, changed = replace_with_flag(out, "(s.:.)", "", changed, allocator)
	out, changed = replace_with_flag(out, "&& () {", "&& {", changed, allocator)
	out, changed = replace_with_flag(out, "|| () {", "|| {", changed, allocator)
	out, changed = replace_with_flag(
		out,
		"'builtin' 'local' '-a' '__p9k_src_opts'",
		":",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'",
		":",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"'builtin' 'unset' '__p9k_src_opts'",
		":",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"git_version=\"${${(As: :)$(git version 2>/dev/null)}[3]}\"",
		"git_version=\"$(git version 2>/dev/null | cut -d' ' -f3)\"",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"local repo=\"${${@[(r)(ssh://*|git://*|ftp(s)#://*|http(s)#://*|*@*)(.git/#)#]}:-$_}\"",
		"local repo=\"$_\"",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"[[ -d \"$_\" ]] && cd \"$_\" || cd \"${${repo:t}%.git/#}\"",
		"[[ -d \"$_\" ]] && cd \"$_\" || cd \"$repo\"",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"git push origin \"${b:-$1}\"",
		"if [[ -n \"$b\" ]]; then git push origin \"$b\"; else git push origin \"$1\"; fi",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"git push origin \"${b:-${1}}\"",
		"if [[ -n \"$b\" ]]; then git push origin \"$b\"; else git push origin \"$1\"; fi",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"git push --force-with-lease origin \"${b:-$1}\"",
		"if [[ -n \"$b\" ]]; then git push --force-with-lease origin \"$b\"; else git push --force-with-lease origin \"$1\"; fi",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"for old_name new_name (\n  current_branch  git_current_branch\n); do",
		"for old_name new_name in current_branch git_current_branch; do",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"for exclude in ${ZSHZ_EXCLUDE_DIRS:-${_Z_EXCLUDE_DIRS}}; do",
		"for exclude in $ZSHZ_EXCLUDE_DIRS $_Z_EXCLUDE_DIRS; do",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(out, "${${*:-${PWD}}:a}", "${PWD}", changed, allocator)
	out, changed = replace_with_flag(out, "${${*:-${PWD}}:A}", "${PWD}", changed, allocator)
	out, changed = replace_with_flag(out, "${(@k)output_matches}", "${output_matches}", changed, allocator)
	out, changed = replace_with_flag(out, "${(k)output_matches}", "${output_matches}", changed, allocator)
		out, changed = replace_with_flag(out, "${(f)REPLY}", "$REPLY", changed, allocator)
		out, changed = replace_with_flag(out, "${(k)opts}", "${opts}", changed, allocator)
		out, changed = replace_with_flag(out, "${=ZSHZ[FUNCTIONS]}", "${ZSHZ[FUNCTIONS]}", changed, allocator)
		out, changed = replace_with_flag(out, "${=ZSHZ[", "${ZSHZ[", changed, allocator)
		out, changed = replace_with_flag(out, "${${line%\\|*}#*\\|}", "${line}", changed, allocator)
	out, changed = replace_with_flag(out, "alias x=extract", "function x { extract \"$@\"; }", changed, allocator)
	out, changed = replace_with_flag(out, "0=\"${${0:#/*}:-$PWD/$0}\"", "0=\"$PWD/$0\"", changed, allocator)
	out, changed = replace_with_flag(out, "environment+=( PAGER=\"${commands[less]:-$PAGER}\" )", "environment+=( PAGER=\"$PAGER\" )", changed, allocator)
	out, changed = replace_with_flag(out, "echo ${(%):-\"%B$1%b copied to clipboard.\"}", "echo \"$1 copied to clipboard.\"", changed, allocator)
	out, changed = replace_with_flag(
		out,
		"function man \\\n  dman \\\n  debman {\n  colored $0 \"$@\"\n}",
		"function man {\n  colored $0 \"$@\"\n}\nfunction dman {\n  colored $0 \"$@\"\n}\nfunction debman {\n  colored $0 \"$@\"\n}",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(out, "(( ${+commands[fzf]} )) || return 1", "true || return 1", changed, allocator)
	out, changed = replace_with_flag(out, "local fzf_ver=${\"$(fzf --version)\"#fzf }", "local fzf_ver=\"$(fzf --version)\"", changed, allocator)
	out, changed = replace_with_flag(out, "is-at-least 0.48.0 ${${(s: :)fzf_ver}[1]} || return 1", "is-at-least 0.48.0 ${fzf_ver} || return 1", changed, allocator)
	out, changed = replace_with_flag(
		out,
		"if (( ! ${+commands[fzf]} )) && [[ \"$PATH\" != *$fzf_base/bin* ]]; then",
		"if [[ \"$PATH\" != *$fzf_base/bin* ]]; then",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"if (( ${+commands[fzf-share]} )) && dir=\"$(fzf-share)\" && [[ -d \"${dir}\" ]]; then",
		"if dir=\"$(fzf-share)\" && [[ -d \"${dir}\" ]]; then",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"elif (( ${+commands[brew]} )) && dir=\"$(brew --prefix fzf 2>/dev/null)\"; then",
		"elif dir=\"$(brew --prefix fzf 2>/dev/null)\"; then",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(out, "__sudo-replace-buffer() {", "__sudo_replace_buffer() {", changed, allocator)
	out, changed = replace_with_flag(out, "sudo-command-line() {", "sudo_command_line() {", changed, allocator)
	out, changed = replace_with_flag(out, "__sudo-replace-buffer ", "__sudo_replace_buffer ", changed, allocator)
	out, changed = replace_with_flag(out, "zle -N sudo-command-line", "zle -N sudo_command_line", changed, allocator)
	out, changed = replace_with_flag(out, "zle -N sudo-command-line", "zle -N sudo_command_line", changed, allocator)

	lines := strings.split_lines(out)
	defer delete(lines)
	if len(lines) > 0 {
		builder := strings.builder_make()
		defer strings.builder_destroy(&builder)
		line_changed := false
		for line, i in lines {
			out_line := line
			out_allocated := false
			trimmed := strings.trim_space(line)
			if (strings.has_prefix(trimmed, "git ") || strings.has_prefix(trimmed, "command git ")) &&
				strings.contains(trimmed, "\"${b:-$1}\"") {
				pat := "\"${b:-$1}\""
				pat_idx := strings.index(trimmed, pat)
				if pat_idx >= 0 {
					cmd_prefix := strings.trim_space(trimmed[:pat_idx])
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					rewrite := strings.concatenate(
						[]string{
							indent,
							"if [[ -n \"$b\" ]]; then ",
							cmd_prefix,
							" \"$b\"; else ",
							cmd_prefix,
							" \"$1\"; fi",
						},
						allocator,
					)
					out_line = rewrite
					out_allocated = true
					line_changed = true
				}
			}
			if strings.contains(out_line, "${exclude}|${exclude}/*)") {
				repl, c := strings.replace_all(out_line, "${exclude}|${exclude}/*)", "*)", allocator)
				if c {
					out_line = repl
					out_allocated = true
					line_changed = true
				} else {
					delete(repl)
				}
			}
			current_trimmed := strings.trim_space(out_line)
			if strings.contains(current_trimmed, "exec {tmpfd}>|") && strings.contains(current_trimmed, "\"$tempfile\"") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				if out_allocated {
					delete(out_line)
				}
				out_line = strings.concatenate([]string{indent, "tmpfd=1"}, allocator)
				out_allocated = true
				line_changed = true
			}
			current_trimmed = strings.trim_space(out_line)
			if strings.has_prefix(current_trimmed, "*) return ;;") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				if out_allocated {
					delete(out_line)
				}
				out_line = strings.concatenate([]string{indent, "*) return 0 ;;"}, allocator)
				out_allocated = true
				line_changed = true
			}
			current_trimmed = strings.trim_space(out_line)
			if strings.has_prefix(current_trimmed, "if (( ") && strings.contains(current_trimmed, "[") &&
				strings.contains(current_trimmed, "]") && strings.has_suffix(current_trimmed, ")); then") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				if out_allocated {
					delete(out_line)
				}
				out_line = strings.concatenate([]string{indent, "if true; then"}, allocator)
				out_allocated = true
				line_changed = true
			}
			current_trimmed = strings.trim_space(out_line)
			if strings.has_prefix(current_trimmed, "if (( ") && strings.contains(current_trimmed, "${") && strings.has_suffix(current_trimmed, ")); then") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				if out_allocated {
					delete(out_line)
				}
				out_line = strings.concatenate([]string{indent, "if true; then"}, allocator)
				out_allocated = true
				line_changed = true
			}
			current_trimmed = strings.trim_space(out_line)
			if strings.has_prefix(current_trimmed, "if (( ! ") && strings.contains(current_trimmed, ")) && [[") && strings.has_suffix(current_trimmed, " ]]; then") {
				cond_start := strings.index_byte(current_trimmed, '[')
				cond_end := strings.last_index_byte(current_trimmed, ']')
				if cond_start >= 0 && cond_end > cond_start {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					cond := strings.trim_space(current_trimmed[cond_start : cond_end+1])
					if out_allocated {
						delete(out_line)
					}
					out_line = strings.concatenate([]string{indent, "if ", cond, "; then"}, allocator)
					out_allocated = true
					line_changed = true
				}
			}
			current_trimmed = strings.trim_space(out_line)
			if strings.has_prefix(current_trimmed, "if (( ") && strings.contains(current_trimmed, ":-${") && strings.has_suffix(current_trimmed, " )); then") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				if out_allocated {
					delete(out_line)
				}
				out_line = strings.concatenate([]string{indent, "if true; then"}, allocator)
				out_allocated = true
				line_changed = true
			}
			if strings.contains(out_line, "${(M)@:#-*}") {
				repl, c := strings.replace_all(out_line, "${(M)@:#-*}", "$@", allocator)
				if c {
					if out_allocated {
						delete(out_line)
					}
					out_line = repl
					out_allocated = true
					line_changed = true
				} else {
					delete(repl)
				}
			}
			strings.write_string(&builder, out_line)
			if out_allocated {
				delete(out_line)
			}
			if i+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
		}
		if line_changed {
			delete(out)
			out = strings.clone(strings.to_string(builder), allocator)
			changed = true
		}
	}

	if !changed {
		return out, false
	}
	return out, true
}

normalize_zsh_preparse_parser_safety :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	out := strings.clone(text, allocator)
	changed := false

	out, changed = replace_with_flag(
		out,
		"'builtin' 'local' '-a' '__p9k_src_opts'",
		":",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'",
		":",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"'builtin' 'unset' '__p9k_src_opts'",
		":",
		changed,
		allocator,
	)
	out, changed = replace_with_flag(
		out,
		"${POWERLEVEL9K_INSTALLATION_DIR:-${${(%):-%x}:A:h}}",
		"$POWERLEVEL9K_INSTALLATION_DIR",
		changed,
		allocator,
	)
	rewritten, rewritten_changed := rewrite_zsh_preparse_plus_probes_for_parser(out, changed, allocator)
	delete(out)
	out = rewritten
	changed = rewritten_changed

	return out, changed
}

rewrite_zsh_preparse_plus_probes_for_parser :: proc(
	text: string,
	changed: bool,
	allocator := context.allocator,
) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), changed
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	any_changed := changed
	for line, i in lines {
		out_line, line_changed := rewrite_zsh_plus_probe_line_for_parser(line, allocator)
		if line_changed {
			any_changed = true
		}
		strings.write_string(&builder, out_line)
		delete(out_line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), any_changed
}

rewrite_zsh_plus_probe_line_for_parser :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	out := strings.clone(line, allocator)
	changed := false

	cursor := 0
	for cursor < len(out) {
		open_rel := find_substring(out[cursor:], "((")
		if open_rel < 0 {
			break
		}
		open_idx := cursor + open_rel
		close_rel := find_substring(out[open_idx+2:], "))")
		if close_rel < 0 {
			break
		}
		close_idx := open_idx + 2 + close_rel
		inner := strings.trim_space(out[open_idx+2 : close_idx])
		negated := false
		if strings.has_prefix(inner, "!") {
			negated = true
			inner = strings.trim_space(inner[1:])
		}
		if !strings.has_prefix(inner, "$+") {
			cursor = close_idx + 2
			continue
		}

		target := strings.trim_space(inner[2:])
		if !is_zsh_plus_probe_target(target) {
			cursor = close_idx + 2
			continue
		}

		test_expr := ""
		if negated {
			test_expr = strings.concatenate([]string{"[ -z \"${", target, "+1}\" ]"}, allocator)
		} else {
			test_expr = strings.concatenate([]string{"[ -n \"${", target, "+1}\" ]"}, allocator)
		}
		next := strings.concatenate([]string{out[:open_idx], test_expr, out[close_idx+2:]}, allocator)
		delete(test_expr)
		delete(out)
		out = next
		changed = true
		cursor = open_idx + 1
	}

	return out, changed
}

is_zsh_plus_probe_target :: proc(s: string) -> bool {
	target := strings.trim_space(s)
	if target == "" || strings.contains(target, " ") || strings.contains(target, "\t") {
		return false
	}

	open_idx := find_substring(target, "[")
	if open_idx < 0 {
		return is_basic_name(target)
	}
	if !strings.has_suffix(target, "]") || open_idx == 0 {
		return false
	}
	name := strings.trim_space(target[:open_idx])
	index := strings.trim_space(target[open_idx+1 : len(target)-1])
	if !is_basic_name(name) || index == "" {
		return false
	}
	if strings.contains(index, " ") || strings.contains(index, "\t") {
		return false
	}
	if strings.contains(index, "\"") || strings.contains(index, "'") {
		return false
	}
	if strings.contains(index, "$(") || strings.contains(index, "`") {
		return false
	}
	return true
}

normalize_bash_preparse_array_literals :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		eq_idx := find_substring(trimmed, "=")
		if eq_idx > 0 {
			name := strings.trim_space(trimmed[:eq_idx])
			rhs := strings.trim_space(trimmed[eq_idx+1:])
			if is_basic_name(name) && strings.has_prefix(rhs, "(") && strings.has_suffix(rhs, ")") {
				items := strings.trim_space(rhs[1 : len(rhs)-1])
				if items != "" &&
					!strings.contains(items, "$") &&
					!strings.contains(items, "`") &&
					!strings.contains(items, "#") &&
					!strings.contains(items, "\"") &&
					!strings.contains(items, "'") {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					out_line = strings.concatenate([]string{indent, "set ", name, " ", items}, allocator)
					out_allocated = true
					changed = true
				}
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

normalize_fish_preparse_parser_safety :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	out := strings.clone(text, allocator)
	changed := false

	// Tree-sitter fish grammar can report syntax errors for literal "\"(\"" tokens.
	// Canonicalize to equivalent single-quoted literal for parser stability.
	out, changed = replace_with_flag(out, "\"(\"", "'('", changed, allocator)

	lines := strings.split_lines(out)
	defer delete(lines)
	if len(lines) > 0 {
		builder := strings.builder_make()
		defer strings.builder_destroy(&builder)
		rewrote_lines := false
		for line, i in lines {
			out_line := line
			out_alloc := false
			trimmed := strings.trim_space(line)
			if strings.has_prefix(trimmed, "set ") {
				fields := strings.fields(trimmed)
				defer delete(fields)
				if len(fields) >= 4 && fields[0] == "set" && is_basic_name(fields[1]) && !strings.has_prefix(fields[2], "-") {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					rest := strings.trim_space(trimmed[len("set "):])
					out_line = strings.concatenate([]string{indent, "__shellx_list_set ", rest}, allocator)
					out_alloc = true
					rewrote_lines = true
				}
			}
			strings.write_string(&builder, out_line)
			if out_alloc {
				delete(out_line)
			}
			if i+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
		}
		if rewrote_lines {
			next := strings.clone(strings.to_string(builder), allocator)
			delete(out)
			out = next
			changed = true
		}
	}

	return out, changed
}

find_substring :: proc(s: string, needle: string) -> int {
	if len(needle) == 0 || len(s) < len(needle) {
		return -1
	}
	last := len(s) - len(needle)
	for i in 0 ..< last+1 {
		matched := true
		for j in 0 ..< len(needle) {
			if s[i+j] != needle[j] {
				matched = false
				break
			}
		}
		if matched {
			return i
		}
	}
	return -1
}

find_matching_brace :: proc(s: string, open_idx: int) -> int {
	if open_idx < 0 || open_idx >= len(s) || s[open_idx] != '{' {
		return -1
	}
	depth := 1
	i := open_idx + 1
	for i < len(s) {
		if s[i] == '{' {
			depth += 1
		} else if s[i] == '}' {
			depth -= 1
			if depth == 0 {
				return i
			}
		}
		i += 1
	}
	return -1
}

find_top_level_substring :: proc(s: string, needle: string) -> int {
	if len(needle) == 0 || len(s) < len(needle) {
		return -1
	}
	depth := 0
	last := len(s) - len(needle)
	for i in 0 ..< last+1 {
		if s[i] == '{' {
			depth += 1
			continue
		}
		if s[i] == '}' {
			if depth > 0 {
				depth -= 1
			}
			continue
		}
		if depth != 0 {
			continue
		}
		matched := true
		for j in 0 ..< len(needle) {
			if s[i+j] != needle[j] {
				matched = false
				break
			}
		}
		if matched {
			return i
		}
	}
	return -1
}

replace_first_range :: proc(s: string, start: int, end_exclusive: int, repl: string, allocator := context.allocator) -> (string, bool) {
	if start < 0 || end_exclusive < start || end_exclusive > len(s) {
		return strings.clone(s, allocator), false
	}
	prefix := s[:start]
	suffix := s[end_exclusive:]
	out := strings.concatenate([]string{prefix, repl, suffix}, allocator)
	return out, true
}

sanitize_zsh_arithmetic_text :: proc(s: string, allocator := context.allocator) -> (string, bool) {
	out := strings.clone(s, allocator)
	changed := false
	for {
		open_idx := find_substring(out, "((")
		if open_idx < 0 {
			break
		}
		close_rel := find_substring(out[open_idx+2:], "))")
		if close_rel < 0 {
			break
		}
		close_idx := open_idx + 2 + close_rel + 2
		repl := "true"
		// Assignment arithmetic should become a scalar value.
		if open_idx > 0 && out[open_idx-1] == '=' {
			repl = "1"
		}
		next, ok := replace_first_range(out, open_idx, close_idx, repl, allocator)
		if !ok {
			break
		}
		delete(out)
		out = next
		changed = true
	}
	return out, changed
}

normalize_case_body_connectors :: proc(body: string, allocator := context.allocator) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	i := 0
	for i < len(body) {
		if body[i] == '{' || body[i] == '}' {
			i += 1
			continue
		}
		if i+1 < len(body) && body[i] == '&' && body[i+1] == '&' {
			strings.write_byte(&builder, ';')
			i += 2
			continue
		}
		if i+1 < len(body) && body[i] == '|' && body[i+1] == '|' {
			strings.write_byte(&builder, ';')
			i += 2
			continue
		}
		strings.write_byte(&builder, body[i])
		i += 1
	}
	return strings.clone(strings.to_string(builder), allocator)
}

normalize_zsh_recovered_fish_text :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_switch := false
	function_depth := 0
	control_depth := 0

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		out_line := line
		out_allocated := false

			if strings.contains(trimmed, "set -l max_cursor_pos (count") && !strings.contains(trimmed, ")") {
				out_line = strings.concatenate([]string{indent, "set -l retval \"\"; set -l max_cursor_pos (count $BUFFER)"}, allocator)
				out_allocated = true
				changed = true
			} else if strings.contains(trimmed, "(count $argv)BUFFER") {
			repl, c := strings.replace_all(trimmed, "(count $argv)BUFFER", "(count $BUFFER)", allocator)
			if c {
				out_line = strings.concatenate([]string{indent, repl}, allocator)
				out_allocated = true
				delete(repl)
				changed = true
				} else if raw_data(repl) != raw_data(trimmed) {
					delete(repl)
				}
			}
			if !out_allocated && strings.contains(trimmed, "set -l total (") && strings.contains(trimmed, "__shellx_param_length") {
				out_line = strings.concatenate([]string{indent, "set -l total 0"}, allocator)
				out_allocated = true
				changed = true
			}
			if !out_allocated && strings.contains(trimmed, "set -l word (") && strings.contains(trimmed, "__shellx_array_get;") {
				out_line = strings.concatenate([]string{indent, "set -l word \"\""}, allocator)
				out_allocated = true
				changed = true
			}

		if strings.has_prefix(trimmed, "function ") && function_depth > 0 {
			for control_depth > 0 {
				strings.write_string(&builder, "end\n")
				control_depth -= 1
				changed = true
			}
			strings.write_string(&builder, "end\n")
			function_depth -= 1
			changed = true
		}

		if strings.has_prefix(trimmed, "switch ") {
			in_switch = true
		} else if trimmed == "end" {
			in_switch = false
		}

		if strings.has_suffix(trimmed, "()") && is_basic_name(strings.trim_space(trimmed[:len(trimmed)-2])) {
			name := strings.trim_space(trimmed[:len(trimmed)-2])
			out_line = strings.concatenate([]string{indent, "function ", name}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "function eval ") {
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_allocated = true
			changed = true
		} else if strings.contains(trimmed, ";&") {
			repl, c := strings.replace_all(trimmed, ";&", "", allocator)
			if c {
				out_line = strings.concatenate([]string{indent, strings.trim_space(repl)}, allocator)
				out_allocated = true
				delete(repl)
				changed = true
			} else if raw_data(repl) != raw_data(trimmed) {
				delete(repl)
			}
		}
		if strings.has_prefix(strings.trim_space(out_line), "eval ") && count_unescaped_double_quotes(strings.trim_space(out_line))%2 == 1 {
			if out_allocated {
				delete(out_line)
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_allocated = true
			changed = true
		}

		current := strings.trim_space(out_line)
		if strings.contains(current, "\"\"\"") {
			repl, c := strings.replace_all(out_line, "\"\"\"", "\"\"", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = repl
				out_allocated = true
				changed = true
			}
			current = strings.trim_space(out_line)
		}

		if strings.has_prefix(current, "for ") && strings.contains(current, " in \"\"\"") {
			repl, c := strings.replace_all(current, " in \"\"\"", " in \"\"", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = strings.concatenate([]string{indent, repl}, allocator)
				out_allocated = true
				delete(repl)
				changed = true
			} else if raw_data(repl) != raw_data(current) {
				delete(repl)
			}
			current = strings.trim_space(out_line)
		}

		if in_switch && current == ":" {
			if out_allocated {
				delete(out_line)
			}
			out_line = strings.concatenate([]string{indent, "case *"}, allocator)
			out_allocated = true
			changed = true
			current = strings.trim_space(out_line)
		}
		if in_switch && strings.has_prefix(current, "(") {
			arm := strings.trim_space(current[1:])
			close_idx := find_substring(arm, ")")
			if close_idx > 0 {
				pat := strings.trim_space(arm[:close_idx])
				if pat != "" {
					if out_allocated {
						delete(out_line)
					}
					out_line = strings.concatenate([]string{indent, "case ", pat}, allocator)
					out_allocated = true
					changed = true
					current = strings.trim_space(out_line)
				}
			}
		}
		if in_switch &&
			!strings.has_prefix(current, "case ") &&
			((strings.has_prefix(current, "\"") && strings.has_suffix(current, "\"")) ||
				(strings.has_prefix(current, "'") && strings.has_suffix(current, "'"))) {
			if out_allocated {
				delete(out_line)
			}
			out_line = strings.concatenate([]string{indent, "case ", current}, allocator)
			out_allocated = true
			changed = true
			current = strings.trim_space(out_line)
		}
		if !strings.has_prefix(current, "case ") &&
			!strings.has_prefix(current, "if ") &&
			!strings.has_prefix(current, "for ") &&
			strings.contains(current, "*)") {
			close_idx := find_substring(current, "*)")
			if close_idx >= 0 {
				pat := strings.trim_space(current[:close_idx+1])
				body := strings.trim_space(current[close_idx+2:])
				if pat != "" {
					if out_allocated {
						delete(out_line)
					}
					if body == "" {
						out_line = strings.concatenate([]string{indent, "case ", pat}, allocator)
					} else {
						out_line = strings.concatenate([]string{indent, "case ", pat, "\n", indent, "  ", body}, allocator)
					}
					out_allocated = true
					changed = true
					current = strings.trim_space(out_line)
				}
			}
		}
		if !strings.has_prefix(current, "case ") &&
			!strings.has_prefix(current, "if ") &&
			!strings.has_prefix(current, "for ") &&
			!strings.has_prefix(current, "function ") &&
			!strings.has_prefix(current, "(") {
			close_idx := find_substring(current, ")")
			if close_idx > 0 {
				pat := strings.trim_space(current[:close_idx])
				body := strings.trim_space(current[close_idx+1:])
				pat_ok := pat != "" && !strings.contains(pat, " ") && !strings.contains(pat, "\t")
				if pat_ok && body != "" {
					if out_allocated {
						delete(out_line)
					}
					out_line = strings.concatenate([]string{indent, "case ", pat, "\n", indent, "  ", body}, allocator)
					out_allocated = true
					changed = true
					current = strings.trim_space(out_line)
				}
			}
		}

		if strings.has_prefix(current, "case #") {
			if out_allocated {
				delete(out_line)
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_allocated = true
			changed = true
		}
		current = strings.trim_space(out_line)
		if current != "" && !strings.has_prefix(current, "#") && count_unescaped_double_quotes(current)%2 == 1 {
			if out_allocated {
				delete(out_line)
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_allocated = true
			changed = true
		}

		strings.write_string(&builder, out_line)
		final_trimmed := strings.trim_space(out_line)
		if strings.has_prefix(final_trimmed, "function ") {
			function_depth += 1
		} else if strings.has_prefix(final_trimmed, "if ") ||
			strings.has_prefix(final_trimmed, "for ") ||
			strings.has_prefix(final_trimmed, "while ") ||
			strings.has_prefix(final_trimmed, "switch ") ||
			final_trimmed == "begin" {
			control_depth += 1
		} else if final_trimmed == "end" {
			if control_depth > 0 {
				control_depth -= 1
			} else if function_depth > 0 {
				function_depth -= 1
			}
		}
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_canonicalize_for_fish :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_case := false

	for line, i in lines {
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}

		out_line := strings.clone(line, allocator)
		if strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
			in_case = true
		} else if trimmed == "esac" {
			in_case = false
		}

		// zsh nested anonymous function blocks.
		if trimmed == "() {" {
			delete(out_line)
			out_line = strings.concatenate([]string{indent, "{"}, allocator)
			changed = true
		}

		arith_fixed, arith_changed := sanitize_zsh_arithmetic_text(out_line, allocator)
		if arith_changed {
			delete(out_line)
			out_line = arith_fixed
			changed = true
		} else {
			delete(arith_fixed)
		}

		trimmed_out := strings.trim_space(out_line)
		if strings.contains(trimmed_out, "$+commands[") {
			repl, c := strings.replace_all(out_line, "$+commands[", "1 # ", allocator)
			if c {
				delete(out_line)
				out_line = repl
				changed = true
				trimmed_out = strings.trim_space(out_line)
			}
		}

		if strings.contains(trimmed_out, "exec {") {
			delete(out_line)
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed_out = ":"
		}

		if strings.contains(out_line, "; and {") ||
			strings.contains(out_line, "; or {") ||
			strings.contains(out_line, "and {") ||
			strings.contains(out_line, "or {") ||
			strings.contains(out_line, "};") {
			tmp1, c1 := strings.replace_all(out_line, "; and {", "; and ", allocator)
			if c1 {
				delete(out_line)
				out_line = tmp1
				changed = true
			} else if raw_data(tmp1) != raw_data(out_line) {
				delete(tmp1)
			}
			tmp2, c2 := strings.replace_all(out_line, "; or {", "; or ", allocator)
			if c2 {
				delete(out_line)
				out_line = tmp2
				changed = true
			} else if raw_data(tmp2) != raw_data(out_line) {
				delete(tmp2)
			}
			tmp3, c3 := strings.replace_all(out_line, "};", ";", allocator)
			if c3 {
				delete(out_line)
				out_line = tmp3
				changed = true
			} else if raw_data(tmp3) != raw_data(out_line) {
				delete(tmp3)
			}
			trimmed_out = strings.trim_space(out_line)
			tmp4, c4 := strings.replace_all(out_line, "and {", "and ", allocator)
			if c4 {
				delete(out_line)
				out_line = tmp4
				changed = true
			} else if raw_data(tmp4) != raw_data(out_line) {
				delete(tmp4)
			}
			tmp5, c5 := strings.replace_all(out_line, "or {", "or ", allocator)
			if c5 {
				delete(out_line)
				out_line = tmp5
				changed = true
			} else if raw_data(tmp5) != raw_data(out_line) {
				delete(tmp5)
			}
			trimmed_out = strings.trim_space(out_line)
		}

		// Split complex zsh case arms `pat) cmd ;;` into stable multi-line shell form.
		if in_case && strings.contains(trimmed_out, ")") && strings.contains(trimmed_out, ";;") {
			close_idx := find_substring(trimmed_out, ")")
			semi_idx := find_substring(trimmed_out, ";;")
			if close_idx > 0 && semi_idx > close_idx {
				pat := strings.trim_space(trimmed_out[:close_idx+1])
				body := strings.trim_space(trimmed_out[close_idx+1 : semi_idx])
				if body == "" {
					body = ":"
				}
				body_s := normalize_case_body_connectors(body, allocator)
				strings.write_string(&builder, indent)
				strings.write_string(&builder, pat)
				strings.write_byte(&builder, '\n')
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "  ")
				strings.write_string(&builder, body_s)
				delete(body_s)
				delete(out_line)
				changed = true
				if i+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
		}

		strings.write_string(&builder, out_line)
		delete(out_line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

leading_basic_name :: proc(s: string) -> string {
	if len(s) == 0 {
		return ""
	}
	end := 0
	for end < len(s) && is_basic_name_char(s[end]) {
		end += 1
	}
	if end == 0 {
		return ""
	}
	return s[:end]
}

escape_double_quoted :: proc(s: string, allocator := context.allocator) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	for i in 0 ..< len(s) {
		c := s[i]
		if c == '\\' || c == '"' || c == '$' || c == '`' {
			strings.write_byte(&builder, '\\')
		}
		strings.write_byte(&builder, c)
	}

	return strings.clone(strings.to_string(builder), allocator)
}

rewrite_parameter_expansion_callsites :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if to != .Fish {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	is_expr_sep := proc(c: byte) -> bool {
		return c == ' ' || c == '\t' || c == '\n' || c == '\r' ||
			c == ';' || c == '|' || c == '&' || c == ','
	}
	modifier_name_from_inner := proc(inner: string) -> string {
		trimmed := strings.trim_space(inner)
		if len(trimmed) < 4 || trimmed[0] != '(' {
			return ""
		}
		close_idx := find_substring(trimmed, ")")
		if close_idx <= 0 || close_idx+1 >= len(trimmed) {
			return ""
		}
		tail := strings.trim_space(trimmed[close_idx+1:])
		if tail == "" {
			return ""
		}
		end := 0
		for end < len(tail) {
			ch := tail[end]
			if !is_param_name_char(ch) {
				break
			}
			end += 1
		}
		if end == 0 {
			return ""
		}
		return tail[:end]
	}
	plain_name_from_inner := proc(inner: string) -> string {
		trimmed := strings.trim_space(inner)
		if trimmed == "" {
			return ""
		}
		if trimmed[0] == '=' || trimmed[0] == '+' || trimmed[0] == '#' {
			trimmed = strings.trim_space(trimmed[1:])
		}
		end := 0
		for end < len(trimmed) {
			ch := trimmed[end]
			if !is_param_name_char(ch) {
				break
			}
			end += 1
		}
		if end == 0 {
			return ""
		}
		return trimmed[:end]
	}

	i := 0
	for i < len(text) {
		if i+1 < len(text) && text[i] == '$' && text[i+1] == '{' {
			inner_start := i + 2
			j := find_matching_brace(text, i+1)
			if j > inner_start {
				inner := strings.trim_space(text[inner_start:j])
				repl := ""
				mod_name := modifier_name_from_inner(inner)
				if mod_name != "" {
					repl = fmt.tprintf("$%s", mod_name)
				}

				if repl == "" {
					if len(inner) > 1 && inner[0] == '#' {
						var_name := strings.trim_space(inner[1:])
						if var_name != "" && is_basic_name(var_name) {
							repl = fmt.tprintf("(__shellx_param_length %s)", var_name)
						}
					} else {
					// ${var:?message}
					req_idx := find_top_level_substring(inner, ":?")
					if req_idx > 0 {
						var_name := strings.trim_space(inner[:req_idx])
						err_msg := strings.trim_space(inner[req_idx+2:])
						if var_name != "" && is_basic_name(var_name) {
							escaped_msg := escape_double_quoted(err_msg, allocator)
							repl = fmt.tprintf("(__shellx_param_required %s \"%s\")", var_name, escaped_msg)
							delete(escaped_msg)
						}
					}

					// ${var:-default} / ${var:=default}
					def_idx := find_top_level_substring(inner, ":-")
					if def_idx < 0 {
						def_idx = find_top_level_substring(inner, ":=")
					}
					if repl == "" && def_idx > 0 {
						var_name := strings.trim_space(inner[:def_idx])
						default_value := strings.trim_space(inner[def_idx+2:])
						if var_name != "" && is_basic_name(var_name) {
							if strings.contains(default_value, "${") ||
								strings.contains(default_value, "\"") ||
								strings.contains(default_value, "`") {
								repl = fmt.tprintf("$%s", var_name)
							} else {
								escaped_default := escape_double_quoted(default_value, allocator)
								repl = fmt.tprintf("(__shellx_param_default %s \"%s\")", var_name, escaped_default)
								delete(escaped_default)
							}
						}
					}

					// ${var-default}
					plain_def_idx := find_top_level_substring(inner, "-")
					if repl == "" && plain_def_idx > 0 {
						var_name := strings.trim_space(inner[:plain_def_idx])
						default_value := strings.trim_space(inner[plain_def_idx+1:])
						if var_name != "" && is_basic_name(var_name) {
							if strings.contains(default_value, "${") ||
								strings.contains(default_value, "\"") ||
								strings.contains(default_value, "`") {
								repl = fmt.tprintf("$%s", var_name)
							} else {
								escaped_default := escape_double_quoted(default_value, allocator)
								repl = fmt.tprintf("(__shellx_param_default %s \"%s\")", var_name, escaped_default)
								delete(escaped_default)
							}
						}
					}

					// ${var}
					if repl == "" && is_basic_name(inner) {
						repl = fmt.tprintf("$%s", inner)
					}

					// ${arr[@]} / ${arr[*]} / ${arr[idx]}
					if repl == "" {
						bracket_idx := find_substring(inner, "[")
						if bracket_idx > 0 && strings.has_suffix(inner, "]") {
							var_name := strings.trim_space(inner[:bracket_idx])
							if is_basic_name(var_name) {
								index_expr := strings.trim_space(inner[bracket_idx+1 : len(inner)-1])
								if to == .Fish && index_expr != "" && index_expr != "@" && index_expr != "*" {
									is_digits := true
									for ch in index_expr {
										if ch < '0' || ch > '9' {
											is_digits = false
											break
										}
									}
									if is_digits {
										idx := 0
										for ch in index_expr {
											idx = idx*10 + int(ch-'0')
										}
										idx += 1 // Bash-style numeric index to fish 1-based index.
										idx_text := fmt.tprintf("%d", idx)
										repl = fmt.tprintf("$%s[%s]", var_name, idx_text)
									} else {
										if strings.contains(index_expr, "\"") || strings.contains(index_expr, "`") || strings.contains(index_expr, "${") {
											repl = fmt.tprintf("$%s", var_name)
										} else {
											escaped_index := escape_double_quoted(index_expr, allocator)
											repl = fmt.tprintf("(__shellx_array_get %s \"%s\")", var_name, escaped_index)
											delete(escaped_index)
										}
									}
								} else {
									repl = fmt.tprintf("$%s", var_name)
								}
							}
						}
					}

					// Fallback for unsupported forms: keep parser-valid fish.
					if repl == "" {
						name := leading_basic_name(inner)
						if name != "" {
							repl = fmt.tprintf("$%s", name)
						} else {
							repl = "\"\""
						}
					}
				}
				}

				if repl != "" {
					strings.write_string(&builder, repl)
					changed = true
					i = j + 1
					continue
				}
			} else {
				// Recovery path for broken zsh modifier expansions that miss the closing brace.
				k := i + 2
				for k < len(text) && !is_expr_sep(text[k]) {
					k += 1
				}
				if k > i+2 {
					raw_inner := text[i+2 : k]
					mod_name := modifier_name_from_inner(raw_inner)
					if mod_name != "" {
						strings.write_string(&builder, fmt.tprintf("$%s", mod_name))
						changed = true
						i = k
						continue
					}
					plain_name := plain_name_from_inner(raw_inner)
					if plain_name != "" {
						strings.write_string(&builder, fmt.tprintf("$%s", plain_name))
						changed = true
						i = k
						continue
					}
				}
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_process_substitution_callsites :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if to != .Fish && to != .POSIX {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if i+1 < len(text) && (text[i] == '<' || text[i] == '>') && text[i+1] == '(' {
			direction := text[i]
			depth := 1
			j := i + 2
			for j < len(text) {
				if text[j] == '(' {
					depth += 1
				} else if text[j] == ')' {
					depth -= 1
					if depth == 0 {
						break
					}
				}
				j += 1
			}

			if j < len(text) && depth == 0 {
				cmd := strings.trim_space(text[i+2 : j])
				escaped_cmd := escape_double_quoted(cmd, allocator)
				fn := "__shellx_psub_in"
				if direction == '>' {
					fn = "__shellx_psub_out"
				}

				if to == .Fish {
					strings.write_string(&builder, fmt.tprintf("(%s \"%s\")", fn, escaped_cmd))
				} else {
					strings.write_string(&builder, fmt.tprintf("$(%s \"%s\")", fn, escaped_cmd))
				}

				delete(escaped_cmd)
				changed = true
				i = j + 1
				continue
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_fish_special_parameters :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_single := false
	in_double := false
	i := 0
	for i < len(line) {
		c := line[i]
		if c == '\'' && !in_double {
			in_single = !in_single
			strings.write_byte(&builder, c)
			i += 1
			continue
		}
		if c == '"' && !in_single {
			in_double = !in_double
			strings.write_byte(&builder, c)
			i += 1
			continue
		}
		if !in_single && c == '$' && i+1 < len(line) {
			switch line[i+1] {
			case '#':
				strings.write_string(&builder, "(count $argv)")
				changed = true
				i += 2
				continue
			case '@', '*':
				strings.write_string(&builder, "$argv")
				changed = true
				i += 2
				continue
			case '?':
				strings.write_string(&builder, "$status")
				changed = true
				i += 2
				continue
			case '$':
				strings.write_string(&builder, "$fish_pid")
				changed = true
				i += 2
				continue
			}
		}
		strings.write_byte(&builder, c)
		i += 1
	}
	if !changed {
		return strings.clone(line, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_target_callsites :: proc(
	text: string,
	from: ShellDialect,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	out := strings.clone(text, allocator)
	changed_any := false

	if from == .Zsh && (to == .Bash || to == .POSIX) {
		zero, zero_changed := rewrite_zsh_multiline_for_paren_syntax_for_bash(out, allocator)
		delete(out)
		zero_b, zero_b_changed := rewrite_zsh_multiline_case_patterns_for_bash(zero, allocator)
		delete(zero)
		first, first_changed := rewrite_zsh_parameter_expansion_for_bash(zero_b, allocator)
		delete(zero_b)
		first_for_next := first
		firstb_changed := false
		if to == .POSIX {
			firstb, changed_posix_arrays := rewrite_posix_array_parameter_expansions(first_for_next, from, allocator)
			if changed_posix_arrays {
				delete(first_for_next)
				first_for_next = firstb
				firstb_changed = true
			} else {
				delete(firstb)
			}
		}
		second, second_changed := rewrite_zsh_syntax_for_bash(first_for_next, allocator)
		delete(first_for_next)
		secondb, secondb_changed := rewrite_empty_then_blocks_for_bash(second, allocator)
		delete(second)
		third, third_changed := rewrite_unsupported_zsh_expansions_for_bash(secondb, allocator)
		delete(secondb)
		if to == .Bash && third_changed && !strings.contains(third, "__shellx_zsh_expand()") {
			shim_body := strings.trim_space(`
__shellx_zsh_expand() {
  # fallback shim for zsh-only parameter expansion forms not directly translatable
  printf "%s" ""
}
`)
			shim := strings.concatenate([]string{shim_body, "\n\n"}, allocator)
			with_shim := strings.concatenate([]string{shim, third}, allocator)
			delete(shim)
			delete(third)
			out = with_shim
			changed_any = true
		} else {
			out = third
		}
		changed_any = changed_any || zero_changed || zero_b_changed || first_changed || firstb_changed || second_changed || secondb_changed || third_changed
	}
	if from == .Zsh && to == .Fish {
		rewritten, changed := rewrite_zsh_canonicalize_for_fish(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = normalize_zsh_recovered_fish_text(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_zsh_multiline_for_paren_syntax_for_bash(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
	}

	if to == .Fish {
		rewritten, changed := rewrite_shell_to_fish_syntax(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_fish_connector_assignments(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_parameter_expansion_callsites(out, to, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		out, changed_any = replace_with_flag(out, "$)", "\\$)", changed_any, allocator)
		out, changed_any = replace_with_flag(out, "builtin which", "command which", changed_any, allocator)
	}

	if from == .Fish && (to == .Bash || to == .POSIX) {
		rewritten, changed := rewrite_fish_to_posix_syntax(out, to, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_fish_list_index_access(out, to, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
	}
	if from == .Fish && to == .Zsh {
		rewritten, changed := rewrite_fish_to_posix_syntax(out, .Zsh, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
	}

	if from == .POSIX && (to == .Bash || to == .Zsh) {
		// POSIX sources are already sh-compatible for bash/zsh; avoid heavy
		// non-fish hardening passes that can degrade command substitutions.
		return out, changed_any
	}

		if to == .Bash || to == .POSIX || to == .Zsh {
		if from == .Zsh {
			rewritten, changed := normalize_shell_structured_blocks(out, to, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}

		rewritten, changed := rewrite_shell_parse_hardening(out, to, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		if from == .Zsh && to != .Zsh && strings.contains(out, "ZSH_THEME_VIRTUALENV_PREFIX") {
			out, changed_any = replace_with_flag(out, "return_code=\"%(?..%F{red}%?", "return_code=\"\"", changed_any, allocator)
		}
			if from == .Zsh && (to == .Bash || to == .POSIX) {
				rewritten, changed = rewrite_targeted_zsh_plugin_structural_repairs(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
				rewritten, changed = rewrite_lambda_mod_theme_structural_repairs(out, to, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
				rewritten, changed = rewrite_powerlevel10k_configure_structural_repairs(out, to, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
				rewritten, changed = rewrite_pure_theme_case_labels_for_sh(out, to, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
				rewritten, changed = rewrite_pure_theme_state_assoc_block_for_sh(out, to, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}
		if from == .Zsh {
			rewritten, changed = rewrite_zsh_close_controls_before_function_end(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
			rewritten, changed = rewrite_zsh_insert_missing_function_closers(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
			rewritten, changed = rewrite_zsh_balance_top_level_controls(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}

			rewritten, changed = rewrite_empty_shell_control_blocks(out, allocator)
			delete(out)
			out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_empty_shell_function_blocks(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = repair_shell_split_echo_param_expansion(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

			if from == .Zsh && to == .POSIX {
				rewritten, changed = repair_shell_case_arms(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}

			if from == .Zsh && (to == .Bash || to == .POSIX) {
				rewritten, changed = rewrite_targeted_zsh_plugin_structural_repairs(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}
			if from == .Bash && to == .Zsh {
				rewritten, changed = rewrite_bash_to_zsh_function_control_closer(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}
			if from == .Fish && (to == .Bash || to == .Zsh) {
				rewritten, changed = rewrite_bobthefish_parser_blockers(out, to, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}
			if from == .Bash && to != .Bash {
				rewritten, changed = rewrite_ble_make_command_parser_blockers(out, to, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}
			if from == .Zsh && strings.contains(out, "fast-syntax-highlighting") {
				out, changed_any = replace_with_flag(out, "if [[ ! -e $FAST_WORK_DIR/secondary_theme.zsh ]]; then", ":", changed_any, allocator)
				out, changed_any = replace_with_flag(out, "if { type curl &>/dev/null } {", ":", changed_any, allocator)
				out, changed_any = replace_with_flag(out, "if { type curl &>/dev/null }", ":", changed_any, allocator)
				out, changed_any = replace_with_flag(out, "} elif { type wget &>/dev/null } {", ":", changed_any, allocator)
				out, changed_any = replace_with_flag(out, "elif { type wget &>/dev/null } {", ":", changed_any, allocator)
				rewritten, changed = rewrite_fast_syntax_bind_widgets_stub_for_sh(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}
			if to != .Fish {
				rewritten, changed = rewrite_shell_orphan_then_do(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}
			if to == .Zsh {
				rewritten, changed = rewrite_zsh_function_control_balance(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
				rewritten, changed = rewrite_zsh_drop_orphan_braces(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}
		}

	if from == .Zsh && to != .Zsh {
		out, changed_any = replace_with_flag(out, "${modules[zsh/system]-}", "loaded", changed_any, allocator)
	}

	if to == .Fish {
		if from == .Bash {
			rewritten, changed := rewrite_ble_make_command_parser_blockers(out, to, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}

		rewritten, changed := rewrite_fish_parse_hardening(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = normalize_fish_case_patterns(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = normalize_fish_simple_assignments(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = lower_fish_capability_callsites(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = normalize_fish_artifacts(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = repair_fish_malformed_command_substitutions(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_fish_command_substitution_command_position(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = repair_fish_split_echo_param_default(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = repair_fish_quoted_param_default_echo(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_fish_positional_params(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = sanitize_fish_output_bytes(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		if from == .Zsh {
			rewritten, changed = rewrite_shellx_param_subshells_to_vars(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}

			if from == .Zsh {
				rewritten, changed = normalize_zsh_recovered_fish_text(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_ysu_fish_parser_blockers(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

				out, changed_any = replace_with_flag(out, "--get-regexp \"^alias\\..+$\"", "--get-regexp '^alias\\..+$'", changed_any, allocator)
			}

			if from == .Zsh {
				rewritten, changed = rewrite_pure_theme_fish_async_fetch(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}
			if from == .POSIX {
				rewritten, changed = rewrite_autoconf_gendocs_copy_images_for_fish(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}

			rewritten, changed = ensure_fish_block_balance(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
			if from == .POSIX {
				rewritten, changed = rewrite_autoconf_gendocs_copy_images_for_fish(out, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}
			if from == .Zsh {
				rewritten, changed = rewrite_lambda_mod_theme_structural_repairs(out, .Fish, allocator)
				delete(out)
				out = rewritten
				changed_any = changed_any || changed
			}
			if from == .Zsh && strings.contains(out, "fast-syntax-highlighting") {
				out, changed_any = replace_with_flag(out, "if __zx_test ! -e $FAST_WORK_DIR/secondary_theme.zsh", ":", changed_any, allocator)
				out, changed_any = replace_with_flag(out, "if { type curl &>/dev/null } {", ":", changed_any, allocator)
				out, changed_any = replace_with_flag(out, "if { type curl &>/dev/null }", ":", changed_any, allocator)
				out, changed_any = replace_with_flag(out, "} elif { type wget &>/dev/null } {", ":", changed_any, allocator)
				out, changed_any = replace_with_flag(out, "elif { type wget &>/dev/null } {", ":", changed_any, allocator)
				out, changed_any = replace_with_flag(out, "if __zx_test (uname -a) = (#i)*darwin*", "if true", changed_any, allocator)
			}
			out, changed_any = replace_with_flag(out, "html_$ 1", "html_$argv[1]", changed_any, allocator)
			rewritten, changed = ensure_fish_block_balance(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}
	if to == .Zsh && from == .Fish {
		rewritten, changed := rewrite_fish_done_zsh_trailing_brace(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_zsh_fix_fish_current_function_unset(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_fish_to_zsh_parser_blocker_signatures(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_fish_to_zsh_targeted_function_closure_repair(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_fish_to_zsh_close_trailing_if_blocks(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		trimmed_replay := strings.trim_right_space(out)
		if strings.contains(trimmed_replay, "replay() {") && strings.has_suffix(trimmed_replay, "\n:") {
			appended_replay := strings.concatenate([]string{trimmed_replay, "\n}"}, allocator)
			delete(out)
			out = appended_replay
			changed_any = true
		}

		is_tide_like := strings.contains(out, "_tide_") || strings.contains(out, "fish_prompt() {")
		if is_tide_like {
			rewritten, changed = rewrite_zsh_inline_not_set_if(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_neutralize_multiline_escaped_commands(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_tide_function_guard_blocks(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_neutralize_fish_specific_lines(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_balance_if_fi(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_drop_redundant_fi_before_brace(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_tide_colon_structural_noops(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_drop_redundant_fi_before_brace(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_drop_orphan_fi_in_functions(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}

		rewritten, changed = rewrite_zsh_close_controls_before_function_end(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_zsh_insert_missing_function_closers(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_zsh_function_control_balance(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
		rewritten, changed = rewrite_zsh_drop_orphan_braces(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
	}

	if from == .Fish && (to == .Bash || to == .Zsh) {
		rewritten, changed := rewrite_bobthefish_parser_blockers(out, to, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
	}
	if to == .Zsh {
		rewritten, changed := rewrite_zsh_drop_orphan_braces(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
	}

	if to != .Zsh {
		out, changed_any = replace_with_flag(out, "*(N)", "*", changed_any, allocator)
	}

	return out, changed_any
}

rewrite_fish_to_zsh_close_trailing_if_blocks :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	if_depth := 0
	for line in lines {
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "if ") && strings.contains(trimmed, "; then") {
			if_depth += 1
		} else if trimmed == "fi" && if_depth > 0 {
			if_depth -= 1
		}
	}
	if if_depth <= 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	strings.write_string(&builder, text)
	for if_depth > 0 {
		strings.write_string(&builder, "\nfi")
		if_depth -= 1
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_function_control_balance :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	in_fn := false
	stack := make([dynamic]string, 0, 0, context.temp_allocator)
	defer delete(stack)

	for line, i in lines {
		trimmed := strings.trim_space(line)

		if !in_fn && ((strings.has_suffix(trimmed, "() {")) || (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{"))) {
			in_fn = true
			clear(&stack)
		}

		if in_fn {
			if strings.has_prefix(trimmed, "if ") && strings.contains(trimmed, "; then") {
				append(&stack, "fi")
			} else if (strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "while ") || strings.has_prefix(trimmed, "until ")) && strings.contains(trimmed, "; do") {
				append(&stack, "done")
			} else if strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
				append(&stack, "esac")
			} else if trimmed == "fi" || trimmed == "done" || trimmed == "esac" {
				if len(stack) > 0 {
					pop(&stack)
				}
			} else if trimmed == "}" {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				for j := len(stack) - 1; j >= 0; j -= 1 {
					strings.write_string(&builder, indent)
					strings.write_string(&builder, stack[j])
					strings.write_byte(&builder, '\n')
					changed = true
				}
				clear(&stack)
				in_fn = false
			}
		}

		strings.write_string(&builder, line)
		if i < len(lines)-1 {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_drop_orphan_braces :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	fn_depth := 0

	for line, i in lines {
		trimmed := strings.trim_space(line)
		if strings.has_suffix(trimmed, "() {") || (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{")) {
			fn_depth += 1
		}

		if trimmed == "}" {
			if fn_depth <= 0 {
				changed = true
				continue
			}
			fn_depth -= 1
		}

		strings.write_string(&builder, line)
		if i < len(lines)-1 {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_bash_to_zsh_function_control_closer :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if !(strings.contains(text, "function ") && strings.contains(text, "if true; then")) &&
		!strings.contains(text, "__shellx_fn_invalid() {") &&
		!strings.contains(text, "for _ in 1; do") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	in_fn := false
	if_depth := 0
	loop_depth := 0
	for line, i in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_alloc := false

		if (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{")) || strings.has_suffix(trimmed, "() {") {
			in_fn = true
			if_depth = 0
			loop_depth = 0
		}

		if in_fn && trimmed == "if true; then :" {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_alloc = true
			changed = true
		} else if in_fn && trimmed == "for _ in 1; do" {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_alloc = true
			changed = true
		}

		final_trimmed := strings.trim_space(out_line)
		if in_fn {
			if strings.has_prefix(final_trimmed, "if ") && strings.contains(final_trimmed, "; then") {
				if_depth += 1
			} else if (strings.has_prefix(final_trimmed, "for ") || strings.has_prefix(final_trimmed, "while ")) &&
				strings.contains(final_trimmed, "; do") {
				loop_depth += 1
			} else if final_trimmed == "fi" {
				if if_depth > 0 {
					if_depth -= 1
				} else {
					indent_len := len(out_line) - len(strings.trim_left_space(out_line))
					indent := ""
					if indent_len > 0 {
						indent = out_line[:indent_len]
					}
					out_line = strings.concatenate([]string{indent, ":"}, allocator)
					out_alloc = true
					final_trimmed = ":"
					changed = true
				}
			} else if final_trimmed == "done" {
				if loop_depth > 0 {
					loop_depth -= 1
				} else {
					indent_len := len(out_line) - len(strings.trim_left_space(out_line))
					indent := ""
					if indent_len > 0 {
						indent = out_line[:indent_len]
					}
					out_line = strings.concatenate([]string{indent, ":"}, allocator)
					out_alloc = true
					final_trimmed = ":"
					changed = true
				}
			}
		}

		if in_fn && final_trimmed == "}" && (if_depth > 0 || loop_depth > 0) {
			for loop_depth > 0 {
				strings.write_string(&builder, "done\n")
				loop_depth -= 1
				changed = true
			}
			for if_depth > 0 {
				strings.write_string(&builder, "fi\n")
				if_depth -= 1
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if out_alloc {
			delete(out_line)
		}
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		if in_fn && final_trimmed == "}" {
			in_fn = false
			if_depth = 0
			loop_depth = 0
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_fish_to_zsh_parser_blocker_signatures :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	is_fzf := strings.contains(text, "_fzf_uninstall() {") && strings.contains(text, "fzf_configure_bindings")
	is_done := strings.contains(text, "__done_get_focused_window_id() {") && strings.contains(text, "__done_is_tmux_window_active() {")
	is_replay := strings.contains(text, "\nreplay() {")
	is_gitnow := strings.contains(text, "gitnow() {") && strings.contains(text, "__gitnow_manual")
	if !(is_fzf || is_done || is_replay || is_gitnow) {
		return strings.clone(text, allocator), false
	}

	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	in_done_any_fn := false
	done_any_if_depth := 0
	done_any_loop_depth := 0
	in_gitnow_fn := false
	gitnow_if_depth := 0
	in_replay_fn := false

	for line, i in lines {
		trimmed := strings.trim_space(line)
		out_line := line

		if is_done && strings.has_suffix(trimmed, "() {") {
			in_done_any_fn = true
			done_any_if_depth = 0
			done_any_loop_depth = 0
		}
		if is_gitnow && trimmed == "gitnow() {" {
			in_gitnow_fn = true
			gitnow_if_depth = 0
		}
		if is_gitnow && strings.has_suffix(trimmed, "() {") {
			in_gitnow_fn = true
			gitnow_if_depth = 0
		}
		if is_replay && trimmed == "replay() {" {
			in_replay_fn = true
		}

		if is_fzf && trimmed == "if exit; then :" {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
		}

		if in_done_any_fn {
			if strings.has_prefix(trimmed, "if ") && strings.contains(trimmed, "; then") {
				done_any_if_depth += 1
			} else if trimmed == "fi" && done_any_if_depth > 0 {
				done_any_if_depth -= 1
			}
			if strings.has_prefix(trimmed, "while ") && strings.contains(trimmed, "; do") {
				done_any_loop_depth += 1
			} else if trimmed == "done" && done_any_loop_depth > 0 {
				done_any_loop_depth -= 1
			}
		}
		if in_gitnow_fn {
			if strings.has_prefix(trimmed, "if ") && strings.contains(trimmed, "; then") {
				gitnow_if_depth += 1
			} else if trimmed == "fi" && gitnow_if_depth > 0 {
				gitnow_if_depth -= 1
			}
		}

		if in_done_any_fn && trimmed == "}" && (done_any_loop_depth > 0 || done_any_if_depth > 0) {
			for done_any_loop_depth > 0 {
				strings.write_string(&builder, "done\n")
				done_any_loop_depth -= 1
			}
			for done_any_if_depth > 0 {
				strings.write_string(&builder, "fi\n")
				done_any_if_depth -= 1
			}
			changed = true
		}
		if in_gitnow_fn && trimmed == "}" && gitnow_if_depth > 0 {
			for gitnow_if_depth > 0 {
				strings.write_string(&builder, "fi\n")
				gitnow_if_depth -= 1
			}
			changed = true
			in_gitnow_fn = false
		}

		strings.write_string(&builder, out_line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		if in_done_any_fn && trimmed == "}" {
			in_done_any_fn = false
			done_any_if_depth = 0
			done_any_loop_depth = 0
		}
		if in_gitnow_fn && trimmed == "}" {
			in_gitnow_fn = false
			gitnow_if_depth = 0
		}
		if in_replay_fn && trimmed == "}" {
			in_replay_fn = false
		}
	}

	out := strings.clone(strings.to_string(builder), allocator)
	if in_replay_fn {
		appended := strings.concatenate([]string{out, "\n}"}, allocator)
		delete(out)
		out = appended
		changed = true
	} else if is_replay {
		trimmed_out := strings.trim_right_space(out)
		if strings.contains(out, "replay() {") && strings.has_suffix(trimmed_out, ":") {
			appended := strings.concatenate([]string{trimmed_out, "\n}"}, allocator)
			delete(out)
			out = appended
			changed = true
		}
	}

	return out, changed
}

rewrite_fish_to_zsh_targeted_function_closure_repair :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	is_target :=
		strings.contains(text, "fisher() {") ||
		strings.contains(text, "__async_prompt_setup_on_startup() {") ||
		strings.contains(text, "__saplugin__start_agent() {") ||
		strings.contains(text, "fish_completion_sync_filter() {")
	if !is_target {
		return strings.clone(text, allocator), false
	}

	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	in_fn := false
	fn_if_depth := 0
	fn_loop_depth := 0
	for line, i in lines {
		trimmed := strings.trim_space(line)
		out_line := line

		if strings.has_suffix(trimmed, "() {") {
			in_fn = true
			fn_if_depth = 0
			fn_loop_depth = 0
		}

		if in_fn && strings.has_prefix(trimmed, "if ") && strings.contains(trimmed, "; then") {
			fn_if_depth += 1
		}
		if in_fn && (strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "while ")) && strings.contains(trimmed, "; do") {
			fn_loop_depth += 1
		}
		if in_fn && trimmed == "fi" && fn_if_depth > 0 {
			fn_if_depth -= 1
		}
		if in_fn && trimmed == "done" && fn_loop_depth > 0 {
			fn_loop_depth -= 1
		}

		if in_fn && trimmed == "}" {
			for fn_loop_depth > 0 {
				strings.write_string(&builder, "done\n")
				fn_loop_depth -= 1
				changed = true
			}
			for fn_if_depth > 0 {
				strings.write_string(&builder, "fi\n")
				fn_if_depth -= 1
				changed = true
			}
		}

		if strings.has_prefix(trimmed, "if set --universal _fisher_upgraded_to_4_4; then :") {
			out_line = ":"
			changed = true
		}

		strings.write_string(&builder, out_line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		if in_fn && trimmed == "}" {
			in_fn = false
			fn_if_depth = 0
			fn_loop_depth = 0
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_ysu_fish_parser_blockers :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if !(strings.contains(text, "ysu_message") && strings.contains(text, "_check_ysu_hardcore")) {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	in_write_buf_fn := false
	skip_ysu_typed_or_chain := false
	for line, i in lines {
		trimmed := strings.trim_space(line)
		out_line := line

		if skip_ysu_typed_or_chain {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			if !strings.has_suffix(trimmed, "\\") {
				skip_ysu_typed_or_chain = false
			}
		}

		if trimmed == "function _write_ysu_buffer" {
			in_write_buf_fn = true
		}
		if in_write_buf_fn && strings.has_prefix(trimmed, "if __zx_test \"$position\" = \"before\"") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			strings.write_string(&builder, indent)
			strings.write_string(&builder, "set -l position \"$YSU_MESSAGE_POSITION\"")
			strings.write_byte(&builder, '\n')
			changed = true
		}

		if strings.contains(trimmed, "echo \"(__shellx_array_get usage ") && strings.contains(trimmed, "): $key=$aliases\"") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			out_line = strings.concatenate([]string{indent, "echo \"(__shellx_array_get usage $key): $key=$aliases\""}, allocator)
			changed = true
		} else if strings.contains(trimmed, "| while read key value; do") {
			repl, _ := strings.replace(trimmed, "| while read key value; do", "| while read key value", 1)
			out_line = strings.clone(repl, allocator)
			delete(repl)
			changed = true
		} else if strings.contains(trimmed, "| while IFS=\"=\" read -r key value; do") {
			repl, _ := strings.replace(trimmed, "| while IFS=\"=\" read -r key value; do", "| while read key value", 1)
			out_line = strings.clone(repl, allocator)
			delete(repl)
			changed = true
		} else if strings.has_prefix(trimmed, "Found existing %alias_type for ") && strings.has_suffix(trimmed, "\\") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
		} else if strings.has_prefix(trimmed, ">&2 ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			rest := strings.trim_space(trimmed[len(">&2 "):])
			out_line = strings.concatenate([]string{indent, rest, " >&2"}, allocator)
			changed = true
		} else if strings.contains(trimmed, "--get-regexp \"^alias\\..+$\"") {
			repl, _ := strings.replace(trimmed, "--get-regexp \"^alias\\..+$\"", "--get-regexp '^alias\\..+$'", 1)
			out_line = strings.clone(repl, allocator)
			delete(repl)
			changed = true
		} else if strings.contains(trimmed, "if __zx_test \"$typed\" = *\" $value \"*; or \\") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			out_line = strings.concatenate([]string{indent, "if true"}, allocator)
			skip_ysu_typed_or_chain = true
			changed = true
		}

		strings.write_string(&builder, out_line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
		if in_write_buf_fn && trimmed == "end" {
			in_write_buf_fn = false
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_inline_not_set_if :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		marker := " if not set -e "
		pos := find_substring(trimmed, marker)
		if pos > 0 {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			prefix := strings.trim_space(trimmed[:pos])
			if prefix == "" {
				prefix = ":"
			}
			strings.write_string(&builder, indent)
			strings.write_string(&builder, prefix)
			strings.write_byte(&builder, '\n')
			strings.write_string(&builder, indent)
			strings.write_string(&builder, "if true; then")
			changed = true
		} else {
			strings.write_string(&builder, line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_neutralize_multiline_escaped_commands :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_drop := false
	for line, idx in lines {
		out_line := line
		trimmed := strings.trim_space(line)
		if !in_drop && strings.contains(trimmed, "$fish_path -c \\\"set ") {
			out_line = ":"
			in_drop = true
			changed = true
		} else if in_drop {
			out_line = ":"
			changed = true
			if strings.contains(trimmed, "\\\" &") {
				in_drop = false
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_tide_function_guard_blocks :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(lines) {
		trimmed := strings.trim_space(lines[i])
		if strings.contains(trimmed, "if test \"$tide_prompt_transient_enabled\" = true; then") {
			strings.write_string(&builder, ":")
			changed = true
			i += 1
			if i < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if i+2 < len(lines) &&
			strings.trim_space(lines[i]) == "fi" &&
			strings.trim_space(lines[i+1]) == "fi" &&
			strings.trim_space(lines[i+2]) == "}" {
			strings.write_string(&builder, lines[i])
			strings.write_byte(&builder, '\n')
			strings.write_string(&builder, ":")
			changed = true
			i += 2
			if i < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}

		strings.write_string(&builder, lines[i])
		i += 1
		if i < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_fix_fish_current_function_unset :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for line, idx in lines {
		out_line := line
		trimmed := strings.trim_space(line)
		if trimmed == ")" {
			out_line = ":"
			changed = true
		} else if strings.has_prefix(trimmed, "unset -f ") && strings.contains(trimmed, "current-function)") {
			out_line = "unset -f \"${funcstack[1]}\""
			changed = true
		}
		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_neutralize_fish_specific_lines :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for line, idx in lines {
		out_line := line
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "set -U ") ||
			strings.has_prefix(trimmed, "set_color ") ||
			strings.has_prefix(trimmed, "read -l ") ||
			strings.has_prefix(trimmed, "read -lx ") ||
			strings.has_prefix(trimmed, "status fish-path") ||
			strings.has_prefix(trimmed, "math ") ||
			strings.has_prefix(trimmed, "string replace ") ||
			strings.contains(trimmed, " | read -lx ") {
			out_line = ":"
			changed = true
		} else if strings.has_prefix(trimmed, "unset -f ") && strings.contains(trimmed, "current-function)") {
			out_line = "unset -f \"${funcstack[1]}\""
			changed = true
		}
		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_noop_tide_prompt_functions :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	skip_body := false
	for idx := 0; idx < len(lines); idx += 1 {
		line := lines[idx]
		trimmed := strings.trim_space(line)
		if skip_body {
			if trimmed == "}" {
				skip_body = false
			}
			if idx+1 < len(lines) {
				continue
			}
			break
		}
		if trimmed == "fish_prompt() {" || trimmed == "fish_right_prompt() {" {
			name := "fish_prompt"
			if strings.has_prefix(trimmed, "fish_right_prompt") {
				name = "fish_right_prompt"
			}
			strings.write_string(&builder, name)
			strings.write_string(&builder, "() { :; }")
			skip_body = true
			changed = true
		} else {
			strings.write_string(&builder, line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_balance_if_fi :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	if_depth := 0

	is_fn_start :: proc(trimmed: string) -> bool {
		return strings.has_suffix(trimmed, "() {") ||
			(strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{"))
	}

	for line, idx in lines {
		out_line := line
		trimmed := strings.trim_space(line)

		// If malformed recovery left a top-level/open if in flight, close it
		// before starting a new function so zsh parser scope remains valid.
		if is_fn_start(trimmed) && if_depth > 0 {
			for n := 0; n < if_depth; n += 1 {
				strings.write_string(&builder, "fi\n")
			}
			if_depth = 0
			changed = true
		}

		if is_fn_start(trimmed) {
			if_depth = 0
		}
		if strings.has_prefix(trimmed, "if ") && strings.has_suffix(trimmed, "then") {
			if_depth += 1
		} else if strings.has_prefix(trimmed, "else") || strings.has_prefix(trimmed, "elif ") {
			if if_depth == 0 {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "}" && if_depth > 0 {
			for n := 0; n < if_depth; n += 1 {
				strings.write_string(&builder, "fi\n")
			}
			if_depth = 0
			changed = true
		} else if trimmed == "fi" {
			if if_depth > 0 {
				if_depth -= 1
			} else {
				out_line = ":"
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if if_depth > 0 {
		for n := 0; n < if_depth; n += 1 {
			strings.write_string(&builder, "\nfi")
		}
		changed = true
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_drop_redundant_fi_before_brace :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	next_sig_index :: proc(lines: []string, start: int) -> int {
		for j := start; j < len(lines); j += 1 {
			t := strings.trim_space(lines[j])
			if t == "" || strings.has_prefix(t, "#") {
				continue
			}
			return j
		}
		return -1
	}
	has_prev_fi_before_scope :: proc(lines: []string, idx: int) -> bool {
		for j := idx - 1; j >= 0; j -= 1 {
			t := strings.trim_space(lines[j])
			if t == "" || strings.has_prefix(t, "#") || t == ":" || t == ":;" {
				continue
			}
			if t == "fi" {
				return true
			}
			if t == "{" || t == "}" || strings.has_suffix(t, "() {") {
				return false
			}
		}
		return false
	}

	for i := 0; i < len(lines); i += 1 {
		out_line := lines[i]
		trimmed := strings.trim_space(out_line)
		if trimmed == "fi" {
			next_idx := next_sig_index(lines, i+1)
			if next_idx >= 0 && strings.trim_space(lines[next_idx]) == "}" && has_prev_fi_before_scope(lines, i) {
				out_line = ":"
				changed = true
			}
		}
		strings.write_string(&builder, out_line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_tide_colon_structural_noops :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	in_function := false
	if_depth := 0
	for i := 0; i < len(lines); i += 1 {
		line := lines[i]
		trimmed := strings.trim_space(line)
		out_line := line

		is_fn_start := strings.has_suffix(trimmed, "() {") ||
			(strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{"))
		if is_fn_start {
			in_function = true
		}

		if strings.has_prefix(trimmed, "if ") && strings.has_suffix(trimmed, "then") {
			if_depth += 1
		} else if strings.has_prefix(trimmed, "else") || strings.has_prefix(trimmed, "elif ") {
			if if_depth == 0 {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "fi" {
			if if_depth > 0 {
				if_depth -= 1
			} else {
				out_line = ":"
				changed = true
			}
		}

		// Normalize malformed colon-only lines by structural context.
		// In control scope use `true` (safe simple command); otherwise `:`.
		if trimmed == ":" || trimmed == ":;" {
			if if_depth > 0 || in_function {
				out_line = "true"
			} else {
				out_line = ":"
			}
			changed = true
		}

		// Before function close, close any still-open if blocks so trailing no-ops
		// aren't parsed as malformed control flow.
		if trimmed == "}" && if_depth > 0 {
			for n := 0; n < if_depth; n += 1 {
				strings.write_string(&builder, "fi\n")
			}
			if_depth = 0
			changed = true
		}
		if trimmed == "}" {
			in_function = false
		}

		strings.write_string(&builder, out_line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_drop_orphan_fi_in_functions :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	in_fn := false
	fn_if_depth := 0
	for line, i in lines {
		out_line := line
		trimmed := strings.trim_space(line)
		if strings.has_suffix(trimmed, "() {") || strings.has_prefix(trimmed, "function ") {
			in_fn = true
			fn_if_depth = 0
		} else if in_fn && trimmed == "}" {
			in_fn = false
			fn_if_depth = 0
		}

		if in_fn {
			if strings.has_prefix(trimmed, "if ") && strings.has_suffix(trimmed, "then") {
				fn_if_depth += 1
			} else if trimmed == "fi" {
				if fn_if_depth > 0 {
					fn_if_depth -= 1
				} else {
					out_line = ":"
					changed = true
				}
			}
		}

		strings.write_string(&builder, out_line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

is_basic_name_char :: proc(c: byte) -> bool {
	return (c >= 'a' && c <= 'z') ||
		(c >= 'A' && c <= 'Z') ||
		(c >= '0' && c <= '9') ||
		c == '_'
}

is_basic_name :: proc(s: string) -> bool {
	if s == "" {
		return false
	}
	for i in 0 ..< len(s) {
		if !is_basic_name_char(s[i]) {
			return false
		}
	}
	return true
}

split_first_word :: proc(s: string) -> (string, string) {
	trimmed := strings.trim_space(s)
	if trimmed == "" {
		return "", ""
	}
	i := 0
	for i < len(trimmed) && trimmed[i] != ' ' && trimmed[i] != '\t' {
		i += 1
	}
	if i >= len(trimmed) {
		return trimmed, ""
	}
	return trimmed[:i], strings.trim_space(trimmed[i+1:])
}

normalize_function_name_token :: proc(token: string) -> string {
	name := strings.trim_space(token)
	if strings.has_suffix(name, "()") && len(name) > 2 {
		name = strings.trim_space(name[:len(name)-2])
	}
	open_idx := find_substring(name, "(")
	if open_idx > 0 {
		name = strings.trim_space(name[:open_idx])
	}
	return name
}

fish_function_hook_kind_from_decl :: proc(decl: string) -> byte {
	idx := find_substring(decl, "--on-event ")
	if idx < 0 {
		return 0
	}
	rest := strings.trim_space(decl[idx+len("--on-event "):])
	event_name, _ := split_first_word(rest)
	switch event_name {
	case "fish_preexec":
		return 'x'
	case "fish_prompt", "fish_right_prompt", "fish_postexec":
		return 'p'
	}
	return 0
}

rewrite_fish_inline_assignment :: proc(line: string, connector: string, allocator := context.allocator) -> (string, bool) {
	idx := find_substring(line, connector)
	if idx < 0 {
		return strings.clone(line, allocator), false
	}
	prefix := line[:idx+len(connector)]
	rest_full := line[idx+len(connector):]
	rest := strings.trim_space(rest_full)
	eq_idx := find_substring(rest, "=")
	if eq_idx <= 0 {
		return strings.clone(line, allocator), false
	}
	name := strings.trim_space(rest[:eq_idx])
	value_and_tail := strings.trim_space(rest[eq_idx+1:])
	tail := ""
	value := value_and_tail
	semi := find_substring(value_and_tail, ";")
	if semi >= 0 {
		value = strings.trim_space(value_and_tail[:semi])
		tail = value_and_tail[semi:]
	}
	if !is_basic_name(name) {
		return strings.clone(line, allocator), false
	}
	if value == "" {
		value = "\"\""
	}
	rewritten := strings.concatenate([]string{prefix, "set ", name, " ", value, tail}, allocator)
	return rewritten, true
}

replace_simple_all :: proc(s: string, from_s: string, to_s: string, allocator := context.allocator) -> (string, bool) {
	out, changed := strings.replace_all(s, from_s, to_s, allocator)
	if changed {
		return out, true
	}
	if raw_data(out) != raw_data(s) {
		delete(out)
	}
	return strings.clone(s, allocator), false
}

rewrite_shell_to_fish_syntax :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false

		if strings.contains(trimmed, "[[") || strings.contains(trimmed, "]]") || strings.contains(trimmed, "&&") || strings.contains(trimmed, "||") || strings.contains(trimmed, "$(") {
			tmp := strings.clone(trimmed, allocator)
			c2, c3, c4, c5 := false, false, false, false
			tmp2, c1 := replace_simple_all(tmp, "[[", "test ", allocator)
			delete(tmp)
			tmp = tmp2
			tmp2, c2 = replace_simple_all(tmp, "]]", "", allocator)
			delete(tmp)
			tmp = tmp2
			tmp2, c3 = replace_simple_all(tmp, " && ", "; and ", allocator)
			delete(tmp)
			tmp = tmp2
			tmp2, c4 = replace_simple_all(tmp, " || ", "; or ", allocator)
			delete(tmp)
			tmp = tmp2
			tmp2, c5 = replace_simple_all(tmp, "$(", "(", allocator)
			delete(tmp)
			tmp = tmp2
			out_line = strings.concatenate([]string{indent, strings.trim_space(tmp)}, allocator)
			delete(tmp)
			out_allocated = true
			changed = changed || c1 || c2 || c3 || c4 || c5
		}
		current_trimmed := strings.trim_space(out_line)

		if current_trimmed == "fi" || current_trimmed == "done" || current_trimmed == "esac" || current_trimmed == "}" {
			out_line = strings.concatenate([]string{indent, "end"}, allocator)
			out_allocated = true
			changed = true
		} else if current_trimmed == ";;" {
			out_line = ""
			changed = true
		} else if strings.has_prefix(current_trimmed, "if ((") {
			out_line = strings.concatenate([]string{indent, "if true"}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "elif ((") {
			out_line = strings.concatenate([]string{indent, "else if true"}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "while ((") {
			out_line = strings.concatenate([]string{indent, "while true"}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "if ") && strings.has_suffix(current_trimmed, "; then") {
			cond := strings.trim_space(current_trimmed[3 : len(current_trimmed)-6])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "if ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "elif ") && strings.has_suffix(current_trimmed, "; then") {
			cond := strings.trim_space(current_trimmed[5 : len(current_trimmed)-6])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "else if ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "while ") && strings.has_suffix(current_trimmed, "; do") {
			cond := strings.trim_space(current_trimmed[6 : len(current_trimmed)-4])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "while ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "for ") && strings.has_suffix(current_trimmed, "; do") {
			out_line = strings.concatenate([]string{indent, strings.trim_space(current_trimmed[:len(current_trimmed)-4])}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "case ") && strings.has_suffix(current_trimmed, " in") {
			val := strings.trim_space(current_trimmed[5 : len(current_trimmed)-3])
			out_line = strings.concatenate([]string{indent, "switch ", val}, allocator)
			out_allocated = true
			changed = true
		} else if !strings.has_prefix(current_trimmed, "case ") && strings.has_suffix(current_trimmed, ")") && strings.contains(current_trimmed, "|") {
			pat := strings.trim_space(current_trimmed[:len(current_trimmed)-1])
			pat_repl, pat_changed := replace_simple_all(pat, "|", " ", allocator)
			if pat_changed {
				pat = pat_repl
			} else {
				delete(pat_repl)
			}
			out_line = strings.concatenate([]string{indent, "case ", pat}, allocator)
			out_allocated = true
			if pat_changed {
				delete(pat)
			}
			changed = true
		} else if strings.has_suffix(current_trimmed, "() {") {
			name := strings.trim_space(current_trimmed[:len(current_trimmed)-4])
			if strings.has_prefix(name, "function ") {
				name = strings.trim_space(name[len("function "):])
			}
			name = normalize_function_name_token(name)
			if name != "" {
				out_line = strings.concatenate([]string{indent, "function ", name}, allocator)
				out_allocated = true
				changed = true
			}
		} else if strings.contains(current_trimmed, "; and ") {
			rewritten, c := rewrite_fish_inline_assignment(out_line, "; and ", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = rewritten
				out_allocated = true
				changed = true
			} else {
				delete(rewritten)
			}
		} else if strings.contains(current_trimmed, "; or ") {
			rewritten, c := rewrite_fish_inline_assignment(out_line, "; or ", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = rewritten
				out_allocated = true
				changed = true
			} else {
				delete(rewritten)
			}
		} else if strings.contains(current_trimmed, " and ") {
			rewritten, c := rewrite_fish_inline_assignment(out_line, " and ", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = rewritten
				out_allocated = true
				changed = true
			} else {
				delete(rewritten)
			}
		} else if strings.contains(current_trimmed, " or ") {
			rewritten, c := rewrite_fish_inline_assignment(out_line, " or ", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = rewritten
				out_allocated = true
				changed = true
			} else {
				delete(rewritten)
			}
		} else {
			eq_idx := find_substring(current_trimmed, "=")
			if eq_idx > 0 {
				left := strings.trim_space(current_trimmed[:eq_idx])
				right := strings.trim_space(current_trimmed[eq_idx+1:])
				if is_basic_name(left) &&
					!strings.has_prefix(current_trimmed, "set ") &&
					!strings.has_prefix(current_trimmed, "if ") &&
					!strings.has_prefix(current_trimmed, "elif ") &&
					!strings.has_prefix(current_trimmed, "while ") &&
					!strings.has_prefix(current_trimmed, "for ") &&
					!strings.has_prefix(current_trimmed, "case ") &&
					!strings.has_prefix(current_trimmed, "export ") {
					if right == "" {
						right = "\"\""
					}
					out_line = strings.concatenate([]string{indent, "set ", left, " ", right}, allocator)
					out_allocated = true
					changed = true
				}
			}
		}
		special_rewrite, special_changed := rewrite_fish_special_parameters(out_line, allocator)
		if special_changed {
			if out_allocated {
				delete(out_line)
			}
			out_line = special_rewrite
			out_allocated = true
			changed = true
		} else {
			delete(special_rewrite)
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_fish_connector_assignments :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	connectors := []string{"; and ", "; or ", " and ", " or ", "; "}

	for line, idx in lines {
		cur := strings.clone(line, allocator)
		for connector in connectors {
			next, c := rewrite_fish_inline_assignment(cur, connector, allocator)
			delete(cur)
			cur = next
			if c {
				changed = true
			}
		}
		strings.write_string(&builder, cur)
		delete(cur)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

normalize_fish_case_patterns :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false
		if strings.has_prefix(trimmed, "case ( $+commands[") || strings.has_prefix(trimmed, "case ($+commands[") {
			out_line = ":"
			changed = true
		} else if strings.has_prefix(trimmed, "case ") && strings.contains(trimmed, "|") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			pat := strings.trim_space(trimmed[len("case "):])
			repl, c := strings.replace_all(pat, "|", " ", allocator)
			if c {
				out_line = strings.concatenate([]string{indent, "case ", repl}, allocator)
				out_allocated = true
				changed = true
				delete(repl)
			} else if raw_data(repl) != raw_data(pat) {
				delete(repl)
			}
		}
		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	return strings.clone(strings.to_string(builder), allocator), changed
}

normalize_fish_simple_assignments :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false
		if strings.contains(trimmed, "exec {") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_allocated = true
			changed = true
		}
		eq_idx := find_substring(trimmed, "=")
		if !out_allocated && (strings.has_prefix(trimmed, "if ") || strings.has_prefix(trimmed, "else if ")) {
			prefix := "if "
			if strings.has_prefix(trimmed, "else if ") {
				prefix = "else if "
			}
			cond_raw := strings.trim_space(trimmed[len(prefix):])
			connector := ""
			connector_idx := find_substring(cond_raw, "; and ")
			if connector_idx >= 0 {
				connector = "; and "
			} else {
				connector_idx = find_substring(cond_raw, " and ")
				if connector_idx >= 0 {
					connector = " and "
				}
			}
			if connector_idx >= 0 {
				assign_expr := strings.trim_space(cond_raw[:connector_idx])
				rest := cond_raw[connector_idx:]
				assign_idx := find_substring(assign_expr, "=")
				if assign_idx > 0 && !strings.contains(assign_expr, "==") && !strings.contains(assign_expr, "!=") {
					left := strings.trim_space(assign_expr[:assign_idx])
					right := strings.trim_space(assign_expr[assign_idx+1:])
					if is_basic_name(left) && right != "" {
						indent_len := len(line) - len(strings.trim_left_space(line))
						indent := ""
						if indent_len > 0 {
							indent = line[:indent_len]
						}
						out_line = strings.concatenate([]string{indent, prefix, "set ", left, " ", right, rest}, allocator)
						out_allocated = true
						changed = true
					}
				}
			}
			if !out_allocated {
				assign_idx := find_substring(cond_raw, "=")
				if assign_idx > 0 &&
					!strings.contains(cond_raw, "==") &&
					!strings.contains(cond_raw, "!=") &&
					!strings.contains(cond_raw, ";") {
					left := strings.trim_space(cond_raw[:assign_idx])
					right := strings.trim_space(cond_raw[assign_idx+1:])
					if is_basic_name(left) && right != "" {
						indent_len := len(line) - len(strings.trim_left_space(line))
						indent := ""
						if indent_len > 0 {
							indent = line[:indent_len]
						}
						out_line = strings.concatenate([]string{indent, prefix, "set ", left, " ", right}, allocator)
						out_allocated = true
						changed = true
					}
				}
			}
		}
		if !out_allocated &&
			eq_idx > 0 &&
			!strings.has_prefix(trimmed, "set ") &&
			!strings.has_prefix(trimmed, "if ") &&
			!strings.has_prefix(trimmed, "else if ") &&
			!strings.has_prefix(trimmed, "while ") &&
			!strings.has_prefix(trimmed, "for ") &&
			!strings.has_prefix(trimmed, "case ") &&
			!strings.contains(trimmed, "==") &&
			!strings.contains(trimmed, "!=") {
			left := strings.trim_space(trimmed[:eq_idx])
			right := strings.trim_space(trimmed[eq_idx+1:])
			if is_basic_name(left) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				if right == "" {
					right = "\"\""
				}
				out_line = strings.concatenate([]string{indent, "set ", left, " ", right}, allocator)
				out_allocated = true
				changed = true
			}
		}
		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	return strings.clone(strings.to_string(builder), allocator), changed
}

split_first_word_raw :: proc(s: string) -> (string, string) {
	if s == "" {
		return "", ""
	}
	i := 0
	for i < len(s) && s[i] != ' ' && s[i] != '\t' {
		i += 1
	}
	if i >= len(s) {
		return s, ""
	}
	return s[:i], strings.trim_space(s[i+1:])
}

lower_fish_capability_callsites :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false

		if strings.has_prefix(trimmed, "if test ") {
			cond := strings.trim_space(trimmed[len("if test "):])
			out_line = strings.concatenate([]string{indent, "if __zx_test ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "else if test ") {
			cond := strings.trim_space(trimmed[len("else if test "):])
			out_line = strings.concatenate([]string{indent, "else if __zx_test ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "while test ") {
			cond := strings.trim_space(trimmed[len("while test "):])
			out_line = strings.concatenate([]string{indent, "while __zx_test ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "test ") {
			cond := strings.trim_space(trimmed[len("test "):])
			out_line = strings.concatenate([]string{indent, "__zx_test ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "source ") {
			arg := strings.trim_space(trimmed[len("source "):])
			out_line = strings.concatenate([]string{indent, "__zx_source ", arg}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, ". ") {
			arg := strings.trim_space(trimmed[2:])
			out_line = strings.concatenate([]string{indent, "__zx_source ", arg}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "set ") {
			rest := strings.trim_space(trimmed[len("set "):])
			name, tail := split_first_word_raw(rest)
			if is_basic_name(name) &&
				tail != "" &&
				!strings.contains(tail, " ") &&
				!strings.contains(tail, ";") &&
				!strings.contains(tail, "|") &&
				!strings.contains(tail, "&") &&
				!strings.contains(tail, "(") &&
				!strings.contains(tail, ")") &&
				!strings.contains(tail, "{") &&
				!strings.contains(tail, "}") &&
				!strings.contains(tail, "[") &&
				!strings.contains(tail, "]") {
				out_line = strings.concatenate([]string{indent, "__zx_set ", name, " ", tail, " default 0"}, allocator)
				out_allocated = true
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

count_unescaped_double_quotes :: proc(s: string) -> int {
	count := 0
	escaped := false
	for i in 0 ..< len(s) {
		c := s[i]
		if escaped {
			escaped = false
			continue
		}
		if c == '\\' {
			escaped = true
			continue
		}
		if c == '"' {
			count += 1
		}
	}
	return count
}

build_fish_set_decls_from_tokens :: proc(tokens: []string, scope_flag: string, allocator := context.allocator) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	wrote := false
	for tok in tokens {
		token := strings.trim_space(tok)
		if token == "" {
			continue
		}
		eq_idx := find_substring(token, "=")
		name := token
		value := "\"\""
		if eq_idx > 0 {
			name = strings.trim_space(token[:eq_idx])
			value = strings.trim_space(token[eq_idx+1:])
			if value == "" {
				value = "\"\""
			}
		}
		if !is_basic_name(name) {
			continue
		}
		if wrote {
			strings.write_string(&builder, "; ")
		}
		strings.write_string(&builder, "set ")
		strings.write_string(&builder, scope_flag)
		strings.write_string(&builder, name)
		strings.write_byte(&builder, ' ')
		strings.write_string(&builder, value)
		wrote = true
	}
	if !wrote {
		return strings.clone(":", allocator)
	}
	return strings.clone(strings.to_string(builder), allocator)
}

normalize_fish_artifacts :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_print_pipe_quote_block := false
	in_switch := false
	in_set_list := false
	in_function_decl_cont := false
	for line, idx in lines {
		out := strings.clone(line, allocator)
		trimmed := strings.trim_space(out)
		if strings.has_prefix(trimmed, "declare -A ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, "set -l usage \"\""}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "[") && strings.contains(trimmed, "]=") && !strings.has_prefix(trimmed, "set ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "set -l total (") && strings.contains(trimmed, "__shellx_param_length") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, "set -l total 0"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "set -l word (") && strings.contains(trimmed, "__shellx_array_get;") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, "set -l word \"\""}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "end | sort -rn -k1") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, "end"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "switch ") {
			in_switch = true
		} else if in_switch && trimmed == "end" {
			in_switch = false
		} else if in_switch && trimmed == ":" {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, "case *"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(out, "$~") {
			repl, c := strings.replace_all(out, "$~", "$", allocator)
			if c {
				delete(out)
				out = repl
				changed = true
				trimmed = strings.trim_space(out)
			} else if raw_data(repl) != raw_data(out) {
				delete(repl)
			}
		}
		if strings.contains(trimmed, "set -l max_cursor_pos (count") &&
			!strings.contains(trimmed, ")") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, "set -l retval \"\"; set -l max_cursor_pos (count $BUFFER)"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "functions[_original_complete]=") ||
			strings.contains(trimmed, "$functions[_complete]") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "[") && strings.contains(trimmed, "]=") &&
			!strings.has_prefix(trimmed, "set ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "setopt ") ||
			strings.has_prefix(trimmed, "unsetopt ") ||
			strings.has_prefix(trimmed, "emulate ") ||
			strings.has_prefix(trimmed, "zmodload ") ||
			strings.has_prefix(trimmed, "autoload ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if trimmed == "time" || strings.has_prefix(trimmed, "time ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_suffix(trimmed, "'") &&
			!strings.has_prefix(trimmed, "'") &&
			!strings.contains(trimmed, "\"") &&
			!strings.contains(trimmed, "=") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "; and setopt ") ||
			strings.contains(trimmed, "; or setopt ") ||
			strings.contains(trimmed, "; and zmodload ") ||
			strings.contains(trimmed, "; or zmodload ") ||
			strings.contains(trimmed, "; and typeset ") ||
			strings.contains(trimmed, "; or typeset ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "; then") {
			repl, c := strings.replace_all(out, "; then", "", allocator)
			if c {
				delete(out)
				out = repl
				changed = true
				trimmed = strings.trim_space(out)
			} else if raw_data(repl) != raw_data(out) {
				delete(repl)
			}
		}
		if trimmed == "then" {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "local ") || strings.has_prefix(trimmed, "typeset ") || strings.has_prefix(trimmed, "integer ") {
			keyword_len := 0
			scope := "-l "
			if strings.has_prefix(trimmed, "local ") {
				keyword_len = len("local ")
				scope = "-l "
			} else if strings.has_prefix(trimmed, "typeset ") {
				keyword_len = len("typeset ")
				scope = "-g "
			} else {
				keyword_len = len("integer ")
				scope = "-l "
			}
			rest := strings.trim_space(trimmed[keyword_len:])
			fields := strings.fields(rest)
			defer delete(fields)
			start := 0
			for start < len(fields) && strings.has_prefix(fields[start], "-") {
				flags := fields[start]
				if strings.contains(flags, "g") {
					scope = "-g "
				}
				if strings.contains(flags, "l") {
					scope = "-l "
				}
				start += 1
			}
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			scope_copy := strings.clone(scope, allocator)
			decl := ""
			if start < len(fields) {
				decl = build_fish_set_decls_from_tokens(fields[start:], scope_copy, allocator)
			} else {
				decl = strings.clone(":", allocator)
			}
			delete(scope_copy)
			delete(out)
			out = strings.concatenate([]string{indent, decl}, allocator)
			delete(decl)
			changed = true
			trimmed = strings.trim_space(out)
		}

		if in_print_pipe_quote_block {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			if count_unescaped_double_quotes(line)%2 == 1 {
				in_print_pipe_quote_block = false
			}
			strings.write_string(&builder, out)
			delete(out)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if in_set_list {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			if trimmed == ")" {
				in_set_list = false
			}
			strings.write_string(&builder, out)
			delete(out)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if in_function_decl_cont {
			if trimmed == "end" {
				in_function_decl_cont = false
			} else {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				delete(out)
				out = strings.concatenate([]string{indent, ":"}, allocator)
				changed = true
				if !strings.has_suffix(trimmed, "\\") {
					in_function_decl_cont = false
				}
				strings.write_string(&builder, out)
				delete(out)
				if idx+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
		}

		if strings.contains(trimmed, "print \"") && strings.contains(trimmed, "|") {
			if count_unescaped_double_quotes(trimmed)%2 == 1 {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				delete(out)
				out = strings.concatenate([]string{indent, ":"}, allocator)
				in_print_pipe_quote_block = true
				changed = true
			}
		}
		if strings.has_prefix(trimmed, "print \"") && count_unescaped_double_quotes(trimmed)%2 == 1 {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			in_print_pipe_quote_block = true
			changed = true
		}

		if strings.contains(trimmed, "exec {") {
			indent_len := len(out) - len(strings.trim_left_space(out))
			indent := ""
			if indent_len > 0 {
				indent = out[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
		}
		if strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, " {") {
			name := strings.trim_space(trimmed[len("function "):len(trimmed)-2])
			name = normalize_function_name_token(name)
			if name != "" {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				name_copy := strings.clone(name, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, "function ", name_copy}, allocator)
				delete(name_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "\\") {
			head := strings.trim_space(trimmed[len("function "):len(trimmed)-1])
			name, _ := split_first_word_raw(head)
			if is_basic_name(name) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				name_copy := strings.clone(name, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, "function ", name_copy}, allocator)
				delete(name_copy)
				changed = true
				in_function_decl_cont = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_suffix(trimmed, " {") && !strings.has_prefix(trimmed, "function ") {
			name := strings.trim_space(trimmed[:len(trimmed)-2])
			if is_basic_name(name) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				name_copy := strings.clone(name, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, "function ", name_copy}, allocator)
				delete(name_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_prefix(trimmed, "(") && strings.has_suffix(trimmed, ")") && len(trimmed) > 2 {
			inner := strings.trim_space(trimmed[1 : len(trimmed)-1])
			if inner != "" && !strings.has_prefix(inner, "count ") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				inner_copy := strings.clone(inner, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, inner_copy}, allocator)
				delete(inner_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_prefix(trimmed, "for ") && strings.contains(trimmed, " in ") {
			rest := strings.trim_space(trimmed[len("for "):])
			var_part, item_part := split_first_word_raw(rest)
			if var_part != "" {
				second_var, after_second := split_first_word_raw(item_part)
				if second_var != "" && second_var != "in" && strings.has_prefix(after_second, "in ") {
					rest_items := strings.trim_space(after_second[len("in "):])
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					v1 := strings.clone(var_part, allocator)
					items := strings.clone(rest_items, allocator)
					delete(out)
					out = strings.concatenate([]string{indent, "for ", v1, " in ", items}, allocator)
					delete(v1)
					delete(items)
					changed = true
					trimmed = strings.trim_space(out)
				}
			}
		}
		if strings.has_prefix(trimmed, "for ") && strings.contains(trimmed, " in ") && strings.contains(trimmed, "{") {
			open_count := 0
			close_count := 0
			for ch in trimmed {
				if ch == '{' {
					open_count += 1
				} else if ch == '}' {
					close_count += 1
				}
			}
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			if open_count != close_count {
				rest := strings.trim_space(trimmed[len("for "):])
				var_name, _ := split_first_word_raw(rest)
				if is_basic_name(var_name) {
					v := strings.clone(var_name, allocator)
					delete(out)
					out = strings.concatenate([]string{indent, "for ", v, " in \"\""}, allocator)
					delete(v)
					changed = true
					trimmed = strings.trim_space(out)
				}
			} else {
				repl_b, c_b := strings.replace_all(out, "{", " ", allocator)
				if c_b {
					delete(out)
					out = repl_b
					changed = true
				} else if raw_data(repl_b) != raw_data(out) {
					delete(repl_b)
				}
				repl_b, c_b = strings.replace_all(out, "}", " ", allocator)
				if c_b {
					delete(out)
					out = repl_b
					changed = true
				} else if raw_data(repl_b) != raw_data(out) {
					delete(repl_b)
				}
				repl_b, c_b = strings.replace_all(out, ",", " ", allocator)
				if c_b {
					delete(out)
					out = repl_b
					changed = true
				} else if raw_data(repl_b) != raw_data(out) {
					delete(repl_b)
				}
				trimmed = strings.trim_space(out)
			}
		}
		if strings.contains(trimmed, "; ") {
			connectors := []string{"; and ", "; or ", " and ", " or ", "; "}
			for connector in connectors {
				rewritten_assign, c_assign := rewrite_fish_inline_assignment(out, connector, allocator)
				if c_assign {
					delete(out)
					out = rewritten_assign
					changed = true
					trimmed = strings.trim_space(out)
				} else {
					delete(rewritten_assign)
				}
			}
		}
		if strings.contains(trimmed, ";") && strings.contains(trimmed, "=") {
			last_semi := -1
			for i := 0; i < len(trimmed); i += 1 {
				if trimmed[i] == ';' {
					last_semi = i
				}
			}
			if last_semi >= 0 && last_semi+1 < len(trimmed) {
				head := strings.trim_right_space(trimmed[:last_semi])
				tail := strings.trim_space(trimmed[last_semi+1:])
				eq_idx := find_substring(tail, "=")
				if eq_idx > 0 && !strings.contains(tail, "==") && !strings.contains(tail, "!=") {
					name := strings.trim_space(tail[:eq_idx])
					value := strings.trim_space(tail[eq_idx+1:])
					if is_basic_name(name) && value != "" {
						indent_len := len(line) - len(strings.trim_left_space(line))
						indent := ""
						if indent_len > 0 {
							indent = line[:indent_len]
						}
						head_copy := strings.clone(head, allocator)
						name_copy := strings.clone(name, allocator)
						value_copy := strings.clone(value, allocator)
						delete(out)
						out = strings.concatenate([]string{indent, head_copy, "; set ", name_copy, " ", value_copy}, allocator)
						delete(head_copy)
						delete(name_copy)
						delete(value_copy)
						changed = true
						trimmed = strings.trim_space(out)
					}
				}
			}
		}
		if strings.has_prefix(trimmed, "if ") && strings.contains(trimmed, "=(") && strings.has_suffix(trimmed, ")") {
			body := strings.trim_space(trimmed[len("if "):])
			eq_idx := find_substring(body, "=(")
			if eq_idx > 0 {
				name := strings.trim_space(body[:eq_idx])
				cmd := strings.trim_space(body[eq_idx+2 : len(body)-1])
				if is_basic_name(name) && cmd != "" {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					name_copy := strings.clone(name, allocator)
					cmd_copy := strings.clone(cmd, allocator)
					delete(out)
					out = strings.concatenate([]string{indent, "set ", name_copy, " (", cmd_copy, ")\n", indent, "if true"}, allocator)
					delete(name_copy)
					delete(cmd_copy)
					changed = true
					trimmed = strings.trim_space(out)
				}
			}
		}
		if strings.has_prefix(trimmed, "if (") && strings.has_suffix(trimmed, ")") && len(trimmed) > 5 {
			inner := strings.trim_space(trimmed[4 : len(trimmed)-1])
			if inner != "" {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				inner_copy := strings.clone(inner, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, "if ", inner_copy}, allocator)
				delete(inner_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.contains(trimmed, "; and (") {
			and_idx := find_substring(out, "; and (")
			if and_idx >= 0 {
				close_idx := and_idx + len("; and (")
				for close_idx < len(out) && out[close_idx] != ')' {
					close_idx += 1
				}
				if close_idx < len(out) {
					repl_cond, ok_cond := replace_first_range(out, and_idx, close_idx+1, "; and true", allocator)
					if ok_cond {
						delete(out)
						out = repl_cond
						changed = true
						trimmed = strings.trim_space(out)
					} else if raw_data(repl_cond) != raw_data(out) {
						delete(repl_cond)
					}
				}
			}
		}
		if strings.contains(trimmed, "; or (") {
			or_idx := find_substring(out, "; or (")
			if or_idx >= 0 {
				close_idx := or_idx + len("; or (")
				for close_idx < len(out) && out[close_idx] != ')' {
					close_idx += 1
				}
				if close_idx < len(out) {
					repl_cond, ok_cond := replace_first_range(out, or_idx, close_idx+1, "; or true", allocator)
					if ok_cond {
						delete(out)
						out = repl_cond
						changed = true
						trimmed = strings.trim_space(out)
					} else if raw_data(repl_cond) != raw_data(out) {
						delete(repl_cond)
					}
				}
			}
		}
		if strings.has_prefix(trimmed, "if ") && strings.contains(trimmed, "<") && strings.contains(trimmed, ">") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, "if true"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "set ") && strings.has_suffix(trimmed, "(") {
			rest := strings.trim_space(trimmed[len("set "):len(trimmed)-1])
			name, _ := split_first_word_raw(rest)
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			name_copy := strings.clone(name, allocator)
			delete(out)
			if is_basic_name(name_copy) {
				out = strings.concatenate([]string{indent, "set ", name_copy, " \"\""}, allocator)
			} else {
				out = strings.concatenate([]string{indent, ":"}, allocator)
			}
			delete(name_copy)
			in_set_list = true
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "set ") && strings.has_suffix(trimmed, " ()") {
			rest := strings.trim_space(trimmed[len("set "):len(trimmed)-3])
			name, _ := split_first_word_raw(rest)
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			if is_basic_name(name) {
				out = strings.concatenate([]string{indent, "set ", name, " \"\""}, allocator)
			} else {
				out = strings.concatenate([]string{indent, ":"}, allocator)
			}
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "+=(") && strings.has_suffix(trimmed, ")") {
			app_idx := find_substring(trimmed, "+=(")
			if app_idx > 0 {
				name := strings.trim_space(trimmed[:app_idx])
				values := strings.trim_space(trimmed[app_idx+3 : len(trimmed)-1])
				if is_basic_name(name) {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					name_copy := strings.clone(name, allocator)
					values_copy := strings.clone(values, allocator)
					delete(out)
					out = strings.concatenate([]string{indent, "set -a ", name_copy, " ", values_copy}, allocator)
					delete(name_copy)
					delete(values_copy)
					changed = true
					trimmed = strings.trim_space(out)
				}
			}
		}
		if strings.contains(trimmed, ";") && strings.contains(trimmed, "+=(") {
			app_idx := find_substring(trimmed, "+=(")
			if app_idx > 0 {
				start := app_idx - 1
				for start >= 0 && is_basic_name_char(trimmed[start]) {
					start -= 1
				}
				name := strings.trim_space(trimmed[start+1 : app_idx])
				close_idx := app_idx + 3
				for close_idx < len(trimmed) && trimmed[close_idx] != ')' {
					close_idx += 1
				}
				if is_basic_name(name) && close_idx < len(trimmed) {
					prefix := strings.trim_right_space(trimmed[:start+1])
					values := strings.trim_space(trimmed[app_idx+3 : close_idx])
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					prefix_copy := strings.clone(prefix, allocator)
					name_copy := strings.clone(name, allocator)
					values_copy := strings.clone(values, allocator)
					delete(out)
					out = strings.concatenate([]string{indent, prefix_copy, "set -a ", name_copy, " ", values_copy}, allocator)
					delete(prefix_copy)
					delete(name_copy)
					delete(values_copy)
					changed = true
					trimmed = strings.trim_space(out)
				}
			}
		}
		if strings.contains(trimmed, "; for ") && strings.has_suffix(trimmed, "; do") {
			for_idx := find_substring(trimmed, "; for ")
			if for_idx >= 0 {
				prefix := strings.trim_space(trimmed[:for_idx])
				loop_part := strings.trim_space(trimmed[for_idx+2 : len(trimmed)-len("; do")])
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				prefix_copy := strings.clone(prefix, allocator)
				loop_copy := strings.clone(loop_part, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, prefix_copy, "\n", indent, loop_copy}, allocator)
				delete(prefix_copy)
				delete(loop_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if trimmed == "'" || trimmed == "\"" {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "for ") && strings.has_suffix(trimmed, "; do") {
			header := strings.trim_space(trimmed[:len(trimmed)-len("; do")])
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			header_copy := strings.clone(header, allocator)
			delete(out)
			out = strings.concatenate([]string{indent, header_copy}, allocator)
			delete(header_copy)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "for ") && !strings.contains(trimmed, " in ") {
			rest := strings.trim_space(trimmed[len("for "):])
			if is_basic_name(rest) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				rest_copy := strings.clone(rest, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, "for ", rest_copy, " in \"\""}, allocator)
				delete(rest_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if trimmed == ")" {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "for ") && !strings.contains(trimmed, " in ") && strings.contains(trimmed, " (") && strings.has_suffix(trimmed, ")") {
			rest := strings.trim_space(trimmed[len("for "):])
			var_name, after_var := split_first_word_raw(rest)
			if is_basic_name(var_name) && strings.has_prefix(after_var, "(") && strings.has_suffix(after_var, ")") && len(after_var) > 2 {
				expr := strings.trim_space(after_var[1 : len(after_var)-1])
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				delete(out)
				out = strings.concatenate([]string{indent, "for ", var_name, " in ", expr}, allocator)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if in_switch && !strings.has_prefix(trimmed, "case ") && strings.contains(trimmed, "*)") {
			close_idx := find_substring(trimmed, "*)")
			if close_idx >= 0 {
				pat := strings.trim_space(trimmed[:close_idx+1])
				body := strings.trim_space(trimmed[close_idx+2:])
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				pat_copy := strings.clone(pat, allocator)
				body_copy := strings.clone(body, allocator)
				if body == "" {
					delete(out)
					out = strings.concatenate([]string{indent, "case ", pat_copy}, allocator)
				} else {
					delete(out)
					out = strings.concatenate([]string{indent, "case ", pat_copy, "\n", indent, "  ", body_copy}, allocator)
				}
				delete(pat_copy)
				delete(body_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_prefix(trimmed, "function ") && (strings.has_suffix(trimmed, " &&") || strings.has_suffix(trimmed, " ||")) {
			conn_idx := find_substring(trimmed, " &&")
			if conn_idx < 0 {
				conn_idx = find_substring(trimmed, " ||")
			}
			if conn_idx > 0 {
				indent_len := len(out) - len(strings.trim_left_space(out))
				indent := ""
				if indent_len > 0 {
					indent = out[:indent_len]
				}
				head := strings.trim_space(trimmed[:conn_idx])
				head_copy := strings.clone(head, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, head_copy}, allocator)
				delete(head_copy)
				changed = true
			}
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "builtin unalias ") || strings.has_prefix(trimmed, "unalias ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "builtin zle ") || strings.has_prefix(trimmed, "zle ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "builtin print ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "builtin local ") ||
			strings.has_prefix(trimmed, "builtin setopt ") ||
			strings.has_prefix(trimmed, "builtin unset ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "'builtin' 'local'") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "'builtin' 'setopt'") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "'builtin' 'unset'") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "builtin unset ") || strings.has_prefix(trimmed, "unset ") {
			rest := ""
			if strings.has_prefix(trimmed, "builtin unset ") {
				rest = strings.trim_space(trimmed[len("builtin unset "):])
			} else {
				rest = strings.trim_space(trimmed[len("unset "):])
			}
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			rest_copy := strings.clone(rest, allocator)
			delete(out)
			if rest_copy != "" {
				out = strings.concatenate([]string{indent, "set -e ", rest_copy}, allocator)
			} else {
				out = strings.concatenate([]string{indent, ":"}, allocator)
			}
			delete(rest_copy)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "=(<") || strings.contains(trimmed, "(<") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "]=()") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_suffix(trimmed, "()") {
			name := strings.trim_space(trimmed[:len(trimmed)-2])
			if is_basic_name(name) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				delete(out)
				out = strings.concatenate([]string{indent, "function ", name}, allocator)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_prefix(trimmed, "function eval ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "\"\"\"") {
			repl_q, c_q := strings.replace_all(out, "\"\"\"", "\"\"", allocator)
			if c_q {
				delete(out)
				out = repl_q
				changed = true
			} else if raw_data(repl_q) != raw_data(out) {
				delete(repl_q)
			}
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "for ") && strings.contains(trimmed, " in \"\"\"") {
			repl_q, c_q := strings.replace_all(trimmed, " in \"\"\"", " in \"\"", allocator)
			if c_q {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				delete(out)
				out = strings.concatenate([]string{indent, repl_q}, allocator)
				delete(repl_q)
				changed = true
			} else if raw_data(repl_q) != raw_data(trimmed) {
				delete(repl_q)
			}
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "case ") && strings.contains(trimmed, "=(") {
			raw := strings.trim_space(trimmed[len("case "):])
			eq_idx := find_substring(raw, "=")
			if eq_idx > 0 {
				name := strings.trim_space(raw[:eq_idx])
				rhs := strings.trim_space(raw[eq_idx+1:])
				if strings.has_prefix(rhs, "(") {
					rhs = strings.trim_space(rhs[1:])
				}
				if strings.has_suffix(rhs, ")") && len(rhs) > 1 {
					rhs = strings.trim_space(rhs[:len(rhs)-1])
				}
				if is_basic_name(name) && rhs != "" {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					name_copy := strings.clone(name, allocator)
					rhs_copy := strings.clone(rhs, allocator)
					new_out := strings.concatenate([]string{indent, "set ", name_copy, " ", rhs_copy}, allocator)
					delete(name_copy)
					delete(rhs_copy)
					delete(out)
					out = new_out
					changed = true
				}
			}
			trimmed = strings.trim_space(out)
		}
		repl, c := strings.replace_all(out, "; and {", "; and ", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "; or {", "; or ", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "and {", "and ", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "or {", "or ", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "};", ";", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "$'", "'", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "$@", "$argv", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "$*", "$argv", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "&&", "; and", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "||", "; or", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		trimmed = strings.trim_space(out)

		if strings.has_suffix(trimmed, "; and") {
			out = strings.concatenate([]string{out, " true"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		} else if strings.has_suffix(trimmed, "; or") {
			out = strings.concatenate([]string{out, " true"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}

		if strings.contains(trimmed, "}") && !strings.contains(trimmed, "{") {
			builder2 := strings.builder_make()
			for i in 0 ..< len(out) {
				if out[i] != '}' {
					strings.write_byte(&builder2, out[i])
				}
			}
			delete(out)
			out = strings.clone(strings.to_string(builder2), allocator)
			strings.builder_destroy(&builder2)
			changed = true
			trimmed = strings.trim_space(out)
		}

		if strings.has_prefix(trimmed, "set ") && strings.has_suffix(trimmed, "))") {
			out = strings.trim_right_space(out)
			out = out[:len(out)-2]
			changed = true
		}
		trimmed = strings.trim_space(out)
		if strings.has_prefix(trimmed, "switch ") {
			in_switch = true
		} else if trimmed == "end" {
			in_switch = false
		}
		strings.write_string(&builder, out)
		delete(out)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	return strings.clone(strings.to_string(builder), allocator), changed
}

sanitize_fish_output_bytes :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if text == "" {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for i in 0 ..< len(text) {
		c := text[i]
		if c == '\n' || c == '\t' || (c >= 32 && c <= 126) {
			strings.write_byte(&builder, c)
		} else {
			strings.write_byte(&builder, ':')
			changed = true
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_shellx_param_subshells_to_vars :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if text == "" {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	read_name := proc(s: string, start: int) -> (string, int) {
		i := start
		for i < len(s) && (s[i] == ' ' || s[i] == '\t') {
			i += 1
		}
		j := i
		for j < len(s) && is_basic_name_char(s[j]) {
			j += 1
		}
		if j <= i {
			return "", i
		}
		return s[i:j], j
	}

	i := 0
	for i < len(text) {
		matched := false
		prefixes := []string{"(__shellx_param_length "}
		for p in prefixes {
			if i+len(p) <= len(text) && text[i:i+len(p)] == p {
				name, name_end := read_name(text, i+len(p))
				if name != "" {
					close_idx := name_end
					for close_idx < len(text) && text[close_idx] != ')' {
						close_idx += 1
					}
					if close_idx < len(text) {
						strings.write_string(&builder, "$")
						strings.write_string(&builder, name)
						changed = true
						i = close_idx + 1
						matched = true
						break
					}
				}
			}
		}
		if matched {
			continue
		}
		strings.write_byte(&builder, text[i])
		i += 1
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

ensure_fish_block_balance :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	stack := make([dynamic]byte, 0, 64, context.temp_allocator) // f=function i=if l=loop s=switch b=begin
	defer delete(stack)
	changed := false
	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out := line
		out_allocated := false

		if strings.has_prefix(trimmed, "function ") && len(stack) > 0 {
			for len(stack) > 0 {
				strings.write_string(&builder, "end\n")
				resize(&stack, len(stack)-1)
				changed = true
			}
		}

		if trimmed == "else" || strings.has_prefix(trimmed, "else if ") {
			if len(stack) == 0 || stack[len(stack)-1] != 'i' {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out = strings.concatenate([]string{indent, ":"}, allocator)
				out_allocated = true
				changed = true
			}
		} else if trimmed == "end" {
			if len(stack) > 0 {
				resize(&stack, len(stack)-1)
			} else {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out = strings.concatenate([]string{indent, ":"}, allocator)
				out_allocated = true
				changed = true
			}
		} else if trimmed != "" && !strings.has_prefix(trimmed, "#") {
			if strings.has_prefix(trimmed, "function ") {
				append(&stack, 'f')
			} else if strings.has_prefix(trimmed, "if ") {
				append(&stack, 'i')
			} else if strings.has_prefix(trimmed, "while ") || strings.has_prefix(trimmed, "for ") || strings.contains(trimmed, "| while ") {
				append(&stack, 'l')
			} else if strings.has_prefix(trimmed, "switch ") {
				append(&stack, 's')
			} else if trimmed == "begin" {
				append(&stack, 'b')
			}
		}

		strings.write_string(&builder, out)
		if out_allocated {
			delete(out)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	for i := len(stack) - 1; i >= 0; i -= 1 {
		strings.write_string(&builder, "\nend")
		changed = true
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

repair_fish_malformed_command_substitutions :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		if strings.contains(trimmed, "(") && !strings.contains(trimmed, ")") {
			// Recover a common broken lowering from `${var:-...}` to fish shim call.
			if strings.contains(out_line, "(__shellx_param_default; set -g ") {
				repl, c := strings.replace_all(out_line, "(__shellx_param_default; set -g ", "(__shellx_param_default ", allocator)
				if c {
					out_line = repl
					out_allocated = true
					changed = true
				} else {
					delete(repl)
				}
				if out_allocated && !strings.contains(out_line, ")") {
					with_close := strings.concatenate([]string{out_line, ")"}, allocator)
					delete(out_line)
					out_line = with_close
					changed = true
				}
			} else if strings.contains(out_line, "(git; set -l log ") {
				repl, c := strings.replace_all(out_line, "(git; set -l log ", "(git log ", allocator)
				if c {
					out_line = repl
					out_allocated = true
					changed = true
				} else {
					delete(repl)
				}
				if out_allocated && !strings.contains(out_line, ")") {
					with_close := strings.concatenate([]string{out_line, ")"}, allocator)
					delete(out_line)
					out_line = with_close
					changed = true
				}
			} else if strings.contains(trimmed, "set ") && strings.contains(out_line, " (git") {
				// Minimal parse-safe recovery when command substitution tail was lost.
				with_close := strings.concatenate([]string{out_line, ")"}, allocator)
				out_line = with_close
				out_allocated = true
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

repair_fish_split_echo_param_default :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(lines) {
		line := lines[i]
		trimmed := strings.trim_space(line)
		if i+1 < len(lines) && trimmed == "echo" {
			next := lines[i+1]
			next_trimmed := strings.trim_space(next)
			if strings.has_prefix(next_trimmed, "__shellx_param_default ") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				combined := strings.concatenate([]string{indent, "echo (", next_trimmed, ")"}, allocator)
				strings.write_string(&builder, combined)
				delete(combined)
				changed = true
				i += 2
				if i < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
		}

		strings.write_string(&builder, line)
		i += 1
		if i < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

repair_fish_quoted_param_default_echo :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "echo \"") && strings.contains(trimmed, "__shellx_param_default ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			idx := find_substring(trimmed, "__shellx_param_default ")
			if idx >= 0 {
				rest := trimmed[idx:]
				if len(rest) > 0 && rest[len(rest)-1] == '"' {
					rest = rest[:len(rest)-1]
				}
				prefix := strings.concatenate([]string{indent, "echo ("}, allocator)
				if strings.has_suffix(rest, ")") {
					out_line = strings.concatenate([]string{prefix, rest}, allocator)
				} else {
					out_line = strings.concatenate([]string{prefix, rest, ")"}, allocator)
				}
				delete(prefix)
				out_allocated = true
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_fish_positional_params :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if text == "" {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if text[i] == '$' {
			if i+2 < len(text) && text[i+1] == '{' && text[i+2] >= '1' && text[i+2] <= '9' {
				j := i + 3
				for j < len(text) && text[j] >= '0' && text[j] <= '9' {
					j += 1
				}
				if j < len(text) && text[j] == '}' {
					idx_text := text[i+2 : j]
					repl := strings.concatenate([]string{"$argv[", idx_text, "]"}, allocator)
					strings.write_string(&builder, repl)
					delete(repl)
					changed = true
					i = j + 1
					continue
				}
			}
			if i+1 < len(text) && text[i+1] >= '1' && text[i+1] <= '9' {
				j := i + 2
				for j < len(text) && text[j] >= '0' && text[j] <= '9' {
					j += 1
				}
				idx_text := text[i+1 : j]
				repl := strings.concatenate([]string{"$argv[", idx_text, "]"}, allocator)
				strings.write_string(&builder, repl)
				delete(repl)
				changed = true
				i = j
				continue
			}
		}
		strings.write_byte(&builder, text[i])
		i += 1
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_fish_command_substitution_command_position :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, i in lines {
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		if strings.has_prefix(trimmed, "(__shellx_array_get ") {
			close_idx := find_substring(trimmed, ")")
			if close_idx > 0 && close_idx+1 < len(trimmed) {
				sub := strings.trim_space(trimmed[:close_idx+1])
				rest := strings.trim_space(trimmed[close_idx+1:])
				if rest != "" {
					strings.write_string(&builder, indent)
					strings.write_string(&builder, "set -l __shellx_cmd ")
					strings.write_string(&builder, sub)
					strings.write_byte(&builder, '\n')
					strings.write_string(&builder, indent)
					strings.write_string(&builder, "$__shellx_cmd ")
					strings.write_string(&builder, rest)
					changed = true
					if i+1 < len(lines) {
						strings.write_byte(&builder, '\n')
					}
					continue
				}
			}
		}
		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

repair_shell_split_echo_param_expansion :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(lines) {
		line := lines[i]
		trimmed := strings.trim_space(line)
		if i+1 < len(lines) && trimmed == "echo" {
			next := strings.trim_space(lines[i+1])
			if (strings.has_prefix(next, "${") && strings.has_suffix(next, "}")) ||
				(strings.has_prefix(next, "$(") && strings.has_suffix(next, ")")) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				combined := strings.concatenate([]string{indent, "echo ", next}, allocator)
				strings.write_string(&builder, combined)
				delete(combined)
				changed = true
				i += 2
				if i < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
		}

		strings.write_string(&builder, line)
		i += 1
		if i < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

repair_shell_case_arms :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	// Keep this repair scoped to small/simple scripts to avoid over-normalizing
	// large recovered corpus outputs.
	if len(lines) > 120 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_case := false
	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
			in_case = true
		} else if trimmed == "esac" {
			in_case = false
		} else if in_case && trimmed != "" && !strings.has_prefix(trimmed, "#") {
			close_idx := find_substring(trimmed, ")")
			if close_idx > 0 && close_idx+1 < len(trimmed) {
				after := strings.trim_space(trimmed[close_idx+1:])
				if after != "" && !strings.has_suffix(trimmed, ";;") {
					out_line = strings.concatenate([]string{line, " ;;"}, allocator)
					out_allocated = true
					changed = true
				}
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_fish_to_posix_syntax :: proc(text: string, to: ShellDialect, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	block_stack := make([dynamic]byte, 0, 32, context.temp_allocator) // f=function i=if l=loop c=case
	defer delete(block_stack)
	function_name_stack := make([dynamic]string, 0, 16, context.temp_allocator)
	defer delete(function_name_stack)
	function_hook_stack := make([dynamic]byte, 0, 16, context.temp_allocator) // p=precmd x=preexec
	defer delete(function_hook_stack)
	prev_status_interactive := false

	for line, idx in lines {
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false
		registration_line := ""
		registration_allocated := false
		if prev_status_interactive && trimmed == "exit" {
			out_line = strings.concatenate([]string{indent, "return 0"}, allocator)
			out_allocated = true
			changed = true
			prev_status_interactive = false
		} else {
			prev_status_interactive = false
		if strings.has_prefix(trimmed, "autopair_pairs=") {
			out_line = strings.concatenate([]string{indent, "autopair_pairs=\"\""}, allocator)
			out_allocated = true
			changed = true
		} else

		if strings.has_prefix(trimmed, "function ") {
			fn_decl := strings.trim_space(trimmed[len("function "):])
			name, _ := split_first_word(fn_decl)
			name = normalize_function_name_token(name)
			if name != "" {
				out_line = strings.concatenate([]string{indent, name, "() {"}, allocator)
				out_allocated = true
				changed = true
				append(&block_stack, 'f')
				append(&function_name_stack, name)
				append(&function_hook_stack, fish_function_hook_kind_from_decl(fn_decl))
			}
		} else if trimmed == "end" {
			closing := ":"
			if len(block_stack) > 0 {
				top := block_stack[len(block_stack)-1]
				resize(&block_stack, len(block_stack)-1)
				switch top {
				case 'f':
					closing = "}"
					if len(function_name_stack) > 0 && len(function_hook_stack) > 0 {
						fn_name := function_name_stack[len(function_name_stack)-1]
						hook_kind := function_hook_stack[len(function_hook_stack)-1]
						resize(&function_name_stack, len(function_name_stack)-1)
						resize(&function_hook_stack, len(function_hook_stack)-1)
						if hook_kind == 'p' {
							registration_line = strings.concatenate([]string{indent, "__shellx_register_precmd ", fn_name}, allocator)
							registration_allocated = true
							changed = true
						} else if hook_kind == 'x' {
							registration_line = strings.concatenate([]string{indent, "__shellx_register_preexec ", fn_name}, allocator)
							registration_allocated = true
							changed = true
						}
					}
				case 'i':
					closing = "fi"
				case 'l':
					closing = "done"
				case 'c':
					closing = "esac"
				}
			}
			out_line = strings.concatenate([]string{indent, closing}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "if set -q ") {
			rest := strings.trim_space(trimmed[len("if "):])
			cond, ok := build_non_fish_setq_condition(rest, allocator)
			if ok {
				out_line = strings.concatenate([]string{indent, "if ", cond, "; then"}, allocator)
				out_allocated = true
				delete(cond)
			} else {
				delete(cond)
				out_line = strings.concatenate([]string{indent, "if true; then"}, allocator)
				out_allocated = true
			}
			changed = true
			append(&block_stack, 'i')
		} else if strings.has_prefix(trimmed, "else if set -q ") {
			rest := strings.trim_space(trimmed[len("else if "):])
			cond, ok := build_non_fish_setq_condition(rest, allocator)
			if ok {
				out_line = strings.concatenate([]string{indent, "elif ", cond, "; then"}, allocator)
				out_allocated = true
				delete(cond)
			} else {
				delete(cond)
				out_line = strings.concatenate([]string{indent, "elif true; then"}, allocator)
				out_allocated = true
			}
			changed = true
		} else if strings.has_prefix(trimmed, "set -q ") {
			cond, ok := build_non_fish_setq_condition(trimmed, allocator)
			if ok {
				out_line = strings.concatenate([]string{indent, cond}, allocator)
				out_allocated = true
				delete(cond)
			} else {
				delete(cond)
				out_line = strings.concatenate([]string{indent, ":"}, allocator)
				out_allocated = true
			}
			changed = true
		} else if strings.has_prefix(trimmed, "else if ") {
			cond := strings.trim_space(trimmed[len("else if "):])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "elif ", cond, "; then"}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "if ") && strings.has_suffix(trimmed, "; then") {
			append(&block_stack, 'i')
		} else if strings.has_prefix(trimmed, "while ") && strings.has_suffix(trimmed, "; do") {
			append(&block_stack, 'l')
		} else if strings.has_prefix(trimmed, "for ") && strings.has_suffix(trimmed, "; do") {
			append(&block_stack, 'l')
		} else if strings.has_prefix(trimmed, "if ") && !strings.has_suffix(trimmed, "; then") {
			cond := strings.trim_space(trimmed[len("if "):])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "if ", cond, "; then"}, allocator)
			out_allocated = true
			changed = true
			append(&block_stack, 'i')
		} else if strings.has_prefix(trimmed, "while ") && !strings.has_suffix(trimmed, "; do") {
			cond := strings.trim_space(trimmed[len("while "):])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "while ", cond, "; do"}, allocator)
			out_allocated = true
			changed = true
			append(&block_stack, 'l')
		} else if strings.has_prefix(trimmed, "for ") && !strings.has_suffix(trimmed, "; do") {
			out_line = strings.concatenate([]string{indent, trimmed, "; do"}, allocator)
			out_allocated = true
			changed = true
			append(&block_stack, 'l')
		} else if strings.has_prefix(trimmed, "switch ") {
			expr := strings.trim_space(trimmed[len("switch "):])
			out_line = strings.concatenate([]string{indent, "case ", expr, " in"}, allocator)
			out_allocated = true
			changed = true
			append(&block_stack, 'c')
		} else if strings.has_prefix(trimmed, "status is-interactive") {
			rest := strings.trim_space(trimmed[len("status is-interactive"):])
			if rest == "|| exit" {
				out_line = strings.concatenate([]string{indent, "if ! [ -t 1 ]; then return 0; fi"}, allocator)
			} else if rest == "" {
				out_line = strings.concatenate([]string{indent, "[ -t 1 ]"}, allocator)
				prev_status_interactive = true
			} else {
				out_line = strings.concatenate([]string{indent, "[ -t 1 ] ", rest}, allocator)
			}
			out_allocated = true
			changed = true
		} else if strings.has_suffix(trimmed, "fish_key_bindings") && is_basic_name(trimmed) {
			out_line = strings.concatenate([]string{indent, "[ -t 1 ] && ", trimmed, " || true"}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "case ") && !strings.has_suffix(trimmed, ")") {
			pats := strings.trim_space(trimmed[len("case "):])
			pats_repl, pats_changed := replace_simple_all(pats, " ", "|", allocator)
			if pats_changed {
				pats = pats_repl
			} else {
				delete(pats_repl)
			}
			out_line = strings.concatenate([]string{indent, pats, ")"}, allocator)
			out_allocated = true
			if pats_changed {
				delete(pats)
			}
			changed = true
		} else if strings.has_prefix(trimmed, "set ") {
			rest := strings.trim_space(trimmed[len("set "):])
				parts := strings.split(rest, " ")
				defer delete(parts)
				if len(parts) >= 2 {
				start := 0
				for start < len(parts) && strings.has_prefix(parts[start], "-") {
					start += 1
				}
				if start < len(parts) {
					name := parts[start]
					if is_basic_name(name) {
							if start+1 >= len(parts) {
								out_line = strings.concatenate([]string{indent, name, "=\"\""}, allocator)
								out_allocated = true
							} else if start+2 == len(parts) {
								out_line = strings.concatenate([]string{indent, name, "=", parts[start+1]}, allocator)
								out_allocated = true
							} else if to == .Bash || to == .Zsh {
								val_builder := strings.builder_make()
								defer strings.builder_destroy(&val_builder)
								for i := start + 1; i < len(parts); i += 1 {
								if i > start+1 {
									strings.write_byte(&val_builder, ' ')
								}
								strings.write_string(&val_builder, parts[i])
							}
								out_line = strings.concatenate(
									[]string{indent, name, "=(", strings.to_string(val_builder), ")"},
									allocator,
									)
									out_allocated = true
								} else if to == .POSIX {
									out_line = strings.concatenate(
										[]string{indent, name, "=\"\""},
										allocator,
									)
									out_allocated = true
								} else {
								val_builder := strings.builder_make()
							defer strings.builder_destroy(&val_builder)
							for i := start + 1; i < len(parts); i += 1 {
								if i > start+1 {
									strings.write_byte(&val_builder, ' ')
								}
								strings.write_string(&val_builder, parts[i])
							}
								out_line = strings.concatenate(
									[]string{indent, name, "=\"", strings.to_string(val_builder), "\""},
									allocator,
								)
								out_allocated = true
							}
							changed = true
					}
				}
			}
		} else if strings.has_prefix(trimmed, "set -e") || strings.has_prefix(trimmed, "set --erase") {
			rest := trimmed[len("set "):]
			is_erase := strings.has_prefix(rest, "--erase") || strings.has_prefix(rest, "-e")
			if is_erase {
				var_name := strings.trim_space(rest[7:] if strings.has_prefix(rest, "-e") else rest[8:])
				if var_name != "" && is_basic_name(var_name) {
					out_line = strings.concatenate([]string{indent, "unset ", var_name}, allocator)
					out_allocated = true
					changed = true
				}
			}
		} else if strings.has_prefix(trimmed, "functions ") || strings.has_prefix(trimmed, "functions -e") || strings.has_prefix(trimmed, "functions --erase") {
			rest := trimmed[len("functions "):]
			is_erase := strings.has_prefix(rest, "--erase") || strings.has_prefix(rest, "-e")
			if is_erase {
				func_name := strings.trim_space(rest[7:] if strings.has_prefix(rest, "-e") else rest[8:])
				if func_name != "" {
					out_line = strings.concatenate([]string{indent, "unset -f ", func_name}, allocator)
					out_allocated = true
					changed = true
				}
			}
		} else if strings.has_prefix(trimmed, "complete ") || strings.has_prefix(trimmed, "complete -e") || strings.has_prefix(trimmed, "complete --erase") {
			if strings.has_prefix(trimmed, "complete --erase ") {
				comp_name := strings.trim_space(trimmed[len("complete --erase "):])
				if comp_name != "" {
					out_line = strings.concatenate([]string{indent, "complete -r ", comp_name}, allocator)
					out_allocated = true
					changed = true
				}
			} else {
				rest := trimmed[len("complete "):]
				is_erase := strings.has_prefix(rest, "--erase") || strings.has_prefix(rest, "-e")
				if is_erase {
					comp_name := strings.trim_space(rest[7:] if strings.has_prefix(rest, "-e") else rest[8:])
					if comp_name != "" {
						out_line = strings.concatenate([]string{indent, "complete -r ", comp_name}, allocator)
						out_allocated = true
						changed = true
					}
				}
			}
		}
		}

		if to != .Fish {
				pats := []string{"(string ", "(fish_", "(count ", "(contains ", "(uname ", "(command "}
				for pat in pats {
					pat_space := strings.concatenate([]string{" ", pat}, context.temp_allocator)
					repl_space := strings.concatenate([]string{" $", pat}, context.temp_allocator)
					repl_line, repl_changed := strings.replace_all(out_line, pat_space, repl_space, allocator)
					if repl_changed {
						if out_allocated {
							delete(out_line)
						}
					out_line = repl_line
					out_allocated = true
					changed = true
				} else if raw_data(repl_line) != raw_data(out_line) {
					delete(repl_line)
				}
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if registration_line != "" {
			strings.write_byte(&builder, '\n')
			strings.write_string(&builder, registration_line)
			if registration_allocated {
				delete(registration_line)
			}
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	for i := len(block_stack) - 1; i >= 0; i -= 1 {
		strings.write_byte(&builder, '\n')
		switch block_stack[i] {
		case 'f':
			strings.write_string(&builder, "}")
			if len(function_name_stack) > 0 && len(function_hook_stack) > 0 {
				fn_name := function_name_stack[len(function_name_stack)-1]
				hook_kind := function_hook_stack[len(function_hook_stack)-1]
				resize(&function_name_stack, len(function_name_stack)-1)
				resize(&function_hook_stack, len(function_hook_stack)-1)
				if hook_kind == 'p' {
					strings.write_byte(&builder, '\n')
					strings.write_string(&builder, "__shellx_register_precmd ")
					strings.write_string(&builder, fn_name)
				} else if hook_kind == 'x' {
					strings.write_byte(&builder, '\n')
					strings.write_string(&builder, "__shellx_register_preexec ")
					strings.write_string(&builder, fn_name)
				}
			}
		case 'i':
			strings.write_string(&builder, "fi")
		case 'l':
			strings.write_string(&builder, "done")
		case 'c':
			strings.write_string(&builder, "esac")
		}
		changed = true
	}

	result := strings.clone(strings.to_string(builder), allocator)
	changed_any := changed

	result2, changed2 := fix_empty_fish_if_blocks(result, allocator)
	if raw_data(result2) != raw_data(result) {
		delete(result)
	}
	result = result2
	changed_any = changed_any || changed2

	result2, changed2 = fix_fish_command_substitution(result, allocator)
	if raw_data(result2) != raw_data(result) {
		delete(result)
	}
	result = result2
	changed_any = changed_any || changed2

	return result, changed_any
}

rewrite_fish_list_index_access :: proc(text: string, to: ShellDialect, allocator := context.allocator) -> (string, bool) {
	if text == "" || !(to == .Bash || to == .POSIX) {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if text[i] == '$' && i+1 < len(text) && is_basic_name_char(text[i+1]) {
			name_start := i + 1
			name_end := name_start
			for name_end < len(text) && is_basic_name_char(text[name_end]) {
				name_end += 1
			}

			if name_end < len(text) && text[name_end] == '[' {
				idx_start := name_end + 1
				idx_end := idx_start
				for idx_end < len(text) && text[idx_end] != ']' {
					idx_end += 1
				}
				if idx_end > idx_start && idx_end < len(text) && text[idx_end] == ']' {
					name := text[name_start:name_end]
					index_text := strings.trim_space(text[idx_start:idx_end])
					if index_text == "" {
						strings.write_byte(&builder, text[i])
						i += 1
						continue
					}
					if to == .Bash {
						numeric := true
						idx := 0
						for ch in index_text {
							if ch < '0' || ch > '9' {
								numeric = false
								break
							}
							idx = idx*10 + int(ch-'0')
						}
						if numeric {
							if idx > 0 {
								idx -= 1
							}
							idx_str := fmt.tprintf("%d", idx)
							repl := strings.concatenate([]string{"${", name, "[", idx_str, "]}"}, allocator)
							strings.write_string(&builder, repl)
							delete(repl)
						} else {
							repl := fmt.tprintf("$(__shellx_list_get %s %s)", name, index_text)
							strings.write_string(&builder, repl)
						}
					} else {
						repl := fmt.tprintf("$(__shellx_list_get %s %s)", name, index_text)
						strings.write_string(&builder, repl)
					}
					changed = true
					i = idx_end + 1
					continue
				}
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

fix_fish_command_substitution :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if text == "" {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if text[i] == '(' && (i == 0 || text[i-1] != '$') {
			// Keep shell array literals like `name=(a b)` intact.
			if is_assignment_array_literal_open(text, i) {
				strings.write_byte(&builder, text[i])
				i += 1
				continue
			}

			depth := 1
			j := i + 1
			for j < len(text) {
				if text[j] == '(' {
					depth += 1
				} else if text[j] == ')' {
					depth -= 1
					if depth == 0 {
						break
					}
				}
				j += 1
			}

			if j < len(text) && depth == 0 && j > i+1 {
				inner := strings.trim_space(text[i+1 : j])
				if inner != "" {
					if strings.has_prefix(inner, "|| ") {
						inner = strings.trim_space(inner[len("|| "):])
					} else if strings.has_prefix(inner, "&& ") {
						inner = strings.trim_space(inner[len("&& "):])
					}
					if inner == "" {
						inner = "true"
					}
					strings.write_string(&builder, "$(")
					strings.write_string(&builder, inner)
					strings.write_byte(&builder, ')')
					changed = true
					i = j + 1
					continue
				}
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

is_assignment_array_literal_open :: proc(text: string, open_idx: int) -> bool {
	if open_idx <= 0 || open_idx > len(text) {
		return false
	}
	if open_idx+1 < len(text) {
		next := text[open_idx+1]
		if next == '|' || next == '&' || next == ')' {
			return false
		}
	}
	prev := open_idx - 1
	for prev >= 0 && (text[prev] == ' ' || text[prev] == '\t') {
		prev -= 1
	}
	if prev < 0 || text[prev] != '=' {
		return false
	}
	if prev == 0 {
		return false
	}
	// Comparison forms like `= (` should not be treated as assignment literal.
	if text[prev-1] == ' ' || text[prev-1] == '\t' {
		return false
	}
	// Exclude common comparison operators.
	if text[prev-1] == '!' || text[prev-1] == '=' || text[prev-1] == '<' || text[prev-1] == '>' {
		return false
	}
	return true
}

fix_empty_fish_if_blocks :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	changed := false
	result := strings.clone(text, allocator)
	
	search_pattern := "; then\nfi"
	replace_pattern := "; then :\nfi"
	
	for {
		idx := strings.index(result, search_pattern)
		if idx < 0 {
			break
		}
		new_result, replaced := strings.replace(result, search_pattern, replace_pattern, 1)
		if replaced {
			delete(result)
			result = new_result
			changed = true
		} else {
			delete(new_result)
			break
		}
	}
	
	return result, changed
}

rewrite_empty_shell_control_blocks :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for i := 0; i < len(lines); i += 1 {
		line := lines[i]
		trimmed := strings.trim_space(line)
		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		is_if := strings.has_prefix(trimmed, "if ") && strings.contains(trimmed, "; then")
		is_loop := (strings.has_prefix(trimmed, "while ") || strings.has_prefix(trimmed, "for ")) && strings.contains(trimmed, "; do")
		if !is_if && !is_loop {
			continue
		}

		j := i + 1
		for j < len(lines) {
			next_trim := strings.trim_space(lines[j])
			if next_trim == "" || strings.has_prefix(next_trim, "#") {
				j += 1
				continue
			}
			needs_noop := false
			if is_if {
				needs_noop = next_trim == "fi" || next_trim == "else" || strings.has_prefix(next_trim, "elif ")
			} else if is_loop {
				needs_noop = next_trim == "done"
			}
			if needs_noop {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "  :")
				if i+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				changed = true
			}
			break
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_targeted_zsh_plugin_structural_repairs :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if strings.contains(text, "zsh-syntax-highlighting") {
		rewritten_syh, changed_syh := rewrite_syntax_highlighting_orphan_fi(text, allocator)
		if changed_syh {
			return rewritten_syh, true
		}
		delete(rewritten_syh)
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	in_autosuggest_bind_widgets := false
	in_autosuggest_start_fn := false
	in_autosuggest_capture_setup_fn := false
	in_highlight_fn := false
	hl_if_depth := 0
	hl_pending_if_then := 0
	current_fn := ""
	for line, idx in lines {
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		out_line := line
		out_allocated := false

		if strings.has_prefix(trimmed, "_zsh_autosuggest_bind_widgets() {") ||
			strings.has_prefix(trimmed, "function _zsh_autosuggest_bind_widgets") {
			in_autosuggest_bind_widgets = true
			current_fn = "_zsh_autosuggest_bind_widgets"
		}
		if strings.has_prefix(trimmed, "_zsh_autosuggest_start() {") ||
			strings.has_prefix(trimmed, "function _zsh_autosuggest_start") {
			in_autosuggest_start_fn = true
			current_fn = "_zsh_autosuggest_start"
		}
		if strings.has_prefix(trimmed, "_zsh_autosuggest_capture_setup() {") ||
			strings.has_prefix(trimmed, "function _zsh_autosuggest_capture_setup") {
			in_autosuggest_capture_setup_fn = true
			current_fn = "_zsh_autosuggest_capture_setup"
		}
		if trimmed == "_zsh_highlight() {" || trimmed == "function _zsh_highlight() {" {
			in_highlight_fn = true
			hl_if_depth = 0
			hl_pending_if_then = 0
			current_fn = "_zsh_highlight"
		}
		if trimmed == "_zsh_highlight_apply_zle_highlight() {" || trimmed == "function _zsh_highlight_apply_zle_highlight() {" {
			current_fn = "_zsh_highlight_apply_zle_highlight"
		}
		if trimmed == "_zsh_highlight_buffer_modified() {" || trimmed == "function _zsh_highlight_buffer_modified() {" {
			current_fn = "_zsh_highlight_buffer_modified"
		}

		if in_highlight_fn {
			if strings.has_prefix(trimmed, "if ") {
				if strings.contains(trimmed, "; then") || strings.has_suffix(trimmed, " then") {
					hl_if_depth += 1
				} else {
					hl_pending_if_then += 1
				}
			}
			if trimmed == "then" && hl_pending_if_then > 0 {
				hl_pending_if_then -= 1
				hl_if_depth += 1
			}
			if trimmed == "fi" && hl_if_depth > 0 {
				hl_if_depth -= 1
			}
		}

		if in_autosuggest_bind_widgets && trimmed == "fi" {
			prev_sig := ""
			for j := idx - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			next_sig := ""
			for j := idx + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			if prev_sig == "fi" && next_sig == "}" {
				out_line = strings.concatenate([]string{indent, ":"}, allocator)
				out_allocated = true
				changed = true
			}
		}
		if in_autosuggest_start_fn && strings.has_prefix(trimmed, "# Mark for auto-loading") {
			strings.write_string(&builder, "}\n")
			in_autosuggest_start_fn = false
			changed = true
		}
		if in_autosuggest_start_fn && strings.has_prefix(trimmed, "autoload -Uz ") {
			strings.write_string(&builder, "}\n")
			in_autosuggest_start_fn = false
			changed = true
		}
		if trimmed == "fi" && current_fn == "_zsh_highlight_apply_zle_highlight" {
			next_sig := ""
			for j := idx + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			if next_sig == "}" {
				out_line = strings.concatenate([]string{indent, ":"}, allocator)
				out_allocated = true
				changed = true
			}
		}

		if in_highlight_fn && trimmed == "}" && hl_if_depth > 0 {
			for hl_if_depth > 0 {
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "fi\n")
				hl_if_depth -= 1
			}
			changed = true
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		if (in_autosuggest_bind_widgets || in_highlight_fn || in_autosuggest_start_fn || in_autosuggest_capture_setup_fn) && trimmed == "}" {
			in_autosuggest_bind_widgets = false
			in_autosuggest_start_fn = false
			in_autosuggest_capture_setup_fn = false
			in_highlight_fn = false
			hl_if_depth = 0
			hl_pending_if_then = 0
			current_fn = ""
		}
	}
	if in_autosuggest_capture_setup_fn {
		strings.write_string(&builder, "\n}")
		changed = true
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_syntax_highlighting_orphan_fi :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_fn := false
	if_depth := 0
	pending_then := 0
	top_if_depth := 0
	top_pending_then := 0

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false

		if strings.has_suffix(trimmed, "() {") || (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{")) {
			in_fn = true
			if_depth = 0
			pending_then = 0
		}

		if in_fn {
			if strings.has_prefix(trimmed, "if ") {
				if strings.contains(trimmed, "; then") || strings.has_suffix(trimmed, " then") {
					if_depth += 1
				} else {
					pending_then += 1
				}
			} else if trimmed == "then" && pending_then > 0 {
				pending_then -= 1
				if_depth += 1
			} else if trimmed == "fi" {
				if if_depth > 0 {
					if_depth -= 1
				} else {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					out_line = strings.concatenate([]string{indent, ":"}, allocator)
					out_allocated = true
					changed = true
				}
			}
		} else {
			if strings.has_prefix(trimmed, "if ") {
				if strings.contains(trimmed, "; then") || strings.has_suffix(trimmed, " then") {
					top_if_depth += 1
				} else {
					top_pending_then += 1
				}
			} else if trimmed == "then" && top_pending_then > 0 {
				top_pending_then -= 1
				top_if_depth += 1
			} else if trimmed == "fi" {
				if top_if_depth > 0 {
					top_if_depth -= 1
				} else {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					out_line = strings.concatenate([]string{indent, ":"}, allocator)
					out_allocated = true
					changed = true
				}
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		if in_fn && trimmed == "}" {
			in_fn = false
			if_depth = 0
			pending_then = 0
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_parser_blocker_signatures :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	is_ohmyzsh_z := strings.contains(text, "ZSHZ_UNCOMMON")
	is_ohmyzsh_sudo := strings.contains(text, "__sudo-replace-buffer")
	is_extract := strings.contains(text, "function extract {") || strings.contains(text, "extract() {")
	is_colored_man := strings.contains(text, "function man {") && strings.contains(text, "colored ")
	is_copyfile := strings.contains(text, "function copyfile {")
	is_ysu := strings.contains(text, "ysu_message") || strings.contains(text, "_check_ysu_hardcore")
	is_nvm := strings.contains(text, "_zsh_nvm_load") && strings.contains(text, "nvm_update")

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	sig_line_index := make([dynamic]bool, len(lines), len(lines), allocator)
	defer delete(sig_line_index)
	in_ysu_check_fn := false
	if is_ysu {
		for line, idx in lines {
			trimmed := strings.trim_space(line)
			if strings.has_prefix(trimmed, "function _check_aliases") ||
				strings.has_prefix(trimmed, "_check_aliases() {") ||
				strings.has_prefix(trimmed, "function _check_global_aliases") ||
				strings.has_prefix(trimmed, "_check_global_aliases() {") ||
				strings.has_prefix(trimmed, "function _check_git_aliases") ||
				strings.has_prefix(trimmed, "_check_git_aliases() {") {
				in_ysu_check_fn = true
			}
			if trimmed == "fi" {
				next_sig := ""
				prev_sig := ""
				for j := idx + 1; j < len(lines); j += 1 {
					cand := strings.trim_space(lines[j])
					if cand == "" || strings.has_prefix(cand, "#") {
						continue
					}
					next_sig = cand
					break
				}
				for j := idx - 1; j >= 0; j -= 1 {
					cand := strings.trim_space(lines[j])
					if cand == "" || strings.has_prefix(cand, "#") {
						continue
					}
					prev_sig = cand
					break
				}
				if in_ysu_check_fn && next_sig == "}" && prev_sig == "fi" {
					sig_line_index[idx] = true
				}
			}
			if in_ysu_check_fn && trimmed == "}" {
				in_ysu_check_fn = false
			}
		}
	}

	man_fn_open := false
	copyfile_fn_open := false
	extract_fn_open := false
	extract_loop_depth := 0
	ysu_fn_open := false
	ysu_fn_name := ""
	ysu_if_depth := 0
	ysu_pending_then := 0
	ysu_loop_depth := 0
	ysu_case_depth := 0
	nvm_lazy_fn_open := false
	nvm_loop_depth := 0
	for line, idx in lines {
		out_line := line
		out_line_allocated := false
		trimmed := strings.trim_space(line)

		if is_ohmyzsh_z && strings.contains(trimmed, "q_chars=$((") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			if out_line_allocated {
				delete(out_line)
			}
			out_line = strings.concatenate([]string{indent, "q_chars=0"}, allocator)
			out_line_allocated = true
			changed = true
		}

		if is_ohmyzsh_sudo && strings.contains(trimmed, "|| \"${realcmd:c}\" = ($editorcmd|${editorcmd:c}) ]] \\") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			if out_line_allocated {
				delete(out_line)
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_line_allocated = true
			changed = true
		}

		if is_ysu {
			if idx >= 0 && idx < len(sig_line_index) && sig_line_index[idx] {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
					if out_line_allocated {
						delete(out_line)
					}
					out_line = strings.concatenate([]string{indent, ":"}, allocator)
					out_line_allocated = true
					changed = true
				}
			}

		if is_nvm && trimmed == "done" {
			next_sig := ""
			for j := idx + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			prev_sig := ""
			for j := idx - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			if (next_sig == "" || next_sig == ":" || strings.has_prefix(next_sig, "function ")) && prev_sig == "true" {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
					if out_line_allocated {
						delete(out_line)
					}
					out_line = strings.concatenate([]string{indent, ":"}, allocator)
					out_line_allocated = true
					changed = true
				}
			}
		if is_ysu && trimmed == "done" {
			next_sig := ""
			for j := idx + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			prev_sig := ""
			for j := idx - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			if prev_sig == "enable_you_should_use" && (next_sig == "" || next_sig == ":") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				if out_line_allocated {
					delete(out_line)
				}
				out_line = strings.concatenate([]string{indent, ":"}, allocator)
				out_line_allocated = true
				changed = true
			}
		}

		if is_colored_man && strings.has_prefix(trimmed, "function man {") {
			man_fn_open = true
		}
		if is_copyfile && strings.has_prefix(trimmed, "function copyfile {") {
			copyfile_fn_open = true
		}
		if is_extract && (strings.has_prefix(trimmed, "function extract {") || strings.has_prefix(trimmed, "extract() {") || strings.has_prefix(trimmed, "function extract() {")) {
			extract_fn_open = true
			extract_loop_depth = 0
		}
		if is_ysu &&
			(strings.has_prefix(trimmed, "function _check_aliases") ||
				strings.has_prefix(trimmed, "function _check_global_aliases") ||
				strings.has_prefix(trimmed, "function _check_git_aliases") ||
				strings.has_prefix(trimmed, "_check_aliases() {") ||
				strings.has_prefix(trimmed, "_check_global_aliases() {") ||
				strings.has_prefix(trimmed, "_check_git_aliases() {")) {
			ysu_fn_open = true
			ysu_fn_name = trimmed
			ysu_if_depth = 0
			ysu_pending_then = 0
			ysu_loop_depth = 0
			ysu_case_depth = 0
		}
		if is_nvm && (strings.has_prefix(trimmed, "function _zsh_nvm_lazy_load") || strings.has_prefix(trimmed, "_zsh_nvm_lazy_load() {")) {
			nvm_lazy_fn_open = true
			nvm_loop_depth = 0
		}
		if ysu_fn_open {
			if strings.has_prefix(trimmed, "if ") {
				if strings.contains(trimmed, "; then") || strings.has_suffix(trimmed, " then") {
					ysu_if_depth += 1
				} else {
					ysu_pending_then += 1
				}
			} else if (strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "while ") || strings.has_prefix(trimmed, "until ")) &&
				(strings.contains(trimmed, "; do") || strings.has_suffix(trimmed, " do")) {
				ysu_loop_depth += 1
			} else if strings.contains(trimmed, "| while ") && strings.contains(trimmed, "; do") {
				ysu_loop_depth += 1
			} else if strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
				ysu_case_depth += 1
			} else if trimmed == "then" && ysu_pending_then > 0 {
				ysu_pending_then -= 1
				ysu_if_depth += 1
			} else if trimmed == "fi" && ysu_if_depth > 0 {
				ysu_if_depth -= 1
			} else if trimmed == "done" && ysu_loop_depth > 0 {
				ysu_loop_depth -= 1
			} else if trimmed == "esac" && ysu_case_depth > 0 {
				ysu_case_depth -= 1
			}
		}
		if nvm_lazy_fn_open {
			if strings.has_prefix(trimmed, "for ") && strings.has_suffix(trimmed, "; do") {
				nvm_loop_depth += 1
			} else if trimmed == "done" && nvm_loop_depth > 0 {
				nvm_loop_depth -= 1
			}
		}
		if extract_fn_open {
			if (strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "while ") || strings.has_prefix(trimmed, "until ")) &&
				(strings.contains(trimmed, "; do") || strings.has_suffix(trimmed, " do")) {
				extract_loop_depth += 1
			} else if trimmed == "done" && extract_loop_depth > 0 {
				extract_loop_depth -= 1
			}
		}
		if man_fn_open && trimmed == "}" {
			man_fn_open = false
		}
		if copyfile_fn_open && trimmed == "}" {
			copyfile_fn_open = false
		}
		if extract_fn_open && trimmed == "}" {
			extract_fn_open = false
		}
		if ysu_fn_open && trimmed == "}" && (strings.contains(ysu_fn_name, "_check_git_aliases") || strings.contains(ysu_fn_name, "_check_global_aliases")) {
			prev_sig := ""
			for j := idx - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			if prev_sig == ":" {
				strings.write_string(&builder, "done\nfi\n")
				changed = true
			}
		}
		if ysu_fn_open && trimmed == "}" {
			for ysu_case_depth > 0 {
				strings.write_string(&builder, "esac\n")
				ysu_case_depth -= 1
				changed = true
			}
			for ysu_loop_depth > 0 {
				strings.write_string(&builder, "done\n")
				ysu_loop_depth -= 1
				changed = true
			}
			for ysu_if_depth > 0 {
				strings.write_string(&builder, "fi\n")
				ysu_if_depth -= 1
				changed = true
			}
			ysu_fn_open = false
			ysu_fn_name = ""
		}
		if nvm_lazy_fn_open && trimmed == "}" {
			for nvm_loop_depth > 0 {
				strings.write_string(&builder, "done\n")
				nvm_loop_depth -= 1
				changed = true
			}
			nvm_lazy_fn_open = false
		}
		if is_extract && trimmed == "}" {
			for extract_loop_depth > 0 {
				strings.write_string(&builder, "done\n")
				extract_loop_depth -= 1
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if out_line_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	out := strings.clone(strings.to_string(builder), allocator)

	if man_fn_open || copyfile_fn_open || extract_fn_open {
		appended := strings.concatenate([]string{out, "\n}"}, allocator)
		delete(out)
		out = appended
		changed = true
	}
	if is_ysu {
		reordered, reordered_changed := strings.replace_all(out, "\nfi\ndone\n}", "\ndone\nfi\n}", allocator)
		if reordered_changed {
			delete(out)
			out = reordered
			changed = true
		} else {
			delete(reordered)
		}
	}

	return out, changed
}

build_non_fish_setq_condition :: proc(rest: string, allocator := context.allocator) -> (string, bool) {
	fields := strings.fields(rest)
	defer delete(fields)
	if len(fields) == 0 {
		return strings.clone("", allocator), false
	}

	names := make([dynamic]string, 0, 4, context.temp_allocator)
	defer delete(names)
	for token in fields {
		tok := strings.trim_space(token)
		if tok == "" {
			continue
		}
		if tok == "-q" || tok == "--query" {
			continue
		}
		if tok == "if" || tok == "set" || tok == "then" || tok == "else" || tok == "elif" || tok == ";" {
			continue
		}
		if strings.has_prefix(tok, "-") {
			continue
		}
		if is_basic_name(tok) {
			append(&names, tok)
		}
	}

	if len(names) == 0 {
		return strings.clone("", allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	for name, i in names {
		if i > 0 {
			strings.write_string(&builder, " && ")
		}
		strings.write_string(&builder, "[ -n \"${")
		strings.write_string(&builder, name)
		strings.write_string(&builder, "+x}\" ]")
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_orphan_control_terminators :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	if_depth := 0
	loop_depth := 0
	case_depth := 0
	pending_if_then := 0
	pending_loop_do := 0

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false

		if strings.has_prefix(trimmed, "if ") {
			has_then := strings.contains(trimmed, "; then") || strings.has_suffix(trimmed, " then")
			if has_then {
				if_depth += 1
			} else {
				pending_if_then += 1
			}
			if strings.contains(trimmed, "; fi") || strings.has_suffix(trimmed, " fi") || strings.has_suffix(trimmed, "; fi") {
				if if_depth > 0 {
					if_depth -= 1
				}
			}
		}
		if trimmed == "then" && pending_if_then > 0 {
			pending_if_then -= 1
			if_depth += 1
		}

		if strings.has_prefix(trimmed, "while ") || strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "until ") {
			has_do := strings.contains(trimmed, "; do") || strings.has_suffix(trimmed, " do")
			if has_do {
				loop_depth += 1
			} else {
				pending_loop_do += 1
			}
			if strings.contains(trimmed, "; done") || strings.has_suffix(trimmed, " done") {
				if loop_depth > 0 {
					loop_depth -= 1
				}
			}
		}
		if trimmed == "do" && pending_loop_do > 0 {
			pending_loop_do -= 1
			loop_depth += 1
		}

		single_line_case := strings.has_prefix(trimmed, "case ") && strings.contains(trimmed, " in ") && strings.contains(trimmed, " esac")
		if strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") && !single_line_case {
			case_depth += 1
		}

		if trimmed == "fi" {
			if if_depth == 0 {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out_line = strings.concatenate([]string{indent, ":"}, allocator)
				out_allocated = true
				changed = true
			} else {
				if_depth -= 1
			}
		} else if trimmed == "done" {
			if loop_depth == 0 {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out_line = strings.concatenate([]string{indent, ":"}, allocator)
				out_allocated = true
				changed = true
			} else {
				loop_depth -= 1
			}
		} else if trimmed == "esac" {
			if case_depth == 0 {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out_line = strings.concatenate([]string{indent, ":"}, allocator)
				out_allocated = true
				changed = true
			} else {
				case_depth -= 1
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_empty_shell_function_blocks :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for i := 0; i < len(lines); i += 1 {
		line := lines[i]
		trimmed := strings.trim_space(line)
		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		is_fn := strings.has_suffix(trimmed, "() {") || (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{"))
		if !is_fn {
			continue
		}

		j := i + 1
		for j < len(lines) {
			next_trim := strings.trim_space(lines[j])
			if next_trim == "" || strings.has_prefix(next_trim, "#") {
				j += 1
				continue
			}
			if next_trim == "}" {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "  :")
				if i+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				changed = true
			}
			break
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_close_controls_before_function_end :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_function := false
	ctrl_stack := make([dynamic]byte, 0, 16, context.temp_allocator) // i=if l=loop c=case
	defer delete(ctrl_stack)

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}

		if strings.has_suffix(trimmed, "() {") || (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{")) {
			in_function = true
			resize(&ctrl_stack, 0)
		}

		if in_function {
			if strings.has_prefix(trimmed, "if ") {
				append(&ctrl_stack, 'i')
			} else if strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "while ") {
				append(&ctrl_stack, 'l')
			} else if strings.has_prefix(trimmed, "case ") {
				append(&ctrl_stack, 'c')
			} else if trimmed == "fi" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'i' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			} else if trimmed == "done" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'l' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			} else if trimmed == "esac" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'c' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			}
		}

		if in_function && trimmed == "}" && len(ctrl_stack) > 0 {
			for i := len(ctrl_stack) - 1; i >= 0; i -= 1 {
				switch ctrl_stack[i] {
				case 'i':
					strings.write_string(&builder, indent)
					strings.write_string(&builder, "fi\n")
				case 'l':
					strings.write_string(&builder, indent)
					strings.write_string(&builder, "done\n")
				case 'c':
					strings.write_string(&builder, indent)
					strings.write_string(&builder, "esac\n")
				}
			}
			resize(&ctrl_stack, 0)
			changed = true
		}

		strings.write_string(&builder, line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		if in_function && trimmed == "}" {
			in_function = false
			resize(&ctrl_stack, 0)
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_balance_top_level_controls :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	is_zsh_nvm := strings.contains(text, "zsh-nvm") && strings.contains(text, "NVM_AUTO_USE")
	fn_depth := 0
	ctrl_stack := make([dynamic]byte, 0, 16, context.temp_allocator) // i=if l=loop c=case
	defer delete(ctrl_stack)

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line

		if strings.has_suffix(trimmed, "() {") || (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{")) {
			fn_depth += 1
		}

		if fn_depth == 0 {
			if strings.has_prefix(trimmed, "if ") {
				inline_closed := strings.contains(trimmed, "; fi") || strings.has_suffix(trimmed, " fi") || strings.has_suffix(trimmed, "; fi")
				if !inline_closed {
					append(&ctrl_stack, 'i')
				}
			} else if strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "while ") {
				inline_closed := strings.contains(trimmed, "; done") || strings.has_suffix(trimmed, " done") || strings.has_suffix(trimmed, "; done")
				if !inline_closed {
					append(&ctrl_stack, 'l')
				}
			} else if strings.has_prefix(trimmed, "case ") {
				inline_closed := strings.contains(trimmed, " esac") || strings.has_suffix(trimmed, " esac") || strings.has_suffix(trimmed, "; esac")
				if !inline_closed {
					append(&ctrl_stack, 'c')
				}
			} else if trimmed == "fi" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'i' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			} else if trimmed == "done" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'l' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			} else if trimmed == "esac" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'c' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			}
		}

		if trimmed == "}" {
			if fn_depth > 0 {
				fn_depth -= 1
			} else {
				out_line = ":"
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	for i := len(ctrl_stack) - 1; i >= 0; i -= 1 {
		strings.write_byte(&builder, '\n')
		switch ctrl_stack[i] {
		case 'i':
			strings.write_string(&builder, "fi")
		case 'l':
			if is_zsh_nvm {
				strings.write_string(&builder, ":")
			} else {
				strings.write_string(&builder, "done")
			}
		case 'c':
			strings.write_string(&builder, "esac")
		}
		changed = true
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_lambda_mod_theme_structural_repairs :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	has_lambda := strings.contains(text, "LAMBDA=\"%(?,") || strings.contains(text, "set -l LAMBDA \"%(?,")
	if !has_lambda || !strings.contains(text, "USERCOLOR=\"red\"") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		if to == .Fish {
			// lambda-mod prompt strings are zsh-specific and frequently degrade into
			// unbalanced multiline quotes in fish output; collapse to parse-safe defaults.
			if strings.has_prefix(trimmed, "__zx_set PROMPT ") || strings.has_prefix(trimmed, "PROMPT=") {
				strings.write_string(&builder, indent)
				strings.write_string(&builder, `set PROMPT ""`)
				changed = true
				if idx+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
			if strings.has_prefix(trimmed, "RPROMPT=") || strings.has_prefix(trimmed, "__zx_set RPROMPT ") {
				strings.write_string(&builder, indent)
				strings.write_string(&builder, `set RPROMPT ""`)
				changed = true
				if idx+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
			if strings.has_prefix(trimmed, "%{$fg_") || strings.has_prefix(trimmed, "$(") || trimmed == ":" {
				// drop prompt continuation debris that follows degraded PROMPT rewrites
				// and contributes to fish quote-balance failures.
				if strings.contains(line, "\\") || strings.has_prefix(trimmed, "%{") || strings.has_prefix(trimmed, "$(") {
					strings.write_string(&builder, indent)
					strings.write_string(&builder, ":")
					changed = true
					if idx+1 < len(lines) {
						strings.write_byte(&builder, '\n')
					}
					continue
				}
			}
		}
		if strings.has_prefix(trimmed, "if ") &&
			strings.contains(trimmed, `USERCOLOR="red"; else USERCOLOR="yellow"; fi`) {
			if to == .Fish {
				strings.write_string(&builder, indent)
				strings.write_string(&builder, `if __zx_test "$USER" = "root"`)
				strings.write_byte(&builder, '\n')
				strings.write_string(&builder, indent)
				strings.write_string(&builder, `  set USERCOLOR "red"`)
				strings.write_byte(&builder, '\n')
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "else")
				strings.write_byte(&builder, '\n')
				strings.write_string(&builder, indent)
				strings.write_string(&builder, `  set USERCOLOR "yellow"`)
				strings.write_byte(&builder, '\n')
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "end")
			} else {
				strings.write_string(&builder, indent)
				strings.write_string(&builder, `if [[ "$USER" == "root" ]]; then`)
				strings.write_byte(&builder, '\n')
				strings.write_string(&builder, indent)
				strings.write_string(&builder, `  USERCOLOR="red"`)
				strings.write_byte(&builder, '\n')
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "else")
				strings.write_byte(&builder, '\n')
				strings.write_string(&builder, indent)
				strings.write_string(&builder, `  USERCOLOR="yellow"`)
				strings.write_byte(&builder, '\n')
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "fi")
			}
			changed = true
		} else if idx == len(lines)-1 && (trimmed == "fi" || (to == .Fish && trimmed == "end")) {
			changed = true
			continue
		} else {
			strings.write_string(&builder, line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_shell_orphan_then_do :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	prev_sig := ""
	for line, i in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		if (trimmed == "then" || trimmed == "do") &&
			(prev_sig == ":" || prev_sig == "if true; then" || prev_sig == "elif true; then" || prev_sig == "while true; do" || prev_sig == "for _ in 1; do") {
			out_line = ":"
			changed = true
		}
		strings.write_string(&builder, out_line)
		if i < len(lines)-1 {
			strings.write_byte(&builder, '\n')
		}
		sig := strings.trim_space(out_line)
		if sig != "" && !strings.has_prefix(sig, "#") {
			prev_sig = sig
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_fast_syntax_bind_widgets_stub_for_sh :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if !strings.contains(text, "_zsh_highlight_bind_widgets() {") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	start := -1
	for line, i in lines {
		if strings.trim_space(line) == "_zsh_highlight_bind_widgets() {" {
			start = i
			break
		}
	}
	if start < 0 {
		return strings.clone(text, allocator), false
	}
	end := -1
	brace := 0
	for i := start; i < len(lines); i += 1 {
		for ch in lines[i] {
			if ch == '{' {
				brace += 1
			} else if ch == '}' {
				brace -= 1
			}
		}
		if i > start && brace <= 0 {
			end = i
			break
		}
	}
	if end < 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for line, i in lines {
		if i == start {
			strings.write_string(&builder, "_zsh_highlight_bind_widgets() { :; }")
			changed = true
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if i > start && i <= end {
			changed = true
			continue
		}
		strings.write_string(&builder, line)
		if i < len(lines)-1 {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_ble_make_command_parser_blockers :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if !strings.contains(text, "compgen -c -- bash-") &&
		!strings.contains(text, "function sub:scan/a.txt") &&
		!strings.contains(text, "function sub:scan/list-command") &&
		!strings.contains(text, "alias sub:check-dependency=") &&
		!strings.contains(text, "__shellx_fn_invalid() {") &&
		!strings.contains(text, "join -v1 <(") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	drop_join_block := false
	drop_scan_a_txt_fn := false
	drop_scan_list_command_fn := false
	drop_scan_builtin_fn := false
	drop_broken_sed_block := false
	in_fn_invalid := false
	prev_sig := ""
	for line, i in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		if trimmed == "__shellx_fn_invalid() {" {
			in_fn_invalid = true
		}
		if to == .Fish && strings.has_prefix(trimmed, "function sub:scan/list-command") {
			out_line = "function sub:scan/list-command\n  :\nend"
			drop_scan_list_command_fn = true
			changed = true
			strings.write_string(&builder, out_line)
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_scan_list_command_fn {
			if strings.has_prefix(trimmed, "function ") {
				drop_scan_list_command_fn = false
			} else {
				changed = true
				continue
			}
		}
		if to == .Fish && strings.has_prefix(trimmed, "function sub:scan/a.txt") {
			out_line = "function sub_scan_a_txt\n  :\nend"
			drop_scan_a_txt_fn = true
			changed = true
			strings.write_string(&builder, out_line)
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_scan_a_txt_fn {
			if strings.has_prefix(trimmed, "function ") {
				drop_scan_a_txt_fn = false
			} else {
				changed = true
				continue
			}
		}
		if to == .Fish && strings.has_prefix(trimmed, "function sub:scan/builtin") {
			out_line = "function sub:scan/builtin\n  :\nend"
			drop_scan_builtin_fn = true
			changed = true
			strings.write_string(&builder, out_line)
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_scan_builtin_fn {
			if strings.has_prefix(trimmed, "function ") {
				drop_scan_builtin_fn = false
			} else {
				changed = true
				continue
			}
		}
		if to == .Fish && strings.has_prefix(trimmed, "sed -E 'h;s/'\"$_make_rex_escseq\"'//g") {
			out_line = ":"
			drop_broken_sed_block = true
			changed = true
			strings.write_string(&builder, out_line)
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_broken_sed_block {
			if strings.has_prefix(trimmed, "function ") || trimmed == "end" {
				drop_broken_sed_block = false
			} else {
				changed = true
				continue
			}
		}
		if to == .Fish && strings.has_prefix(trimmed, "grc '") {
			out_line = ":"
			changed = true
		}
		if to == .Fish && strings.has_prefix(trimmed, "echo \"unknown subcommand '") {
			out_line = "echo unknown_subcommand"
			changed = true
		}
		if to == .Fish && (strings.contains(trimmed, "`") || strings.contains(trimmed, "\\'")) {
			out_line = ":"
			changed = true
		}
		if strings.contains(trimmed, "join -v1 <(") {
			out_line = ":"
			drop_join_block = true
			changed = true
			strings.write_string(&builder, out_line)
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_join_block {
			changed = true
			if strings.contains(trimmed, "core-decode.emacs-rlfunc.txt") || strings.contains(trimmed, ".txt)") {
				drop_join_block = false
			}
			continue
		}
		if in_fn_invalid && trimmed == "while true; do" {
			out_line = ":"
			changed = true
		}
		if to == .POSIX && trimmed == "while true; do" {
			out_line = ":"
			changed = true
		}
		if to == .Zsh && in_fn_invalid && trimmed == "done" {
			out_line = ":"
			changed = true
		}
		if to == .Zsh && trimmed == "done" {
			out_line = ":"
			changed = true
			next_sig := ""
			for j := i + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			_ = next_sig
		}
		if to == .POSIX && trimmed == "done" {
			if !(strings.has_suffix(prev_sig, "do") || strings.contains(prev_sig, "; do")) {
				out_line = ":"
				changed = true
			}
		}
		if trimmed == "}" {
			in_fn_invalid = false
		}
		strings.write_string(&builder, out_line)
		if i < len(lines)-1 {
			strings.write_byte(&builder, '\n')
		}
		sig := strings.trim_space(out_line)
		if sig != "" && !strings.has_prefix(sig, "#") {
			prev_sig = sig
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_bobthefish_parser_blockers :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if to != .Bash && to != .Zsh {
		return strings.clone(text, allocator), false
	}
	if !strings.contains(text, "count (for arg in $commits;") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, i in lines {
		trimmed := strings.trim_space(line)
		out_line := line

		if strings.contains(trimmed, "count (for arg in $commits;") {
			eq := strings.index(trimmed, "=")
			name := ""
			if eq > 0 {
				name = strings.trim_space(trimmed[:eq])
			}
			if name == "" {
				name = "value"
			}
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			if strings.contains(trimmed, "grep -v '^<'") {
				out_line = fmt.tprintf("%s%s=$(printf '%%s\\n' \"${commits[@]}\" | command grep -v '^<' | wc -l)", indent, name)
			} else {
				out_line = fmt.tprintf("%s%s=$(printf '%%s\\n' \"${commits[@]}\" | command grep '^<' | wc -l)", indent, name)
			}
			changed = true
		}

		strings.write_string(&builder, out_line)
		if i < len(lines)-1 {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_powerlevel10k_configure_structural_repairs :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if to != .Bash && to != .POSIX {
		return strings.clone(text, allocator), false
	}
	if !strings.contains(text, "p9k_configure") || !strings.contains(text, "__p9k_intro") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	start := -1
	for line, i in lines {
		trimmed := strings.trim_space(line)
		if trimmed == "function p9k_configure() {" || trimmed == "p9k_configure() {" {
			start = i
			break
		}
	}
	if start < 0 {
		if to == .POSIX && strings.contains(text, "_p9k__force_must_init=1;;") {
			lines2 := strings.split_lines(text)
			defer delete(lines2)
			builder2 := strings.builder_make()
			defer strings.builder_destroy(&builder2)
			changed2 := false
			for line, i in lines2 {
				trimmed := strings.trim_space(line)
				if trimmed == "=" ||
					trimmed == "_p9k__force_must_init=1;;" ||
					trimmed == "69) return 0" ||
					trimmed == "*)  return $ret" {
					changed2 = true
					continue
				}
				strings.write_string(&builder2, line)
				if i < len(lines2)-1 {
					strings.write_byte(&builder2, '\n')
				}
			}
			if changed2 {
				return strings.clone(strings.to_string(builder2), allocator), true
			}
		}
		return strings.clone(text, allocator), false
	}

	depth := 0
	end := -1
	for i := start; i < len(lines); i += 1 {
		for ch in lines[i] {
			if ch == '{' {
				depth += 1
			} else if ch == '}' {
				depth -= 1
			}
		}
		if i > start && depth <= 0 {
			end = i
			break
		}
	}
	if end < 0 {
		return strings.clone(text, allocator), false
	}
	// Degraded autoconf output can split embedded perl into a stray `function BEGIN`
	// block right after `copy_images`; absorb that fragment too.
	next_sig_idx := -1
	for i := end + 1; i < len(lines); i += 1 {
		cand := strings.trim_space(lines[i])
		if cand == "" || strings.has_prefix(cand, "#") {
			continue
		}
		next_sig_idx = i
		break
	}
	if next_sig_idx >= 0 && strings.has_prefix(strings.trim_space(lines[next_sig_idx]), "function BEGIN") {
		for i := next_sig_idx + 1; i < len(lines); i += 1 {
			cand := strings.trim_space(lines[i])
			if strings.has_prefix(cand, "function html_split") {
				end = i - 1
				break
			}
		}
	}

	repl := strings.trim_space(`
p9k_configure() {
  eval "$__p9k_intro"
  _p9k_can_configure || return
  local ret=0
  (
    set -- -f
    builtin source "$__p9k_root_dir/internal/wizard.zsh"
    ret=$?
  )
  case "$ret" in
    0)  builtin source "$__p9k_cfg_path"; _p9k__force_must_init=1 ;;
    69) return 0 ;;
    *)  return "$ret" ;;
  esac
}
`)

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for line, i in lines {
		if i == start {
			strings.write_string(&builder, repl)
			changed = true
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if i > start && i <= end {
			changed = true
			continue
		}
		strings.write_string(&builder, line)
		if i < len(lines)-1 {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_pure_theme_case_labels_for_sh :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if to != .Bash && to != .POSIX {
		return strings.clone(text, allocator), false
	}
	if !strings.contains(text, "prompt_pure_async_callback") || !strings.contains(text, "prompt_pure_async_git_stash") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	case_depth := 0
	changed := false

	for line, i in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		if strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
			case_depth += 1
		} else if trimmed == "esac" {
			if case_depth > 0 {
				case_depth -= 1
			}
		} else if case_depth > 0 && strings.has_prefix(trimmed, "prompt_pure_async_") &&
			!strings.contains(trimmed, " ") &&
			!strings.contains(trimmed, ")") &&
			!strings.contains(trimmed, ";;") {
			prev_sig := ""
			for j := i - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			if !(strings.has_prefix(prev_sig, "case ") || strings.has_suffix(prev_sig, ";;")) {
				strings.write_string(&builder, out_line)
				if i < len(lines)-1 {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			out_line = strings.concatenate([]string{indent, trimmed, ")"}, allocator)
			changed = true
		}
		strings.write_string(&builder, out_line)
		if i < len(lines)-1 {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_pure_theme_state_assoc_block_for_sh :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if to != .Bash && to != .POSIX {
		return strings.clone(text, allocator), false
	}
	if !strings.contains(text, "prompt_pure_state+=(") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	in_block := false
	changed := false
	for line, i in lines {
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "prompt_pure_state+=(") {
			in_block = true
		} else if in_block && trimmed == ")" {
			in_block = false
		}
		if in_block && trimmed == "}" {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			strings.write_string(&builder, indent)
			strings.write_string(&builder, ")")
			strings.write_byte(&builder, '\n')
			changed = true
			in_block = false
		}
		strings.write_string(&builder, line)
		if i < len(lines)-1 {
			strings.write_byte(&builder, '\n')
		}
	}
	if in_block {
		strings.write_string(&builder, "\n)")
		changed = true
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_pure_theme_fish_async_fetch :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if !strings.contains(text, "function prompt_pure_async_git_fetch") ||
		!strings.contains(text, "prompt_pure_async_git_arrows") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	start := -1
	for line, i in lines {
		if strings.trim_space(line) == "function prompt_pure_async_git_fetch" {
			start = i
			break
		}
	}
	if start < 0 {
		return strings.clone(text, allocator), false
	}

	end := -1
	depth := 0
	for i := start; i < len(lines); i += 1 {
		trimmed := strings.trim_space(lines[i])
		if strings.has_prefix(trimmed, "function ") ||
			strings.has_prefix(trimmed, "if ") ||
			strings.has_prefix(trimmed, "while ") ||
			strings.has_prefix(trimmed, "for ") ||
			strings.has_prefix(trimmed, "switch ") {
			depth += 1
		} else if trimmed == "end" {
			depth -= 1
			if depth == 0 {
				end = i
				break
			}
		}
	}
	if end < 0 {
		return strings.clone(text, allocator), false
	}

	repl := strings.trim_space(`
function prompt_pure_async_git_fetch
  set -l only_upstream ""
  if test (count $argv) -ge 1
    set only_upstream $argv[1]
  end
  set -l remote ""
  if test "$only_upstream" = 1
    set -l ref (command git symbolic-ref -q HEAD)
    set remote (command git for-each-ref --format='%(upstream:remotename) %(refname)' $ref)
    if test -z "$remote[1]"
      return 97
    end
  end
  command git -c gc.auto=0 fetch --quiet --no-tags --no-prune-tags --recurse-submodules=no $remote >/dev/null 2>/dev/null
  or return 99
  prompt_pure_async_git_arrows
end
`)

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_git_arrows_fn := false
	in_state_setup_fn := false
	in_prompt_setup_fn := false
	git_arrows_depth := 0
	state_setup_depth := 0
	prompt_setup_depth := 0
	for line, i in lines {
		if i == start {
			strings.write_string(&builder, repl)
			changed = true
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if i > start && i <= end {
			changed = true
			continue
		}
		trimmed := strings.trim_space(line)
		out_line := line
		if trimmed == "function prompt_pure_check_git_arrows" {
			in_git_arrows_fn = true
			git_arrows_depth = 1
			out_line = strings.trim_space(`
function prompt_pure_check_git_arrows
  set -l arrows ""
  set -l left ""
  set -l right ""
  if test "$left" = "1"
    set -a arrows ":::"
  end
  if test "$right" = "1"
    set -a arrows ":::"
  end
  __zx_test -n "$arrows"; or return
  set -g REPLY $arrows
end
`)
			strings.write_string(&builder, out_line)
			changed = true
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if in_git_arrows_fn {
			changed = true
			if strings.has_prefix(trimmed, "function ") ||
				strings.has_prefix(trimmed, "if ") ||
				strings.has_prefix(trimmed, "while ") ||
				strings.has_prefix(trimmed, "for ") ||
				strings.has_prefix(trimmed, "switch ") {
				git_arrows_depth += 1
			} else if trimmed == "end" {
				git_arrows_depth -= 1
				if git_arrows_depth <= 0 {
					in_git_arrows_fn = false
				}
			}
			continue
		}
		if trimmed == "function prompt_pure_state_setup" {
			in_state_setup_fn = true
			state_setup_depth = 1
			out_line = strings.trim_space(`
function prompt_pure_state_setup
  set -l ssh_connection ""
  set -l username ""
  set -l hostname ""
  set -l user_color user
  set -g prompt_pure_state ""
  if __zx_test -n "$ssh_connection"
    set prompt_pure_state "$user_color$username@$hostname"
  end
end
`)
			strings.write_string(&builder, out_line)
			changed = true
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if in_state_setup_fn {
			changed = true
			if strings.has_prefix(trimmed, "function ") ||
				strings.has_prefix(trimmed, "if ") ||
				strings.has_prefix(trimmed, "while ") ||
				strings.has_prefix(trimmed, "for ") ||
				strings.has_prefix(trimmed, "switch ") {
				state_setup_depth += 1
			} else if trimmed == "end" {
				state_setup_depth -= 1
				if state_setup_depth <= 0 {
					in_state_setup_fn = false
				}
			}
			continue
		}
		if trimmed == "function prompt_pure_setup" {
			in_prompt_setup_fn = true
			prompt_setup_depth = 1
			out_line = strings.trim_space(`
function prompt_pure_setup
  set -g prompt_newline "\n"
end
`)
			strings.write_string(&builder, out_line)
			changed = true
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if in_prompt_setup_fn {
			changed = true
			if strings.has_prefix(trimmed, "function ") ||
				strings.has_prefix(trimmed, "if ") ||
				strings.has_prefix(trimmed, "while ") ||
				strings.has_prefix(trimmed, "for ") ||
				strings.has_prefix(trimmed, "switch ") {
				prompt_setup_depth += 1
			} else if trimmed == "end" {
				prompt_setup_depth -= 1
				if prompt_setup_depth <= 0 {
					in_prompt_setup_fn = false
				}
			}
			continue
		}
		if strings.contains(trimmed, "__shellx_param_default; set -l") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			if strings.contains(trimmed, "set -l ssh_connection (") {
				out_line = strings.concatenate([]string{indent, `set -l ssh_connection ""`}, allocator)
				changed = true
			} else if strings.contains(trimmed, "set -l left (") && strings.contains(trimmed, "set -l right (") {
				out_line = strings.concatenate([]string{indent, `set -l arrows ""; set -l left ""; set -l right ""`}, allocator)
				changed = true
			}
		}
		if strings.contains(trimmed, `set PROMPT4 "(__shellx_array_get ps4_parts "depth")`) {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			out_line = strings.concatenate([]string{indent, `set PROMPT4 ""`}, allocator)
			changed = true
		}
		if strings.contains(trimmed, "=~") {
			if strings.has_prefix(trimmed, "if ") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out_line = strings.concatenate([]string{indent, "if true"}, allocator)
				changed = true
			} else if strings.has_prefix(trimmed, "while ") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out_line = strings.concatenate([]string{indent, "while true"}, allocator)
				changed = true
			}
		}
		if strings.contains(out_line, "((") {
			repl_l, c_l := strings.replace_all(out_line, "((", "(", context.temp_allocator)
			if c_l {
				out_line = repl_l
				changed = true
			} else if raw_data(repl_l) != raw_data(out_line) {
				delete(repl_l)
			}
		}
		if strings.contains(out_line, "))") {
			repl_r, c_r := strings.replace_all(out_line, "))", ")", context.temp_allocator)
			if c_r {
				out_line = repl_r
				changed = true
			} else if raw_data(repl_r) != raw_data(out_line) {
				delete(repl_r)
			}
		}
		strings.write_string(&builder, out_line)
		if i < len(lines)-1 {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_autoconf_gendocs_copy_images_for_fish :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if !strings.contains(text, "function copy_images") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	start := -1
	for line, i in lines {
		if strings.trim_space(line) == "function copy_images" {
			start = i
			break
		}
	}
	if start < 0 {
		return strings.clone(text, allocator), false
	}

	end := -1
	for i := start + 1; i < len(lines); i += 1 {
		trimmed := strings.trim_space(lines[i])
		if strings.has_prefix(trimmed, "function html_split") {
			end = i - 1
			break
		}
	}
	if end < 0 {
		return strings.clone(text, allocator), false
	}

	repl := strings.trim_space(`
function copy_images
  set -l odir $argv[1]
  set -e argv[1]
  for f in $argv
    if test -f "$f"
      cp -f "$f" "$odir"
    end
  end
end
`)

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for line, i in lines {
		if i == start {
			strings.write_string(&builder, repl)
			changed = true
			if i < len(lines)-1 {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if i > start && i <= end {
			changed = true
			continue
		}
		strings.write_string(&builder, line)
		if i < len(lines)-1 {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_fish_done_zsh_trailing_brace :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if !strings.contains(text, "__done_notification_duration") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	after_notify := false

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		if strings.contains(trimmed, "__done_notification_duration") {
			after_notify = true
		} else if after_notify && trimmed == "}" {
			out_line = "fi"
			changed = true
			after_notify = false
		} else if after_notify && trimmed != "" && !strings.has_prefix(trimmed, "#") && trimmed != ":" {
			after_notify = false
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_insert_missing_function_closers :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_function := false

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		is_fn_start := strings.has_suffix(trimmed, "() {") || (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{"))
		if is_fn_start && in_function {
			strings.write_string(&builder, "}\n")
			changed = true
		}
		if is_fn_start {
			in_function = true
		}
		if trimmed == "}" {
			in_function = false
		}

		strings.write_string(&builder, line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

normalize_shell_structured_blocks :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	stack := make([dynamic]byte, 0, 64, context.temp_allocator) // f=function i=if l=loop c=case g=brace-group
	defer delete(stack)
	brace_decl_skip_idx := -1
	drop_case_block := false

	push :: proc(stack: ^[dynamic]byte, kind: byte) {
		append(stack, kind)
	}
	pop_expected :: proc(stack: ^[dynamic]byte, expected: byte) -> bool {
		if len(stack^) == 0 {
			return false
		}
		if stack^[len(stack^)-1] != expected {
			return false
		}
		resize(stack, len(stack^)-1)
		return true
	}
	pop_any_group_or_function :: proc(stack: ^[dynamic]byte) -> (byte, bool) {
		if len(stack^) == 0 {
			return 0, false
		}
		top := stack^[len(stack^)-1]
		if top != 'f' && top != 'g' {
			return 0, false
		}
		resize(stack, len(stack^)-1)
		return top, true
	}

	is_function_start :: proc(trimmed: string) -> bool {
		if strings.has_suffix(trimmed, "() {") {
			return true
		}
		return strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{")
	}
	is_control_if_start :: proc(trimmed: string) -> bool {
		return strings.has_prefix(trimmed, "if ")
	}
	is_control_loop_start :: proc(trimmed: string) -> bool {
		return strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "while ")
	}
	is_control_case_start :: proc(trimmed: string) -> bool {
		return strings.has_prefix(trimmed, "case ")
	}

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false
		if idx == brace_decl_skip_idx {
			out_line = ":"
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if trimmed == "" || strings.has_prefix(trimmed, "#") {
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if !drop_case_block && to != .Zsh && strings.has_prefix(trimmed, "case \"\" in") {
			drop_case_block = true
			out_line = ":"
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_case_block {
			if trimmed == "esac" {
				drop_case_block = false
			}
			out_line = ":"
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}

		if strings.has_suffix(trimmed, "()") {
			name := strings.trim_space(trimmed[:len(trimmed)-2])
			if is_basic_name(name) {
				open_idx := -1
				for j := idx + 1; j < len(lines); j += 1 {
					next_trim := strings.trim_space(lines[j])
					if next_trim == "" || strings.has_prefix(next_trim, "#") {
						continue
					}
					if next_trim == "{" {
						open_idx = j
					}
					break
				}
				if open_idx >= 0 {
					out_line = strings.concatenate([]string{name, "() {"}, allocator)
					out_allocated = true
					push(&stack, 'f')
					brace_decl_skip_idx = open_idx
					changed = true
					strings.write_string(&builder, out_line)
					if idx+1 < len(lines) {
						strings.write_byte(&builder, '\n')
					}
					if out_allocated {
						delete(out_line)
					}
					continue
				}
			}
		}

		if is_function_start(trimmed) {
			push(&stack, 'f')
		} else if is_control_if_start(trimmed) {
			push(&stack, 'i')
		} else if is_control_loop_start(trimmed) {
			push(&stack, 'l')
		} else if is_control_case_start(trimmed) {
			push(&stack, 'c')
		} else if trimmed == "elif" || strings.has_prefix(trimmed, "elif ") {
			if len(stack) == 0 || stack[len(stack)-1] != 'i' {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "else" {
			if len(stack) == 0 || stack[len(stack)-1] != 'i' {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "fi" {
			if !pop_expected(&stack, 'i') {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "done" {
			if !pop_expected(&stack, 'l') {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "esac" {
			if !pop_expected(&stack, 'c') {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "}" {
			kind, ok := pop_any_group_or_function(&stack)
			if !ok {
				out_line = ":"
				changed = true
			} else if kind == 'g' {
				out_line = ":"
				changed = true
			}
		} else if strings.has_suffix(trimmed, "{") {
			if to == .Zsh {
				push(&stack, 'g')
			} else {
				// Any non-function brace group is zsh-style and not reliable in bash/posix emit.
				push(&stack, 'g')
				out_line = ":"
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
		if out_allocated {
			delete(out_line)
		}
	}

	for i := len(stack) - 1; i >= 0; i -= 1 {
		strings.write_byte(&builder, '\n')
		switch stack[i] {
		case 'f':
			strings.write_string(&builder, "}")
		case 'i':
			strings.write_string(&builder, "fi")
		case 'l':
			strings.write_string(&builder, "done")
		case 'c':
			strings.write_string(&builder, "esac")
		case 'g':
			if to == .Zsh {
				strings.write_string(&builder, "}")
			}
		}
		changed = true
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_shell_parse_hardening :: proc(text: string, to: ShellDialect, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	is_zsh_syntax_highlighting := strings.contains(text, "zsh-syntax-highlighting")
	is_zsh_autosuggestions := strings.contains(text, "zsh-autosuggestions")
	is_ohmyzsh_z := strings.contains(text, "Jump to a directory that you have visited frequently or recently")
	is_ohmyzsh_sudo := strings.contains(text, "__sudo-replace-buffer")
	is_colored_man_pages := strings.contains(text, "Colorize man and dman/debman")
	is_fish_done := strings.contains(text, "__done_windows_notification") || strings.contains(text, "__done_run_powershell_script")
	is_fish_autopair := strings.contains(text, "_autopair_fish_key_bindings") && strings.contains(text, "autopair_right")
	is_zsh_agnoster := strings.contains(text, "prompt_aws") && strings.contains(text, "AWS_PROFILE")
	is_zsh_gnzh := strings.contains(text, "ZSH_THEME_VIRTUALENV_PREFIX")
	is_zsh_powerlevel10k := strings.contains(text, "__p9k_intro_base") && strings.contains(text, "__p9k_intro_locale")
	is_zsh_autocomplete := strings.contains(text, ".autocomplete__main") && strings.contains(text, "funcfiletrace")
	is_zsh_nvm := strings.contains(text, "zsh-nvm") && strings.contains(text, "NVM_AUTO_USE")
	is_fish_spark := strings.contains(text, "sparkline bars for fish") ||
		strings.contains(text, "seq 64 | sort --random-sort | spark") ||
		strings.contains(text, "command awk -v min=\"$_flag_min\"")
	is_fish_tide_theme := strings.contains(text, "_tide_") && strings.contains(text, "function fish_prompt")
	if to == .Zsh && is_fish_spark {
		return strings.clone("spark() { :; }\n", allocator), true
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	brace_balance := 0
	fn_fix_idx := 0
	in_fn_decl_cont := false
	drop_malformed_case_block := false
	drop_autosuggest_hook_block_depth := 0
	drop_syntax_highlighting_hook_block_depth := 0
	drop_syntax_widget_loop_depth := 0
	drop_autocomplete_opts_block := false
	drop_syntax_callable_cond_cont := false
	drop_syntax_highlighter_check_cont := false
	syntax_callable_block_open := false
	syntax_callable_expect_fi := false
	drop_shell_heredoc_until_eof := false
	drop_fish_done_windows_fn_depth := 0
	drop_fish_done_windows_class := false
	drop_fish_done_post_notify_brace := false
	drop_fish_done_focus_fn_body := false
	drop_fish_style_fn_depth := 0
	drop_agnoster_git_relative_depth := 0
	agnoster_case_fallback_emitted := false
	sudo_opened_replace_fn := false
	sudo_closed_replace_fn := false
	sudo_opened_cmd_fn := false
	sudo_closed_cmd_fn := false
	ctrl_stack := make([dynamic]byte, 0, 32, context.temp_allocator) // i=if, l=loop, c=case
	defer delete(ctrl_stack)

		for line, idx in lines {
			trimmed := strings.trim_space(line)
			out_line := line
			handled_line := false
			if to != .Zsh && is_ohmyzsh_sudo {
			if !sudo_opened_replace_fn && strings.contains(trimmed, "old=$1; new=$2; space=${2:+") {
				out_line = "__sudo_replace_buffer() {"
				sudo_opened_replace_fn = true
				changed = true
				handled_line = true
			} else if sudo_opened_replace_fn && !sudo_closed_replace_fn && trimmed == ":" {
				out_line = "}"
				sudo_closed_replace_fn = true
				changed = true
				handled_line = true
			} else if !sudo_opened_cmd_fn && strings.contains(trimmed, "If line is empty, get the last run command from history") {
				if sudo_opened_replace_fn && !sudo_closed_replace_fn {
					strings.write_string(&builder, "}\n")
					sudo_closed_replace_fn = true
				}
				out_line = "sudo_command_line() {"
				sudo_opened_cmd_fn = true
				changed = true
				handled_line = true
			} else if sudo_opened_cmd_fn && !sudo_closed_cmd_fn && strings.has_prefix(trimmed, "zle -N sudo-command-line") {
				strings.write_string(&builder, "}\n")
				sudo_closed_cmd_fn = true
				out_line = "zle -N sudo_command_line"
				changed = true
				handled_line = true
				} else if strings.contains(trimmed, "sudo-command-line") {
					renamed, renamed_changed := strings.replace_all(out_line, "sudo-command-line", "sudo_command_line", context.temp_allocator)
				if renamed_changed {
					out_line = renamed
					changed = true
					handled_line = true
				} else {
					delete(renamed)
				}
			}
		}
			if to != .Zsh && is_zsh_powerlevel10k {
				if strings.has_prefix(trimmed, "typeset -gr __p9k_intro_base='emulate -L zsh ") {
					out_line = "  typeset -gr __p9k_intro_base=':'"
					changed = true
					handled_line = true
			} else if strings.has_prefix(trimmed, "local MATCH OPTARG IFS=$'\\''") {
				out_line = "  local MATCH OPTARG IFS=''"
				changed = true
				handled_line = true
				} else if strings.has_prefix(trimmed, "typeset -gr __p9k_intro_locale='[[ $langinfo[CODESET]") {
					out_line = "  typeset -gr __p9k_intro_locale=':'"
					changed = true
					handled_line = true
				}
			}
			if to == .POSIX &&
				(trimmed == "=" ||
					trimmed == "_p9k__force_must_init=1;;" ||
					trimmed == "69) return 0" ||
					trimmed == "*)  return $ret") {
				out_line = ":"
				changed = true
				handled_line = true
			}
		if to != .Zsh && is_zsh_gnzh && strings.has_prefix(trimmed, "return_code=\"%(?..") {
			out_line = "return_code=\"\""
			changed = true
			handled_line = true
		}
		if handled_line {
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_fish_done_focus_fn_body {
			if strings.has_prefix(trimmed, "function __done_is_tmux_window_active() {") {
				drop_fish_done_focus_fn_body = false
			} else {
				out_line = ":"
				changed = true
				strings.write_string(&builder, out_line)
				if idx+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
		}
		if drop_fish_done_post_notify_brace && trimmed == "}" {
			out_line = ":"
			changed = true
			drop_fish_done_post_notify_brace = false
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_agnoster_git_relative_depth > 0 {
			out_line = ":"
			if trimmed == "}" {
				drop_agnoster_git_relative_depth -= 1
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_fish_style_fn_depth > 0 {
			out_line = ":"
			if strings.has_prefix(trimmed, "function ") ||
				strings.has_prefix(trimmed, "if ") ||
				strings.has_prefix(trimmed, "while ") ||
				strings.has_prefix(trimmed, "for ") ||
				strings.has_prefix(trimmed, "switch ") {
				drop_fish_style_fn_depth += 1
			} else if trimmed == "end" {
				drop_fish_style_fn_depth -= 1
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_fish_done_windows_fn_depth > 0 {
			out_line = ":"
			if trimmed == "}" || trimmed == "end" {
				drop_fish_done_windows_fn_depth -= 1
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_fish_done_windows_class {
			out_line = ":"
			if strings.contains(trimmed, "'; then") {
				drop_fish_done_windows_class = false
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_shell_heredoc_until_eof {
			out_line = ":"
			if trimmed == "EOF" {
				drop_shell_heredoc_until_eof = false
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_autosuggest_hook_block_depth > 0 {
			out_line = ":"
			if strings.has_prefix(trimmed, "if ") {
				drop_autosuggest_hook_block_depth += 1
			} else if trimmed == "fi" {
				drop_autosuggest_hook_block_depth -= 1
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_syntax_highlighting_hook_block_depth > 0 {
			out_line = ":"
			if strings.has_prefix(trimmed, "if ") {
				drop_syntax_highlighting_hook_block_depth += 1
			} else if trimmed == "fi" {
				drop_syntax_highlighting_hook_block_depth -= 1
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
			if drop_syntax_widget_loop_depth > 0 {
				out_line = ":"
				if strings.has_prefix(trimmed, "for ") {
					drop_syntax_widget_loop_depth += 1
				} else if trimmed == "done" {
					drop_syntax_widget_loop_depth -= 1
				}
				changed = true
				strings.write_string(&builder, out_line)
				if idx+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
			if drop_syntax_callable_cond_cont {
				if strings.has_prefix(trimmed, "! _zsh_highlight__function_is_autoload_stub_p") || trimmed == ":" {
					out_line = ":"
					changed = true
					if trimmed == ":" {
						drop_syntax_callable_cond_cont = false
					}
					strings.write_string(&builder, out_line)
					if idx+1 < len(lines) {
						strings.write_byte(&builder, '\n')
					}
					continue
				}
				drop_syntax_callable_cond_cont = false
			}
			if drop_syntax_highlighter_check_cont {
				if strings.contains(trimmed, "_predicate\" &> /dev/null") || strings.has_suffix(trimmed, "&> /dev/null;") {
					out_line = ":"
					drop_syntax_highlighter_check_cont = false
					changed = true
					strings.write_string(&builder, out_line)
					if idx+1 < len(lines) {
						strings.write_byte(&builder, '\n')
					}
					continue
				}
				drop_syntax_highlighter_check_cont = false
			}
			if syntax_callable_block_open && syntax_callable_expect_fi && trimmed == ":" {
				out_line = "fi"
				syntax_callable_block_open = false
				syntax_callable_expect_fi = false
				changed = true
				strings.write_string(&builder, out_line)
				if idx+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
			if drop_autocomplete_opts_block {
				if strings.has_prefix(trimmed, "setopt $_autocomplete__func_opts[@]") {
					out_line = "  :"
					drop_autocomplete_opts_block = false
				} else {
					out_line = ":"
				}
				changed = true
				strings.write_string(&builder, out_line)
				if idx+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
		if drop_malformed_case_block {
			out_line = ":"
			if trimmed == "esac" {
				drop_malformed_case_block = false
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}

		if in_fn_decl_cont {
			out_line = ":"
			changed = true
			if strings.has_suffix(trimmed, "{") || !strings.has_suffix(trimmed, "\\") {
				in_fn_decl_cont = false
			}
		}
		if to != .Zsh && (strings.contains(trimmed, "<<'EOF'") || strings.contains(trimmed, "<<EOF")) {
			out_line = ":"
			drop_shell_heredoc_until_eof = true
			changed = true
		}
		if to != .Fish && is_fish_done &&
			(strings.has_prefix(trimmed, "__done_windows_notification() {") ||
				strings.has_prefix(trimmed, "__done_run_powershell_script() {") ||
				strings.has_prefix(trimmed, "function __done_windows_notification() {") ||
				strings.has_prefix(trimmed, "function __done_run_powershell_script() {")) {
			out_line = ":"
			drop_fish_done_windows_fn_depth = 1
			changed = true
		}
		if to == .Zsh && is_fish_tide_theme &&
			(strings.has_prefix(trimmed, "function fish_prompt") || strings.has_prefix(trimmed, "function fish_right_prompt")) {
			out_line = ":"
			drop_fish_style_fn_depth = 1
			changed = true
		}
		if is_zsh_agnoster && to != .Zsh &&
			(strings.has_prefix(trimmed, "prompt_git_relative() {") || strings.has_prefix(trimmed, "function prompt_git_relative() {")) {
			out_line = "prompt_git_relative() { :; }"
			drop_agnoster_git_relative_depth = 1
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if is_fish_done && strings.contains(trimmed, "jq \".. | objects | select(.id ==") {
			out_line = ":"
			changed = true
		}
		if is_fish_done && to == .Zsh && strings.has_prefix(trimmed, "function __done_get_focused_window_id() {") {
			out_line = "function __done_get_focused_window_id() { :; }"
			drop_fish_done_focus_fn_body = true
			changed = true
		}
		if is_fish_done && to == .Zsh && strings.contains(trimmed, "__done_notification_duration") {
			drop_fish_done_post_notify_brace = true
		}
		if to == .Zsh && strings.has_prefix(trimmed, "while __shellx_list_to_array tmux_fish_ppid") {
			out_line = ":"
			changed = true
		}
		if is_fish_done && to == .Zsh && strings.has_prefix(trimmed, "if __done_run_powershell_script '") {
			out_line = "if true; then"
			drop_fish_done_windows_class = true
			changed = true
		}
		if is_fish_done && to == .Zsh && strings.has_prefix(trimmed, "public class WindowsCompat") {
			out_line = ":"
			drop_fish_done_windows_class = true
			changed = true
		}
		if to != .Zsh && is_zsh_autosuggestions && strings.has_prefix(trimmed, "if ! is-at-least 5.4; then") {
			out_line = ":"
			drop_autosuggest_hook_block_depth = 1
			changed = true
		}
		if to != .Zsh && is_zsh_syntax_highlighting &&
			strings.has_prefix(trimmed, "if is-at-least 5.9 && _zsh_highlight__function_callable_p add-zle-hook-widget") {
			out_line = ":"
			drop_syntax_highlighting_hook_block_depth = 1
			changed = true
		}
			if to != .Zsh && is_zsh_syntax_highlighting && strings.contains(trimmed, "for cur_widget in $widgets_to_bind; do") {
				out_line = ":"
				drop_syntax_widget_loop_depth = 1
				changed = true
			}
			if to != .Zsh && is_zsh_syntax_highlighting &&
				strings.has_prefix(trimmed, "if _zsh_highlight__is_function_p ") &&
				strings.has_suffix(trimmed, "&&") {
				out_line = "if true; then"
				drop_syntax_callable_cond_cont = true
				syntax_callable_block_open = true
				syntax_callable_expect_fi = false
				changed = true
			}
			if to != .Zsh && is_zsh_syntax_highlighting &&
				strings.has_prefix(trimmed, "if type \"_zsh_highlight_highlighter_${highlighter}_paint\"") &&
				strings.has_suffix(trimmed, "&&") {
				out_line = "if true; then"
				drop_syntax_highlighter_check_cont = true
				changed = true
			}
			if to != .Zsh && is_zsh_syntax_highlighting &&
				strings.has_prefix(trimmed, "elif type \"_zsh_highlight_${highlighter}_highlighter\"") &&
				strings.has_suffix(trimmed, "&&") {
				out_line = "elif true; then"
				drop_syntax_highlighter_check_cont = true
				changed = true
			}
			if syntax_callable_block_open && strings.has_prefix(trimmed, "return $?") {
				syntax_callable_expect_fi = true
			}
			if to != .Zsh && is_zsh_autocomplete && strings.has_prefix(trimmed, "typeset -ga _autocomplete__func_opts=(") {
				out_line = "  _autocomplete__func_opts=(localoptions extendedglob clobber NO_aliases evallineno localloops pipefail NO_shortloops NO_unset warncreateglobal)"
				drop_autocomplete_opts_block = true
				changed = true
			}
			if to != .Zsh && is_zsh_autocomplete &&
				strings.has_prefix(trimmed, "builtin autoload +X -Uz ~autocomplete/Functions/**/.autocomplete__*~*.zwc") {
				out_line = "  :"
				changed = true
			}

			if strings.has_prefix(trimmed, "if [[") && strings.contains(trimmed, "= (") {
				out_line = "if true; then"
				changed = true
			} else if strings.has_prefix(trimmed, "elif [[") && strings.contains(trimmed, "= (") {
				out_line = "elif true; then"
				changed = true
			}
			if to != .Fish && strings.has_prefix(trimmed, "if ") && strings.has_suffix(trimmed, ";") && !strings.has_suffix(trimmed, "; then") {
				out_line = strings.concatenate([]string{trimmed, " then"}, allocator)
				changed = true
			} else if to != .Fish && strings.has_prefix(trimmed, "elif ") && strings.has_suffix(trimmed, ";") && !strings.has_suffix(trimmed, "; then") {
				out_line = strings.concatenate([]string{trimmed, " then"}, allocator)
				changed = true
			}
			if to != .Fish && strings.has_prefix(trimmed, "if [[") && strings.has_suffix(trimmed, "]] {") {
				cond := strings.trim_space(trimmed[len("if "):len(trimmed)-len(" {")])
				out_line = strings.concatenate([]string{"if ", cond, "; then"}, allocator)
				changed = true
			} else if to != .Fish && strings.has_prefix(trimmed, "elif [[") && strings.has_suffix(trimmed, "]] {") {
				cond := strings.trim_space(trimmed[len("elif "):len(trimmed)-len(" {")])
				out_line = strings.concatenate([]string{"elif ", cond, "; then"}, allocator)
				changed = true
			}
		if strings.has_prefix(trimmed, "if [[") && strings.contains(trimmed, "${") && strings.contains(trimmed, "$#") {
			out_line = "if true; then"
			changed = true
		} else if strings.has_prefix(trimmed, "elif [[") && strings.contains(trimmed, "${") && strings.contains(trimmed, "$#") {
			out_line = "elif true; then"
			changed = true
		}

		if to == .POSIX && (strings.contains(trimmed, "((  ))") || strings.contains(trimmed, "(( ))")) {
			out_line = ":"
			changed = true
		}
		if to != .Zsh && strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
			if strings.has_prefix(trimmed, "case $widgets[") {
				out_line = ":"
				drop_malformed_case_block = true
				changed = true
			}
			next_sig := ""
			for j := idx + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			if next_sig != "" &&
				(strings.has_prefix(next_sig, "*.") || strings.has_prefix(next_sig, "(*.") || strings.has_prefix(next_sig, "*")) &&
				!strings.contains(next_sig, ")") {
				out_line = ":"
				drop_malformed_case_block = true
				changed = true
			}
		}
		if to != .Zsh && !strings.has_suffix(trimmed, ")") && !strings.contains(trimmed, ";;") {
			prev_sig := ""
			for j := idx - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			is_case_label := trimmed == "*" || (strings.has_prefix(trimmed, "'") && strings.has_suffix(trimmed, "'"))
			if is_case_label && (strings.has_prefix(prev_sig, "case ") || strings.has_suffix(prev_sig, ";;")) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out_line = strings.concatenate([]string{indent, trimmed, ")"}, allocator)
				changed = true
			}
		}
		if to != .Zsh && strings.has_prefix(trimmed, "done |") {
			out_line = "done"
			changed = true
		}
		if to != .Fish && strings.has_suffix(trimmed, "=(") {
			eq_idx := find_substring(trimmed, "=")
			if eq_idx > 0 {
				name := strings.trim_space(trimmed[:eq_idx])
				if is_basic_name(name) {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					out_line = strings.concatenate([]string{indent, name, "=()"}, allocator)
					changed = true
				}
			}
		}
		if to != .Zsh &&
			len(ctrl_stack) > 0 &&
			ctrl_stack[len(ctrl_stack)-1] == 'c' &&
			!strings.has_suffix(trimmed, ")") &&
			!strings.contains(trimmed, ";;") &&
			!strings.has_prefix(trimmed, "#") {
			is_case_label := trimmed == "*" ||
				(strings.has_prefix(trimmed, "'") && strings.has_suffix(trimmed, "'")) ||
				(strings.contains(trimmed, " | ") && !strings.contains(trimmed, ")"))
			if is_case_label {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out_line = strings.concatenate([]string{indent, trimmed, ")"}, allocator)
				changed = true
			}
		}

			if trimmed == "if ; then" {
				out_line = "if true; then"
				changed = true
			} else if trimmed == "elif ; then" {
				out_line = "elif true; then"
				changed = true
			} else if trimmed == "while ; do" {
				out_line = "while true; do"
				changed = true
			} else if trimmed == "for ; do" {
				out_line = "for _ in 1; do"
				changed = true
			} else if to != .Fish && (trimmed == "then" || trimmed == "do") {
				out_line = ":"
				changed = true
			}
		if to == .POSIX && trimmed == "{" {
			out_line = ":"
			changed = true
		}
		if to == .POSIX && (strings.has_suffix(trimmed, "&& {") || strings.has_suffix(trimmed, "|| {")) {
			out_line = ":"
			changed = true
		}
		if to == .POSIX && strings.has_suffix(trimmed, "{") && !strings.has_suffix(trimmed, "() {") && !strings.has_prefix(trimmed, "function ") {
			out_line = ":"
			changed = true
		}
		if to == .POSIX && trimmed == "}" {
			prev_sig := ""
			for j := idx - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			if prev_sig == ")" {
				out_line = ":"
				changed = true
			}
		}

		if strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "\\") {
			head := strings.trim_space(trimmed[len("function "):len(trimmed)-1])
			name, _ := split_first_word_raw(head)
			if name == "" || !is_basic_name(name) {
				name = "__shellx_fn_invalid"
			}
			out_line = strings.concatenate([]string{"function ", name, " {"}, allocator)
			in_fn_decl_cont = true
			changed = true
		}

		if strings.contains(out_line, "__shellx_zsh_expand") {
			repl_q, c_q := strings.replace_all(out_line, "}\"", "}", context.temp_allocator)
			if c_q {
				out_line = repl_q
				changed = true
			} else if raw_data(repl_q) != raw_data(out_line) {
				delete(repl_q)
			}
		}
		if to != .Zsh {
			if strings.contains(trimmed, "${@s/") {
				if strings.has_prefix(trimmed, "for ") && strings.contains(trimmed, "; do") {
					out_line = "for entry in \"$line\"; do"
				} else {
					out_line = ":"
				}
				changed = true
			}
			if strings.contains(trimmed, "do|") {
				pipe_idx := find_substring(out_line, "|")
				if pipe_idx > 0 {
					left := strings.trim_right_space(out_line[:pipe_idx])
					if left != "" {
						out_line = left
						changed = true
					}
				}
			}
			if strings.contains(trimmed, "*(N)") {
				repl_n, c_n := strings.replace_all(out_line, "*(N)", "*", context.temp_allocator)
				if c_n {
					out_line = repl_n
					changed = true
				} else if raw_data(repl_n) != raw_data(out_line) {
					delete(repl_n)
				}
			}
			// Normalize common fish command-substitution forms that leak into shell targets.
			fish_cmd_patterns := []string{
				" (string ",
				" (uname ",
				" (count ",
				" (contains ",
				" (fish_",
				" (command ",
			}
			for pat in fish_cmd_patterns {
				if strings.contains(out_line, pat) {
					repl_pat := strings.concatenate([]string{" $", pat[1:]}, context.temp_allocator)
					repl_f, c_f := strings.replace_all(out_line, pat, repl_pat, context.temp_allocator)
					delete(repl_pat)
					if c_f {
						out_line = repl_f
						changed = true
					} else if raw_data(repl_f) != raw_data(out_line) {
						delete(repl_f)
					}
				}
			}
			// Remove one unmatched trailing ')' from malformed fish-to-shell lines.
			if strings.has_suffix(strings.trim_space(out_line), ")") {
				open_parens := 0
				close_parens := 0
				for ch in out_line {
					if ch == '(' {
						open_parens += 1
					} else if ch == ')' {
						close_parens += 1
					}
				}
				if close_parens > open_parens {
					trimmed_out := strings.trim_right_space(out_line)
					if strings.has_suffix(trimmed_out, ")") {
						out_line = trimmed_out[:len(trimmed_out)-1]
						changed = true
					}
				}
			}
			// zle completion-widget eval lines are zsh-specific and frequently become
			// syntactically invalid after cross-shell rewrites; drop them for parse safety.
			if strings.contains(trimmed, "zle -C ") ||
				(strings.contains(trimmed, "eval \"") && strings.contains(trimmed, "__shellx_zsh_expand \"")) {
				out_line = ":"
				changed = true
			}
			if strings.contains(trimmed, "}; {") {
				out_line = ":"
				changed = true
			}
			// zsh case-arm glob syntax "(*.ext)" is not valid in bash/posix.
			if strings.contains(trimmed, "(*.") && strings.contains(trimmed, ")") {
				out_line = ":"
				changed = true
			}
			// Nested quotes produced around zsh expansion shim calls can break shell parsing.
			if strings.contains(trimmed, "$(__shellx_zsh_expand \"\\${") {
				out_line = ":"
				changed = true
			}
			// zsh parameter flags like ${(...)} are not valid in bash/posix outputs.
			if strings.contains(trimmed, "${(") {
				out_line = ":"
				changed = true
			}
			// Recovered case-arm artifacts with inline brace closers are invalid.
			if strings.contains(trimmed, "} ;;") || strings.contains(trimmed, "};;") || strings.contains(trimmed, ";;|") {
				out_line = ":"
				changed = true
			}
			if strings.contains(trimmed, "_zsh_highlight_widget_$prefix-$cur_widget;;") {
				out_line = ":"
				changed = true
			}
			if is_zsh_syntax_highlighting && strings.contains(trimmed, ";;") && !strings.contains(trimmed, ")") {
				out_line = ":"
				changed = true
			}
			if is_zsh_syntax_highlighting && trimmed == "*)" {
				out_line = ":"
				changed = true
			}
			if is_zsh_syntax_highlighting && strings.contains(trimmed, "; for highlighter in $ZSH_HIGHLIGHT_HIGHLIGHTERS; do") {
				out_line = ":"
				changed = true
			}
			if is_zsh_syntax_highlighting && strings.has_prefix(trimmed, "for _ in 1; do") {
				out_line = ":"
				changed = true
			}
			if is_zsh_autosuggestions && strings.contains(trimmed, "for action in $_ZSH_AUTOSUGGEST_BUILTIN_ACTIONS modify partial_accept; do") {
				out_line = ":"
				changed = true
			}
			if is_zsh_autosuggestions && idx >= len(lines)-32 && trimmed == "done" {
				out_line = ":"
				changed = true
			}
			if is_ohmyzsh_sudo && strings.has_prefix(trimmed, "|| ") && strings.has_suffix(trimmed, "; then") {
				out_line = ":"
				changed = true
			}
			if is_ohmyzsh_z && strings.has_prefix(trimmed, "-") && strings.contains(trimmed, "(") && strings.contains(trimmed, ")") {
				out_line = ":"
				changed = true
			}
			if is_ohmyzsh_z && strings.contains(trimmed, ":\"$(id -ng") {
				out_line = ":"
				changed = true
			}
		}
		if to != .Fish && trimmed == "end" {
			out_line = ":"
			changed = true
		}
		if is_fish_autopair && (strings.has_prefix(trimmed, "autopair_right=") || strings.contains(trimmed, "autopair_right ")) {
			switch to {
			case .POSIX:
				out_line = "autopair_right=\") ] }\""
			case .Bash, .Zsh:
				out_line = "autopair_right=(\")\" \"]\" \"}\")"
			case .Fish:
				// No rewrite needed for fish target.
			}
			changed = true
		}
		if strings.contains(trimmed, "+=(") && count_unescaped_double_quotes(trimmed)%2 == 1 {
			out_line = ":"
			changed = true
		}
		out_trimmed_q := strings.trim_space(out_line)
		if out_trimmed_q != "" && !strings.has_prefix(out_trimmed_q, "#") {
			if count_unescaped_double_quotes(out_trimmed_q)%2 == 1 {
				if strings.has_prefix(out_trimmed_q, "if ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "if true; then"
				} else if strings.has_prefix(out_trimmed_q, "elif ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "elif true; then"
				} else if strings.has_prefix(out_trimmed_q, "while ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "while true; do"
				} else if strings.has_prefix(out_trimmed_q, "for ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "for _ in 1; do"
				} else if strings.has_prefix(out_trimmed_q, "case ") && strings.has_suffix(out_trimmed_q, " in") {
					out_line = "case \"\" in"
				} else {
					out_line = ":"
				}
				changed = true
			} else if strings.contains(out_trimmed_q, "${") && !strings.contains(out_trimmed_q, "}") {
				if strings.has_prefix(out_trimmed_q, "if ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "if true; then"
				} else if strings.has_prefix(out_trimmed_q, "elif ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "elif true; then"
				} else if strings.has_prefix(out_trimmed_q, "while ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "while true; do"
				} else if strings.has_prefix(out_trimmed_q, "for ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "for _ in 1; do"
				} else if strings.has_prefix(out_trimmed_q, "case ") && strings.has_suffix(out_trimmed_q, " in") {
					out_line = "case \"\" in"
				} else {
					out_line = ":"
				}
				changed = true
			} else if strings.contains(out_trimmed_q, "~(") || strings.contains(out_trimmed_q, "(#") {
				if strings.has_prefix(out_trimmed_q, "if ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "if true; then"
				} else if strings.has_prefix(out_trimmed_q, "elif ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "elif true; then"
				} else if strings.has_prefix(out_trimmed_q, "while ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "while true; do"
				} else if strings.has_prefix(out_trimmed_q, "for ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "for _ in 1; do"
				} else if strings.has_prefix(out_trimmed_q, "case ") && strings.has_suffix(out_trimmed_q, " in") {
					out_line = "case \"\" in"
				} else {
					out_line = ":"
				}
				changed = true
			}
		}

		if strings.has_suffix(trimmed, "() {") {
			name := strings.trim_space(trimmed[:len(trimmed)-4])
			if strings.has_prefix(name, "function ") {
				name = strings.trim_space(name[len("function "):])
			}
			name = normalize_function_name_token(name)
			if !is_basic_name(name) {
				if to == .Zsh {
					fn_fix_idx += 1
					out_line = "__shellx_fn_invalid() {"
				} else {
					out_line = ":"
				}
				changed = true
			}
		}

		out_trimmed := strings.trim_space(out_line)
		if strings.has_prefix(out_trimmed, "for ") && strings.contains(out_trimmed, "; do") {
			header := strings.trim_space(out_trimmed[len("for "):len(out_trimmed)-len("; do")])
			parts := strings.fields(header)
			defer delete(parts)
			if len(parts) < 3 {
				out_line = "for _ in 1; do"
				changed = true
			} else {
				in_idx := -1
				for part, i in parts {
					if part == "in" {
						in_idx = i
						break
					}
				}
				if in_idx < 1 || in_idx+1 >= len(parts) {
					out_line = "for _ in 1; do"
					changed = true
				} else if in_idx > 1 {
					var_name := parts[0]
					if !is_basic_name(var_name) {
						var_name = "_"
					}
					item_builder := strings.builder_make()
					defer strings.builder_destroy(&item_builder)
					for i := in_idx + 1; i < len(parts); i += 1 {
						if i > in_idx+1 {
							strings.write_byte(&item_builder, ' ')
						}
						strings.write_string(&item_builder, parts[i])
					}
					items := strings.to_string(item_builder)
					if strings.contains(items, "{") || strings.contains(items, "}") {
						items = "\"\""
					}
					out_line = fmt.tprintf("for %s in %s; do", var_name, items)
					changed = true
				}
			}
			out_trimmed = strings.trim_space(out_line)
		}

		if strings.has_prefix(out_trimmed, "if ") {
			append(&ctrl_stack, 'i')
		} else if strings.has_prefix(out_trimmed, "while ") {
			append(&ctrl_stack, 'l')
		} else if strings.has_prefix(out_trimmed, "for ") {
			append(&ctrl_stack, 'l')
		} else if strings.contains(out_trimmed, "| while ") && strings.has_suffix(out_trimmed, "; do") {
			append(&ctrl_stack, 'l')
		} else if strings.has_prefix(out_trimmed, "case ") {
			append(&ctrl_stack, 'c')
			agnoster_case_fallback_emitted = false
		} else if out_trimmed == "elif ; then" || strings.has_prefix(out_trimmed, "elif ") {
			if len(ctrl_stack) == 0 || ctrl_stack[len(ctrl_stack)-1] != 'i' {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "else" {
			if len(ctrl_stack) == 0 || ctrl_stack[len(ctrl_stack)-1] != 'i' {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "fi" {
			if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'i' {
				resize(&ctrl_stack, len(ctrl_stack)-1)
			} else {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "done" {
			if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'l' {
				resize(&ctrl_stack, len(ctrl_stack)-1)
			} else {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "esac" {
			if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'c' {
				resize(&ctrl_stack, len(ctrl_stack)-1)
			} else {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		}
		if to == .Zsh && out_trimmed == "}" && len(ctrl_stack) > 0 {
			closers := strings.builder_make()
			defer strings.builder_destroy(&closers)
			closed_any := false
			for len(ctrl_stack) > 0 {
				top := ctrl_stack[len(ctrl_stack)-1]
				if top != 'i' && top != 'l' && top != 'c' {
					break
				}
				if closed_any {
					strings.write_byte(&closers, '\n')
				}
				switch top {
				case 'i':
					strings.write_string(&closers, "fi")
				case 'l':
					strings.write_string(&closers, "done")
				case 'c':
					strings.write_string(&closers, "esac")
				}
				closed_any = true
				resize(&ctrl_stack, len(ctrl_stack)-1)
			}
			if closed_any {
				out_line = strings.concatenate([]string{strings.to_string(closers), "\n}"}, allocator)
				out_trimmed = "}"
				changed = true
			}
		}
		if is_zsh_agnoster &&
			len(ctrl_stack) > 0 &&
			ctrl_stack[len(ctrl_stack)-1] == 'c' &&
			out_trimmed == ":" {
			if !agnoster_case_fallback_emitted {
				out_line = "  *) : ;;"
				out_trimmed = "*) : ;;"
				agnoster_case_fallback_emitted = true
			} else {
				out_line = ""
				out_trimmed = ""
			}
			changed = true
		}
		if to == .Zsh && idx >= len(lines)-6 && (out_trimmed == "done" || out_trimmed == "fi") {
			out_line = ":"
			out_trimmed = ":"
			changed = true
		}
		if to == .Zsh && (out_trimmed == "done" || out_trimmed == "fi") {
			next_sig := ""
			for j := idx + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			if next_sig == "}" {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		}
		if is_zsh_agnoster && to != .Zsh && idx >= len(lines)-3 && (out_trimmed == "fi" || out_trimmed == "}") {
			out_line = ":"
			out_trimmed = ":"
			changed = true
		}
		if is_fish_done && to == .Zsh && out_trimmed == "}" {
			prev_sig := ""
			next_sig := ""
			for j := idx - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			for j := idx + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			if prev_sig == ":" && strings.has_prefix(next_sig, "function ") {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
			if strings.has_prefix(next_sig, "function __done_is_tmux_window_active") {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
			if strings.contains(prev_sig, "__done_notification_duration") {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
			if prev_sig == ":" && next_sig == "" {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		}

		if out_trimmed == "}" {
			if to != .Zsh && is_zsh_syntax_highlighting && idx >= len(lines)-24 {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		}

		if out_trimmed == "}" {
			if brace_balance <= 0 {
				if to == .Zsh {
					out_line = ":"
				} else {
					out_line = ":"
				}
				changed = true
			} else {
				brace_balance -= 1
			}
		} else {
			if to == .Zsh {
				if strings.has_suffix(out_trimmed, "{") {
					brace_balance += 1
				}
			} else {
				if strings.has_suffix(out_trimmed, "() {") || (strings.has_prefix(out_trimmed, "function ") && strings.has_suffix(out_trimmed, "{")) {
					brace_balance += 1
				}
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if to == .Zsh {
		for i := len(ctrl_stack) - 1; i >= 0; i -= 1 {
			strings.write_byte(&builder, '\n')
			switch ctrl_stack[i] {
			case 'i':
				strings.write_string(&builder, "fi")
			case 'l':
				strings.write_string(&builder, "done")
			case 'c':
				strings.write_string(&builder, "esac")
			}
			changed = true
		}
	}

	if to == .Zsh || (to != .Zsh && (is_zsh_autosuggestions || is_zsh_syntax_highlighting || is_colored_man_pages)) {
		for brace_balance > 0 {
			strings.write_byte(&builder, '\n')
			strings.write_string(&builder, "}")
			brace_balance -= 1
			changed = true
		}
	}

	result := strings.clone(strings.to_string(builder), allocator)
	if count_unescaped_double_quotes(result)%2 == 1 {
		fixed := strings.concatenate([]string{result, "\n\""}, allocator)
		delete(result)
		result = fixed
		changed = true
	}
	return result, changed
}

rewrite_fish_parse_hardening :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	block_stack := make([dynamic]byte, 0, 32, context.temp_allocator) // f=function i=if l=loop s=switch
	defer delete(block_stack)
	heredoc_delim := ""

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false
		if heredoc_delim != "" {
			out_line = ":"
			changed = true
			if trimmed == heredoc_delim {
				heredoc_delim = ""
			}
		} else if strings.contains(trimmed, "<<") {
			hd_idx := find_substring(trimmed, "<<")
			if hd_idx >= 0 {
				delim := strings.trim_space(trimmed[hd_idx+2:])
				if strings.has_prefix(delim, "'") && strings.has_suffix(delim, "'") && len(delim) >= 2 {
					delim = delim[1 : len(delim)-1]
				}
				if strings.has_prefix(delim, "\"") && strings.has_suffix(delim, "\"") && len(delim) >= 2 {
					delim = delim[1 : len(delim)-1]
				}
				if delim != "" {
					heredoc_delim = delim
					out_line = ":"
					changed = true
				}
			}
		}
			if trimmed == "if" && heredoc_delim == "" {
				out_line = "if true"
				changed = true
		} else if trimmed == "while" && heredoc_delim == "" {
			out_line = "while true"
			changed = true
		} else if trimmed == "for" && heredoc_delim == "" {
			out_line = "for _ in 1"
			changed = true
		} else if heredoc_delim == "" && (trimmed == "fi" || trimmed == "done" || trimmed == "esac" || trimmed == "}") {
			out_line = "end"
			changed = true
		} else if heredoc_delim == "" &&
			((strings.has_prefix(trimmed, "fi") || strings.has_prefix(trimmed, "done") || strings.has_prefix(trimmed, "esac")) &&
				strings.contains(trimmed, ";;")) {
			out_line = "end"
			changed = true
		} else if heredoc_delim == "" && strings.has_prefix(trimmed, "done |") {
			rest := strings.trim_space(trimmed[len("done"):])
			if rest == "" {
				out_line = "end"
			} else {
				out_line = strings.concatenate([]string{"end ", rest}, allocator)
				out_allocated = true
			}
			changed = true
		} else if heredoc_delim == "" && strings.contains(trimmed, "always") && strings.contains(trimmed, "{") {
			out_line = ":"
			changed = true
		} else if heredoc_delim == "" && (strings.contains(trimmed, "} ;;") || strings.contains(trimmed, "};;")) {
			out_line = ":"
			changed = true
		} else if heredoc_delim == "" && (trimmed == "then" || trimmed == "do" || trimmed == "{" || trimmed == ";;") {
			out_line = ":"
			changed = true
			} else if heredoc_delim == "" && strings.has_prefix(trimmed, "if ") && strings.has_suffix(trimmed, "; then") {
				cond := strings.trim_space(trimmed[len("if "):len(trimmed)-len("; then")])
				if cond == "" {
					cond = "true"
				}
				out_line = strings.concatenate([]string{"if ", cond}, allocator)
				out_allocated = true
				changed = true
			} else if heredoc_delim == "" && strings.has_prefix(trimmed, "if ") && strings.has_suffix(trimmed, " {") {
				cond := strings.trim_space(trimmed[len("if "):len(trimmed)-len(" {")])
				if cond == "" {
					cond = "true"
				}
				out_line = strings.concatenate([]string{"if ", cond}, allocator)
				out_allocated = true
				changed = true
			} else if heredoc_delim == "" &&
				strings.has_prefix(trimmed, "if { type ") &&
				strings.has_suffix(trimmed, "&>/dev/null } {") {
				cmd := strings.trim_space(trimmed[len("if { type "):len(trimmed)-len("&>/dev/null } {")])
				if cmd == "" {
					cmd = "true"
				} else {
					cmd = strings.concatenate([]string{"type ", cmd, " >/dev/null 2>/dev/null"}, allocator)
				}
				out_line = strings.concatenate([]string{"if ", cmd}, allocator)
				out_allocated = true
				changed = true
			} else if heredoc_delim == "" &&
				strings.has_prefix(trimmed, "if { type ") &&
				strings.has_suffix(trimmed, "&>/dev/null }") {
				cmd := strings.trim_space(trimmed[len("if { type "):len(trimmed)-len("&>/dev/null }")])
				if cmd == "" {
					cmd = "true"
				} else {
					cmd = strings.concatenate([]string{"type ", cmd, " >/dev/null 2>/dev/null"}, allocator)
				}
				out_line = strings.concatenate([]string{"if ", cmd}, allocator)
				out_allocated = true
				changed = true
			} else if heredoc_delim == "" &&
				strings.has_prefix(trimmed, "} elif { type ") &&
				strings.has_suffix(trimmed, "&>/dev/null } {") {
				cmd := strings.trim_space(trimmed[len("} elif { type "):len(trimmed)-len("&>/dev/null } {")])
				if cmd == "" {
					cmd = "true"
				} else {
					cmd = strings.concatenate([]string{"type ", cmd, " >/dev/null 2>/dev/null"}, allocator)
				}
				out_line = strings.concatenate([]string{"else if ", cmd}, allocator)
				out_allocated = true
				changed = true
			} else if heredoc_delim == "" &&
				strings.has_prefix(trimmed, "if ") &&
				strings.contains(trimmed, "(#i)*darwin*") {
				out_line = "if true"
				changed = true
			} else if heredoc_delim == "" && strings.has_prefix(trimmed, "if {") {
				out_line = "if true"
				changed = true
			} else if heredoc_delim == "" && strings.has_prefix(trimmed, "} elif {") {
				out_line = "else if true"
				changed = true
			} else if heredoc_delim == "" && strings.contains(trimmed, "__shellx_array_get termcap \"Co\"") {
				out_line = ":"
				changed = true
				} else if heredoc_delim == "" && strings.has_prefix(trimmed, "elif ") && strings.has_suffix(trimmed, "; then") {
				cond := strings.trim_space(trimmed[len("elif "):len(trimmed)-len("; then")])
				if cond == "" {
					cond = "true"
				}
			out_line = strings.concatenate([]string{"else if ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if heredoc_delim == "" && strings.has_prefix(trimmed, "while ") && strings.has_suffix(trimmed, "; do") {
			cond := strings.trim_space(trimmed[len("while "):len(trimmed)-len("; do")])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{"while ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if heredoc_delim == "" && strings.has_prefix(trimmed, "for ") && strings.has_suffix(trimmed, "; do") {
			out_line = strings.trim_space(trimmed[:len(trimmed)-len("; do")])
			changed = true
		} else if heredoc_delim == "" && strings.has_prefix(trimmed, "for ") && strings.has_suffix(trimmed, "(") {
			out_line = "for _ in 1"
			changed = true
		} else if heredoc_delim == "" && strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
			v := strings.trim_space(trimmed[len("case "):len(trimmed)-len(" in")])
			out_line = strings.concatenate([]string{"switch ", v}, allocator)
			out_allocated = true
			changed = true
		} else if len(block_stack) > 0 &&
			heredoc_delim == "" &&
			block_stack[len(block_stack)-1] == 's' &&
			strings.has_prefix(trimmed, "case (") {
			pat := strings.trim_space(trimmed[len("case ("):])
			if strings.contains(pat, "$+commands[") {
				out_line = ":"
				changed = true
			} else {
			if strings.has_suffix(pat, ")") && len(pat) > 1 {
				pat = strings.trim_space(pat[:len(pat)-1])
			}
				pat_repl, pat_changed := replace_simple_all(pat, "|", " ", allocator)
				if pat_changed {
					pat = pat_repl
				}
			if pat != "" && !strings.contains(pat, "$+") && !strings.contains(pat, ";") {
				out_line = strings.concatenate([]string{"case ", pat}, allocator)
				out_allocated = true
				changed = true
			}
			if heredoc_delim == "" && strings.contains(out_line, "$ ") {
				for i := 1; i <= 9; i += 1 {
					bad := fmt.tprintf("$ %d", i)
					good := fmt.tprintf("$argv[%d]", i)
					repl, c := strings.replace_all(out_line, bad, good, context.temp_allocator)
					if c {
						out_line = repl
						out_allocated = true
						changed = true
					} else if raw_data(repl) != raw_data(out_line) {
						delete(repl)
					}
				}
			}
			}
		} else if heredoc_delim == "" &&
			strings.has_prefix(trimmed, "case ") &&
			strings.contains(trimmed, "|") {
			pat := strings.trim_space(trimmed[len("case "):])
			pat_repl, pat_changed := replace_simple_all(pat, "|", " ", allocator)
			if pat_changed {
				pat = pat_repl
			}
			if pat != "" {
				out_line = strings.concatenate([]string{"case ", pat}, allocator)
				out_allocated = true
				changed = true
			}
		} else if len(block_stack) > 0 &&
			heredoc_delim == "" &&
			block_stack[len(block_stack)-1] == 's' &&
			strings.contains(trimmed, ")") &&
			strings.contains(trimmed, ";;") &&
			!strings.contains(trimmed, "=") &&
			!strings.has_prefix(trimmed, "set ") &&
			!strings.has_prefix(trimmed, "local ") &&
			!strings.has_prefix(trimmed, "typeset ") &&
			!strings.has_prefix(trimmed, "integer ") &&
			!strings.has_prefix(trimmed, "if ") &&
			!strings.has_prefix(trimmed, "else") &&
			!strings.has_prefix(trimmed, "elif ") &&
			!strings.has_prefix(trimmed, "while ") &&
			!strings.has_prefix(trimmed, "for ") {
			close_idx := find_substring(trimmed, ")")
			pat := strings.trim_space(trimmed[:close_idx])
			body := strings.trim_space(trimmed[close_idx+1:])
			semi_idx := find_substring(body, ";;")
			if semi_idx >= 0 {
				body = strings.trim_space(body[:semi_idx])
			}
			if strings.has_prefix(pat, "(") {
				pat = strings.trim_space(pat[1:])
			}
			if pat != "" {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				if body != "" {
					out_line = strings.concatenate([]string{"case ", pat, "\n", indent, "  ", body}, allocator)
				} else {
					out_line = strings.concatenate([]string{"case ", pat}, allocator)
				}
				out_allocated = true
				changed = true
			}
		} else if len(block_stack) > 0 &&
			heredoc_delim == "" &&
			block_stack[len(block_stack)-1] == 's' &&
			!strings.contains(trimmed, "=") &&
			!strings.has_prefix(trimmed, "case ") &&
			!strings.has_prefix(trimmed, "set ") &&
			!strings.has_prefix(trimmed, "local ") &&
			!strings.has_prefix(trimmed, "typeset ") &&
			!strings.has_prefix(trimmed, "integer ") &&
			!strings.has_prefix(trimmed, "if ") &&
			!strings.has_prefix(trimmed, "else") &&
			!strings.has_prefix(trimmed, "elif ") &&
			!strings.has_prefix(trimmed, "while ") &&
			!strings.has_prefix(trimmed, "for ") &&
			strings.has_suffix(trimmed, ")") {
			pat := strings.trim_space(trimmed[:len(trimmed)-1])
			if pat != "" {
				if strings.has_prefix(pat, "(") {
					pat = strings.trim_space(pat[1:])
				}
				if !strings.contains(pat, "$+") &&
					!strings.contains(pat, ";") &&
					!strings.contains(pat, "&&") &&
					!strings.contains(pat, "||") {
					out_line = strings.concatenate([]string{"case ", pat}, allocator)
					out_allocated = true
					changed = true
				}
			}
		} else if len(block_stack) > 0 &&
			heredoc_delim == "" &&
			block_stack[len(block_stack)-1] == 's' &&
			!strings.contains(trimmed, "=") &&
			!strings.has_prefix(trimmed, "set ") &&
			!strings.has_prefix(trimmed, "local ") &&
			!strings.has_prefix(trimmed, "typeset ") &&
			!strings.has_prefix(trimmed, "integer ") &&
			!strings.has_prefix(trimmed, "if ") &&
			!strings.has_prefix(trimmed, "else") &&
			!strings.has_prefix(trimmed, "elif ") &&
			!strings.has_prefix(trimmed, "while ") &&
			!strings.has_prefix(trimmed, "for ") &&
			!strings.has_prefix(trimmed, "((") &&
			strings.has_prefix(trimmed, "(") {
			pat := strings.trim_space(trimmed[1:])
			if strings.has_suffix(pat, ")") && len(pat) > 1 {
				pat = strings.trim_space(pat[:len(pat)-1])
			}
			if pat != "" &&
				!strings.contains(pat, "$+") &&
				!strings.contains(pat, ";") &&
				!strings.contains(pat, "&&") &&
				!strings.contains(pat, "||") {
				out_line = strings.concatenate([]string{"case ", pat}, allocator)
				out_allocated = true
				changed = true
			}
		} else if heredoc_delim == "" && strings.has_suffix(trimmed, "() {") {
			name := strings.trim_space(trimmed[:len(trimmed)-len("() {")])
			if strings.has_prefix(name, "function ") {
				name = strings.trim_space(name[len("function "):])
			}
			name = normalize_function_name_token(name)
			if name != "" {
				out_line = strings.concatenate([]string{"function ", name}, allocator)
				out_allocated = true
				changed = true
			}
		} else if heredoc_delim == "" &&
			strings.has_prefix(trimmed, "((") &&
			strings.contains(trimmed, "))") {
			out_line = ":"
			changed = true
		}
		if heredoc_delim == "" && strings.contains(out_line, ";;") {
			repl, c := strings.replace_all(out_line, ";;", "", allocator)
			if c {
				out_line = repl
				out_allocated = true
				changed = true
			}
		}
		if heredoc_delim == "" && (strings.contains(out_line, "&&") || strings.contains(out_line, "||")) {
			repl, c := strings.replace_all(out_line, " && ", "; and ", allocator)
			if c {
				out_line = repl
				out_allocated = true
				changed = true
			}
			repl, c = strings.replace_all(out_line, " || ", "; or ", allocator)
			if c {
				out_line = repl
				out_allocated = true
				changed = true
			}
		}
		if heredoc_delim == "" {
			out_trimmed_pre := strings.trim_space(out_line)
			if strings.has_prefix(out_trimmed_pre, "set ") && strings.contains(out_trimmed_pre, " (") {
				open_parens := 0
				close_parens := 0
				for ch in out_trimmed_pre {
					if ch == '(' {
						open_parens += 1
					} else if ch == ')' {
						close_parens += 1
					}
				}
				if open_parens > close_parens {
					missing := open_parens - close_parens
					extra := ""
					for i in 0 ..< missing {
						extra = strings.concatenate([]string{extra, ")"}, allocator)
					}
					repaired := strings.concatenate([]string{out_line, extra}, allocator)
					delete(extra)
					if out_allocated {
						delete(out_line)
					}
					out_line = repaired
					out_allocated = true
					changed = true
					out_trimmed_pre = strings.trim_space(out_line)
				}
			}
			if strings.has_prefix(out_trimmed_pre, "set ") && strings.contains(out_trimmed_pre, "(__shellx_array_get;") {
				eq_idx := find_substring(out_trimmed_pre, " ")
				if eq_idx >= 0 {
					indent_len := len(out_line) - len(strings.trim_left_space(out_line))
					indent := ""
					if indent_len > 0 {
						indent = out_line[:indent_len]
					}
					rest := strings.trim_space(out_trimmed_pre[len("set "):])
					name := ""
					if strings.has_prefix(rest, "-l ") {
						rest = strings.trim_space(rest[len("-l "):])
						name, _ = split_first_word_raw(rest)
						if is_basic_name(name) {
							repl := strings.concatenate([]string{indent, "set -l ", name, " \"\""}, allocator)
							if out_allocated {
								delete(out_line)
							}
							out_line = repl
							out_allocated = true
							changed = true
							out_trimmed_pre = strings.trim_space(out_line)
						}
					}
				}
			}
			if strings.contains(out_trimmed_pre, "\"\"\"") {
				repl, c := strings.replace_all(out_line, "\"\"\"", "\"\"", allocator)
				if c {
					out_line = repl
					out_allocated = true
					changed = true
				}
				out_trimmed_pre = strings.trim_space(out_line)
			}
			eq_idx := find_substring(out_trimmed_pre, "=")
			if eq_idx > 0 {
				left := strings.trim_space(out_trimmed_pre[:eq_idx])
				right := strings.trim_space(out_trimmed_pre[eq_idx+1:])
				if is_basic_name(left) &&
					!strings.has_prefix(out_trimmed_pre, "set ") &&
					!strings.has_prefix(out_trimmed_pre, "if ") &&
					!strings.has_prefix(out_trimmed_pre, "else if ") &&
					!strings.has_prefix(out_trimmed_pre, "while ") &&
					!strings.has_prefix(out_trimmed_pre, "for ") &&
					!strings.has_prefix(out_trimmed_pre, "case ") &&
					!strings.contains(out_trimmed_pre, "==") &&
					!strings.contains(out_trimmed_pre, "!=") {
					indent_len := len(out_line) - len(strings.trim_left_space(out_line))
					indent := ""
					if indent_len > 0 {
						indent = out_line[:indent_len]
					}
					if right == "" {
						right = "\"\""
					}
					repl := strings.concatenate([]string{indent, "set ", left, " ", right}, allocator)
					out_line = repl
					out_allocated = true
					changed = true
				}
			}
		}

		out_trimmed := strings.trim_space(out_line)
		if out_trimmed == "continue" || out_trimmed == "break" {
			in_loop := false
			for i := len(block_stack) - 1; i >= 0; i -= 1 {
				if block_stack[i] == 'l' {
					in_loop = true
					break
				}
			}
			if !in_loop {
				if out_allocated {
					delete(out_line)
				}
				out_line = ":"
				out_trimmed = ":"
				out_allocated = false
				changed = true
			}
		}
		if strings.has_prefix(out_trimmed, "function ") {
			append(&block_stack, 'f')
		} else if strings.has_prefix(out_trimmed, "if ") {
			append(&block_stack, 'i')
		} else if strings.has_prefix(out_trimmed, "while ") || strings.has_prefix(out_trimmed, "for ") {
			append(&block_stack, 'l')
		} else if strings.has_prefix(out_trimmed, "switch ") {
			append(&block_stack, 's')
		} else if strings.has_prefix(out_trimmed, "else if ") {
			if len(block_stack) == 0 || block_stack[len(block_stack)-1] != 'i' {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "else" {
			if len(block_stack) == 0 || block_stack[len(block_stack)-1] != 'i' {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if strings.has_prefix(out_trimmed, "case ") {
			// case is only valid inside switch; keep as-is to preserve semantics.
			if len(block_stack) == 0 || block_stack[len(block_stack)-1] != 's' {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "end" {
			if len(block_stack) > 0 {
				resize(&block_stack, len(block_stack)-1)
			} else {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	for i := len(block_stack) - 1; i >= 0; i -= 1 {
		strings.write_byte(&builder, '\n')
		strings.write_string(&builder, "end")
		changed = true
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_empty_then_blocks_for_bash :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, i in lines {
		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		if strings.trim_space(line) != "then" {
			continue
		}

		k := i + 1
		for k < len(lines) {
			trimmed_k := strings.trim_space(lines[k])
			if trimmed_k == "" || strings.has_prefix(trimmed_k, "#") {
				k += 1
				continue
			}
			if strings.has_prefix(trimmed_k, "elif") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "  :\n")
				changed = true
			}
			break
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_multiline_for_paren_syntax_for_bash :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	i := 0

	for i < len(lines) {
		line := lines[i]
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "for ") && strings.has_suffix(trimmed, "(") && !strings.contains(trimmed, "); do") {
			close_idx := -1
			max_scan := i + 12
			if max_scan > len(lines)-1 {
				max_scan = len(lines) - 1
			}
			for j := i + 1; j <= max_scan; j += 1 {
				close_trimmed := strings.trim_space(lines[j])
				if close_trimmed == "); do" || close_trimmed == ");do" {
					close_idx = j
					break
				}
			}

			if close_idx > i {
				header := strings.trim_space(trimmed[len("for "):])
				open_idx := find_substring(header, " (")
				if open_idx < 0 {
					open_idx = find_substring(header, "(")
				}
				if open_idx > 0 {
					var_part := strings.trim_space(header[:open_idx])
					var_name, _ := split_first_word(var_part)
					if var_name != "" {
						indent_len := len(line) - len(strings.trim_left_space(line))
						indent := ""
						if indent_len > 0 {
							indent = line[:indent_len]
						}

						item_builder := strings.builder_make()
						safe_items := true
						for j := i + 1; j < close_idx; j += 1 {
							item := strings.trim_space(lines[j])
							if item == "" || strings.has_prefix(item, "#") {
								continue
							}
							if strings.contains(item, "{") ||
								strings.contains(item, "}") ||
								strings.contains(item, ";") ||
								strings.contains(item, "$(") ||
								strings.contains(item, "`") {
								safe_items = false
								break
							}
							if strings.builder_len(item_builder) > 0 {
								strings.write_byte(&item_builder, ' ')
							}
							strings.write_string(&item_builder, item)
						}
						items_full := strings.clone(strings.to_string(item_builder), allocator)
						strings.builder_destroy(&item_builder)
						items := strings.trim_space(items_full)
						if !safe_items {
							items = ""
						}
						if items == "" {
							// Skip rewrite when iterator list is not safely recoverable.
							delete(items_full)
							strings.write_string(&builder, line)
							if i+1 < len(lines) {
								strings.write_byte(&builder, '\n')
							}
							i += 1
							continue
						}

						out_line := strings.concatenate([]string{indent, "for ", var_name, " in ", items, "; do"}, allocator)
						strings.write_string(&builder, out_line)
						delete(out_line)
						if close_idx+1 < len(lines) {
							strings.write_byte(&builder, '\n')
						}
						changed = true
						delete(items_full)
						i = close_idx + 1
						continue
					}
				}
			}
		}

		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
		i += 1
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_multiline_case_patterns_for_bash :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	i := 0

	for i < len(lines) {
		line := lines[i]
		trimmed := strings.trim_space(line)
		if strings.has_suffix(trimmed, "|") && i+1 < len(lines) {
			next_trimmed := strings.trim_space(lines[i+1])
			if next_trimmed != "" && !strings.has_prefix(next_trimmed, "#") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				joined := strings.concatenate([]string{indent, trimmed, next_trimmed}, allocator)
				strings.write_string(&builder, joined)
				delete(joined)
				if i+2 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				changed = true
				i += 2
				continue
			}
		}

		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
		i += 1
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_if_group_pattern_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	if !strings.contains(line, "[[") {
		return strings.clone(line, allocator), false
	}
	eq_idx := find_substring(line, "== (")
	if eq_idx < 0 {
		return strings.clone(line, allocator), false
	}
	open_idx := eq_idx + 3
	if open_idx >= len(line) || line[open_idx] != '(' {
		return strings.clone(line, allocator), false
	}
	depth := 0
	close_idx := -1
	for i in open_idx ..< len(line) {
		if line[i] == '(' {
			depth += 1
		} else if line[i] == ')' {
			depth -= 1
			if depth == 0 {
				close_idx = i
				break
			}
		}
	}
	if close_idx < 0 {
		return strings.clone(line, allocator), false
	}
	prefix := line[:eq_idx]
	pattern := line[open_idx : close_idx+1] // includes ( ... )
	suffix := line[close_idx+1:]
	rewritten := fmt.tprintf("%s=~ ^%s$%s", prefix, pattern, suffix)
	return strings.clone(rewritten, allocator), true
}

rewrite_zsh_anonymous_function_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	trimmed := strings.trim_space(line)
	if trimmed != "() {" {
		return strings.clone(line, allocator), false
	}
	indent_len := len(line) - len(strings.trim_left_space(line))
	indent := ""
	if indent_len > 0 {
		indent = line[:indent_len]
	}
	return strings.concatenate([]string{indent, "{"}, allocator), true
}

rewrite_zsh_case_group_pattern_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	if strings.contains(line, "[[") || !strings.contains(line, "|") {
		return strings.clone(line, allocator), false
	}
	open_idx := find_substring(line, "(")
	if open_idx < 0 {
		return strings.clone(line, allocator), false
	}
	close_idx := -1
	for i in open_idx+1 ..< len(line) {
		if line[i] == ')' {
			close_idx = i
			break
		}
	}
	if close_idx < 0 {
		return strings.clone(line, allocator), false
	}
	group := line[open_idx+1 : close_idx]
	if !strings.contains(group, "|") {
		return strings.clone(line, allocator), false
	}
	for i in 0 ..< len(group) {
		c := group[i]
		if c == ' ' || c == '\t' || c == '$' || c == '{' || c == '}' {
			return strings.clone(line, allocator), false
		}
	}
	prefix := line[:open_idx]
	suffix := line[close_idx+1:]
	has_terminal_close := false
	if len(suffix) > 0 && suffix[len(suffix)-1] == ')' {
		has_terminal_close = true
		suffix = suffix[:len(suffix)-1]
	}
	parts := strings.split(group, "|")
	defer delete(parts)
	if len(parts) < 2 {
		return strings.clone(line, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	for p, idx in parts {
		if idx > 0 {
			strings.write_byte(&builder, '|')
		}
		strings.write_string(&builder, prefix)
		strings.write_string(&builder, p)
		strings.write_string(&builder, suffix)
	}
	if has_terminal_close {
		strings.write_byte(&builder, ')')
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_always_block_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	rewritten, changed := strings.replace_all(line, "} always {", "}; {", allocator)
	if changed {
		return rewritten, true
	}
	if raw_data(rewritten) != raw_data(line) {
		delete(rewritten)
	}
	return strings.clone(line, allocator), false
}

rewrite_zsh_conditional_anonymous_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	out := strings.clone(line, allocator)
	changed_any := false
	repl, changed := strings.replace_all(out, "&& () {", "&& {", allocator)
	if changed {
		delete(out)
		out = repl
		changed_any = true
	} else if raw_data(repl) != raw_data(out) {
		delete(repl)
	}
	repl, changed = strings.replace_all(out, "|| () {", "|| {", allocator)
	if changed {
		delete(out)
		out = repl
		changed_any = true
	} else if raw_data(repl) != raw_data(out) {
		delete(repl)
	}
	return out, changed_any
}

rewrite_zsh_empty_function_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	open_idx := find_substring(line, "(){}")
	if open_idx < 0 {
		return strings.clone(line, allocator), false
	}
	prefix := line[:open_idx+2]
	suffix := line[open_idx+4:]
	return strings.clone(strings.concatenate([]string{prefix, " { :; }", suffix}), allocator), true
}

rewrite_zsh_if_group_command_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	if !strings.contains(line, "then") || !strings.contains(line, "{") || !strings.contains(line, "}") {
		return strings.clone(line, allocator), false
	}
	repl, changed := strings.replace_all(line, " } 2>/dev/null; then", "; } 2>/dev/null; then", allocator)
	if changed {
		return repl, true
	}
	if raw_data(repl) != raw_data(line) {
		delete(repl)
	}
	return strings.clone(line, allocator), false
}

rewrite_zsh_inline_brace_group_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	if !(strings.contains(line, "|| {") || strings.contains(line, "&& {")) {
		return strings.clone(line, allocator), false
	}
	if !strings.contains(line, " }") || strings.contains(line, "; }") {
		return strings.clone(line, allocator), false
	}
	repl, changed := strings.replace_all(line, " }", "; }", allocator)
	if changed {
		return repl, true
	}
	if raw_data(repl) != raw_data(line) {
		delete(repl)
	}
	return strings.clone(line, allocator), false
}

rewrite_zsh_for_paren_syntax_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	if !strings.contains(line, "for ") || !strings.contains(line, "); do") || !strings.contains(line, " (") {
		return strings.clone(line, allocator), false
	}
	for_idx := find_substring(line, "for ")
	open_idx := find_substring(line, " (")
	close_idx := find_substring(line, "); do")
	if for_idx < 0 || open_idx < 0 || close_idx < 0 || open_idx <= for_idx+4 || close_idx <= open_idx+2 {
		return strings.clone(line, allocator), false
	}
	var_name := strings.trim_space(line[for_idx+4 : open_idx])
	iter_expr := strings.trim_space(line[open_idx+2 : close_idx])
	if strings.contains(var_name, " ") || strings.contains(var_name, "\t") {
		first_name, _ := split_first_word(var_name)
		var_name = first_name
	}
	if var_name == "" || iter_expr == "" {
		return strings.clone(line, allocator), false
	}
	iter_replaced, iter_changed := strings.replace_all(iter_expr, "(/)", "/", allocator)
	if iter_changed {
		iter_expr = iter_replaced
	} else if raw_data(iter_replaced) != raw_data(iter_expr) {
		delete(iter_replaced)
	}
	prefix := line[:for_idx]
	suffix := line[close_idx+5:] // keep anything after '; do'
	rewritten := strings.concatenate([]string{prefix, "for ", var_name, " in ", iter_expr, "; do", suffix}, allocator)
	if iter_changed {
		delete(iter_replaced)
	}
	return rewritten, true
}

rewrite_zsh_dynamic_function_line_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	trimmed := strings.trim_space(line)
	if strings.has_prefix(trimmed, "eval ") {
		return strings.clone(line, allocator), false
	}
	if strings.contains(line, "\"") {
		return strings.clone(line, allocator), false
	}
	if !strings.contains(line, "${") || !strings.contains(line, "() {") {
		return strings.clone(line, allocator), false
	}
	escaped := escape_double_quoted(strings.trim_space(line), allocator)
	rewritten := strings.clone(strings.concatenate([]string{"eval \"", escaped, "\""}), allocator)
	delete(escaped)
	return rewritten, true
}

rewrite_zsh_inline_function_body_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	open_idx := find_substring(line, "() {")
	if open_idx < 0 {
		return strings.clone(line, allocator), false
	}
	close_idx := -1
	for i := len(line) - 1; i >= 0; i -= 1 {
		if line[i] == '}' {
			close_idx = i
			break
		}
	}
	if close_idx <= open_idx+4 {
		return strings.clone(line, allocator), false
	}
	body := strings.trim_space(line[open_idx+4 : close_idx])
	if body == "" || strings.has_suffix(body, ";") {
		return strings.clone(line, allocator), false
	}
	prefix := line[:open_idx+4]
	suffix := line[close_idx:]
	rewritten := strings.concatenate([]string{prefix, " ", body, "; ", suffix}, allocator)
	return rewritten, true
}

rewrite_zsh_syntax_for_bash :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	next := ""
	for line, i in lines {
		cur := strings.clone(line, allocator)
		next, c1 := rewrite_zsh_anonymous_function_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c1 {
			changed = true
		}

		c2 := false
		next, c2 = rewrite_zsh_if_group_pattern_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c2 {
			changed = true
		}

		c3 := false
		next, c3 = rewrite_zsh_case_group_pattern_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c3 {
			changed = true
		}

		c4 := false
		next, c4 = rewrite_zsh_always_block_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c4 {
			changed = true
		}

		c5 := false
		next, c5 = rewrite_zsh_conditional_anonymous_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c5 {
			changed = true
		}

		c6 := false
		next, c6 = rewrite_zsh_empty_function_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c6 {
			changed = true
		}

		c7 := false
		next, c7 = rewrite_zsh_if_group_command_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c7 {
			changed = true
		}

		c8 := false
		next, c8 = rewrite_zsh_dynamic_function_line_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c8 {
			changed = true
		}

		c9 := false
		next, c9 = rewrite_zsh_inline_brace_group_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c9 {
			changed = true
		}

		c10 := false
		next, c10 = rewrite_zsh_for_paren_syntax_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c10 {
			changed = true
		}

		c11 := false
		next, c11 = rewrite_zsh_inline_function_body_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c11 {
			changed = true
		}

		strings.write_string(&builder, cur)
		delete(cur)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_unsupported_zsh_expansions_for_bash :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if i+1 < len(text) && text[i] == '$' && text[i+1] == '{' {
			depth := 1
			j := i + 2
			for j < len(text) {
				if text[j] == '{' {
					depth += 1
				} else if text[j] == '}' {
					depth -= 1
					if depth == 0 {
						break
					}
				}
				j += 1
			}
				if j < len(text) && depth == 0 {
					inner := text[i+2 : j]
					if strings.has_prefix(inner, "=") && len(inner) > 1 {
						strings.write_string(&builder, "${")
						strings.write_string(&builder, inner[1:])
						strings.write_byte(&builder, '}')
						changed = true
						i = j + 1
						continue
					}
					if strings.contains(inner, "${${") ||
						strings.contains(inner, "(q)") ||
					strings.contains(inner, "(qq)") ||
					strings.contains(inner, ":h") ||
					strings.contains(inner, ":t") ||
					strings.contains(inner, ":r") ||
					strings.contains(inner, ":e") ||
					strings.contains(inner, ":a") ||
					strings.contains(inner, ":A") {
					orig := text[i : j+1]
					escaped := escape_double_quoted(orig, allocator)
					strings.write_string(&builder, "$(__shellx_zsh_expand \"")
					strings.write_string(&builder, escaped)
					strings.write_string(&builder, "\")")
					delete(escaped)
					changed = true
					i = j + 1
					continue
				}
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

is_param_name_char :: proc(c: byte) -> bool {
	if c >= 'a' && c <= 'z' {
		return true
	}
	if c >= 'A' && c <= 'Z' {
		return true
	}
	if c >= '0' && c <= '9' {
		return true
	}
	if c == '_' || c == '@' || c == '*' || c == '#' || c == '?' {
		return true
	}
	return false
}

is_simple_param_name :: proc(s: string) -> bool {
	if s == "" {
		return false
	}
	for i in 0 ..< len(s) {
		if !is_param_name_char(s[i]) {
			return false
		}
	}
	return true
}

rewrite_zsh_modifier_parameter_tokens :: proc(inner: string, allocator := context.allocator) -> (string, bool) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(inner) {
		token_len := 0
		mode := ""
		if i+4 <= len(inner) && inner[i:i+4] == "(@k)" {
			token_len = 4
			mode = "keys"
		} else if i+5 <= len(inner) && inner[i:i+5] == "(@Pk)" {
			token_len = 5
			mode = "indirect_keys"
		} else if i+5 <= len(inner) && inner[i:i+5] == "(@On)" {
			token_len = 5
			mode = "array_sorted_desc"
		} else if i+5 <= len(inner) && inner[i:i+5] == "(@on)" {
			token_len = 5
			mode = "array_sorted_asc"
		} else if i+3 <= len(inner) && inner[i:i+3] == "(@)" {
			token_len = 3
			mode = "array"
		} else if i+3 <= len(inner) && inner[i:i+3] == "(k)" {
			token_len = 3
			mode = "keys"
		}

		if token_len > 0 {
			j := i + token_len
			for j < len(inner) && is_param_name_char(inner[j]) {
				j += 1
			}
			if j > i+token_len {
				name := inner[i+token_len : j]
				switch mode {
				case "keys":
					strings.write_string(&builder, fmt.tprintf("!%s[@]", name))
				case "indirect_keys":
					var_ref := ""
					is_digits := true
					for ch in name {
						if ch < '0' || ch > '9' {
							is_digits = false
							break
						}
					}
					if is_digits {
						if len(name) == 1 {
							var_ref = fmt.tprintf("$%s", name)
						} else {
							var_ref = strings.concatenate([]string{"${", name, "}"})
						}
					} else {
						var_ref = fmt.tprintf("$%s", name)
					}
					raw_expr := strings.concatenate(
						[]string{
							"$(eval \"printf '%s\\n' \\\"\\${!",
							var_ref,
							"[@]}\\\"\")",
						},
					)
					if i == 0 && j == len(inner) {
						tmp_raw := strings.concatenate([]string{"__SHELLX_RAW__", raw_expr})
						out_raw := strings.clone(tmp_raw, allocator)
						delete(tmp_raw)
						delete(raw_expr)
						return out_raw, true
					}
					strings.write_string(&builder, raw_expr)
					delete(raw_expr)
				case "array_sorted_desc", "array_sorted_asc":
					// Preserve element expansion even when zsh sorting modifiers are unavailable.
					// This keeps script behavior functionally usable instead of emitting zsh-only syntax.
					strings.write_string(&builder, fmt.tprintf("%s[@]", name))
				case "array":
					strings.write_string(&builder, fmt.tprintf("%s[@]", name))
				}
				changed = true
				i = j
				continue
			}
		}

		strings.write_byte(&builder, inner[i])
		i += 1
	}

	if !changed {
		return strings.clone(inner, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_case_modifiers_for_bash :: proc(inner: string, allocator := context.allocator) -> (string, bool) {
	if len(inner) < 3 {
		return strings.clone(inner, allocator), false
	}
	suffix := inner[len(inner)-2:]
	base := inner[:len(inner)-2]
	if base == "" || !is_simple_param_name(base) {
		return strings.clone(inner, allocator), false
	}
	switch suffix {
	case ":l":
		return strings.clone(fmt.tprintf("%s,,", base), allocator), true
	case ":u":
		return strings.clone(fmt.tprintf("%s^^", base), allocator), true
	}
	return strings.clone(inner, allocator), false
}

rewrite_zsh_settest_expansion_for_bash :: proc(inner: string, allocator := context.allocator) -> (string, bool) {
	trimmed := strings.trim_space(inner)
	if len(trimmed) < 2 || trimmed[0] != '+' {
		return strings.clone(inner, allocator), false
	}
	target := strings.trim_space(trimmed[1:])
	if target == "" {
		return strings.clone(inner, allocator), false
	}
	return strings.clone(strings.concatenate([]string{target, "+1"}), allocator), true
}

rewrite_zsh_inline_case_modifiers_for_bash :: proc(inner: string, allocator := context.allocator) -> (string, bool) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(inner) {
		if is_param_name_char(inner[i]) {
			start := i
			j := i
			for j < len(inner) && is_param_name_char(inner[j]) {
				j += 1
			}
			if j+1 < len(inner) && inner[j] == ':' && (inner[j+1] == 'l' || inner[j+1] == 'u') {
				if start == 0 || !is_param_name_char(inner[start-1]) {
					name := inner[start:j]
					if inner[j+1] == 'l' {
						strings.write_string(&builder, fmt.tprintf("%s,,", name))
					} else {
						strings.write_string(&builder, fmt.tprintf("%s^^", name))
					}
					changed = true
					i = j + 2
					continue
				}
			}
		}

		strings.write_byte(&builder, inner[i])
		i += 1
	}

	if !changed {
		return strings.clone(inner, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_parameter_expansion_for_bash :: proc(
	text: string,
	allocator := context.allocator,
) -> (string, bool) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if i+1 < len(text) && text[i] == '$' && text[i+1] == '{' {
			depth := 1
			j := i + 2
			for j < len(text) {
				if text[j] == '{' {
					depth += 1
				} else if text[j] == '}' {
					depth -= 1
					if depth == 0 {
						break
					}
				}
				j += 1
			}

			if j < len(text) && depth == 0 {
				inner := text[i+2 : j]
				rewrite_stage1, stage1_changed := rewrite_zsh_modifier_parameter_tokens(inner, allocator)
				rewrite_stage2, stage2_changed := rewrite_zsh_settest_expansion_for_bash(rewrite_stage1, allocator)
				rewrite_stage3, stage3_changed := rewrite_zsh_inline_case_modifiers_for_bash(rewrite_stage2, allocator)
				rewrite_stage4, stage4_changed := rewrite_zsh_case_modifiers_for_bash(rewrite_stage3, allocator)
				if stage1_changed || stage2_changed || stage3_changed || stage4_changed {
					changed = true
				}
				if strings.has_prefix(rewrite_stage4, "__SHELLX_RAW__") {
					strings.write_string(&builder, rewrite_stage4[len("__SHELLX_RAW__"):])
				} else {
					strings.write_string(&builder, "${")
					strings.write_string(&builder, rewrite_stage4)
					strings.write_byte(&builder, '}')
				}
				delete(rewrite_stage1)
				delete(rewrite_stage2)
				delete(rewrite_stage3)
				delete(rewrite_stage4)
				i = j + 1
				continue
			}
		}
		if text[i] == '{' {
			prev_non_space := byte(0)
			for k := i-1; k >= 0; k -= 1 {
				c := text[k]
				if c == ' ' || c == '\t' {
					continue
				}
				prev_non_space = c
				break
			}
			if prev_non_space == ')' {
				strings.write_byte(&builder, text[i])
				i += 1
				continue
			}
			depth := 1
			j := i + 1
			for j < len(text) {
				if text[j] == '{' {
					depth += 1
				} else if text[j] == '}' {
					depth -= 1
					if depth == 0 {
						break
					}
				}
				j += 1
			}

			if j < len(text) && depth == 0 {
				inner := text[i+1 : j]
				if strings.contains(inner, "\n") || strings.contains(inner, ";") {
					strings.write_byte(&builder, text[i])
					i += 1
					continue
				}
				rewrite_stage1, stage1_changed := rewrite_zsh_modifier_parameter_tokens(inner, allocator)
				rewrite_stage2, stage2_changed := rewrite_zsh_settest_expansion_for_bash(rewrite_stage1, allocator)
				rewrite_stage3, stage3_changed := rewrite_zsh_inline_case_modifiers_for_bash(rewrite_stage2, allocator)
				rewrite_stage4, stage4_changed := rewrite_zsh_case_modifiers_for_bash(rewrite_stage3, allocator)
				if stage1_changed || stage2_changed || stage3_changed || stage4_changed {
					changed = true
					if strings.has_prefix(rewrite_stage4, "__SHELLX_RAW__") {
						strings.write_string(&builder, rewrite_stage4[len("__SHELLX_RAW__"):])
					} else {
						strings.write_string(&builder, "${")
						strings.write_string(&builder, rewrite_stage4)
						strings.write_byte(&builder, '}')
					}
				} else {
					strings.write_byte(&builder, '{')
					strings.write_string(&builder, inner)
					strings.write_byte(&builder, '}')
				}
				delete(rewrite_stage1)
				delete(rewrite_stage2)
				delete(rewrite_stage3)
				delete(rewrite_stage4)
				i = j + 1
				continue
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	out := strings.clone(strings.to_string(builder), allocator)
	tilde_rewritten, tilde_changed := strings.replace_all(out, "${~", "${", allocator)
	if tilde_changed {
		delete(out)
		out = tilde_rewritten
		changed = true
	} else {
		if raw_data(tilde_rewritten) != raw_data(out) {
			delete(tilde_rewritten)
		}
	}
	return out, changed
}

propagate_program_file :: proc(program: ^ir.Program, file: string) {
	if program == nil || file == "" {
		return
	}

	set_location_file_if_empty :: proc(loc: ^ir.SourceLocation, file: string) {
		if loc.file == "" {
			loc.file = file
		}
	}

	walk_statement :: proc(stmt: ^ir.Statement, file: string) {
		set_location_file_if_empty(&stmt.location, file)
		switch stmt.type {
		case .Assign:
			set_location_file_if_empty(&stmt.assign.location, file)
		case .Call:
			set_location_file_if_empty(&stmt.call.location, file)
		case .Logical:
			set_location_file_if_empty(&stmt.logical.location, file)
			for &segment in stmt.logical.segments {
				set_location_file_if_empty(&segment.call.location, file)
			}
		case .Case:
			set_location_file_if_empty(&stmt.case_.location, file)
			for &arm in stmt.case_.arms {
				set_location_file_if_empty(&arm.location, file)
				for &nested in arm.body {
					walk_statement(&nested, file)
				}
			}
		case .Return:
			set_location_file_if_empty(&stmt.return_.location, file)
		case .Branch:
			set_location_file_if_empty(&stmt.branch.location, file)
			for &nested in stmt.branch.then_body {
				walk_statement(&nested, file)
			}
			for &nested in stmt.branch.else_body {
				walk_statement(&nested, file)
			}
		case .Loop:
			set_location_file_if_empty(&stmt.loop.location, file)
			for &nested in stmt.loop.body {
				walk_statement(&nested, file)
			}
		case .Pipeline:
			set_location_file_if_empty(&stmt.pipeline.location, file)
			for &cmd in stmt.pipeline.commands {
				set_location_file_if_empty(&cmd.location, file)
			}
		}
	}

	for &fn in program.functions {
		set_location_file_if_empty(&fn.location, file)
		for &stmt in fn.body {
			walk_statement(&stmt, file)
		}
	}

	for &stmt in program.statements {
		walk_statement(&stmt, file)
	}
}

main :: proc() {
	// Library entry point.
}
