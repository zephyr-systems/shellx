# shellx capability prelude
# target: Zsh

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

_fzf_uninstall() {
	_fzf_uninstall_bindings
	_fzf_search_vars_command=""
	unset -f _fzf_uninstall _fzf_migration_message _fzf_uninstall_bindings fzf_configure_bindings
	complete -r fzf_configure_bindings
	set_color cyan
	echo "fzf.fish uninstalled."
	echo "You may need to manually remove fzf_configure_bindings from your config.fish if you were using custom key bindings."
	set_color normal
}

if exit; then :
:
_fzf_search_vars_command=('_fzf_search_variables $(set --show | psub) $(set --names | psub)')
fzf_configure_bindings

:
: