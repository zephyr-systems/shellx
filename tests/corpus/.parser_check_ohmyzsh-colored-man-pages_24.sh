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
__shellx_list_set() {
  _zx_name="$1"
  shift
  _zx_acc=""
  _zx_sep=""
  for _zx_item in "$@"; do
    _zx_acc="${_zx_acc}${_zx_sep}${_zx_item}"
    _zx_sep=" "
  done
  eval "$_zx_name=\$_zx_acc"
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
  eval "$_zx_name=\$_zx_acc"
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
  eval "$_zx_name=\$_zx_out"
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
      -*A*) builtin declare -gA "$@" ;;
      -*a*|-*U*) builtin declare -ga "$@" ;;
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

function colored() {
	  environment=""
	  # Convert associative array to plain array of NAME=VALUE items.
	  local k v
:
	    __shellx_list_append environment "LESS_TERMCAP_${k}=${v}"
:
	  # Prefer `less` whenever available, since we specifically configured
	  # environment for it.
	  __shellx_list_append environment PAGER="${commands[less]:-$PAGER}"
	  __shellx_list_append environment GROFF_NO_SGR=1
	  # See ./nroff script.
	  if [[ "$OSTYPE" = solaris* ]]; then
	    __shellx_list_append environment PATH="${__colored_man_pages_dir}:$PATH"
	  fi
	  command env $environment "$@"
}
# Requires colors autoload.
# See termcap(5).
# Set up once, and then reuse. This way it supports user overrides after the
# plugin is loaded.
typeset -AHg less_termcap
# bold & blinking mode
less_termcap[mb]="$(__shellx_list_get fg_bold red)"
less_termcap[md]="$(__shellx_list_get fg_bold red)"
less_termcap[me]="${reset_color}"
# standout mode
less_termcap[so]="$(__shellx_list_get fg_bold yellow)$(__shellx_list_get bg blue)"
less_termcap[se]="${reset_color}"
# underlining
less_termcap[us]="$(__shellx_list_get fg_bold green)"
less_termcap[ue]="${reset_color}"
# Handle $0 according to the standard:
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
:
:
# Absolute path to this file's directory.
:
# Colorize man and dman/debman (from debian-goodies)
function man {
:
:
  colored $0 "$@"
:

: