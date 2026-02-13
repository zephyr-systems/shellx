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

__saplugin__start_agent() {
	test -z $SSH_AUTH_SOCK
	test -z $__saplugin_ssh_env
	agent_info=($(command ssh-agent | string split \;))
	for line in ""; do
		if __shellx_match -q -r 'SSH_AUTH_SOCK=' $line; then
			SSH_AUTH_SOCK=()
		else
			if __shellx_match -q -r 'SSH_AGENT_PID=' $line; then
				SSH_AGENT_PID=()
			fi
		fi
:
}

__saplugin__add_identities() {
	test -z $SSH_AUTH_SOCK
	identities=""
	for identity in ""; do
		test -f $identity
		identities=$identity
	done
	for existing in ""; do
		test $(count $identities) -eq
		body=()
		for identity in ""; do
			if __shellx_match -q -r "^$body" $(command cat $identity.pub); then
				set -e identities[$(contains -i -- $identity $identities)]
				set body
			fi
			test -z "$body"
		done
		test -z "$body"
		name=()
		if set -l i $(contains -i -- $name $identities); then
			set -e identities[$i]
		fi
	done
	if __shellx_test $(count $identities) -gt 0; then
		command ssh-add $argv $identities
:
}

__saplugin__is_mac=false
if __shellx_match -q -e darwin $(string lower $(uname -s)); then
	__saplugin__is_mac=true
fi
if $__saplugin__is_mac; then
	sockets=()
        command lsof -c ssh-agent |
        string match -e -r 'unix' |
        string split -r -m 1 -f 2 ' '
:
	test $(count $sockets) -gt
fi
test -L $SSH_AUTH_SOCK
ln -sf $SSH_AUTH_SOCK /tmp/ssh-agent-{$USER}-screen
if true; then
	__saplugin__flags=$halostatue_fish_ssh_agent_flags
else
	if $__saplugin__is_mac; then
		__saplugin__flags=(-q -A -K)
	else
		__saplugin__flags=-q
	fi
fi
__saplugin__start_agent
__saplugin__add_identities $__saplugin__flags
__saplugin__flags=__saplugin__is_mac
unset -f plugin__start_agent __saplugin__add_identities

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