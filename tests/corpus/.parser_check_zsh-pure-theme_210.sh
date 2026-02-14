# shellx capability prelude
# target: POSIX

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

# shim: runtime_polyfills
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

setopt() {
  _zx_rc=0
  for _zx_opt in "$@"; do
    case "$_zx_opt" in
      -*) continue ;;
    esac
    _zx_enable=1
    _zx_name="$_zx_opt"
    case "$_zx_name" in
      no*) _zx_enable=0; _zx_name="${_zx_name#no}" ;;
    esac
    _zx_key="$(printf "%s" "$_zx_name" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"
    eval "SHELLX_SETOPT_${_zx_key}=\$_zx_enable"
    if [ -n "${BASH_VERSION-}" ]; then
      case "$_zx_name" in
        aliases)
          if command -v shopt >/dev/null 2>&1; then
            if [ "$_zx_enable" -eq 1 ]; then shopt -s expand_aliases >/dev/null 2>&1 || _zx_rc=1; else shopt -u expand_aliases >/dev/null 2>&1 || _zx_rc=1; fi
          fi
          ;;
        braceexpand)
          if [ "$_zx_enable" -eq 1 ]; then set +o braceexpand >/dev/null 2>&1 || true; else set +B >/dev/null 2>&1 || true; fi
          ;;
        extendedglob|kshglob)
          if command -v shopt >/dev/null 2>&1; then
            if [ "$_zx_enable" -eq 1 ]; then shopt -s extglob >/dev/null 2>&1 || _zx_rc=1; else shopt -u extglob >/dev/null 2>&1 || _zx_rc=1; fi
          fi
          ;;
        noglob|glob)
          if [ "$_zx_enable" -eq 1 ]; then set +f >/dev/null 2>&1 || true; else set -f >/dev/null 2>&1 || true; fi
          ;;
      esac
    fi
  done
  return "$_zx_rc"
}

zparseopts() {
  _zx_assoc=""
  _zx_array=""
  _zx_specs=""
  _zx_mode="spec"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -A) shift; _zx_assoc="$1" ;;
      -a) shift; _zx_array="$1" ;;
      --) _zx_mode="args"; shift; break ;;
      -*) ;;
      *)
        if [ "$_zx_mode" = "spec" ]; then
          if [ -n "$_zx_specs" ]; then _zx_specs="$_zx_specs $1"; else _zx_specs="$1"; fi
        fi
        ;;
    esac
    shift
  done
  _zx_args="$*"
  _zx_assoc_out=""
  _zx_arr_out=""
  for _zx_arg in $_zx_args; do
    case "$_zx_arg" in
      -*)
        _zx_item="${_zx_arg#-}"
        _zx_key="${_zx_item%%=*}"
        _zx_val="1"
        if [ "$_zx_item" != "$_zx_key" ]; then
          _zx_val="${_zx_item#*=}"
        fi
        if [ -n "$_zx_assoc" ]; then
          if [ -n "$_zx_assoc_out" ]; then _zx_assoc_out="$_zx_assoc_out ${_zx_key}=${_zx_val}"; else _zx_assoc_out="${_zx_key}=${_zx_val}"; fi
        fi
        if [ -n "$_zx_array" ]; then
          if [ -n "$_zx_arr_out" ]; then _zx_arr_out="$_zx_arr_out $_zx_arg"; else _zx_arr_out="$_zx_arg"; fi
        fi
        ;;
    esac
  done
  if [ -n "$_zx_assoc" ]; then eval "$_zx_assoc=\"\$_zx_assoc_out\""; fi
  if [ -n "$_zx_array" ]; then eval "$_zx_array=\"\$_zx_arr_out\""; fi
  return 0
}

__shellx_list_has() {
  _zx_name="$1"
  _zx_key="$2"
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

function prompt_pure_human_time_to_var() {
		local human total_seconds=$1 var=$2
		days=$(( total_seconds / 60 / 60 / 24 ))
		hours=$(( total_seconds / 60 / 60 % 24 ))
		minutes=$(( total_seconds / 60 % 60 ))
		seconds=$(( total_seconds % 60 ))
		(( days > 0 )) && human+="${days}d "
		(( hours > 0 )) && human+="${hours}h "
		(( minutes > 0 )) && human+="${minutes}m "
		human+="${seconds}s"
		# Store human readable time in a variable as specified by the caller
		typeset -g "${var}"="${human}"
}
function prompt_pure_check_cmd_exec_time() {
		integer elapsed
		(( elapsed = EPOCHSECONDS - ${prompt_pure_cmd_timestamp:-$EPOCHSECONDS} ))
		typeset -g prompt_pure_cmd_exec_time=
:
			prompt_pure_human_time_to_var $elapsed "prompt_pure_cmd_exec_time"
:
}
function prompt_pure_set_title() {
		setopt localoptions noshwordsplit
		# Emacs terminal does not support settings the title.
		(( ${EMACS+1} || ${INSIDE_EMACS+1} )) && return
		case $TTY in
			# Don't set title over serial console.
			/dev/ttyS[0-9]*) return;;
		esac
		# Show hostname if connected via SSH.
		local hostname=
		if (( psvar[13] )); then
			# Expand in-place in case ignore-escape is used.
:
		fi
		opts=""
		case $1 in
			expand-prompt) opts=(-P);;
			ignore-escape) opts=(-r);;
		esac
		# Set title atomically in one print statement so that it works when XTRACE is enabled.
		print -n $opts $'\e]0;'${hostname}${2}$'\a'
}
function prompt_pure_preexec() {
		if [[ -n $prompt_pure_git_fetch_pattern ]]; then
			# Detect when Git is performing pull/fetch, including Git aliases.
			local -H MATCH MBEGIN MEND match mbegin mend
			if [[ $2 =~ (git|hub)\ (.*\ )?($prompt_pure_git_fetch_pattern)(\ .*)?$ ]]; then
				# We must flush the async jobs to cancel our git fetch in order
				# to avoid conflicts with the user issued pull / fetch.
				async_flush_jobs 'prompt_pure'
			fi
		fi
		typeset -g prompt_pure_cmd_timestamp=$EPOCHSECONDS
		# Shows the current directory and executed command in the title while a process is active.
		prompt_pure_set_title 'ignore-escape' "$PWD:t: $2"
		# Disallow Python virtualenv from updating the prompt. Set it to 20 if
		# untouched by the user to indicate that Pure modified it. Here we use
		# the magic number 20, same as in `psvar`.
		export VIRTUAL_ENV_DISABLE_PROMPT=${VIRTUAL_ENV_DISABLE_PROMPT:-20}
}
function prompt_pure_set_colors() {
		local color_temp key value
:
			zstyle -t ":prompt:pure:$key" color "$value"
			case $? in
				1) # The current style is different from the one from zstyle.
					zstyle -s ":prompt:pure:$key" color color_temp
					__shellx_list_set_index prompt_pure_colors $key $color_temp ;;
				2) # No style is defined.
					__shellx_list_set_index prompt_pure_colors $key $prompt_pure_colors_default[$key] ;;
			esac
:
}
function prompt_pure_preprompt_render() {
		setopt localoptions noshwordsplit
		unset prompt_pure_async_render_requested
		# Update git branch color based on cache state.
		typeset -g prompt_pure_git_branch_color=$prompt_pure_colors[git:branch]
		[[ -n ${prompt_pure_git_last_dirty_check_timestamp+x} ]] && prompt_pure_git_branch_color=$prompt_pure_colors[git:branch:cached]
		# Update psvar values. PROMPT uses %(NV.true.false) to conditionally
		# render each part. See prompt_pure_setup for the PROMPT template.
		#
		# psvar[12]: Suspended jobs symbol.
		__shellx_list_set_index psvar 12 ""
:
		# psvar[13]: Username flag (set once in prompt_pure_state_setup).
		# psvar[14]: Git branch name.
		__shellx_list_set_index psvar 14 $(__shellx_list_get prompt_pure_vcs_info branch)
		# psvar[15]: Git dirty marker.
		__shellx_list_set_index psvar 15 ${prompt_pure_git_dirty}
		# psvar[16]: Git action (rebase/merge).
		__shellx_list_set_index psvar 16 $(__shellx_list_get prompt_pure_vcs_info action)
		# psvar[17]: Git arrows (push/pull).
		__shellx_list_set_index psvar 17 ${prompt_pure_git_arrows}
		# psvar[18]: Git stash flag.
		__shellx_list_set_index psvar 18 ""
		[[ -n $prompt_pure_git_stash ]] && psvar[18]=1
		# psvar[19]: Command execution time.
		__shellx_list_set_index psvar 19 ${prompt_pure_cmd_exec_time}
		# Expand the prompt for future comparison.
		local expanded_prompt
:
		if [[ $1 == precmd ]]; then
			# Initial newline, for spaciousness.
			print
		elif [[ $prompt_pure_last_prompt != $expanded_prompt ]]; then
			# Redraw the prompt.
			prompt_pure_reset_prompt
		fi
		typeset -g prompt_pure_last_prompt=$expanded_prompt
}
function prompt_pure_precmd() {
		setopt localoptions noshwordsplit
		# Check execution time and store it in a variable.
		prompt_pure_check_cmd_exec_time
		unset prompt_pure_cmd_timestamp
		# Shows the full path in the title.
		prompt_pure_set_title 'expand-prompt' '%~'
		# Modify the colors if some have changed..
		prompt_pure_set_colors
		# Perform async Git dirty check and fetch.
		prompt_pure_async_tasks
		# Check if we should display the virtual env (psvar[20]).
		__shellx_list_set_index psvar 20 ""
		# Check if a Conda environment is active and display its name.
		if [[ -n $CONDA_DEFAULT_ENV ]]; then
			__shellx_list_set_index psvar 20 "${CONDA_DEFAULT_ENV//[$'\t\r\n']}"
		fi
		# When VIRTUAL_ENV_DISABLE_PROMPT is empty, it was unset by the user and
		# Pure should take back control.
		if [[ -n $VIRTUAL_ENV ]] && [[ -z $VIRTUAL_ENV_DISABLE_PROMPT || $VIRTUAL_ENV_DISABLE_PROMPT = 20 ]]; then
			if [[ -n $VIRTUAL_ENV_PROMPT ]]; then
				__shellx_list_set_index psvar 20 "${VIRTUAL_ENV_PROMPT}"
			else
:
			fi
			export VIRTUAL_ENV_DISABLE_PROMPT=20
		fi
		# Nix package manager integration. If used from within 'nix shell' - shell name is shown like so:
		# ~/Projects/flake-utils-plus master
		# flake-utils-plus ❯
		if zstyle -T ":prompt:pure:environment:nix-shell" show; then
			if [[ -n $IN_NIX_SHELL ]]; then
				__shellx_list_set_index psvar 20 "${name:-nix-shell}"
			fi
		fi
		# Make sure VIM prompt is reset.
		prompt_pure_reset_prompt_symbol
		# Print the preprompt.
		prompt_pure_preprompt_render "precmd"
		if [[ -n $ZSH_THEME ]]; then
			print "WARNING: Oh My Zsh themes are enabled (ZSH_THEME='${ZSH_THEME}'). Pure might not be working correctly."
			print "For more information, see: https://github.com/sindresorhus/pure#oh-my-zsh"
			unset ZSH_THEME  # Only show this warning once.
		fi
}
function prompt_pure_async_git_aliases() {
		setopt localoptions noshwordsplit
		local -a gitalias pullalias
		# List all aliases and split on newline.
:
		for line in $gitalias; do
:
			aliasname=${parts[1]#alias.}  # Grab the name (alias.[name]).
			shift parts                   # Remove `aliasname`
			# Check alias for pull or fetch. Must be exact match.
			if [[ $parts =~ ^(.*\ )?(pull|fetch)(\ .*)?$ ]]; then
				__shellx_list_append pullalias $aliasname
			fi
		done
		print -- ${j:pullalias}  # Join on pipe, for use in regex.|		print -- ${:pullalias}  # Join on pipe, for use in regex.
}
function prompt_pure_async_vcs_info() {
		setopt localoptions noshwordsplit
		# Configure `vcs_info` inside an async task. This frees up `vcs_info`
		# to be used or configured as the user pleases.
		zstyle ':vcs_info:*' enable git
		zstyle ':vcs_info:*' use-simple true
		# Only export four message variables from `vcs_info`.
		zstyle ':vcs_info:*' max-exports 3
		# Export branch (%b), Git toplevel (%R), action (rebase/cherry-pick) (%a)
		zstyle ':vcs_info:git*' formats '%b' '%R' '%a'
		zstyle ':vcs_info:git*' actionformats '%b' '%R' '%a'
		vcs_info
		local -A info
		__shellx_list_set_index info pwd $PWD
		__shellx_list_set_index info branch ${vcs_info_msg_0_//\%/%%}
		__shellx_list_set_index info top $vcs_info_msg_1_
		__shellx_list_set_index info action $vcs_info_msg_2_
:
}
function prompt_pure_async_git_dirty() {
		setopt localoptions noshwordsplit
		local untracked_dirty=$1
		untracked_git_mode=$(command git config --get status.showUntrackedFiles)
		if [[ "$untracked_git_mode" != 'no' ]]; then
			untracked_git_mode='normal'
		fi
		# Prevent e.g. `git status` from refreshing the index as a side effect.
		export GIT_OPTIONAL_LOCKS=0
		if [[ $untracked_dirty = 0 ]]; then
			command git diff --no-ext-diff --quiet --exit-code
		else
			test -z "$(command git status --porcelain -u${untracked_git_mode})"
		fi
		return $?
}
function prompt_pure_async_git_fetch() {
		setopt localoptions noshwordsplit
		local only_upstream=${1:-0}
		# Sets `GIT_TERMINAL_PROMPT=0` to disable authentication prompt for Git fetch (Git 2.3+).
		export GIT_TERMINAL_PROMPT=0
		# Set SSH `BachMode` to disable all interactive SSH password prompting.
		export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-"ssh"} -o BatchMode=yes"
		# If gpg-agent is set to handle SSH keys for `git fetch`, make
		# sure it doesn't corrupt the parent TTY.
		# Setting an empty GPG_TTY forces pinentry-curses to close immediately rather
		# than stall indefinitely waiting for user input.
		export GPG_TTY=
		remote=""
		if ((only_upstream)); then
			local ref
			ref=$(command git symbolic-ref -q HEAD)
			# Set remote to only fetch information for the current branch.
			__shellx_list_set remote $(command git for-each-ref --format='%(upstream:remotename) %(refname)' $ref)
			if [[ -z $remote[1] ]]; then
				# No remote specified for this branch, skip fetch.
				return 97
			fi
		fi
		# Default return code, which indicates Git fetch failure.
		local fail_code=99
		# Guard against all forms of password prompts. By setting the shell into
		# MONITOR mode we can notice when a child process prompts for user input
		# because it will be suspended. Since we are inside an async worker, we
		# have no way of transmitting the password and the only option is to
		# kill it. If we don't do it this way, the process will corrupt with the
		# async worker.
		setopt localtraps monitor
		# Make sure local HUP trap is unset to allow for signal propagation when
		# the async worker is flushed.
		trap - HUP
		trap '
			# Unset trap to prevent infinite loop
			trap - CHLD
			if [[ $jobstates = suspended* ]]; then
				# Set fail code to password prompt and kill the fetch.
				fail_code=98
				kill %%
			fi
		' CHLD
		# Do git fetch and avoid fetching tags or
		# submodules to speed up the process.
		command git -c gc.auto=0 fetch \
			--quiet \
			--no-tags \
			--no-prune-tags \
			--recurse-submodules=no \
			$remote &>/dev/null &
		wait $! || return $fail_code
		unsetopt monitor
		# Check arrow status after a successful `git fetch`.
		prompt_pure_async_git_arrows
}
function prompt_pure_async_git_arrows() {
		setopt localoptions noshwordsplit
		command git rev-list --left-right --count HEAD...@'{u}'
}
function prompt_pure_async_git_stash() {
		git rev-list --walk-reflogs --count refs/stash
}
function prompt_pure_async_renice() {
		setopt localoptions noshwordsplit
		if command -v renice >/dev/null; then
			command renice +15 -p $$
		fi
		if command -v ionice >/dev/null; then
			command ionice -c 3 -p $$
		fi
}
function prompt_pure_async_init() {
		typeset -g prompt_pure_async_inited
		if ((${prompt_pure_async_inited:-0})); then
			return
		fi
		prompt_pure_async_inited=1
		async_start_worker "prompt_pure" -u -n
		async_register_callback "prompt_pure" prompt_pure_async_callback
		async_worker_eval "prompt_pure" prompt_pure_async_renice
}
function prompt_pure_async_tasks() {
		setopt localoptions noshwordsplit
		# Initialize the async worker.
		prompt_pure_async_init
		# Update the current working directory of the async worker.
		async_worker_eval "prompt_pure" builtin cd -q $PWD
		typeset -gA prompt_pure_vcs_info
		local -H MATCH MBEGIN MEND
		if [[ $PWD != $(__shellx_list_get prompt_pure_vcs_info pwd)* ]]; then
			# Stop any running async jobs.
			async_flush_jobs "prompt_pure"
			# Reset Git preprompt variables, switching working tree.
			unset prompt_pure_git_dirty
			unset prompt_pure_git_last_dirty_check_timestamp
			unset prompt_pure_git_arrows
			unset prompt_pure_git_stash
			unset prompt_pure_git_fetch_pattern
			__shellx_list_set_index prompt_pure_vcs_info branch ""
			__shellx_list_set_index prompt_pure_vcs_info top ""
		fi
		unset MATCH MBEGIN MEND
		async_job "prompt_pure" prompt_pure_async_vcs_info
		# Only perform tasks inside a Git working tree.
		[[ -n $prompt_pure_vcs_info[top] ]] || return
		prompt_pure_async_refresh
}
function prompt_pure_async_refresh() {
		setopt localoptions noshwordsplit
		if [[ -z $prompt_pure_git_fetch_pattern ]]; then
			# We set the pattern here to avoid redoing the pattern check until the
			# working tree has changed. Pull and fetch are always valid patterns.
			typeset -g prompt_pure_git_fetch_pattern="pull|fetch"
			async_job "prompt_pure" prompt_pure_async_git_aliases
		fi
		async_job "prompt_pure" prompt_pure_async_git_arrows
		# Do not perform `git fetch` if it is disabled or in home folder.
		if (( ${PURE_GIT_PULL:-1} )) && [[ $prompt_pure_vcs_info[top] != $HOME ]]; then
			zstyle -t :prompt:pure:git:fetch only_upstream
			only_upstream=$((? == 0))
			async_job "prompt_pure" prompt_pure_async_git_fetch $only_upstream
		fi
		# If dirty checking is sufficiently fast,
		# tell the worker to check it again, or wait for timeout.
		time_since_last_dirty_check=$(( EPOCHSECONDS - ${prompt_pure_git_last_dirty_check_timestamp:-0} ))
		if (( time_since_last_dirty_check > ${PURE_GIT_DELAY_DIRTY_CHECK:-1800} )); then
			unset prompt_pure_git_last_dirty_check_timestamp
			# Check check if there is anything to pull.
			async_job "prompt_pure" prompt_pure_async_git_dirty ${PURE_GIT_UNTRACKED_DIRTY:-1}
		fi
		# If stash is enabled, tell async worker to count stashes
		if zstyle -t ":prompt:pure:git:stash" show; then
			async_job "prompt_pure" prompt_pure_async_git_stash
		else
			unset prompt_pure_git_stash
		fi
}
function prompt_pure_check_git_arrows() {
		setopt localoptions noshwordsplit
		local arrows left=${1:-0} right=${2:-0}
		(( right > 0 )) && arrows+=${PURE_GIT_DOWN_ARROW:-⇣}
		(( left > 0 )) && arrows+=${PURE_GIT_UP_ARROW:-⇡}
		[[ -n $arrows ]] || return
		typeset -g REPLY=$arrows
}
function prompt_pure_async_callback() {
		setopt localoptions noshwordsplit
		local job=$1 code=$2 output=$3 exec_time=$4 next_pending=$6
		local do_render=0
		case $job in
			\[async])
				# Handle all the errors that could indicate a crashed
				# async worker. See zsh-async documentation for the
				# definition of the exit codes.
				if (( code == 2 )) || (( code == 3 )) || (( code == 130 )); then
					# Our worker died unexpectedly, try to recover immediately.
					# TODO(mafredri): Do we need to handle next_pending
					#                 and defer the restart?
					typeset -g prompt_pure_async_inited=0
					async_stop_worker prompt_pure
					prompt_pure_async_init   # Reinit the worker.
					prompt_pure_async_tasks  # Restart all tasks.
					# Reset render state due to restart.
					unset prompt_pure_async_render_requested
				fi
				;;
			\[async/eval])
				if (( code )); then
					# Looks like async_worker_eval failed,
					# rerun async tasks just in case.
					prompt_pure_async_tasks
				fi
				;;
			prompt_pure_async_vcs_info)
				local -A info
				typeset -gA prompt_pure_vcs_info
				# Parse output (z) and unquote as array (Q@).
:
				local -H MATCH MBEGIN MEND
				if [[ $info[pwd] != $PWD ]]; then
					# The path has changed since the check started, abort.
					return
				fi
				# Check if Git top-level has changed.
				__shellx_list_set_index if [ $info[top $prompt_pure_vcs_info[top] ]]; then
					# If the stored pwd is part of $PWD, $PWD is shorter and likelier
					# to be top-level, so we update pwd.
					__shellx_list_set_index if [ $prompt_pure_vcs_info[pwd ${PWD}* ]]; then
						__shellx_list_set_index prompt_pure_vcs_info pwd $PWD
:
:
					# Store $PWD to detect if we (maybe) left the Git path.
					__shellx_list_set_index prompt_pure_vcs_info pwd $PWD
:
				unset MATCH MBEGIN MEND
				# The update has a Git top-level set, which means we just entered a new
				# Git directory. Run the async refresh tasks.
				[[ -n $info[top] ]] && [[ -z $prompt_pure_vcs_info[top] ]] && prompt_pure_async_refresh
				# Always update branch, top-level and stash.
				__shellx_list_set_index prompt_pure_vcs_info branch $info[branch]
				__shellx_list_set_index prompt_pure_vcs_info top $info[top]
				__shellx_list_set_index prompt_pure_vcs_info action $info[action]
				do_render=1
				;;
			prompt_pure_async_git_aliases)
				if [[ -n $output ]]; then
					# Append custom Git aliases to the predefined ones.
					prompt_pure_git_fetch_pattern+="|$output"
				fi
				;;
			prompt_pure_async_git_dirty)
				local prev_dirty=$prompt_pure_git_dirty
				if (( code == 0 )); then
					unset prompt_pure_git_dirty
				else
					typeset -g prompt_pure_git_dirty="*"
				fi
				[[ $prev_dirty != $prompt_pure_git_dirty ]] && do_render=1
				# When `prompt_pure_git_last_dirty_check_timestamp` is set, the Git info is displayed
				# in a different color. To distinguish between a "fresh" and a "cached" result, the
				# preprompt is rendered before setting this variable. Thus, only upon the next
				# rendering of the preprompt will the result appear in a different color.
				(( $exec_time > 5 )) && prompt_pure_git_last_dirty_check_timestamp=$EPOCHSECONDS
				;;
			prompt_pure_async_git_fetch|prompt_pure_async_git_arrows)
				# `prompt_pure_async_git_fetch` executes `prompt_pure_async_git_arrows`
				# after a successful fetch.
				case $code in
					0)
						local REPLY
:
						if [[ $prompt_pure_git_arrows != $REPLY ]]; then
							typeset -g prompt_pure_git_arrows=$REPLY
							do_render=1
						fi
						;;
					97)
						# No remote available, make sure to clear git arrows if set.
						if [[ -n $prompt_pure_git_arrows ]]; then
							typeset -g prompt_pure_git_arrows=
							do_render=1
						fi
						;;
					99|98)
						# Git fetch failed.
						;;
					*)
						# Non-zero exit status from `prompt_pure_async_git_arrows`,
						# indicating that there is no upstream configured.
						if [[ -n $prompt_pure_git_arrows ]]; then
							unset prompt_pure_git_arrows
							do_render=1
						fi
						;;
				esac
				;;
			prompt_pure_async_git_stash)
				local prev_stash=$prompt_pure_git_stash
				typeset -g prompt_pure_git_stash=$output
				[[ $prev_stash != $prompt_pure_git_stash ]] && do_render=1
				;;
		esac
		if (( next_pending )); then
			(( do_render )) && typeset -g prompt_pure_async_render_requested=1
			return
		fi
		[[ ${prompt_pure_async_render_requested:-$do_render} = 1 ]] && prompt_pure_preprompt_render
		unset prompt_pure_async_render_requested
}
function prompt_pure_reset_prompt() {
		if [[ $CONTEXT == cont ]]; then
			# When the context is "cont", PS2 is active and calling
			# reset-prompt will have no effect on PS1, but it will
			# reset the execution context (%_) of PS2 which we don't
			# want. Unfortunately, we can't save the output of "%_"
			# either because it is only ever rendered as part of the
			# prompt, expanding in-place won't work.
			return
		fi
		zle && zle .reset-prompt
}
function prompt_pure_reset_prompt_symbol() {
		__shellx_list_set_index prompt_pure_state prompt ${PURE_PROMPT_SYMBOL:-❯}
}
function prompt_pure_update_vim_prompt_widget() {
		setopt localoptions noshwordsplit
		__shellx_list_set_index prompt_pure_state prompt ${${KEYMAP/vicmd/${PURE_PROMPT_VICMD_SYMBOL:-❮}}/main/${PURE_PROMPT_SYMBOL:-❯}}|		__shellx_list_set_index prompt_pure_state prompt ${${KEYMAP/vicmd/${PURE_PROMPT_VICMD_SYMBOL:-❮}}/viins/${PURE_PROMPT_SYMBOL:-❯}}
		prompt_pure_reset_prompt
}
function prompt_pure_reset_vim_prompt_widget() {
		setopt localoptions noshwordsplit
		prompt_pure_reset_prompt_symbol
		# We can't perform a prompt reset at this point because it
		# removes the prompt marks inserted by macOS Terminal.
}
function prompt_pure_state_setup() {
		setopt localoptions noshwordsplit
		# Check SSH_CONNECTION and the current state.
		local ssh_connection=${SSH_CONNECTION:-$PROMPT_PURE_SSH_CONNECTION}
		local username hostname
		if [[ -z $ssh_connection ]] && [ -n "$(__shellx_list_has commands "who")" ]; then
			# When changing user on a remote system, the $SSH_CONNECTION
			# environment variable can be lost. Attempt detection via `who`.
			local who_out
			who_out=$(who -m 2>/dev/null)
			if (( $? )); then
				# Who am I not supported, fallback to plain who.
				who_in=""
:
:
			fi
			local reIPv6='(([0-9a-fA-F]+:)|:){2,}[0-9a-fA-F]+'  # Simplified, only checks partial pattern.
			local reIPv4='([0-9]{1,3}\.){3}[0-9]+'   # Simplified, allows invalid ranges.
			# Here we assume two non-consecutive periods represents a
			# hostname. This matches `foo.bar.baz`, but not `foo.bar`.
			local reHostname='([.][^. ]+){2}'
			# Usually the remote address is surrounded by parenthesis, but
			# not on all systems (e.g. busybox).
			local -H MATCH MBEGIN MEND
			if [[ $who_out =~ "\(?($reIPv4|$reIPv6|$reHostname)\)?\$" ]]; then
				ssh_connection=$MATCH
				# Export variable to allow detection propagation inside
				# shells spawned by this one (e.g. tmux does not always
				# inherit the same tty, which breaks detection).
				export PROMPT_PURE_SSH_CONNECTION=$ssh_connection
			fi
			unset MATCH MBEGIN MEND
		fi
		local user_color
		# Show `username@host` if logged in through SSH.
		[[ -n $ssh_connection ]] && user_color=user
		# Show `username@host` if inside a container and not in GitHub Codespaces.
		[[ -z "${CODESPACES}" ]] && prompt_pure_is_inside_container && user_color=user
		# Show `username@host` if root, with username in default color.
		[[ $UID -eq 0 ]] && user_color=user:root
		# Set psvar[13] flag for username display in PROMPT.
		[[ -n $user_color ]] && psvar[13]=1
		typeset -gA prompt_pure_state
		__shellx_list_set_index prompt_pure_state version "1.27.1"
		__shellx_list_append prompt_pure_state user_color "$user_color" prompt	   "${PURE_PROMPT_SYMBOL:-❯}"
}
function prompt_pure_is_inside_container() {
		local -r nspawn_file='/run/host/container-manager'
		local -r podman_crio_file='/run/.containerenv'
		local -r docker_file='/.dockerenv'
		local -r k8s_token_file='/var/run/secrets/kubernetes.io/serviceaccount/token'
		local -r cgroup_file='/proc/1/cgroup'
		[[ "$container" == "lxc" ]] \
			|| [[ "$container" == "oci" ]] \
			|| [[ "$container" == "podman" ]] \
			|| [[ -r "$nspawn_file" ]] \
			|| [[ -r "$podman_crio_file" ]] \
			|| [[ -r "$docker_file" ]] \
			|| [[ -r "$k8s_token_file" ]] \
			|| [[ -r "$cgroup_file" && "$(< $cgroup_file)" = *(lxc|docker|containerd)* ]]
}
function prompt_pure_system_report() {
		setopt localoptions noshwordsplit
		local shell=$SHELL
		if [[ -z $shell ]]; then
			shell=$commands[zsh]
		fi
		print - "- Zsh: $($shell --version) ($shell)"
		print -n - "- Operating system: "
		case "$(uname -s)" in
			Darwin)	print "$(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))";;
			*)	print "$(uname -s) ($(uname -r) $(uname -v) $(uname -m) $(uname -o))";;
		esac
		print - "- Terminal program: ${TERM_PROGRAM:-unknown} (${TERM_PROGRAM_VERSION:-unknown})"
		print -n - "- Tmux: "
		[[ -n $TMUX ]] && print "yes" || print "no"
		local git_version
		git_version=($(git --version))  # Remove newlines, if hub is present.
		print - "- Git: $git_version"
		print - "- Pure state:"
