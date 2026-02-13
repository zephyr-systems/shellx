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

replay() {
  :
:

: