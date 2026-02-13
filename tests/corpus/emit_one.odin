package main

import shellx "../.."
import "core:fmt"
import "core:os"

parse_dialect :: proc(s: string) -> shellx.ShellDialect {
	switch s {
	case "bash": return .Bash
	case "zsh": return .Zsh
	case "fish": return .Fish
	case "posix": return .POSIX
	}
	return .Bash
}

main :: proc() {
	args := os.args
	if len(args) < 5 do return
	src := args[1]
	from := parse_dialect(args[2])
	to := parse_dialect(args[3])
	out := args[4]
	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	res := shellx.translate_file(src, from, to, opts)
	defer shellx.destroy_translation_result(&res)
	if !res.success {
		fmt.println("ERR", res.error)
		for e in res.errors {
			fmt.println("RULE", e.rule_id)
			fmt.println("MSG", e.message)
			fmt.println("SNIP", e.snippet)
		}
		return
	}
	os.write_entire_file(out, transmute([]byte)res.output)
}
