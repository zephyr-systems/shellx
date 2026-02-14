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

function depend
	need localmount
	after bootmisc clock
if true
	end
	keyword -jail -prefix -vserver
end

function uniqify
	set result 
	set i 
	# Unsupported loop type in Fish
	echo "$result"
end

function reverse
	set result 
	set i 
	# Unsupported loop type in Fish
	echo "$result"
end

function sys_interfaces
	set w 
	set rest 
	set i 
	__zx_set cmd $argv[1] default 0
while true
	end
	ifconfig -l$argv[1]
end

function tentative
	set inet 
	set address 
	set rest 
	command -v ip
	return 1
	ip -f inet6 addr show tentative
	set inet 
	set address 
	set rest 
	ifconfig LC_ALL=C -a
while true
	end
end

function auto_interfaces
	set ifs 
	set c 
	set f 
	# Unsupported loop type in Fish
	# Unsupported loop type in Fish
	# Unsupported loop type in Fish
	echo
end

function interfaces
	uniqify (sys_interfaces "$argv") $interfaces (auto_interfaces)
end

function dumpargs
	__zx_set f "$argv[1]" default 0
	shift
	cat "$f"
	echo "$argv"
	set -o noglob
	:
	set -- $argv
	__zx_set IFS "$__nl" default 0
	echo "$argv"
end

function runip
	__zx_set int "$argv[1]" default 0
	set err 
	shift
	set -- "$argv" brd +
	set err 
if true
	end
if true
	end
	ip address add "$argv" dev "$int"
end

function routeflush
if true
	end
end

function runargs
	dumpargs "$argv"
while true
	end
end

function start
	__zx_set cr 0 default 0
	set r 
	set int 
	set intv 
	set cmd 
	set args 
	set upcmd 
if true
	end
if true
	end
	einfo "Starting network"
	routeflush
	eindent
	# Unsupported loop type in Fish
	eoutdent
	eend $cr
	__zx_set r 5 default 0
while true
	end
if true
	end
if true
	end
if true
	end
	return 0
end

function stop
	yesno (__shellx_param_default keep_network "YES")
	yesno $RC_GOINGDOWN
	return 0
	set int 
	set intv 
	set cmd 
	set downcmd 
	set r 
	einfo "Stopping network"
	routeflush
	eindent
	# Unsupported loop type in Fish
	eoutdent
	eend 0
end

set description "Configures network interfaces."
__zx_set __nl " default 0
:
__zx_set intup false default 0
