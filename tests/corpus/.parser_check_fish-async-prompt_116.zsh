# shellx capability prelude
# target: Zsh

# cap: arrays
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

# cap: set_get
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

# cap: test
__zx_test() {
  test "$@"
}

# cap: case_match
__zx_case_match() {
  case "$1" in
    $2) return 0 ;;
  esac
  return 1
}

# cap: warn_die
__zx_warn() {
  printf "%s\n" "$1" >&2
}

__zx_die() {
  __zx_warn "$1"
  return 1
}

# shellx compatibility shims

# shim: arrays_lists
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

# shim: condition_semantics
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

# shim: hooks_events
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

__async_prompt_log() {
	if __shellx_test "$async_prompt_debug_log_enable" = 1; then
		echo $(date "+%Y-%m-%d %H:%M:%S") "[$func_name]" "$message"
:
}

__async_prompt_setup_on_startup() {
	__async_prompt_log "__async_prompt_setup_on_startup" "Starting setup"
unset -f "${funcstack[1]}"
	if __shellx_test "$async_prompt_enable" = 0; then
		__async_prompt_log "__async_prompt_setup_on_startup" "Async prompt disabled"
	fi
	for func in ""; do
		__async_prompt_log "__async_prompt_setup_on_startup" "Setting up function: $func"
		functions -c $func '__async_prompt_orig_'$func
:
}

__async_prompt_keep_last_pipestatus() {
	__async_prompt_log "__async_prompt_setup_on_startup" "Setup complete"
	__async_prompt_last_pipestatus=$pipestatus
}

__async_prompt_fire() {
	__async_prompt_log "__async_prompt_fire" "Starting..."
	__async_prompt_last_pipestatus=$pipestatus
	for func in ""; do
		__async_prompt_log "__async_prompt_fire" "Generating async prompt for function: $func"
		tmpfile=$__async_prompt_tmpdir'/'$fish_pid'_'$func
		if __async_prompt_log "__async_prompt_fire" "Generating loading indicator for function: $func"; then
			read -zl last_prompt
			eval $(string escape -- $func'_loading_indicator' "$last_prompt")
		fi
	done
	__async_prompt_log "__async_prompt_fire" "Prompt fire complete"
}

__async_prompt_spawn() {
	__async_prompt_log "__async_prompt_spawn" "Spawning command: $cmd"
	envs=""
	__async_prompt_log "__async_prompt_spawn" "Got vars: $vars"
	if __shellx_test $(__async_prompt_config_disown) = 1; then
		disown
	fi
	__async_prompt_log "__async_prompt_spawn" "Command spawned and disowned: $__async_prompt_config_disown"
}

__async_prompt_config_inherit_variables() {
	__async_prompt_log "__async_prompt_config_inherit_variables" "Getting inherited variables"
	if true; then
	  :
	else
		echo CMD_DURATION
		echo fish_bind_mode
		echo pipestatus
		echo SHLVL
		echo status
	fi
	echo __async_prompt_last_pipestatus
}

__async_prompt_config_functions() {
	__async_prompt_log "__async_prompt_config_functions" "Getting configured prompt functions"
	funcs=()
        if [ -n "${async_prompt_functions+x}" ]; then
            string join \n $async_prompt_functions
        else
            echo fish_prompt
            echo fish_right_prompt
        fi
:
	for func in ""; do
		functions -q "$func"
		echo $func
:
}

__async_prompt_config_internal_signal() {
	if __shellx_test -z "$async_prompt_signal_number"; then
		echo SIGUSR1
	else
		echo "$async_prompt_signal_number"
:
}

__async_prompt_config_disown() {
	if __shellx_test -z "$async_prompt_disown"; then
		echo
	else
		echo "$async_prompt_disown"
:
}

__async_prompt_repaint_prompt() {
	__async_prompt_log "__async_prompt_repaint_prompt" "Repainting prompt"
	commandline -f repaint
}

__async_prompt_tmpdir_cleanup() {
	__async_prompt_log "__async_prompt_tmpdir_cleanup" "Cleaning up temporary directory: $__async_prompt_tmpdir"
	command rm -rf "$__async_prompt_tmpdir"
}

[ -t 1 ]
return 0
__async_prompt_tmpdir=($(command mktemp -d))
__async_prompt_last_pipestatus=""
[ -n "${async_prompt_on_variable+x}" ]
async_prompt_on_variable=(fish_bind_mode PWD)

:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
:
__shellx_register_precmd __async_prompt_setup_on_startup
__shellx_register_precmd __async_prompt_keep_last_pipestatus
__shellx_register_precmd __async_prompt_fire