# Test function library from Git with modifications.
#
# Modifications Copyright (C) 2016,2017,2021 Kyle J. McKay
# All rights reserved
# Modifications made:
#
#  * Many "GIT_..." variables removed -- some were kept as TESTLIB_..." instead
#    (Except "GIT_PATH" is new and is the full path to a "git" executable)
#
#  * IMPORTANT: test-lib-functions.sh SHOULD NOT EXECUTE ANY CODE!  A new
#    function "test_lib_functions_init" has been added that will be called
#    and MUST contain any lines of code to be executed.  This will ALWAYS
#    be the LAST function defined in this file for easy locatability.
#
#  * Added test_tolerate_failure and $LINENO support unctions
#
#  * Anything related to valgrind or perf has been stripped out
#
#  * Many other minor changes and efficiencies
#
# Library of functions shared by all tests scripts, included by
# test-lib.sh.
#
# Copyright (C) 2005 Junio C Hamano
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses/ .

#
## IMPORTANT:  THIS FILE MUST NOT CONTAIN ANYTHING OTHER THAN FUNCTION
##             DEFINITION!!!  INITIALIZATION GOES IN THE LAST FUNCTION
##             DEFINED IN THIS FILE "test_lib_functions_init" IF REQUIRED!
#

# The semantics of the editor variables are that of invoking
# sh -c "$EDITOR \"$@\"" files ...
#
# If our trash directory contains shell metacharacters, they will be
# interpreted if we just set $EDITOR directly, so do a little dance with
# environment variables to work around this.
#
# In particular, quoting isn't enough, as the path may contain the same quote
# that we're using.
test_set_editor() {
	FAKE_EDITOR="$1"
	export FAKE_EDITOR
	EDITOR='"$FAKE_EDITOR"'
	export EDITOR
}

test_decode_color() {
	awk '
		function name(n) {
			if (n == 0) return "RESET";
			if (n == 1) return "BOLD";
			if (n == 30) return "BLACK";
			if (n == 31) return "RED";
			if (n == 32) return "GREEN";
			if (n == 33) return "YELLOW";
			if (n == 34) return "BLUE";
			if (n == 35) return "MAGENTA";
			if (n == 36) return "CYAN";
			if (n == 37) return "WHITE";
			if (n == 40) return "BLACK";
			if (n == 41) return "BRED";
			if (n == 42) return "BGREEN";
			if (n == 43) return "BYELLOW";
			if (n == 44) return "BBLUE";
			if (n == 45) return "BMAGENTA";
			if (n == 46) return "BCYAN";
			if (n == 47) return "BWHITE";
		}
		{
			while (match($0, /\033\[[0-9;]*m/) != 0) {
				printf "%s<", substr($0, 1, RSTART-1);
				codes = substr($0, RSTART+2, RLENGTH-3);
				if (length(codes) == 0)
					printf "%s", name(0)
				else {
					n = split(codes, ary, ";");
					sep = "";
					for (i = 1; i <= n; i++) {
						printf "%s%s", sep, name(ary[i]);
						sep = ";"
					}
				}
				printf ">";
				$0 = substr($0, RSTART + RLENGTH, length($0) - RSTART - RLENGTH + 1);
			}
			print
		}
	'
}

lf_to_nul() {
	tr '\012' '\000'
}

nul_to_q() {
	tr '\000' Q
}

q_to_nul() {
	tr Q '\000'
}

q_to_cr() {
	tr Q '\015'
}

q_to_tab() {
	tr Q '\011'
}

qz_to_tab_space() {
	tr QZ '\011\040'
}

append_cr() {
	sed -e 's/$/Q/' | tr Q '\015'
}

remove_cr() {
	tr '\015' Q | sed -e 's/Q$//'
}

# In some bourne shell implementations, the "unset" builtin returns
# nonzero status when a variable to be unset was not set in the first
# place.
#
# Use sane_unset when that should not be considered an error.

sane_unset() {
	{ "unset" "$@"; } >/dev/null 2>&1 || :
}

test_asv_cache_lno() {
	: "${callerlno:=$1}"
	shift
	if [ "$1" != "-" ]; then
		test_asv_cache_lno "$callerlno" - <<EOT
$1
EOT
	else
		while read _tac_id _tac_hash _tac_value; do
			case "$_tac_id" in "#"*|"") continue; esac
			case "$_tac_hash" in
			sha1|sha256)
				eval "test_asvdb_${_tac_id}_$_tac_hash=\"\$_tac_value\""
				;;
			*)
				die "${0##*/}:${callerlno:+$callerlno:}" \
					"invalid test_asv_cache hash algorithm '$_tac_hash'"
			esac
		done
	fi
}
test_asv_cache() {
	test_asv_cache_lno "" "$@"
}
alias test_asv_cache='test_asv_cache_lno "$LINENO"' >/dev/null 2>&1 || :

test_v_asv_lno() {
	: "${callerlno:=$1}"
	shift
	_asvhash="${3:-$test_hash_algo}"
	: "${_asvhash:=sha1}"
	case "$_asvhash" in sha1|sha256);;*)
		die "${0##*/}:${callerlno:+$callerlno:} invalid test_v_asv hash algorithm '$_asvhash'"
	esac
	eval "_tac_set=\${test_asvdb_${2}_$_asvhash+set}"
	test "$_tac_set" = "set" ||
		die "${0##*/}:${callerlno:+$callerlno:}" \
			"missing test_asv_cache value for id \"$2\" hash algorithm $_asvhash"
	test -z "$1" || eval "$1=\"\$test_asvdb_${2}_$_asvhash\""
}
test_v_asv() {
	test_v_asv_lno "" "$@"
}
alias test_v_asv='test_v_asv_lno "$LINENO"' >/dev/null 2>&1 || :

test_asv_lno() {
	: "${callerlno:=$1}"
	shift
	_asvhash="${2:-$test_hash_algo}"
	: "${_asvhash:=sha1}"
	case "$_asvhash" in sha1|sha256);;*)
		die "${0##*/}:${callerlno:+$callerlno:} invalid test_asv hash algorithm '$_asvhash'"
	esac
	eval "_tac_set=\${test_asvdb_${1}_$_asvhash+set}"
	test "$_tac_set" = "set" ||
		die "${0##*/}:${callerlno:+$callerlno:}" \
			"missing test_asv_cache value for id \"$1\" hash algorithm $_asvhash"
	eval "printf '%s\n' \"\$test_asvdb_${1}_$_asvhash\""
}
test_asv() {
	test_asv_lno "" "$@"
}
alias test_asv='test_asv_lno "$LINENO"' >/dev/null 2>&1 || :

test_v_git_mt_lno() {
	: "${callerlno:=$1}"
	shift
	case "$2" in blob|tree|null);;*)
		die "${0##*/}:${callerlno:+$callerlno:} invalid test_v_git_mt object type '$2'"
	esac
	_mthash="${3:-$test_hash_algo}"
	: "${_mthash:=sha1}"
	case "$_mthash" in sha1|sha256);;*)
		die "${0##*/}:${callerlno:+$callerlno:} invalid test_v_git_mt hash algorithm '$_mthash'"
	esac
	_mthashval=
	case "$2" in
	null)
		case "$_mthash" in
		sha1)	_mthashval="0000000000000000000000000000000000000000";;
		sha256)	_mthashval="0000000000000000000000000000000000000000000000000000000000000000";;
		esac;;
	blob)
		case "$_mthash" in
		sha1)	_mthashval="e69de29bb2d1d6434b8b29ae775ad8c2e48c5391";;
		sha256)	_mthashval="473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813";;
		esac;;
	tree)
		case "$_mthash" in
		sha1)	_mthashval="4b825dc642cb6eb9a060e54bf8d69288fbee4904";;
		sha256)	_mthashval="6ef19b41225c5369f1c104d45d8d85efa9b057b53b14b4b9b939dd74decc5321";;
		esac;;
	esac
	test -z "$1" || eval "$1=\"\$_mthashval\""
}
test_v_git_mt() {
	test_v_git_mt_lno "" "$@"
}
alias test_v_git_mt='test_v_git_mt_lno "$LINENO"' >/dev/null 2>&1 || :

test_set_hash_algo_lno() {
	: "${callerlno:=$1}"
	shift
	case "$1" in sha1|sha256);;*)
		die "${0##*/}:${callerlno:+$callerlno:} invalid test_set_hash_algo hash algorithm '$1'"
	esac
	test "$1" != "sha256" || test -n "$test_git229_plus" ||
		die "${0##*/}:${callerlno:+$callerlno:}" \
			"test_set_hash_algo sha256 requires Git 2.29.0 or later" \
			"but found $git_version"
	test_hash_algo="$1"
	GIT_DEFAULT_HASH="$test_hash_algo" && export GIT_DEFAULT_HASH
}
test_set_hash_algo() {
	test_set_hash_algo_lno "" "$@"
}
alias test_set_hash_algo='test_set_hash_algo_lno "$LINENO"' >/dev/null 2>&1 || :

# Protect against breaking in the future when Git changes its
# nearly two decades old defaults.  The `-c` option first appeared
# in Git 1.7.2 (2010-07-21).  That means this test framework
# requires at least Git 1.7.2.  Since TopGit requires at least
# Git 1.9.2 that's not a problem.  If Git is at least version 2.29.0
# pass a --object-format=$test_hash_algo option as the first `git init`
# option.
git_init() {
	test -z "$test_git229_plus" ||
	set -- --object-format="${test_hash_algo:-sha1}" "$@"
	git -c init.defaultBranch=master init "$@"
}

test_tick() {
	if test -z "${test_tick:+set}"
	then
		test_tick=1112911993
	else
		test_tick=$(($test_tick + 60))
	fi
	GIT_COMMITTER_DATE="$test_tick -0700"
	GIT_AUTHOR_DATE="$test_tick -0700"
	export GIT_COMMITTER_DATE GIT_AUTHOR_DATE
}

# Stop execution and start a shell. This is useful for debugging tests and
# only makes sense together with "-v".
#
# Be sure to remove all invocations of this command before submitting.

test_pause() {
	if test "$verbose" = t; then
		"$SHELL_PATH" <&6 >&3 2>&4
	else
		error >&5 "test_pause requires --verbose"
	fi
}

test_check_tag_ok_() {
	case "$1" in ""|*"^"*|*[?*:~]*|*"["*|*"@{"*|*".."*|*"//"*|*"\\"*) return 1; esac
	return 0
}

test_check_one_tag_() {
	test $# -eq 1 &&
	test_check_tag_ok_ "$1"
}

# Call test_commit with the arguments "<message> [<file> [<contents> [<tag>]]]"
#
# This will commit a file with the given contents and the given commit
# message, and tag the resulting commit with the given tag name.
#
# <file> defaults to "<message>.t", <contents> and <tag> default to
#  "<message>".  If the (possibly default) value for <tag> ends up being
# empty or contains any whitespace or invalid ref name characters the tag will
# be omitted.
#
# <file>, <contents>, and <tag> all default to <message>.

test_commit() {
	notick= &&
	signoff= &&
	while test $# != 0
	do
		case "$1" in
		--notick)
			notick=yes
			;;
		--signoff)
			signoff="$1"
			;;
		*)
			break
			;;
		esac
		shift
	done &&
	file=${2:-"$1.t"} &&
	printf '%s\n' "${3-$1}" > "$file" &&
	git add "$file" &&
	if test -z "$notick"
	then
		test_tick
	fi &&
	git commit $signoff -m "$1" &&
	if test_check_one_tag_ ${4-$1}
	then
		git tag ${4-$1}
	fi
}

# Call test_merge with the arguments "<message> [<opt>...] <commit>", where
# <commit> can be a tag pointing to the commit-to-merge, but automatically skip
# the tag if <message> is not tagish and supply --allow-unrelated-histories
# when running Git >= 2.9.

test_merge() {
	test_tick &&
	git merge $test_auh -m "$@" &&
	if test_check_one_tag_ $1
	then
		git tag $1
	fi
}

# This function helps systems where core.filemode=false is set.
# Use it instead of plain 'chmod +x' to set or unset the executable bit
# of a file in the working directory and add it to the index.

test_chmod() {
	chmod "$@" &&
	git update-index --add "--chmod=$@"
}

# Unset a configuration variable, but don't fail if it doesn't exist.
test_unconfig() {
	config_dir=
	if test "$1" = -C
	then
		shift
		config_dir=$1
		shift
	fi
	eval git "${config_dir:+-C \"\$config_dir\"}" config --unset-all '"$@"'
	config_status=$?
	case "$config_status" in
	5) # ok, nothing to unset
		config_status=0
		;;
	esac
	return $config_status
}

# Set git config, automatically unsetting it after the test is over.
test_config() {
	config_dir=
	if test "$1" = -C
	then
		shift
		config_dir="$1"
		shift
	fi
	eval test_when_finished test_unconfig "${config_dir:+-C \"\$config_dir\"}" '"$1"' &&
	eval git "${config_dir:+-C \"\$config_dir\"}" config '"$@"'
}

test_config_global() {
	test_when_finished test_unconfig --global "$1" &&
	git config --global "$@"
}

write_script() {
	{
		echo "#!${2-"$SHELL_PATH"}" &&
		cat
	} >"$1" &&
	chmod +x "$1"
}

# Use test_set_prereq to tell that a particular prerequisite is available.
# The prerequisite can later be checked for in two ways:
#
# - Explicitly using test_have_prereq.
#
# - Implicitly by specifying the prerequisite tag in the calls to
#   test_expect_{success,failure,code}.
#
# The single parameter is the prerequisite tag (a simple word, in all
# capital letters by convention).

test_set_prereq() {
	satisfied_prereq="$satisfied_prereq$1 "
}

# Usage: test_lazy_prereq PREREQ 'script'
test_lazy_prereq() {
	lazily_testable_prereq="$lazily_testable_prereq$1 "
	eval test_prereq_lazily_$1=\$2
}

test_ensure_git_dir_() {
	git rev-parse --git-dir >/dev/null 2>&1 ||
	git_init --quiet --template="$EMPTY_DIRECTORY" >/dev/null 2>&1 ||
		fatal "cannot run git init"
}

test_run_lazy_prereq_() {
	script='
test_ensure_temp_dir_ "test_run_lazy_prereq_" "prereq-test-dir" &&
(
	cd "$TRASHTMP_DIRECTORY/prereq-test-dir" &&'"$2"'
)'
	say >&3 "checking prerequisite: $1"
	say >&3 "$script"
	test_eval_ "$script"
	eval_ret=$?
	rm -rf "$TRASHTMP_DIRECTORY/prereq-test-dir"
	if test "$eval_ret" = 0; then
		say >&3 "prerequisite $1 ok"
	else
		say >&3 "prerequisite $1 not satisfied"
	fi
	return $eval_ret
}

test_have_prereq() {
	# prerequisites can be concatenated with ',' or whitespace
	save_IFS="$IFS"
	_tab='	'
	_nl='
'
	IFS=", $_tab$_nl"
	set -- $*
	IFS="$save_IFS"

	total_prereq=0
	ok_prereq=0
	missing_prereq=

	for prerequisite
	do
		case "$prerequisite" in
		!*)
			negative_prereq=t
			prerequisite=${prerequisite#!}
			;;
		*)
			negative_prereq=
		esac

		case " $lazily_tested_prereq " in
		*" $prerequisite "*)
			;;
		*)
			case " $lazily_testable_prereq " in
			*" $prerequisite "*)
				eval "script=\$test_prereq_lazily_$prerequisite" &&
				if test_run_lazy_prereq_ "$prerequisite" "$script"
				then
					test_set_prereq $prerequisite
				fi
				lazily_tested_prereq="$lazily_tested_prereq$prerequisite "
			esac
			;;
		esac

		total_prereq=$(($total_prereq + 1))
		satisfied_this_prereq=
		if test "$prerequisite" = "LASTOK"
		then
			if test -n "$test_last_subtest_ok"
			then
				satisfied_this_prereq=t
			fi
		elif test "$prerequisite" = "GITSHA1"
		then
			if test "${test_hash_algo:-sha1}" = "sha1"
			then
				satisfied_this_prereq=t
			fi
		else
			case "$satisfied_prereq" in
			*" $prerequisite "*)
				satisfied_this_prereq=t
			esac
		fi

		case "$satisfied_this_prereq,$negative_prereq" in
		t,|,t)
			ok_prereq=$(($ok_prereq + 1))
			;;
		*)
			# Keep a list of missing prerequisites; restore
			# the negative marker if necessary.
			prerequisite=${negative_prereq:+!}$prerequisite
			if test -z "$missing_prereq"
			then
				missing_prereq=$prerequisite
			else
				missing_prereq="$missing_prereq, $prerequisite"
			fi
		esac
	done

	test $total_prereq = $ok_prereq
}

test_declared_prereq() {
	case " $test_prereq " in
	*" $1 "*)
		return 0
		;;
	esac
	return 1
}

test_verify_prereq() {
	test -z "$test_prereq" ||
	test "x$test_prereq" = "x${test_prereq#*[!A-Z0-9_ !]}" ||
	error "bug in the test script: '$test_prereq' does not look like a prereq"
}

_test_set_test_prereq() {
	test_prereq_fmt=
	save_IFS="$IFS"
	_tab='	'
	_nl='
'
	IFS=", $_tab$_nl"
	set -- $*
	IFS="$save_IFS"
	test_prereq="$*"
	while test "$#" != "0"
	do
		test_prereq_fmt="${test_prereq_fmt:+$test_prereq_fmt, }$1"
		shift
	done
}

test_expect_failure_lno() {
	callerlno="$1"
	shift
	test_start_
	test "$#" = 3 && { _test_set_test_prereq "$1"; shift; } || test_prereq=
	test "$#" = 2 ||
	error "bug in the test script: not 2 or 3 parameters to test-expect-failure"
	test_get_ "$2"
	set -- "$1" "$test_script_"
	test_verify_prereq
	export test_prereq
	if ! test_skip "$@"
	then
		say >&3 "checking known breakage: $2"
		if test_run_ "$2" expecting_failure
		then
			test_known_broken_ok_ "$1"
			test_last_subtest_ok=1
		else
			test_known_broken_failure_ "$1"
			test_last_subtest_ok=
		fi
	fi
	test_finish_
	unset_ callerlno
}
test_expect_failure() {
	test_expect_failure_lno "" "$@"
}
alias test_expect_failure='test_expect_failure_lno "$LINENO"' >/dev/null 2>&1 || :

if test -n "$TESTLIB_NO_TOLERATE"; then
test_tolerate_failure_lno() { test_expect_success_lno "$@"; }
else
test_tolerate_failure_lno() {
	callerlno="$1"
	shift
	test_start_
	test "$#" = 3 && { _test_set_test_prereq "$1"; shift; } || test_prereq=
	test "$#" = 2 ||
	error "bug in the test script: not 2 or 3 parameters to test-tolerate-failure"
	test_get_ "$2"
	set -- "$1" "$test_script_"
	test_verify_prereq
	export test_prereq
	if ! test_skip "$@"
	then
		say >&3 "checking possible breakage: $2"
		if test_run_ "$2" tolerating_failure
		then
			test_possibly_broken_ok_ "$1"
			test_last_subtest_ok=1
		else
			test_possibly_broken_failure_ "$1"
			test_last_subtest_ok=
		fi
	fi
	test_finish_
	unset_ callerlno
}
fi
test_tolerate_failure() {
	test_tolerate_failure_lno "" "$@"
}
alias test_tolerate_failure='test_tolerate_failure_lno "$LINENO"' >/dev/null 2>&1 || :

test_expect_success_lno() {
	callerlno="$1"
	shift
	test_start_
	test "$#" = 3 && { _test_set_test_prereq "$1"; shift; } || test_prereq=
	test "$#" = 2 ||
	error "bug in the test script: not 2 or 3 parameters to test-expect-success"
	test_get_ "$2"
	set -- "$1" "$test_script_"
	test_verify_prereq
	export test_prereq
	if ! test_skip "$@"
	then
		say >&3 "expecting success: $2"
		if test_run_ "$2"
		then
			test_ok_ "$1"
			test_last_subtest_ok=1
		else
			test_failure_ "$callerlno" "$@"
			test_last_subtest_ok=
		fi
	fi
	test_finish_
	unset_ callerlno
}
test_expect_success() {
	test_expect_success_lno "" "$@"
}
alias test_expect_success='test_expect_success_lno "$LINENO"' >/dev/null 2>&1 || :

