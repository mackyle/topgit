# Test libe caching support
# Copyright (C) 2016 Kyle J. McKay.  All rights reserved.
# License GPLv2+

if [ "$1" = "--cache" ]; then
	# export all state to $PWD/TG-TEST-CACHE
	# then return a suitable value for 'TESTLIB_CACHE'
	#
	# CACHE_VARS is a list of variable names to cache but only if they
	# are actually set.
	#
	# EXPORT_VARS is a list of variables that should be exported.
	#
	# UNSET_VARS is a list of variables that should always be unset
	# it will automatically have unwanted GIT_XXX vars added to it

	CACHE_VARS="GIT_MERGE_VERBOSITY GIT_MERGE_AUTOEDIT \
		GIT_CONFIG_NOSYSTEM GIT_ATTR_NOSYSTEM GIT_TRACE_BARE \
		debug verbose verbose_only test_count trace LANG LC_ALL \
		TZ _x05 _x40 _z40 EMPTY_TREE EMPTY_BLOB LF u200c color \
		immediate TESTLIB_TEST_LONG run_list help quiet \
		say_color_error say_color_skip say_color_warn say_color_pass \
		say_color_info say_color_reset say_color_ TERM BASH_XTRACEFD \
		test_failure test_count test_fixed test_broken test_success \
		test_external_has_tap last_verbose GIT_MINIMUM_VERSION \
		TG_TEST_INSTALLED uname_s test_prereq TG_GIT_MINIMUM_VERSION \
		TG_INST_BINDIR TG_INST_CMDDIR TG_INST_HOOKSDIR TG_VERSION \
		TG_INST_SHAREDIR git_version git_vernum tg_version \
		lazily_tested_prereq satisfied_prereq PATH TESTLIB_TEST_CMP \
		GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_PATH DIFF \
		GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_TEMPLATE_DIR \
		EMPTY_DIRECTORY EDITOR TESTLIB_DIRECTORY TEST_DIRECTORY \
		TEST_OUTPUT_DIRECTORY PAGER root SHELL_PATH PERL_PATH \
		TESTLIB_NO_TOLERATE TESTLIB_TEST_CHAIN_LINT"

	EXPORT_VARS="PATH GIT_TEMPLATE_DIR GIT_CONFIG_NOSYSTEM \
		GIT_ATTR_NOSYSTEM GIT_MERGE_VERBOSITY GIT_MERGE_AUTOEDIT \
		GIT_AUTHOR_EMAIL GIT_AUTHOR_NAME GIT_COMMITTER_EMAIL TZ \
		GIT_COMMITTER_NAME EDITOR GIT_TRACE_BARE LANG LC_ALL PAGER \
		_x05 _x40 _z40 EMPTY_TREE EMPTY_BLOB LF u200c \
		TERM SHELL_PATH PERL_PATH GIT_PATH DIFF TG_TEST_INSTALLED \
		test_prereq TESTLIB_NO_TOLERATE TESTLIB_TEST_LONG"

	UNSET_VARS="VISUAL EMAIL LANGUAGE COLUMNS XDG_CONFIG_HOME GITPERLLIB \
		CDPATH GREP_OPTIONS UNZIP TESTLIB_EXIT_OK last_verbose"

	# strip off --cache
	shift

	# run the standard init but avoid doing any --tee processing now
	. ./test-lib-main.sh
	TESTLIB_TEST_TEE_STARTED=done
	test_lib_main_init_generic "$@" || exit $?
	unset TESTLIB_TEST_TEE_STARTED

	if [ -n "$lazily_testable_prereq" ]; then
		# run all the "lazy" prereq tests now
		cachetestdir="$TESTLIB_DIRECTORY/cachetest"
		! [ -e "$cachetestdir" ] || rm -rf "$cachetestdir" ||
			fatal "cannot remove $cachetestdir"
		mkdir "$cachetestdir" || fatal "cannot mkdir $cachetestdir"
		savepwd="$PWD"
		cd "$cachetestdir" || fatal "cannot cd to $cachetestdir"
		for lp in $lazily_testable_prereq; do
			! { eval "lpscript=\$test_prereq_lazily_$lp" &&
			(t() { eval "$lpscript";}; t) >/dev/null 2>&1;} || test_set_prereq $lp
			lazily_tested_prereq="$lazily_tested_prereq$lp "
		done
		cd "$savepwd" || fatal "cannot cd to $savepwd"
		rm -rf "$cachetestdir"
	fi

	# Add most GIT_XXX vars (variation of code from test-lib-main.sh)
	UNSET_VARS="$UNSET_VARS $("$PERL_PATH" -e '
			my @env = keys %ENV;
			my $ok = join("|", qw(
				TRACE
				DEBUG
				USE_LOOKUP
				TEST
				.*_TEST
				MINIMUM_VERSION
				PATH
				PROVE
				UNZIP
				PERF_
				CURL_VERBOSE
				TRACE_CURL
			));
			my @vars = grep(/^GIT_/ && !/^GIT_($ok)/o, @env);
			print join(" ", @vars);
		')"

	# writes the single-quoted value of the variable name passed as
	# the first argument to stdout (will be '' if unset) followed by the
	# second followed by a newline; use `quotevar 3 "" "$value"` to quote
	# a value directly
	quotevar() {
		eval "_scratch=\"\${$1}\""
		case "$_scratch" in *"'"*)
			_scratch="$(printf '%s\nZ\n' "$_scratch" | sed "s/'/'\\\''/g")"
			_scratch="${_scratch%??}"
		esac
		printf "'%s'%s\n" "$_scratch" "$2"
	}
	# return true if variable name passed as the first argument is
	# set even if to an empty value
	isvarset() {
		test "$(eval 'echo "${'$1'+set}"')" = "set"
	}
	PWD_SQ="$(quotevar PWD)"
	{
		echo unset $UNSET_VARS "&&"
		while read vname && [ -n "$vname" ]; do
			! isvarset $vname || { printf "%s=" $vname; quotevar $vname " &&"; }
		done <<-EOT
		$(echo $CACHE_VARS | sed 'y/ /\n/' | sort -u)
		EOT
		echo export $EXPORT_VARS "&&"
		echo "cd $PWD_SQ &&"
		echo ". ./test-lib-functions.sh &&"
		echo ". ./test-lib-main.sh &&"
		echo "TESTLIB_CACHE_ACTIVE=1"
	} >TG-TEST-CACHE
	printf ". %s/TG-TEST-CACHE || { echo 'error: missing '\'%s'/TG-TEST-CACHE'\' >&2; exit 1; }\n" "$PWD_SQ" "$PWD_SQ"
	TESTLIB_EXIT_OK=1
	exit 0
fi

[ -z "$TESTLIB_CACHE" ] || eval "$TESTLIB_CACHE" || exit $?
if [ -n "$TESTLIB_CACHE_ACTIVE" ]; then
	# Everything should have been restored by the eval of "$TESTLIB_CACHE"
	# Remove the leftover variables used to trigger use of the cache
	unset TESTLIB_CACHE TESTLIB_CACHE_ACTIVE

	# However, we still must parse and handle some options :(
	# swiped from test-lib-main.sh
	case "$TESTLIB_TEST_TEE_STARTED, $* " in
	done,*)
		# do not redirect again
		;;
	*' --tee '*|*' --va'*|*' --verbose-log '*)
		mkdir -p "$TEST_OUTPUT_DIRECTORY/test-results"
		BASE="$TEST_OUTPUT_DIRECTORY/test-results/$(basename "$0" .sh)"

		# Make this filename available to the sub-process in case it is using
		# --verbose-log.
		TESTLIB_TEST_TEE_OUTPUT_FILE=$BASE.out
		export TESTLIB_TEST_TEE_OUTPUT_FILE

		# Truncate before calling "tee -a" to get rid of the results
		# from any previous runs.
		>"$TESTLIB_TEST_TEE_OUTPUT_FILE"

		(TESTLIB_TEST_TEE_STARTED=done ${SHELL_PATH} "$0" "$@" 2>&1;
		 echo $? >"$BASE.exit") | tee -a "$TESTLIB_TEST_TEE_OUTPUT_FILE"
		test "$(cat "$BASE.exit")" = 0
		exit
		;;
	esac

	# We must also still perform per-test initialization though
	test_lib_main_init_specific "$@"
else
	# Normal, non-cached case where we run the init function
	. ./test-lib-main.sh
	test_lib_main_init "$@"
fi
