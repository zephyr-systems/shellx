package main

import shellx "../.."
import "../../frontend"
import "core:fmt"
import "core:os"
import "core:strings"

Case :: struct {
	name: string,
	path: string,
}

main :: proc() {
	cases := []Case{
		{"zsh-autosuggestions", "tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"},
		{"zsh-syntax-highlighting", "tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"},
		{"ohmyzsh-git", "tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh"},
		{"ohmyzsh-z", "tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh"},
		{"ohmyzsh-fzf", "tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh"},
		{"ohmyzsh-sudo", "tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh"},
		{"ohmyzsh-extract", "tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh"},
		{"ohmyzsh-colored-man-pages", "tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh"},
		{"ohmyzsh-web-search", "tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh"},
		{"ohmyzsh-copyfile", "tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh"},
		{"zsh-powerlevel10k", "tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme"},
		{"zsh-agnoster", "tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme"},
		{"zsh-eastwood", "tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme"},
		{"zsh-spaceship", "tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme"},
		{"zsh-gnzh", "tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme"},
	}

	for c in cases {
		data, ok := os.read_entire_file(c.path)
		if !ok {
			continue
		}
		src := string(data)
		delete(data)

		norm1, _ := shellx.normalize_zsh_preparse_local_cmdsubs(src)
		norm2, _ := shellx.normalize_zsh_preparse_syntax(norm1)
		delete(norm1)

		fe := frontend.create_frontend(.Zsh)
		tree, perr := frontend.parse(&fe, norm2)
		if perr.error != .None || tree == nil {
			fmt.println("PARSE_FAIL", c.name, perr.message)
			frontend.destroy_frontend(&fe)
			delete(norm2)
			continue
		}
		diags := frontend.collect_parse_diagnostics(tree, norm2, c.path)
		fmt.printf("CASE %s count=%d\n", c.name, len(diags))
		if len(diags) > 0 {
			lines := strings.split_lines(norm2)
			defer delete(lines)
			limit := len(diags)
			if limit > 8 { limit = 8 }
			for i := 0; i < limit; i += 1 {
				d := diags[i]
				line_text := ""
				if d.location.line >= 1 && d.location.line <= len(lines) {
					line_text = strings.trim_space(lines[d.location.line-1])
				}
				fmt.printf("  %d:%d %s | %s\n", d.location.line, d.location.column, d.message, line_text)
			}
		}
		delete(diags)
		frontend.destroy_tree(tree)
		frontend.destroy_frontend(&fe)
		delete(norm2)
	}
}
