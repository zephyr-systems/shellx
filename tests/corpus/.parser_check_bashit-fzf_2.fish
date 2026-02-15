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

# cap: cmd_has
function __zx_cmd_has --argument cmd
    type -q -- "$cmd"
end

# cap: source
function __zx_source --argument path
    if test -f "$path"
        source "$path"
    else
        __zx_warn "source target missing: $path"
        return 1
    end
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

# shim: process_substitution
function __shellx_psub_tmp
    mktemp
end

function __shellx_psub_in --argument cmd
    set -l tmp (__shellx_psub_tmp)
    sh -c "$cmd" > "$tmp"
    echo $tmp
end

function __shellx_psub_out --argument cmd
    set -l tmp (__shellx_psub_tmp)
    rm -f "$tmp"
    mkfifo $tmp
    sh -c "$cmd < \"$tmp\"; rm -f \"$tmp\"" &
    echo $tmp
end

function fe
	about "Open the selected file in the default editor"
	group "fzf"
	param "1: Search term"
	example "fe foo"
	__zx_set IFS '\n' default 0
	set files 
while true
	end
	fzf-tmux --query="$argv[1]" --multi --select-1 --exit-0
	(__shellx_param_default EDITOR "vim") "$files"
end

function fcd
	about "cd to the selected directory"
	group "fzf"
	param "1: Directory to browse, or . if omitted"
	example "fcd aliases"
	set dir 
	cd "$dir"
	return 1
end

cite about-plugin
:
url "https://github.com/junegunn/fzf"
_bash-it-component-item-is-enabled plugin blesh
__zx_source ~/.fzf.bash
__zx_source "(__shellx_param_default XDG_CONFIG_HOME "\$HOME/.config")"/fzf/fzf.bash
_command_exists fzf
return
_command_exists fd
:
