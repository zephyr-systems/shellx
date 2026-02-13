package compat

import "../ir"
import "core:fmt"
import "core:strings"

// ShimType represents different types of compatibility shims
ShimType :: enum {
	ArrayToList, // Bash array -> Fish list
	ParameterExpansion, // Bash ${var:-default} -> Fish equivalent
	ProcessSubstitution, // Bash <(cmd) -> Fish temp file workaround
}

ParameterExpansionModifier :: enum {
	None,
	DefaultValue,
	Length,
	Substring,
}

ParameterExpansionData :: struct {
	variable:      string,
	modifier:      ParameterExpansionModifier,
	default_value: string,
	offset:        int,
	length:        int,
}

ProcessSubstitutionDirection :: enum {
	Input,
	Output,
}

// Shim represents a compatibility shim
Shim :: struct {
	name:        string,
	type:        ShimType,
	code:        string,
	description: string,
}

// ShimRegistry contains all available shims
ShimRegistry :: struct {
	shims: [dynamic]Shim,
}

// create_shim_registry creates a new shim registry
create_shim_registry :: proc() -> ShimRegistry {
	return ShimRegistry{shims = make([dynamic]Shim)}
}

// destroy_shim_registry cleans up the registry
destroy_shim_registry :: proc(registry: ^ShimRegistry) {
	delete(registry.shims)
}

// add_shim adds a shim to the registry
add_shim :: proc(registry: ^ShimRegistry, shim: Shim) {
	append(&registry.shims, shim)
}

// generate_array_shim generates a shim for array -> list conversion
// Bash: arr=(one two three)
// Fish: set arr one two three
generate_array_shim :: proc(var_name: string, values: []string) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	strings.write_string(&builder, "set ")
	strings.write_string(&builder, var_name)

	for value in values {
		strings.write_byte(&builder, ' ')
		strings.write_string(&builder, value)
	}

	return strings.to_string(builder)
}

// generate_parameter_expansion_shim generates Fish equivalent for Bash parameter expansion
// Handles: ${var:-default}, ${var:=default}, ${var:?error}, ${var:+alt}, ${#var}
generate_parameter_expansion_shim :: proc(expansion: ParameterExpansionData) -> string {
	switch expansion.modifier {
	case .None:
		return fmt.tprintf("$%s", expansion.variable)
	case .DefaultValue:
		// ${var:-default} -> if not set $var; or echo $var; else; echo default; end
		return fmt.tprintf(
			"if not set %s; or echo $%s; else; echo %s; end",
			expansion.variable,
			expansion.variable,
			expansion.default_value,
		)

	case .Length:
		// ${#var} -> string length $var
		return fmt.tprintf("string length $%s", expansion.variable)

	case .Substring:
		// ${var:offset:length} -> string sub -s offset -l length $var
		return fmt.tprintf(
			"string sub -s %d -l %d $%s",
			expansion.offset,
			expansion.length,
			expansion.variable,
		)

	case:
		// Other modifiers not easily supported in Fish
		return fmt.tprintf("$%s", expansion.variable)
	}
}

// generate_process_substitution_shim generates Fish workaround for process substitution
// Bash: cmd <(other_cmd)
// Fish workaround using temp files
generate_process_substitution_shim :: proc(
	command: string,
	direction: ProcessSubstitutionDirection,
) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	// Generate temp file creation
	temp_var := "__temp_file"

	strings.write_string(&builder, "set ")
	strings.write_string(&builder, temp_var)
	strings.write_string(&builder, " (mktemp)\n")

	switch direction {
	case .Input:
		// <(command) - write command output to temp file
		strings.write_string(&builder, command)
		strings.write_string(&builder, " > $")
		strings.write_string(&builder, temp_var)
		strings.write_string(&builder, "\n")

	case .Output:
		// >(command) - read from temp file into command
		strings.write_string(&builder, "# Output to ")
		strings.write_string(&builder, command)
		strings.write_string(&builder, " from $")
		strings.write_string(&builder, temp_var)
		strings.write_string(&builder, "\n")
	}

	// Cleanup
	strings.write_string(&builder, "rm -f $")
	strings.write_string(&builder, temp_var)

	return strings.to_string(builder)
}

// needs_shim checks if a feature needs a shim for the target dialect
needs_shim :: proc(feature: string, from: ir.ShellDialect, to: ir.ShellDialect) -> bool {
	switch feature {
	case "arrays", "arrays_lists", "indexed_arrays", "assoc_arrays", "fish_list_indexing":
		if to == .Fish || to == .POSIX || from == .Fish {
			return true
		}
	case "parameter_expansion":
		return to == .Fish
	case "process_substitution":
		return to == .Fish || to == .POSIX
	case "condition_semantics":
		return to == .Fish || from == .Fish || to == .POSIX
	case "hooks_events", "zsh_hooks", "fish_events", "prompt_hooks":
		return from != to
	}
	return false
}

