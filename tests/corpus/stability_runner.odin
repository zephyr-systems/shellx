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
	rule_ids:    [dynamic]string,
}

RuleFailureGroup :: struct {
	pair_label: string,
	rule_id:    string,
	count:      int,
	examples:   [dynamic]string,
}

contains_string :: proc(items: []string, value: string) -> bool {
	for item in items {
		if item == value {
			return true
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
			}
			for w in tr.warnings {
				if strings.has_prefix(w, "Parse diagnostic at ") {
					out.parse_warning_count += 1
				} else {
					out.compat_warning_count += 1
				}
			}
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
			if !tr.success && len(out.rule_ids) > 0 {
				pair_label := fmt.tprintf("%s->%s", dialect_name(c.from), dialect_name(to))
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
				"- [WARN] %s %s->%s warnings=%d(parse=%d compat=%d) shims=%d src_fn=%d out_fn=%d path=%s\n",
				outcome.case_.name,
				dialect_name(outcome.case_.from),
				dialect_name(outcome.to),
				outcome.warning_count,
				outcome.parse_warning_count,
				outcome.compat_warning_count,
				outcome.shim_count,
				outcome.source_functions,
				outcome.target_functions,
				outcome.case_.path,
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