# test_external runs external test scripts that provide continuous
# test output about their progress, and succeeds/fails on
# zero/non-zero exit code.  It outputs the test output on stdout even
# in non-verbose mode, and announces the external script with "# run
# <n>: ..." before running it.  When providing relative paths, keep in
# mind that all scripts run in "trash directory".
# Usage: test_external description command arguments...
# Example: test_external 'Awk API' awk -f ../path/to/test.awk
test_external_lno() {
	callerlno="$1"
	shift
	test_count=$(($test_count+1))
	test "$#" = 4 && { _test_set_test_prereq "$1"; shift; } || test_prereq=
	test "$#" = 3 ||
	error >&5 "bug in the test script: not 3 or 4 parameters to test_external"
	descr="$1"
	shift
	test_verify_prereq
	export test_prereq
	test_external_skipped=1
	if ! test_skip "$descr" "$@"
	then
		# Announce the script to reduce confusion about the
		# test output that follows.
		say_color "" "# run $test_count: $descr ($*)"
		# Export TEST_DIRECTORY, TRASH_DIRECTORY, TRASHTMP_DIRECTORY
		# and TESTLIB_TEST_LONG to be able to use them in script
		export TEST_DIRECTORY TRASH_DIRECTORY TRASHTMP_DIRECTORY TESTLIB_TEST_LONG
		# Run command; redirect its stderr to &4 as in
		# test_run_, but keep its stdout on our stdout even in
		# non-verbose mode.
		"$@" 2>&4
		if test "$?" = 0
		then
			if test $test_external_has_tap -eq 0; then
				test_ok_ "$descr"
			else
				say_color "" "# test_external test $descr was ok"
				test_success=$(($test_success + 1))
			fi
			test_last_subtest_ok=1
		else
			if test $test_external_has_tap -eq 0; then
				test_failure_ "$callerlno" "$descr" "$@"
			else
				say_color error "# test_external test $descr failed: $@"
				test_failure=$(($test_failure + 1))
			fi
			test_last_subtest_ok=
		fi
		test_external_skipped=
	fi
	unset_ callerlno
}
test_external() {
	test_external_lno "" "$@"
}
alias test_external='test_external_lno "$LINENO"' >/dev/null 2>&1 || :

# Like test_external, but in addition tests that the command generated
# no output on stderr.
test_external_without_stderr_lno() {
	callerlno="$1"
	shift
	# The temporary file has no (and must have no) security
	# implications.
	tmp=${TMPDIR:-/tmp}
	stderr="$tmp/git-external-stderr.$$.tmp"
	test_external_lno "$callerlno" "$@" 4> "$stderr"
	test -f "$stderr" || error "Internal error: $stderr disappeared."
	descr="no stderr: $1"
	shift
	test_count=$(($test_count+1))
	say >&3 "# expecting no stderr from previous command"
	if test -n "$test_external_skipped" || test ! -s "$stderr"
	then
		rm "$stderr"

		if test $test_external_has_tap -eq 0; then
			test_ok_ "$descr"
		else
			say_color "" "# test_external_without_stderr test $descr was ok"
			test_success=$(($test_success + 1))
		fi
	else
		test_last_subtest_ok=
		if test "$verbose" = t
		then
			output=$(echo; echo "# Stderr is:"; cat "$stderr")
		else
			output=
		fi
		# rm first in case test_failure exits.
		rm "$stderr"
		if test $test_external_has_tap -eq 0; then
			test_failure_ "$callerlno" "$descr" "$@" "$output"
		else
			say_color error "# test_external_without_stderr test $descr failed: $@: $output"
			test_failure=$(($test_failure + 1))
		fi
	fi
	unset_ callerlno
}
test_external_without_stderr() {
	test_external_without_stderr_lno "" "$@"
}
alias test_external_without_stderr='test_external_without_stderr_lno "$LINENO"' >/dev/null 2>&1 || :

# debugging-friendly alternatives to "test [-f|-d|-e]"
# The commands test the existence or non-existence of $1. $2 can be
# given to provide a more precise diagnosis.
test_path_is_file() {
	if ! test -f "$1"
	then
		echo "File $1 doesn't exist. $2"
		false
	fi
}

test_path_is_dir() {
	if ! test -d "$1"
	then
		echo "Directory $1 doesn't exist. $2"
		false
	fi
}

# Check if the directory exists and is empty as expected, barf otherwise.
test_dir_is_empty() {
	test_path_is_dir "$1" &&
	if test -n "$(ls -a1 "$1" | grep -E -v '^\.\.?$')"
	then
		echo "Directory '$1' is not empty, it contains:"
		ls -la "$1"
		return 1
	fi
}

test_path_is_missing() {
	if test -e "$1"
	then
		echo "Path exists:"
		ls -ld "$1"
		if test $# -ge 1
		then
			echo "$*"
		fi
		false
	fi
}

wc() {
	wc_=0 &&
	{
		{
			wc_vals_="$(command wc "$@")" &&
			set -- $wc_vals_ &&
			echo "$*"
		} || wc_=$?
	} &&
	set -- "$wc_" &&
	unset_ wc_ wc_vals_ &&
	return $1
}

