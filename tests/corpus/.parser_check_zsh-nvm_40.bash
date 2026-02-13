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

:

[[ -z "$NVM_DIR" ]] && export NVM_DIR="$HOME/.nvm"

_zsh_nvm_rename_function() {
  test -n "$(declare -f $1)" || return
  eval "${_/$1/$2}"
  unset -f $1
}

_zsh_nvm_has() {
  type "$1" > /dev/null 2>&1
}

_zsh_nvm_latest_release_tag() {
  echo $(builtin cd "$NVM_DIR" && git fetch --quiet --tags origin && git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1))
}

_zsh_nvm_install() {
  echo "Installing nvm..."
  git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
  $(builtin cd "$NVM_DIR" && git checkout --quiet "$(_zsh_nvm_latest_release_tag)")
}

_zsh_nvm_global_binaries() {

  # Look for global binaries
  local global_binary_paths="$(echo "$NVM_DIR"/v0*/bin/* "$NVM_DIR"/versions/*/*/bin/*)"

  # If we have some, format them
  if [[ -n "$global_binary_paths" ]]; then
    echo "$NVM_DIR"/v0*/bin/* "$NVM_DIR"/versions/*/*/bin/* |xargs -n 1 basename |
      sort |uniq
  fi
}

_zsh_nvm_load() {

  # Source nvm (check if `nvm use` should be ran after load)
  if [[ "$NVM_NO_USE" == true ]]; then
    source "$NVM_DIR/nvm.sh" --no-use
  else
    source "$NVM_DIR/nvm.sh"
  fi

  # Rename main nvm function
  _zsh_nvm_rename_function nvm _zsh_nvm_nvm

  # Wrap nvm in our own function
}
  nvm() {
    case $1 in
      'upgrade')
        _zsh_nvm_upgrade
        ;;
      'revert')
        _zsh_nvm_revert
        ;;
      'use')
        _zsh_nvm_nvm "$@"
        export NVM_AUTO_USE_ACTIVE=false
        ;;
      'install' | 'i')
        _zsh_nvm_install_wrapper "$@"
        ;;
      *)
        _zsh_nvm_nvm "$@"
        ;;
    esac
  }
:

_zsh_nvm_completion() {

  # Add provided nvm completion
  [[ -r $NVM_DIR/bash_completion ]] && source $NVM_DIR/bash_completion
}

_zsh_nvm_lazy_load() {

  # Get all global node module binaries including node
  # (only if NVM_NO_USE is off)
  local global_binaries
  if [[ "$NVM_NO_USE" == true ]]; then
    global_binaries=()
  else
    global_binaries=($(_zsh_nvm_global_binaries))
  fi

  # Add yarn lazy loader if it's been installed by something other than npm
  _zsh_nvm_has yarn && global_binaries+=('yarn')

  # Add nvm
  global_binaries+=('nvm')
  global_binaries+=($NVM_LAZY_LOAD_EXTRA_COMMANDS)

  # Remove any binaries that conflict with current aliases
  local cmds
  cmds=()
  local bin
  for bin in $global_binaries; do
    [[ "$(which $bin 2> /dev/null)" = "$bin: aliased to "* ]] || cmds+=($bin)
  done

  # Create function for each command
  local cmd
  for cmd in $cmds; do

    # When called, unset all lazy loaders, load nvm then run current command
:
      unset -f $cmds > /dev/null 2>&1
      _zsh_nvm_load
      $cmd \"\$@\"
:
:
:

}
nvm_update() {
  echo 'Deprecated, please use `nvm upgrade`'
}
_zsh_nvm_upgrade() {

  # Use default upgrade if it's built in
  if [[ -n "$(_zsh_nvm_nvm help | grep 'nvm upgrade')" ]]; then
    _zsh_nvm_nvm upgrade
    return
  fi

  # Otherwise use our own
  local installed_version=$(builtin cd "$NVM_DIR" && git describe --tags)
  echo "Installed version is $installed_version"
  echo "Checking latest version of nvm..."
  local latest_version=$(_zsh_nvm_latest_release_tag)
  if [[ "$installed_version" = "$latest_version" ]]; then
    echo "You're already up to date"
  else
    echo "Updating to $latest_version..."
    echo "$installed_version" > "$ZSH_NVM_DIR/previous_version"
    $(builtin cd "$NVM_DIR" && git fetch --quiet && git checkout "$latest_version")
    _zsh_nvm_load
  fi
}

_zsh_nvm_previous_version() {
  cat "$ZSH_NVM_DIR/previous_version" 2>/dev/null
}

_zsh_nvm_revert() {
  local previous_version="$(_zsh_nvm_previous_version)"
  if [[ -n "$previous_version" ]]; then
    local installed_version=$(builtin cd "$NVM_DIR" && git describe --tags)
    if [[ "$installed_version" = "$previous_version" ]]; then
      echo "Already reverted to $installed_version"
      return
    fi
    echo "Installed version is $installed_version"
    echo "Reverting to $previous_version..."
    $(builtin cd "$NVM_DIR" && git checkout "$previous_version")
    _zsh_nvm_load
  else
    echo "No previous version found"
  fi
}

autoload -U add-zsh-hook
_zsh_nvm_auto_use() {
  _zsh_nvm_has nvm_find_nvmrc || return

  local node_version="$(nvm version)"
  local nvmrc_path="$(nvm_find_nvmrc)"

  if [[ -n "$nvmrc_path" ]]; then
    local nvmrc_node_version="$(nvm version $(cat "$nvmrc_path"))"

    if [[ "$nvmrc_node_version" = "N/A" ]]; then
      nvm install && export NVM_AUTO_USE_ACTIVE=true
    elif [[ "$nvmrc_node_version" != "$node_version" ]]; then
      nvm use && export NVM_AUTO_USE_ACTIVE=true
    fi
  elif [[ "$node_version" != "$(nvm version default)" ]] && [[ "$NVM_AUTO_USE_ACTIVE" = true ]]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}

_zsh_nvm_install_wrapper() {
  case $2 in
    'rc')
      NVM_NODEJS_ORG_MIRROR=https://nodejs.org/download/rc/ nvm install node && nvm alias rc "$(node --version)"
      echo "Clearing mirror cache..."
      nvm ls-remote > /dev/null 2>&1
      echo "Done!"
      ;;
    'nightly')
      NVM_NODEJS_ORG_MIRROR=https://nodejs.org/download/nightly/ nvm install node && nvm alias nightly "$(node --version)"
      echo "Clearing mirror cache..."
      nvm ls-remote > /dev/null 2>&1
      echo "Done!"
      ;;
    *)
      _zsh_nvm_nvm "$@"
      ;;
  esac
}

# Don't init anything if this is true (debug/testing only)
if [[ "$ZSH_NVM_NO_LOAD" != true ]]; then

  # Install nvm if it isn't already installed
  [[ ! -f "$NVM_DIR/nvm.sh" ]] && _zsh_nvm_install

  # If nvm is installed
  if [[ -f "$NVM_DIR/nvm.sh" ]]; then

    # Load it
    [[ "$NVM_LAZY_LOAD" == true ]] && _zsh_nvm_lazy_load || _zsh_nvm_load

    # Enable completion
    [[ "$NVM_COMPLETION" == true ]] && _zsh_nvm_completion
    
    # Auto use nvm on chpwd
    [[ "$NVM_AUTO_USE" == true ]] && :
  fi

fi

# Make sure we always return good exit code
# We can't `return 0` because that breaks antigen
true

done
: