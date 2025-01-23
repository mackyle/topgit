# Makefile.sh - POSIX Makefile scripting adjunct for TopGit tests
# Copyright (C) 2017,2025 Kyle J. McKay
# All rights reserved
# License GPL2

# Set MAKEFILESH_DEBUG to get:
#  1. All defined environment variales saved to Makefile.var
#  2. set -x
#  3. set -v if MAKEFILESH_DEBUG contains "v"

MKTOP=..
. "$MKTOP/Makefile.sh" # top-level defines

# prevent crazy "sh" implementations from exporting functions into environment
set +a

# wrap it up for safe returns
# "$@" is the current build target(s), if any
makefile() {

# config.sh is wrapped up for return safety
configsh

# config.sh may not unset these
: "${SHELL_PATH:=/bin/sh}" "${DIFF:=diff}" "${PROVE:=prove}"
: "${TESTLIB_TEST_LINT=test-lint}"
TEST_RESULTS_DIRECTORY="${TEST_OUTPUT_DIRECTORY:+$TEST_OUTPUT_DIRECTORY/}test-results"

quotevar SHELL_PATH SHELL_PATH_SQ
quotevar PERL_PATH PERL_PATH_SQ
quotevar GIT_PATH GIT_PATH_SQ
quotevar TEST_RESULTS_DIRECTORY TEST_RESULTS_DIRECTORY_SQ

# Default list of tests is all t????-*.sh files

v_wildcard ALLT 't[0-9][0-9][0-9][0-9]-*.sh'
v_sort ALLT $ALLT
if [ -n "$T" ]; then
	expand_T_() { T="$*"; }
	expand_T_ $T
else
	T="$ALLT"
fi
export T
[ -n "$LINTTESTS" ] || LINTTESTS="$T"

# Extra shell scripts to run through check-non-portable-shell.pl
# These will ALWAYS be "checked" whenever the test-lint target is made
# By default all $(T) test files are checked so they don't need to be
# in this list

v_wildcard LINTSCRIPTS '*.sh'
v_filter_out LINTSCRIPTS "$ALLT" $LINTSCRIPTS
v_sort LINTSCRIPTS $LINTSCRIPTS

if [ -z "$TESTLIB_NO_CACHE" ]; then
	CACHE_SETUP='TESTLIB_CACHE="$$($(SHELL_PATH_SQ) ./test-lib.sh --cache $(TESTLIB_TEST_OPTS) 2>/dev/null || :)"'
	CACHE_SETUP_TTY='! test -t 1 || { TESTLIB_FORCETTY=1 && export TESTLIB_FORCETTY; }; $(CACHE_SETUP)'
fi

if [ -n "$TESTLIB_NO_CLEAN" ]; then
	NOCLEANCMT='#'
fi

[ -z "$MAKEFILESH_DEBUG" ] || {
	printenv | LC_ALL=C grep '^[_A-Za-z][_A-Za-z0-9]*=' | LC_ALL=C sort
} >"Makefile.var"

# Force TG-TEST-SETTINGS to be updated now if needed
${MAKE:-make} ${GNO_PD_OPT} -e -f Makefile.mak FORCE_SETTINGS_BUILD=FORCE TG-TEST-SETTINGS

# end of wrapper
}

. "$MKTOP/gnomake.sh" &&
set_gno_pd_opt &&
makefile "$@"
