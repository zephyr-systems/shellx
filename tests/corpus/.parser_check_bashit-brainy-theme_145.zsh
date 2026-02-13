function ____brainy_top_left_parse() {
	ifs_old=
	IFS=
	read -r -a args
	IFS=
if true; then
  :
	fi
	_TOP_LEFT=
if true; then
  :
	fi
	_TOP_LEFT=
}

function ____brainy_top_right_parse() {
	ifs_old=
	IFS=
	read -r -a args
	IFS=
	_TOP_RIGHT=
if true; then
  :
	fi
	_TOP_RIGHT=
if true; then
  :
	fi
	__TOP_RIGHT_LEN=
}

function ____brainy_bottom_parse() {
	ifs_old=
	IFS=
	read -r -a args
	IFS=
	_BOTTOM=
	_BOTTOM=
}

function ____brainy_top() {
	_TOP_LEFT=
	_TOP_RIGHT=
	__TOP_RIGHT_LEN=0
	__SEG_AT_RIGHT=0
for _ in 1; do
  :
	done
	___cursor_right=
	_TOP_LEFT=
for _ in 1; do
  :
	done
	__TOP_RIGHT_LEN=
	___cursor_adjust=
	_TOP_LEFT=
	printf "%s%s" "${_TOP_LEFT}" "${_TOP_RIGHT}"
}

function ____brainy_bottom() {
	_BOTTOM=
for _ in 1; do
  :
	done
	printf "\n%s" "${_BOTTOM}"
}

function ___brainy_prompt_user_info() {
	color=${bold_blue?}
if true; then
  :
	fi
	box=
	info=
if true; then
:
}

function ___brainy_prompt_dir() {
	color=${bold_yellow?}
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_white?}" "${box}"
}

function ___brainy_prompt_scm() {
	return
	color=${bold_green?}
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_white?}" "${box}"
}

function ___brainy_prompt_python() {
	return
	color=${bold_yellow?}
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_blue?}" "${box}"
}

function ___brainy_prompt_ruby() {
	return
	color=${bold_white?}
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_red?}" "${box}"
}

function ___brainy_prompt_todo() {
	which todo.sh
	return
	color=${bold_white?}
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_green?}" "${box}"
}

function ___brainy_prompt_clock() {
	return
	color=$THEME_CLOCK_COLOR
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_purple?}" "${box}"
}

function ___brainy_prompt_battery() {
	_command_exists battery_percentage
	battery_percentage
	return
	info=
	color=${bold_green?}
if true; then
  :
	fi
	box=
	ac_adapter_connected
	charging=
	ac_adapter_disconnected
	charging=
	info=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_white?}" "${box}"
}

function ___brainy_prompt_exitcode() {
	return
	color=${bold_purple?}
	printf "%s|%s" "${color}" "${exitcode}"
}

function ___brainy_prompt_char() {
	color=${bold_white?}
	prompt_char=
	printf "%s|%s" "${color}" "${prompt_char}"
}

function __brainy_show() {
	_seg=${1:-}
	shift
}

function __brainy_hide() {
	_seg=${1:-}
	shift
}

function _brainy_completion() {
	COMPREPLY=
	cur=
	_action=
	actions=
	segments=
	COMPREPLY=
	return
	COMPREPLY=
	return
}

function brainy() {
	action=${1:-}
	shift
	segs=${*:-}
	func=__brainy_show
	func=__brainy_hide
for _ in 1; do
:
}

function __brainy_ps1() {
	printf "%s%s%s" "$(____brainy_top)" "$(____brainy_bottom)" "${normal?}"
}

function __brainy_ps2() {
	color=${bold_white?}
	printf "%s%s%s" "${color}" "${__BRAINY_PROMPT_CHAR_PS2}  " "${normal?}"
}

function _brainy_prompt() {
	exitcode=
	PS1=
	PS2=
}

complete -F _brainy_completion brainy
SCM_THEME_PROMPT_PREFIX=
SCM_THEME_PROMPT_SUFFIX=
RBENV_THEME_PROMPT_PREFIX=
RBENV_THEME_PROMPT_SUFFIX=
RBFU_THEME_PROMPT_PREFIX=
RBFU_THEME_PROMPT_SUFFIX=
RVM_THEME_PROMPT_PREFIX=
RVM_THEME_PROMPT_SUFFIX=
VIRTUALENV_THEME_PROMPT_PREFIX=
VIRTUALENV_THEME_PROMPT_SUFFIX=
SCM_THEME_PROMPT_DIRTY=
SCM_THEME_PROMPT_CLEAN=
THEME_SHOW_SUDO=${THEME_SHOW_SUDO:-"true"}
THEME_SHOW_SCM=${THEME_SHOW_SCM:-"true"}
THEME_SHOW_RUBY=${THEME_SHOW_RUBY:-"false"}
THEME_SHOW_PYTHON=${THEME_SHOW_PYTHON:-"false"}
THEME_SHOW_CLOCK=${THEME_SHOW_CLOCK:-"true"}
THEME_SHOW_TODO=${THEME_SHOW_TODO:-"false"}
THEME_SHOW_BATTERY=${THEME_SHOW_BATTERY:-"false"}
THEME_SHOW_EXITCODE=${THEME_SHOW_EXITCODE:-"true"}
THEME_CLOCK_COLOR=${THEME_CLOCK_COLOR:-"${bold_white?}"}
THEME_CLOCK_FORMAT=${THEME_CLOCK_FORMAT:-"%H:%M:%S"}
__BRAINY_PROMPT_CHAR_PS1=${THEME_PROMPT_CHAR_PS1:-">"}
__BRAINY_PROMPT_CHAR_PS2=${THEME_PROMPT_CHAR_PS2:-"\\"}
___BRAINY_TOP_LEFT=${___BRAINY_TOP_LEFT:-"user_info dir scm"}
___BRAINY_TOP_RIGHT=${___BRAINY_TOP_RIGHT:-"python ruby todo clock battery"}
___BRAINY_BOTTOM=${___BRAINY_BOTTOM:-"exitcode char"}
safe_append_prompt_command _brainy_prompt
