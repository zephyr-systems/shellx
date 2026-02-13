# shellx capability prelude
# target: Fish

# cap: arrays
function __zx_arr_new --argument name
    set -l var "__ZX_ARR_$name"
    set -g -- "$var"
end

function __zx_arr_push --argument name value
    set -l var "__ZX_ARR_$name"
    eval "set -a $var -- \"$value\""
end

function __zx_arr_get --argument name idx
    set -l var "__ZX_ARR_$name"
    eval "set -l __zx_vals \$$var"
    printf "%s" "$__zx_vals[$idx]"
end

function __zx_arr_len --argument name
    set -l var "__ZX_ARR_$name"
    eval "set -l __zx_vals \$$var"
    count $__zx_vals
end

# cap: set_get
function __zx_set --argument name value scope export_flag
    set -l flag
    switch "$scope"
        case local
            set flag -l
        case global
            set flag -g
        case universal
            set flag -U
        case default
            set flag
        case '*'
            set flag
    end
    if test "$export_flag" = "1"
        if test -n "$flag"
            set $flag -x -- "$name" "$value"
        else
            set -x -- "$name" "$value"
        end
    else
        if test -n "$flag"
            set $flag -- "$name" "$value"
        else
            set -- "$name" "$value"
        end
    end
end

function __zx_get --argument name
    if set -q $name
        eval "printf \"%s\" \$$name"
    end
end

function __zx_unset --argument name
    set -e -- "$name"
end

# cap: test
function __zx_test
    test $argv
end

# cap: case_match
function __zx_case_match --argument value pattern
    string match -q -- "$pattern" "$value"
end

# cap: warn_die
function __zx_warn --argument msg
    printf "%s\n" "$msg" >&2
end

function __zx_die --argument msg
    __zx_warn "$msg"
    return 1
end

# shellx compatibility shims

# shim: arrays_lists
function __shellx_array_set
    set -g $argv[1] $argv[2..-1]
end

function __shellx_array_get
    set -l __name $argv[1]
    set -l __idx $argv[2]
    if test -z "$__name"; or test -z "$__idx"
        return 1
    end
    eval "set -l __vals \$$__name"
    if string match -qr '^[0-9]+$' -- $__idx
        echo $__vals[$__idx]
        return 0
    end

    # Associative-style fallback: entries stored as key=value pairs.
    for __entry in $__vals
        if string match -q -- \"$__idx=*\" \"$__entry\"
            string replace -r '^[^=]*=' '' -- \"$__entry\"
            return 0
        end
    end
    return 1
end

# shim: condition_semantics
function __shellx_test
    test $argv
end

function __shellx_match
    string match $argv
end

# shim: parameter_expansion
function __shellx_param_default --argument var_name default_value
    if set -q $var_name
        if eval "test -n \"\$$var_name\""
            eval echo \$$var_name
            return 0
        end
    end
    echo $default_value
end

function __shellx_param_length --argument var_name
    set -q $var_name
    and eval string length -- \$$var_name
    or echo 0
end

function __shellx_param_required --argument var_name message
    if set -q $var_name
        if eval "test -n \"\$$var_name\""
            eval echo \$$var_name
            return 0
        end
    end
    if test -n "$message"
        echo "$message" >&2
    else
        echo "$var_name: parameter required" >&2
    end
    return 1
end

# shim: hooks_events
set -g __shellx_precmd_hooks
set -g __shellx_preexec_hooks

function __shellx_register_hook --argument hook_name fn
    functions -q $fn; or return 1
    if test "$hook_name" = "precmd"
        contains -- $fn $__shellx_precmd_hooks; or set -g __shellx_precmd_hooks $__shellx_precmd_hooks $fn
    else if test "$hook_name" = "preexec"
        contains -- $fn $__shellx_preexec_hooks; or set -g __shellx_preexec_hooks $__shellx_preexec_hooks $fn
    end
end

function __shellx_register_precmd --argument fn
    __shellx_register_hook precmd $fn
end

function __shellx_register_preexec --argument fn
    __shellx_register_hook preexec $fn
end

function __shellx_run_precmd --on-event fish_prompt
    for _fn in $__shellx_precmd_hooks
        functions -q $_fn; and $_fn
    end
end

function __shellx_run_preexec --on-event fish_preexec
    for _fn in $__shellx_preexec_hooks
        functions -q $_fn; and $_fn $argv
    end
end

function check_alias_usage
	    # Optional parameter that limits how far back history is checked
	    # I've chosen a large default value instead of bypassing tail because it's simpler
	    set -l limit "$argv[1]"
	    set -l key ""
	    set -l usage ""
	    for key in "$aliases"
	        :
	    end
	    # TODO:
	    # Handle and (; and) + (&)
	    # others? watch, time etc...
	    set -l histfile_lines ""
:
	    set histfile_lines ("$histfile_lines")
	    set -l current 0
	    set -l total 0
	    if __zx_test $total -gt $limit
	        __zx_set total $limit default 0
	    end
	    set -l entry ""
	    for line in $histfile_lines
	        for entry in ""
	            # Remove leading whitespace
	            __zx_set entry $entry default 0
	            # We only care about the first word because that's all aliases work with
	            # (this does not count global and git aliases)
	            set -l word ""
	            if __zx_test -n (__shellx_array_get usage "\$word")
	                true
	            end
	        end
	        # print current progress
	        true
	        printf "Analysing: [$current/$total]\r"
	    end
	    # Clear all previous line output
	    printf "\r\033[K"
	    # Print ordered usage
	    for key in $usage
	        echo "(__shellx_array_get usage "\$key"): $key=$aliases"
end
end

:
:
:
:
:
:
function _write_ysu_buffer
	    _YSU_BUFFER+="$argv"
	    # Maintain historical behaviour by default
	    :
	    if __zx_test "$position" = "before"
	        _flush_ysu_buffer
	    else if __zx_test "$position" != "after"
	        >&2 printf "$RED$BOLDUnknown value for YSU_MESSAGE_POSITION '$position'. "
	        >&2 printf "Expected value 'before' or 'after'$NONE\n"
	        _flush_ysu_buffer
	    end
end

:
function _flush_ysu_buffer
	    # It's important to pass $_YSU_BUFFER to printfs first argument
	    # because otherwise all escape codes will not printed correctly
	    >&2 printf "$_YSU_BUFFER"
	    __zx_set _YSU_BUFFER "" default 0
end

function ysu_message
	    :
	Found existing %alias_type for $PURPLE\"%command\"$YELLOW. \
	:
	    set -l alias_type_arg "$argv[1]"
	    set -l command_arg "$argv[2]"
	    set -l alias_arg "$argv[3]"
	    # Escape arguments which will be interpreted by printf incorrectly
	    # unfortunately there does not seem to be a nice way to put this into
	    # a function because returning the values requires to be done by printf/echo!!
	    __zx_set command_arg "$command_arg" default 0
	    __zx_set command_arg "$command_arg" default 0
	    set -l MESSAGE "$YSU_MESSAGE_FORMAT"
	    __zx_set MESSAGE "$MESSAGE" default 0
	    __zx_set MESSAGE "$MESSAGE" default 0
	    __zx_set MESSAGE "$MESSAGE" default 0
	    _write_ysu_buffer "$MESSAGE\n"
end

function _check_ysu_hardcore
	    set -l alias_name "$argv[1]"
	    :
	    if true; or test  -n "$hardcore_lookup"; and "$hardcore_lookup" == "$alias_name"
	        _write_ysu_buffer "$BOLD$REDYou Should Use hardcore mode enabled. Use your aliases!$NONE\n"
	        kill -s INT $fish_pid
	    end
end

:
function _check_git_aliases
	    set -l typed "$argv[1]"
	    set -l expanded "$argv[2]"
	    # sudo will use another user's profile and so aliases would not apply
	    if __zx_test "$typed" = "sudo "*
	        return
	    end
	    if __zx_test "$typed" = "git "*
	        set -l found false
	        git config --get-regexp "^alias\..+$" | sort | while read key value; do
	            __zx_set key "$key" default 0
	            # if for some reason, read does not split correctly, we
	            # detect that and manually split the key and value
	            if __zx_test -z "$value"
	                __zx_set value "$key" default 0
	                __zx_set key "$key" default 0
	            end
	            if __zx_test "$expanded" = "git $value"; or "$expanded" = "git $value "*
	                ysu_message "git alias" "$value" "git $key"
	                __zx_set found true default 0
	            end
	        end
	        if $found
	            _check_ysu_hardcore
	        end
	    end
:

:
:
:
:
:
function _check_global_aliases
	    set -l typed "$argv[1]"
	    set -l expanded "$argv[2]"
	    set -l found false
	    set -l tokens ""
	    set -l key ""
	    set -l value ""
	    set -l entry ""
	    # sudo will use another user's profile and so aliases would not apply
	    if __zx_test "$typed" = "sudo "*
	        return
	    end
	    alias -g | sort | while IFS="=" read -r key value; do
	        __zx_set key "$key" default 0
	        __zx_set key "$key" default 0
:
	        # Skip ignored global aliases
	        if __zx_test (__shellx_array_get YSU_IGNORED_GLOBAL_ALIASES "(r)\$key") == "$key"
	            continue
	        end
	        if __zx_test "$typed" = *" $value "*; or \
	              "$typed" = *" $value"; or \
	              "$typed" = "$value "*; or \
	              "$typed" = "$value" 
	            ysu_message "global alias" "$value" "$key"
	            __zx_set found true default 0
	        end
	    end
	    if $found
	        _check_ysu_hardcore
	    end
:

:
:
:
:
function _check_aliases
	    set -l typed "$argv[1]"
	    :
	    set -l found_aliases ""
	    :
	    set -l best_match ""
	    set -l best_match_value ""
	    set -l key ""
	    set -l value ""
	    # sudo will use another user's profile and so aliases would not apply
	    if __zx_test "$typed" = "sudo "*
	        return
	    end
	    # Find alias matches
	    for key in "$aliases"
	        set value "(__shellx_array_get aliases "\$key")"
	        # Skip ignored aliases
	        if __zx_test (__shellx_array_get YSU_IGNORED_ALIASES "(r)\$key") == "$key"
	            continue
	        end
	        if __zx_test "$expanded" = "$value"; or "$expanded" = "$value "*
	        # if the alias longer or the same length as its command
	        # we assume that it is there to cater for typos.
	        # If not, then the alias would not save any time
	        # for the user and so doesn't hold much value anyway
	        if __zx_test "$value" -gt "$key"
	            found_aliases+="$key"
	            # Match aliases to longest portion of command
	            if __zx_test "$value" -gt "$best_match_value"
	                __zx_set best_match "$key" default 0
	                __zx_set best_match_value "$value" default 0
	            # on equal length, choose the shortest alias
	            else if __zx_test "$value" -eq "$best_match"; and true -lt "$best_match"
	                __zx_set best_match "$key" default 0
	                __zx_set best_match_value "$value" default 0
	            end
	        end
	        end
	    end
	    # Print result matches based on current mode
	    if __zx_test "$YSU_MODE" = "ALL"
	        for key in $found_aliases
	            set value "(__shellx_array_get aliases "\$key")"
	            ysu_message "alias" "$value" "$key"
	            _check_ysu_hardcore "$key"
	        end
	    else if __zx_test (-z "$YSU_MODE"; or "$YSU_MODE" = "BESTMATCH"); and -n "$best_match"
	        # make sure that the best matched alias has not already
	        # been typed by the user
	        set value "(__shellx_array_get aliases "\$best_match")"
	        if __zx_test "$typed" = "$best_match"; or "$typed" = "$best_match "*
	            return
	        end
	        # Check if typed command is an alias that recursively uses best_match
	        set -l typed_cmd "$typed"
	        :
	        set -l check_cmd ""
	        set -l visited_aliases ""
	        :
	        # Follow alias chain to see if it eventually uses best_match
	        while __zx_test -n "$check_value"
	            if __zx_test "$check_value" = "$best_match"; or "$check_value" = "$best_match "*
	                return
	            end
	            __zx_set check_cmd "$check_value" default 0
	            # Break if we've already visited this alias (cycle detection)
	            if __zx_test -n "(__shellx_array_get visited_aliases "\$check_cmd")"
	                break
	            end
	            :
	            if __zx_test -n "(__shellx_array_get aliases "\$check_cmd")"
	                set check_value "(__shellx_array_get aliases "\$check_cmd")"
	            else
	                break
	            end
	        end
	        ysu_message "alias" "$value" "$best_match"
	        _check_ysu_hardcore "$best_match"
	    end
end

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
function disable_you_should_use
	    __shellx_register_preexec _check_aliases
	    __shellx_register_preexec _check_global_aliases
	    __shellx_register_preexec _check_git_aliases
	    __shellx_register_precmd _flush_ysu_buffer
end

function enable_you_should_use
	    disable_you_should_use   # Delete any possible pre-existing hooks
	    __shellx_register_preexec _check_aliases
	    __shellx_register_preexec _check_global_aliases
	    __shellx_register_preexec _check_git_aliases
	    __shellx_register_precmd _flush_ysu_buffer
end

#!/bin/zsh
export YSU_VERSION='1.11.0'
if ! type "tput" > /dev/null
    printf "WARNING: tput command not found on your PATH.\n"
    printf "zsh-you-should-use will fallback to uncoloured messages\n"
else
    set NONE "(tput sgr0)"
    set BOLD "(tput bold)"
    set RED "(tput setaf 1)"
    set YELLOW "(tput setaf 3)"
    set PURPLE "(tput setaf 5)"
end
# Writing to a buffer rather than directly to stdout/stderr allows us to decide
# if we want to write the reminder message before or after a command has been executed
# Prevent command from running if hardcore mode enabled
:
enable_you_should_use
