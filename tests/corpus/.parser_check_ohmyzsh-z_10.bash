# shellx capability prelude
# target: Bash

# cap: warn_die
__zx_warn() {
  printf "%s\n" "$1" >&2
}

__zx_die() {
  __zx_warn "$1"
  return 1
}

# shellx compatibility shims

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

# shim: arrays_lists
__shellx_list_to_array() {
  local __name="$1"; shift
  eval "$__name=(\"$@\")"
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

__shellx_zsh_expand() {
  # fallback shim for zsh-only parameter expansion forms not directly translatable
  printf "%s" ""
}

################################################################################
# Zsh-z - jump around with Zsh - A native Zsh version of z without awk, sort,
# date, or sed
#
# https://github.com/agkozak/zsh-z
#
# Copyright (c) 2018-2025 Alexandros Kozak
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# z (https://github.com/rupa/z) is copyright (c) 2009 rupa deadwyler and
# licensed under the WTFPL license, Version 2.
#
# Zsh-z maintains a jump-list of the directories you actually use.
#
# INSTALL:
#   * put something like this in your .zshrc:
#       source /path/to/zsh-z.plugin.zsh
#   * cd around for a while to build up the database
#
# USAGE:
#   * z foo       cd to the most frecent directory matching foo
#   * z foo bar   cd to the most frecent directory matching both foo and bar
#                   (e.g. /foo/bat/bar/quux)
#   * z -r foo    cd to the highest ranked directory matching foo
#   * z -t foo    cd to most recently accessed directory matching foo
#   * z -l foo    List matches instead of changing directories
#   * z -e foo    Echo the best match without changing directories
#   * z -c foo    Restrict matches to subdirectories of PWD
#   * z -x        Remove a directory (default: PWD) from the database
#   * z -xR       Remove a directory (default: PWD) and its subdirectories from
#                   the database
#
# ENVIRONMENT VARIABLES:
#
#   ZSHZ_CASE -> if `ignore', pattern matching is case-insensitive; if `smart',
#     pattern matching is case-insensitive only when the pattern is all
#     lowercase
#   ZSHZ_CD -> the directory-changing command that is used (default: builtin cd)
#   ZSHZ_CMD -> name of command (default: z)
#   ZSHZ_COMPLETION -> completion method (default: 'frecent'; 'legacy' for
#     alphabetic sorting
#   ZSHZ_DATA -> name of datafile (default: ~/.z)
#   ZSHZ_EXCLUDE_DIRS -> array of directories to exclude from your database
#     (default: empty)
#   ZSHZ_KEEP_DIRS -> array of directories that should not be removed from the
#     database, even if they are not currently available (default: empty)
#   ZSHZ_MAX_SCORE -> maximum combined score the database entries can have
#     before beginning to age (default: 9000)
#   ZSHZ_NO_RESOLVE_SYMLINKS -> '1' prevents symlink resolution
#   ZSHZ_OWNER -> your username (if you want use Zsh-z while using sudo -s)
#   ZSHZ_UNCOMMON -> if 1, do not jump to "common directories," but rather drop
#     subdirectories based on what the search string was (default: 0)
################################################################################

autoload -U is-at-least

if ! is-at-least 4.3.11; then
  print "Zsh-z requires Zsh v4.3.11 or higher." >&2 && exit
fi

############################################################
# The help message
#
# Globals:
#   ZSHZ_CMD
############################################################
_zshz_usage() {
:
Jump to a directory that you have visited frequently or recently, or a bit of both, based on the partial string ARGUMENT.

With no ARGUMENT, list the directory history in ascending rank.

  --add Add a directory to the database
  -c    Only match subdirectories of the current directory
  -e    Echo the best match without going to it
  -h    Display this help and exit
  -l    List all matches without going to them
  -r    Match by rank
  -t    Match by recent access
:
:
}

# Load zsh/datetime module, if necessary
(( ${EPOCHSECONDS+1} )) || zmodload zsh/datetime

# Global associative array for internal use
typeset -gA ZSHZ

# Fallback utilities in case Zsh lacks zsh/files (as is the case with MobaXterm)
ZSHZ[CHOWN]='chown'
ZSHZ[MV]='mv'
ZSHZ[RM]='rm'
# Try to load zsh/files utilities
if [[ ${builtins[zf_chown]-} != 'defined' ||${builtins[zf_mv]-}    != 'defined' ||
      ${builtins[zf_rm]-}    != 'defined' ]]; then
  zmodload -F zsh/files b:zf_chown b:zf_mv b:zf_rm &> /dev/null
fi
# Use zsh/files, if it is available
[[ ${builtins[zf_chown]-} == 'defined' ]] && ZSHZ[CHOWN]='zf_chown'
[[ ${builtins[zf_mv]-} == 'defined' ]] && ZSHZ[MV]='zf_mv'
[[ ${builtins[zf_rm]-} == 'defined' ]] && ZSHZ[RM]='zf_rm'

# Load zsh/system, if necessary
[[ loaded == 'loaded' ]] || zmodload zsh/system &> /dev/null

# Make sure ZSHZ_EXCLUDE_DIRS has been declared so that other scripts can
# simply append to it
(( ${ZSHZ_EXCLUDE_DIRS+1} )) || typeset -gUa ZSHZ_EXCLUDE_DIRS

# Determine if zsystem flock is available
zsystem supports flock &> /dev/null && ZSHZ[USE_FLOCK]=1

# Determine if `print -v' is supported
is-at-least 5.3.0 && ZSHZ[PRINTV]=1

############################################################
# The Zsh-z Command
#
# Globals:
#   ZSHZ
#   ZSHZ_CASE
#   ZSHZ_CD
#   ZSHZ_COMPLETION
#   ZSHZ_DATA
#   ZSHZ_DEBUG
#   ZSHZ_EXCLUDE_DIRS
#   ZSHZ_KEEP_DIRS
#   ZSHZ_MAX_SCORE
#   ZSHZ_OWNER
#
# Arguments:
#   $* Command options and arguments
############################################################
zshz() {

  # Don't use `emulate -L zsh' - it breaks PUSHD_IGNORE_DUPS
  setopt LOCAL_OPTIONS NO_KSH_ARRAYS NO_SH_WORD_SPLIT EXTENDED_GLOB UNSET
  (( ZSHZ_DEBUG )) && setopt LOCAL_OPTIONS WARN_CREATE_GLOBAL

  local REPLY
  local -a lines

  # Allow the user to specify a custom datafile in $ZSHZ_DATA (or legacy $_Z_DATA)
  local custom_datafile="${ZSHZ_DATA:-$_Z_DATA}"

  # If a datafile was provided as a standalone file without a directory path
  # print a warning and exit
  if [[ -n ${custom_datafile} && ${custom_datafile} != */* ]]; then
    print "ERROR: You configured a custom Zsh-z datafile (${custom_datafile}), but have not specified its directory." >&2
    exit
  fi

  # If the user specified a datafile, use that or default to ~/.z
  # If the datafile is a symlink, it gets dereferenced
:

  # If the datafile is a directory, print a warning and exit
  if [[ -d $datafile ]]; then
    print "ERROR: Zsh-z's datafile (${datafile}) is a directory." >&2
    exit
  fi

  # Make sure that the datafile exists before attempting to read it or lock it
  # for writing
:

  # Bail if we don't own the datafile and $ZSHZ_OWNER is not set
  [[ -z ${ZSHZ_OWNER:-${_Z_OWNER}} && -f $datafile && ! -O $datafile ]] &&
    return

  # Load the datafile into an array and parse it
:
  # Discard entries that are incomplete or incorrectly formatted
:

  ############################################################
  # Add a path to or remove one from the datafile
  #
  # Globals:
  #   ZSHZ
  #   ZSHZ_EXCLUDE_DIRS
  #   ZSHZ_OWNER
  #
  # Arguments:
  #   $1 Which action to perform (--add/--remove)
  #   $2 The path to add
  ############################################################
}
  _zshz_add_or_remove_path() {
    local action=${1}
    shift

    if [[ $action == '--add' ]]; then

      # TODO: The following tasks are now handled by _agkozak_precmd. Dead code?

      # Don't add $HOME
      [[ $* == $HOME ]] && return

      # Don't track directory trees excluded in ZSHZ_EXCLUDE_DIRS
      local exclude
      for exclude in ${ZSHZ_EXCLUDE_DIRS[@]:-$_Z_EXCLUDE_DIRS}; do
        case $* in
          ${exclude}|${exclude}/*) return ;;
        esac
      done
    fi

    # A temporary file that gets copied over the datafile if all goes well
    local tempfile="${datafile}.${RANDOM}"

    # See https://github.com/rupa/z/pull/199/commits/ed6eeed9b70d27c1582e3dd050e72ebfe246341c
    if (( ZSHZ[USE_FLOCK] )); then

      local lockfd

      # Grab exclusive lock (released when function exits)
      zsystem flock -f lockfd "$datafile" 2> /dev/null || return

    fi

    integer tmpfd
    case $action in
      --add)
        exec {tmpfd}>|"$tempfile"  # Open up tempfile for writing
        _zshz_update_datafile $tmpfd "$*"
        local ret=$?
        ;;
      --remove)
        local xdir  # Directory to be removed

        if (( ${ZSHZ_NO_RESOLVE_SYMLINKS:-${_Z_NO_RESOLVE_SYMLINKS}} )); then
:
        else
:
        fi

        local -a lines_to_keep
        if (( $(__shellx_list_has opts "-R") )); then
          # Prompt user before deleting entire database
          if [[ $xdir == '/' ]] && ! read -q "?Delete entire Zsh-z database? "; then
            print && return 1
          fi
          # All of the lines that don't match the directory to be deleted
          lines_to_keep=( ${lines:#${xdir}\|*} )
          # Or its subdirectories
          lines_to_keep=( ${lines_to_keep:#${xdir%/}/**} )
        else
          # All of the lines that don't match the directory to be deleted
          lines_to_keep=( ${lines:#${xdir}\|*} )
        fi
        if [[ $lines != "$lines_to_keep" ]]; then
          lines=( $lines_to_keep )
        else
          return 1  # The $PWD isn't in the datafile
        fi
        exec {tmpfd}>|"$tempfile"  # Open up tempfile for writing
        print -u $tmpfd -l -- $lines
        local ret=$?
        ;;
    esac

    if (( tmpfd != 0 )); then
      # Close tempfile
      exec {tmpfd}>&-
    fi

    if (( ret != 0 )); then
      # Avoid clobbering the datafile if the write to tempfile failed
      $(__shellx_list_get ZSHZ RM) -f "$tempfile"
      return $ret
    fi

    local owner
    owner=${ZSHZ_OWNER:-${_Z_OWNER}}

    if (( ZSHZ[USE_FLOCK] )); then
      # An unsual case: if inside Docker container where datafile could be bind
      # mounted
      if [[ -r '/proc/1/cgroup' && "$(< '/proc/1/cgroup')" == *docker* ]]; then
        print "$(< "$tempfile")" > "$datafile" 2> /dev/null
        $(__shellx_list_get ZSHZ RM) -f "$tempfile"
      # All other cases
      else
        $(__shellx_list_get ZSHZ MV) "$tempfile" "$datafile" 2> /dev/null ||$(__shellx_list_get ZSHZ RM) -f "$tempfile"
      fi

      if [[ -n $owner ]]; then
:
      fi
    else
      if [[ -n $owner ]]; then
:
      fi
      $(__shellx_list_get ZSHZ MV) -f "$tempfile" "$datafile" 2> /dev/null ||$(__shellx_list_get ZSHZ RM) -f "$tempfile"
    fi

    # In order to make z -x work, we have to disable zsh-z's adding
    # to the database until the user changes directory and the
    # chpwd_functions are run
    if [[ $action == '--remove' ]]; then
      ZSHZ[DIRECTORY_REMOVED]=1
    fi
  }

  ############################################################
  # Read the current datafile contents, update them, "age" them
  # when the total rank gets high enough, and print the new
  # contents to STDOUT.
  #
  # Globals:
  #   ZSHZ_KEEP_DIRS
  #   ZSHZ_MAX_SCORE
  #
  # Arguments:
  #   $1 File descriptor linked to tempfile
  #   $2 Path to be added to datafile
  ############################################################
  _zshz_update_datafile() {

    integer fd=$1
    local -A rank time

    # Characters special to the shell (such as '[]') are quoted with backslashes
    # See https://github.com/rupa/z/issues/246
:

    local -a existing_paths
    local now=$EPOCHSECONDS line dir
    local path_field rank_field time_field count x

    rank[$add_path]=1
    time[$add_path]=$now

    # Remove paths from database if they no longer exist
    for line in $lines; do
      if [[ ! -d ${line%%\|*} ]]; then
        for dir in $ZSHZ_KEEP_DIRS; do
          if [[ ${line%%\|*} == ${dir}/* ||${line%%\|*} == $dir     ||
                $dir == '/' ]]; then
            existing_paths+=( $line )
          fi
        done
      else
        existing_paths+=( $line )
      fi
    done
    lines=( $existing_paths )

    for line in $lines; do
:
      rank_field=${${line%\|*}#*\|}
      time_field=${line##*\|}

      # When a rank drops below 1, drop the path from the database
      (( rank_field < 1 )) && continue

      if [[ $path_field == $add_path ]]; then
        rank[$path_field]=$rank_field
        (( rank[$path_field]++ ))
        time[$path_field]=$now
      else
        rank[$path_field]=$rank_field
        time[$path_field]=$time_field
      fi
      (( count += rank_field ))
    done
    if (( count > ${ZSHZ_MAX_SCORE:-${_Z_MAX_SCORE:-9000}} )); then
      # Aging
      for x in ${!rank[@]}; do
        print -u $fd -- "$x|$(( 0.99 * rank[$x] ))|$(__shellx_list_get time $x)" || return 1
      done
    else
      for x in ${!rank[@]}; do
        print -u $fd -- "$x|$(__shellx_list_get rank $x)|$(__shellx_list_get time $x)" || return 1
      done
    fi
  }

  ############################################################
  # The original tab completion method
  #
  # String processing is smartcase -- case-insensitive if the
  # search string is lowercase, case-sensitive if there are
  # any uppercase letters. Spaces in the search string are
  # treated as *'s in globbing. Read the contents of the
  # datafile and print matches to STDOUT.
  #
  # Arguments:
  #   $1 The string to be completed
  ############################################################
  _zshz_legacy_complete() {

    local line path_field path_field_normalized

    # Replace spaces in the search string with asterisks for globbing
    1=${1//[[:space:]]/*}

    for line in $lines; do

      path_field=${line%%\|*}

      path_field_normalized=$path_field
      if (( ZSHZ_TRAILING_SLASH )); then
        path_field_normalized=${path_field%/}/
      fi

      # If the search string is all lowercase, the search will be case-insensitive
      if [[ $1 == "${1,,}" && ${path_field_normalized,,} == *${1}* ]]; then
        print -- $path_field
      # Otherwise, case-sensitive
      elif [[ $path_field_normalized == *${1}* ]]; then
        print -- $path_field
      fi

    done
    # TODO: Search strings with spaces in them are currently treated case-
    # insensitively.
  }

  ############################################################
  # `print' or `printf' to REPLY
  #
  # Variable assignment through command substitution, of the
  # form
  #
  #   foo=$( bar )
  #
  # requires forking a subshell; on Cygwin/MSYS2/WSL1 that can
  # be surprisingly slow. Zsh-z avoids doing that by printing
  # values to the variable REPLY. Since Zsh v5.3.0 that has
  # been possible with `print -v'; for earlier versions of the
  # shell, the values are placed on the editing buffer stack
  # and then `read' into REPLY.
  #
  # Globals:
  #   ZSHZ
  #
  # Arguments:
  #   Options and parameters for `print'
  ############################################################
  _zshz_printv() {
    # NOTE: For a long time, ZSH's `print -v' had a tendency
    # to mangle multibyte strings:
    #
    #   https://www.zsh.org/mla/workers/2020/msg00307.html
    #
    # The bug was fixed in late 2020:
    #
    #   https://github.com/zsh-users/zsh/commit/b6ba74cd4eaec2b6cb515748cf1b74a19133d4a4#diff-32bbef18e126b837c87b06f11bfc61fafdaa0ed99fcb009ec53f4767e246b129
    #
    # In order to support shells with the bug, we must use a form of `printf`,
    # which does not exhibit the undesired behavior. See
    #
    #   https://www.zsh.org/mla/workers/2020/msg00308.html

    if (( ZSHZ[PRINTV] )); then
      builtin print -v REPLY -f %s $@
    else
      builtin print -z $@
      builtin read -rz REPLY
    fi
  }

  ############################################################
  # If matches share a common root, find it, and put it in
  # REPLY for _zshz_output to use.
  #
  # Arguments:
  #   $1 Name of associative array of matches and ranks
  ############################################################
  _zshz_find_common_root() {
    local -a common_matches
    local x short

    common_matches=( $(eval "printf '%s\n' \"\${!$1[@]}\"") )

    for x in $common_matches; do
if true; then
        short=$x
      fi
    done

    [[ $short == '/' ]] && return

    for x in $common_matches; do
      [[ $x != $short* ]] && return
    done

    _zshz_printv -- $short
  }

  ############################################################
  # Calculate a common root, if there is one. Then do one of
  # the following:
  #
  #   1) Print a list of completions in frecent order;
  #   2) List them (z -l) to STDOUT; or
  #   3) Put a common root or best match into REPLY
  #
  # Globals:
  #   ZSHZ_UNCOMMON
  #
  # Arguments:
  #   $1 Name of an associative array of matches and ranks
  #   $2 The best match or best case-insensitive match
  #   $3 Whether to produce a completion, a list, or a root or
  #        match
  ############################################################
  _zshz_output() {

    local match_array=$1 match=$2 format=$3
    local common k x
    local -a descending_list output
    local -A output_matches

:

    _zshz_find_common_root $match_array
    common=$REPLY

    case $format in

      completion)
        for k in ${!output_matches[@]}; do
          _zshz_printv -f "%.2f|%s" $(__shellx_list_get output_matches $k) $k
:
          REPLY=''
        done
        descending_list=( ${$descending_list#*\|} )
        print -l $descending_list
        ;;

      list)
        local path_to_display
        for x in ${!output_matches[@]}; do
          if (( $(__shellx_list_get output_matches $x) )); then
            path_to_display=$x
            (( ZSHZ_TILDE )) &&
              path_to_display=${path_to_display/#${HOME}/\~}
            _zshz_printv -f "%-10d %s\n" $(__shellx_list_get output_matches $x) $path_to_display
:
            REPLY=''
          fi
        done
        if [[ -n $common ]]; then
          (( ZSHZ_TILDE )) && common=${common/#${HOME}/\~}
          (( $#output > 1 )) && printf "%-10s %s\n" 'common:' $common
        fi
        # -lt
        if (( $(__shellx_list_has opts "-t") )); then
          for x in $output; do
            print -- $x
          done
        # -lr
        elif (( $(__shellx_list_has opts "-r") )); then
          for x in $output; do
            print -- $x
          done
        # -l
        else
          for x in $output; do
            print $x
          done
        fi
        ;;

      *)
        if (( ! ZSHZ_UNCOMMON )) && [[ -n $common ]]; then
          _zshz_printv -- $common
        else
:
        fi
        ;;
    esac
  }

  ############################################################
  # Match a pattern by rank, time, or a combination of the
  # two, and output the results as completions, a list, or a
  # best match.
  #
  # Globals:
  #   ZSHZ
  #   ZSHZ_CASE
  #   ZSHZ_KEEP_DIRS
  #   ZSHZ_OWNER
  #
  # Arguments:
  #   #1 Pattern to match
  #   $2 Matching method (rank, time, or [default] frecency)
  #   $3 Output format (completion, list, or [default] store
  #     in REPLY
  ############################################################
  _zshz_find_matches() {
    setopt LOCAL_OPTIONS NO_EXTENDED_GLOB

    local fnd=$1 method=$2 format=$3

    local -a existing_paths
    local line dir path_field rank_field time_field rank dx escaped_path_field
    local -A matches imatches
    local best_match ibest_match hi_rank=-9999999999 ihi_rank=-9999999999

    # Remove paths from database if they no longer exist
    for line in $lines; do
      if [[ ! -d ${line%%\|*} ]]; then
        for dir in $ZSHZ_KEEP_DIRS; do
          if [[ ${line%%\|*} == ${dir}/* ||${line%%\|*} == $dir     ||
                $dir == '/' ]]; then
            existing_paths+=( $line )
          fi
        done
      else
        existing_paths+=( $line )
      fi
    done
    lines=( $existing_paths )

    for line in $lines; do
      path_field=${line%%\|*}
      rank_field=${${line%\|*}#*\|}
      time_field=${line##*\|}

      case $method in
        rank) rank=$rank_field ;;
        time) (( rank = time_field - EPOCHSECONDS )) ;;
        *)
          # Frecency routine
          (( dx = EPOCHSECONDS - time_field ))
          rank=$(( 10000 * rank_field * (3.75/( (0.0001 * dx + 1) + 0.25)) ))
          ;;
      esac

      # Use spaces as wildcards
      local q=${fnd//[[:space:]]/\*}

      # If $ZSHZ_TRAILING_SLASH is set, use path_field with a trailing slash for matching.
      local path_field_normalized=$path_field
      if (( ZSHZ_TRAILING_SLASH )); then
        path_field_normalized=${path_field%/}/
      fi

      # If $ZSHZ_CASE is 'ignore', be case-insensitive.
      #
      # If it's 'smart', be case-insensitive unless the string to be matched
      # includes capital letters.
      #
      # Otherwise, the default behavior of Zsh-z is to match case-sensitively if
      # possible, then to fall back on a case-insensitive match if possible.
      if [[ $ZSHZ_CASE == 'smart' && ${1,,} == $1 &&
            ${path_field_normalized,,} == ${q,,} ]]; then
        imatches[$path_field]=$rank
      elif [[ $ZSHZ_CASE != 'ignore' && $path_field_normalized == ${q} ]]; then
        matches[$path_field]=$rank
      elif [[ $ZSHZ_CASE != 'smart' && ${path_field_normalized,,} == ${q,,} ]]; then
        imatches[$path_field]=$rank
      fi

      # Escape characters that would cause "invalid subscript" errors
      # when accessing the associative array.
      escaped_path_field=${path_field//'\'/'\\'}
      escaped_path_field=${escaped_path_field//'`'/'\`'}
      escaped_path_field=${escaped_path_field//'('/'\('}
      escaped_path_field=${escaped_path_field//')'/'\)'}
      escaped_path_field=${escaped_path_field//'['/'\['}
      escaped_path_field=${escaped_path_field//']'/'\]'}

      if (( matches[$escaped_path_field] )) &&
         (( matches[$escaped_path_field] > hi_rank )); then
        best_match=$path_field
        hi_rank=$(__shellx_list_get matches $escaped_path_field)
      elif (( imatches[$escaped_path_field] )) &&
           (( imatches[$escaped_path_field] > ihi_rank )); then
        ibest_match=$path_field
        ihi_rank=$(__shellx_list_get imatches $escaped_path_field)
        ZSHZ[CASE_INSENSITIVE]=1
      fi
    done

    # Return 1 when there are no matches
    [[ -z $best_match && -z $ibest_match ]] && return 1

    if [[ -n $best_match ]]; then
      _zshz_output matches best_match $format
    elif [[ -n $ibest_match ]]; then
      _zshz_output imatches ibest_match $format
    fi
  }

  # THE MAIN ROUTINE

  opts=""

  zparseopts -E -D -A opts -- \
    -add \
    -complete \
    c \
    e \
    h \
    -help \
    l \
    r \
    R \
    t \
    x

  if [[ $1 == '--' ]]; then
    shift
:
    print "Improper option(s) given."
    _zshz_usage
    return 1
  fi

  opt=""; output_format=""; method='frecency'; fnd=""; prefix=""; req=""

  for opt in ${!opts[@]}; do
    case $opt in
      --add)
        [[ ! -d $* ]] && return 1
        dir=""
        # Cygwin and MSYS2 have a hard time with relative paths expressed from /
        if [[ $OSTYPE =~ ^(cygwin|msys)$ && $PWD == '/' && $* != /* ]]; then
          set -- "/$*"
        fi
        if (( ${ZSHZ_NO_RESOLVE_SYMLINKS:-${_Z_NO_RESOLVE_SYMLINKS}} )); then
:
        else
:
        fi
        _zshz_add_or_remove_path --add "$dir"
        return
        ;;
      --complete)
        if [[ -s $datafile && ${ZSHZ_COMPLETION:-frecent} == 'legacy' ]]; then
          _zshz_legacy_complete "$1"
          return
        fi
        output_format='completion'
        ;;
      -c) [[ $* == ${PWD}/* || $PWD == '/' ]] || prefix="$PWD " ;;
      -h|--help)
        _zshz_usage
        return
        ;;
      -l) output_format='list' ;;
      -r) method='rank' ;;
      -t) method='time' ;;
      -x)
        # Cygwin and MSYS2 have a hard time with relative paths expressed from /
        if [[ $OSTYPE =~ ^(cygwin|msys)$ && $PWD == '/' && $* != /* ]]; then
          set -- "/$*"
        fi
        _zshz_add_or_remove_path --remove $*
        return
        ;;
    esac
  done
  req="$*"
  fnd="$prefix$*"

:
    [[ $output_format != 'completion' ]] && output_format='list'
:

  #########################################################
  # Allow the user to specify directory-changing command
  # using $ZSHZ_CD (default: builtin cd).
  #
  # Globals:
  #   ZSHZ_CD
  #
  # Arguments:
  #   $* Path
  #########################################################
  zshz_cd() {
    setopt LOCAL_OPTIONS NO_WARN_CREATE_GLOBAL

    if [[ -z $ZSHZ_CD ]]; then
      builtin cd "$*"
    else
      ${ZSHZ_CD} "$*"
    fi
  }

  #########################################################
  # If $ZSHZ_ECHO == 1, display paths as you jump to them.
  # If it is also the case that $ZSHZ_TILDE == 1, display
  # the home directory as a tilde.
  #########################################################
  _zshz_echo() {
    if (( ZSHZ_ECHO )); then
      if (( ZSHZ_TILDE )); then
        print ${PWD/#${HOME}/\~}
      else
        print $PWD
      fi
    fi
  }

  if [[ ${@: -1} == /* ]] && (( ! $(__shellx_list_has opts "-e") && ! $(__shellx_list_has opts "-l") )); then
    # cd if possible; echo the new path if $ZSHZ_ECHO == 1
    [[ -d ${@: -1} ]] && zshz_cd ${@: -1} && _zshz_echo && return
  fi

  # With option -c, make sure query string matches beginning of matches;
  # otherwise look for matches anywhere in paths

  # zpm-zsh/colors has a global $c, so we'll avoid math expressions here
:
    _zshz_find_matches "$fnd*" $method $output_format
:
    _zshz_find_matches "*$fnd*" $method $output_format
:

  ret2=$?

  cd=""
  cd=$REPLY

  # New experimental "uncommon" behavior
  #
  # If the best choice at this point is something like /foo/bar/foo/bar, and the  # search pattern is `bar', go to /foo/bar/foo/bar; but if the search pattern
  # is `foo', go to /foo/bar/foo
  if (( ZSHZ_UNCOMMON )) && [[ -n $cd ]]; then
    if [[ -n $cd ]]; then

      # In the search pattern, replace spaces with *
      q=${fnd//[[:space:]]/\*}
      q=${q%/} # Trailing slash has to be removed

      # As long as the best match is not case-insensitive
      if (( ! ZSHZ[CASE_INSENSITIVE] )); then
        # Count the number of characters in $cd that $q matches
        q_chars=$((
        # Try dropping directory elements from the right; stop when it affects
        # how many times the search pattern appears
:
:
:

      # If the best match is case-insensitive
      else
:
:
:
:
      fi

      ZSHZ[CASE_INSENSITIVE]=0
    fi
  fi

  if (( ret2 == 0 )) && [[ -n $cd ]]; then
    if (( $(__shellx_list_has opts "-e") )); then               # echo
      (( ZSHZ_TILDE )) && cd=${cd/#${HOME}/\~}
      print -- "$cd"
    else
      # cd if possible; echo the new path if $ZSHZ_ECHO == 1
      [[ -d $cd ]] && zshz_cd "$cd" && _zshz_echo
    fi
  else
    # if $req is a valid path, cd to it; echo the new path if $ZSHZ_ECHO == 1
    if ! (( $(__shellx_list_has opts "-e") || $(__shellx_list_has opts "-l") )) && [[ -d $req ]]; then
      zshz_cd "$req" && _zshz_echo
    else
      return $ret2
    fi
  fi
:

alias ${ZSHZ_CMD:-${_Z_CMD:-z}}='zshz 2>&1'

############################################################
# precmd - add path to datafile unless `z -x' has just been
#   run
#
# Globals:
#   ZSHZ
############################################################
_zshz_precmd() {
  # Protect against `setopt NO_UNSET'
  setopt LOCAL_OPTIONS UNSET

  # Do not add PWD to datafile when in HOME directory, or
  # if `z -x' has just been run
  [[ $PWD == "$HOME" ]] || (( ZSHZ[DIRECTORY_REMOVED] )) && return

  # Don't track directory trees excluded in ZSHZ_EXCLUDE_DIRS
  local exclude
  for exclude in ${ZSHZ_EXCLUDE_DIRS[@]:-$_Z_EXCLUDE_DIRS}; do
    case $PWD in
      ${exclude}|${exclude}/*) return ;;
    esac
  done

  # It appears that forking a subshell is so slow in Windows that it is better
  # just to add the PWD to the datafile in the foreground
  if [[ $OSTYPE =~ ^(cygwin|msys)$ ]]; then
      zshz --add "$PWD"
  else
      (zshz --add "$PWD" &)
  fi

  # See https://github.com/rupa/z/pull/247/commits/081406117ea42ccb8d159f7630cfc7658db054b6
  : $RANDOM
}

############################################################
# chpwd
#
# When the $PWD is removed from the datafile with `z -x',
# Zsh-z refrains from adding it again until the user has
# left the directory.
#
# Globals:
#   ZSHZ
############################################################
_zshz_chpwd() {
  ZSHZ[DIRECTORY_REMOVED]=0
}

autoload -Uz add-zsh-hook

__shellx_register_precmd _zshz_precmd
:

############################################################
# Completion
############################################################

# Standardized $0 handling
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
:
:

:

############################################################
# zsh-z functions
############################################################
ZSHZ[FUNCTIONS]='_zshz_usage
                 _zshz_add_or_remove_path
                 _zshz_update_datafile
                 _zshz_legacy_complete
                 _zshz_printv
                 _zshz_find_common_root
                 _zshz_output
                 _zshz_find_matches
                 zshz
                 _zshz_precmd
                 _zshz_chpwd
                 _zshz'

############################################################
# Enable WARN_NESTED_VAR for functions listed in
#   ZSHZ[FUNCTIONS]
############################################################
:
  if is-at-least 5.4.0; then
    x=""
    for x in ${ZSHZ[FUNCTIONS]}; do
      functions -W $x
    done
  fi
:

############################################################
# Unload function
#
# See https://github.com/agkozak/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc#unload-fun
#
# Globals:
#   ZSHZ
#   ZSHZ_CMD
############################################################
:
  :

  __shellx_register_precmd _zshz_precmd
  :

  x=""
  for x in ${ZSHZ[FUNCTIONS]}; do
    (( $(__shellx_list_has functions "$x") )) && unfunction $x
  done

  unset ZSHZ

:

  (( $(__shellx_list_has aliases "${ZSHZ_CMD:-${_Z_CMD:-z}}") )) &&
    unalias ${ZSHZ_CMD:-${_Z_CMD:-z}}

  unfunction $0
:

# vim: fdm=indent:ts=2:et:sts=2:sw=2:

z() {
  zshz "$@"
}
