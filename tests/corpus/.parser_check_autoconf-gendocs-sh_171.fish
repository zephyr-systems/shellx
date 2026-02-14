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

function calcsize
	set `ls -ks "$argv[1]"`
	echo $argv[1]
end

function copy_images
  set -l odir $argv[1]
  set -e argv[1]
  for f in $argv
    if test -f "$f"
      cp -f "$f" "$odir"
    end
  end
end
function html_split
	set opt "--split=$argv[1] --node-files $commonarg $htmlarg"
	set cmd "$SETLANG $TEXI2HTML --output $PACKAGE.html $opt \"$srcfile\""
	printf "\nGenerating html by %s... (%s)\n" "$argv[1]" "$cmd"
	eval "$cmd"
	__zx_set split_html_dir $PACKAGE.html default 0
	cd $split_html_dir
	exit 1
	__zx_test -f index.html
	__zx_test ! -f $PACKAGE.html
	ln -s $PACKAGE.html index.html
	tar -czf "$abs_outdir/$PACKAGE.html_$argv[1].tar.gz" -- *.html
	eval html_$argv[1]_tgz_size=`calcsize "$outdir/$PACKAGE.html_$argv[1].tar.gz"`
	rm -f "$outdir"/html_$argv[1]/*.html
	mkdir -p "$outdir/html_$argv[1]/"
	mv $split_html_dir/*.html "$outdir/html_$argv[1]/"
	rmdir $split_html_dir
end

__zx_set scriptversion 2026-01-01.00 default 0
set prog 
set srcdir 
__zx_set scripturl "https://git.savannah.gnu.org/cgit/gnulib.git/plain/build-aux/gendocs.sh" default 0
__zx_set templateurl "https://git.savannah.gnu.org/cgit/gnulib.git/plain/doc/gendocs_template" default 0
: "$SETLANG"
: "$MAKEINFO"
: "$TEXI2DVI"
: "$DOCBOOK2HTML"
: "$DOCBOOK2PDF"
: "$DOCBOOK2TXT"
: "$GENDOCS_TEMPLATE_DIR"
: "$PERL"
: "$TEXI2HTML"
set MANUAL_TITLE 
set PACKAGE 
__zx_set EMAIL webmasters@gnu.org default 0
set commonarg 
set dirargs 
set dirs 
set htmlarg "--css-ref=https://www.gnu.org/software/gnulib/manual.css -c TOP_NODE_UP_URL=/manual"
__zx_set default_htmlarg true default 0
__zx_set infoarg --no-split default 0
__zx_set generate_ascii true default 0
__zx_set generate_html true default 0
__zx_set generate_info true default 0
__zx_set generate_tex true default 0
__zx_set outdir manual default 0
__zx_set split node default 0
set srcfile 
set texarg "-t @finalout"
set version "gendocs.sh $scriptversion

Copyright 2026 Free Software Foundation, Inc.
There is NO warranty.  You may redistribute this software
under the terms of the GNU General Public License.
For more information about these matters, see the files named COPYING."
set usage "Usage: $prog [OPTION]... PACKAGE MANUAL-TITLE

Generate output in various formats from PACKAGE.texinfo (or .texi or
.txi) source.  See the GNU Maintainers document for a more extensive
discussion:
  https://www.gnu.org/prep/maintain_toc.html

Options:
  --email ADR use ADR as contact in generated web pages; always give this.

  -s SRCFILE   read Texinfo from SRCFILE, instead of PACKAGE.{texinfo|texi|txi}
  -o OUTDIR    write files into OUTDIR, instead of manual/.
  -I DIR       append DIR to the Texinfo search path.
  --common ARG pass ARG in all invocations.
  --html ARG   pass ARG to makeinfo or texi2html for HTML targets,
                 instead of '$htmlarg'.
  --info ARG   pass ARG to makeinfo for Info, instead of --no-split.
  --no-ascii   skip generating the plain text output.
  --no-html    skip generating the html output.
  --no-info    skip generating the info output.
  --no-tex     skip generating the dvi and pdf output.
  --source ARG include ARG in tar archive of sources.
  --split HOW  make split HTML by node, section, chapter; default node.
  --tex ARG    pass ARG to texi2dvi for DVI and PDF, instead of -t @finalout.

  --texi2html  use texi2html to make HTML target, with all split versions.
  --docbook    convert through DocBook too (xml, txt, html, pdf).

  --help       display this help and exit successfully.
  --version    display version information and exit successfully.

Simple example: $prog --email bug-gnu-emacs@gnu.org emacs \"GNU Emacs Manual\"

Typical sequence:
  cd PACKAGESOURCE/doc
  wget \"$scripturl\"
  wget \"$templateurl\"
  $prog --email BUGLIST MANUAL \"GNU MANUAL - One-line description\"

Output will be in a new subdirectory \"manual\" (by default;
use -o OUTDIR to override).  Move all the new files into your web CVS
tree, as explained in the Web Pages node of maintain.texi.

Please use the --email ADDRESS option so your own bug-reporting
address will be used in the generated HTML pages.

MANUAL-TITLE is included as part of the HTML <title> of the overall
manual/index.html file.  It should include the name of the package being
documented.  manual/index.html is created by substitution from the file
$GENDOCS_TEMPLATE_DIR/gendocs_template.  (Feel free to modify the
generic template for your own purposes.)

If you have several manuals, you'll need to run this script several
times with different MANUAL values, specifying a different output
directory with -o each time.  Then write (by hand) an overall index.html
with links to them all.

If a manual's Texinfo sources are spread across several directories,
first copy or symlink all Texinfo sources into a single directory.
Part of the script's work is to make a tar.gz of the sources.

As implied above, by default monolithic Info files are generated.
If you want split Info, or other Info options, use --info to override.

You can set the environment variables MAKEINFO, TEXI2DVI, TEXI2HTML,
and PERL to control the programs that get executed, and
GENDOCS_TEMPLATE_DIR to control where the gendocs_template file is
looked for.  With --docbook, the environment variables DOCBOOK2HTML,
DOCBOOK2PDF, and DOCBOOK2TXT are also consulted.

By default, makeinfo and texi2dvi are run in the default (English)
locale, since that's the language of most Texinfo manuals.  If you
happen to have a non-English manual and non-English web site, see the
SETLANG setting in the source.

Email bug reports or enhancement requests to bug-gnulib@gnu.org.
:
__zx_test (count $argv) -gt 0
shift
__zx_set srcfile $argv[1] default 0
shift
__zx_set outdir $argv[1] default 0
shift
set dirargs "$dirargs -I '$argv[1]'"
set dirs "$dirs $argv[1]"
shift
__zx_set commonarg $argv[1] default 0
__zx_set docbook yes default 0
shift
__zx_set EMAIL $argv[1] default 0
shift
__zx_set default_htmlarg false default 0
__zx_set htmlarg $argv[1] default 0
shift
__zx_set infoarg $argv[1] default 0
__zx_set generate_ascii false default 0
__zx_set generate_html false default 0
__zx_set generate_info false default 0
__zx_set generate_tex false default 0
shift
__zx_set source_extra $argv[1] default 0
shift
__zx_set split $argv[1] default 0
shift
__zx_set texarg $argv[1] default 0
__zx_set use_texi2html 1 default 0
echo "$usage"
exit 0
echo "$version"
exit 0
echo "$0: Unknown option \`$argv[1]'."
echo "$0: Try \`--help' for more information."
exit 1
__zx_test -z "$PACKAGE"
__zx_set PACKAGE $argv[1] default 0
__zx_test -z "$MANUAL_TITLE"
__zx_set MANUAL_TITLE $argv[1] default 0
echo "$0: extra non-option argument \`$argv[1]'."
exit 1
shift
set commonarg " $dirargs $commonarg"
__zx_set base $PACKAGE default 0

__zx_test -n "$use_texi2html"
__zx_set htmlarg "--css-ref=https://www.gnu.org/software/gnulib/manual.css" default 0
__zx_test -n "$srcfile"
set base 
set base 
__zx_set PACKAGE $base default 0
__zx_test -s "$srcdir/$PACKAGE.texinfo"
PACKAGE.texinfo srcfile=$srcdir/$
__zx_test -s "$srcdir/$PACKAGE.texi"
PACKAGE.texi srcfile=$srcdir/$
__zx_test -s "$srcdir/$PACKAGE.txi"
PACKAGE.txi srcfile=$srcdir/$
echo "$0: cannot find .texinfo or .texi or .txi for $PACKAGE in $srcdir."
exit 1
__zx_test ! -r $GENDOCS_TEMPLATE_DIR/gendocs_template
echo "$0: cannot read $GENDOCS_TEMPLATE_DIR/gendocs_template."
echo "$0: it is available from $templateurl."
exit 1
__zx_set abs_outdir $outdir default 0
__zx_set abs_outdir $srcdir/$outdir default 0
echo "Making output for $srcfile"
echo " in `pwd`"
mkdir -p "$outdir/"

set cmd "$SETLANG $MAKEINFO -o $PACKAGE.info $commonarg $infoarg \"$srcfile\""
echo "Generating info... ($cmd)"
rm -f $PACKAGE.info*
eval "$cmd"
tar czf "$outdir/$PACKAGE.info.tar.gz" $PACKAGE.info*
ls -l "$outdir/$PACKAGE.info.tar.gz"
set info_tgz_size 

set cmd "$SETLANG $TEXI2DVI $dirargs $texarg \"$srcfile\""
printf "\nGenerating dvi... (%s)\n" "$cmd"
eval "$cmd"
gzip -f -9 $PACKAGE.dvi
set dvi_gz_size 
mv $PACKAGE.dvi.gz "$outdir/"
ls -l "$outdir/$PACKAGE.dvi.gz"
set cmd "$SETLANG $TEXI2DVI --pdf $dirargs $texarg \"$srcfile\""
printf "\nGenerating pdf... (%s)\n" "$cmd"
eval "$cmd"
set pdf_size 
mv $PACKAGE.pdf "$outdir/"
ls -l "$outdir/$PACKAGE.pdf"

set opt "-o $PACKAGE.txt --no-split --no-headers $commonarg"
set cmd "$SETLANG $MAKEINFO $opt \"$srcfile\""
printf "\nGenerating ascii... (%s)\n" "$cmd"
eval "$cmd"
set ascii_size 
gzip -f -9 -c $PACKAGE.txt
set ascii_gz_size 
mv $PACKAGE.txt "$outdir/"
ls -l "$outdir/$PACKAGE.txt" "$outdir/$PACKAGE.txt.gz"

__zx_test -z "$use_texi2html"
set opt "--no-split --html -o $PACKAGE.html $commonarg $htmlarg"
set cmd "$SETLANG $MAKEINFO $opt \"$srcfile\""
printf "\nGenerating monolithic html... (%s)\n" "$cmd"
rm -rf $PACKAGE.html
eval "$cmd"
set html_mono_size 
gzip -f -9 -c $PACKAGE.html
set html_mono_gz_size 
copy_images "$outdir/" $PACKAGE.html
mv $PACKAGE.html "$outdir/"
ls -l "$outdir/$PACKAGE.html" "$outdir/$PACKAGE.html.gz"
__zx_test "x$split" = xnode
set split_arg 
__zx_set split_arg --split=$split default 0
set opt "--html -o $PACKAGE.html $split_arg $commonarg $htmlarg"
set cmd "$SETLANG $MAKEINFO $opt \"$srcfile\""
printf "\nGenerating html by %s... (%s)\n" "$split" "$cmd"
eval "$cmd"
__zx_set split_html_dir $PACKAGE.html default 0
copy_images $split_html_dir/ $split_html_dir/*.html
cd $split_html_dir
exit 1
tar -czf "$abs_outdir/$PACKAGE.html_$split.tar.gz" -- *
eval html_$split_tgz_size=`calcsize "$outdir/$PACKAGE.html_$split.tar.gz"`
rm -rf "$outdir/html_$split/"
mv $split_html_dir "$outdir/html_$split/"
du -s "$outdir/html_$split/"
ls -l "$outdir/$PACKAGE.html_$split.tar.gz"
set opt "--output $PACKAGE.html $commonarg $htmlarg"
set cmd "$SETLANG $TEXI2HTML $opt \"$srcfile\""
printf "\nGenerating monolithic html with texi2html... (%s)\n" "$cmd"
rm -rf $PACKAGE.html
eval "$cmd"
set html_mono_size 
gzip -f -9 -c $PACKAGE.html
set html_mono_gz_size 
mv $PACKAGE.html "$outdir/"
html_split node
html_split chapter
html_split section
printf "\nMaking .tar.gz for sources...\n"
set d 
cd "$d"
exit
set pats 
 --version
sed -e 's/^[^0-9]*//' -e 1q
false
true
__zx_test "$file" = "$pat"
__zx_test ! -e "$file"
set pats "$pats $pat"
:
set base 
set cmd "$SETLANG $MAKEINFO $commonarg --trace-includes \"$base\""
eval "$cmd"
tar -czhf "$abs_outdir/$PACKAGE.texi.tar.gz" --verbatim-files-from -T- -- "$base" $pats $source_extra
ls -l "$abs_outdir/$PACKAGE.texi.tar.gz"
__zx_test "$file" = "$pat"
__zx_test ! -e "$file"
set pats "$pats $pat"
:
tar -czhf "$abs_outdir/$PACKAGE.texi.tar.gz" -- $pats $source_extra
ls -l "$abs_outdir/$PACKAGE.texi.tar.gz"
exit
set texi_tgz_size 
__zx_test -n "$docbook"
set opt "-o - --docbook $commonarg"
set cmd "$SETLANG $MAKEINFO $opt \"$srcfile\" >$srcdir/$PACKAGE-db.xml"
printf "\nGenerating docbook XML... (%s)\n" "$cmd"
eval "$cmd"
set docbook_xml_size 
gzip -f -9 -c $PACKAGE-db.xml
set docbook_xml_gz_size 
mv $PACKAGE-db.xml "$outdir/"
__zx_set split_html_db_dir html_node_db default 0
set opt "$commonarg -o $split_html_db_dir"
set cmd "$DOCBOOK2HTML $opt \"$outdir/$PACKAGE-db.xml\""
printf "\nGenerating docbook HTML... (%s)\n" "$cmd"
eval "$cmd"
cd $split_html_db_dir
exit 1
tar -czf "$abs_outdir/$PACKAGE.html_node_db.tar.gz" -- *.html
set html_node_db_tgz_size 
rm -f "$outdir"/html_node_db/*.html
mkdir -p "$outdir/html_node_db"
mv $split_html_db_dir/*.html "$outdir/html_node_db/"
rmdir $split_html_db_dir
set cmd "$DOCBOOK2TXT \"$outdir/$PACKAGE-db.xml\""
printf "\nGenerating docbook ASCII... (%s)\n" "$cmd"
eval "$cmd"
set docbook_ascii_size 
mv $PACKAGE-db.txt "$outdir/"
set cmd "$DOCBOOK2PDF \"$outdir/$PACKAGE-db.xml\""
printf "\nGenerating docbook PDF... (%s)\n" "$cmd"
eval "$cmd"
set docbook_pdf_size 
mv $PACKAGE-db.pdf "$outdir/"
printf "\nMaking index.html for %s...\n" "$PACKAGE"
__zx_test -z "$use_texi2html"
__zx_test x$split = xnode
set CONDS "/%%IF  *HTML_NODE%%/d;/%%ENDIF  *HTML_NODE%%/d;\
           /%%IF  *HTML_CHAPTER%%/,/%%ENDIF  *HTML_CHAPTER%%/d;\
           /%%IF  *HTML_SECTION%%/,/%%ENDIF  *HTML_SECTION%%/d;"
__zx_test x$split = xchapter
set CONDS "/%%IF  *HTML_CHAPTER%%/d;/%%ENDIF  *HTML_CHAPTER%%/d;\
           /%%IF  *HTML_SECTION%%/,/%%ENDIF  *HTML_SECTION%%/d;\
           /%%IF  *HTML_NODE%%/,/%%ENDIF  *HTML_NODE%%/d;"
__zx_test x$split = xsection
set CONDS "/%%IF  *HTML_SECTION%%/d;/%%ENDIF  *HTML_SECTION%%/d;\
           /%%IF  *HTML_CHAPTER%%/,/%%ENDIF  *HTML_CHAPTER%%/d;\
           /%%IF  *HTML_NODE%%/,/%%ENDIF  *HTML_NODE%%/d;"
set CONDS "/%%IF.*%%/d;/%%ENDIF.*%%/d;"
set CONDS "/%%IF.*%%/d;/%%ENDIF.*%%/d;"
set curdate 
sed -e "s!%%TITLE%%!$MANUAL_TITLE!g" -e "s!%%EMAIL%%!$EMAIL!g" -e "s!%%PACKAGE%%!$PACKAGE!g" -e "s!%%DATE%%!$curdate!g" -e "s!%%HTML_MONO_SIZE%%!$html_mono_size!g" -e "s!%%HTML_MONO_GZ_SIZE%%!$html_mono_gz_size!g" -e "s!%%HTML_NODE_TGZ_SIZE%%!$html_node_tgz_size!g" -e "s!%%HTML_SECTION_TGZ_SIZE%%!$html_section_tgz_size!g" -e "s!%%HTML_CHAPTER_TGZ_SIZE%%!$html_chapter_tgz_size!g" -e "s!%%INFO_TGZ_SIZE%%!$info_tgz_size!g" -e "s!%%DVI_GZ_SIZE%%!$dvi_gz_size!g" -e "s!%%PDF_SIZE%%!$pdf_size!g" -e "s!%%ASCII_SIZE%%!$ascii_size!g" -e "s!%%ASCII_GZ_SIZE%%!$ascii_gz_size!g" -e "s!%%TEXI_TGZ_SIZE%%!$texi_tgz_size!g" -e "s!%%DOCBOOK_HTML_NODE_TGZ_SIZE%%!$html_node_db_tgz_size!g" -e "s!%%DOCBOOK_ASCII_SIZE%%!$docbook_ascii_size!g" -e "s!%%DOCBOOK_PDF_SIZE%%!$docbook_pdf_size!g" -e "s!%%DOCBOOK_XML_SIZE%%!$docbook_xml_size!g" -e "s!%%DOCBOOK_XML_GZ_SIZE%%!$docbook_xml_gz_size!g" -e "s,%%SCRIPTURL%%,$scripturl,g" -e "s!%%SCRIPTNAME%%!$prog!g" -e "$CONDS" $GENDOCS_TEMPLATE_DIR/gendocs_template
echo "Done, see $outdir/ subdirectory for new files."
