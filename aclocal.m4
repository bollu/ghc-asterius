dnl $Id: aclocal.m4,v 1.87 2001/11/07 20:13:26 sof Exp $
dnl 
dnl Extra autoconf macros for the Glasgow fptools
dnl
dnl To be a good autoconf citizen, names of local macros have
dnl prefixed with FPTOOLS_ to ensure we don't clash
dnl with any pre-supplied autoconf ones.

dnl
dnl Is timezone around? (in a header file)
dnl 
AC_DEFUN(FPTOOLS_HAVE_TIMEZONE,
[AC_CACHE_CHECK([timezone], fptools_cv_have_timezone,
[AC_TRY_COMPILE([#if TIME_WITH_SYS_TIME
# include <sys/time.h>
# include <time.h>
#else
# if HAVE_SYS_TIME_H
#  include <sys/time.h>
# else
#  include <time.h>
# endif
#endif
], [return timezone;], 
fptools_cv_have_timezone=yes, fptools_cv_have_timezone=no)])
if test "$fptools_cv_have_timezone" = yes; then
  AC_DEFINE(HAVE_TIMEZONE)
fi
])

dnl
dnl Has timezone the type time_t or long (HP-UX 10.20 apparently
dnl has `long'..)
dnl 
AC_DEFUN(FPTOOLS_TYPE_TIMEZONE,
[AC_CACHE_CHECK([type of timezone], fptools_cv_type_timezone,
[AC_TRY_COMPILE([#if TIME_WITH_SYS_TIME
# include <sys/time.h>
# include <time.h>
#else
# if HAVE_SYS_TIME_H
#  include <sys/time.h>
# else
#  include <time.h>
# endif
#endif

extern time_t timezone;	
],
[int i;], fptools_cv_type_timezone=time_t, fptools_cv_type_timezone=long)])
AC_DEFINE_UNQUOTED(TYPE_TIMEZONE, $fptools_cv_type_timezone)
])

dnl *** Is altzone available? ***
dnl 
AC_DEFUN(FPTOOLS_ALTZONE,
[AC_CACHE_CHECK([altzone], fptools_cv_altzone,
[AC_TRY_LINK([#if TIME_WITH_SYS_TIME
# include <sys/time.h>
# include <time.h>
#else
# if HAVE_SYS_TIME_H
#  include <sys/time.h>
# else
#  include <time.h>
# endif
#endif
], [return altzone;], 
fptools_cv_altzone=yes, fptools_cv_altzone=no)])
if test "$fptools_cv_altzone" = yes; then
  AC_DEFINE(HAVE_ALTZONE)
fi
])


dnl *** Does libc contain GNU regex? ***
dnl 
AC_DEFUN(FPTOOLS_REGEX_IN_LIBC,
[AC_CACHE_CHECK([for GNU regex in libc], fptools_cv_have_regex,
[AC_TRY_LINK([#if HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <regex.h>
],[ struct re_pattern_buffer patbuf; 
    re_compile_pattern("",0,&patbuf);
    re_search_2 (&patbuf, "", 0, "",0, 0,0,0,0); ],
fptools_cv_have_regex=yes, fptools_cv_have_regex=no)])
if test "$fptools_cv_have_regex" = yes; then
	HaveRegex=YES
else
	HaveRegex=NO
fi
AC_SUBST(HaveRegex)
])


dnl ** check for leading underscores in symbol names
dnl 
dnl Test for determining whether symbol names have a leading
dnl underscore.
dnl 
dnl We assume that they _haven't_ if anything goes wrong.
dnl
dnl Some nlist implementations seem to try to be compatible by ignoring
dnl a leading underscore sometimes (eg. FreeBSD).  We therefore have
dnl to work around this by checking for *no* leading underscore first.
dnl Sigh.  --SDM
dnl
AC_DEFUN(FPTOOLS_UNDERSCORE,
[AC_CHECK_LIB(elf, nlist, LIBS="-lelf $LIBS")dnl
AC_CACHE_CHECK([leading underscore in symbol names], fptools_cv_lead_uscore,

dnl
dnl Hack!: nlist() under Digital UNIX insist on there being an _,
dnl but symbol table listings shows none. What is going on here?!?
dnl
dnl Another hack: cygwin doesn't come with nlist.h , so we hardwire
dnl the underscoredness of that "platform"
changequote(<<, >>)dnl
<<
case $HostPlatform in
alpha-dec-osf*) fptools_cv_lead_uscore='no';;
*cygwin32) fptools_cv_lead_uscore='yes';;
*mingw32) fptools_cv_lead_uscore='yes';;
*) >>
changequote([, ])dnl
AC_TRY_RUN([#ifdef HAVE_NLIST_H
#include <nlist.h>
changequote(<<, >>)dnl
<<
struct nlist xYzzY1[] = {{"xYzzY1", 0},{0}};
struct nlist xYzzY2[] = {{"_xYzzY2", 0},{0}};
#endif

main(argc, argv)
int argc;
char **argv;
{
#ifdef HAVE_NLIST_H
    if(nlist(argv[0], xYzzY1) == 0 && xYzzY1[0].n_value != 0)
        exit(1);
    if(nlist(argv[0], xYzzY2) == 0 && xYzzY2[0].n_value != 0)
        exit(0);>>
changequote([, ])dnl
#endif
    exit(1);
}], fptools_cv_lead_uscore=yes, fptools_cv_lead_uscore=no, fptools_cv_lead_uscore=NO)
;;
esac);
LeadingUnderscore=`echo $fptools_cv_lead_uscore | sed 'y/yesno/YESNO/'`
AC_SUBST(LeadingUnderscore)
case $LeadingUnderscore in
YES) AC_DEFINE(LEADING_UNDERSCORE);;
esac
])

dnl
dnl FPTOOLS_PROG_CHECK_VERSION(VERSIONSTR1, TEST, VERSIONSTR2,
dnl                            ACTION-IF-TRUE [, ACTION-IF-FALSE])
dnl
dnl compare versions field-wise (separator is '.')
dnl TEST is one of {-lt,-le,-eq,-ge,-gt}
dnl
dnl quite shell-independant and SUSv2 compliant code
dnl
dnl NOTE: the loop could be unrolled within autoconf, but the
dnl       macro code would be a) longer and b) harder to debug... ;)
dnl
AC_DEFUN(FPTOOLS_PROG_CHECK_VERSION,
[if ( IFS=".";
      a="[$1]";  b="[$3]";
      while test -n "$a$b"
      do
              set -- [$]a;  h1="[$]1";  shift 2>/dev/null;  a="[$]*"
              set -- [$]b;  h2="[$]1";  shift 2>/dev/null;  b="[$]*"
              test -n "[$]h1" || h1=0;  test -n "[$]h2" || h2=0
              test [$]{h1} -eq [$]{h2} || break
      done
      test [$]{h1} [$2] [$]{h2}
    )
then ifelse([$4],,[:],[
  $4])
ifelse([$5],,,
[else
  $5])
fi
])])dnl


dnl
dnl Check for Happy and version.  If we're building GHC, then we need
dnl at least Happy version 1.9.  If there's no installed Happy, we look
dnl for a happy source tree and point the build system at that instead.
dnl
AC_DEFUN(FPTOOLS_HAPPY,
[
if test -d $srcdir/happy; then
   SrcTreeHappyCmd=$hardtop/happy/src/happy-inplace
fi
AC_PATH_PROG(HappyCmd,happy,$SrcTreeHappyCmd)
AC_CACHE_CHECK([for version of happy], fptools_cv_happy_version,
changequote(, )dnl
[if test x"$HappyCmd" = x"$SrcTreeHappyCmd"; then
   fptools_cv_happy_version=`grep '^ProjectVersion[ 	]*=' $srcdir/happy/mk/version.mk | sed 's/.*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/g'`;
elif test x"$HappyCmd" != x; then
   fptools_cv_happy_version="`$HappyCmd -v |
			  grep 'Happy Version' | sed -e 's/Happy Version \([^ ]*\).*/\1/g'`" ;
else
   fptools_cv_happy_version="";
fi;
changequote([, ])dnl
])
if test -d $srcdir/ghc; then
  FPTOOLS_PROG_CHECK_VERSION([$fptools_cv_happy_version],-lt,[1.9],
  [AC_MSG_ERROR([Happy version 1.9 or later is required to compile GHC.])])dnl
fi
HappyVersion=$fptools_cv_happy_version;
AC_SUBST(HappyVersion)

# 1.9 and later is required, assume that we can use
# the "-agc" options.
HappyOpts="-agc"
AC_SUBST(HappyOpts)
])

dnl
dnl What's the best way of doing context diffs?
dnl
dnl (NB: NeXTStep thinks diff'ing a file against itself is "trouble")
dnl
AC_DEFUN(FPTOOLS_PROG_DIFF,
[AC_CACHE_CHECK([for ok way to do context diffs], fptools_cv_context_diffs,
[echo foo > conftest1
echo foo > conftest2
if diff -C 1 conftest1 conftest2 > /dev/null 2>&1 ; then
    fptools_cv_context_diffs='diff -C 1'
else
    if diff -c1 conftest1 conftest2 > /dev/null 2>&1 ; then
        fptools_cv_context_diffs='diff -c1'
    else
        echo "Can't figure out how to do context diffs."
        echo "Neither \`diff -C 1' nor \`diff -c1' works."
        exit 1
    fi
fi
rm -f conftest1 conftest2
])
ContextDiffCmd=$fptools_cv_context_diffs
AC_SUBST(ContextDiffCmd)
])

dnl
dnl Check whether ld supports -x
dnl
AC_DEFUN(FPTOOLS_LD_X,
[AC_CACHE_CHECK([whether ld understands -x], fptools_cv_ld_x,
[
echo 'foo() {}' > conftest.c
${CC-cc} -c conftest.c
if ${LdCmd} -r -x -o foo.o conftest.o; then
   fptools_cv_ld_x=yes
else
   fptools_cv_ld_x=no
fi
rm -rf conftest.c conftest.o foo.o
])
if test "$fptools_cv_ld_x" = yes; then
	LdXFlag=-x
else
	LdXFlag=
fi
AC_SUBST(LdXFlag)
])

dnl
dnl Finding the Right Yacc
dnl
AC_DEFUN(FPTOOLS_PROG_YACCY,
[AC_PROG_YACC
if test "$YACC" = "yacc"; then
   AC_CACHE_CHECK([if it is an OK yacc], ac_cv_prog_yacc,
   [AC_CHECK_PROG(WhatCmd, what, what, :)
    $WhatCmd $YACC > conftest.out
    if egrep 'y1\.c 1\..*SMI' conftest.out >/dev/null 2>&1; then
        echo "I don't trust your $YaccCmd; it looks like an old Sun yacc"
        if test -f /usr/lang/yacc; then
           echo "I'm going to use /usr/lang/yacc instead"
           ac_cv_prog_yacc=/usr/lang/yacc
        else
           echo "I'm assuming the worst...no parser generator at all"
           ac_cv_prog_yacc=:
        fi
    elif egrep 'y1\.c.*Revision: 4\.2\.6\.3.*DEC' conftest.out >/dev/null 2>&1; then
        echo "I don't trust your $YaccCmd; it looks like a lame DEC yacc"
        echo "I'm assuming the worst...no parser generator at all"
        ac_cv_prog_yacc=:
    else
	ac_cv_prog_yacc=$YACC
    fi
    rm -fr conftest*
])
else
    ac_cv_prog_yacc=$YACC
fi
YaccCmd=$ac_cv_prog_yacc
AC_SUBST(YaccCmd)
])

dnl *** Checking for ar and its arguments + whether we need ranlib.
dnl
dnl ArCmd, ArSupportsInput and RANLIB are AC_SUBST'ed
dnl On Digital UNIX, we test for the -Z (compress) and
dnl -input (take list of files from external file) flags.
dnl 
AC_DEFUN(FPTOOLS_PROG_AR_AND_RANLIB,
[AC_PATH_PROG(ArCmd,ar)
if test -z "$ArCmd"; then
    echo "You don't seem to have ar in your PATH...I have no idea how to make a library"
    exit 1;
fi
if $ArCmd clqsZ conftest.a >/dev/null 2>/dev/null; then
    ArCmd="$ArCmd clqsZ"
    NeedRanLib=''
elif $ArCmd clqs conftest.a >/dev/null 2>/dev/null; then
    ArCmd="$ArCmd clqs"
    NeedRanLib=''
elif $ArCmd cqs conftest.a >/dev/null 2>/dev/null; then
    ArCmd="$ArCmd cqs"
    NeedRanLib=''
elif $ArCmd clq conftest.a >/dev/null 2>/dev/null; then
    ArCmd="$ArCmd clq"
    NeedRanLib='YES'
elif $ArCmd cq conftest.a >/dev/null 2>/dev/null; then
    ArCmd="$ArCmd cq"
    NeedRanLib='YES'
elif $ArCmd cq conftest.a 2>&1 | grep 'no archive members specified' >/dev/null 2>/dev/null; then
    ArCmd="$ArCmd cq"
    NeedRanLib='YES'
else
    echo "I can't figure out how to use your $ArCmd"
    exit 1
fi
rm -rf conftest*
test -n "$ArCmd" && test -n "$verbose" && echo "        setting ArCmd to $ArCmd"
AC_SUBST(ArCmd)
if $ArCmd conftest.a -input /dev/null >/dev/null 2>/dev/null; then
    ArSupportsInput='-input'
else
    ArSupportsInput=''
fi
rm -rf conftest*
test -n "$ArSupportsInput" && test -n "$verbose" && echo "        setting ArSupportsInput to $ArSupportsInput"
AC_SUBST(ArSupportsInput)
if test -z "$NeedRanLib"; then
    RANLIB=':'
    test -n "$verbose" && echo "        setting RANLIB to $RANLIB"
    AC_SUBST(RANLIB)
else
    AC_PROG_RANLIB
fi
])

dnl
dnl AC_SHEBANG_PERL - can we she-bang perl?
dnl
AC_DEFUN(FPTOOLS_SHEBANG_PERL,
[AC_CACHE_CHECK([if your perl works in shell scripts], fptools_cv_shebang_perl,
[echo "#!$PerlCmd"'
exit $1;
' > conftest
chmod u+x conftest
(SHELL=/bin/sh; export SHELL; ./conftest 69 > /dev/null)
if test $? -ne 69; then
   fptools_cv_shebang_perl=yes
else
   fptools_cv_shebang_perl=no
fi
rm -f conftest
])])

dnl
dnl Extra testing of the result AC_PROG_CC, testing the gcc version no.
dnl *Must* be called after AC_PROG_CC
dnl
AC_DEFUN(FPTOOLS_HAVE_GCC,
[AC_CACHE_CHECK([whether you have an ok gcc], fptools_cv_have_gcc,
[if test -z "$GCC"; then
    echo ''
    echo "You would be better off with gcc"
    echo "Perhaps it is already installed, but not in your PATH?"
    fptools_cv_have_gcc='no'
else
changequote(, )dnl
    is_gcc_v1="`$CC -v 2>&1 | grep 'version ' | sed -e 's/.*version [^0-9]*\([0-9][0-9]*\)\.\([0-9][0-9]*\).*/expr 2000 \\\>= \1 \\\* 1000 + \2/g' `"
    is_gcc_v3="`$CC -v 2>&1 | grep 'version ' | sed -e 's/.*version [^0-9]*\([0-9][0-9]*\)\.\([0-9][0-9]*\).*/expr 3000 \\\<= \1 \\\* 1000 + \2/g' `"
changequote([, ])dnl
    fptools_cv_have_gcc='yes'
    if test `eval $is_gcc_v1 2>/dev/null` = "1"; then
        fptools_cv_have_gcc='no'
        echo ""
	echo "your gcc version appears to be ..."
        $CC --version
        echo "gcc prior to 2.0 and have never worked with ghc."
        echo "we recommend 2.95.3, although versions back to 2.7.2 should be ok."
        AC_MSG_ERROR([gcc 1.X has never been supported])
    fi
    if test `eval $is_gcc_v3 2>/dev/null` = "1"; then
        fptools_cv_have_gcc='no'
        echo ""
	echo "your gcc version appears to be ..."
        $CC --version
        echo "gcc versions 3.0 and above are not yet supported."
        echo "we recommend 2.95.3, although versions back to 2.7.2 should be ok."
        AC_MSG_ERROR([gcc 3.0 and above is not currently supported])
    fi
fi
])
HaveGcc=`echo $fptools_cv_have_gcc | sed 'y/yesno/YESNO/'`
AC_SUBST(HaveGcc)
])

dnl Small feature test for perl version. Assumes PerlCmd
dnl contains path to perl binary
dnl
AC_DEFUN(FPTOOLS_CHECK_PERL_VERSION,
[$PerlCmd -v >conftest.out 2>&1
if grep "version 5" conftest.out >/dev/null 2>&1; then
   :
else
  if grep "v5.6" conftest.out >/dev/null 2>&1; then
     :
  else
     if grep "version 6" conftest.out >/dev/null 2>&1; then
	:
     else
       echo "Your version of perl probably won't work."
     fi
  fi
fi
rm -fr conftest*
])

dnl
dnl Getting at the right version of 'find'
dnl (i.e., not the MS util on a Win32 box).
dnl
AC_DEFUN(FPTOOLS_FIND_FIND,
[
AC_PATH_PROG(Find2Cmd, find)
$Find2Cmd --version > conftest.out 2>&1 
if grep "FIND: Parameter format" conftest.out >/dev/null 2>&1 ; then
   # Encountered MS' find utility, which is not what we're after.
   #
   # HACK - AC_CHECK_PROG is useful here in that does let you reject
   # an (absolute) entry in the path (Find2Cmd). It is not so useful
   # in that it doesn't let you (AFAIU) set VARIABLE equal to the 
   # absolute path eventually found. So, hack around this by inspecting
   # what variables hold the abs. path & use them directly.
   AC_CHECK_PROG(FindCmd,find,`echo $ac_dir/$ac_word`,find,,$Find2Cmd)
else
FindCmd=$Find2Cmd
AC_SUBST(FindCmd)
fi
])

dnl
dnl FPTOOLS_NOCACHE_CHECK prints a message, then sets the
dnl values of the second argument to the result of running
dnl the commands given by the third. It does not cache its
dnl result, so it is suitable for checks which should be
dnl run every time.
dnl
AC_DEFUN(FPTOOLS_NOCACHE_CHECK,
[AC_MSG_CHECKING([$1])
 $3
 AC_MSG_RESULT([$][$2])
])

dnl
dnl FPTOOLS_GHC_VERSION(version)
dnl FPTOOLS_GHC_VERSION(major, minor [, patchlevel])
dnl FPTOOLS_GHC_VERSION(version, major, minor, patchlevel)
dnl
dnl Test for version of installed ghc.  Uses $GHC.
dnl [original version pinched from c2hs]
dnl
AC_DEFUN(FPTOOLS_GHC_VERSION,
[FPTOOLS_NOCACHE_CHECK([version of ghc], [fptools_version_of_ghc],
[${WithGhc-ghc} --version > conftestghc 2>&1
  cat conftestghc >&AC_FD_CC
#Useless Use Of cat award...
  fptools_version_of_ghc=`cat conftestghc | sed -n -e 's/, patchlevel *\([[0-9]]\)/.\1/;s/.* version \([[0-9]][[0-9.]]*\).*/\1/p'`
  rm -fr conftest*
  if test "[$]fptools_version_of_ghc" = ""
  then
    fptools_version_of_ghc='unknown'
  fi
fptools_version_of_ghc[_major]=`echo [$]fptools_version_of_ghc | sed -e 's/^\([[0-9]]\).*/\1/'`
fptools_version_of_ghc[_minor]=`echo [$]fptools_version_of_ghc | sed -e 's/^[[0-9]]\.\([[0-9]]*\).*/\1/'`
fptools_version_of_ghc[_pl]=`echo [$]fptools_version_of_ghc | sed -n -e 's/^[[0-9]]\.[[0-9]]*\.\([[0-9]]*\)/\1/p'`
#
if test "[$]fptools_version_of_ghc[_pl]" = ""
then
  fptools_version_of_ghc[_all]="[$]fptools_version_of_ghc[_major].[$]fptools_version_of_ghc[_minor]"
  fptools_version_of_ghc[_pl]="0"
else
  fptools_version_of_ghc[_all]="[$]fptools_version_of_ghc[_major].[$]fptools_version_of_ghc[_minor].[$]fptools_version_of_ghc[_pl]"
fi
#
ifelse($#, [1], [dnl
[$1]="[$]fptools_version_of_ghc[_all]"
], $#, [2], [dnl
[$1]="[$]fptools_version_of_ghc[_major]"
[$2]="[$]fptools_version_of_ghc[_minor]"
], $#, [3], [dnl
[$1]="[$]fptools_version_of_ghc[_major]"
[$2]="[$]fptools_version_of_ghc[_minor]"
[$3]="[$]fptools_version_of_ghc[_pl]"
], $#, [4], [dnl
[$1]="[$]fptools_version_of_ghc[_all]"
[$2]="[$]fptools_version_of_ghc[_major]"
[$3]="[$]fptools_version_of_ghc[_minor]"
[$4]="[$]fptools_version_of_ghc[_pl]"
])
])
])dnl


dnl ** figure out the alignment restriction of a type
dnl    (required SIZEOF test but AC_CHECK_SIZEOF doesn't call PROVIDE
dnl     so we can't call REQUIRE)

dnl FPTOOLS_CHECK_ALIGNMENT(TYPE)
AC_DEFUN(FPTOOLS_CHECK_ALIGNMENT,
[changequote(<<, >>)dnl
dnl The name to #define.
define(<<AC_TYPE_NAME>>, translit(alignment_$1, [a-z *], [A-Z_P]))dnl
dnl The cache variable name.
define(<<AC_CV_NAME>>, translit(ac_cv_alignment_$1, [ *], [_p]))dnl
dnl The name of the corresponding size.
define(<<AC_CV_SIZEOF_NAME>>, translit(ac_cv_sizeof_$1, [ *], [_p]))dnl
changequote([, ])dnl
AC_MSG_CHECKING(alignment of $1)
AC_CACHE_VAL(AC_CV_NAME,
[AC_TRY_RUN([
#include <stdio.h>
#if HAVE_STDDEF_H
#include <stddef.h>
#endif
#ifndef offsetof
#define offsetof(ty,field) ((size_t)((char *)&((ty *)0)->field - (char *)(ty *)0))
#endif
int
main()
{
  FILE *f=fopen("conftestval", "w");
  if (!f) exit(1);
  fprintf(f, "%d", offsetof(struct { char c; $1 ty;},ty));
  exit(0);
}],
AC_CV_NAME=`cat conftestval`,
AC_CV_NAME=$AC_CV_SIZEOF_NAME,
AC_CV_NAME=$AC_CV_SIZEOF_NAME)])
AC_MSG_RESULT($AC_CV_NAME)
AC_DEFINE_UNQUOTED(AC_TYPE_NAME, $AC_CV_NAME)
AC_PROVIDE($AC_TYPE_NAME)
undefine([AC_TYPE_NAME])dnl
undefine([AC_CV_NAME])dnl
undefine([AC_CV_SIZEOF_NAME])dnl
])

dnl ** Map an arithmetic C type to a Haskell type.
dnl    Based on autconf's AC_CHECK_SIZEOF.

dnl FPTOOLS_CHECK_HTYPE(TYPE [, DEFAULT_VALUE, [, VALUE-FOR-CROSS-COMPILATION])
AC_DEFUN(FPTOOLS_CHECK_HTYPE,
[changequote(<<, >>)dnl
dnl The name to #define.
define(<<AC_TYPE_NAME>>, translit(htype_$1, [a-z *], [A-Z_P]))dnl
dnl The cache variable name.
define(<<AC_CV_NAME>>, translit(fptools_cv_htype_$1, [ *], [_p]))dnl
changequote([, ])dnl
AC_MSG_CHECKING(Haskell type for $1)
AC_CACHE_VAL(AC_CV_NAME,
[AC_TRY_RUN([#include <stdio.h>
#include <stddef.h>
#ifdef HAVE_SIGNAL_H
#include <signal.h>
#endif
#ifdef HAVE_TIME_H
#include <time.h>
#endif
#ifdef HAVE_GL_GL_H
#include <GL/gl.h>
#endif

typedef $1 testing;

main() {
  FILE *f=fopen("conftestval", "w");
  if (!f) exit(1);
  if (((testing)((int)((testing)1.4))) == ((testing)1.4)) {
    fprintf(f, "%s%d\n",
           ((testing)(-1) < (testing)0) ? "Int" : "Word",
           sizeof(testing)*8);
  } else {
    fprintf(f,"%s\n",
           (sizeof(testing) >  sizeof(double)) ? "LDouble" :
           (sizeof(testing) == sizeof(double)) ? "Double"  : "Float");
  }
  fclose(f);
  exit(0);
}], AC_CV_NAME=`cat conftestval`,
ifelse([$2], , AC_CV_NAME=NotReallyAType,      AC_CV_NAME=$2),
ifelse([$3], , AC_CV_NAME=NotReallyATypeCross, AC_CV_NAME=$3))]) dnl
AC_MSG_RESULT($AC_CV_NAME)
AC_DEFINE_UNQUOTED(AC_TYPE_NAME, $AC_CV_NAME)
undefine([AC_TYPE_NAME])dnl
undefine([AC_CV_NAME])dnl
])

dnl ** figure out whether C compiler supports 'long long's
dnl    (Closely based on Andreas Zeller's macro for testing
dnl     for this under C++)
dnl
dnl    If the C compiler supports `long long' types,
dnl    define `HAVE_LONG_LONG'.
dnl
AC_DEFUN(FPTOOLS_C_LONG_LONG,
[
AC_REQUIRE([AC_PROG_CC])
AC_MSG_CHECKING(whether ${CC} supports long long types)
AC_CACHE_VAL(fptools_cv_have_long_long,
[
AC_LANG_SAVE
AC_LANG_C
AC_TRY_COMPILE(,[long long a;],
fptools_cv_have_long_long=yes,
fptools_cv_have_long_long=no)
AC_LANG_RESTORE
])
AC_MSG_RESULT($fptools_cv_have_long_long)
if test "$fptools_cv_have_long_long" = yes; then
AC_DEFINE(HAVE_LONG_LONG)
fi
])

dnl ** Obtain the value of a C constant.
dnl    The value will be `(-1)' if the constant is undefined.
dnl
dnl    This is set up so that the argument can be a shell variable.
dnl
AC_DEFUN(FPTOOLS_CHECK_CCONST,
[
eval "def_name=CCONST_$1"
eval "cv_name=ac_cv_cconst_$1"
AC_MSG_CHECKING(value of $1)
AC_CACHE_VAL($cv_name,
[AC_TRY_RUN([#include <stdio.h>
#include <errno.h>
main()
{
  FILE *f=fopen("conftestval", "w");
  if (!f) exit(1);
  fprintf(f, "%d\n", $1);
  exit(0);
}], 
eval "$cv_name=`cat conftestval`",
eval "$cv_name=-1",
eval "$cv_name=-1")])dnl
eval "fptools_check_cconst_result=`echo '$'{$cv_name}`"
AC_MSG_RESULT($fptools_check_cconst_result)
AC_DEFINE_UNQUOTED($def_name, $fptools_check_cconst_result)
unset fptools_check_cconst_result
])

dnl ** Invoke AC_CHECK_CCONST on each argument (which have to separate with 
dnl    spaces)
dnl
AC_DEFUN(FPTOOLS_CHECK_CCONSTS,
[for ac_const_name in $1
do
FPTOOLS_CHECK_CCONST($ac_const_name)dnl
done
])


dnl *** Can we open files in binary mode? ***
dnl 
AC_DEFUN(FPTOOLS_O_BINARY,
[
AC_REQUIRE([AC_PROG_CC])
AC_MSG_CHECKING(whether we can open files in binary mode)
AC_CACHE_VAL(fptools_cv_have_o_binary,
[
AC_LANG_SAVE
AC_LANG_C
AC_TRY_COMPILE(,
[#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif
int x = O_BINARY;],
fptools_cv_have_o_binary=yes,
fptools_cv_have_o_binary=no)
AC_LANG_RESTORE
])
AC_MSG_RESULT($fptools_cv_have_o_binary)
if test "$fptools_cv_have_o_binary" = yes; then
AC_DEFINE(HAVE_O_BINARY)
fi
])

dnl *** Which one comes first, .text or .data? ***
dnl 
AC_DEFUN(FPTOOLS_CODE_BEFORE_DATA,
[AC_CACHE_CHECK([if code section appears before data], fptools_cv_code_bef_data,
[AC_TRY_RUN([
int f() { return 1; }
int i;
int main() { return ((char*)&f > (char*)&i); }

],
fptools_cv_code_bef_data=yes, fptools_cv_code_bef_data=no,false)])
if test "$fptools_cv_code_bef_data" = yes; then
  AC_DEFINE(CODE_BEFORE_DATA)
fi
])

dnl *** Helper function **
dnl 
AC_DEFUN(FPTOOLS_IN_SCOPE,
[AC_TRY_LINK([extern char* $1;],[return (int)&$2], $3=yes, $3=no)
])

dnl *** What's the end-of-text-section marker called? ***
dnl
AC_DEFUN([FPTOOLS_END_TEXT_SECTION],
[AC_CACHE_CHECK([for end of text section marker],
                [fptools_cv_end_of_text],
		[fptools_cv_end_of_text=""
		 not_done=1
		 for i in data_start _data_start etext _etext __etext; do
		   FPTOOLS_IN_SCOPE($i,$i,fptools_end_of_text)
		   if test "$fptools_end_of_text" = yes; then
		     fptools_cv_end_of_text=$i
		     not_done=0
		     break
		   fi
		 done
		 if test "$not_done" = 1; then
		   FPTOOLS_IN_SCOPE(etext asm("etext"),etext,fptools_end_of_text)
		   if test "$fptools_end_of_text" = yes; then
		     fptools_cv_end_of_text="etext"
		   fi
		 fi])
		 if test -n "$fptools_cv_end_of_text"; then
		   AC_DEFINE_UNQUOTED([TEXT_SECTION_END_MARKER], $fptools_cv_end_of_text)
		 else
		   AC_DEFINE_UNQUOTED([TEXT_SECTION_END_MARKER], dunno_end_of_text)
		 fi
 AC_CACHE_CHECK([for end of text section marker declaration],
		[fptools_cv_end_of_text_decl],
		[fptools_cv_end_of_text_decl=""
		 not_done=1
		 for i in data_start _data_start etext _etext __etext; do
		   FPTOOLS_IN_SCOPE($i,$i,fptools_end_of_text_decl)
		   if test "$fptools_end_of_text_decl" = yes; then
		     fptools_cv_end_of_text_decl=$i
		     not_done=0
		     break
		   fi
		 done
		 if test "$not_done" = 1; then
		   FPTOOLS_IN_SCOPE(etext asm("etext"),etext,fptools_end_of_text_decl)
		   if test "$fptools_end_of_text_decl" = yes; then
		     fptools_cv_end_of_text_decl="etext asm(\"etext\")"
		   fi
		 fi])
		 if test -n "$fptools_cv_end_of_text_decl"; then
		   AC_DEFINE_UNQUOTED([TEXT_SECTION_END_MARKER_DECL], $fptools_cv_end_of_text_decl)
		 else
		   AC_DEFINE_UNQUOTED([TEXT_SECTION_END_MARKER_DECL], dunno_end_of_text_decl)
		 fi
])		   
 
dnl *** What's the end-of-data-section marker called? ***
dnl
AC_DEFUN([FPTOOLS_END_DATA_SECTION],
[AC_CACHE_CHECK([for end of data section marker],
                [fptools_cv_end_of_data],
		[fptools_cv_end_of_data=""
		 not_done=1
		 for i in end _end __end; do
		   FPTOOLS_IN_SCOPE($i,$i,fptools_end_of_data)
		   if test "$fptools_end_of_data" = yes; then
		     fptools_cv_end_of_data=$i
		     not_done=0
		     break
		   fi
		 done
		 if test "$not_done" = 1; then
		   FPTOOLS_IN_SCOPE(end asm("end"),end,fptools_end_of_data)
		   if test "$fptools_end_of_data" = yes; then
		     fptools_cv_end_of_data="end"
		   fi
		 fi])
		 if test -n "$fptools_cv_end_of_data"; then
		   AC_DEFINE_UNQUOTED([DATA_SECTION_END_MARKER], $fptools_cv_end_of_data)
		 else
		   AC_DEFINE_UNQUOTED([DATA_SECTION_END_MARKER], dunno_end_of_data)
		 fi
 AC_CACHE_CHECK([for end of data section marker declaration],
		[fptools_cv_end_of_data_decl],
		[fptools_cv_end_of_data_decl=""
		 not_done=1
		 for i in end _end __end; do
		   FPTOOLS_IN_SCOPE($i,$i,fptools_end_of_data_decl)
		   if test "$fptools_end_of_data_decl" = yes; then
		     fptools_cv_end_of_data_decl=$i
		     not_done=0
		     break
		   fi
		 done
		 if test "$not_done" = 1; then
		   FPTOOLS_IN_SCOPE(end asm("end"),end,fptools_end_of_data_decl)
		   if test "$fptools_end_of_data_decl" = yes; then
		     fptools_cv_end_of_data_decl="end asm(\"end\")"
		   fi
		 fi])
		 if test -n "$fptools_cv_end_of_data_decl"; then
		   AC_DEFINE_UNQUOTED([DATA_SECTION_END_MARKER_DECL], $fptools_cv_end_of_data_decl)
		 else
		   AC_DEFINE_UNQUOTED([DATA_SECTION_END_MARKER_DECL], dunno_end_of_data_decl)
		 fi
])		   
 

dnl Based on AC_TRY_LINK - run iftrue if links cleanly with no warning

dnl FPTOOLS_TRY_LINK_NOWARN(flags,main?,iftrue,iffalse)

AC_DEFUN(FPTOOLS_TRY_LINK_NOWARN,
[
ac_save_LIBS="$LIBS"
LIBS=[$1];
cat > conftest.$ac_ext <<EOF
dnl This sometimes fails to find confdefs.h, for some reason.
dnl [#]line __oline__ "[$]0"
[#]line __oline__ "configure"
#include "confdefs.h"
[$2]
int t() { return 0; }
EOF
if AC_TRY_EVAL(ac_link); then
  ifelse([$3], , :, [
    LIBS="$ac_save_LIBS"
    rm -rf conftest*
    $3])
  ifelse([$4], , , [else
    LIBS="$ac_save_LIBS"
    rm -rf conftest*
    $4
])dnl
fi
rm -f conftest*
]
)

dnl Loosely based on AC_CHECK_LIB in acgeneral.m4 in autoconf distribution

dnl FPTOOLS_CHECK_FLAG_NOWARN(NAME, FLAG, CODE, iftrue, iffalse)

AC_DEFUN(FPTOOLS_CHECK_FLAG_NOWARN,
[AC_MSG_CHECKING([for $1])
 AC_CACHE_VAL(ac_cv_flag_$1,
   [FPTOOLS_TRY_LINK_NOWARN("$2", [main() { $3; exit(0); } ],
     eval "ac_cv_flag_$1=yes",
     eval "ac_cv_flag_$1=no"
   )]
 )
if eval "test \"`echo '$ac_cv_flag_'$1`\" = yes"; then
  AC_MSG_RESULT(yes)
  LIBS="$2 $LIBS"
  $4
else
  AC_MSG_RESULT(no)
  $5
fi
])

dnl FPTOOLS_CHECK_LIB_NOWARN(LIBRARY, FUNCTION)

AC_DEFUN(FPTOOLS_CHECK_LIB_NOWARN,
[FPTOOLS_CHECK_FLAG_NOWARN([function_$2],[],[extern char $2(); $2();],
[changequote(, )dnl
  ac_tr_lib=HAVE_LIB`echo $1 | tr 'abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'`
 changequote([, ])dnl
 AC_DEFINE_UNQUOTED($ac_tr_lib)
],
[FPTOOLS_CHECK_FLAG_NOWARN([library_$1],[-l$1],[extern char $2(); $2();],
[changequote(, )dnl
  ac_tr_lib=HAVE_LIB`echo $1 | tr 'abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'`
 changequote([, ])dnl
 AC_DEFINE_UNQUOTED($ac_tr_lib)
],
[]
)])]
)

dnl check for prototypes
dnl
AC_DEFUN([AC_C_PROTOTYPES],
[AC_CACHE_CHECK([prototypes], ac_cv_prototypes,
[AC_TRY_COMPILE([
void foo(int);
void foo(i)
int i; { 
return;
}
],
[int i;], 
ac_cv_prototypes=yes,
ac_cv_prototypes=no)])
if test "$ac_cv_prototypes" = yes; then
AC_DEFINE([HAVE_PROTOTYPES])
fi
])

dnl ** Check which CATALOG file we have to use with DocBook SGML.
dnl
dnl FPTOOLS_DOCBOOK_CATALOG(VARIABLE, JADE, STYLESHEET, CATALOGS-TO-CHECK-FOR)
dnl
dnl If any of the catalogs given in CATALOGS-TO-CHECK-FOR works on this
dnl platform, let VARIABLE refer to this catalog; otherwise, VARIABLE
dnl is set to "no".  JADE is the jade executable and STYLESHEET
dnl a DocBook style sheet.
dnl
AC_DEFUN(FPTOOLS_DOCBOOK_CATALOG,
[AC_CACHE_CHECK([for DocBook CATALOG], fptools_cv_sgml_catalog,
[
cat > conftest.sgml << EOF
<!DOCTYPE Article PUBLIC "-//OASIS//DTD DocBook V3.1//EN">
<Article>
<ArtHeader>
<Title>Test</Title>
<Author><OtherName>Test</OtherName></Author>
<Address>Test</Address>
<PubDate>Test</PubDate>
</ArtHeader>
<Sect1><Title>Test</Title>
<Para>
Test.
</Para>
</Sect1>
</Article>
EOF
fptools_cv_sgml_catalog=no
for fptools_catalog in $4; do
  ac_try="$2 -t rtf -d $3#print -c $fptools_catalog conftest.sgml"
  if AC_TRY_EVAL(ac_try); then
    fptools_cv_sgml_catalog=[$]fptools_catalog
    break
  fi
done
])
rm -rf conftest*
if test $fptools_cv_sgml_catalog != "no"; then
  $1=$fptools_cv_sgml_catalog
fi
])

dnl ######################################################################
dnl FPTOOLS_SEARCH_LIBS(INCLUDES, FUNCTION, SEARCH-LIBS [, ACTION-IF-FOUND
dnl                     [, ACTION-IF-NOT-FOUND [, OTHER-LIBRARIES]]])
dnl Search for a library defining FUNC, if it's not already available.
dnl This is almost the same as AC_SEARCH_LIBS, but the INCLUDES can be
dnl specified.
dnl ######################################################################

AC_DEFUN(FPTOOLS_SEARCH_LIBS,
[AC_PREREQ([2.13])
AC_CACHE_CHECK([for library containing $2], [ac_cv_search_$2],
[ac_func_search_save_LIBS="$LIBS"
ac_cv_search_$2="no"
AC_TRY_LINK([$1], [$2()], [ac_cv_search_$2="none required"])
test "$ac_cv_search_$2" = "no" && for i in $3; do
LIBS="-l$i $6 $ac_func_search_save_LIBS"
AC_TRY_LINK([$1], [$2()],
[ac_cv_search_$2="-l$i"
break])
done
LIBS="$ac_func_search_save_LIBS"])
if test "$ac_cv_search_$2" != "no"; then
  test "$ac_cv_search_$2" = "none required" || LIBS="$ac_cv_search_$2 $LIBS"
  $4
else :
  $5
fi])

dnl ####################### -*- Mode: M4 -*- ###########################
dnl Copyright (C) 98, 1999 Matthew D. Langston <langston@SLAC.Stanford.EDU>
dnl
dnl This file is free software; you can redistribute it and/or modify it
dnl under the terms of the GNU General Public License as published by
dnl the Free Software Foundation; either version 2 of the License, or
dnl (at your option) any later version.
dnl
dnl This file is distributed in the hope that it will be useful, but
dnl WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
dnl General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License
dnl along with this file; if not, write to:
dnl
dnl   Free Software Foundation, Inc.
dnl   Suite 330
dnl   59 Temple Place
dnl   Boston, MA 02111-1307, USA.
dnl ####################################################################


dnl @synopsis FPTOOLS_CHECK_LIBM
dnl 
dnl Search for math library (typically -lm).
dnl
dnl The variable LIBM (which is not an output variable by default) is
dnl set to a value which is suitable for use in a Makefile (for example,
dnl in make's LOADLIBES macro) provided you AC_SUBST it first.
dnl
dnl @author Matthew D. Langston <langston@SLAC.Stanford.EDU>

# FPTOOLS_CHECK_LIBM - check for math library
AC_DEFUN(FPTOOLS_CHECK_LIBM,
[AC_REQUIRE([AC_CANONICAL_HOST])dnl
LIBM=
case "$host" in
*-*-beos* | *-*-macosx*)
  # These system don't have libm
  ;;
*-ncr-sysv4.3*)
  AC_CHECK_LIB(mw, _mwvalidcheckl, LIBM="-lmw")
  AC_CHECK_LIB(m, main, LIBM="$LIBM -lm")
  ;;
*)
  AC_CHECK_LIB(m, main, LIBM="-lm")
  ;;
esac
])

dnl ######################################################################
dnl NOTE: Because of portability issues between different autoconf
dnl versions the AC_HELP_STRING macro has been removed from FPTOOLS_HAVE_OPENGL.
dnl Furthermore, caching has been completely rewritten.
dnl ######################################################################

dnl ########################### -*- Mode: M4 -*- #######################
dnl Copyright (C) 98, 1999 Matthew D. Langston <langston@SLAC.Stanford.EDU>
dnl
dnl This file is free software; you can redistribute it and/or modify it
dnl under the terms of the GNU General Public License as published by
dnl the Free Software Foundation; either version 2 of the License, or
dnl (at your option) any later version.
dnl
dnl This file is distributed in the hope that it will be useful, but
dnl WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
dnl General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License
dnl along with this file; if not, write to:
dnl
dnl   Free Software Foundation, Inc.
dnl   Suite 330
dnl   59 Temple Place
dnl   Boston, MA 02111-1307, USA.
dnl ####################################################################

dnl @synopsis FPTOOLS_HAVE_OPENGL
dnl 
dnl Search for OpenGL.  We search first for Mesa (a GPL'ed version of
dnl OpenGL) before a vendor's version of OpenGL, unless we were
dnl specifically asked not to with `--with-Mesa=no' or `--without-Mesa'.
dnl
dnl The four "standard" OpenGL libraries are searched for: "-lGL",
dnl "-lGLU", "-lGLX" (or "-lMesaGL", "-lMesaGLU" as the case may be) and
dnl "-lglut".
dnl
dnl All of the libraries that are found (since "-lglut" or "-lGLX" might
dnl be missing) are added to the shell output variable "GL_LIBS", along
dnl with any other libraries that are necessary to successfully link an
dnl OpenGL application (e.g. the X11 libraries).  Care has been taken to
dnl make sure that all of the libraries in "GL_LIBS" are listed in the
dnl proper order.
dnl
dnl Additionally, the shell output variable "GL_CFLAGS" is set to any
dnl flags (e.g. "-I" flags) that are necessary to successfully compile
dnl an OpenGL application.
dnl
dnl The following shell variable (which are not output variables) are
dnl also set to either "yes" or "no" (depending on which libraries were
dnl found) to help you determine exactly what was found.
dnl
dnl   have_GL
dnl   have_GLU
dnl   have_GLX
dnl   have_glut
dnl
dnl A complete little toy "Automake `make distcheck'" package of how to
dnl use this macro is available at:
dnl
dnl   ftp://ftp.slac.stanford.edu/users/langston/autoconf/ac_opengl-0.01.tar.gz
dnl
dnl Please note that as the ac_opengl macro and the toy example evolves,
dnl the version number increases, so you may have to adjust the above
dnl URL accordingly.
dnl
dnl @author Matthew D. Langston <langston@SLAC.Stanford.EDU>

AC_DEFUN(FPTOOLS_HAVE_OPENGL,
[
  AC_REQUIRE([AC_PROG_CC])
  AC_REQUIRE([AC_PATH_X])
  AC_REQUIRE([AC_PATH_XTRA])
  AC_REQUIRE([FPTOOLS_CHECK_LIBM])

dnl Check for Mesa first, unless we were asked not to.
dnl    AC_HELP_STRING([--with-Mesa],
dnl                   [Prefer the Mesa library over a vendors native OpenGL library (default=yes)],
dnl                   with_Mesa_help_string)
dnl    AC_ARG_ENABLE(Mesa, $with_Mesa_help_string, use_Mesa=$enableval, use_Mesa=yes)
  AC_ARG_ENABLE(Mesa, [  --with-Mesa             Prefer the Mesa library over a vendors native OpenGL library (default=yes)], use_Mesa=$enableval, use_Mesa=yes)

  if test x"$use_Mesa" = xyes; then
     GL_search_list="MesaGL  GL  opengl32"
    GLU_search_list="MesaGLU GLU glu32"
    GLX_search_list="MesaGLX GLX"
  else
     GL_search_list="GL  opengl32 MesaGL"
    GLU_search_list="GLU glu32    MesaGLU"
    GLX_search_list="GLX          MesaGLX"
  fi      

  AC_LANG_SAVE
  AC_LANG_C

dnl If we are running under X11 then add in the appropriate libraries.
  if ! test x"$no_x" = xyes; then
dnl Add everything we need to compile and link X programs to GL_CFLAGS
dnl and GL_X_LIBS.
    GL_CFLAGS="$X_CFLAGS"
    GL_X_LIBS="$X_PRE_LIBS $X_LIBS -lX11 -lXext -lXmu -lXt -lXi $X_EXTRA_LIBS $LIBM"
  fi
  GL_save_CPPFLAGS="$CPPFLAGS"
  CPPFLAGS="$GL_CFLAGS"

  GL_save_LIBS="$LIBS"
  LIBS="$GL_X_LIBS"

  FPTOOLS_SEARCH_LIBS([#include <GL/gl.h>],   glEnd,           $GL_search_list,  have_GL=yes,   have_GL=no)
  FPTOOLS_SEARCH_LIBS([#include <GL/glu.h>],  gluNewQuadric,   $GLU_search_list, have_GLU=yes,  have_GLU=no)
  FPTOOLS_SEARCH_LIBS([#include <GL/glx.h>],  glXChooseVisual, $GLX_search_list, have_GLX=yes,  have_GLX=no)
  FPTOOLS_SEARCH_LIBS([#include <GL/glut.h>], glutMainLoop,    glut glut32,      have_glut=yes, have_glut=no)

  if test -n "$LIBS"; then
    GL_LIBS="$LIBS"
  else
    GL_LIBS=
    GL_CFLAGS=
  fi

  AC_CACHE_CHECK([OpenGL flags], mdl_cv_gl_cflags, [mdl_cv_gl_cflags="$GL_CFLAGS"])
  GL_CFLAGS="$mdl_cv_gl_cflags"
  AC_SUBST(GL_CFLAGS)
  AC_CACHE_CHECK([OpenGL libs],  mdl_cv_gl_libs,   [mdl_cv_gl_libs="$GL_LIBS"])
  GL_LIBS="$mdl_cv_gl_libs"
  AC_SUBST(GL_LIBS)

dnl Reset GL_X_LIBS regardless, since it was just a temporary variable
dnl and we don't want to be global namespace polluters.
  GL_X_LIBS=

  LIBS="$GL_save_LIBS"
  CPPFLAGS="$GL_save_CPPFLAGS"

  AC_LANG_RESTORE
])

# LocalWords:  fi

dnl 
dnl acspecific.m4's defn of AC_PROG_LEX is a bit too permissive, as it
dnl defaults to 'lex' if 'flex' isn't found (without checking whether
dnl 'lex' is actually present along the user's PATH).
dnl
AC_DEFUN(AC_PROG_LEX_STRICT,
[AC_CHECK_PROG(LEX, flex, flex)
if test -z "$LEX"
then
  AC_CHECK_PROG(LEX,lex,lex)
  test -z "$LEX" && AC_MSG_ERROR(['lex' or 'flex' is required to compile GHC.])
fi
])

dnl
dnl Check to see whether CC (gcc) supports a particular option.
dnl 
AC_DEFUN(FPTOOLS_CC_FLAG,
[
AC_CACHE_CHECK([whether $CC accepts $1], [ac_cv_cc_$2],
[save_CFLAGS="$CFLAGS"
 CFLAGS="$CFLAGS $1"
 AC_LANG_C
 AC_TRY_COMPILE(,[int main(){return(0);}],
                 [ac_cv_cc_$2=yes],
		 [ac_cv_cc_$2=no])
 CFLAGS="$save_CFLAGS"
])
if test "$ac_cv_cc_$2"x = "yesx"; then
  $2=$1;
else
  $2="";
fi;
])
