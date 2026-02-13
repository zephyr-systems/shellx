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
	if len(os.args) < 5 {
		fmt.println("usage: debug_translate <from> <to> <input> <output>")
		return
	}
	from := parse_dialect(os.args[1])
	to := parse_dialect(os.args[2])
	in_path := os.args[3]
	out_path := os.args[4]
	data, ok := os.read_entire_file(in_path)
	if !ok {
		fmt.println("read failed")
		return
	}
	defer delete(data)
	opts := shellx.DEFAULT_TRANSLATION_OPTIONS
	opts.insert_shims = true
	res := shellx.translate(string(data), from, to, opts)
	defer shellx.destroy_translation_result(&res)
	fmt.println("success=", res.success, "warnings=", len(res.warnings), "shims=", len(res.required_shims))
	_ = os.write_entire_file(out_path, transmute([]byte)res.output)
}
