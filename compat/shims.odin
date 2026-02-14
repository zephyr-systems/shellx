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
	case "runtime_polyfills", "framework_metadata", "zsh_runtime", "fish_runtime", "typeset_compat":
		return to != .Fish
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
	case "runtime_polyfills", "framework_metadata", "zsh_runtime", "fish_runtime", "typeset_compat":
		return "runtime_polyfills"
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
	case .Zsh:
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
    _matched=1
    if [ "$_regex" -eq 1 ]; then
      [[ "$_arg" =~ "$_pattern" ]] && _matched=0
    else
      [[ "$_arg" == ${~_pattern} ]] && _matched=0
    fi
    if [ "$_invert" -eq 1 ]; then
      [ "$_matched" -ne 0 ] && return 0
    else
      [ "$_matched" -eq 0 ] && return 0
    fi
  done
  return 1
}
`)
	case .Bash, .POSIX:
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

function __shellx_array_get
    set -l __name $argv[1]
    set -l __idx $argv[2]
    if test -z "$__name"; or test -z "$__idx"
        return 1
    end
    eval "set -l __vals \$$__name"
    if string match -qr '^[0-9]+$' -- $__idx
        echo $__vals[$__idx]
        return 0
    end

    # Associative-style fallback: entries stored as key=value pairs.
    for __entry in $__vals
        if string match -q -- \"$__idx=*\" \"$__entry\"
            string replace -r '^[^=]*=' '' -- \"$__entry\"
            return 0
        end
    end
    return 1
end
`)
	case .Bash:
		return strings.trim_space(`
__shellx_list_to_array() {
  local __name="$1"; shift
  if [ -z "$__name" ]; then
    return 1
  fi
  eval "$__name=(\"\$@\")"
}

__shellx_list_set() {
  __shellx_list_to_array "$@"
}

__shellx_list_get() {
  local __name="$1"
  local __idx="$2"
  if [ "${__idx#\\$}" != "$__idx" ]; then
    eval "__idx=${__idx}"
  fi
  local __adj="$__idx"
  case "$__idx" in
    ''|*[!0-9]*) __adj="$__idx" ;;
    0) __adj=0 ;;
    *) __adj="$((__idx - 1))" ;;
  esac
  eval "printf '%s' \"\${$__name[$__adj]}\""
}

__shellx_list_len() {
  local __name="$1"
  eval "printf '%s' \"\${#$__name[@]}\""
}
`)
	case .Zsh:
		return strings.trim_space(`
__shellx_list_to_array() {
  local __name="$1"; shift
  eval "$__name=(\"\$@\")"
}

__shellx_list_set() {
  __shellx_list_to_array "$@"
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
__shellx_list_to_array() {
  __shellx_list_set "$@"
}

__shellx_list_set() {
  _zx_name="$1"
  shift
  _zx_acc=""
  _zx_sep=""
  for _zx_item in "$@"; do
    _zx_acc="${_zx_acc}${_zx_sep}${_zx_item}"
    _zx_sep=" "
  done
  eval "$_zx_name=\"\$_zx_acc\""
}

__shellx_key_norm() {
  printf "%s" "$1" | tr -c 'A-Za-z0-9_' '_'
}

__shellx_list_set_index() {
  _zx_name="$1"
  _zx_idx="$2"
  _zx_val="$3"
  _zx_key="$(__shellx_key_norm "$_zx_idx")"
  eval "${_zx_name}__k_${_zx_key}=\"\$_zx_val\""
}

__shellx_list_append() {
  _zx_name="$1"
  shift
  eval "_zx_cur=\${$_zx_name}"
  _zx_acc="$_zx_cur"
  _zx_sep=""
  if [ -n "$_zx_acc" ]; then
    _zx_sep=" "
  fi
  for _zx_item in "$@"; do
    _zx_acc="${_zx_acc}${_zx_sep}${_zx_item}"
    _zx_sep=" "
  done
  eval "$_zx_name=\"\$_zx_acc\""
}

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
  _zx_key="$(__shellx_key_norm "$_zx_idx")"
  eval "_zx_hit=\${${_zx_name}__k_${_zx_key}-__shellx_miss__}"
  if [ "$_zx_hit" != "__shellx_miss__" ]; then
    printf "%s" "$_zx_hit"
    return 0
  fi
  case "$_zx_idx" in
    ''|*[!0-9]*) ;;
    *)
      if [ "$_zx_idx" -gt 0 ]; then
        _zx_alt="$((_zx_idx - 1))"
        _zx_alt_key="$(__shellx_key_norm "$_zx_alt")"
        eval "_zx_hit=\${${_zx_name}__k_${_zx_alt_key}-__shellx_miss__}"
        if [ "$_zx_hit" != "__shellx_miss__" ]; then
          printf "%s" "$_zx_hit"
          return 0
        fi
      fi
      ;;
  esac
  eval "_zx_vals=\${$_zx_name}"
  set -- $_zx_vals
  if [ -z "$_zx_idx" ]; then
    return 1
  fi
  eval "printf '%s' \"\${$_zx_idx}\""
}

__shellx_list_len() {
  _zx_name="$1"
  eval "_zx_vals=\${$_zx_name}"
  set -- $_zx_vals
  printf "%d" "$#"
}

__shellx_list_has() {
  _zx_name="$1"
  _zx_key="$2"
  _zx_norm="$(__shellx_key_norm "$_zx_key")"
  eval "_zx_hit=\${${_zx_name}__k_${_zx_norm}-__shellx_miss__}"
  if [ "$_zx_hit" != "__shellx_miss__" ]; then
    printf "1"
    return 0
  fi
  eval "_zx_vals=\${$_zx_name}"
  set -- $_zx_vals
  for _zx_item in "$@"; do
    if [ "$_zx_item" = "$_zx_key" ]; then
      printf "1"
      return 0
    fi
  done
  printf "0"
}

__shellx_list_unset_index() {
  _zx_name="$1"
  _zx_idx="$2"
  eval "_zx_vals=\${$_zx_name}"
  set -- $_zx_vals
  _zx_len="$#"
  if [ -z "$_zx_idx" ]; then
    return 1
  fi
  case "$_zx_idx" in
    -*) _zx_idx=$((_zx_len + _zx_idx + 1)) ;;
  esac
  _zx_out=""
  _zx_sep=""
  _zx_pos=1
  for _zx_item in "$@"; do
    if [ "$_zx_pos" -ne "$_zx_idx" ]; then
      _zx_out="${_zx_out}${_zx_sep}${_zx_item}"
      _zx_sep=" "
    fi
    _zx_pos=$((_zx_pos + 1))
  done
  eval "$_zx_name=\"\$_zx_out\""
}

__shellx_zsh_subscript_r() {
  _zx_name="$1"
  _zx_pattern="$2"
  eval "_zx_vals=\${$_zx_name}"
  set -- $_zx_vals
  _zx_match=""
  for _zx_item in "$@"; do
    case "$_zx_item" in
      $_zx_pattern) _zx_match="$_zx_item" ;;
    esac
  done
  printf "%s" "$_zx_match"
}

__shellx_zsh_subscript_I() {
  _zx_name="$1"
  _zx_pattern="$2"
  eval "_zx_vals=\${$_zx_name}"
  set -- $_zx_vals
  _zx_idx=0
  _zx_pos=1
  for _zx_item in "$@"; do
    case "$_zx_item" in
      $_zx_pattern) _zx_idx=$_zx_pos ;;
    esac
    _zx_pos=$((_zx_pos + 1))
  done
  printf "%s" "$_zx_idx"
}

__shellx_zsh_subscript_Ib() {
  _zx_name="$1"
  _zx_needle="$2"
  _zx_default_var="$3"
  eval "_zx_vals=\${$_zx_name}"
  set -- $_zx_vals
  _zx_idx=0
  _zx_pos=1
  for _zx_item in "$@"; do
    case "$_zx_item" in
      *"$_zx_needle"*) _zx_idx=$_zx_pos ;;
    esac
    _zx_pos=$((_zx_pos + 1))
  done
  if [ "$_zx_idx" -gt 0 ]; then
    printf "%s" "$_zx_idx"
    return 0
  fi
  if [ -n "$_zx_default_var" ]; then
    eval "printf '%s' \"\${$_zx_default_var}\""
    return 0
  fi
  printf "0"
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
SHELLX_PRECMD_HOOKS="${SHELLX_PRECMD_HOOKS-}"
SHELLX_PREEXEC_HOOKS="${SHELLX_PREEXEC_HOOKS-}"

__shellx_append_hook() {
  _zx_list="$1"
  _zx_fn="$2"
  case " $_zx_list " in
    *" $_zx_fn "*) printf "%s" "$_zx_list" ;;
    *)
      if [ -n "$_zx_list" ]; then
        printf "%s %s" "$_zx_list" "$_zx_fn"
      else
        printf "%s" "$_zx_fn"
      fi
      ;;
  esac
}

__shellx_run_precmd() {
  if command -v fish_prompt >/dev/null 2>&1; then
    fish_prompt >/dev/null 2>&1 || true
  fi
  if command -v fish_right_prompt >/dev/null 2>&1; then
    RPROMPT="$(fish_right_prompt 2>/dev/null || true)"
  fi
  [ -n "${SHELLX_PRECMD_HOOKS-}" ] || return 0
  for _fn in $SHELLX_PRECMD_HOOKS; do
    command -v "$_fn" >/dev/null 2>&1 || continue
    "$_fn"
  done
}

__shellx_run_preexec() {
  [ -n "${SHELLX_PREEXEC_HOOKS-}" ] || return 0
  [ -n "${__shellx_in_preexec-}" ] && return 0
  __shellx_in_preexec=1
  for _fn in $SHELLX_PREEXEC_HOOKS; do
    command -v "$_fn" >/dev/null 2>&1 || continue
    "$_fn" "$@"
  done
  __shellx_in_preexec=
}

__shellx_register_hook() {
  : "${1:?hook required}"
  : "${2:?callback required}"
  case "$1" in
    precmd) SHELLX_PRECMD_HOOKS="$(__shellx_append_hook "${SHELLX_PRECMD_HOOKS-}" "$2")" ;;
    preexec) SHELLX_PREEXEC_HOOKS="$(__shellx_append_hook "${SHELLX_PREEXEC_HOOKS-}" "$2")" ;;
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

generate_runtime_polyfill_shim :: proc(to: ir.ShellDialect) -> string {
	switch to {
	case .Fish:
		return ""
	case .Bash, .Zsh, .POSIX:
		return strings.trim_space(`
# cross-shell runtime polyfills for translated plugins

about_plugin() {
  SHELLX_ABOUT_PLUGIN="$*"
  return 0
}

about_alias() {
  SHELLX_ABOUT_ALIAS="$*"
  return 0
}

is_at_least() {
  _zx_req="$1"
  _zx_cur="${2:-${ZSH_VERSION:-${BASH_VERSION:-0}}}"
  [ -n "$_zx_req" ] || return 1
  _zx_req="${_zx_req%%[^0-9.]*}"
  _zx_cur="${_zx_cur%%[^0-9.]*}"
  [ -n "$_zx_req" ] || _zx_req="0"
  [ -n "$_zx_cur" ] || _zx_cur="0"
  [ "$(printf "%s\n%s\n" "$_zx_req" "$_zx_cur" | sort -V | head -n 1)" = "$_zx_req" ]
}

autoload() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -*) shift ;;
      *) break ;;
    esac
  done
  _zx_rc=0
  for _zx_fn in "$@"; do
    if command -v "$_zx_fn" >/dev/null 2>&1; then
      continue
    fi
    case "$_zx_fn" in
      is-at-least|add-zsh-hook|status|about-plugin|about-alias)
        continue
        ;;
    esac
    _zx_old_ifs="$IFS"
    IFS=:
    for _zx_dir in ${FPATH:-}; do
      [ -f "$_zx_dir/$_zx_fn" ] || continue
      . "$_zx_dir/$_zx_fn" >/dev/null 2>&1 && break
    done
    IFS="$_zx_old_ifs"
    command -v "$_zx_fn" >/dev/null 2>&1 || _zx_rc=1
  done
  return "$_zx_rc"
}

emulate() {
  # zsh option scope emulation is not 1:1 in sh-like shells; keep callsites non-fatal.
  return 0
}

unfunction() {
  _zx_rc=0
  for _zx_fn in "$@"; do
    unset -f "$_zx_fn" >/dev/null 2>&1 || _zx_rc=1
  done
  return "$_zx_rc"
}

zsystem() {
  case "$1" in
    supports)
      case "$2" in
        flock) command -v flock >/dev/null 2>&1 ;;
        *) return 1 ;;
      esac
      ;;
    flock)
      shift
      command flock "$@"
      ;;
    *)
      return 1
      ;;
  esac
}

status() {
  case "$1" in
    is-interactive|--is-interactive)
      [ -t 1 ]
      ;;
    is-login|--is-login)
      if [ -n "${BASH_VERSION-}" ] && command -v shopt >/dev/null 2>&1; then
        shopt -q login_shell
      else
        case "$0" in
          -*) return 0 ;;
          *) return 1 ;;
        esac
      fi
      ;;
    current-command|--current-command)
      if [ -n "${BASH_COMMAND-}" ]; then
        printf "%s\n" "$BASH_COMMAND"
        return 0
      fi
      return 1
      ;;
    filename|--current-filename)
      if [ -n "${BASH_SOURCE-}" ]; then
        printf "%s\n" "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
      else
        printf "%s\n" "$0"
      fi
      ;;
    line-number|--line-number)
      printf "%s\n" "${LINENO:-0}"
      ;;
    *)
      return 1
      ;;
  esac
}

