package compat

import "../ir"
import "core:fmt"
import "core:strings"

Capability :: enum {
	WarnDie,
	CmdHas,
	SetGet,
	Source,
	Test,
	CaseMatch,
	Arrays,
}

capability_id :: proc(cap: Capability) -> string {
	switch cap {
	case .WarnDie:
		return "warn_die"
	case .CmdHas:
		return "cmd_has"
	case .SetGet:
		return "set_get"
	case .Source:
		return "source"
	case .Test:
		return "test"
	case .CaseMatch:
		return "case_match"
	case .Arrays:
		return "arrays"
	}
	return ""
}

append_capability :: proc(caps: ^[dynamic]string, cap: Capability) {
	id := capability_id(cap)
	if id == "" {
		return
	}
	for existing in caps^ {
		if existing == id {
			return
		}
	}
	append(caps, id)
}

append_capability_for_feature :: proc(
	caps: ^[dynamic]string,
	feature: string,
	from: ir.ShellDialect,
	to: ir.ShellDialect,
) {
	_ = from
	_ = to
	switch feature {
	case "condition_semantics":
		append_capability(caps, .Test)
		append_capability(caps, .CaseMatch)
	case "arrays", "arrays_lists", "indexed_arrays", "assoc_arrays", "fish_list_indexing":
		append_capability(caps, .Arrays)
		append_capability(caps, .SetGet)
	case "hooks_events", "zsh_hooks", "fish_events", "prompt_hooks":
		append_capability(caps, .WarnDie)
	case "parameter_expansion":
		append_capability(caps, .SetGet)
	case "process_substitution":
		append_capability(caps, .CmdHas)
	case "source", "source_builtin":
		append_capability(caps, .Source)
	}
}

collect_caps_from_output :: proc(caps: ^[dynamic]string, output: string, to: ir.ShellDialect) {
	_ = to
	if output == "" {
		return
	}
	if strings.contains(output, "__zx_set ") || strings.contains(output, "__zx_get ") || strings.contains(output, "__zx_unset ") {
		append_capability(caps, .SetGet)
	}
	if strings.contains(output, "__zx_source ") {
		append_capability(caps, .Source)
	}
	if strings.contains(output, "__zx_test ") {
		append_capability(caps, .Test)
	}
	if strings.contains(output, "__zx_case_match ") {
		append_capability(caps, .CaseMatch)
	}
	if strings.contains(output, "__zx_arr_") {
		append_capability(caps, .Arrays)
	}
	if strings.contains(output, "__zx_cmd_has ") {
		append_capability(caps, .CmdHas)
	}
	if strings.contains(output, "__zx_") {
		append_capability(caps, .WarnDie)
	}
}

resolve_capability_dependencies :: proc(caps: ^[dynamic]string) {
	has_cap := proc(items: []string, id: string) -> bool {
		for item in items {
			if item == id {
				return true
			}
		}
		return false
	}

	if has_cap(caps^[:], "arrays") && !has_cap(caps^[:], "set_get") {
		append(caps, "set_get")
	}
	if (has_cap(caps^[:], "test") || has_cap(caps^[:], "case_match") || has_cap(caps^[:], "set_get") || has_cap(caps^[:], "source") || has_cap(caps^[:], "arrays")) &&
		!has_cap(caps^[:], "warn_die") {
		append(caps, "warn_die")
	}
}

snippet_warn_die :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
function __zx_warn --argument msg
    printf "%s\n" "$msg" >&2
end

function __zx_die --argument msg
    __zx_warn "$msg"
    return 1
end
`)
	case .Bash, .Zsh, .POSIX:
		return strings.trim_space(`
__zx_warn() {
  printf "%s\n" "$1" >&2
}

__zx_die() {
  __zx_warn "$1"
  return 1
}
`)
	}
	return ""
}

snippet_cmd_has :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
function __zx_cmd_has --argument cmd
    type -q -- "$cmd"
end
`)
	case .Bash, .Zsh, .POSIX:
		return strings.trim_space(`
__zx_cmd_has() {
  command -v "$1" >/dev/null 2>&1
}
`)
	}
	return ""
}

snippet_set_get :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
function __zx_set --argument name value scope export_flag
    set -l flag
    switch "$scope"
        case local
            set flag -l
        case global
            set flag -g
        case universal
            set flag -U
        case default
            set flag
        case '*'
            set flag
    end
    if test "$export_flag" = "1"
        if test -n "$flag"
            set $flag -x -- "$name" "$value"
        else
            set -x -- "$name" "$value"
        end
    else
        if test -n "$flag"
            set $flag -- "$name" "$value"
        else
            set -- "$name" "$value"
        end
    end
end

function __zx_get --argument name
    if set -q $name
        eval "printf \"%s\" \$$name"
    end
end

function __zx_unset --argument name
    set -e -- "$name"