:
:
:
		print - "- zsh-async version: \`${ASYNC_VERSION}\`"
		print - "- PROMPT: \`$(typeset -p PROMPT)\`"
		print - "- Colors: \`$(typeset -p prompt_pure_colors)\`"
		print - "- TERM: \`$(typeset -p TERM)\`"
		print - "- Virtualenv: \`$(typeset -p VIRTUAL_ENV_DISABLE_PROMPT)\`"
		print - "- Conda: \`$(typeset -p CONDA_CHANGEPS1)\`"
		local ohmyzsh=0
		frameworks=""
		[ -n "${ANTIBODY_HOME+1}" ] && __shellx_list_append frameworks "Antibody"
		[ -n "${ADOTDIR+1}" ] && __shellx_list_append frameworks "Antigen"
		[ -n "${ANTIGEN_HS_HOME+1}" ] && __shellx_list_append frameworks "Antigen-hs"
:
			ohmyzsh=1
			__shellx_list_append frameworks "Oh My Zsh"
:
}
function prompt_pure_setup() {
		# Prevent percentage showing up if output doesn't end with a newline.
		export PROMPT_EOL_MARK=''
		__shellx_list_set prompt_opts subst percent
		# Borrowed from `promptinit`. Sets the prompt options in case Pure was not
		# initialized via `promptinit`.
		setopt noprompt{bang,cr,percent,subst} "prompt${^prompt_opts[@]}"
		if [[ -z $prompt_newline ]]; then
			# This variable needs to be set, usually set by promptinit.
			typeset -g prompt_newline=$'\n%{\r%}'
		fi
		zmodload zsh/datetime
		zmodload zsh/zle
		zmodload zsh/parameter
		zmodload zsh/zutil
		autoload -Uz add-zsh-hook
		autoload -Uz vcs_info
		autoload -Uz async && async
		# The `add-zle-hook-widget` function is not guaranteed to be available.
		# It was added in Zsh 5.3.
		autoload -Uz +X add-zle-hook-widget 2>/dev/null
		# Set the colors.
		typeset -gA prompt_pure_colors_default prompt_pure_colors
		__shellx_list_set prompt_pure_colors_default execution_time       yellow git:arrow            cyan git:stash            cyan git:branch           242 git:branch:cached    red git:action           yellow git:dirty            218 host                 242 path                 blue prompt:error         red prompt:success       magenta prompt:continuation  242 suspended_jobs       red user                 242 user:root            default virtualenv           242
:
		__shellx_register_precmd prompt_pure_precmd
		__shellx_register_preexec prompt_pure_preexec
		prompt_pure_state_setup
		zle -N prompt_pure_reset_prompt
		zle -N prompt_pure_update_vim_prompt_widget
		zle -N prompt_pure_reset_vim_prompt_widget
		if [ -n "$(__shellx_list_has functions "add-zle-hook-widget")" ]; then
			add-zle-hook-widget zle-line-finish prompt_pure_reset_vim_prompt_widget
			add-zle-hook-widget zle-keymap-select prompt_pure_update_vim_prompt_widget
		fi
		# Initialize globals referenced by PROMPT via prompt subst.
		typeset -gA prompt_pure_vcs_info
		typeset -g prompt_pure_git_branch_color=$prompt_pure_colors[git:branch]
		# Construct PROMPT once, both preprompt and prompt line. Kept
		# dynamic via variables and psvar[12-20], updated each render
		# in prompt_pure_preprompt_render. Numbering starts at 12 for
		# legacy reasons (Pure originally used psvar[12] for virtualenv)
		# and to avoid collisions with low psvar indices which users
		# may rely on (e.g. %v expands psvar[1]).
		#
		#   psvar[12] = suspended jobs symbol (e.g. ✦)
		#   psvar[13] = username flag, renders user/host (e.g. user@host)
		#   psvar[14] = git branch
		#   psvar[15] = git dirty marker, nested inside [14] conditional
		#   psvar[16] = git action (e.g. rebase, merge)
		#   psvar[17] = git arrows (e.g. ⇣⇡)
		#   psvar[18] = git stash flag, renders stash symbol
		#   psvar[19] = exec time (e.g. 1d 3h 2m 5s)
		#   psvar[20] = virtualenv/conda/nix-shell name
		#
		# Example output:
		#   ✦ user@host ~/Code/pure main* rebase ⇣⇡ ≡ 3s
		#   myenv ❯
		#
		# Preprompt line: each %(NV..) section only renders when its psvar is non-empty.
		PROMPT='%(12V.%F{$prompt_pure_colors[suspended_jobs]}%12v%f .)'
		PROMPT+='%(13V.%F{$prompt_pure_colors['"${prompt_pure_state[user_color]:-user}"']}%n%f%F{$prompt_pure_colors[host]}@%m%f .)'
		PROMPT+='%F{$(__shellx_list_get prompt_pure_colors path)}%~%f'
		PROMPT+='%(14V. %F{${prompt_pure_git_branch_color}}%14v%(15V.%F{$prompt_pure_colors[git:dirty]}%15v.)%f.)'
		PROMPT+='%(16V. %F{$prompt_pure_colors[git:action]}%16v%f.)'
		PROMPT+='%(17V. %F{$prompt_pure_colors[git:arrow]}%17v%f.)'
		PROMPT+='%(18V. %F{$prompt_pure_colors[git:stash]}${PURE_GIT_STASH_SYMBOL:-≡}%f.)'
		PROMPT+='%(19V. %F{$prompt_pure_colors[execution_time]}%19v%f.)'
		# Newline separating preprompt from prompt.
		PROMPT+='${prompt_newline}'
		# Prompt line: virtualenv and prompt symbol.
		PROMPT+='%(20V.%F{$prompt_pure_colors[virtualenv]}%20v%f .)'
		# Prompt symbol: turns red if the previous command didn't exit with 0.
		local prompt_indicator='%(?.%F{$prompt_pure_colors[prompt:success]}.%F{$prompt_pure_colors[prompt:error]})$(__shellx_list_get prompt_pure_state prompt)%f '
		PROMPT+=$prompt_indicator
		# Indicate continuation prompt by … and use a darker color for it.
		PROMPT2='%F{$prompt_pure_colors[prompt:continuation]}… %(1_.%_ .%_)%f'$prompt_indicator
		# Store prompt expansion symbols for in-place expansion via (%). For
		# some reason it does not work without storing them in a variable first.
		prompt_pure_debug_depth=""
		__shellx_list_set prompt_pure_debug_depth '%e' '%N' '%x'
		# Compare is used to check if %N equals %x. When they differ, the main
		# prompt is used to allow displaying both filename and function. When
		# they match, we use the secondary prompt to avoid displaying duplicate
		# information.
		local -A ps4_parts
:
		# Combine the parts with conditional logic. First the `:+` operator is
		# used to replace `compare` either with `main` or an ampty string. Then
		# the `:-` operator is used so that if `compare` becomes an empty
		# string, it is replaced with `secondary`.
		local ps4_symbols='${${'$(__shellx_list_get ps4_parts compare)':+"'$(__shellx_list_get ps4_parts main)'"}:-"'$(__shellx_list_get ps4_parts secondary)'"}'
		# Improve the debug prompt (PS4), show depth by repeating the +-sign and
		# add colors to highlight essential parts like file and function name.
		PROMPT4="$(__shellx_list_get ps4_parts depth) ${ps4_symbols}$(__shellx_list_get ps4_parts prompt)"
		# Guard against Oh My Zsh themes overriding Pure.
		unset ZSH_THEME
		# Guard against (ana)conda changing the PS1 prompt
		# (we manually insert the env when it's available).
		export CONDA_CHANGEPS1=no
}
# Pure
# by Sindre Sorhus
# https://github.com/sindresorhus/pure
# MIT License
# For my own and others sanity
# git:
# %b => current branch
# %a => current action (rebase/merge)
# prompt:
# %F => color dict
# %f => reset color
# %~ => current path
# %* => time
# %n => username
# %m => shortname host
# %(?..) => prompt conditional - %(condition.true.false)
# terminal codes:
# \e7   => save cursor position
# \e[2A => move cursor 2 lines up
# \e[1G => go to position 1 in terminal
# \e8   => restore cursor position
# \e[K  => clears everything after the cursor on the current line
# \e[2K => clear everything on the current line
# Turns seconds into human readable time.
# 165392 => 1d 21h 56m 32s
# https://github.com/sindresorhus/pretty-time-zsh
# Stores (into prompt_pure_cmd_exec_time) the execution
# time of the last command if set threshold was exceeded.
:
# Change the colors if their value are different from the current ones.
# Fastest possible way to check if a Git repo is dirty.
# Try to lower the priority of the worker so that disk heavy operations
# like `git status` has less impact on the system responsivity.
# Return true if executing inside a Docker, OCI, LXC, or systemd-nspawn container.
	[ -n "${ZPREZTODIR+1}" ] && __shellx_list_append frameworks "Prezto"
	[ -n "${ZPLUG_ROOT+1}" ] && __shellx_list_append frameworks "Zplug"
	[ -n "${ZPLGM+1}" ] && __shellx_list_append frameworks "Zplugin"
	(( $#frameworks == 0 )) && __shellx_list_append frameworks "None"
:
	if (( ohmyzsh )); then
		print - "    - Oh My Zsh:"
:
	fi
:
prompt_pure_setup "$@"