print() {
  _zx_newline=1
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -n) _zx_newline=0; shift ;;
      -r|-P|--|--) shift ;;
      -u*) shift ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  if [ "$_zx_newline" -eq 1 ]; then
    printf "%s\n" "$*"
  else
    printf "%s" "$*"
  fi
}

if [ -n "${BASH_VERSION-}" ]; then
  typeset() {
    _zx_opt=""
    if [ "$#" -gt 0 ] && [ "${1#-}" != "$1" ]; then
      _zx_opt="$1"
      shift
    fi
    if [ -z "$_zx_opt" ]; then
      builtin declare "$@"
      return $?
    fi
    case "$_zx_opt" in
      -*A*) builtin declare -A "$@" ;;
      -*a*|-*U*) builtin declare -a "$@" ;;
      -*) builtin declare "$@" ;;
    esac
  }
else
  typeset() {
    while [ "$#" -gt 0 ] && [ "${1#-}" != "$1" ]; do
      shift
    done
    for _zx_arg in "$@"; do
      case "$_zx_arg" in
        *=*) eval "$_zx_arg" ;;
        *) eval "${_zx_arg}=\${$_zx_arg-}" ;;
      esac
    done
    return 0
  }
fi

__shellx_remove_hook() {
  _zx_list="$1"
  _zx_fn="$2"
  _zx_out=""
  for _zx_item in $_zx_list; do
    [ "$_zx_item" = "$_zx_fn" ] && continue
    if [ -n "$_zx_out" ]; then
      _zx_out="$_zx_out $_zx_item"
    else
      _zx_out="$_zx_item"
    fi
  done
  printf "%s" "$_zx_out"
}