end
`)
	case .Bash, .Zsh, .POSIX:
		return strings.trim_space(`
__zx_set() {
  _zx_name="$1"
  _zx_value="$2"
  _zx_scope="$3"
  _zx_export="$4"
  eval "$_zx_name=\$_zx_value"
  if [ "$_zx_export" = "1" ]; then
    export "$_zx_name"
  fi
}

__zx_get() {
  _zx_name="$1"
  eval "printf '%s' \"\${$_zx_name}\""
}

__zx_unset() {
  unset "$1"
}
`)
	}
	return ""
}

snippet_source :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
function __zx_source --argument path
    if test -f "$path"
        source "$path"
    else
        __zx_warn "source target missing: $path"
        return 1
    end
end
`)
	case .Bash, .Zsh, .POSIX:
		return strings.trim_space(`
__zx_source() {
  if [ -f "$1" ]; then
    . "$1"
  else
    __zx_warn "source target missing: $1"
    return 1
  fi
}
`)
	}
	return ""
}

snippet_test :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
function __zx_test
    test $argv
end
`)
	case .Bash, .Zsh, .POSIX:
		return strings.trim_space(`
__zx_test() {
  test "$@"
}
`)
	}
	return ""
}

snippet_case_match :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
function __zx_case_match --argument value pattern
    string match -q -- "$pattern" "$value"
end
`)
	case .Bash, .Zsh, .POSIX:
		return strings.trim_space(`
__zx_case_match() {
  case "$1" in
    $2) return 0 ;;
  esac
  return 1
}
`)
	}
	return ""
}

snippet_arrays :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
function __zx_arr_new --argument name
    set -l var "__ZX_ARR_$name"
    set -g -- "$var"
end

function __zx_arr_push --argument name value
    set -l var "__ZX_ARR_$name"
    eval "set -a $var -- \"$value\""
end

function __zx_arr_get --argument name idx
    set -l var "__ZX_ARR_$name"
    eval "set -l __zx_vals \$$var"
    printf "%s" "$__zx_vals[$idx]"
end

function __zx_arr_len --argument name
    set -l var "__ZX_ARR_$name"
    eval "set -l __zx_vals \$$var"
    count $__zx_vals
end
`)
	case .Bash, .Zsh, .POSIX:
		return strings.trim_space(`
__zx_arr_new() {
  eval "__ZX_ARR_$1=''"
}

__zx_arr_push() {
  _zx_var="__ZX_ARR_$1"
  eval "_zx_cur=\${$_zx_var}"
  if [ -z "$_zx_cur" ]; then
    eval "$_zx_var=\$2"
  else
    eval "$_zx_var=\${_zx_cur}\${IFS}\$2"
  fi
}

__zx_arr_get() {
  _zx_var="__ZX_ARR_$1"
  _zx_idx="$2"
  eval "_zx_vals=\${$_zx_var}"
  set -- $_zx_vals
  eval "printf '%s' \"\${$_zx_idx}\""
}

__zx_arr_len() {
  _zx_var="__ZX_ARR_$1"
  eval "_zx_vals=\${$_zx_var}"
  set -- $_zx_vals
  printf "%d" "$#"
}
`)
	}
	return ""
}

snippet_for_capability :: proc(id: string, to: ir.ShellDialect) -> string {
	switch id {
	case "warn_die":
		return snippet_warn_die(to)
	case "cmd_has":
		return snippet_cmd_has(to)
	case "set_get":
		return snippet_set_get(to)
	case "source":
		return snippet_source(to)
	case "test":
		return snippet_test(to)
	case "case_match":
		return snippet_case_match(to)
	case "arrays":
		return snippet_arrays(to)
	}
	return ""
}

build_capability_prelude :: proc(required_caps: []string, to: ir.ShellDialect, allocator := context.allocator) -> string {
	if len(required_caps) == 0 {
		return ""
	}

	resolved := make([dynamic]string, 0, len(required_caps)+4, context.temp_allocator)
	defer delete(resolved)
	for cap in required_caps {
		exists := false
		for seen in resolved {
			if seen == cap {
				exists = true
				break
			}
		}
		if !exists {
			append(&resolved, cap)
		}
	}
	resolve_capability_dependencies(&resolved)

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	strings.write_string(&builder, "# shellx capability prelude\n")
	strings.write_string(&builder, fmt.tprintf("# target: %v\n\n", to))
	for cap in resolved {
		snippet := snippet_for_capability(cap, to)
		if snippet == "" {
			continue
		}
		strings.write_string(&builder, "# cap: ")
		strings.write_string(&builder, cap)
		strings.write_byte(&builder, '\n')
		strings.write_string(&builder, snippet)
		strings.write_string(&builder, "\n\n")
	}

	return strings.clone(strings.to_string(builder), allocator)
}
