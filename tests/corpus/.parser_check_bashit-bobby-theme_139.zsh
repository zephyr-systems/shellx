function __bobby_clock() {
	printf "$(clock_prompt) "
if true; then
:
}

function prompt_command() {
	PS1=
	PS1=
	PS1=
	PS1=
	PS1=
	PS1=
	PS1=
}

SCM_THEME_PROMPT_DIRTY=
SCM_THEME_PROMPT_CLEAN=
SCM_THEME_PROMPT_PREFIX=
SCM_THEME_PROMPT_SUFFIX=
GIT_THEME_PROMPT_DIRTY=
GIT_THEME_PROMPT_CLEAN=
GIT_THEME_PROMPT_PREFIX=
GIT_THEME_PROMPT_SUFFIX=
RVM_THEME_PROMPT_PREFIX=
RVM_THEME_PROMPT_SUFFIX=
: "${THEME_SHOW_CLOCK_CHAR:="true"}"
: "${THEME_CLOCK_CHAR_COLOR:=${red?}}"
: "${THEME_CLOCK_COLOR:=${bold_cyan?}}"
: "${THEME_CLOCK_FORMAT:="%Y-%m-%d %H:%M:%S"}"
safe_append_prompt_command prompt_command
