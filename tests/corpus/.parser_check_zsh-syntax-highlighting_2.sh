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

alias _zsh_highlight__zle-line-finish=_zsh_highlight__zle_line_finish
alias _zsh_highlight__zle-line-pre-redraw=_zsh_highlight__zle_line_pre_redraw

function _zsh_highlight__function_is_autoload_stub_p() {
	  if zmodload -e zsh/parameter; then
	    #(( $(__shellx_list_has functions "$1") )) &&
	    [[ "$functions[$1]" == *"builtin autoload -X"* ]]
	  else
	    #[[ $(type -wa -- "$1") == *'function'* ]] &&
:
	  fi
	  # Do nothing here: return the exit code of the if.
}
function _zsh_highlight__is_function_p() {
	  if zmodload -e zsh/parameter; then
	    (( $(__shellx_list_has functions "$1") ))
	  else
	    [[ $(type -wa -- "$1") == *'function'* ]]
	  fi
}
function _zsh_highlight__function_callable_p() {
if true; then
:
:
	    # Already fully loaded.
	    return 0 # true
	  else
	    # "$1" is either an autoload stub, or not a function at all.
	    #
	    # Use a subshell to avoid affecting the calling shell.
	    #
	    # We expect 'autoload +X' to return non-zero if it fails to fully load
	    # the function.
	    ( autoload -U +X -- "$1" 2>/dev/null )
	    return $?
	  fi
}
function _zsh_highlight_apply_zle_highlight() {
	  local entry="$1" default="$2"
	  integer first="$3" second="$4"
	  # read the relevant entry from zle_highlight
	  #
:
	  # ### add (b).  The only effect is on the failure mode for callers that violate
	  # ### the precondition.
	  local region="${zle_highlight[(r)${entry}:*]-}"
	  if [[ -z "$region" ]]; then
	    # entry not specified at all, use default value
	    region=$default
	  else
	    # strip prefix
	    region="${region#${entry}:}"
	    # no highlighting when set to the empty string or to 'none'
	    if [[ -z "$region" ]] || [[ "$region" == none ]]; then
	      return
	    fi
	  fi
	  integer start end
	  if (( first < second )); then
	    start=$first end=$second
	  else
	    start=$second end=$first
	  fi
	  __shellx_list_append region_highlight "$start $end $region, memo=zsh-syntax-highlighting"
}
:
	    # Reset $WIDGET since the 'main' highlighter depends on it.
	    #
	    # Since $WIDGET is declared by zle as read-only in this function's scope,
	    # a nested function is required in order to shadow its built-in value;
	    # see "User-defined widgets" in zshall.
:
	      WIDGET=zle-line-finish
	      _zsh_highlight
:
:
	    # Set $? to 0 for _zsh_highlight.  Without this, subsequent
	    # zle-line-pre-redraw hooks won't run, since add-zle-hook-widget happens to
	    # call us with $? == 1 in the common case.
	    true && _zsh_highlight "$@"
:
function _zsh_highlight_bind_widgets() {
	  if [[ -o zle ]]; then
	    add-zle-hook-widget zle-line-pre-redraw _zsh_highlight__zle-line-pre-redraw
	    add-zle-hook-widget zle-line-finish _zsh_highlight__zle-line-finish
	  fi
:
	  # Rebind all ZLE widgets to make them invoke _zsh_highlights.
}
_zsh_highlight_bind_widgets() {
:
	    setopt localoptions noksharrays
	    typeset -F SECONDS
	    local prefix=orig-s$SECONDS-r$RANDOM # unique each time, in case we're sourced more than once
	    # Load ZSH module zsh/zleparameter, needed to override user defined widgets.
:
	      print -r -- >&2 'zsh-syntax-highlighting: failed loading zsh/zleparameter.'
	      return 1
:
:
:
	        # Completion widget: override and rebind old one with prefix "orig-".
:
:
:
	        # Builtin widget: override and make it call the builtin ".widget".
:
:
	        # Incomplete or nonexistent widget: Bind to z-sy-h directly.
:
	           if [[ $cur_widget == zle-* ]] && (( ! $(__shellx_list_has widgets "$cur_widget") )); then
eval "_zsh_highlight_widget_\${cur_widget}() { :; _zsh_highlight; }"
	             zle -N $cur_widget _zsh_highlight_widget_$cur_widget
	           else
	        # Default: unhandled case.
:
:
	           fi
:
:
}
:
:
:
:
:
:
:
# -------------------------------------------------------------------------------------------------
# Copyright (c) 2010-2020 zsh-syntax-highlighting contributors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice, this list of conditions
#    and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice, this list of
#    conditions and the following disclaimer in the documentation and/or other materials provided
#    with the distribution.
#  * Neither the name of the zsh-syntax-highlighting contributors nor the names of its contributors
#    may be used to endorse or promote products derived from this software without specific prior
#    written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------
# First of all, ensure predictable parsing.
zsh_highlight__aliases="$(builtin alias -Lm '[^+]*')"
# In zsh <= 5.2, aliases that begin with a plus sign ('alias -- +foo=42')
# are emitted by `alias -L` without a '--' guard, so they don't round trip.
#
# Hence, we exclude them from unaliasing:
builtin unalias -m '[^+]*'
# Set $0 to the expected value, regardless of functionargzero.
:
if true; then
  # $0 is reliable
