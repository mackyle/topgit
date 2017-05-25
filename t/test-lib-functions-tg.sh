# test-lib-functions-tg.sh - test library functions specific to TopGit
# Copyright (C) 2017 Kyle J. McKay
# All rights reserved
# License GPL2

# The test library itself is expected to set and export TG_TEST_FULL_PATH as
# the full path to the current "tg" executable being tested
#
# IMPORTANT: test-lib-functions-tg.sh MUST NOT EXECUTE ANY CODE!
#
# Also since this file is sourced BEFORE test-lib-functions.sh it may not
# override any functions in there either
#
# The function test_lib_functions_tg_init, which should ALWAYS be kept as
# the very LAST function in this file, will be called once (AFTER
# test-lib-functions.sh has been sourced and inited) but before any other
# functions in it are called


##
## TopGit specific test functions
##


# tg_test_include [-C <dir>] [-r <remote>] [-u] [-f]
#
# Source tg in "tg__include=1" mode to provide access to internal functions
# Since this bypasses normal tg options parsing provide a few options
#
# While -C <dir> options are indeed parsed and acted upon and the "include"
# itself will occur with the result of any -C <dir> options still active,
# the directory will be changed back to the saved "$PWD" (saved at the
# beginning of this function) immediately after the "include" takes place.
# As a result, if any -C <dir> options are used it may subsequently be
# necessary to do an explicit cd <dir> later on before calling any of the
# internal tg functions.
#
# This function, obviously, causes the "tg" file to be sourced at the current
# shell level so there's no "tg_uninclude" possible, but since the various
# test_expect/tolerate functions run the test code itself in a subshell by
# default, use of tg_test_include from within a test body will be effectively
# local for that specific test body and be "undone" after it's finished.
#
# Note that the special "tg__include" variable IS left set to "1" after this
# function returns (but it is NOT exported) and all temporary variables used by
# this function are unset
#
# Return status will be "0" on success or last failing status (which will be
# from the include itself if that's the last thing to fail)
#
# However, if the "-f" option is passed any failure is immediately fatal
#
# Since the test library always sets TG_TEST_FULL_PATH it's a fatal error to
# call this function when that's unset or invalid (not a readable file)
#
# Note that the "-u" option causes the base_remote variable to always be unset
# immediately after the include while the "-r <remote>" option causes
# the base_remote variable to be set before the include; if neither option is
# used and the caller has set base_remote, it will end up as the remote since
# the "tg" command will keep it; however, if the base_remote variable is either
# unset or empty and the "-u" option is not used when this function is called
# then any base_remote setting that "tg" itself picks up will be kept
#
tg_test_include() {
	[ -f "$TG_TEST_FULL_PATH" ] && [ -r "$TG_TEST_FULL_PATH" ] ||
		fatal "tg_test_include called while TG_TEST_FULL_PATH is unset or invalid"
	unset _tgf_noremote _tgf_fatal _tgf_curdir _tgf_errcode
	_tgf_curdir="$PWD"
	while [ $# -gt 0 ]; do case "$1" in
		-h|--help)
			unset _tgf_noremote _tgf_fatal _tgf_curdir
			echo "tg_test_include [-C <dir>] [-r <remote>] [-u]"
			return 0
			;;
		-C)
			shift
			[ -n "$1" ] || fatal "tg_test_include option -C requires an argument"
			cd "$1" || return 1
			;;
		-u)
			_tgf_noremote=1
			;;
		-r)
			shift
			[ -n "$1" ] || fatal "tg_test_include option -r requires an argument"
			base_remote="$1"
			unset _tgf_noremote
			;;
		-f)
			_tgf_fatal=1
			;;
		--)
			shift
			break
			;;
		-?*)
			echo "tg_test_include: unknown option: $1" >&2
			usage 1
			;;
		*)
			break
			;;
	esac; shift; done
	[ $# -eq 0 ] || fatal "tg_test_include non-option arguments prohibited: $*"
	unset tg__include # make sure it's not exported
	tg__include=1
	# MUST do this AFTER changing the current directory since it sets $git_dir!
	_tgf_errcode=0
	. "$TG_TEST_FULL_PATH" || _tgf_errcode=$?
	[ -z "$_tgf_noremote" ] || base_remote=
	cd "$_tgf_curdir" || _fatal "tg_test_include post-include cd failed to: $_tgf_curdir"
	set -- "$_tgf_errcode" "$_tgf_fatal"
	unset _tgf_noremote _tgf_fatal _tgf_curdir _tgf_errcode
	[ -z "$2" ] || [ "$1" = "0" ] || _fatal "tg_test_include sourcing of tg failed with status $1"
	return $1
}


##
## TopGit specific test functions "init" function
##


#
# THIS SHOULD ALWAYS BE THE LAST FUNCTION DEFINED IN THIS FILE
#
# Any client that sources this file should immediately call this function
# afterwards
#
# THERE SHOULD NOT BE ANY DIRECTLY EXECUTED LINES OF CODE IN THIS FILE
#
test_lib_functions_tg_init() {
	# Nothing to do here yet, but a function must have at least one command
	:
}
