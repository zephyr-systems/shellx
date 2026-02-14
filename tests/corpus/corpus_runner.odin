package main

import shellx "../.."
import "../../frontend"
import "core:fmt"
import "core:os"
import "core:strings"

Case :: struct {
	name: string,
	kind: string,
	path: string,
	from: shellx.ShellDialect,
}

CaseResult :: struct {
	case_:             Case,
	exists:            bool,
	translate_success: bool,
	bash_parse_success: bool,
	error:             shellx.Error,
	error_message:     string,
}

main :: proc() {
	cases := []Case {
		// Zsh plugins (list provided)
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
		{"zsh-autocomplete", "plugin", "tests/corpus/repos/zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh", .Zsh},
		{"zoxide-zsh", "plugin", "tests/corpus/repos/zsh/zoxide/zoxide.plugin.zsh", .Zsh},
		{"atuin-zsh", "plugin", "tests/corpus/repos/zsh/atuin/atuin.plugin.zsh", .Zsh},
		{"fast-syntax-highlighting", "plugin", "tests/corpus/repos/zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh", .Zsh},
		{"zsh-async", "plugin", "tests/corpus/repos/zsh/zsh-async/async.plugin.zsh", .Zsh},
		{"powerlevel10k-configure", "plugin", "tests/corpus/repos/zsh/powerlevel10k-extra/internal/configure.zsh", .Zsh},

		// Bash-it plugins (mapped to concrete files)
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
		{"bash-preexec", "plugin", "tests/corpus/repos/bash/bash-preexec/bash-preexec.sh", .Bash},
		{"ble-sh-make-command", "plugin", "tests/corpus/repos/bash/ble.sh/make_command.sh", .Bash},
		{"bash-completion-cargo", "plugin", "tests/corpus/repos/bash/bash-completion/completions-fallback/cargo.bash", .Bash},
		{"direnv-stdlib", "plugin", "tests/corpus/repos/bash/direnv/stdlib.sh", .Bash},

		// Fish plugins (list provided)
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
		{"fish-nvm", "plugin", "tests/corpus/repos/fish/nvm.fish/conf.d/nvm.fish", .Fish},
		{"fish-sponge", "plugin", "tests/corpus/repos/fish/sponge/conf.d/sponge.fish", .Fish},
		{"thefuck-install", "plugin", "tests/corpus/repos/fish/thefuck/install.sh", .Bash},

		// POSIX scripts
		{"openrc-network-init", "plugin", "tests/corpus/repos/posix/openrc/init.d/network.in", .POSIX},
		{"busybox-install-sh", "plugin", "tests/corpus/repos/posix/busybox/applets/install.sh", .POSIX},
		{"autoconf-gendocs-sh", "plugin", "tests/corpus/repos/posix/autoconf/build-aux/gendocs.sh", .POSIX},

		// Themes (from provided list, where pure shell files exist)
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
		{"zsh-pure-theme", "theme", "tests/corpus/repos/zsh/pure/pure.zsh", .Zsh},
		{"fish-bobthefish-theme", "theme", "tests/corpus/repos/fish/theme-bobthefish/functions/fish_prompt.fish", .Fish},
		{"zsh-lambda-mod-theme", "theme", "tests/corpus/repos/zsh/lambda-mod-zsh-theme/lambda-mod.zsh-theme", .Zsh},
		{"bash-powerline-theme", "theme", "tests/corpus/repos/bash/bash-powerline/bash-powerline.sh", .Bash},
	}

	results := make([dynamic]CaseResult, 0, len(cases))
	defer delete(results)

	total_existing := 0
	translated_ok := 0
	parse_ok := 0

	for c in cases {
		exists := os.is_file(c.path)
		res := CaseResult{case_ = c, exists = exists}
		if !exists {
			append(&results, res)
			continue
		}

		total_existing += 1
		tr := shellx.translate_file(c.path, c.from, .Bash)
		res.translate_success = tr.success
		res.error = tr.error
		if len(tr.errors) > 0 {
			res.error_message = tr.errors[0].message
		}

		if tr.success {
			translated_ok += 1

			fe := frontend.create_frontend(.Bash)
			tree, parse_err := frontend.parse(&fe, tr.output)
			if parse_err.error == .None && tree != nil {
				res.bash_parse_success = true
				parse_ok += 1
			}
			if tree != nil {
				frontend.destroy_tree(tree)
			}
			frontend.destroy_frontend(&fe)
		}

		shellx.destroy_translation_result(&tr)
		append(&results, res)
	}

	plugin_existing := 0
	plugin_ok := 0
	theme_existing := 0
	theme_ok := 0

	for r in results {
		if !r.exists {
			continue
		}
		if r.case_.kind == "plugin" {
			plugin_existing += 1
			if r.translate_success && r.bash_parse_success {
				plugin_ok += 1
			}
		} else if r.case_.kind == "theme" {
			theme_existing += 1
			if r.translate_success && r.bash_parse_success {
				theme_ok += 1
			}
		}
	}

	report := strings.builder_make()
	defer strings.builder_destroy(&report)

	strings.write_string(&report, "# ShellX Corpus Translation Report\n\n")
	strings.write_string(&report, fmt.tprintf("Total cases listed: %d\n\n", len(cases)))
	strings.write_string(&report, fmt.tprintf("Cases found locally: %d\n\n", total_existing))
	strings.write_string(&report, fmt.tprintf("Translate success: %d/%d\n\n", translated_ok, total_existing))
	strings.write_string(&report, fmt.tprintf("Translate+parse(Bash) success: %d/%d\n\n", parse_ok, total_existing))
	strings.write_string(&report, fmt.tprintf("Plugin success (translate+parse): %d/%d\n\n", plugin_ok, plugin_existing))
	strings.write_string(&report, fmt.tprintf("Theme success (translate+parse): %d/%d\n\n", theme_ok, theme_existing))

	strings.write_string(&report, "## Failures\n\n")
	for r in results {
		if !r.exists {
			strings.write_string(&report, fmt.tprintf("- [MISSING] %s (%s) path=%s\n", r.case_.name, r.case_.kind, r.case_.path))
			continue
		}
		if !(r.translate_success && r.bash_parse_success) {
			strings.write_string(&report, fmt.tprintf(
				"- [FAIL] %s (%s) from=%v translate=%v parse=%v error=%v msg=%s path=%s\n",
				r.case_.name,
				r.case_.kind,
				r.case_.from,
				r.translate_success,
				r.bash_parse_success,
				r.error,
				r.error_message,
				r.case_.path,
			))
		}
	}

	report_path := "tests/corpus/translation_report.md"
	write_ok := os.write_entire_file(report_path, transmute([]byte)strings.to_string(report))
	if !write_ok {
		fmt.println("failed to write report")
		os.exit(1)
	}

	fmt.println("Corpus run complete.")
	fmt.println(fmt.tprintf("Report: %s", report_path))
	fmt.println(fmt.tprintf("Translate success: %d/%d", translated_ok, total_existing))
	fmt.println(fmt.tprintf("Translate+parse success: %d/%d", parse_ok, total_existing))
}
