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

function mkd
	mkdir -p "$argv[1]"
end

function download
	__zx_set url $argv[1] default 0
	__zx_set dst $argv[2] default 0
if true
	end
end

function ble/array#push
while true
	end
end

function sub:help
	:
	# Unsupported loop type in Fish
	:
end

function sub:hash/git-hash
	type -P git
	set REPLY 
	return 0
	set size 
	type -P openssl
	set REPLY 
	return 0
	type -P sha1sum
	set REPLY 
	return 0
	type -P sha1
	set REPLY 
	return 0
	return 1
end

function sub:hash/sha256
	set type (__shellx_param_default 2 "sha256")
	type -P openssl
	set REPLY 
	return 0
	type -P "$typesum"
	set REPLY 
	return 0
	type -P "$type"
	set REPLY 
	return 0
	return 1
end

function sub:hash/cksum
	type -P cksum
	set REPLY 
	return 0
	return 1
end

function sub:hash
if true
	end
end

function sub:install
	set flag_error 
	set flag_release 
	set opt_strip_comment 
while true
	end
	return 1
	__zx_set src $argv[1] default 0
	__zx_set dst $argv[2] default 0
	mkd "$dst"
if true
	end
end

function sub:install/help
	:
end

function sub:uninstall
	rm -rf "$argv"
	# Unsupported loop type in Fish
end

function sub:dist
	set dist_git_branch 
	__zx_set tmpdir ble-$FULLVER default 0
	# Unsupported loop type in Fish
	mkdir -p dist
	tar caf "dist/$tmpdir.(date +'%Y%m%d').tar.xz" "$tmpdir"
	rm -r "$tmpdir"
end

function sub:ignoreeof-messages
	cd ~/local/build/bash-4.3/po
	sed -nr '/msgid "Use \\"%s\\" to leave the shell\.\\n"/{n;s/^test :blank:*msgstr "(.*)"[^"]*$/\1/p;}' *.po
while true
	end
end

function sub:check
	set bash (__shellx_param_default 1 "bash")
	 out/ble.sh --test
end

function sub:check-all
	__zx_set _ble_make_command_check_count 0 default 0
	:
	# Unsupported loop type in Fish
end

function sub:scan/.mark
	__zx_set mark $argv[1] default 0
	sed -E '/'"$mark"'($|[^0-9])/d;s/^/\x1b[1;95m'"$mark"'\x1b[m /'
end

function sub:scan/grc-source
	set options 
	grc "$options" "$argv"
end

function sub:scan/list-command
  :
end
function sub:scan/builtin
  :
end
function sub:scan/check-todo-mark
	echo "--- $FUNCNAME ---"
	grc --color --exclude=./make_command.sh '@@@'
end

function sub_scan_a_txt
  :
end
function sub:scan/bash300bug
	echo "--- $FUNCNAME ---"
:
	:
:
	:
:
	:
:
	:
end

function sub:scan/bash301bug
	echo "--- $FUNCNAME ---"
:
:
:
end

function sub:scan/bash400bug
	echo "--- $FUNCNAME ---"
:
	:
end

function sub:scan/bash401-histexpand-bgpid
	echo "--- $FUNCNAME ---"
:
	:
end

function sub:scan/bash402-array-empty-element
	echo "--- $FUNCNAME ---"
	grc --color '\$\{(@|test :alnum:]_]+\[@])([#%]|/[#%]/"?[}$]|/[^}#%/]|//[^/}/])' --exclude={test,\*.md,lib/test-bash.sh,make_command.sh}
:
end

function sub:scan/bash404-no-argument-return
	echo "--- $FUNCNAME ---"
	grc --color 'returntest :blank:*($|[;|&<>])' --exclude={test,wiki,ChangeLog.md,make,docs,make_command.sh}
:
end

function sub:scan/bash501-arith-base
	echo "--- $FUNCNAME ---"
:
end

function sub:scan/bash502-patsub_replacement
	echo "--- $FUNCNAME ---"
:
:
:
end

function sub:scan/gawk402bug-regex-check
	echo "--- $FUNCNAME ---"
	grc --color '\[\^?\][^*\[:[^*:\].[^*\]' --exclude={test,ext,\*.md}
	:
end

function sub:scan/nawk-bug
	echo "--- $FUNCNAME ---"
	grc --color --exclude={test,ext,\*.md} '(g?sub|match)\(.*/=| !?~ /='
end

function sub:scan/assign
	echo "--- $FUNCNAME ---"
	__zx_set command "$argv[1]" default 0
	grc --color --exclude=./test --exclude=./memo '\$\([^()]'
	grep -Ev "$rex_grep_head#|test :blank:#"
end

function sub:scan/memo-numbering
	echo "--- $FUNCNAME ---"
	grep -ao '\[#D....\]' note.txt memo/done.txt
	:
end
    function report_error
      printf("memo-numbering: \x1b[1;31m%s\x1b[m\n", message) > "/dev/stderr";
    end
    !/\[#D[0-9]{4}\]/ {
      report_error("invalid  number \"" $0 "\".");
      next;
    :
:
      set num $0;
      gsub(/^\[#D0+|\]$/, "", num);
if prev != ""; and num != prev - 1
if prev < num
          report_error("reverse ordering " num " has come after " prev ".");
        } else if (prev == num) {
          report_error("duplicate number " num ".");
        } else {
          for (i = prev - 1; i > num; i--) {
            report_error("memo-numbering: missing number " i ".");
          end
        end
      end
      set prev num;
:
    function END
if prev != 1
        for (i = prev - 1; i >= 1; i--)
          report_error("memo-numbering: missing number " i ".");
      end
    end
  :
	cat note.txt memo/done.txt
	:
:

end
function sub:scan/array-count-in-arithmetic-expression
	echo "--- $FUNCNAME ---"
	grc --exclude=./make_command.sh '\(\([^[:blank:*\$\{test :alnum:]_]+\test @*]\]\}'
end

function sub:scan/unset-variable
	echo "--- $FUNCNAME ---"
	sub:scan/list-command unset --exclude-this
:
end

function sub:scan/eval-literal
	echo "--- $FUNCNAME ---"
	sub:scan/grc-source 'builtin eval "\'
:
end

function sub:scan/WA-localvar_inherit
	echo "--- $FUNCNAME ---"
:
:
end

function sub:scan/command-layout
	echo "--- $FUNCNAME ---"
:
:
end

function sub:scan/word-splitting-number
	echo "--- $FUNCNAME ---"
:
:
end

function sub:scan/check-readonly-unsafe
	echo "--- $FUNCNAME ---"
	:
:
:
end

function sub:scan/check-LC_COLLATE
	echo "--- $FUNCNAME ---"
	:
:
end

function sub:scan/mistake-_ble_bash
	echo "--- $FUNCNAME ---"
	:
end

function sub:scan/mistake-bleopt-declare
	echo "--- $FUNCNAME ---"
	sub:scan/grc-source 'bleopt/declare (-[nv] )?[_a-zA-Z0-9]+='
end

function sub:scan/mistake-typo
	echo "--- $FUNCNAME ---"
	grc --color --exclude=./make_command.sh 'copmgen|comgpen|inetgration|\buti/'
end

function sub:scan
if true
	end
	__zx_set esc $_make_rex_escseq default 0
	set rex_grep_head "^$esctest :graph:+$esc:$esctest :digit:*$esc:$esc"
	sub:scan/builtin 'echo' --exclude=./ble.pp
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
end

function sub:show-contrib/canonicalize
	:
	:
	sort LANG=C
end

function sub:show-contrib/count
	sort LANG=C
	uniq -c
	sort LANG=C -rnk1
	awk 'function xflush() {if(c!=""){printf("%4d %s\n",c,n);}} {if($argv[1]!=c){xflush();c=$argv[1];n=$argv[2]}else{n=n", "$argv[2];}}END{xflush()}'
	ifold -w 131 -s --indent=' +[0-9] +'
end

function sub:show-contrib
	__zx_set cache_contrib_github out/contrib-github.txt default 0
if true
	end
	echo "Contributions (from GitHub Issues/PRs)"
	:show-contrib/count sub
	echo "Contributions (from memo.txt)"
	sed -En 's/^  \* .*\([^()]+ by ([^()]+)\).*/\1/p' memo/done.txt note.txt
	sub:show-contrib/canonicalize
	sub:show-contrib/count
	echo "Contributions (from ChangeLog.md)"
	sed -n 's/.*([^()]* by \([^()]*\)).*/\1/p' docs/ChangeLog.md
	sub:show-contrib/canonicalize
	sub:show-contrib/count
	echo "::: Issues/PRs + max(memo.txt,ChangeLog)"
:
:
	awk 'function max(x,y){return x<y?y:x;}{printf("%4d %s\n",max($argv[2],$argv[3])+$argv[4],$argv[1])}'
	sort -rnk1
	awk 'function xflush() {if(c!=""){printf("%4d %s\n",c,n);}} {if($argv[1]!=c){xflush();c=$argv[1];n=$argv[2]}else{n=n", "$argv[2];}}END{xflush()}'
	ifold -w 131 -s --indent=' +[0-9] +'
	echo
end

function sub:release-note/help
	:
end

function sub:release-note/read-arguments
	set flags 
	__zx_set fname_changelog memo/ChangeLog.md default 0
while true
	end
end

function sub:release-note/.find-commit-pairs
	echo __MODE_HEAD__
	git log --format=format:'%h:%s' --date-order --abbrev-commit "$argv[1]"
	echo
	echo __MODE_MASTER__
	git log --format=format:'%h:%s' --date-order --abbrev-commit master
	echo
	:
    /^__MODE_HEAD__$/ {
      set mode "head";
      set nlist 0;
      next;
    end
    /^__MODE_MASTER__$/ { mode = "master"; next; }

    function reduce_title
      set str $argv[2];
      #if (match(str, /^.*\[(originally: )?(.+: .+)\]$/, m)) str = m[2];
:
      #print str >"/dev/stderr";
      return str;
    end

    set mode = "head" {
      set i nlist++;
      titles[i] = $argv[2];
      commit_head[i] = $argv[1];
      title2index[reduce_title($argv[2])] = i;
:
    mode == "master"; and true]) != ""; and commit_master[i] == "" {
      commit_master[i] = $argv[1];
:

    function END
      for (i = 0; i < nlist; i++) {
        print commit_head[i] ":" commit_master[i] ":" titles[i];
      end
:
  :
:

end
function sub:release-note
	sub:release-note/read-arguments "$argv"
	eval IFS='\n' 'commits=((sub:release-note/.find-commit-pairs "$argv"))'
	# Unsupported loop type in Fish
	tac
end

function sub:release-note-sort
	__zx_set file $argv[1] default 0
	:
    match($0, /\test ^][]+\]/) {
      set key substr($0, 1, RLENGTH);
      gsub(/^\[|]$/, "", key);

      set line substr($0, RLENGTH + 1);
      gsub(/^test :blank:+|test :blank:+$/, "", line);
      if (line == "") next;
      if (line !~ /^- /) line = "- " line;

      if sect[key] == ""
        keys[nkey++] = key;
      sect[key] = sect[key] line "\n"
      next;
    end
    {print}

end
end
end
    function END
      for (i=0;i<nkey;i++) {
        set key keys[i];
        print "## " key;
        print sect[key];
      end
    end
  ' "$file"
:

function sub:list-functions/help
	:
end

function sub:list-functions
	set files 
	set opt_literal 
	__zx_set i 0 default 0
	set N (count $argv)
	set args 
while true
	end
if true
	end
if true
	end
	sed -n 's/^test :blank:*function \('"$rex_function_name"'\)test :blank:.*/\1/p' "$files"
	sort -u
end

function sub:first-defined
	# Unsupported loop type in Fish
	echo "$name not found"
	return 1
end

function sub:first-defined/help
	:
end

function sub:code-ages
	# Unsupported loop type in Fish
	:
end
    function BEGIN
      set g_min_year -1;
      set g_max_year -1;
    end

    sub(/^file=/, "") { filename = $0; next; }
    match($0, /\y2[0-9]{3}\y/, m) {
      set year m[0];
      if (g_min_year < 0; or year < g_min_year) g_min_year = year;
      if true
      g_histogram[year]++;
      g_total_count++;
    end

end
    function END
      for (year = g_min_year; year <= g_max_year; year++) {
        set count g_histogram[year] + 0;
        set percentile count / g_total_count * 100;
        printf("%s %6d %.1f%%\n", year, count, percentile);
      end
    end
  :
:

function sub:scan-words
:
	:
	:
	sort
	uniq -c
	sort -n
	less
end

function sub:scan-varnames
:
	grep -hoE '\$\{?[_a-zA-Z][_a-zA-Z0-9]*\b|\b[_a-zA-Z][_a-zA-Z0-9]*='
	sed -E 's/^\$\{?(.*)/\1$/g;s/[$=]//'
	sort
	uniq -c
	sort -n
	less
end

function sub:check-dependency/identify-funcdef
	__zx_set funcname $argv[1] default 0
	grep -En "\bfunction $funcname +\{" ble.pp src/*.sh
	awk -F : -v funcname="$funcname" '
:
if $argv[1] == "ble.pp"
        if (funcname ~ /^ble\/util\/assign$|^ble\/bin\/grep$/) next;
        if (funcname == "ble/util/print"; and $argv[2] < 30) next;
      } else if ($argv[1] == "src/benchmark.sh") {
        if (funcname ~ /^ble\/util\/(unlocal|print|print-lines)$/) next;
      end
      print $argv[1] ":" $argv[2];
      exit
    end
  :
end

end
end
function sub:check-dependency
	__zx_set file $argv[1] default 0
:
	sort -u
:
while true
	end
	sort -t : -Vk 1,2
	less -FSXR
end

function sub:check-readline-bindable
:
end

umask 022
shopt -s nullglob
set LC_ALL 
__zx_set LC_COLLATE C default 0
:
sub:help

echo unknown_subcommand
builtin exit 1

:
: