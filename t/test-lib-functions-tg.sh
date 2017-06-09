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
	unset_ _tgf_noremote _tgf_fatal _tgf_curdir _tgf_errcode
	_tgf_curdir="$PWD"
	while [ $# -gt 0 ]; do case "$1" in
		-h|--help)
			unset_ _tgf_noremote _tgf_fatal _tgf_curdir
			echo "tg_test_include [-C <dir>] [-r <remote>] [-u] [-f]"
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
			unset_ _tgf_noremote
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
	unset_ tg__include # make sure it's not exported
	tg__include=1
	# MUST do this AFTER changing the current directory since it sets $git_dir!
	_tgf_errcode=0
	. "$TG_TEST_FULL_PATH" || _tgf_errcode=$?
	[ -z "$_tgf_noremote" ] || base_remote=
	cd "$_tgf_curdir" || _fatal "tg_test_include post-include cd failed to: $_tgf_curdir"
	set -- "$_tgf_errcode" "$_tgf_fatal"
	unset_ _tgf_noremote _tgf_fatal _tgf_curdir _tgf_errcode
	[ -z "$2" ] || [ "$1" = "0" ] || _fatal "tg_test_include sourcing of tg failed with status $1"
	return $1
}


# tg_test_setup_topgit [-C <dir>] [-f]
#
tg_test_setup_topgit() {
	[ -f "$TG_TEST_FULL_PATH" ] && [ -r "$TG_TEST_FULL_PATH" ] ||
		fatal "tg_test_setup_topgit called while TG_TEST_FULL_PATH is unset or invalid"
	unset_ _tgf_fatal _tgf_curdir _tgf_td
	_tgf_curdir="$PWD"
	while [ $# -gt 0 ]; do case "$1" in
		-h|--help)
			unset_ _tgf_fatal _tgf_curdir
			echo "tg_test_setup_topgit [-C <dir>] [-f]"
			return 0
			;;
		-C)
			shift
			[ -n "$1" ] || fatal "tg_test_include option -C requires an argument"
			cd "$1" || return 1
			;;
		-f)
			_tgf_fatal=1
			;;
		--)
			shift
			break
			;;
		-?*)
			echo "tg_test_setup_topgit: unknown option: $1" >&2
			usage 1
			;;
		*)
			break
			;;
	esac; shift; done
	[ $# -eq 0 ] || fatal "tg_test_setup_topgit non-option arguments prohibited: $*"
	_tgf_td="$(test_get_temp -d setup)" || failt "tg_test_setup_topgit test_get_temp failed"
	_tgf_td_script="$_tgf_td/${TG_TEST_FULL_PATH##*/}"
	write_script "$_tgf_td_script" <<-'KLUDGE'
		# without this $0 will be wrong and the installed hook will never run
		tg__include=1 &&
		PATH="${TG_TEST_FULL_PATH%/*}:$PATH" && export PATH &&
		. "$TG_TEST_FULL_PATH" &&
		setup_ours &&
		setup_hook "pre-commit"
	KLUDGE
	_tgf_errcode=0
	TG_TEST_FULL_PATH="$TG_TEST_FULL_PATH" "$_tgf_td_script" || _tgf_errcode=$?
	cd "$_tgf_curdir" || _fatal "tg_test_setup_topgit post-setup cd failed to: $_tgf_curdir"
	set -- "$_tgf_errcode" "$_tgf_fatal"
	rm -rf "$_tgf_td"
	unset_ _tgf_fatal _tgf_curdir _tgf_errcode _tgf_td _tgf_td_script
	[ -z "$2" ] || [ "$1" = "0" ] || _fatal "tg_test_setup_topgit failed with status $1"
	return $1
}