:
:
  if [[ $ZSH_HIGHLIGHT_REVISION == \$Format:* ]]; then
    # When running from a source tree without 'make install', $ZSH_HIGHLIGHT_REVISION
    # would be set to '$Format:%H$' literally.  That's an invalid value, and obtaining
    # the valid value (via `git rev-parse HEAD`, as Makefile does) might be costly, so:
    ZSH_HIGHLIGHT_REVISION=HEAD
  fi
fi
# This function takes a single argument F and returns True iff F is an autoload stub.
# Return True iff the argument denotes a function name.
# This function takes a single argument F and returns True iff F denotes the
# name of a callable function.  A function is callable if it is fully defined
# or if it is marked for autoloading and autoloading it at the first call to it
# will succeed.  In particular, if F has been marked for autoloading
# but is not available in $fpath, then calling this function on F will return False.
#
# See users/21671 https://www.zsh.org/cgi-bin/mla/redirect?USERNUMBER=21671
# -------------------------------------------------------------------------------------------------
# Core highlighting update system
# -------------------------------------------------------------------------------------------------
# Use workaround for bug in ZSH?
# zsh-users/zsh@48cadf4 https://www.zsh.org/mla/workers/2017/msg00034.html
autoload -Uz is-at-least
if is-at-least 5.4; then
  typeset -g zsh_highlight__pat_static_bug=false
else
  typeset -g zsh_highlight__pat_static_bug=true
fi
# Array declaring active highlighters names.
ZSH_HIGHLIGHT_HIGHLIGHTERS=""
# Update ZLE buffer syntax highlighting.
#
# Invokes each highlighter that needs updating.
# This function is supposed to be called whenever the ZLE state changes.
_zsh_highlight() {
:
  # Store the previous command return code to restore it whatever happens.
  local ret=$?
  # Make it read-only.  Can't combine this with the previous line when POSIX_BUILTINS may be set.
  typeset -r ret
  # $region_highlight should be predefined, either by zle or by the test suite's mock (non-special) array.
:
    echo >&2 'zsh-syntax-highlighting: error: $region_highlight is not defined'
    echo >&2 'zsh-syntax-highlighting: (Check whether zsh-syntax-highlighting was installed according to the instructions.)'
    return $ret
:
  # Probe the memo= feature, once.
:
    __shellx_list_append region_highlight " 0 0 fg=red, memo=zsh-syntax-highlighting"
    case $(__shellx_list_get region_highlight -1) in
      ("0 0 fg=red")
        # zsh 5.8 or earlier
        integer -gr zsh_highlight__memo_feature=0
:
      ("0 0 fg=red memo=zsh-syntax-highlighting")
        # zsh 5.9 or later
        integer -gr zsh_highlight__memo_feature=1
:
      (" 0 0 fg=red, memo=zsh-syntax-highlighting") ;&
      (*)
        # We can get here in two ways:
        #
        # 1. When not running as a widget.  In that case, $region_highlight is
        # not a special variable (= one with custom getter/setter functions
        # written in C) but an ordinary one, so the third case pattern matches
        # and we fall through to this block.  (The test suite uses this codepath.)
        #
        # 2. When running under a future version of zsh that will have changed
        # the serialization of $region_highlight elements from their underlying
        # C structs, so that none of the previous case patterns will match.
        #
        # In either case, fall back to a version check.
        if is-at-least 5.9; then
          integer -gr zsh_highlight__memo_feature=1
        else
          integer -gr zsh_highlight__memo_feature=0
        fi
:
    esac
    __shellx_list_unset_index region_highlight -1
:
  # Reset region_highlight to build it from scratch
  if (( zsh_highlight__memo_feature )); then
    __shellx_list_set region_highlight "${region_highlight[@]:#*memo=zsh-syntax-highlighting*}"
  else
    # Legacy codepath.  Not very interoperable with other plugins (issue #418).
    __shellx_list_set region_highlight
  fi
  # Remove all highlighting in isearch, so that only the underlining done by zsh itself remains.
  # For details see FAQ entry 'Why does syntax highlighting not work while searching history?'.
  # This disables highlighting during isearch (for reasons explained in README.md) unless zsh is new enough
  # and doesn't have the pattern matching bug
  if [[ $WIDGET == zle-isearch-update ]] && { $zsh_highlight__pat_static_bug || ! [ -n "${ISEARCHMATCH_ACTIVE+1}" ]; }; then
    return $ret
  fi
  # Before we 'emulate -L', save the user's options
  local -A zsyh_user_options
  if zmodload -e zsh/parameter; then
:
  else
    local canonical_options onoff option raw_options
:
:
    for option in "$canonical_options"; do
      [[ -o $option ]]
      case $? in
        (0) __shellx_list_append zsyh_user_options $option on;;
        (1) __shellx_list_append zsyh_user_options $option off;;
        (*) # Can't happen, surely?
            echo "zsh-syntax-highlighting: warning: '[[ -o $option ]]' returned $?"
:
      esac
    done
  fi
  typeset -r zsyh_user_options
  emulate -L zsh
  setopt localoptions warncreateglobal nobashrematch
  local REPLY # don't leak $REPLY into global scope
  # Do not highlight if there are more than 300 chars in the buffer. It's most
  # likely a pasted command or a huge list of files in that case..
  [[ -n ${ZSH_HIGHLIGHT_MAXLENGTH:-} ]] && [[ $#BUFFER -gt $ZSH_HIGHLIGHT_MAXLENGTH ]] && return $ret
  # Do not highlight if there are pending inputs (copy/paste).
  (( KEYS_QUEUED_COUNT > 0 )) && return $ret
  (( PENDING > 0 )) && return $ret
:
    local cache_place
    region_highlight_copy=""
    # Select which highlighters in ZSH_HIGHLIGHT_HIGHLIGHTERS need to be invoked.
:
      # eval cache place for current highlighter and prepare it
      cache_place="_zsh_highlight__highlighter_${highlighter}_cache"
      typeset -ga ${cache_place}
      # If highlighter needs to be invoked
      if ! type "_zsh_highlight_highlighter_${highlighter}_predicate" >&/dev/null; then
:
:
        __shellx_list_set ZSH_HIGHLIGHT_HIGHLIGHTERS ${ZSH_HIGHLIGHT_HIGHLIGHTERS:#${highlighter}}
      elif "_zsh_highlight_highlighter_${highlighter}_predicate"; then
        # save a copy, and cleanup region_highlight
        __shellx_list_set region_highlight_copy "$region_highlight"
        __shellx_list_set region_highlight
        # Execute highlighter and save result
:
          "_zsh_highlight_highlighter_${highlighter}_paint"
:
:
:
        # Restore saved region_highlight
        __shellx_list_set region_highlight "$region_highlight_copy"
:
      # Use value form cache if any cached
:
:
    # Re-apply zle_highlight settings
    # region
:
      (( REGION_ACTIVE )) || return
      integer min max
      if (( MARK > CURSOR )) ; then
        min=$CURSOR max=$MARK
      else
        min=$MARK max=$CURSOR
      fi
      if (( REGION_ACTIVE == 1 )); then
        [[ $KEYMAP = vicmd ]] && (( max++ ))
      elif (( REGION_ACTIVE == 2 )); then
        local needle=$'\n'
        # CURSOR and MARK are 0 indexed between letters like region_highlight
        # Do not include the newline in the highlight
        (( min = $(__shellx_zsh_subscript_Ib BUFFER "$needle" "min") ))
        (( max = $(__shellx_list_get BUFFER "(ib:max:)$needle") - 1 ))
      fi
      _zsh_highlight_apply_zle_highlight region standout "$min" "$max"
:
    # yank / paste (zsh-5.1.1 and newer)
    [ -n "${YANK_ACTIVE+1}" ] && (( YANK_ACTIVE )) && _zsh_highlight_apply_zle_highlight paste standout "$YANK_START" "$YANK_END"
    # isearch
    [ -n "${ISEARCHMATCH_ACTIVE+1}" ] && (( ISEARCHMATCH_ACTIVE )) && _zsh_highlight_apply_zle_highlight isearch underline "$ISEARCHMATCH_START" "$ISEARCHMATCH_END"
    # suffix
    [ -n "${SUFFIX_ACTIVE+1}" ] && (( SUFFIX_ACTIVE )) && _zsh_highlight_apply_zle_highlight suffix bold "$SUFFIX_START" "$SUFFIX_END"
    return $ret
:
    typeset -g _ZSH_HIGHLIGHT_PRIOR_BUFFER="$BUFFER"
    typeset -gi _ZSH_HIGHLIGHT_PRIOR_CURSOR=$CURSOR
:
:
# Apply highlighting based on entries in the zle_highlight array.
# This function takes four arguments:
# 1. The exact entry (no patterns) in the zle_highlight array:
#    region, paste, isearch, or suffix
# 2. The default highlighting that should be applied if the entry is unset
# 3. and 4. Two integer values describing the beginning and end of the
#    range. The order does not matter.
# -------------------------------------------------------------------------------------------------
# API/utility functions for highlighters
# -------------------------------------------------------------------------------------------------
# Array used by highlighters to declare user overridable styles.
typeset -gA ZSH_HIGHLIGHT_STYLES
# Whether the command line buffer has been modified or not.
#
# Returns 0 if the buffer has changed since _zsh_highlight was last called.
fi
}
_zsh_highlight_buffer_modified() {
:
  [[ "${_ZSH_HIGHLIGHT_PRIOR_BUFFER:-}" != "$BUFFER" ]]
}
# Whether the cursor has moved or not.
#
# Returns 0 if the cursor has moved since _zsh_highlight was last called.
_zsh_highlight_cursor_moved() {
:
  [[ -n $CURSOR ]] && [[ -n ${_ZSH_HIGHLIGHT_PRIOR_CURSOR-} ]] && (($_ZSH_HIGHLIGHT_PRIOR_CURSOR != $CURSOR))
}
# Add a highlight defined by ZSH_HIGHLIGHT_STYLES.
#
# Should be used by all highlighters aside from 'pattern' (cf. ZSH_HIGHLIGHT_PATTERN).
# Overwritten in tests/test-highlighting.zsh when testing.
_zsh_highlight_add_highlight() {
:
  local -i start end
  local highlight
  start=$1
  end=$2
  shift 2
for _ in 1; do
    if [ -n "$(__shellx_list_has ZSH_HIGHLIGHT_STYLES "$highlight")" ]; then
      __shellx_list_append region_highlight "$start $end $ZSH_HIGHLIGHT_STYLES[$highlight], memo=zsh-syntax-highlighting"
      break
    fi
  done
}
# -------------------------------------------------------------------------------------------------
# Setup functions
# -------------------------------------------------------------------------------------------------
# Helper for _zsh_highlight_bind_widgets
# $1 is name of widget to call
_zsh_highlight_call_widget() {
:
  builtin zle "$@" &&
  _zsh_highlight
}
# Decide whether to use the zle-line-pre-redraw codepath (colloquially known as
# "feature/redrawhook", after the topic branch's name) or the legacy "bind all
# widgets" codepath.
#
# We use the new codepath under two conditions:
#
# 1. If it's available, which we check by testing for add-zle-hook-widget's availability.
# 
# 2. If zsh has the memo= feature, which is required for interoperability reasons.
#    See issues #579 and #735, and the issues referenced from them.
#
#    We check this with a plain version number check, since a functional check,
#    as done by _zsh_highlight, can only be done from inside a widget
#    function — a catch-22.
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