# test_line_count checks that a file has the number of lines it
# ought to. For example:
#
#	test_expect_success 'produce exactly one line of output' '
#		do something >output &&
#		test_line_count = 1 output
#	'
#
# is like "test $(wc -l <output) = 1" except that it passes the
# output through when the number of lines is wrong.

test_line_count() {
	if test $# != 3
	then
		error "bug in the test script: not 3 parameters to test_line_count"
	elif ! test $(wc -l <"$3") "$1" "$2"
	then
		echo "test_line_count: line count for $3 !$1 $2"
		cat "$3"
		return 1
	fi
}

# Returns success if a comma separated string of keywords ($1) contains a
# given keyword ($2).
# Examples:
# `list_contains "foo,bar" bar` returns 0
# `list_contains "foo" bar` returns 1

list_contains() {
	case ",$1," in
	*,$2,*)
		return 0
		;;
	esac
	return 1
}

# This is not among top-level (test_expect_success | test_expect_failure)
# but is a prefix that can be used in the test script, like:
#
#	test_expect_success 'complain and die' '
#           do something &&
#           do something else &&
#	    test_must_fail git checkout ../outerspace
#	'
#
# Writing this as "! git checkout ../outerspace" is wrong, because
# the failure could be due to a segv.  We want a controlled failure.

test_must_fail() {
	case "$1" in
	ok=*)
		_test_ok=${1#ok=}
		shift
		;;
	*)
		_test_ok=
		;;
	esac
	exit_code=0
	"$@" ||
	exit_code=$?
	if test $exit_code -eq 0 && ! list_contains "$_test_ok" success
	then
		echo >&2 "test_must_fail: command succeeded: $*"
		return 1
	elif test_match_signal 13 $exit_code && list_contains "$_test_ok" sigpipe
	then
		return 0
	elif test $exit_code -gt 129 && test $exit_code -le 192
	then
		echo >&2 "test_must_fail: died by signal $(($exit_code - 128)): $*"
		return 1
	elif test $exit_code -eq 127
	then
		echo >&2 "test_must_fail: command not found: $*"
		return 1
	elif test $exit_code -eq 126
	then
		echo >&2 "test_must_fail: command not executable: $*"
		return 1
	fi
	return 0
}

# Similar to test_must_fail, but tolerates success, too.  This is
# meant to be used in contexts like:
#
#	test_expect_success 'some command works without configuration' '
#		test_might_fail git config --unset all.configuration &&
#		do something
#	'
#
# Writing "git config --unset all.configuration || :" would be wrong,
# because we want to notice if it fails due to segv.

test_might_fail() {
	test_must_fail ok=success "$@"
}

# Similar to test_must_fail and test_might_fail, but check that a
# given command exited with a given exit code. Meant to be used as:
#
#	test_expect_success 'Merge with d/f conflicts' '
#		test_expect_code 1 git merge "merge msg" B master
#	'

test_expect_code() {
	want_code=$1 &&
	shift &&
	exit_code=0 &&
	"$@" ||
	exit_code=$?
	if test $exit_code = $want_code
	then
		return 0
	fi

	echo >&2 "test_expect_code: command exited with $exit_code, we wanted $want_code $*"
	return 1
}

# test_cmp is a helper function to compare actual and expected output.
# You can use it like:
#
#	test_expect_success 'foo works' '
#		echo expected >expected &&
#		foo >actual &&
#		test_cmp expected actual
#	'
#
# This could be written as either "cmp" or "diff -u", but:
# - cmp's output is not nearly as easy to read as diff -u
# - not all diff versions understand "-u"

test_cmp() {
	$TESTLIB_TEST_CMP "$@"
}

# test_cmp_bin - helper to compare binary files

test_cmp_bin() {
	cmp "$@"
}

# Use git diff --no-index for the diff (with a few supporting options)
test_diff() {
	git --git-dir="$EMPTY_DIRECTORY" --no-pager -c core.abbrev=16 diff --no-color --exit-code --no-prefix --no-index "$@"
}

# Call any command "$@" but be more verbose about its
# failure. This is handy for commands like "test" which do
# not output anything when they fail.
verbose() {
	"$@" && return 0
	echo >&2 "command failed: $(git rev-parse --sq-quote "$@")"
	return 1
}

# Check if the file expected to be empty is indeed empty, and barfs
# otherwise.

test_must_be_empty() {
	if test -s "$1"
	then
		echo "'$1' is not empty, it contains:"
		cat "$1"
		return 1
	fi
}

# Tests that its two parameters refer to the same revision
test_cmp_rev() {
	test_ensure_temp_dir_ "test_cmp_rev"
	git rev-parse --verify "$1" -- >"$TRASHTMP_DIRECTORY/expect.rev" &&
	git rev-parse --verify "$2" -- >"$TRASHTMP_DIRECTORY/actual.rev" &&
	test_cmp "$TRASHTMP_DIRECTORY/expect.rev" "$TRASHTMP_DIRECTORY/actual.rev"
}

# Print a sequence of integers in increasing order, either with
# two arguments (start and end):
#
#     test_seq 1 5 -- outputs 1 2 3 4 5 one line at a time
#
# or with one argument (end), in which case it starts counting
# from 1.

test_seq() {
	case $# in
	1)	set 1 "$@" ;;
	2)	;;
	*)	error "bug in the test script: not 1 or 2 parameters to test_seq" ;;
	esac
	test_seq_counter__=$1
	while test "$test_seq_counter__" -le "$2"
	do
		echo "$test_seq_counter__"
		test_seq_counter__=$(( $test_seq_counter__ + 1 ))
	done
}

# This function can be used to schedule some commands to be run
# unconditionally at the end of the test to restore sanity:
#
#	test_expect_success 'test core.capslock' '
#		git config core.capslock true &&
#		test_when_finished git config --unset core.capslock &&
#		hello world
#	'
#
# That would be roughly equivalent to
#
#	test_expect_success 'test core.capslock' '
#		git config core.capslock true &&
#		hello world
#		git config --unset core.capslock
#	'
#
# except that the greeting and config --unset must both succeed for
# the test to pass.
#
# Note that under --immediate mode, no clean-up is done to help diagnose
# what went wrong.

test_when_finished() {
	test z"$*" != z && test -z "$linting" || return 0
	test_ensure_temp_dir_ "test_when_finished"
	twf_script_="$TRASHTMP_DIRECTORY/test_when_finished_${test_count:-0}.sh"
	twf_cmd_=
	for twf_arg_ in "$@"; do
		twf_dq_=1
		case "$twf_arg_" in [A-Za-z_]*)
			if test z"${twf_arg_%%[!A-Za-z_0-9]*}" = z"$twf_arg_"
			then
				twf_arg_sq_="$twf_arg_"
				twf_dq_=
			else case "$twf_arg_" in *=*)
				twf_var_="${twf_arg_%%=*}"
				if test z"${twf_var_%%[!A-Za-z_0-9]*}" = z"$twf_var_"
				then
					test_quotevar_ 3 twf_arg_sq_ "${twf_arg_#*=}"
					twf_arg_sq_="$twf_var_=$twf_arg_sq_"
					twf_dq_=
				fi
			esac; fi
		esac
		test z"$twf_dq_" = z || test_quotevar_ twf_arg_ twf_arg_sq_
		twf_cmd_="${twf_cmd_:+$twf_cmd_ }$twf_arg_sq_"
	done
	printf '{ %s\n} && (exit "$eval_ret"); eval_ret=$?\n' "$twf_cmd_" >>"$twf_script_"
}

# clear out any test_when_finished items scheduled so far in this subtest
test_clear_when_finished() {
	tcwf_script_="$TRASHTMP_DIRECTORY/test_when_finished_${test_count:-0}.sh"
	! test -e "$tcwf_script_" || {
		rm -f "$tcwf_script_" &&
		! test -e "$tcwf_script_"
	}
}

# Most tests can use the created repository, but some may need to create more.
# Usage: test_create_repo <directory>
test_create_repo() {
	test "$#" = 1 ||
	error "bug in the test script: not 1 parameter to test-create-repo"
	repo="$1"
	mkdir -p "$repo"
	(
		cd "$repo" || error "Cannot setup test environment"
		git_init --quiet "--template=$EMPTY_DIRECTORY" >&3 2>&4 ||
		error "cannot run git init -- have you built things yet?"
		! [ -e .git/hooks ] || mv .git/hooks .git/hooks-disabled
	) || exit
}

# This function helps on symlink challenged file systems when it is not
# important that the file system entry is a symbolic link.
# Use test_ln_s_add instead of "ln -s x y && git add y" to add a
# symbolic link entry y to the index.

test_ln_s_add() {
	if test_have_prereq SYMLINKS
	then
		ln -s "$1" "$2" &&
		git update-index --add "$2"
	else
		printf '%s' "$1" >"$2" &&
		ln_s_obj=$(git hash-object -w "$2") &&
		git update-index --add --cacheinfo 120000 $ln_s_obj "$2" &&
		# pick up stat info from the file
		git update-index "$2"
	fi
}

# This function writes out its parameters, one per line
test_write_lines() {
	printf '%s\n' "$@"
}

awk() (
	{ "unset" -f awk; } >/dev/null 2>&1 || :
	"exec" "$AWK_PATH" "$@"
)

git() (
	{ "unset" -f git; } >/dev/null 2>&1 || :
	"exec" "$GIT_PATH" "$@"
)

perl_lno() (
	: "${callerlno:=$1}"
	shift
	perlerr_() { return 70; } # EX_SOFTWARE
	perlerr_ || die "${0##*/}:${callerlno:+$callerlno:} test suite attempted to use perl"
	exit 70 # EX_SOFTWARE
)
perl() {
	perl_lno "" "$@"
}
alias perl='perl_lno "$LINENO"' >/dev/null 2>&1 || :

# Given a variable $1, normalize the value of it to one of "true",
# "false", or "auto" and store the result to it.
#
#     test_tristate TESTLIB_TEST_FLIBITY
#
# A variable set to an empty string is set to 'false'.
# A variable set to 'false' or 'auto' keeps its value.
# Anything else is set to 'true'.
# An unset variable defaults to 'auto'.
#
# The last rule is to allow people to set the variable to an empty
# string and export it to decline testing the particular feature
# for versions both before and after this change.  We used to treat
# both unset and empty variable as a signal for "do not test" and
# took any non-empty string as "please test".

test_tristate() {
	if eval "test \"z\${$1+set}\" = \"zset\""
	then
		# explicitly set
		eval "set -- \"\$1\" \"\$$1\""
		case "$2" in [-+]0?*|0?*)
			set -- "$1" "${2#[-+]}"
			set -- "$1" "$2" "${2%%[!0]*}"
			set -- "$1" "${2#"$3"}"
		esac
		case "$2" in
			[Aa][Uu][Tt][Oo])
				set "$1" "auto";;
			""|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|[Nn][Oo]|[-+]0|0)
				set "$1" "false";;
			*)
				# Git is actually more picky than this in that
				# only true/on/yes/(int)!=0 qualify else an err
				# but the original code treated those as true
				set "$1" "true";;
		esac
		eval "$1=\"\$2\""
	else
		eval "$1=\"auto\""
	fi
}

# Exit the test suite, either by skipping all remaining tests or by
# exiting with an error. If "$1" is "auto", we then we assume we were
# opportunistically trying to set up some tests and we skip. If it is
# "true", then we report a failure.
#
# The error/skip message should be given by $2.
#
test_skip_or_die() {
	case "$1" in
	auto)
		skip_all=$2
		test_done
		;;
	true)
		error "$2"
		;;
	*)
		error "BUG: test tristate is '$1' (real error: $2)"
	esac
}

# The following mingw_* functions obey POSIX shell syntax, but are actually
# bash scripts, and are meant to be used only with bash on Windows.

# A test_cmp function that treats LF and CRLF equal and avoids forking
# diff when possible.
mingw_test_cmp() {
	# Read text into shell variables and compare them. If the results
	# are different, use regular diff to report the difference.
	test_cmp_a= test_cmp_b=

	# When text came from stdin (one argument is '-') we must feed it
	# to diff.
	stdin_for_diff=

	# Since it is difficult to detect the difference between an
	# empty input file and a failure to read the files, we go straight
	# to diff if one of the inputs is empty.
	if test -s "$1" && test -s "$2"
	then
		# regular case: both files non-empty
		mingw_read_file_strip_cr_ test_cmp_a <"$1"
		mingw_read_file_strip_cr_ test_cmp_b <"$2"
	elif test -s "$1" && test "$2" = -
	then
		# read 2nd file from stdin
		mingw_read_file_strip_cr_ test_cmp_a <"$1"
		mingw_read_file_strip_cr_ test_cmp_b
		stdin_for_diff='<<<"$test_cmp_b"'
	elif test "$1" = - && test -s "$2"
	then
		# read 1st file from stdin
		mingw_read_file_strip_cr_ test_cmp_a
		mingw_read_file_strip_cr_ test_cmp_b <"$2"
		stdin_for_diff='<<<"$test_cmp_a"'
	fi
	test -n "$test_cmp_a" &&
	test -n "$test_cmp_b" &&
	test "$test_cmp_a" = "$test_cmp_b" ||
	eval "diff -u \"\$@\" $stdin_for_diff"
}

# $1 is the name of the shell variable to fill in
mingw_read_file_strip_cr_() {
	# Read line-wise using LF as the line separator
	# and use IFS to strip CR.
	line_=
	while :
	do
		if IFS=$'\r' read -r -d $'\n' line_
		then
			# good
			line_=$line_$'\n'
		else
			# we get here at EOF, but also if the last line
			# was not terminated by LF; in the latter case,
			# some text was read
			if test -z "$line_"
			then
				# EOF, really
				break
			fi
		fi
		eval "$1=\$$1\$line_"
	done
}

# Like "env FOO=BAR some-program", but run inside a subshell, which means
# it also works for shell functions (though those functions cannot impact
# the environment outside of the test_env invocation).
test_env() {
	(
		while test $# -gt 0
		do
			case "$1" in
			*=*)
				eval "${1%%=*}=\${1#*=}"
				eval "export ${1%%=*}"
				shift
				;;
			*)
				"$@"
				exit
				;;
			esac
		done
	)
}

# Returns true if the numeric exit code in "$2" represents the expected signal
# in "$1". Signals should be given numerically.
test_match_signal() {
	if test "$2" = "$((128 + $1))"
	then
		# POSIX
		return 0
	elif test "$2" = "$((256 + $1))"
	then
		# ksh
		return 0
	fi
	return 1
}

# Read up to "$1" bytes (or to EOF) from stdin and write them to stdout.
test_copy_bytes() {
	dd bs=1 count="$1" 2>/dev/null
}

#
# THIS SHOULD ALWAYS BE THE LAST FUNCTION DEFINED IN THIS FILE
#
# Any client that sources this file should immediately execute this function
# afterwards.
#
# THERE SHOULD NOT BE ANY DIRECTLY EXECUTED LINES OF CODE IN THIS FILE
#
test_lib_functions_init() {
	satisfied_prereq=" "
	lazily_testable_prereq= lazily_tested_prereq=
}