# tg_test_v_getbases <varname> [<remotename>]
#
# If tg_test_bases is unset the default for this release of TopGit is used.
# Otherwise the it must be set to "refs" or "heads" or a fatal error occurs.
#
# The variable named by <varname> is set to the full ref prefix for top-bases
# (as selected by tg_test_bases).  If <remotename> is non-empty it will be the
# prefix for top-bases under that remote's ref namespace.
#
# Example return values:
#
#   tg_test_v_getbases x        # x='refs/top-bases'                  # "refs"
#   tg_test_v_getbases x        # x='refs/heads/{top-bases}'          # "heads"
#   tg_test_v_getbases x origin # x='refs/remotes/origin/top-bases'   # "refs"
#   tg_test_v_getbases x origin # x='refs/remotes/origin/{top-bases}' # "heads"
#
tg_test_v_getbases() {
	[ -n "$1" ] || fatal "tg_test_v_getbases called without varname argument"
	[ $# -le 2 ] || fatal "tg_test_v_getbases called with more than two arguments"
	case "${tg_test_bases:-refs}" in
		"refs")  _tgbases="top-bases";;
		"heads") _tgbases="heads/{top-bases}";;
		*) fatal "tg_test_v_getbases called with invalid tg_test_bases setting \"$tg_test_bases\"";;
	esac
	if [ -n "$2" ]; then
		set -- "$1" "refs/remotes/$2/${_tgbases#heads/}"
	else
		set -- "$1" "refs/$_tgbases"
	fi
	unset_ _tgbases
	eval "$1"'="$2"'
}


# tg_test_v_getremote <varname> [<remotename>]
#
# Set the variable named by <varname> to <remotename> unless <remotename> is
# omitted or empty in which case use the value of tg_test_remote unless it's
# empty in which case fail with a fatal error.
#
tg_test_v_getremote() {
	[ -n "$1" ] || fatal "tg_test_getremote called without varname argument"
	[ $# -le 2 ] || fatal "tg_test_getremote called with more than two arguments"
	[ -n "${2:-$tg_test_remote}" ] ||
		fatal "tg_test_getremote called with no remote name argument and \$tg_test_remote not set"
	eval "$1"'="${2:-$tg_test_remote}"'
}


# tg_test_bare_tree [-C <dir>] <treeish>
#
# Output the hash of the tree that's equivalent to <treeish>'s tree with any
# .topdeps and .topmsg files removed,  If <treeish> does not have any top-level
# .topdeps or .topmsg files then the result will be the same as <treeish>^{tree}
tg_test_bare_tree() {
	_tct_dir="."
	[ $# -lt 2 ] || [ "$1" != "-C" ] || { shift; _tct_dir="${1:-.}"; shift; }
	[ -d "$_tct_dir" ] ||
		fatal "tg_test_bare_tree no such directory \"$_tct_dir\""
	[ $# -eq 1 ] && [ -n "$1" ] ||
		fatal "tg_test_bare_tree missing treeish argument"
	set -- "$_tct_dir" "$1"
	unset_ _tct_dir
	git -C "$1" ls-tree --full-tree "$2^{tree}" |
	# The first character after the '/' in the sed pattern is a literal tab
	sed -e '/	\.topdeps$/d' -e '/	\.topmsg$/d' |
	git -C "$1" mktree
}


# tg_test_create_branch [-C <dir>] [--notick] [+][\][[<remote>]:[:]]<branch> [-m "message"] [:[:[:]]]<start> [<dep>...]
#
# Create a new TopGit branch named <branch> in the current repository (or
# <dir> if given).
#
# Unless --notick is used the test_tick function will be called just prior to
# the creation of each new commit.
#
# All of the new ref names to be created must be non-existent unless the "+"
# prefix is used and then they're just overwritten if they exist.  A leading
# "\" will be stripped so branch names starting with "+" can be used without
# needing to use the overwrite option.
#
# tg_test_v_getbases is used so tg_test_bases must be unset or "refs" or "heads".
#
# If [-m "message"] is omitted the message will be "branch <branch>" and
# the same with "[PATCH] " prepended for .topmsg (unless it's a bare branch).
# A "[PATCH] " value will be prepended to any -m value when creating the
# .topmsg file unless "message" starts with a "[" character.
#
# The branch will start from <start> which must be the name of a ref located
# under refs/heads i.e. refs/heads/<start>.  <start> will become the first
# dependency in the .topdeps file.  Any additional <dep> names must also be
# Git branch names and will be listed in the order given as additional lines
# in the .topdeps file.
#
# If <start> begins with one ":" it may be any committish AND it will be
# omitted from the .topdeps file so the .topdeps file will then be empty
# unless at least one [<dep>...] is given.
#
# If <start> begins with two colons "::" it may be any committish, but
# [<dep>...] MUST BE OMITTED and the created TopGit branch will be bare
# (i.e. it will have neither a .topmsg nor a .topdeps file at all).
#
# If <start> begins with three colons ":::" it may be any committish, but
# [<dep>...] MUST BE OMITTED and the created branch will not have any
# corresponding base(s) and will be bare (i.e. it will be a non-TopGit branch)
# and will have a single file added in the style of the test_commit function
# where the tag will be omitted if the message contains whitespace or any other
# invalid ref name characters.
#
# Additionally if <start> begins with a colon (or two or three) it may be the
# empty string to start from a new empty tree root commit.
#
# If <remote>:<branch> is used a remote TopGit branch will be created instead
# in which case the :<start> form may be most useful as it can be used to
# specify a starting point not under refs/heads.
#
# If <remote>::<branch> is used then both a local and remote branch will be
# created (both with the same branch and base values).
#
# If <remote> is empty (but the trailing colon is still present) the value of
# the tg_test_remote variable will be used for the remote name (in which case
# if tg_test_remote is empty a fatal error will occur).
#
# The current working tree, index and symolic-ref setting of HEAD are left
# completely untouched by this function although if HEAD is a symbolic ref to
# <branch> and <branch> is unborn, it WILL be created by this function which
# will impact Git's view of the working tree and index in that case.
#
# Note that NO CHECKING is done on the <dep> values whatsoever!  They're just
# dumped into the .topdeps file as-is if given.
#
tg_test_create_branch() {
	_tcb_dir="."
	[ $# -lt 2 ] || [ "$1" != "-C" ] || { shift; _tcb_dir="${1:-.}"; shift; }
	[ -d "$_tcb_dir" ] ||
		fatal "tg_test_create_branch: no such directory \"$_tcb_dir\""
	_tcb_nto=
	[ "$1" != "--notick" ] || { _tcb_nto="$1"; shift; }
	[ $# -ge 1 ] && [ -n "$1" ] ||
		fatal "tg_test_create_branch: missing <branch> name to create"
	_tcb_new="$1"
	shift
	_tcb_bases=
	_tcb_rmt=
	_tcb_rmtonly=
	_tcb_rmtbases=
	_tcb_nooverwrite=1
	case "$_tcb_new" in "+"*)
		_tcb_new="${_tcb_new#?}"
		_tcb_nooverwrite=
	esac
	case "$_tcb_new" in "\\"*) _tcb_new="${_tcb_new#?}"; esac
	case "$_tcb_new" in
		*::*)
			_tcb_rmt="${_tcb_new%%::*}"
			tg_test_v_getremote _tcb_rmt "$_tcb_rmt"
			_tcb_new="${_tcb_new#*::}"
			;;
		*:*)
			_tcb_rmt="${_tcb_new%%:*}"
			tg_test_v_getremote _tcb_rmt "$_tcb_rmt"
			_tcb_new="${_tcb_new#*:}"
			_tcb_rmtonly=1
			;;
	esac
	[ -n "$_tcb_new" ] || 
		fatal "tg_test_create_branch: invalid empty <branch> name"
	[ -n "$_tcb_rmtonly" ] || tg_test_v_getbases _tcb_bases
	[ -z "$_tcb_rmt" ] || tg_test_v_getbases _tcb_rmtbases "$_tcb_rmt"
	_tcb_msg=
	[ $# -lt 2 ] || [ "$1" != "-m" ] || { shift; _tcb_msg="$1"; shift; }
	[ -n "$_tcb_msg" ] || _tcb_msg="branch $_tcb_new"
	[ $# -ge 1 ] && [ -n "$1" ] ||
		fatal "tg_test_create_branch: missing <start> point argument"
	_tcb_start="$1"
	shift
	_tcb_bare=
	_tcb_plain=
	_tcb_sdep="$_tcb_start"
	_tcb_vref="refs/heads/$_tcb_start"
	case "$_tcb_start" in
		:::*)
			_tcb_sdep=
			_tcb_vref="${_tcb_start#:::}"
			_tcb_bare=1
			_tcb_plain=1
			;;
		::*)
			_tcb_sdep=
			_tcb_vref="${_tcb_start#::}"
			_tcb_bare=1
			;;
		:*)
			_tcb_sdep=
			_tcb_vref="${_tcb_start#:}"
			;;
	esac
	if [ -z "$_tcb_sdep$_tcb_vref$_tcb_plain" ]; then
		_tcb_btr="$(git -C "$_tcb_dir" mktree </dev/null)" ||
			fatal "tg_test_create_branch: git mktree failed making empty tree"
		[ -n "$_tcb_nto" ] || test_tick
		_tcb_vref="$(git -C "$_tcb_dir" commit-tree </dev/null \
		  -m "tg_test_create_branch $_tcb_new root" "$_tcb_btr")" && [ -n "$_tcb_vref" ] ||
			fatal "tg_test_create_branch: git commit-tree failed committing new root"
	fi
	_tcb_scmt=
	if [ -n "$_tcb_vref" ]; then
		_tcb_scmt="$(git -C "$_tcb_dir" rev-parse --quiet --verify "$_tcb_vref^0" --)" && [ -n "$_tcb_scmt" ] ||
			fatal "tg_test_create_branch: invalid starting point \"$_tcb_vref\""
	fi
	[ $# -eq 0 ] || [ -z "$_tcb_bare" ] ||
		fatal "tg_test_create_branch: no <dep> arguments allowed for bare branch"
	if [ -n "$_tcb_nooverwrite" ]; then
		{
		    [ -n "$_tcb_rmtonly" ] ||
		    printf '%s\n' "verify refs/heads/$_tcb_new" "verify $_tcb_bases/$_tcb_new"
		    [ -z "$_tcb_rmt" ] ||
		    printf '%s\n' "verify refs/remotes/$_tcb_rmt/$_tcb_new" "verify $_tcb_rmtbases/$_tcb_new"
		} | git -C "$_tcb_dir" update-ref --stdin ||
			fatal "tg_test_create_branch: branch \"$_tcb_new\" already exists"
	fi
	if [ -z "$_tcb_plain" ]; then
		_tcb_btr="$(tg_test_bare_tree -C "$_tcb_dir" "$_tcb_scmt")" && [ -n "$_tcb_btr" ] ||
			fatal "tg_test_create_branch: tg_test_bare_tree failed on \"$_tcb_scmt\" ($_tcb_vref^0)"
		if [ "$_tcb_btr" != "$(git -C "$_tcb_dir" rev-parse --quiet --verify "$_tcb_scmt^{tree}" --)" ]; then
			[ -n "$_tcb_nto" ] || test_tick
			_tcb_scmt="$(git -C "$_tcb_dir" commit-tree </dev/null -p "$_tcb_scmt" \
			  -m "tg_test_create_branch $_tcb_new base" "$_tcb_btr")" && [ -n "$_tcb_scmt" ] ||
				fatal "tg_test_create_branch: git commit-tree failed"
		fi
	fi
	_tcb_hcmt="$_tcb_scmt"
	if [ -z "$_tcb_bare" ]; then
		[ -z "$_tcb_sdep" ] || set -- "$_tcb_sdep" "$@"
		_tcb_fmt=
		[ $# -eq 0 ] || _tcb_fmt='%s\n'
		_tcb_dps="$(printf "$_tcb_fmt" "$@" | git -C "$_tcb_dir" hash-object -t blob -w --stdin)" && [ -n "$_tcb_dps" ] ||
			fatal "tg_test_create_branch: git hash-object failed creating .topdeps blob"
		case "$_tcb_msg" in
			"["*) _tcb_sbj="Subject: $_tcb_msg";;
			*) _tcb_sbj="Subject: [PATCH] $_tcb_msg";;
		esac
		_tcb_tms="$(printf '%s\n' "From: $GIT_AUTHOR_NAME <$GIT_AUTHOR_EMAIL>" "$_tcb_sbj" |
		  git -C "$_tcb_dir" hash-object -t blob -w --stdin)" && [ -n "$_tcb_tms" ] ||
			fatal "tg_test_create_branch: git hash-object failed creating .topmsg blob"
		_tcb_htr="$({
			git -C "$_tcb_dir" ls-tree --full-tree "$_tcb_hcmt^{tree}" &&
			printf '100644 blob %s\011.topdeps\n100644 blob %s\011.topmsg\n' "$_tcb_dps" "$_tcb_tms"
		  } | git -C "$_tcb_dir" mktree)" && [ -n "$_tcb_htr" ] ||
			fatal "tg_test_create_branch: git mktree failed creating new branch \"$_tcb_new\" tree"
		[ -n "$_tcb_nto" ] || test_tick
		_tcb_hcmt="$(git -C "$_tcb_dir" commit-tree </dev/null -p "$_tcb_hcmt" -m "$_tcb_msg" "$_tcb_htr")" && [ -n "$_tcb_hcmt" ] ||
			fatal "tg_test_create_branch: git commit-tree failed"
	elif [ -n "$_tcb_plain" ]; then
		read -r _tcb_fnm <<-EOT
			$_tcb_msg
		EOT
		_tcb_blb="$(printf '%s\n' "$_tcb_msg" | git -C "$_tcb_dir" hash-object -t blob -w --stdin)" && [ -n "$_tcb_blb" ] ||
			fatal "tg_test_create_branch: git hash-object failed creating file \"$_tcb_fnm.t\" blob"
		_tcb_htr="$({
			[ -z "$_tcb_hcmt" ] || git -C "$_tcb_dir" ls-tree --full-tree "$_tcb_hcmt^{tree}"
			printf '100644 blob %s\011%s\n' "$_tcb_blb" "$_tcb_fnm.t"
		  } | git -C "$_tcb_dir" mktree)" && [ -n "$_tcb_htr" ] ||
			fatal "tg_test_create_branch: git mktree failed creating new plain branch \"$_tcb_new\" tree"
		[ -n "$_tcb_nto" ] || test_tick
		_tcb_hcmt="$(git -C "$_tcb_dir" commit-tree </dev/null ${_tcb_hcmt:+-p} $_tcb_hcmt -m "$_tcb_msg" "$_tcb_htr")" && [ -n "$_tcb_hcmt" ] ||
			fatal "tg_test_create_branch: git commit-tree failed"
		! test_check_one_tag_ $_tcb_msg || git -C "$_tcb_dir" tag $_tcb_msg "$_tcb_hcmt"
	fi
	set -- "$_tcb_dir" "$_tcb_new" "$_tcb_overwrite"
	if [ -n "$_tcb_rmt" ]; then
		[ -n "$_tcb_plain" ] || set -- "$@" "$_tcb_rmtbases/$_tcb_new" "$_tcb_scmt"
		set -- "$@" "refs/remotes/$_tcb_rmt/$_tcb_new" "$_tcb_hcmt"
	fi
	if [ -z "$_tcb_rmtonly" ]; then
		[ -n "$_tcb_plain" ] || set -- "$@" "$_tcb_bases/$_tcb_new" "$_tcb_scmt"
		set -- "$@" "refs/heads/$_tcb_new" "$_tcb_hcmt"
	fi
	unset_ _tcb_dir _tcb_nto _tcb_new _tcb_bases _tcb_rmt _tcb_rmtonly _tcb_rmtbases _tcb_msg \
	  _tcb_start _tcb_bare _tcb_sdep _tcb_vref _tcb_scmt _tcb_btr _tcb_hcmt _tcb_fmt _tcb_dps \
	  _tcb_tms _tcb_htr _tcb_nooverwrite || :
	(_ovwno="${3:+ }" && shift 3 && printf "update %s %s$_ovwno"'\n' "$@") | git -C "$1" update-ref --stdin ||
		fatal "tg_test_create_branch: update-ref for branch \"$2\" failed"
}