shim_feature_group :: proc(feature: string) -> string {
	switch feature {
	case "arrays", "arrays_lists", "indexed_arrays", "assoc_arrays", "fish_list_indexing":
		return "arrays_lists"
	case "parameter_expansion":
		return "parameter_expansion"
	case "process_substitution":
		return "process_substitution"
	case "condition_semantics":
		return "condition_semantics"
	case "hooks_events":
		return "hooks_events"
	case "zsh_hooks", "fish_events", "prompt_hooks":
		return "hooks_events"
	}
	return feature
}

// get_shim_description returns a human-readable description of what the shim does
get_shim_description :: proc(shim_type: ShimType) -> string {
	switch shim_type {
	case .ArrayToList:
		return "Converts Bash arrays to Fish lists"
	case .ParameterExpansion:
		return "Converts Bash parameter expansion to Fish string builtin"
	case .ProcessSubstitution:
		return "Converts process substitution to temp file workaround"
	case:
		return "Unknown shim type"
	}
}

generate_condition_semantics_shim :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
function __shellx_test
    test $argv
end

function __shellx_match
    string match $argv
end
`)
	case .Bash, .Zsh, .POSIX:
		return strings.trim_space(`
__shellx_test() {
  test "$@"
}

__shellx_match() {
  _quiet=0 _regex=0 _invert=0 _pattern=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -q|--quiet) _quiet=1; shift ;;
      -r|--regex) _regex=1; shift ;;
      -v|--invert) _invert=1; shift ;;
      --entire|--all|--ignore-case|-i|--) shift ;;
      -*) shift ;;
      *) _pattern="$1"; shift; break ;;
    esac
  done
  [ -n "$_pattern" ] || return 1
  [ "$#" -gt 0 ] || set -- ""
  for _arg in "$@"; do
    if [ "$_regex" -eq 1 ]; then
      printf "%s\n" "$_arg" | grep -E -- "$_pattern" >/dev/null 2>&1
    else
      case "$_arg" in
        $_pattern) true ;;
        *) false ;;
      esac
    fi
    _matched="$?"
    if [ "$_invert" -eq 1 ]; then
      [ "$_matched" -ne 0 ] && return 0
    else
      [ "$_matched" -eq 0 ] && return 0
    fi
  done
  return 1
}
`)
	}
	return ""
}

generate_array_list_bridge_shim :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
function __shellx_array_set
    set -g $argv[1] $argv[2..-1]
end
`)
	case .Bash, .Zsh:
		return strings.trim_space(`
__shellx_list_to_array() {
  local __name="$1"; shift
  eval "$__name=(\"$@\")"
}

__shellx_list_get() {
  local __name="$1"
  local __idx="$2"
  eval "printf '%s' \"\${$__name[$__idx]}\""
}

__shellx_list_len() {
  local __name="$1"
  eval "printf '%s' \"\${#$__name[@]}\""
}
`)
	case .POSIX:
		return strings.trim_space(`
__shellx_list_join() {
  printf "%s" "$1"
  shift
  for _it in "$@"; do
    printf " %s" "$_it"
  done
}

__shellx_list_get() {
  _zx_name="$1"
  _zx_idx="$2"
  eval "_zx_vals=\${$_zx_name}"
  set -- $_zx_vals
  eval "printf '%s' \"\${$_zx_idx}\""
}

__shellx_list_len() {
  _zx_name="$1"
  eval "_zx_vals=\${$_zx_name}"
  set -- $_zx_vals
  printf "%d" "$#"
}
`)
	}
	return ""
}

generate_hook_event_shim :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
set -g __shellx_precmd_hooks
set -g __shellx_preexec_hooks

function __shellx_register_hook --argument hook_name fn
    functions -q $fn; or return 1
    if test "$hook_name" = "precmd"
        contains -- $fn $__shellx_precmd_hooks; or set -g __shellx_precmd_hooks $__shellx_precmd_hooks $fn
    else if test "$hook_name" = "preexec"
        contains -- $fn $__shellx_preexec_hooks; or set -g __shellx_preexec_hooks $__shellx_preexec_hooks $fn
    end
end

function __shellx_register_precmd --argument fn
    __shellx_register_hook precmd $fn
end

function __shellx_register_preexec --argument fn
    __shellx_register_hook preexec $fn
end

function __shellx_run_precmd --on-event fish_prompt
    for _fn in $__shellx_precmd_hooks
        functions -q $_fn; and $_fn
    end
end

function __shellx_run_preexec --on-event fish_preexec
    for _fn in $__shellx_preexec_hooks
        functions -q $_fn; and $_fn $argv
    end
end
`)
	case .Bash, .Zsh, .POSIX:
		return strings.trim_space(`
SHELLX_PRECMD_HOOK="${SHELLX_PRECMD_HOOK-}"
SHELLX_PREEXEC_HOOK="${SHELLX_PREEXEC_HOOK-}"

__shellx_run_precmd() {
  [ -n "${SHELLX_PRECMD_HOOK-}" ] || return 0
  command -v "$SHELLX_PRECMD_HOOK" >/dev/null 2>&1 || return 0
  "$SHELLX_PRECMD_HOOK"
}

__shellx_run_preexec() {
  [ -n "${SHELLX_PREEXEC_HOOK-}" ] || return 0
  [ -n "${__shellx_in_preexec-}" ] && return 0
  __shellx_in_preexec=1
  command -v "$SHELLX_PREEXEC_HOOK" >/dev/null 2>&1 || {
    __shellx_in_preexec=
    return 0
  }
  "$SHELLX_PREEXEC_HOOK" "$@"
  __shellx_in_preexec=
}

__shellx_register_hook() {
  : "${1:?hook required}"
  : "${2:?callback required}"
  case "$1" in
    precmd) SHELLX_PRECMD_HOOK="$2" ;;
    preexec) SHELLX_PREEXEC_HOOK="$2" ;;
  esac
}

__shellx_register_precmd() {
  __shellx_register_hook precmd "$1"
}

__shellx_register_preexec() {
  __shellx_register_hook preexec "$1"
}

__shellx_enable_hooks() {
  if [ -n "${BASH_VERSION-}" ]; then
    case ";${PROMPT_COMMAND-};" in
      *";__shellx_run_precmd;"*) ;;
      *) PROMPT_COMMAND="__shellx_run_precmd${PROMPT_COMMAND:+;${PROMPT_COMMAND}}" ;;
    esac
    trap '__shellx_run_preexec "${BASH_COMMAND}"' DEBUG
  elif [ -n "${ZSH_VERSION-}" ]; then
    autoload -Uz add-zsh-hook >/dev/null 2>&1 || true
    add-zsh-hook precmd __shellx_run_precmd >/dev/null 2>&1 || true
    add-zsh-hook preexec __shellx_run_preexec >/dev/null 2>&1 || true
  fi
}

__shellx_enable_hooks
`)
	}
	return ""
}

generate_process_substitution_bridge_shim :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
function __shellx_psub_tmp
    mktemp
end

function __shellx_psub_in --argument cmd
    set -l tmp (__shellx_psub_tmp)
    sh -c "$cmd" > "$tmp"
    echo $tmp
end

function __shellx_psub_out --argument cmd
    set -l tmp (__shellx_psub_tmp)
    mkfifo $tmp
    sh -c "$cmd < \"$tmp\"; rm -f \"$tmp\"" &
    echo $tmp
end
`)
	case .POSIX:
		return strings.trim_space(`
__shellx_psub_tmp() {
  mktemp
}

__shellx_psub_in() {
  _tmp="$(__shellx_psub_tmp)"
  sh -c "$1" > "$_tmp"
  printf "%s\n" "$_tmp"
}

__shellx_psub_out() {
  _tmp="$(__shellx_psub_tmp)"
  mkfifo "$_tmp"
  sh -c "$1 < \"$_tmp\"; rm -f \"$_tmp\"" &
  printf "%s\n" "$_tmp"
}
`)
	case .Bash, .Zsh:
		return ""
	}
	return ""
}

generate_shim_code :: proc(feature: string, from: ir.ShellDialect, to: ir.ShellDialect) -> string {
	group := shim_feature_group(feature)
	switch group {
	case "arrays_lists":
		return generate_array_list_bridge_shim(to)
	case "condition_semantics":
		return generate_condition_semantics_shim(to)
	case "hooks_events":
		return generate_hook_event_shim(to)
	case "process_substitution":
		return generate_process_substitution_bridge_shim(to)
	case "parameter_expansion":
		if to == .Fish {
			return strings.trim_space(`
function __shellx_param_default --argument var_name default_value
    set -q $var_name
    and eval echo \$$var_name
    or echo $default_value
end

function __shellx_param_length --argument var_name
    set -q $var_name
    and eval string length -- \$$var_name
    or echo 0
end

function __shellx_param_required --argument var_name message
    set -q $var_name
    and eval echo \$$var_name
    or begin
        if test -n "$message"
            echo "$message" >&2
        else
            echo "$var_name: parameter required" >&2
        end
        return 1
    end
end
`)
		}
	}
	return ""
}

build_shim_prelude :: proc(
	required_shims: []string,
	from: ir.ShellDialect,
	to: ir.ShellDialect,
	allocator := context.allocator,
) -> string {
	if len(required_shims) == 0 {
		return ""
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	seen := make(map[string]bool, context.temp_allocator)
	defer delete(seen)

	strings.write_string(&builder, "# shellx compatibility shims\n")
	for feature in required_shims {
		group := shim_feature_group(feature)
		if seen[group] {
			continue
		}
		seen[group] = true

		code := generate_shim_code(feature, from, to)
		if code == "" {
			continue
		}
		strings.write_string(&builder, "\n# shim: ")
		strings.write_string(&builder, group)
		strings.write_byte(&builder, '\n')
		strings.write_string(&builder, code)
		strings.write_byte(&builder, '\n')
	}
	strings.write_byte(&builder, '\n')

	return strings.clone(strings.to_string(builder), allocator)
}
