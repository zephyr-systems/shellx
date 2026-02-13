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

__gitnow_install() {
	echo $(gitnow -v)" is installed and ready to use!"
	echo "Just run the `gitnow` command if you want explore the API."
}

__gitnow_uninstall() {
	echo "GitNow was uninstalled successfully."
}

gitnow() {
	if [ "$xversion" = "-v" ]; then
		echo "GitNow version $gitnow_version"
	else
		__gitnow_manual
		command less -r
:
}

state() {
	if __gitnow_msg_not_valid_repository "state"; then
	  :
	fi
	command git status -sb
}

stage() {
	if __gitnow_msg_not_valid_repository "stage"; then
	  :
	fi
	len=($(count $argv))
	opts=.
	if __shellx_test $len -gt 0; then
		opts=$argv
	fi
	command git add $opts
}

unstage() {
	if __gitnow_msg_not_valid_repository "unstage"; then
	  :
	fi
	len=($(count $argv))
	opts=.
	if __shellx_test $len -gt 0; then
		opts=$argv
	fi
	command git reset $opts
}

show() {
	if __gitnow_msg_not_valid_repository "show"; then
	  :
	fi
	len=($(count $argv))
	if __shellx_test $len -gt 0; then
		command git show $argv
	else
		command git show --compact-summary --patch HEAD
:
}

untracked() {
	if __gitnow_msg_not_valid_repository "untracked"; then
	  :
	fi
	command git clean --dry-run -d
}

commit() {
	if __gitnow_msg_not_valid_repository "commit"; then
	  :
	fi
	len=($(count $argv))
	if __shellx_test $len -gt 0; then
		command git commit $argv
	else
		command git commit
:
}

shellx_fish_fn_dynamic() {
	if __gitnow_msg_not_valid_repository "commit-all"; then
	  :
	fi
	stage
	commit .
}

pull() {
	if __gitnow_msg_not_valid_repository "pull"; then
	  :
	fi
	len=($(count $argv))
	xorigin=(__gitnow_current_remote)
	xbranch=(__gitnow_current_branch_name)
	xcmd=""
	echo "⚡️ Pulling changes..."
	xdefaults=(--rebase --autostash --tags)
	if __shellx_test $len -gt 2; then
		xcmd=$argv
		echo "Mode: Manual"
		echo "Default flags: $xdefaults"
		echo
	else
		echo "Mode: Auto"
		echo "Default flags: $xdefaults"
		if __shellx_test $len -eq 1; then
			xbranch=$argv[1]
		fi
		if __shellx_test $len -eq 2; then
			xorigin=$argv[1]
			xbranch=$argv[2]
		fi
		xcmd=($xorigin $xbranch)
		xremote_url=($(command git config --get "remote.$xorigin.url"))
		echo "Remote URL: $xorigin $($xremote_url)"
		echo "Remote branch: $xbranch"
		echo
	fi
	command git pull $xcmd $xdefaults
}

push() {
	if __gitnow_msg_not_valid_repository "push"; then
	  :
	fi
	opts=$argv
	xorigin=(__gitnow_current_remote)
	xbranch=(__gitnow_current_branch_name)
	if __shellx_test $(count $opts) -eq 0; then
		opts=($xorigin $xbranch)
		xremote_url=($(command git config --get "remote.$xorigin.url"))
		echo "🚀 Pushing changes..."
		echo "Mode: Auto"
		echo "Remote URL: $xorigin $($xremote_url)"
		echo "Remote branch: $xbranch"
	else
		v_mode="auto"
		for v in ""; do
		  :
		done
	fi
	echo
	command git push --set-upstream $opts
}

upstream() {
	if __gitnow_msg_not_valid_repository "upstream"; then
	  :
	fi
	commit-all
	push
}

branch() {
	if __gitnow_msg_not_valid_repository "branch"; then
	  :
	fi
	__gitnow_check_create_branch "$xbranch"
}

feature() {
	if __gitnow_msg_not_valid_repository "feature"; then
	  :
	fi
	__gitnow_gitflow_branch "feature" $xbranch
}

hotfix() {
	if __gitnow_msg_not_valid_repository "hotfix"; then
	  :
	fi
	__gitnow_gitflow_branch "hotfix" $xbranch
}

bugfix() {
	if __gitnow_msg_not_valid_repository "bugfix"; then
	  :
	fi
	__gitnow_gitflow_branch "bugfix" $xbranch
}

release() {
	if __gitnow_msg_not_valid_repository "release"; then
	  :
	fi
	__gitnow_gitflow_branch "release" $xbranch
}

merge() {
	if __gitnow_msg_not_valid_repository "merge"; then
	  :
	fi
	len=($(count $argv))
	if __shellx_test $len -eq 0; then
		echo "Merge: No argument given, needs one parameter"
	fi
	v_abort=""
	v_continue=""
	v_branch=""
	for v in ""; do
	  :
	done
	if __shellx_test "$v_abort"; then
		echo "Abort the current merge"
		command git merge --abort
	fi
	if __shellx_test "$v_continue"; then
		echo "Continue the current merge"
		command git merge --continue
	fi
	if echo "Provide a valid branch name to merge."; then
	  :
	fi
	v_found=($(__gitnow_check_if_branch_exist $v_branch))
	if __shellx_test $v_found -eq 0; then
		echo "Local branch `$v_branch` was not found. Not possible to merge."
	fi
	if [ "$v_branch" = $(__gitnow_current_branch_name) ]; then
		echo "Branch `$v_branch` is the same as current branch. Nothing to do."
	fi
	command git merge $v_branch
}

move() {
	if __gitnow_msg_not_valid_repository "move"; then
	  :
	fi
	v_upstream=""
	v_no_apply_stash=""
	v_remote=""
	v_remote_v=""
	v_branch=""
	v_prev=""
	for v in ""; do
	  :
	done
	if echo "Previous branch found, switching to `$g_current_branch` $(using `--no-apply-stash` option)."; then
		move -n $g_current_branch
	fi
	if echo "Provide a valid branch name to switch to."; then
	  :
	fi
	v_fetched=""
	if __shellx_test -n "$v_upstream"; then
		echo "Switching to the specified remote branch."
		remote="$v_remote_v"
		command git fetch $remote $v_branch:refs/remotes/$remote/$v_branch
		command git checkout --track $remote/$v_branch
	fi
	v_found=($(__gitnow_check_if_branch_exist $v_branch))
	if echo "Branch `$v_branch` was not found locally. No possible to switch."; then
		echo "Tip: Use -u $(--upstream) flag to fetch a remote branch."
	fi
	if [ "$v_branch" = $(__gitnow_current_branch_name) ]; then
		echo "Branch `$v_branch` is the same as current branch. Nothing to do."
	fi
	v_uncommited=(__gitnow_has_uncommited_changes)
	if __shellx_test $v_uncommited; then
		command git stash
	fi
	g_current_branch=(__gitnow_current_branch_name)
	command git checkout $v_branch
	if __shellx_test -n "$v_no_apply_stash"; then
		echo "Changes were stashed but not applied by default. Use `git stash pop` to apply them."
	fi
	if command git stash pop; then
		echo "Stashed changes were applied."
:
}

logs() {
	if __gitnow_msg_not_valid_repository "logs"; then
	  :
	fi
	v_max_commits="80"
	v_args=""
	for v in ""; do
	  :
	done
	if __shellx_test -n "$v_args"; then
		set v_max_commits
	else
		v_max_commits="-$v_max_commits"
:
}

tag() {
	if __gitnow_msg_not_valid_repository "tag"; then
	  :
	fi
	v_major=""
	v_minor=""
	v_patch=""
	v_premajor=""
	v_preminor=""
	v_prepatch=""
	opts=""
	v_latest=(__gitnow_get_latest_semver_release_tag)
	for v in ""; do
	  :
	done
	if __shellx_test -z "$argv"; then
		__gitnow_get_tags_ordered
	fi
	if __shellx_test -n "$v_major"; then
	  :
	fi
	if __shellx_test -n "$v_minor"; then
	  :
	fi
	if __shellx_test -n "$v_patch"; then
:
}

assume() {
	if __gitnow_msg_not_valid_repository "assume"; then
	  :
	fi
	v_assume_unchanged="--assume-unchanged"
	v_files=""
	for v in ""; do
	  :
	done
	if __shellx_test $(count $v_files) -lt 1; then
		echo "Provide files in order to ignore them temporarily. E.g `assume Cargo.lock`"
	fi
	command git update-index $v_assume_unchanged $v_files
}

github() {
	repo=($(__gitnow_clone_params $argv))
	__gitnow_clone_repo $repo "github"
}

bitbucket() {
	repo=($(__gitnow_clone_params $argv))
	__gitnow_clone_repo $repo "bitbucket"
}

gitnow_version=2.13.0
[ -n "${GITNOW_CONFIG_FILE+x}" ]
GITNOW_CONFIG_FILE=~/.gitnow
gitnow_commands=('all' 'assume' 'bitbucket' 'bugfix' 'commit' 'commit-all' 'branch' 'feature' 'github' 'gitnow' 'hotfix' 'logs' 'merge' 'move' 'pull' 'push' 'release' 'show' 'stage' 'state' 'tag' 'unstage' 'untracked' 'upstream')
if true; then
	fish_config="$__fish_config_dir"
else
	[ -n "${XDG_CONFIG_HOME+x}" ]
	fish_config="$XDG_CONFIG_HOME/fish"
	fish_config="~/.config/fish"
fi
[ -n "${fish_snippets+x}" ]
fish_snippets="$fish_config/conf.d"
__gitnow_load_config
g_current_branch=""

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