function ____atomic_top_left_parse() {
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

function ____atomic_top_right_parse() {
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

function ____atomic_bottom_parse() {
	ifs_old=
	IFS=
	read -r -a args
	IFS=
	_BOTTOM=
	_BOTTOM=
}

function ____atomic_top() {
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

function ____atomic_bottom() {
	_BOTTOM=
for _ in 1; do
  :
	done
	printf "\n%s" "${_BOTTOM}"
}

function ___atomic_prompt_user_info() {
	color=
	info=
	box=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${white?}" "${box}"
}

function ___atomic_prompt_dir() {
	color=
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_white?}" "${box}"
}

function ___atomic_prompt_scm() {
	return
	color=
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_white?}" "${box}"
}

function ___atomic_prompt_python() {
	return
	color=
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_blue?}" "${box}"
}

function ___atomic_prompt_ruby() {
	return
	color=
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_red?}" "${box}"
}

function ___atomic_prompt_todo() {
	which todo.sh
	return
	color=
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_green?}" "${box}"
}

function ___atomic_prompt_clock() {
	return
	color=
	box=
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_white?}" "${box}"
}

function ___atomic_prompt_battery() {
	_command_exists battery_percentage
	battery_percentage
	return
	batp=
if true; then
  :
	fi
	box=
	ac_adapter_connected
	info=
	ac_adapter_disconnected
	info=
	info=$batp
	info=
	printf "%s|%s|%s|%s" "${color}" "${info}" "${bold_white?}" "${box}"
}

function ___atomic_prompt_exitcode() {
	return
	color=
	printf "%s|%s" "${color}" "${exitcode}"
}

function ___atomic_prompt_char() {
	color=
	prompt_char=
if true; then
  :
	fi
	printf "%s|%s" "${color}" "${prompt_char}"
}

function __atomic_show() {
	_seg=
}

function __atomic_hide() {
	_seg=
}

function _atomic_completion() {
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

function atomic() {
	action=
	shift
	segs=
	func=__atomic_show
	func=__atomic_hide
	_log_error "${FUNCNAME[0]}: unknown action '${action}'"
	return
for _ in 1; do
:
}

function __atomic_ps1() {
	printf "%s%s%s" "$(____atomic_top)" "$(____atomic_bottom)" "${normal?}"
}

function __atomic_ps2() {
	color=
	printf "%s%s%s" "${color}" "${__ATOMIC_PROMPT_CHAR_PS2?}  " "${normal?}"
}

function _atomic_prompt() {
	exitcode=
	PS1=
	PS2=
}

IRed=
IGreen=
IYellow=
IWhite=
BIWhite=
BICyan=
Line=
LineA=
SX=
LineB=
Circle=
Face=
complete -F _atomic_completion atomic
SCM_THEME_PROMPT_PREFIX=
SCM_THEME_PROMPT_SUFFIX=
RBENV_THEME_PROMPT_PREFIX=
RBENV_THEME_PROMPT_SUFFIX=
RBFU_THEME_PROMPT_PREFIX=
RBFU_THEME_PROMPT_SUFFIX=
RVM_THEME_PROMPT_PREFIX=
RVM_THEME_PROMPT_SUFFIX=
SCM_THEME_PROMPT_DIRTY=
SCM_THEME_PROMPT_CLEAN=
: "${THEME_SHOW_SUDO:="true"}"
: "${THEME_SHOW_SCM:="true"}"
: "${THEME_SHOW_RUBY:="false"}"
: "${THEME_SHOW_PYTHON:="false"}"
: "${THEME_SHOW_CLOCK:="true"}"
: "${THEME_SHOW_TODO:="false"}"
: "${THEME_SHOW_BATTERY:="true"}"
: "${THEME_SHOW_EXITCODE:="false"}"
: "${THEME_CLOCK_COLOR:=${BICyan?}}"
: "${THEME_CLOCK_FORMAT:="%a %b %d - %H:%M"}"
__ATOMIC_PROMPT_CHAR_PS1=${THEME_PROMPT_CHAR_PS1:-"${normal?}${LineB?}${bold_white?}${Circle?}"}
__ATOMIC_PROMPT_CHAR_PS2=${THEME_PROMPT_CHAR_PS2:-"${normal?}${LineB?}${bold_white?}${Circle?}"}
__ATOMIC_PROMPT_CHAR_PS1_SUDO=${THEME_PROMPT_CHAR_PS1_SUDO:-"${normal?}${LineB?}${bold_red?}${Face?}"}
__ATOMIC_PROMPT_CHAR_PS2_SUDO=${THEME_PROMPT_CHAR_PS2_SUDO:-"${normal?}${LineB?}${bold_red?}${Face?}"}
: "${___ATOMIC_TOP_LEFT:="user_info dir scm"}"
: "${___ATOMIC_TOP_RIGHT:="exitcode python ruby todo clock battery"}"
: "${___ATOMIC_BOTTOM:="char"}"
safe_append_prompt_command _atomic_prompt
