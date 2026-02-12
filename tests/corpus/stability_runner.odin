package main

import shellx "../.."
import "../../frontend"
import "../../ir"
import "core:fmt"
import "core:os"
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
	plugin_success: int,
	theme_success: int,

	with_source_functions: int,
	with_target_functions: int,
	with_shims: int,

	total_warnings: int,
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

	source_len: int,
	output_len: int,

	source_functions: int,
	target_functions: int,

	warning_count: int,
	error_count: int,
	shim_count: int,
	error_code: shellx.Error,
	first_error: string,
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

	total_runs := 0
	for c in cases {
		if !os.is_file(c.path) {
			continue
		}

		data, ok := os.read_entire_file(c.path)
		if !ok {
			continue
		}
		source_code := string(data)
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

			tr := shellx.translate(source_code, c.from, to)
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
			}
			if len(tr.errors) > 0 {
				out.first_error = tr.errors[0].message
			}

			summary.total_warnings += out.warning_count
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

	report := strings.builder_make()
	defer strings.builder_destroy(&report)

	strings.write_string(&report, "# ShellX Corpus Stability Report\n\n")
	strings.write_string(&report, fmt.tprintf("Cases configured: %d\n\n", len(cases)))
	strings.write_string(&report, fmt.tprintf("Cross-dialect runs executed: %d\n\n", total_runs))
	strings.write_string(&report, "## Pair Summary\n\n")
	strings.write_string(&report, "| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Avg Size Ratio | Avg Fn Ratio | With Shims |\n")
	strings.write_string(&report, "|---|---:|---:|---:|---:|---:|---:|---:|---:|\n")

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
				"| %s->%s | %d | %d/%d | %d/%d | %d/%d | %d/%d | %.3f | %.3f | %d |\n",
				dialect_name(s.key.from),
				dialect_name(s.key.to),
				s.total_cases,
				s.translate_success, s.total_cases,
				s.parse_success, s.total_cases,
				s.plugin_success, s.plugin_cases,
				s.theme_success, s.theme_cases,
				avg_size_ratio,
				avg_fn_ratio,
				s.with_shims,
			),
		)
	}

	strings.write_string(&report, "\n## Failures\n\n")
	for outcome in outcomes {
		if outcome.translate_success && outcome.parse_success {
			continue
		}
		strings.write_string(
			&report,
			fmt.tprintf(
				"- [FAIL] %s (%s) %s->%s translate=%v parse=%v err=%v warnings=%d shims=%d src_fn=%d out_fn=%d msg=%s path=%s\n",
				outcome.case_.name,
				outcome.case_.kind,
				dialect_name(outcome.case_.from),
				dialect_name(outcome.to),
				outcome.translate_success,
				outcome.parse_success,
				outcome.error_code,
				outcome.warning_count,
				outcome.shim_count,
				outcome.source_functions,
				outcome.target_functions,
				outcome.first_error,
				outcome.case_.path,
			),
		)
	}

	strings.write_string(&report, "\n## High Warning Runs\n\n")
	for outcome in outcomes {
		if outcome.warning_count < 20 {
			continue
		}
		strings.write_string(
			&report,
			fmt.tprintf(
				"- [WARN] %s %s->%s warnings=%d shims=%d src_fn=%d out_fn=%d path=%s\n",
				outcome.case_.name,
				dialect_name(outcome.case_.from),
				dialect_name(outcome.to),
				outcome.warning_count,
				outcome.shim_count,
				outcome.source_functions,
				outcome.target_functions,
				outcome.case_.path,
			),
		)
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
