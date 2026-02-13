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

function check_alias_usage() {
	    # Optional parameter that limits how far back history is checked
	    # I've chosen a large default value instead of bypassing tail because it's simpler
	    local limit="${1:-${HISTSIZE:-9000000000000000}}"
	    local key
	    declare -A usage
	    for key in "${!aliases[@]}"; do
	        usage[$key]=0
	    done
	    # TODO:
	    # Handle and (&&) + (&)
	    # others? watch, time etc...
	    histfile_lines=""
:
	    __shellx_list_set histfile_lines "${histfile_lines[@]#*;}"
	    local current=0
	    local total=${#histfile_lines}
	    if [[ $total -gt $limit ]]; then
	        total=$limit
	    fi
	    local entry
	    for line in $histfile_lines ; do
for entry in "$line"; do
	            # Remove leading whitespace
	            entry=${entry##*[[:space:]]}
	            # We only care about the first word because that's all aliases work with
	            # (this does not count global and git aliases)
	            local word=$(__shellx_list_get entry "(w)1")
	            if [[ -n $(__shellx_list_get usage $word) ]]; then
	                (( usage[$word]++ ))
	            fi
	        done
	        # print current progress
	        (( current++ ))
	        printf "Analysing: [$current/$total]\r"
	    done
	    # Clear all previous line output
	    printf "\r\033[K"
	    # Print ordered usage
	    for key in ${!usage[@]}; do
:
done
:
}
function _write_ysu_buffer() {
	    _YSU_BUFFER+="$@"
	    # Maintain historical behaviour by default
	    local position="${YSU_MESSAGE_POSITION:-before}"
	    if [[ "$position" = "before" ]]; then
	        _flush_ysu_buffer
	    elif [[ "$position" != "after" ]]; then
	        (>&2 printf "${RED}${BOLD}Unknown value for YSU_MESSAGE_POSITION '$position'. ")
	        (>&2 printf "Expected value 'before' or 'after'${NONE}\n")
	        _flush_ysu_buffer
	    fi
}
function _flush_ysu_buffer() {
	    # It's important to pass $_YSU_BUFFER to printfs first argument
	    # because otherwise all escape codes will not printed correctly
	    (>&2 printf "$_YSU_BUFFER")
	    _YSU_BUFFER=""
}
function ysu_message() {
:
	Found existing %alias_type for ${PURPLE}\"%command\"${YELLOW}. \
:
	    local alias_type_arg="${1}"
	    local command_arg="${2}"
	    local alias_arg="${3}"
	    # Escape arguments which will be interpreted by printf incorrectly
	    # unfortunately there does not seem to be a nice way to put this into
	    # a function because returning the values requires to be done by printf/echo!!
	    command_arg="${command_arg//\%/%%}"
	    command_arg="${command_arg//\\/\\\\}"
	    local MESSAGE="${YSU_MESSAGE_FORMAT:-"$DEFAULT_MESSAGE_FORMAT"}"
	    MESSAGE="${MESSAGE//\%alias_type/$alias_type_arg}"
	    MESSAGE="${MESSAGE//\%command/$command_arg}"
	    MESSAGE="${MESSAGE//\%alias/$alias_arg}"
	    _write_ysu_buffer "$MESSAGE\n"
}
function _check_ysu_hardcore() {
	    local alias_name="$1"
	    local hardcore_lookup="$(__shellx_zsh_subscript_r YSU_HARDCORE_ALIASES "$alias_name")"
	    if (( ${YSU_HARDCORE+1} )) || [[ -n "$hardcore_lookup" && "$hardcore_lookup" == "$alias_name" ]]; then
	        _write_ysu_buffer "${BOLD}${RED}You Should Use hardcore mode enabled. Use your aliases!${NONE}\n"
	        kill -s INT $$
	    fi
}
function _check_git_aliases() {
	    local typed="$1"
	    local expanded="$2"
	    # sudo will use another user's profile and so aliases would not apply
	    if [[ "$typed" = "sudo "* ]]; then
	        return
	    fi
	    if [[ "$typed" = "git "* ]]; then
	        local found=false
	        git config --get-regexp "^alias\..+$" | sort | while read key value; do
	            key="${key#alias.}"
	            # if for some reason, read does not split correctly, we
	            # detect that and manually split the key and value
	            if [[ -z "$value" ]]; then
	                value="${key#* }"
	                key="${key%% *}"
	            fi
	            if [[ "$expanded" = "git $value" || "$expanded" = "git $value "* ]]; then
	                ysu_message "git alias" "$value" "git $key"
	                found=true
	            fi
:
	        if $found; then
	            _check_ysu_hardcore
	        fi
:
fi
}
function _check_global_aliases() {
	    local typed="$1"
	    local expanded="$2"
	    local found=false
	    local tokens
	    local key
	    local value
	    local entry
	    # sudo will use another user's profile and so aliases would not apply
	    if [[ "$typed" = "sudo "* ]]; then
	        return
	    fi
	    alias -g | sort | while IFS="=" read -r key value; do
	        key="${key## }"
	        key="${key%% }"
:
	        # Skip ignored global aliases
	        if [[ $(__shellx_zsh_subscript_r YSU_IGNORED_GLOBAL_ALIASES "$key") == "$key" ]]; then
	            continue
	        fi
	        if [[ "$typed" = *" $value "* || \
	              "$typed" = *" $value" || \
	              "$typed" = "$value "* || \
	              "$typed" = "$value" ]]; then
	            ysu_message "global alias" "$value" "$key"
	            found=true
	        fi
:
	    if $found; then
	        _check_ysu_hardcore
	    fi
}
function _check_aliases() {
	    local typed="$1"
	    local expanded="${2:-$1}"
	    local found_aliases
	    found_aliases=""
	    local best_match=""
	    local best_match_value=""
	    local key
	    local value
	    # sudo will use another user's profile and so aliases would not apply
	    if [[ "$typed" = "sudo "* ]]; then
	        return
	    fi
	    # Find alias matches
	    for key in "${!aliases[@]}"; do
	        value="$(__shellx_list_get aliases $key)"
	        # Skip ignored aliases
	        if [[ $(__shellx_zsh_subscript_r YSU_IGNORED_ALIASES "$key") == "$key" ]]; then
	            continue
	        fi
	        if [[ "$expanded" = "$value" || "$expanded" = "$value "* ]]; then
	        # if the alias longer or the same length as its command
	        # we assume that it is there to cater for typos.
	        # If not, then the alias would not save any time
	        # for the user and so doesn't hold much value anyway
	        if [[ "${#value}" -gt "${#key}" ]]; then
	            found_aliases+="$key"
	            # Match aliases to longest portion of command
	            if [[ "${#value}" -gt "${#best_match_value}" ]]; then
	                best_match="$key"
	                best_match_value="$value"
	            # on equal length, choose the shortest alias
	            elif [[ "${#value}" -eq "${#best_match}" && ${#key} -lt "${#best_match}" ]]; then
	                best_match="$key"
	                best_match_value="$value"
	            fi
	        fi
	        fi
	    done
	    # Print result matches based on current mode
	    if [[ "$YSU_MODE" = "ALL" ]]; then
:
	            value="$(__shellx_list_get aliases $key)"
	            ysu_message "alias" "$value" "$key"
	            _check_ysu_hardcore "$key"
:
	    elif [[ (-z "$YSU_MODE" || "$YSU_MODE" = "BESTMATCH") && -n "$best_match" ]]; then
	        # make sure that the best matched alias has not already
	        # been typed by the user
	        value="$(__shellx_list_get aliases $best_match)"
	        if [[ "$typed" = "$best_match" || "$typed" = "$best_match "* ]]; then
	            return
	        fi
	        # Check if typed command is an alias that recursively uses best_match
	        local typed_cmd="${typed%% *}"
	        local check_value="$(__shellx_list_get aliases $typed_cmd)"
	        local check_cmd
	        local -A visited_aliases
	        visited_aliases[$typed_cmd]=1
	        # Follow alias chain to see if it eventually uses best_match
	        while [[ -n "$check_value" ]]; do
	            if [[ "$check_value" = "$best_match" || "$check_value" = "$best_match "* ]]; then
	                return
	            fi
	            check_cmd="${check_value%% *}"
	            # Break if we've already visited this alias (cycle detection)
	            if [[ -n "$(__shellx_list_get visited_aliases $check_cmd)" ]]; then
	                break
	            fi
	            visited_aliases[$check_cmd]=1
	            if [[ -n "$(__shellx_list_get aliases $check_cmd)" ]]; then
	                check_value="$(__shellx_list_get aliases $check_cmd)"
	            else
	                break
	            fi
	        done
	        ysu_message "alias" "$value" "$best_match"
	        _check_ysu_hardcore "$best_match"
	    fi
}
function disable_you_should_use() {
	    __shellx_register_preexec _check_aliases
	    __shellx_register_preexec _check_global_aliases
	    __shellx_register_preexec _check_git_aliases
	    __shellx_register_precmd _flush_ysu_buffer
}
function enable_you_should_use() {
	    disable_you_should_use   # Delete any possible pre-existing hooks
	    __shellx_register_preexec _check_aliases
	    __shellx_register_preexec _check_global_aliases
	    __shellx_register_preexec _check_git_aliases
	    __shellx_register_precmd _flush_ysu_buffer
}
#!/bin/zsh
export YSU_VERSION='1.11.0'
if ! type "tput" > /dev/null; then
    printf "WARNING: tput command not found on your PATH.\n"
    printf "zsh-you-should-use will fallback to uncoloured messages\n"
else
    NONE="$(tput sgr0)"
    BOLD="$(tput bold)"
    RED="$(tput setaf 1)"
    YELLOW="$(tput setaf 3)"
    PURPLE="$(tput setaf 5)"
fi
# Writing to a buffer rather than directly to stdout/stderr allows us to decide
# if we want to write the reminder message before or after a command has been executed
# Prevent command from running if hardcore mode enabled
autoload -Uz add-zsh-hook
enable_you_should_use

done
: