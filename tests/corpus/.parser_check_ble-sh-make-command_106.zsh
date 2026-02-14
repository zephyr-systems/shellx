function mkd() {
	mkdir -p "$1"
}

function download() {
	url=$1
	dst=$2
if true; then
:
fi
}

__shellx_fn_invalid() {
:
:
:
}

__shellx_fn_invalid() {
	printf '%s\n' 'usage: make_command.sh SUBCOMMAND args...' '' 'SUBCOMMAND' ''
:
  :
	:
	printf '\n'
}

__shellx_fn_invalid() {
	type -P git
	REPLY=
	return 0
	size=
	type -P openssl
	REPLY=
	return 0
	type -P sha1sum
	REPLY=
	return 0
	type -P sha1
	REPLY=
	return 0
	return 1
}

__shellx_fn_invalid() {
	type=${2:-sha256}
	type -P openssl
	REPLY=
	return 0
	type -P "${type}sum"
	REPLY=
	return 0
	type -P "$type"
	REPLY=
	return 0
	return 1
}

__shellx_fn_invalid() {
	type -P cksum
	REPLY=
	return 0
	return 1
}

__shellx_fn_invalid() {
if true; then
:
fi
}

__shellx_fn_invalid() {
	flag_error=
	flag_release=
	opt_strip_comment=
:
  :
:
	return 1
	src=$1
	dst=$2
	mkd "${dst%/*}"
if true; then
:
fi
}

__shellx_fn_invalid() {
	printf '  install src dst\n'
}

__shellx_fn_invalid() {
	rm -rf "$@"
:
:
}

__shellx_fn_invalid() {
	dist_git_branch=
	tmpdir=ble-$FULLVER
:
  :
	:
	mkdir -p dist
	tar caf "dist/$tmpdir.$(date +'%Y%m%d').tar.xz" "$tmpdir"
	rm -r "$tmpdir"
}

__shellx_fn_invalid() {
	cd ~/local/build/bash-4.3/po
:
:
:
:
}

__shellx_fn_invalid() {
	bash=${1-bash}
	 out/ble.sh --test
}

__shellx_fn_invalid() {
	_ble_make_command_check_count=0
	rex_version='^bash-([0-9]+)\.([0-9]+)$'
:
:
}

__shellx_fn_invalid() {
	mark=$1
	sed -E '/'"$mark"'($|[^0-9])/d;s/^/\x1b[1;95m'"$mark"'\x1b[m /'
}

__shellx_fn_invalid() {
	options=
	grc "${options[@]}" "$@"
}

__shellx_fn_invalid() {
	options=
	flag_exclude_this=
	flag_error=
	command=
:
  :
:
if true; then
  :
	fi
	return 1
	ble/array#push options --exclude=./make_command.sh
:
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME $1 ---"
	command=$1
	esc=$_make_rex_escseq
	b="(\b|$esc)"
	b="($esc)"
	sub:scan/list-command --exclude-this --exclude={generate-release-note.sh,lib/test-*.sh,make,ext} "$command" "${@:2}"
	grep -Ev "$rex_grep_head([[:blank:]]*|[[:alnum:][:blank:]]*[[:blank:]])#|$b(builtin|function)$esc([[:blank:]]$esc)+$command$b"
	grep -Ev "$command$b="
	grep -Ev "ble\.sh $esc\($esc$command$esc\)$esc"
	sed -E 'h;s/'"$_make_rex_escseq"'//g
        \Z^\./lib/test-[^:]+\.sh:[0-9]+:.*ble/test Zd
      s/^[^:]*:[0-9]+:[[:blank:]]*//
        \Z(\.awk|push|load|==|#(push|pop)) \b'"$command"'\bZd
      g'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc --color --exclude=./make_command.sh '@@@'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
:
	sed -E 'h;s/'"$_make_rex_escseq"'//g
      \Z^\./memo/Zd
      \Zgithub302-perlre-server\.bashZd
      \Z^\./contrib/integration/fzf-git.bash:[0-9]+:Zd
    s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Z^[[:blank:]]*#Zd
      \ZDEBUG_LEAKVARZd
      \Z! \{ \[\[ \$\{bleopt_connect_tty-\} \]\] && >/dev/tty; \}Zd
      \Z^if ble/fd#alloc .*Zd
      \Zbuiltin read -et 0.000001 dummy </dev/ttyZd
      g'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc '(local|declare|typeset) [_a-zA-Z]+=\(' --exclude=./{test,ext} --exclude=./make_command.sh --exclude=ChangeLog.md --color
	sub:scan/.mark '#D0184'
	grc '(local|declare|typeset) -a [[:alnum:]_]+=\([^)]*[\"'\''`]' --exclude=./{test,ext} --exclude=./make_command.sh --color
	sub:scan/.mark '#D0525'
	grc '\$\{[_a-zA-Z0-9]+\[[*@]\]/' --exclude=./{text,ext} --exclude=./make_command.sh --exclude=\*.md --color
	sub:scan/.mark '#D1570'
	grc '".*\$\{[^{}]*\$'\''([^\\'\'']|\\.)*'\''\}.*"' --exclude={./make_command.sh,memo,\*.md} --color
	sub:scan/.mark '#D1774'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc ' [0-9]{2}&?[<>]' --exclude=./{test,ext} --exclude=./make_command.sh --exclude=ChangeLog.md --color
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      /^#/d
      /#D0857/d
      / [0-9]{2}[<>]&-/d
      g'
	grc ' ([0-9]{2}|\$[a-zA-Z_0-9]+)&?[<>]&-' --exclude=./{test,ext} --exclude=./make_command.sh --exclude=ChangeLog.md --color
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      /^#/d
      /#D2164/d
      g'
	grc '\$\{#[[:alnum:]]+\[[^@*]' --exclude={test,ChangeLog.md} --color
	grep -Ev '^([^#]*[[:blank:]])?#'
	sub:scan/.mark '#D0182'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc '\$'\''([^\'\'']|\\[^'\''])*\\'\''([^\'\'']|\\.|'\''([^\'\'']|\\*)'\'')*![^=[:blank:]]' --exclude={test,ChangeLog.md} --color
	grep -v '9f0644470'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc '"\$!"' --exclude={test,ChangeLog.md} --color
	sub:scan/.mark '#D2028'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
:
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//

      \Z"\$\{_ble_util_set_declare\[@\]//NAME/.+\}"Zd

      \Z#D2352Zd
      g'
	sub:scan/.mark '#D2352'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc --color 'return[[:blank:]]*($|[;|&<>])' --exclude={test,wiki,ChangeLog.md,make,docs,make_command.sh}
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//

      \Z@returnZd
      \Z\) return;Zd
      \Zreturn;[[:blank:]]*$Zd
      \Zif \(REQ == "[A-Z]+"\)Zd
      \Z\(return\|ret\)Zd
      \Z_ble_trap_done=return$Zd
      \Z\bwe return\bZd

      g'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc '\b10#\$' --exclude={test,ChangeLog.md}
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
:
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Z//?\$q/\$Q\}Zd
      \Z//?\$q/\$qq\}Zd
      \Z//?\$qq/\$q\}Zd
      \Z//?\$__ble_q/\$__ble_Q\}Zd
      \Z//?\$_ble_local_q/\$_ble_local_Q\}Zd
      \Z/\$\(\([^()]+\)\)\}Zd
      \Z/\$'\''([^\\]|\\.)+'\''\}Zd

      \Z\$\{[_a-zA-Z0-9]+//(ARR|DICT|PREFIX|NAME|LAYER)/\$([_a-zA-Z0-9]+|\{[_a-zA-Z0-9#:-]+\})\}Zd
      \Z\$\{[_a-zA-Z0-9]+//'\''%[dlcxy]'\''/\$[_a-zA-Z0-9]+\}Zd # src/canvas.sh

      \Z#D1738Zd
      \Z\$\{_ble_edit_str//\$'\''\\n'\''/\$'\''\\n'\''"\$comment_begin"\}Zd # edit.sh
      g'
	sub:scan/.mark '#D1738'
:
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Z#D1751Zd
      g'
	sub:scan/.mark '#D1751'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc --color '\[\^?\][^]]*\[:[^]]*:\].[^]]*\]' --exclude={test,ext,\*.md}
	grep -Ev '#D1709 safe'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc --color --exclude={test,ext,\*.md} '(g?sub|match)\(.*/=| !?~ /='
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	command="$1"
	grc --color --exclude=./test --exclude=./memo '\$\([^()]'
	grep -Ev "$rex_grep_head#|[[:blank:]]#"
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grep -ao '\[#D....\]' note.txt memo/done.txt
	awk '
    function report_error(message) {
      printf("memo-numbering: \x1b[1;31m%s\x1b[m\n", message) > "/dev/stderr";
    }
    !/\[#D[0-9]{4}\]/ {
      report_error("invalid  number \"" $0 "\".");
      next;
    }
    {
      num = $0;
      gsub(/^\[#D0+|\]$/, "", num);
      if (prev != "" && num != prev - 1) {
        if (prev < num) {
          report_error("reverse ordering " num " has come after " prev ".");
        } else if (prev == num) {
          report_error("duplicate number " num ".");
        } else {
          for (i = prev - 1; i > num; i--) {
            report_error("memo-numbering: missing number " i ".");
:
fi
fi
      prev = num;
    END {
      if (prev != 1) {
        for (i = prev - 1; i >= 1; i--)
          report_error("memo-numbering: missing number " i ".");
:
fi
  '
	cat note.txt memo/done.txt
	sed -n '0,/^[[:blank:]]\{1,\}Done/d;/  \* .*\[#D....\]$/d;/^  \* /p'

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc --exclude=./make_command.sh '\(\([^[:blank:]]*\$\{[[:alnum:]_]+\[[@*]\]\}'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	sub:scan/list-command unset --exclude-this
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Zunset[[:blank:]]-[vf]Zd
      \Z^[[:blank:]]*#Zd
      \Zunset _ble_init_(version|arg|exit|command)\bZd
      \Zbuiltins1=\(.* unset .*\)Zd
      \Zfunction unsetZd
      \Zreadonly -f unsetZd
      \Z'\''\(unset\)'\''Zd
      \Z"\$__ble_proc" "\$__ble_name" unsetZd
      \Zulimit umask unalias unset waitZd
      \ZThe variable will be unset initiallyZd
      g'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
:
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Zeval "(\$[[:alnum:]_]+)+(\[[^]["'\''\$`]+\])?\+?=Zd
      g'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc 'local [^;&|()]*"\$\{[_a-zA-Z0-9]+\[@*\]\}"'
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Ztest_command='\''ble/bin/stty -echo -nl -icrnl -icanon "\$\{_ble_term_stty_flags_enter\[@]}" size'\''Zd
      /#D1566/d
      g'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc '(/enter-command-layout|ble/edit/\.relocate-textarea|/\.newline)([[:blank:]]|$)' --exclude=./{text,ext} --exclude=./make_command.sh --exclude=\*.md --color
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Z^[[:blank:]]*#Zd
      \Z^[[:blank:]]*function [^[:blank:]]* \{$Zd
      \Z[: ]keep-infoZd
      \Z#D1800Zd
      g'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc '[<>]&\$|([[:blank:]]|=\()\$(\(\(|\{#|\?)' --exclude={docs,mwg_pp.awk,memo}
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Z^[^#]*(^|[[:blank:]])#Zd
:
      \Z^[^][]*\[\[[^][]*([& (]\$)Zd
      \Z\(\([_a-zA-Z0-9]+=\(\$Zd
      \Z\$\{#[_a-zA-Z0-9]+\}[<>?&]Zd
      \Z \$\{\#[_a-zA-Z0-9]+\[@\]\} -gt 0 \]\]Zd
      \Zcase \$\? inZd
      \Zcase \$\(\(.*\)\) inZd
      \Z#D1835Zd
      g'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	rex_varname='\b(_[_a-zA-Z0-9]+|[_A-Z][_A-Z0-9]+)\b'
	grc -Wg,-n -Wg,--color=always -o "$rex_varname"'\+?=\b|(/assign|/assign-array|#split) '"$rex_varname"'| -v '"$rex_varname"' ' --exclude={memo,wiki,test,make,'*.md',make_command.sh,GNUmakefile,'gh????.*.'{sh,bash}}
	sed -E 'h;s/'"$_make_rex_escseq"'//g

      # Exceptions in each file
      /^\.\/ble.pp:[0-9]*:BLEOPT=$/d
      /^\.\/ble.pp:[0-9]*:\/assign (USER|HOSTNAME)/d
      /^\.\/lib\/core-complete.sh:[0-9]+:KEY=$/d
      /^\.\/lib\/core-syntax.sh:[0-9]+:VAR=$/d
      /^\.\/lib\/init-(cmap|term).sh:[0-9]+:TERM=$/d
      /^\.\/src\/edit.sh:[0-9]+:_dirty=$/d
      /^\.\/src\/history.sh:[0-9]+:_history_index=$/d
      /^\.\/src\/util.sh:[0-9]+:(NAMEI|OPEN|TERM)=$/d
      /^\.\/lib\/core-cmdspec.sh:[0-9]+:OLD=$/d

      # (extract only variable names)
      s/^[^:]*:[0-9]+:[[:blank:]]*//;
      s/^-v (.*) $/\1/;s/\+?=$//;s/^.+ //;

      # other frameworks & integrations
      /^__bp_blesh_invoking_through_blesh$/d
      /^__bp_imported$/d
      /^__bp_inside_pre(cmd|exec)$/d
      /^BP_PROMPT_COMMAND_.*$/d

      # common variables
      /^__?ble[_a-zA-Z0-9]*$/d
      /^[A-Z]$/d
      /^BLE_[_A-Z0-9]*$/d
      /^ADVICE_[_A-Z0-9]*$/d
      /^COMP_[_A-Z0-9]*$/d
      /^COMPREPLY$/d
      /^READLINE_[_A-Z0-9]*$/d
      /^LC_[_A-Z0-9]*$/d
      /^LANG$/d

      # other uppercase variables that ble.sh is allowed to use.
      /^(FUNCNEST|IFS|IGNOREEOF|POSIXLY_CORRECT|TMOUT)$/d
      /^(PWD|OLDPWD|CDPATH)$/d
      /^(BASHPID|GLOBIGNORE|MAPFILE|REPLY)$/d
      /^INPUTRC$/d
      /^(LINES|COLUMNS)$/d
      /^HIST(CONTROL|IGNORE|SIZE|TIMEFORMAT)$/d
      /^(PROMPT_COMMAND|PS1)$/d
      /^(BASH_COMMAND|BASH_REMATCH|HISTCMD|LINENO|PIPESTATUS|TIMEFORMAT)$/d
      /^(BASH_XTRACEFD|PS4)$/d
      /^(CC|LESS|MANOPT|MANPAGER|PAGER|PATH|MANPATH)$/d
      /^(BUFF|KEYS|KEYMAP|WIDGET|LASTWIDGET|DRAW_BUFF)$/d
      /^(D(MIN|MAX|MAX0)|(HIGHLIGHT|PREV)_(BUFF|UMAX|UMIN)|LEVEL|LAYER_(UMAX|UMIN))$/d
      /^(HISTINDEX_NEXT|FILE|LINE|INDEX|INDEX_FILE)$/d
      /^(ARG|FLAG|REG)$/d
      /^(COMP[12SV]|ACTION|CAND|DATA|INSERT|PREFIX_LEN)$/d
      /^(PRETTY_NAME|NAME|VERSION)$/d
      /^(OPTIND|OPTERR)$/d

      # variables in awk/comments/etc
      /^AWKTYPE$/d
      /^FOO$/d
      g'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	sub:scan/grc-source '\[[ @]-\\?[?/~]\]|es_unescape\('
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      /^[[:space:]]*#/d
      /#D1440\b/d
      /function es_unescape\(/d
      /LC_COLLATE=C\b/d
      g'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	sub:scan/grc-source '\(\(.*\b_ble_base\b.*\)\)'
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	sub:scan/grc-source 'bleopt/declare (-[nv] )?[_a-zA-Z0-9]+='
}

__shellx_fn_invalid() {
	echo "--- $FUNCNAME ---"
	grc --color --exclude=./make_command.sh 'copmgen|comgpen|inetgration|\buti/'
}

__shellx_fn_invalid() {
if true; then
  :
	fi
	esc=$_make_rex_escseq
	rex_grep_head="^$esc[[:graph:]]+$esc:$esc[[:digit:]]*$esc:$esc"
	sub:scan/builtin 'echo' --exclude=./ble.pp
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Z\bstty[[:blank:]]+echoZd
      \Zecho \$PPIDZd
      \Zble/keymap:vi_test/check Zd
      \Zmandb-help=%'\''help echo'\''Zd
      \Zalias aaa4='\''echo'\''Zd
      g'
	sub:scan/builtin 'bind'
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Zinvalid bind typeZd
      \Zline = "bind"Zd
      \Z'\''  bindZd
      \Z\(bind\)    ble-bindZd
      \Z^alias bind cd command compgenZd
      \Zoutputs of the "bind" builtinZd
      \Zif ble/string#match "\$_ble_edit_str" '\''bindZd
      \Z\(ble/builtin/bind\|ble/builtin/bind/\*\|bind\|ble/decode/read-inputrc/test\)Zd
:
      \Zwarning: readline \\"bind -x\\" does not supportZd
      \Zble/init/measure/section '\''bind'\''Zd
      g'
	sub:scan/builtin 'read'
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \ZDo not read Zd
      \Zfailed to read Zd
      \Zpushd read readonly set shoptZd
      g'
	sub:scan/builtin 'exit'
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Zble.pp.*return 1 2>/dev/null || exit 1Zd
      \Z^[-[:blank:][:alnum:]_./:=$#*]+('\''[^'\'']*|"[^"()`]*|([[:blank:]]|^)#.*)\bexit\bZd
      \Z\(exit\) ;;Zd
      \Zprint NR; exit;Zd;g'
	sub:scan/builtin 'eval'
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Z\('\''eval'\''\)Zd
      \Z\(eval\)Zd
      \Zbuiltins1=\(.* eval .*\)Zd
      \Z\^eval --Zd
      \Zt = "eval -- \$"Zd
:
      \Zcmd '\''eval -- %q'\''Zd
      \Z\$\(eval \$\(call .*\)\)Zd
      \Z^[[:blank:]]*local rex_[_a-zA-Z0-9]+='\''[^'\'']*'\''[[:blank:]]*$Zd
      \ZLINENO='\''\$lineno'\'' evalZd
      \Z'\''argument eval'\''Zd
      \Z^ble/cmdspec/opts Zd
      g'
	sub:scan/builtin 'unset'
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Zunset (-v )?_ble_init_(version|arg|exit|command)\bZd
      \Zreadonly -f unsetZd
      \Zunset -f builtinZd
      \Z'\''\(unset\)'\''Zd
      \Z"\$__ble_proc" "\$__ble_name" unsetZd
      \Zumask unalias unset wait$Zd
      \ZThe variable will be unset initiallyZd
      g'
	sub:scan/builtin 'unalias'
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Zbuiltins1=\(.* unalias .*\)Zd
      \Zumask unalias unset wait$Zd
      g'
	sub:scan/builtin 'trap'
	sed -E 'h;s/'"$_make_rex_escseq"'//g

      # Exceptions in each file
      \Z^\./contrib/integration/bash-preexec\.bash:[0-9]+:.*\btrap -p? DEBUG\bZd
:
      \Z^\./contrib/snake\.sh:[0-9]+:Zd

    s/^[^:]*:[0-9]+:[[:blank:]]*//
:
      \Zline = "bind"Zd
:
:
      \Zlocal trap$Zd
      \Z"trap -- '\''"Zd
      \Z\('\'' trap '\''\*Zd
      \Z\(trap \| ble/builtin/trap\) .*;;Zd
      \Zble/function#trace trap Zd
      \Z# EXIT trapZd
      \Zread readonly set shopt trapZd
      \Zble/util/print "custom trap"Zd
      g'
	sub:scan/builtin 'readonly'
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Z^[[:blank:]]*#Zd
      \ZWA readonlyZd
      \Z\('\''declare'\''(\|'\''[a-z]+'\'')+\)Zd
      \Z readonly was blocked\.Zd
      \Z\[\[ \$\{FUNCNAME\[i]} == \*readonly ]]Zd
      \Zread readonly set shopt trapZd
      g'
	sub:scan/builtin ':' --exclude=./ble.pp
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      g'
	sub:scan/builtin 'type' --exclude=./ble.pp
	sed -E 'h;s/'"$_make_rex_escseq"'//g

      \Zgh0358\.copilot\.bashZd

    s/^[^:]*:[0-9]+:[[:blank:]]*//

      \Zble/util/type type Zd
      \Zble/util/print "[^"].* type\bZd
      \Z\blocal( [_a-zA-Z0-9]+)* typeZd
      \Z # .*\btype\bZd
      \Z # .*\btype\bZd
      \Z\bfor type in Zd

      \Z keys type\bZd
      \Ztrap type ulimitZd
      \Zevent typeZd
:

      # awk scripts
      \Zif \(typeZd
      \Z\btype ==? Zd
      \Z = type\bZd
      \Z\b, type\)Zd

      \Zble/fun:type\bZd
      g'
	sub:scan/builtin 'true' --exclude=./ble.pp
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Zble/cmdspec/opts .* : false trueZd
      \Z# true colorZd
      g'
	sub:scan/builtin 'false' --exclude=./ble.pp
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
      \Zble/cmdspec/opts .* : false trueZd
      g'
	sub:scan/list-command 'source' --exclude-this
	sed -E 'h;s/'"$_make_rex_escseq"'//g;s/^[^:]*:[0-9]+:[[:blank:]]*//
:

        \Ztries to source ~/\.bashrcZd
        \Zsource = source " " \$i;Zd
:
       g'
	sub:scan/a.txt
	sub:scan/check-todo-mark
	sub:scan/bash300bug
	sub:scan/bash301bug
	sub:scan/bash400bug
	sub:scan/bash401-histexpand-bgpid
	sub:scan/bash402-array-empty-element
	sub:scan/bash404-no-argument-return
	sub:scan/bash501-arith-base
	sub:scan/bash502-patsub_replacement
	sub:scan/gawk402bug-regex-check
	sub:scan/nawk-bug
	sub:scan/array-count-in-arithmetic-expression
	sub:scan/unset-variable
	sub:scan/eval-literal
	sub:scan/WA-localvar_inherit
	sub:scan/command-layout
	sub:scan/word-splitting-number
	sub:scan/check-readonly-unsafe
	sub:scan/check-LC_COLLATE
	sub:scan/mistake-_ble_bash
	sub:scan/mistake-bleopt-declare
	sub:scan/mistake-typo
	sub:scan/memo-numbering
}

__shellx_fn_invalid() {
	sed 's/, /\n/g;s/ and /\n/g'
	sed 's/[[:blank:]]/_/g'
	sort LANG=C
}

__shellx_fn_invalid() {
	sort LANG=C
	uniq -c
	sort LANG=C -rnk1
	awk 'function xflush() {if(c!=""){printf("%4d %s\n",c,n);}} {if($1!=c){xflush();c=$1;n=$2}else{n=n", "$2;}}END{xflush()}'
	ifold -w 131 -s --indent=' +[0-9] +'
}

__shellx_fn_invalid() {
	cache_contrib_github=out/contrib-github.txt
if true; then
  :
	fi
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
	echo "Σ: Issues/PRs + max(memo.txt,ChangeLog)"
	join LANG=C -j 2 -e 0 <(sed -En 's/^  \* .*\([^()]+ by ([^()]+)\).*/\1/p' memo/done.txt note.txt | sub:show-contrib/canonicalize | uniq -c | LANG=C sort -k2) <(sed -n 's/.*([^()]* by \([^()]*\)).*/\1/p' docs/ChangeLog.md | sub:show-contrib/canonicalize | uniq -c | LANG=C sort -k2)
	join LANG=C -e 0 -1 1 - -2 2 <(uniq -c "$cache_contrib_github" | LANG=C sort -k2)
	awk 'function max(x,y){return x<y?y:x;}{printf("%4d %s\n",max($2,$3)+$4,$1)}'
	sort -rnk1
	awk 'function xflush() {if(c!=""){printf("%4d %s\n",c,n);}} {if($1!=c){xflush();c=$1;n=$2}else{n=n", "$2;}}END{xflush()}'
	ifold -w 131 -s --indent=' +[0-9] +'
	echo
}

__shellx_fn_invalid() {
	printf '  release-note v0.3.2..v0.3.3 [--changelog CHANGELOG]\n'
}

__shellx_fn_invalid() {
	flags=
	fname_changelog=memo/ChangeLog.md
:
:
:
}

__shellx_fn_invalid() {
	echo __MODE_HEAD__
	git log --format=format:'%h%s' --date-order --abbrev-commit "$1"
	echo
	echo __MODE_MASTER__
	git log --format=format:'%h%s' --date-order --abbrev-commit master
	echo
	awk -F '' '
    /^__MODE_HEAD__$/ {
      mode = "head";
      nlist = 0;
      next;
    }
    /^__MODE_MASTER__$/ { mode = "master"; next; }

    function reduce_title(str) {
      str = $2;
      #if (match(str, /^.*\[(originally: )?(.+: .+)\]$/, m)) str = m[2];
:
      #print str >"/dev/stderr";
      return str;
    }

    mode == "head" {
      i = nlist++;
      titles[i] = $2;
      commit_head[i] = $1;
      title2index[reduce_title($2)] = i;
    mode == "master" && (i = title2index[reduce_title($2)]) != "" && commit_master[i] == "" {
      commit_master[i] = $1;

    END {
      for (i = 0; i < nlist; i++) {
        print commit_head[i] ":" commit_master[i] ":" titles[i];
:
  '

__shellx_fn_invalid() {
	sub:release-note/read-arguments "$@"
	eval IFS=$'\n' 'commits=($(sub:release-note/.find-commit-pairs "$@"))'
:
  :
	:
	tac
}

__shellx_fn_invalid() {
	file=$1
	awk '
    match($0, /\[[^][]+\]/) {
      key = substr($0, 1, RLENGTH);
      gsub(/^\[|]$/, "", key);

      line = substr($0, RLENGTH + 1);
      gsub(/^[[:blank:]]+|[[:blank:]]+$/, "", line);
if (line == "") next; then
if (line !~ /^- /) line = "- " line; then

      if (sect[key] == "")
        keys[nkey++] = key;
      sect[key] = sect[key] line "\n"
      next;
fi
fi
:
}
    {print}

    END {
      for (i=0;i<nkey;i++) {
        key = keys[i];
        print "## " key;
        print sect[key];
:
  ' "$file"

__shellx_fn_invalid() {
	printf '  list-functions [-p] files...\n'
}

__shellx_fn_invalid() {
	files=
	opt_literal=
	i=0
	N=$#
	args=
:
  :
:
if true; then
  :
	fi
if true; then
  :
	fi
	sed -n 's/^[[:blank:]]*function \('"$rex_function_name"'\)[[:blank:]].*/\1/p' "${files[@]}"
	sort -u
}

__shellx_fn_invalid() {
:
  :
	:
	echo "$name not found"
	return 1
}

__shellx_fn_invalid() {
	printf '  first-defined ERE...\n'
}

__shellx_fn_invalid() {
:
  :
	:
	gawk '
    BEGIN {
      g_min_year = -1;
      g_max_year = -1;
    }

    sub(/^file=/, "") { filename = $0; next; }
    match($0, /\y2[0-9]{3}\y/, m) {
      year = m[0];
if (g_min_year < 0 || year < g_min_year) g_min_year = year; then
if (g_max_year < 0 || year > g_max_year) g_max_year = year; then
      g_histogram[year]++;
      g_total_count++;
fi
fi

    END {
      for (year = g_min_year; year <= g_max_year; year++) {
        count = g_histogram[year] + 0;
        percentile = count / g_total_count * 100;
        printf("%s %6d %.1f%%\n", year, count, percentile);
:
  '

__shellx_fn_invalid() {
	sed -E "s/(^| )[[:blank:]]*#.*/ /g" $(findsrc --exclude={memo,wiki,test,\*.md})
	grep -hoE '\b[_a-zA-Z][_a-zA-Z0-9]{3,}\b'
	sed -E 's/^bleopt_//'
	sort
	uniq -c
	sort -n
	less
}

__shellx_fn_invalid() {
	sed -E "s/(^| )[[:blank:]]*#.*/ /g" $(findsrc --exclude={wiki,test,\*.md})
	grep -hoE '\$\{?[_a-zA-Z][_a-zA-Z0-9]*\b|\b[_a-zA-Z][_a-zA-Z0-9]*='
	sed -E 's/^\$\{?(.*)/\1$/g;s/[$=]//'
	sort
	uniq -c
	sort -n
	less
}

__shellx_fn_invalid() {
	funcname=$1
	grep -En "\bfunction $funcname +\{" ble.pp src/*.sh
	awk -F : -v funcname="$funcname" '
    {
      if ($1 == "ble.pp") {
if (funcname ~ /^ble\/util\/assign$|^ble\/bin\/grep$/) next; then
if (funcname == "ble/util/print" && $2 < 30) next; then
      } else if ($1 == "src/benchmark.sh") {
if (funcname ~ /^ble\/util\/(unlocal|print|print-lines)$/) next; then
  :
fi
fi
fi
:
}
      print $1 ":" $2;
      exit
  '

__shellx_fn_invalid() {
	file=$1
:
	sort -u
:
:
  :
:
	sort -t : -Vk 1,2
	less -FSXR
}

__shellx_fn_invalid() {
:
:
}

umask 022
shopt -s nullglob
LC_ALL=
LC_COLLATE=C
_make_rex_escseq='(\[[ -?]*[@-~])*'
sub:help

echo "unknown subcommand '$1'"
builtin exit 1

