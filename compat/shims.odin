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
	case "arrays", "arrays_lists":
		if to == .Fish || to == .POSIX || from == .Fish {
			return true
		}
	case "parameter_expansion":
		return to == .Fish
	case "process_substitution":
		return to == .Fish || to == .POSIX
	case "condition_semantics":
		return to == .Fish || from == .Fish || to == .POSIX
	case "hooks_events":
		return from != to
	}
	return false
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
`)
	}
	return ""
}

generate_hook_event_shim :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return strings.trim_space(`
function __shellx_register_hook --argument hook_name fn
    if test "$hook_name" = "precmd"
        functions -q $fn; and set -g __shellx_precmd $fn
    else if test "$hook_name" = "preexec"
        functions -q $fn; and set -g __shellx_preexec $fn
    end
end
`)
	case .Bash, .Zsh, .POSIX:
		return strings.trim_space(`
__shellx_register_hook() {
  : "${1:?hook required}"
  : "${2:?callback required}"
  case "$1" in
    precmd) SHELLX_PRECMD_HOOK="$2" ;;
    preexec) SHELLX_PREEXEC_HOOK="$2" ;;
  esac
}
`)
	}
	return ""
}

generate_process_substitution_bridge_shim :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish, .POSIX:
		return strings.trim_space(`
__shellx_psub_tmp() {
  mktemp
}
`)
	case .Bash, .Zsh:
		return ""
	}
	return ""
}

generate_shim_code :: proc(feature: string, from: ir.ShellDialect, to: ir.ShellDialect) -> string {
	switch feature {
	case "arrays", "arrays_lists":
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
    set -q $var_name; and eval echo \$$var_name; or echo $default_value
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
		if seen[feature] {
			continue
		}
		seen[feature] = true

		code := generate_shim_code(feature, from, to)
		if code == "" {
			continue
		}
		strings.write_string(&builder, "\n# shim: ")
		strings.write_string(&builder, feature)
		strings.write_byte(&builder, '\n')
		strings.write_string(&builder, code)
		strings.write_byte(&builder, '\n')
	}
	strings.write_byte(&builder, '\n')

	return strings.clone(strings.to_string(builder), allocator)
}