add_zsh_hook() {
  _zx_mode="add"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -d|-D) _zx_mode="del"; shift ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  _zx_hook="$1"
  _zx_fn="$2"
  [ -n "$_zx_hook" ] || return 1
  [ -n "$_zx_fn" ] || return 1
  case "$_zx_mode" in
    del)
      case "$_zx_hook" in
        precmd) SHELLX_PRECMD_HOOKS="$(__shellx_remove_hook "${SHELLX_PRECMD_HOOKS-}" "$_zx_fn")" ;;
        preexec) SHELLX_PREEXEC_HOOKS="$(__shellx_remove_hook "${SHELLX_PREEXEC_HOOKS-}" "$_zx_fn")" ;;
      esac
      ;;
    *)
      case "$_zx_hook" in
        precmd) __shellx_register_precmd "$_zx_fn" ;;
        preexec) __shellx_register_preexec "$_zx_fn" ;;
      esac
      ;;
  esac
  return 0
}

alias about-plugin=about_plugin
alias about-alias=about_alias
alias is-at-least=is_at_least
alias add-zsh-hook=add_zsh_hook

if [ -n "${BASH_VERSION-}" ]; then
  eval 'about-plugin() { about_plugin "$@"; }'
  eval 'about-alias() { about_alias "$@"; }'
  eval 'is-at-least() { is_at_least "$@"; }'
  eval 'add-zsh-hook() { add_zsh_hook "$@"; }'
fi
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
	case "runtime_polyfills":
		return generate_runtime_polyfill_shim(to)
	case "parameter_expansion":
		if to == .Fish {
			return strings.trim_space(`
function __shellx_param_default --argument var_name default_value
    if set -q $var_name
        if eval "test -n \"\$$var_name\""
            eval echo \$$var_name
            return 0
        end
    end
    echo $default_value
end

function __shellx_param_length --argument var_name
    set -q $var_name
    and eval string length -- \$$var_name
    or echo 0
end

function __shellx_param_required --argument var_name message
    if set -q $var_name
        if eval "test -n \"\$$var_name\""
            eval echo \$$var_name
            return 0
        end
    end
    if test -n "$message"
        echo "$message" >&2
    else
        echo "$var_name: parameter required" >&2
    end
    return 1
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
