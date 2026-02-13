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

__done_get_focused_window_id() {
	if type -q lsappinfo; then
	  :
	else
		if __shellx_test -n "$SWAYSOCK"; then
		  :
		fi
		if __shellx_test -n "$HYPRLAND_INSTANCE_SIGNATURE"; then
		  :
		fi
		if __shellx_test -n "$NIRI_SOCKET"; then
		  :
		fi
		if gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval 'global.display.focus_window.get_id()'; then
		  :
		fi
		if type -q xprop; then
		  :
		fi
if true; then
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
		fi
		if true; then
			echo
		fi
:
}

__done_is_tmux_window_active() {
	[ -n "${fish_pid+x}" ]
	tmux_fish_pid=$fish_pid
	while set tmux_fish_ppid $(ps -o ppid= -p $tmux_fish_pid | string trim); do
		tmux_fish_pid=$tmux_fish_ppid
:
}

__done_is_screen_window_active() {
	__shellx_match --quiet --regex "$STY\s+\(Attached" $(screen -ls)
}

__done_is_process_window_focused() {
	if true; then
	  :
	fi
	if true; then
	  :
	fi
	__done_focused_window_id=(__done_get_focused_window_id)
	if __shellx_test "$__done_sway_ignore_visible" -eq 1; then
:
	else
		if __shellx_test -n "$HYPRLAND_INSTANCE_SIGNATURE"; then
		  :
		fi
		if __shellx_test -n "$NIRI_SOCKET"; then
		  :
		fi
		if __shellx_test "$__done_initial_window_id" != "$__done_focused_window_id"; then
		  :
		fi
	fi
	if type -q tmux; then
		__done_is_tmux_window_active
	fi
	if type -q screen; then
		__done_is_screen_window_active
:
}

__done_humanize_duration() {
	seconds=($(math --scale=0 "$milliseconds/1000" % 60))
	minutes=($(math --scale=0 "$milliseconds/60000" % 60))
	hours=($(math --scale=0 "$milliseconds/3600000"))
	if __shellx_test "$hours" -gt 0; then
		printf '%s' $hours'h '
	fi
	if __shellx_test "$minutes" -gt 0; then
		printf '%s' $minutes'm '
	fi
	if __shellx_test "$seconds" -gt 0; then
		printf '%s' $seconds's'
:
}

__done_uninstall() {
	unset -f ne_ended
	unset -f ne_started
	unset -f ne_get_focused_window_id
	unset -f ne_is_tmux_window_active
	unset -f ne_is_screen_window_active
	unset -f ne_is_process_window_focused
	unset -f ne_windows_notification
	unset -f ne_run_powershell_script
	unset -f ne_humanize_duration
	__done_version=""
}

if exit; then :
  :
fi
__done_version=1.21.1
if __shellx_test -z "$SSH_CLIENT"; then
	set __done_enabled
fi
if true; then
	set __done_enabled
fi
if true; then
	__done_initial_window_id=''
	[ -n "${__done_min_cmd_duration+x}" ]
	[ -n "${__done_exclude+x}" ]
	[ -n "${__done_notify_sound+x}" ]
	[ -n "${__done_sway_ignore_visible+x}" ]
	[ -n "${__done_tmux_pane_format+x}" ]
	[ -n "${__done_notification_duration+x}" ]
fi

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
__shellx_register_preexec __done_started
__shellx_register_precmd __done_ended