# tg_test_create_branches [-C <dirpath>] [--notick]
#
# Read `tg_branch_create` instructions from standard input and then call
# tg_create_branch for each set of instructions.
#
# Standard input must be a sequence of line groups each consisting of two or
# more non-empty lines where the groups are separated by a single blank line.
# Each line group must have this form:
#
#   [+][\][[<remote>]:[:]]<branch> [optional] [message] [goes] [here]
#   [[delete]:[:[:]]]<start>
#   [<dep>]
#   [<dep>]
#   ...
#
# Note that any <dep> lines must not be empty.  If there are no <dep>s, then
# there must be no <dep> lines at all.
#
# See the description of tg_test_create_branch for the meaning of the
# arguments.  The provided <dirpath> and --notick options are passed along
# on each call to the tg_test_create_branch function.
#
# Interpretation of "delete:" lines is handled here.  No message or deps
# are allowed.  If <start> is non-empty, all refs (1, 2 or 4) to be deleted
# must have that value.  If the "+" is NOT present and <start> is empty, all
# refs to be deleted MUST actually exist.
#
# Since each line group represents a call to tg_test_create_branch, later
# groups may use any branch name created by an earlier group as a <start>
# point without problem.
#
tg_test_create_branches() {
	_tcbs_dir="."
	[ $# -lt 2 ] || [ "$1" != "-C" ] || { shift; _tcbs_dir="${1:-.}"; shift; }
	[ -d "$_tcbs_dir" ] ||
		fatal "tg_test_create_branches: no such directory \"$_tcbs_dir\""
	_tcbs_nto=
	[ "$1" != "--notick" ] || { _tcbs_nto="$1"; shift; }
	[ $# -eq 0 ] ||
		fatal "tg_test_create_branches: invalid extra arguments: $*"
	_tcbs_bname=
	_tcbs_bmsg=
	_tcbs_bstrt=
	_tcbs_lno=1
	_tcbs_dep=
	_tcbs_glno="$_tcbs_lno"
	_tcbs_tick=
	[ -n "$_tcbs_nto" ] || _tcbs_tick="$(test_get_temp test_tick)"
	while read -r _tcbs_bname _tcbs_bmsg && [ -n "$_tcbs_bname" ]; do
		_tcbs_lno="$(( $_tcbs_lno + 1 ))"
		read -r _tcbs_strt && [ -n "$_tcbs_strt" ] ||
			fatal "tg_test_create_branches: missing <start> at stdin line $_tcbs_lno"
		_tcbs_lno="$(( $_tcbs_lno + 1 ))"
		set -- "-C" "$_tcbs_dir" $_tcbs_nto "$_tcbs_bname" "-m" "$_tcbs_bmsg" "$_tcbs_strt"
		_tcbs_nod=1
		while read -r _tcbs_dep && [ -n "$_tcbs_dep" ]; do
			_tcbs_lno="$(( $_tcbs_lno + 1 ))"
			set -- "$@" "$_tcbs_dep"
			_tcbs_nod=
		done
		_tcbs_lno="$(( $_tcbs_lno + 1 ))"
		case "$_tcbs_strt" in
		"delete:"*)
			[ -z "$_tcbs_bmsg" ] ||
				fatal "tg_test_create_branches: \"delete:...\" usage prohibits msg at stdin line $_tcbs_glno"
			[ -n "$_tcbs_nod" ] ||
				fatal "tg_test_create_branches: \"delete:...\" usage prohibits deps at stdin line $_tcbs_glno"
			_tcbs_rbs=
			case "$_tcbs_strt" in
			"delete:::"*)
				_tcbs_strt="${_tcbs_strt#delete:::}"
				;;
			"delete::"*)
				_tcbs_strt="${_tcbs_strt#delete::}"
				_tcbs_rbs=1
				;;
			"delete:"*)
				_tcbs_strt="${_tcbs_strt#delete:}"
				_tcbs_rbs=1
				;;
			esac
			_tcbs_bases=
			_tcbs_rmt=
			_tcbs_rmtonly=
			_tcbs_rmtbases=
			_tcbs_mustexist=1
			case "$_tcbs_bname" in "+"*)
				_tcbs_bname="${_tcbs_bname#?}"
				_tcbs_mustexist=
			esac
			case "$_tcbs_bname" in "\\"*) _tcbs_bname="${_tcbs_bname#?}"; esac
			case "$_tcbs_bname" in
				*::*)
					_tcbs_rmt="${_tcbs_bname%%::*}"
					tg_test_v_getremote _tcbs_rmt "$_tcbs_rmt"
					_tcbs_bname="${_tcbs_bname#*::}"
					;;
				*:*)
					_tcbs_rmt="${_tcbs_bname%%:*}"
					tg_test_v_getremote _tcbs_rmt "$_tcbs_rmt"
					_tcbs_bname="${_tcbs_bname#*:}"
					_tcbs_rmtonly=1
					;;
			esac
			[ -n "$_tcbs_bname" ] ||
				fatal "tg_test_create_branches: invalid empty delete: <branch> name"
			if [ -n "$_tcbs_rbs" ]; then
				[ -n "$_tcbs_rmtonly" ] || tg_test_v_getbases _tcbs_bases
				[ -z "$_tcbs_rmt" ] || tg_test_v_getbases _tcbs_rmtbases "$_tcbs_rmt"
			fi
			set --
			_tcbs_fmt='delete %s %s\n'
			[ -n "$_tcbs_strt" ] || [ -n "$_tcbs_mustexist" ] || _tcbs_fmt='delete %s\n'
			if [ -n "$_tcbs_rmt" ]; then
				if [ -n "$_tcbs_rbs" ]; then
					set -- "$@" "$_tcbs_rmtbases/$_tcb_bname"
					[ -z "$_tcbs_strt" ] && [ -z "$_tcbs_mustexist" ] ||
					set -- "$@" "${_tcbs_strt:-$_tcbs_rmtbases/$_tcb_bname}"
				fi
				set -- "$@" "refs/remotes/$_tcbs_rmt/$_tcbs_bname"
				[ -z "$_tcbs_strt" ] && [ -z "$_tcbs_mustexist" ] ||
				set -- "$@" "${_tcbs_strt:-refs/remotes/$_tcbs_rmt/$_tcbs_bname}"
			fi
			if [ -z "$_tcbs_rmtonly" ]; then
				if [ -n "$_tcbs_rbs" ]; then
					set -- "$@" "$_tcbs_bases/$_tcbs_bname"
					[ -z "$_tcbs_strt" ] && [ -z "$_tcbs_mustexist" ] ||
					set -- "$@" "${_tcbs_strt:-$_tcbs_bases/$_tcbs_bname}"
				fi
				set -- "$@" "refs/heads/$_tcbs_bname"
				[ -z "$_tcbs_strt" ] && [ -z "$_tcbs_mustexist" ] ||
				set -- "$@" "${_tcbs_strt:-refs/heads/$_tcbs_bname}"
			fi
			printf "$_tcbs_fmt" "$@" | git -C "$_tcbs_dir" update-ref --stdin ||
				fatal "tg_test_create_branches: failed deleting branch \"$_tcbs_bname\" group at stdin line $_tcbs_glno"
			;;
		*)
			(tg_test_create_branch "$@" && { [ -z "$_tcbs_tick" ] || echo "$test_tick" >"$_tcbs_tick"; } ) ||
				fatal "tg_test_create_branches: failed creating branch \"$_tcbs_bname\" group at stdin line $_tcbs_glno"
			[ -z "$_tcbs_tick" ] || { read -r test_tick <"$_tcbs_tick" || :; rm "$_tcbs_tick"; }
			;;
		esac
		_tcbs_glno="$_tcbs_lno"
	done
	[ -z "$_tcbs_tick" ] || ! [ -e "$_tcbs_tick" ] || rm "$_tcbs_tick"
	unset_ _tcbs_dir _tcbs_nto _tcbs_name _tcbs_bmsg _tcbs_bstrt _tcbs_lno \
		_tcbs_dep _tcbs_glno _tcbs_tick _tcbs_nod _tcbs_rbs _tcbs_fmt \
		_tcbs_bases _tcbs_rmt _tcbs_rmtonly _tcbs_rmtbases _tcbs_mustexist || :
	return 0
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
