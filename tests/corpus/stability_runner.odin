package main

import shellx "../.."
import "../../frontend"
import "../../ir"
import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:strings"

Case :: struct {
	name: string,
	kind: string, // plugin|theme
	path: string,
	from: shellx.ShellDialect,
}

PairKey :: struct {
	from: shellx.ShellDialect,
	to:   shellx.ShellDialect,
}

PairSummary :: struct {
	key: PairKey,

	total_cases: int,
	plugin_cases: int,
	theme_cases: int,

	translate_success: int,
	parse_success: int,
	parser_matrix_success: int,
	parser_matrix_ran: int,
	parser_matrix_skipped: int,
	plugin_success: int,
	theme_success: int,

	with_source_functions: int,
	with_target_functions: int,
	with_shims: int,

	total_warnings: int,
	parse_warnings: int,
	compat_warnings: int,
	total_errors: int,
	total_shims: int,

	total_size_ratio: f64,
	size_ratio_cases: int,

	total_fn_ratio: f64,
	fn_ratio_cases: int,
}

CaseOutcome :: struct {
	case_: Case,
	to: shellx.ShellDialect,

	exists:            bool,
	translate_success: bool,
	parse_success:     bool,
	parser_ran:        bool,
	parser_success:    bool,
	parser_command:    string,
	parser_exit_code:  int,
	parser_message:    string,

	source_len: int,
	output_len: int,

	source_functions: int,
	target_functions: int,

	warning_count: int,
	parse_warning_count: int,
	compat_warning_count: int,
	error_count: int,
	shim_count: int,
	error_code: shellx.Error,
	first_error: string,
	first_rule:  string,
	warning_summary: string,
	rule_ids:    [dynamic]string,
	shim_ids:    [dynamic]string,
}

RuleFailureGroup :: struct {
	pair_label: string,
	rule_id:    string,
	count:      int,
	examples:   [dynamic]string,
}

WarningGroup :: struct {
	pair_label: string,
	category:   string,
	rule_id:    string,
	count:      int,
	examples:   [dynamic]string,
}

SemanticCase :: struct {
	name:   string,
	source: string,
	source_path: string,
	probe: string,
	probe_source: string,
	probe_target: string,
	required_probe_markers: []string,
	module_mode: bool,
	from:   shellx.ShellDialect,
	to:     shellx.ShellDialect,
}

SemanticOutcome :: struct {
	name:      string,
	from:      shellx.ShellDialect,
	to:        shellx.ShellDialect,
	ran:       bool,
	pass:      bool,
	skipped:   bool,
	reason:    string,
	src_exit:  int,
	dst_exit:  int,
	src_out:   string,
	dst_out:   string,
	src_err:   string,
	dst_err:   string,
}

contains_string :: proc(items: []string, value: string) -> bool {
	for item in items {
		if item == value {
			return true
		}
	}
	return false
}

has_any_feature :: proc(items: []string, candidates: []string) -> bool {
	for item in items {
		for candidate in candidates {
			if item == candidate {
				return true
			}
		}
	}
	return false
}

rule_group_ptr :: proc(groups: ^[dynamic]RuleFailureGroup, pair_label: string, rule_id: string) -> ^RuleFailureGroup {
	for &group in groups^ {
		if group.pair_label == pair_label && group.rule_id == rule_id {
			return &group
		}
	}
	append(groups, RuleFailureGroup{
		pair_label = pair_label,
		rule_id = rule_id,
		examples = make([dynamic]string, 0, 4),
	})
	return &groups^[len(groups^)-1]
}

warning_group_ptr :: proc(groups: ^[dynamic]WarningGroup, pair_label: string, category: string, rule_id: string) -> ^WarningGroup {
	for &group in groups^ {
		if group.pair_label == pair_label && group.category == category && group.rule_id == rule_id {
			return &group
		}
	}
	append(groups, WarningGroup{
		pair_label = pair_label,
		category = category,
		rule_id = rule_id,
		examples = make([dynamic]string, 0, 5),
	})
	return &groups^[len(groups^)-1]
}

extract_compat_rule_id :: proc(warning: string) -> string {
	if !strings.has_prefix(warning, "Compat[") {
		return ""
	}
	open := len("Compat[")
	close_rel := strings.index_byte(warning[open:], ']')
	if close_rel < 0 {
		return ""
	}
	rule := strings.trim_space(warning[open : open+close_rel])
	return strings.clone(rule, context.allocator)
}

categorize_warning :: proc(warning: string) -> (string, string) {
	if strings.has_prefix(warning, "Parse diagnostic at ") {
		return "parse_recovery", "parse_diagnostic"
	}

	compat_rule := extract_compat_rule_id(warning)
	if compat_rule != "" {
		switch compat_rule {
		case "arrays_lists", "indexed_arrays", "assoc_arrays", "fish_list_indexing":
			return "arrays_maps", compat_rule
		case "hooks_events", "zsh_hooks", "fish_events", "prompt_hooks":
			return "hook_event", compat_rule
		case "condition_semantics":
			return "condition_test", compat_rule
		case "parameter_expansion":
			return "parameter_expansion", compat_rule
		case "process_substitution":
			return "process_substitution", compat_rule
		case "source", "source_builtin":
			return "source_loading", compat_rule
		case:
			return "compat_shim_inserted", compat_rule
		}
	}

	if strings.contains(warning, "fallback") {
		return "recovery_fallback", "fallback"
	}
	if strings.contains(warning, "preserve_comments") {
		return "option_notice", "preserve_comments"
	}

	return "general_warning", "general"
}

file_ext_for_dialect :: proc(dialect: shellx.ShellDialect) -> string {
	switch dialect {
	case .Fish:
		return "fish"
	case .Zsh:
		return "zsh"
	case .Bash:
		return "bash"
	case .POSIX:
		return "sh"
	}
	return "sh"
}

runtime_shell_for_dialect :: proc(dialect: shellx.ShellDialect) -> string {
	switch dialect {
	case .Fish:
		return "fish"
	case .Zsh:
		return "zsh"
	case .Bash:
		return "bash"
	case .POSIX:
		return "sh"
	}
	return "sh"
}

has_shell_binary :: proc(bin: string) -> bool {
	state, _, _, err := os2.process_exec(os2.Process_Desc{command = []string{"sh", "-lc", fmt.tprintf("command -v %s >/dev/null 2>&1", bin)}}, context.temp_allocator)
	return err == nil && state.exit_code == 0
}

run_runtime_script :: proc(dialect: shellx.ShellDialect, script: string, label: string) -> (ran: bool, exit_code: int, out: string, err_out: string, reason: string) {
	bin := runtime_shell_for_dialect(dialect)
	if !has_shell_binary(bin) {
		return false, -1, "", "", fmt.tprintf("missing runtime shell: %s", bin)
	}
	path := fmt.tprintf("tests/corpus/.semantic_%s.%s", label, file_ext_for_dialect(dialect))
	if !os.write_entire_file(path, transmute([]byte)script) {
		return false, -1, "", "", "failed to write semantic temp script"
	}
	defer os.remove(path)
	cmd := make([dynamic]string, 0, 6, context.temp_allocator)
	defer delete(cmd)
	if dialect == .Fish {
		append(&cmd, "env")
		append(&cmd, "XDG_DATA_HOME=/tmp")
		append(&cmd, "XDG_CONFIG_HOME=/tmp")
		append(&cmd, bin, path)
	} else {
		append(&cmd, bin, path)
	}
	state, stdout, stderr, perr := os2.process_exec(os2.Process_Desc{command = cmd[:]}, context.allocator)
	defer delete(stdout)
	defer delete(stderr)
	if perr != nil {
		return false, -1, "", "", fmt.tprintf("runtime execution error: %v", perr)
	}
	return true, state.exit_code, strings.clone(strings.trim_space(string(stdout)), context.allocator), strings.clone(strings.trim_space(string(stderr)), context.allocator), ""
}

run_runtime_module_script :: proc(
	dialect: shellx.ShellDialect,
	module_script: string,
	probe: string,
	label: string,
) -> (ran: bool, exit_code: int, out: string, err_out: string, reason: string) {
	module_path := fmt.tprintf("tests/corpus/.semantic_module_%s.%s", label, file_ext_for_dialect(dialect))
	if !os.write_entire_file(module_path, transmute([]byte)module_script) {
		return false, -1, "", "", "failed to write semantic module temp script"
	}
	defer os.remove(module_path)

	source_cmd := ""
	if dialect == .Fish {
		source_cmd = fmt.tprintf("source \"%s\"", module_path)
	} else {
		source_cmd = fmt.tprintf(". \"%s\"", module_path)
	}
	wrapper := strings.trim_space(strings.concatenate([]string{source_cmd, "\n", strings.trim_space(probe), "\n", ":\n"}, context.allocator))
	defer delete(wrapper)
	return run_runtime_script(dialect, wrapper, strings.concatenate([]string{label, "_wrapper"}, context.temp_allocator))
}

trim_report_text :: proc(s: string, max_len: int) -> string {
	if len(s) <= max_len {
		return s
	}
	if max_len <= 3 {
		return s[:max_len]
	}
	return strings.clone(strings.concatenate([]string{s[:max_len-3], "..."}), context.allocator)
}

run_semantic_case :: proc(c: SemanticCase) -> SemanticOutcome {
	source_text := c.source
	if c.source_path != "" {
		source_data, ok := os.read_entire_file(c.source_path)
		if !ok {
			return SemanticOutcome{
				name = c.name,
				from = c.from,
				to = c.to,
				skipped = true,
				reason = strings.clone(fmt.tprintf("missing semantic source path: %s", c.source_path), context.allocator),
			}
		}
		source_text = string(source_data)
	}

	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	tr := shellx.translate(source_text, c.from, c.to, opts)
	defer shellx.destroy_translation_result(&tr)

	outcome := SemanticOutcome{
		name = c.name,
		from = c.from,
		to = c.to,
	}
	if !tr.success {
		outcome.skipped = true
		outcome.reason = strings.clone(fmt.tprintf("translation failed: %v", tr.error), context.allocator)
		return outcome
	}

	src_label := fmt.tprintf("%s_src", c.name)
	dst_label := fmt.tprintf("%s_dst", c.name)
	src_ran := false
	src_exit := -1
	src_out := ""
	src_err := ""
	src_reason := ""
	dst_ran := false
	dst_exit := -1
	dst_out := ""
	dst_err := ""
	dst_reason := ""
	if c.module_mode {
		source_probe := c.probe
		if c.probe_source != "" {
			source_probe = c.probe_source
		}
		target_probe := c.probe
		if c.probe_target != "" {
			target_probe = c.probe_target
		}
		src_ran, src_exit, src_out, src_err, src_reason = run_runtime_module_script(c.from, source_text, source_probe, src_label)
		dst_ran, dst_exit, dst_out, dst_err, dst_reason = run_runtime_module_script(c.to, tr.output, target_probe, dst_label)
	} else {
		src_ran, src_exit, src_out, src_err, src_reason = run_runtime_script(c.from, source_text, src_label)
		dst_ran, dst_exit, dst_out, dst_err, dst_reason = run_runtime_script(c.to, tr.output, dst_label)
	}
	outcome.src_exit = src_exit
	outcome.dst_exit = dst_exit
	outcome.src_out = src_out
	outcome.dst_out = dst_out
	outcome.src_err = src_err
	outcome.dst_err = dst_err

	if !src_ran {
		outcome.skipped = true
		outcome.reason = src_reason
		return outcome
	}
	if !dst_ran {
		outcome.skipped = true
		outcome.reason = dst_reason
		return outcome
	}

	outcome.ran = true
	markers_ok := true
	for marker in c.required_probe_markers {
		if !strings.contains(src_out, marker) || !strings.contains(dst_out, marker) {
			markers_ok = false
			break
		}
	}
	outcome.pass = src_exit == dst_exit && src_out == dst_out && markers_ok
	if !outcome.pass {
		if !markers_ok {
			outcome.reason = strings.clone("probe marker missing in source/translated output", context.allocator)
		} else {
			outcome.reason = strings.clone("stdout/exit mismatch", context.allocator)
		}
	}
	return outcome
}

run_target_parser_check :: proc(
	output_code: string,
	target: shellx.ShellDialect,
	case_name: string,
	run_index: int,
) -> (ran: bool, ok: bool, command: string, exit_code: int, message: string) {
	temp_path := fmt.tprintf("tests/corpus/.parser_check_%s_%d.%s", case_name, run_index, file_ext_for_dialect(target))
	write_ok := os.write_entire_file(temp_path, transmute([]byte)output_code)
	if !write_ok {
		return false, false, "", -1, "failed to write parser temp file"
	}
	defer os.remove(temp_path)

	cmd := make([dynamic]string, 0, 3, context.temp_allocator)
	defer delete(cmd)
	switch target {
	case .Bash, .POSIX:
		append(&cmd, "bash", "-n", temp_path)
	case .Zsh:
		append(&cmd, "zsh", "-n", temp_path)
	case .Fish:
		append(&cmd, "fish", "--no-execute", temp_path)
	case:
		return false, false, "", -1, "no parser command for target dialect"
	}

	command = strings.join(cmd[:], " ", context.temp_allocator)
	desc := os2.Process_Desc{command = cmd[:]}
	state, _, stderr, err := os2.process_exec(desc, context.allocator)
	defer delete(stderr)

	if err != nil {
		return false, false, command, -1, fmt.tprintf("parser execution error: %v", err)
	}

	ran = true
	ok = state.exit_code == 0
	exit_code = state.exit_code
	if !ok {
		err_text := string(stderr)
		if len(err_text) > 400 {
			err_text = err_text[:400]
		}
		message = strings.clone(err_text, context.allocator)
	}
	return
}

dialect_name :: proc(d: shellx.ShellDialect) -> string {
	switch d {
	case .Bash:
		return "bash"
	case .Zsh:
		return "zsh"
	case .Fish:
		return "fish"
	case .POSIX:
		return "posix"
	}
	return "unknown"
}

make_analysis_arena :: proc(source_len: int) -> ir.Arena_IR {
	size := source_len * 8
	if size < 8*1024*1024 {
		size = 8 * 1024 * 1024
	}
	if size > 64*1024*1024 {
		size = 64 * 1024 * 1024
	}
	return ir.create_arena(size)
}

count_functions_for_dialect :: proc(dialect: shellx.ShellDialect, code: string) -> (int, bool) {
	arena := make_analysis_arena(len(code))
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(dialect)
	defer frontend.destroy_frontend(&fe)

	tree, perr := frontend.parse(&fe, code)
	if perr.error != .None || tree == nil {
		return 0, false
	}
	defer frontend.destroy_tree(tree)

	program, cerr := shellx.convert_to_ir(&arena, dialect, tree, code)
	if cerr.error != .None || program == nil {
		return 0, false
	}
	return len(program.functions), true
}

pair_summary_ptr :: proc(summaries: ^[dynamic]PairSummary, key: PairKey) -> ^PairSummary {
	for &summary in summaries^ {
		if summary.key.from == key.from && summary.key.to == key.to {
			return &summary
		}
	}
	append(summaries, PairSummary{key = key})
	return &summaries^[len(summaries^)-1]
}

main :: proc() {
	semantic_mode := false
	validation_debug := false
	for arg in os.args {
		if arg == "--semantic" {
			semantic_mode = true
			continue
		}
		if arg == "--validation-debug" {
			validation_debug = true
		}
	}

	cases := []Case{
		// Zsh plugins
		{"zsh-autosuggestions", "plugin", "tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh", .Zsh},
		{"zsh-syntax-highlighting", "plugin", "tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh", .Zsh},
		{"ohmyzsh-git", "plugin", "tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh", .Zsh},
		{"ohmyzsh-z", "plugin", "tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh", .Zsh},
		{"ohmyzsh-fzf", "plugin", "tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh", .Zsh},
		{"ohmyzsh-sudo", "plugin", "tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh", .Zsh},
		{"ohmyzsh-extract", "plugin", "tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh", .Zsh},
		{"ohmyzsh-colored-man-pages", "plugin", "tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh", .Zsh},
		{"ohmyzsh-web-search", "plugin", "tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh", .Zsh},
		{"ohmyzsh-copyfile", "plugin", "tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh", .Zsh},
		{"zsh-abbr", "plugin", "tests/corpus/repos/zsh/zsh-abbr/zsh-abbr.plugin.zsh", .Zsh},
		{"zsh-history-substring-search", "plugin", "tests/corpus/repos/zsh/zsh-history-substring-search/zsh-history-substring-search.plugin.zsh", .Zsh},
		{"zsh-you-should-use", "plugin", "tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh", .Zsh},
		{"zsh-nvm", "plugin", "tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh", .Zsh},
		{"zsh-pyenv", "plugin", "tests/corpus/repos/zsh/zsh-pyenv/zsh-pyenv.plugin.zsh", .Zsh},
		{"zsh-completions", "plugin", "tests/corpus/repos/zsh/zsh-completions/zsh-completions.plugin.zsh", .Zsh},

		// Bash-it plugins
		{"bashit-git", "plugin", "tests/corpus/repos/bash/bash-it/plugins/available/git.plugin.bash", .Bash},
		{"bashit-aliases", "plugin", "tests/corpus/repos/bash/bash-it/completion/available/aliases.completion.bash", .Bash},
		{"bashit-completion", "plugin", "tests/corpus/repos/bash/bash-it/completion/available/bash-it.completion.bash", .Bash},
		{"bashit-base", "plugin", "tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash", .Bash},
		{"bashit-fzf", "plugin", "tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash", .Bash},
		{"bashit-tmux", "plugin", "tests/corpus/repos/bash/bash-it/plugins/available/tmux.plugin.bash", .Bash},
		{"bashit-history", "plugin", "tests/corpus/repos/bash/bash-it/plugins/available/history.plugin.bash", .Bash},
		{"bashit-ssh", "plugin", "tests/corpus/repos/bash/bash-it/plugins/available/ssh.plugin.bash", .Bash},
		{"bashit-docker", "plugin", "tests/corpus/repos/bash/bash-it/plugins/available/docker.plugin.bash", .Bash},
		{"bashit-general", "plugin", "tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash", .Bash},
		{"bashit-proxy", "plugin", "tests/corpus/repos/bash/bash-it/plugins/available/proxy.plugin.bash", .Bash},
		{"bashit-nvm-completion", "plugin", "tests/corpus/repos/bash/bash-it/completion/available/nvm.completion.bash", .Bash},
		{"bashit-trap", "plugin", "tests/corpus/repos/bash/bash-it/plugins/available/trap.plugin.bash", .Bash},
		{"bashit-backup", "plugin", "tests/corpus/repos/bash/bash-it/plugins/available/backup.plugin.bash", .Bash},

		// Fish plugins
		{"fish-z", "plugin", "tests/corpus/repos/fish/z/conf.d/z.fish", .Fish},
		{"fish-fzf", "plugin", "tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish", .Fish},
		{"fish-tide", "plugin", "tests/corpus/repos/fish/tide/conf.d/_tide_init.fish", .Fish},
		{"fish-done", "plugin", "tests/corpus/repos/fish/done/conf.d/done.fish", .Fish},
		{"fish-replay", "plugin", "tests/corpus/repos/fish/replay.fish/functions/replay.fish", .Fish},
		{"fish-spark", "plugin", "tests/corpus/repos/fish/spark.fish/functions/spark.fish", .Fish},
		{"fish-autopair", "plugin", "tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish", .Fish},
		{"fish-colored-man-pages", "plugin", "tests/corpus/repos/fish/colored_man_pages.fish/functions/man.fish", .Fish},
		{"fish-gitnow", "plugin", "tests/corpus/repos/fish/gitnow/conf.d/gitnow.fish", .Fish},
		{"fish-fisher", "plugin", "tests/corpus/repos/fish/fisher/functions/fisher.fish", .Fish},
		{"fish-async-prompt", "plugin", "tests/corpus/repos/fish/fish-async-prompt/conf.d/__async_prompt.fish", .Fish},
		{"fish-ssh-agent", "plugin", "tests/corpus/repos/fish/fish-ssh-agent/conf.d/halostatue_fish_ssh_agent.fish", .Fish},
		{"fish-completion-sync", "plugin", "tests/corpus/repos/fish/fish-completion-sync/init.fish", .Fish},

		// Themes
		{"zsh-powerlevel10k", "theme", "tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme", .Zsh},
		{"zsh-agnoster", "theme", "tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme", .Zsh},
		{"zsh-eastwood", "theme", "tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme", .Zsh},
		{"zsh-spaceship", "theme", "tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme", .Zsh},
		{"zsh-gnzh", "theme", "tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme", .Zsh},

		{"bashit-bobby-theme", "theme", "tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash", .Bash},
		{"bashit-atomic-theme", "theme", "tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash", .Bash},
		{"bashit-brainy-theme", "theme", "tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash", .Bash},
		{"bashit-candy-theme", "theme", "tests/corpus/repos/bash/bash-it/themes/candy/candy.theme.bash", .Bash},
		{"bashit-envy-theme", "theme", "tests/corpus/repos/bash/bash-it/themes/envy/envy.theme.bash", .Bash},

		{"fish-tide-theme", "theme", "tests/corpus/repos/fish/tide/functions/fish_prompt.fish", .Fish},
		{"fish-starship-init", "theme", "tests/corpus/repos/fish/starship/install/install.sh", .Bash},
	}
	targets := []shellx.ShellDialect{.Bash, .Zsh, .Fish, .POSIX}

	outcomes := make([dynamic]CaseOutcome, 0, 256)
	defer delete(outcomes)

	summaries := make([dynamic]PairSummary, 0, 16)
	defer delete(summaries)

	rule_groups := make([dynamic]RuleFailureGroup, 0, 32)
	defer delete(rule_groups)
	warning_groups := make([dynamic]WarningGroup, 0, 64)
	defer delete(warning_groups)

	total_runs := 0
	for c in cases {
		if !os.is_file(c.path) {
			continue
		}

		data, ok := os.read_entire_file(c.path)
		if !ok {
			continue
		}
		source_code := strings.clone(string(data), context.allocator)
		source_len := len(data)
		delete(data)

		source_functions, source_stats_ok := count_functions_for_dialect(c.from, source_code)
		if !source_stats_ok {
			source_functions = 0
		}

		for to in targets {
			if to == c.from {
				continue
			}

			total_runs += 1
			key := PairKey{from = c.from, to = to}
			summary := pair_summary_ptr(&summaries, key)
			summary.total_cases += 1
			if c.kind == "plugin" {
				summary.plugin_cases += 1
			} else if c.kind == "theme" {
				summary.theme_cases += 1
			}

			opts := shellx.DEFAULT_TRANSLATION_OPTIONS
			opts.insert_shims = true
			tr := shellx.translate(source_code, c.from, to, opts)
			if validation_debug && !tr.success {
				for err_ctx in tr.errors {
					if !strings.has_prefix(err_ctx.rule_id, "lowering.") {
						continue
					}
					fmt.eprintln("VALIDATION FAILED:", err_ctx.rule_id, "at", fmt.tprintf("%s:%d:%d", err_ctx.location.file, err_ctx.location.line, err_ctx.location.column+1))
					fmt.eprintln("Suggestion:", err_ctx.suggestion)
					if err_ctx.snippet != "" {
						fmt.eprintln("Snippet:", err_ctx.snippet)
					}
					os.exit(-1)
				}
			}
			out := CaseOutcome{
				case_ = c,
				to = to,
				exists = true,
				source_len = source_len,
				source_functions = source_functions,
				warning_count = len(tr.warnings),
				error_count = len(tr.errors),
				shim_count = len(tr.required_shims),
				error_code = tr.error,
				rule_ids = make([dynamic]string, 0, 4),
				shim_ids = make([dynamic]string, 0, 4),
			}
			warn_rules := make([dynamic]string, 0, 8, context.temp_allocator)
			warn_rule_counts := make([dynamic]int, 0, 8, context.temp_allocator)
			pair_label := fmt.tprintf("%s->%s", dialect_name(c.from), dialect_name(to))
			for w in tr.warnings {
				if strings.has_prefix(w, "Parse diagnostic at ") {
					out.parse_warning_count += 1
				} else {
					out.compat_warning_count += 1
				}
				category, rule_id := categorize_warning(w)
				group := warning_group_ptr(&warning_groups, pair_label, category, rule_id)
				group.count += 1
				if len(group.examples) < 5 {
					example := fmt.tprintf("%s (%s) %s", c.name, c.kind, trim_report_text(w, 120))
					append(&group.examples, strings.clone(example, context.allocator))
				}

				found := false
				for rule, i in warn_rules {
					if rule != rule_id {
						continue
					}
					warn_rule_counts[i] += 1
					found = true
					break
				}
				if !found {
					append(&warn_rules, strings.clone(rule_id, context.temp_allocator))
					append(&warn_rule_counts, 1)
				}
			}
			if len(warn_rules) > 0 {
				summary_builder := strings.builder_make()
				for i := 0; i < len(warn_rules); i += 1 {
					if i > 0 {
						strings.write_string(&summary_builder, ", ")
					}
					fmt.sbprintf(&summary_builder, "%s=%d", warn_rules[i], warn_rule_counts[i])
				}
				out.warning_summary = strings.clone(strings.to_string(summary_builder), context.allocator)
				strings.builder_destroy(&summary_builder)
			}
			delete(warn_rules)
			delete(warn_rule_counts)
			if len(tr.errors) > 0 {
				out.first_error = strings.clone(tr.errors[0].message, context.allocator)
				out.first_rule = strings.clone(tr.errors[0].rule_id, context.allocator)
			}
			for err_ctx in tr.errors {
				if err_ctx.rule_id == "" {
					continue
				}
				if !contains_string(out.rule_ids[:], err_ctx.rule_id) {
					append(&out.rule_ids, strings.clone(err_ctx.rule_id, context.allocator))
				}
			}
			for shim in tr.required_shims {
				if shim == "" {
					continue
				}
				if !contains_string(out.shim_ids[:], shim) {
					append(&out.shim_ids, strings.clone(shim, context.allocator))
				}
			}
			if !tr.success && len(out.rule_ids) > 0 {
				for rule_id in out.rule_ids {
					group := rule_group_ptr(&rule_groups, pair_label, rule_id)
					group.count += 1
					if len(group.examples) < 5 {
						example := fmt.tprintf("%s (%s) path=%s", c.name, c.kind, c.path)
						if !contains_string(group.examples[:], example) {
							append(&group.examples, strings.clone(example, context.allocator))
						}
					}
				}
			}

			summary.total_warnings += out.warning_count
			summary.parse_warnings += out.parse_warning_count
			summary.compat_warnings += out.compat_warning_count
			summary.total_errors += out.error_count
			summary.total_shims += out.shim_count
			if out.shim_count > 0 {
				summary.with_shims += 1
			}

			out.translate_success = tr.success
			if tr.success {
				summary.translate_success += 1
				out.output_len = len(tr.output)

				if source_len > 0 {
					summary.total_size_ratio += f64(out.output_len) / f64(source_len)
					summary.size_ratio_cases += 1
				}

				fe := frontend.create_frontend(to)
				tree, perr := frontend.parse(&fe, tr.output)
				if perr.error == .None && tree != nil {
					out.parse_success = true
					summary.parse_success += 1
				}
				if tree != nil {
					frontend.destroy_tree(tree)
				}
				frontend.destroy_frontend(&fe)

				out.parser_ran, out.parser_success, out.parser_command, out.parser_exit_code, out.parser_message =
					run_target_parser_check(tr.output, to, c.name, total_runs)
				if out.parser_ran {
					summary.parser_matrix_ran += 1
					if out.parser_success {
						summary.parser_matrix_success += 1
					}
				} else {
					summary.parser_matrix_skipped += 1
				}

				target_functions, target_stats_ok := count_functions_for_dialect(to, tr.output)
				if target_stats_ok {
					out.target_functions = target_functions
					if source_functions > 0 {
						summary.with_source_functions += 1
						summary.total_fn_ratio += f64(target_functions) / f64(source_functions)
						summary.fn_ratio_cases += 1
						if target_functions > 0 {
							summary.with_target_functions += 1
						}
					}
				}

				if out.parse_success {
					if c.kind == "plugin" {
						summary.plugin_success += 1
					} else if c.kind == "theme" {
						summary.theme_success += 1
					}
				}
			}

			shellx.destroy_translation_result(&tr)
			append(&outcomes, out)
		}
		delete(source_code)
	}

	// Stable ordering by pair label.
	for i in 0 ..< len(summaries) {
		for j in i+1 ..< len(summaries) {
			a := fmt.tprintf("%s->%s", dialect_name(summaries[i].key.from), dialect_name(summaries[i].key.to))
			b := fmt.tprintf("%s->%s", dialect_name(summaries[j].key.from), dialect_name(summaries[j].key.to))
			if b < a {
				tmp := summaries[i]
				summaries[i] = summaries[j]
				summaries[j] = tmp
			}
		}
	}

	for i in 0 ..< len(rule_groups) {
		for j in i+1 ..< len(rule_groups) {
			a := fmt.tprintf("%s|%s", rule_groups[i].pair_label, rule_groups[i].rule_id)
			b := fmt.tprintf("%s|%s", rule_groups[j].pair_label, rule_groups[j].rule_id)
			if b < a {
				tmp := rule_groups[i]
				rule_groups[i] = rule_groups[j]
				rule_groups[j] = tmp
			}
		}
	}
	for i in 0 ..< len(warning_groups) {
		for j in i+1 ..< len(warning_groups) {
			a := fmt.tprintf("%s|%s|%s", warning_groups[i].pair_label, warning_groups[i].category, warning_groups[i].rule_id)
			b := fmt.tprintf("%s|%s|%s", warning_groups[j].pair_label, warning_groups[j].category, warning_groups[j].rule_id)
			if b < a {
				tmp := warning_groups[i]
				warning_groups[i] = warning_groups[j]
				warning_groups[j] = tmp
			}
		}
	}

	report := strings.builder_make()
	defer strings.builder_destroy(&report)

	strings.write_string(&report, "# ShellX Corpus Stability Report\n\n")
	strings.write_string(&report, fmt.tprintf("Cases configured: %d\n\n", len(cases)))
	strings.write_string(&report, fmt.tprintf("Cross-dialect runs executed: %d\n\n", total_runs))
	strings.write_string(&report, "## Pair Summary\n\n")
	strings.write_string(&report, "| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |\n")
	strings.write_string(&report, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n")

	for s in summaries {
		avg_size_ratio := 0.0
		if s.size_ratio_cases > 0 {
			avg_size_ratio = s.total_size_ratio / f64(s.size_ratio_cases)
		}
		avg_fn_ratio := 0.0
		if s.fn_ratio_cases > 0 {
			avg_fn_ratio = s.total_fn_ratio / f64(s.fn_ratio_cases)
		}

		strings.write_string(
			&report,
				fmt.tprintf(
					"| %s->%s | %d | %d/%d | %d/%d | %d/%d | %d | %d/%d | %d/%d | %d | %d | %.3f | %.3f | %d |\n",
					dialect_name(s.key.from),
					dialect_name(s.key.to),
					s.total_cases,
				s.translate_success, s.total_cases,
				s.parse_success, s.total_cases,
				s.parser_matrix_success, s.translate_success,
				s.parser_matrix_skipped,
				s.plugin_success, s.plugin_cases,
				s.theme_success, s.theme_cases,
				s.parse_warnings,
				s.compat_warnings,
				avg_size_ratio,
				avg_fn_ratio,
				s.with_shims,
			),
		)
	}

	strings.write_string(&report, "\n## Failures\n\n")
	for outcome in outcomes {
		if outcome.translate_success && outcome.parse_success && outcome.parser_ran && outcome.parser_success {
			continue
		}
		strings.write_string(
			&report,
			fmt.tprintf(
				"- [FAIL] %s (%s) %s->%s translate=%v parse=%v parser=%v/%v exit=%d err=%v warnings=%d(parse=%d compat=%d) shims=%d src_fn=%d out_fn=%d msg=%s parser_msg=%s path=%s\n",
				outcome.case_.name,
				outcome.case_.kind,
				dialect_name(outcome.case_.from),
				dialect_name(outcome.to),
				outcome.translate_success,
				outcome.parse_success,
				outcome.parser_success,
				outcome.parser_ran,
				outcome.parser_exit_code,
				outcome.error_code,
				outcome.warning_count,
				outcome.parse_warning_count,
				outcome.compat_warning_count,
				outcome.shim_count,
				outcome.source_functions,
				outcome.target_functions,
				outcome.first_error,
				outcome.parser_message,
				outcome.case_.path,
			),
		)
	}

	strings.write_string(&report, "\n## Parser Validation Failures\n\n")
	parser_failures := 0
	parser_skipped := 0
	for outcome in outcomes {
		if !outcome.translate_success {
			continue
		}
		if !outcome.parser_ran {
			parser_skipped += 1
			strings.write_string(
				&report,
				fmt.tprintf(
					"- [PARSER-SKIP] %s (%s) %s->%s command=`%s` message=%s path=%s\n",
					outcome.case_.name,
					outcome.case_.kind,
					dialect_name(outcome.case_.from),
					dialect_name(outcome.to),
					outcome.parser_command,
					outcome.parser_message,
					outcome.case_.path,
				),
			)
			continue
		}
		if outcome.parser_success {
			continue
		}
		parser_failures += 1
		strings.write_string(
			&report,
			fmt.tprintf(
				"- [PARSER-FAIL] %s (%s) %s->%s command=`%s` exit=%d message=%s path=%s\n",
				outcome.case_.name,
				outcome.case_.kind,
				dialect_name(outcome.case_.from),
				dialect_name(outcome.to),
				outcome.parser_command,
				outcome.parser_exit_code,
				outcome.parser_message,
				outcome.case_.path,
			),
		)
	}
	if parser_failures == 0 {
		strings.write_string(&report, "- No parser validation failures.\n")
	}
	if parser_skipped == 0 {
		strings.write_string(&report, "- No parser validation skips.\n")
	}

	strings.write_string(&report, "\n## High Warning Runs\n\n")
	for outcome in outcomes {
		if outcome.warning_count < 20 {
			continue
		}
		strings.write_string(
			&report,
			fmt.tprintf(
				"- [WARN] %s %s->%s warnings=%d(parse=%d compat=%d) shims=%d src_fn=%d out_fn=%d rules=%s path=%s\n",
				outcome.case_.name,
				dialect_name(outcome.case_.from),
				dialect_name(outcome.to),
				outcome.warning_count,
				outcome.parse_warning_count,
				outcome.compat_warning_count,
				outcome.shim_count,
				outcome.source_functions,
				outcome.target_functions,
				outcome.warning_summary,
				outcome.case_.path,
			),
		)
	}

	strings.write_string(&report, "\n## Warning Categories\n\n")
	if len(warning_groups) == 0 {
		strings.write_string(&report, "- No warnings recorded.\n")
	} else {
		current_pair := ""
		for group in warning_groups {
			if group.pair_label != current_pair {
				current_pair = group.pair_label
				strings.write_string(&report, fmt.tprintf("\n### %s\n\n", current_pair))
			}
			strings.write_string(
				&report,
				fmt.tprintf("- `%s/%s`: %d\n", group.category, group.rule_id, group.count),
			)
			for example in group.examples {
				strings.write_string(&report, fmt.tprintf("  - %s\n", example))
			}
		}
	}

	strings.write_string(&report, "\n## Semantic Parity Matrix\n\n")
	strings.write_string(&report, "| Pair | Cases | Arrays/Maps | Hooks/Events | Condition/Test | Param Expansion | Process Subst | Source |\n")
	strings.write_string(&report, "|---|---:|---:|---:|---:|---:|---:|---:|\n")

	arrays_keys := []string{"arrays_lists", "indexed_arrays", "assoc_arrays", "fish_list_indexing"}
	hooks_keys := []string{"hooks_events", "zsh_hooks", "fish_events", "prompt_hooks"}
	cond_keys := []string{"condition_semantics"}
	param_keys := []string{"parameter_expansion"}
	psub_keys := []string{"process_substitution"}
	source_keys := []string{"source", "source_builtin"}
	for s in summaries {
		pair_from := s.key.from
		pair_to := s.key.to
		arrays_count := 0
		hooks_count := 0
		cond_count := 0
		param_count := 0
		psub_count := 0
		source_count := 0
		for outcome in outcomes {
			if !outcome.exists {
				continue
			}
			if outcome.case_.from != pair_from || outcome.to != pair_to {
				continue
			}
			if has_any_feature(outcome.shim_ids[:], arrays_keys) {
				arrays_count += 1
			}
			if has_any_feature(outcome.shim_ids[:], hooks_keys) {
				hooks_count += 1
			}
			if has_any_feature(outcome.shim_ids[:], cond_keys) {
				cond_count += 1
			}
			if has_any_feature(outcome.shim_ids[:], param_keys) {
				param_count += 1
			}
			if has_any_feature(outcome.shim_ids[:], psub_keys) {
				psub_count += 1
			}
			if has_any_feature(outcome.shim_ids[:], source_keys) {
				source_count += 1
			}
		}
		strings.write_string(
			&report,
			fmt.tprintf(
				"| %s->%s | %d | %d | %d | %d | %d | %d | %d |\n",
				dialect_name(pair_from),
				dialect_name(pair_to),
				s.total_cases,
				arrays_count,
				hooks_count,
				cond_count,
				param_count,
				psub_count,
				source_count,
			),
		)
	}

	strings.write_string(&report, "\n## Validator Rule Failures\n\n")
	if len(rule_groups) == 0 {
		strings.write_string(&report, "- No validator rule failures.\n")
	} else {
		current_pair := ""
		for group in rule_groups {
			if group.pair_label != current_pair {
				current_pair = group.pair_label
				strings.write_string(&report, fmt.tprintf("\n### %s\n\n", current_pair))
			}
			strings.write_string(
				&report,
				fmt.tprintf("- `%s`: %d failures\n", group.rule_id, group.count),
			)
			for example in group.examples {
				strings.write_string(
					&report,
					fmt.tprintf("  - %s\n", example),
				)
			}
		}
	}

	if semantic_mode {
		semantic_cases := []SemanticCase{
			// Fish -> Bash/POSIX/Zsh patterns
			{
				name = "fish_gitnow_branch_compare",
				from = .Fish,
				to = .Bash,
				source = strings.trim_space(`
function __gitnow_current_branch_name
    echo main
end
set v_branch main
if test "$v_branch" = (__gitnow_current_branch_name)
    echo SAME
end
`),
			},
			{
				name = "fish_list_index_bash",
				from = .Fish,
				to = .Bash,
				source = strings.trim_space(`
set arr one two three
echo $arr[2]
`),
			},
			{
				name = "fish_list_index_posix",
				from = .Fish,
				to = .POSIX,
				source = strings.trim_space(`
set arr red blue green
echo $arr[3]
`),
			},
			{
				name = "fish_string_match_zsh",
				from = .Fish,
				to = .Zsh,
				source = strings.trim_space(`
set x foobar
if string match -q 'foo*' $x
    echo ok
end
`),
			},
			{
				name = "fish_string_match_bash",
				from = .Fish,
				to = .Bash,
				source = strings.trim_space(`
set x alpha
if string match -q 'a*' $x
    echo hit
end
`),
			},

			// Zsh -> Fish/Bash/POSIX patterns
			{
				name = "zsh_git_cmdsub_if_compare",
				from = .Zsh,
				to = .Fish,
				source = strings.trim_space(`
f() {
  local _commit=$(echo abc)
  if [ "$_commit" != "$(echo def)" ]; then
    echo ok
  fi
}
f
`),
			},
			{
				name = "zsh_param_default_callsite",
				from = .Zsh,
				to = .Fish,
				source = strings.trim_space(`
XDG_CACHE_HOME=""
echo ${XDG_CACHE_HOME:-/tmp/cache}
`),
			},
			{
				name = "zsh_repo_root_cmdsub",
				from = .Zsh,
				to = .Fish,
				source = strings.trim_space(`
git_toplevel() {
  local repo_root=$(echo /tmp/repo)
  if [ "$repo_root" = "" ]; then
    echo none
  else
    echo "$repo_root"
  fi
}
git_toplevel
`),
			},
			{
				name = "zsh_param_default_bash",
				from = .Zsh,
				to = .Bash,
				source = strings.trim_space(`
name=""
echo ${name:-fallback}
`),
			},
			{
				name = "zsh_assoc_array_bash",
				from = .Zsh,
				to = .Bash,
				source = strings.trim_space(`
typeset -A m
m[foo]=bar
echo ${m[foo]}
`),
			},
			{
				name = "zsh_case_posix",
				from = .Zsh,
				to = .POSIX,
				source = strings.trim_space(`
x=one
case "$x" in
  one) echo yes ;;
  *) echo no ;;
esac
`),
			},
			{
				name = "zsh_positional_fish",
				from = .Zsh,
				to = .Fish,
				source = strings.trim_space(`
f() {
  echo "$1-$2"
}
f a b
`),
			},

			// Bash -> Fish/Zsh/POSIX patterns
			{
				name = "bash_array_fish",
				from = .Bash,
				to = .Fish,
				source = strings.trim_space(`
arr=(one two three)
echo "${arr[1]}"
`),
			},
			{
				name = "bash_cond_fish",
				from = .Bash,
				to = .Fish,
				source = strings.trim_space(`
x=hello
if [[ "$x" == h* ]]; then
  echo ok
fi
`),
			},
			{
				name = "bash_param_default_fish",
				from = .Bash,
				to = .Fish,
				source = strings.trim_space(`
v=""
echo "${v:-fallback}"
`),
			},
			{
				name = "bash_function_zsh",
				from = .Bash,
				to = .Zsh,
				source = strings.trim_space(`
f() {
  echo done
}
f
`),
			},

			// POSIX -> Bash/Fish/Zsh patterns
			{
				name = "posix_if_fish",
				from = .POSIX,
				to = .Fish,
				source = strings.trim_space(`
x=1
if [ "$x" = "1" ]; then
  echo one
fi
`),
			},
			{
				name = "posix_default_zsh",
				from = .POSIX,
				to = .Zsh,
				source = strings.trim_space(`
name=""
echo "${name:-alt}"
`),
			},
			{
				name = "posix_case_bash",
				from = .POSIX,
				to = .Bash,
				source = strings.trim_space(`
x=a
case "$x" in
  a) echo match ;;
  *) echo miss ;;
esac
`),
			},

			// Plugin workflow module-level semantic checks
			{
				name = "plugin_ohmyzsh_z_zsh_to_bash",
				from = .Zsh,
				to = .Bash,
				source_path = "tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh",
				module_mode = true,
				probe = strings.trim_space(`
if command -v _z >/dev/null 2>&1; then
  echo HAVE__z
fi
if command -v z >/dev/null 2>&1; then
  echo HAVE_z
fi
`),
				required_probe_markers = []string{"HAVE_z"},
			},
			{
				name = "plugin_bashit_aliases_bash_to_posix",
				from = .Bash,
				to = .POSIX,
				source_path = "tests/corpus/repos/bash/bash-it/completion/available/aliases.completion.bash",
				module_mode = true,
				probe = strings.trim_space(`
if command -v _bash-it-component-completion-callback-on-init-aliases >/dev/null 2>&1; then
  echo HAVE_ALIAS_COMPLETION_CB
fi
`),
				required_probe_markers = []string{"HAVE_ALIAS_COMPLETION_CB"},
			},
			{
				name = "plugin_fish_autopair_fish_to_bash",
				from = .Fish,
				to = .Bash,
				source_path = "tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish",
				module_mode = true,
				probe_source = strings.trim_space(`
if command -v _autopair_fish_key_bindings >/dev/null 2>&1
  echo HAVE_AUTOPAIR_BIND
end
if command -v _autopair_uninstall >/dev/null 2>&1
  echo HAVE_AUTOPAIR_UNINSTALL
end
`),
				probe_target = strings.trim_space(`
if command -v _autopair_fish_key_bindings >/dev/null 2>&1; then
  echo HAVE_AUTOPAIR_BIND
fi
if command -v _autopair_uninstall >/dev/null 2>&1; then
  echo HAVE_AUTOPAIR_UNINSTALL
fi
`),
				required_probe_markers = []string{},
			},
		}

		outcomes := make([dynamic]SemanticOutcome, 0, len(semantic_cases))
		defer delete(outcomes)
		pass_count := 0
		skip_count := 0
		for c in semantic_cases {
			o := run_semantic_case(c)
			append(&outcomes, o)
			if o.skipped {
				skip_count += 1
			} else if o.pass {
				pass_count += 1
			}
		}

		strings.write_string(&report, "\n## Semantic Differential Checks\n\n")
		strings.write_string(&report, fmt.tprintf("Cases: %d, Passed: %d, Skipped: %d\n\n", len(semantic_cases), pass_count, skip_count))

		strings.write_string(&report, "### Semantic Pair Summary\n\n")
		strings.write_string(&report, "| Pair | Cases | Passed | Failed | Skipped |\n")
		strings.write_string(&report, "|---|---:|---:|---:|---:|\n")
		seen_pairs := make([dynamic]string, 0, 16, context.temp_allocator)
		defer delete(seen_pairs)
		for c in semantic_cases {
			pair_label := fmt.tprintf("%s->%s", dialect_name(c.from), dialect_name(c.to))
			if contains_string(seen_pairs[:], pair_label) {
				continue
			}
			append(&seen_pairs, pair_label)
			total := 0
			passed := 0
			failed := 0
			skipped := 0
			for o in outcomes {
				if o.from != c.from || o.to != c.to {
					continue
				}
				total += 1
				if o.skipped {
					skipped += 1
				} else if o.pass {
					passed += 1
				} else {
					failed += 1
				}
			}
			strings.write_string(
				&report,
				fmt.tprintf("| %s | %d | %d | %d | %d |\n", pair_label, total, passed, failed, skipped),
			)
		}
		strings.write_string(&report, "\n")

		for o in outcomes {
			if o.skipped {
				strings.write_string(
					&report,
					fmt.tprintf("- [SKIP] %s %s->%s reason=%s\n", o.name, dialect_name(o.from), dialect_name(o.to), o.reason),
				)
				continue
			}
			if o.pass {
				strings.write_string(
					&report,
					fmt.tprintf("- [PASS] %s %s->%s exit=%d out=%q\n", o.name, dialect_name(o.from), dialect_name(o.to), o.dst_exit, o.dst_out),
				)
				continue
			}
			strings.write_string(
				&report,
				fmt.tprintf(
					"- [FAIL] %s %s->%s src_exit=%d dst_exit=%d src_out=%q dst_out=%q src_err=%q dst_err=%q\n",
					o.name,
					dialect_name(o.from),
					dialect_name(o.to),
					o.src_exit,
					o.dst_exit,
					trim_report_text(o.src_out, 220),
					trim_report_text(o.dst_out, 220),
					trim_report_text(o.src_err, 220),
					trim_report_text(o.dst_err, 220),
				),
			)
		}
	}

	report_path := "tests/corpus/stability_report.md"
	write_ok := os.write_entire_file(report_path, transmute([]byte)strings.to_string(report))
	if !write_ok {
		fmt.println("failed to write stability report")
		os.exit(1)
	}

	fmt.println("Stability run complete.")
	fmt.println(fmt.tprintf("Report: %s", report_path))
	for s in summaries {
		fmt.println(
			fmt.tprintf(
				"%s->%s: translate=%d/%d parse=%d/%d with_shims=%d",
				dialect_name(s.key.from),
				dialect_name(s.key.to),
				s.translate_success,
				s.total_cases,
				s.parse_success,
				s.total_cases,
				s.with_shims,
			),
		)
	}
}
