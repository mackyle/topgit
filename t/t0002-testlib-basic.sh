#!/bin/sh
#
# Copyright (C) 2005 Junio C Hamano
# Copyright (C) 2016 Kyle J. McKay
# All rights reserved
#

test_description='Test the very basics part #1.

The rest of the test suite does not check the basic operation of git
plumbing commands to work very carefully.  Their job is to concentrate
on tricky features that caused bugs in the past to detect regression.

This test runs very basic features, like registering things in cache,
writing tree, etc.

Note that this test *deliberately* hard-codes many expected object
IDs.  When object ID computation changes, like in the previous case of
swapping compression and hashing order, the person who is making the
modification *should* take notice and update the test vectors here.
'

. ./test-lib.sh

test_plan \?

################################################################
# git init has been done in an empty repository.
# make sure it is empty.

test_expect_success '.git/objects should be empty after git init in an empty repo' '
	find .git/objects -type f -print >should-be-empty &&
	test_line_count = 0 should-be-empty
'

# also it should have 2 subdirectories; no fan-out anymore, pack, and info.
# 3 is counting "objects" itself
test_expect_success '.git/objects should have 3 subdirectories' '
	find .git/objects -type d -print >full-of-directories &&
	test_line_count = 3 full-of-directories
'

################################################################
# Test harness
test_expect_success 'success is reported like this' '
	:
'

_run_sub_test_lib_test_common () {
	neg="$1" name="$2" descr="$3" # stdin is the body of the test code
	shift 3
	mkdir "$name" &&
	(
		# Pretend we're not running under a test harness, whether we
		# are or not. The test-lib output depends on the setting of
		# this variable, so we need a stable setting under which to run
		# the sub-test.
		sane_unset HARNESS_ACTIVE &&
		cd "$name" &&
		ln -s "$TESTLIB_DIRECTORY/test-lib.sh" . &&
		cat >"$name.sh" <<-EOF &&
		#!$SHELL_PATH

		test_description='$descr (run in sub test-lib)

		This is run in a sub test-lib so that we do not get incorrect
		passing metrics
		'

		. ./test-lib.sh

		# Unset LINENO as it's not universally supported and we do not
		# want to have to count lines to generate the expected output!
		# Attempting this:
		#   unset LINENO || :
		# may cause some broken sh implementations to abruptly terminate!
		# Instead just unalias all to avoid picking up the line numbers
		# after making sure unalias itself is not a function and
		# dealing with broken zsh that's missing a proper "unalias -a".
		{ "unset" -f unalias; } >/dev/null 2>&1 || :
		{ "unalias" -a || unalias -m "*"; } >/dev/null 2>&1 || :

		EOF
		cat >>"$name.sh" &&
		chmod +x "$name.sh" &&
		TEST_OUTPUT_DIRECTORY=$(pwd) &&
		export TEST_OUTPUT_DIRECTORY &&
		if test -z "$neg"
		then
			./"$name.sh" --no-tap-only "$@" >out 2>err
		else
			! ./"$name.sh" --no-tap-only "$@" >out 2>err
		fi
	)
}

run_sub_test_lib_test () {
	_run_sub_test_lib_test_common '' "$@"
}

run_sub_test_lib_test_err () {
	_run_sub_test_lib_test_common '!' "$@"
}

check_sub_test_lib_test () {
	name="$1" # stdin is the expected output from the test
	(
		cd "$name" &&
		! test -s err &&
		sed -e 's/^> //' -e 's/Z$//' >expect &&
		test_cmp expect out
	)
}

check_sub_test_lib_test_err () {
	name="$1" # stdin is the expected output from the test
	# expected error output is in descriptior 3
	(
		cd "$name" &&
		sed -e 's/^> //' -e 's/Z$//' >expect.out &&
		test_cmp expect.out out &&
		sed -e 's/^> //' -e 's/Z$//' <&3 >expect.err &&
		test_cmp expect.err err
	)
}

test_expect_success 'pretend we have a fully passing test suite' "
	run_sub_test_lib_test full-pass '3 passing tests' <<-\\EOF &&
	test_plan 3
	for i in 1 2 3
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test full-pass <<-\\EOF
	> 1..3
	> ok 1 - passing test #1
	> ok 2 - passing test #2
	> ok 3 - passing test #3
	> # full passed all 3 test(s)
	EOF
"

test_expect_success 'pretend we have a partially passing test suite' "
	test_must_fail run_sub_test_lib_test \
		partial-pass '2/3 tests passing' <<-\\EOF &&
	test_plan 3
	test_expect_success 'passing test #1' 'true'
	test_expect_success 'failing test #2' 'false'
	test_expect_success 'passing test #3' 'true'
	test_done
	EOF
	check_sub_test_lib_test partial-pass <<-\\EOF
	> 1..3
	> ok 1 - passing test #1
	> not ok 2 - failing test #2
	#      failed: partial-pass.sh: 2 - failing test #2
	#
	#      false
	#
	> ok 3 - passing test #3
	> # partial failed 1 among 3 test(s)
	EOF
"

test_expect_success 'pretend we have a known breakage' "
	run_sub_test_lib_test failing-todo 'A failing TODO test' <<-\\EOF &&
	test_plan 2
	test_expect_success 'passing test' 'true'
	test_expect_failure 'pretend we have a known breakage' 'false'
	test_done
	EOF
	check_sub_test_lib_test failing-todo <<-\\EOF
	> 1..2
	> ok 1 - passing test
	> not ok 2 - pretend we have a known breakage # TODO known breakage
	> # failing still have 1 known breakage(s)
	> # failing passed all remaining 1 test(s)
	EOF
"

test_expect_success 'pretend we have fixed a known breakage' "
	run_sub_test_lib_test passing-todo 'A passing TODO test' <<-\\EOF &&
	test_plan 1
	test_expect_failure 'pretend we have fixed a known breakage' 'true'
	test_done
	EOF
	check_sub_test_lib_test passing-todo <<-\\EOF
	> 1..1
	> ok 1 - pretend we have fixed a known breakage # TODO known breakage vanished
	> # passing 1 known breakage(s) vanished; please update test(s)
	EOF
"

test_expect_success 'pretend we have fixed one of two known breakages (run in sub test-lib)' "
	run_sub_test_lib_test partially-passing-todos \
		'2 TODO tests, one passing' <<-\\EOF &&
	test_plan 3
	test_expect_failure 'pretend we have a known breakage' 'false'
	test_expect_success 'pretend we have a passing test' 'true'
	test_expect_failure 'pretend we have fixed another known breakage' 'true'
	test_done
	EOF
	check_sub_test_lib_test partially-passing-todos <<-\\EOF
	> 1..3
	> not ok 1 - pretend we have a known breakage # TODO known breakage
	> ok 2 - pretend we have a passing test
	> ok 3 - pretend we have fixed another known breakage # TODO known breakage vanished
	> # partially 1 known breakage(s) vanished; please update test(s)
	> # partially still have 1 known breakage(s)
	> # partially passed all remaining 1 test(s)
	EOF
"

test_expect_success 'pretend we have a pass, fail, and known breakage' "
	test_must_fail run_sub_test_lib_test \
		mixed-results1 'mixed results #1' <<-\\EOF &&
	test_plan 3
	test_expect_success 'passing test' 'true'
	test_expect_success 'failing test' 'false'
	test_expect_failure 'pretend we have a known breakage' 'false'
	test_done
	EOF
	check_sub_test_lib_test mixed-results1 <<-\\EOF
	> 1..3
	> ok 1 - passing test
	> not ok 2 - failing test
	> #      failed: mixed-results1.sh: 2 - failing test
	> #
	> #      false
	> #
	> not ok 3 - pretend we have a known breakage # TODO known breakage
	> # mixed still have 1 known breakage(s)
	> # mixed failed 1 among remaining 2 test(s)
	EOF
"

test_expect_success 'pretend we have a mix of all possible results' "
	test_must_fail run_sub_test_lib_test \
		mixed-results2 'mixed results #2' <<-\\EOF &&
	test_plan 10
	test_expect_success 'passing test' 'true'
	test_expect_success 'passing test' 'true'
	test_expect_success 'passing test' 'true'
	test_expect_success 'passing test' 'true'
	test_expect_success 'failing test' 'false'
	test_expect_success 'failing test' 'false'
	test_expect_success 'failing test' 'false'
	test_expect_failure 'pretend we have a known breakage' 'false'
	test_expect_failure 'pretend we have a known breakage' 'false'
	test_expect_failure 'pretend we have fixed a known breakage' 'true'
	test_done
	EOF
	check_sub_test_lib_test mixed-results2 <<-\\EOF
	> 1..10
	> ok 1 - passing test
	> ok 2 - passing test
	> ok 3 - passing test
	> ok 4 - passing test
	> not ok 5 - failing test
	> #      failed: mixed-results2.sh: 5 - failing test
	> #
	> #      false
	> #
	> not ok 6 - failing test
	> #      failed: mixed-results2.sh: 6 - failing test
	> #
	> #      false
	> #
	> not ok 7 - failing test
	> #      failed: mixed-results2.sh: 7 - failing test
	> #
	> #      false
	> #
	> not ok 8 - pretend we have a known breakage # TODO known breakage
	> not ok 9 - pretend we have a known breakage # TODO known breakage
	> ok 10 - pretend we have fixed a known breakage # TODO known breakage vanished
	> # mixed 1 known breakage(s) vanished; please update test(s)
	> # mixed still have 2 known breakage(s)
	> # mixed failed 3 among remaining 7 test(s)
	EOF
"

test_expect_success 'test --verbose' '
	test_must_fail run_sub_test_lib_test \
		test-verbose "test verbose" --verbose <<-\EOF &&
	test_plan 3
	test_expect_success "passing test" true
	test_expect_success "test with output" "echo foo"
	test_expect_success "failing test" false
	test_done
	EOF
	mv test-verbose/out test-verbose/out+ &&
	grep -v "^Initialized empty" test-verbose/out+ >test-verbose/out &&
	check_sub_test_lib_test test-verbose <<-\EOF
	> 1..3
	> expecting success: true
	> ok 1 - passing test
	> Z
	> expecting success: echo foo
	> foo
	> ok 2 - test with output
	> Z
	> expecting success: false
	> not ok 3 - failing test
	> #      failed: test-verbose.sh: 3 - failing test
	> #
	> #      false
	> #
	> Z
	> # test failed 1 among 3 test(s)
	EOF
'

test_expect_success 'test --verbose-only' '
	test_must_fail run_sub_test_lib_test \
		test-verbose-only-2 "test verbose-only=2" \
		--verbose-only=2 <<-\EOF &&
	test_plan 3
	test_expect_success "passing test" true
	test_expect_success "test with output" "echo foo"
	test_expect_success "failing test" false
	test_done
	EOF
	check_sub_test_lib_test test-verbose-only-2 <<-\EOF
	> 1..3
	> ok 1 - passing test
	> Z
	> expecting success: echo foo
	> foo
	> ok 2 - test with output
	> Z
	> not ok 3 - failing test
	> #      failed: test-verbose-only-2.sh: 3 - failing test
	> #
	> #      false
	> #
	> # test failed 1 among 3 test(s)
	EOF
'

test_expect_success 'TESTLIB_SKIP_TESTS' "
	(
		TESTLIB_SKIP_TESTS='testlib.2' && export TESTLIB_SKIP_TESTS &&
		run_sub_test_lib_test testlib-skip-tests-basic \
			'TESTLIB_SKIP_TESTS' <<-\\EOF &&
		test_plan 3
		for i in 1 2 3
		do
			test_expect_success \"passing test #\$i\" 'true'
		done
		test_done
		EOF
		check_sub_test_lib_test testlib-skip-tests-basic <<-\\EOF
		> 1..3
		> ok 1 - passing test #1
		> ok 2 # skip passing test #2 (TESTLIB_SKIP_TESTS)
		> ok 3 - passing test #3
		> # testlib passed all 3 test(s)
		EOF
	)
"

test_expect_success 'TESTLIB_SKIP_TESTS several tests' "
	(
		TESTLIB_SKIP_TESTS='testlib.2 testlib.5' && export TESTLIB_SKIP_TESTS &&
		run_sub_test_lib_test testlib-skip-tests-several \
			'TESTLIB_SKIP_TESTS several tests' <<-\\EOF &&
		test_plan 6
		for i in 1 2 3 4 5 6
		do
			test_expect_success \"passing test #\$i\" 'true'
		done
		test_done
		EOF
		check_sub_test_lib_test testlib-skip-tests-several <<-\\EOF
		> 1..6
		> ok 1 - passing test #1
		> ok 2 # skip passing test #2 (TESTLIB_SKIP_TESTS)
		> ok 3 - passing test #3
		> ok 4 - passing test #4
		> ok 5 # skip passing test #5 (TESTLIB_SKIP_TESTS)
		> ok 6 - passing test #6
		> # testlib passed all 6 test(s)
		EOF
	)
"

test_expect_success 'TESTLIB_SKIP_TESTS sh pattern' "
	(
		TESTLIB_SKIP_TESTS='testlib.[2-5]' && export TESTLIB_SKIP_TESTS &&
		run_sub_test_lib_test testlib-skip-tests-sh-pattern \
			'TESTLIB_SKIP_TESTS sh pattern' <<-\\EOF &&
		test_plan 6
		for i in 1 2 3 4 5 6
		do
			test_expect_success \"passing test #\$i\" 'true'
		done
		test_done
		EOF
		check_sub_test_lib_test testlib-skip-tests-sh-pattern <<-\\EOF
		> 1..6
		> ok 1 - passing test #1
		> ok 2 # skip passing test #2 (TESTLIB_SKIP_TESTS)
		> ok 3 # skip passing test #3 (TESTLIB_SKIP_TESTS)
		> ok 4 # skip passing test #4 (TESTLIB_SKIP_TESTS)
		> ok 5 # skip passing test #5 (TESTLIB_SKIP_TESTS)
		> ok 6 - passing test #6
		> # testlib passed all 6 test(s)
		EOF
	)
"

test_expect_success '--run basic' "
	run_sub_test_lib_test run-basic \
		'--run basic' --run='1 3 5' --no-quiet <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-basic <<-\\EOF
	> 1..6
	> ok 1 - passing test #1
	> ok 2 # skip passing test #2 (--run)
	> ok 3 - passing test #3
	> ok 4 # skip passing test #4 (--run)
	> ok 5 - passing test #5
	> ok 6 # skip passing test #6 (--run)
	> # run passed all 6 test(s)
	EOF
"

test_expect_success '--run with a range' "
	run_sub_test_lib_test run-range \
		'--run with a range' --run='1-3' --no-quiet <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-range <<-\\EOF
	> 1..6
	> ok 1 - passing test #1
	> ok 2 - passing test #2
	> ok 3 - passing test #3
	> ok 4 # skip passing test #4 (--run)
	> ok 5 # skip passing test #5 (--run)
	> ok 6 # skip passing test #6 (--run)
	> # run passed all 6 test(s)
	EOF
"

test_expect_success '--run with two ranges' "
	run_sub_test_lib_test run-two-ranges \
		'--run with two ranges' --run='1-2 5-6' <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-two-ranges <<-\\EOF
	> ok 1 - passing test #1
	> ok 2 - passing test #2
	> ok 5 - passing test #5
	> ok 6 - passing test #6
	> # run passed all 6 test(s)
	> 1..6
	EOF
"

test_expect_success '--run with a left open range' "
	run_sub_test_lib_test run-left-open-range \
		'--run with a left open range' --run='-3' --no-quiet <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-left-open-range <<-\\EOF
	> 1..6
	> ok 1 - passing test #1
	> ok 2 - passing test #2
	> ok 3 - passing test #3
	> ok 4 # skip passing test #4 (--run)
	> ok 5 # skip passing test #5 (--run)
	> ok 6 # skip passing test #6 (--run)
	> # run passed all 6 test(s)
	EOF
"

test_expect_success '--run with a right open range' "
	run_sub_test_lib_test run-right-open-range \
		'--run with a right open range' --run='4-' --no-quiet <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-right-open-range <<-\\EOF
	> 1..6
	> ok 1 # skip passing test #1 (--run)
	> ok 2 # skip passing test #2 (--run)
	> ok 3 # skip passing test #3 (--run)
	> ok 4 - passing test #4
	> ok 5 - passing test #5
	> ok 6 - passing test #6
	> # run passed all 6 test(s)
	EOF
"

test_expect_success '--run with basic negation' "
	run_sub_test_lib_test run-basic-neg \
		'--run with basic negation' --run='"'!3'"' <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-basic-neg <<-\\EOF
	> ok 1 - passing test #1
	> ok 2 - passing test #2
	> ok 4 - passing test #4
	> ok 5 - passing test #5
	> ok 6 - passing test #6
	> # run passed all 6 test(s)
	> 1..6
	EOF
"

test_expect_success '--run with two negations' "
	run_sub_test_lib_test run-two-neg \
		'--run with two negations' --run='"'!3 !6'"' <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-two-neg <<-\\EOF
	> ok 1 - passing test #1
	> ok 2 - passing test #2
	> ok 4 - passing test #4
	> ok 5 - passing test #5
	> # run passed all 6 test(s)
	> 1..6
	EOF
"

test_expect_success '--run a range and negation' "
	run_sub_test_lib_test run-range-and-neg \
		'--run a range and negation' --run='"'-4 !2'"' --no-quiet <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-range-and-neg <<-\\EOF
	> 1..6
	> ok 1 - passing test #1
	> ok 2 # skip passing test #2 (--run)
	> ok 3 - passing test #3
	> ok 4 - passing test #4
	> ok 5 # skip passing test #5 (--run)
	> ok 6 # skip passing test #6 (--run)
	> # run passed all 6 test(s)
	EOF
"

test_expect_success '--run range negation' "
	run_sub_test_lib_test run-range-neg \
		'--run range negation' --run='"'!1-3'"' <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-range-neg <<-\\EOF
	> ok 4 - passing test #4
	> ok 5 - passing test #5
	> ok 6 - passing test #6
	> # run passed all 6 test(s)
	> 1..6
	EOF
"

test_expect_success '--run include, exclude and include' "
	run_sub_test_lib_test run-inc-neg-inc \
		'--run include, exclude and include' \
		--run='"'1-5 !1-3 2'"' <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-inc-neg-inc <<-\\EOF
	> ok 2 - passing test #2
	> ok 4 - passing test #4
	> ok 5 - passing test #5
	> # run passed all 6 test(s)
	> 1..6
	EOF
"

test_expect_success '--run include, exclude and include, comma separated' "
	run_sub_test_lib_test run-inc-neg-inc-comma \
		'--run include, exclude and include, comma separated' \
		--run=1-5,\!1-3,2 --no-quiet <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-inc-neg-inc-comma <<-\\EOF
	> 1..6
	> ok 1 # skip passing test #1 (--run)
	> ok 2 - passing test #2
	> ok 3 # skip passing test #3 (--run)
	> ok 4 - passing test #4
	> ok 5 - passing test #5
	> ok 6 # skip passing test #6 (--run)
	> # run passed all 6 test(s)
	EOF
"

test_expect_success '--run exclude and include' "
	run_sub_test_lib_test run-neg-inc \
		'--run exclude and include' \
		--run='"'!3- 5'"' <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-neg-inc <<-\\EOF
	> ok 1 - passing test #1
	> ok 2 - passing test #2
	> ok 5 - passing test #5
	> # run passed all 6 test(s)
	> 1..6
	EOF
"

test_expect_success '--run empty selectors' "
	run_sub_test_lib_test run-empty-sel \
		'--run empty selectors' \
		--run='1,,3,,,5' --no-quiet <<-\\EOF &&
	test_plan 6
	for i in 1 2 3 4 5 6
	do
		test_expect_success \"passing test #\$i\" 'true'
	done
	test_done
	EOF
	check_sub_test_lib_test run-empty-sel <<-\\EOF
	> 1..6
	> ok 1 - passing test #1
	> ok 2 # skip passing test #2 (--run)
	> ok 3 - passing test #3
	> ok 4 # skip passing test #4 (--run)
	> ok 5 - passing test #5
	> ok 6 # skip passing test #6 (--run)
	> # run passed all 6 test(s)
	EOF
"

test_expect_success '--run invalid range start' "
	run_sub_test_lib_test_err run-inv-range-start \
		'--run invalid range start' \
		--run='a-5' <<-\\EOF &&
	test_expect_success \"passing test #1\" 'true'
	test_done
	EOF
	check_sub_test_lib_test_err run-inv-range-start \
		<<-\\EOF_OUT 3<<-\\EOF_ERR
	> FATAL: Unexpected exit with code 1
	EOF_OUT
	> error: --run: invalid non-numeric in range start: 'a-5'
	EOF_ERR
"

test_expect_success '--run invalid range end' "
	run_sub_test_lib_test_err run-inv-range-end \
		'--run invalid range end' \
		--run='1-z' <<-\\EOF &&
	test_expect_success \"passing test #1\" 'true'
	test_done
	EOF
	check_sub_test_lib_test_err run-inv-range-end \
		<<-\\EOF_OUT 3<<-\\EOF_ERR
	> FATAL: Unexpected exit with code 1
	EOF_OUT
	> error: --run: invalid non-numeric in range end: '1-z'
	EOF_ERR
"

test_expect_success '--run invalid selector' "
	run_sub_test_lib_test_err run-inv-selector \
		'--run invalid selector' \
		--run='1?' <<-\\EOF &&
	test_expect_success \"passing test #1\" 'true'
	test_done
	EOF
	check_sub_test_lib_test_err run-inv-selector \
		<<-\\EOF_OUT 3<<-\\EOF_ERR
	> FATAL: Unexpected exit with code 1
	EOF_OUT
	> error: --run: invalid non-numeric in test selector: '1?'
	EOF_ERR
"


test_set_prereq HAVEIT
haveit=no
echo "$haveit" >haveit
test_expect_success HAVEIT 'test runs if prerequisite is satisfied' '
	test_have_prereq HAVEIT &&
	haveit=yes &&
	echo "$haveit" >haveit
'
donthaveit=yes
echo "$donthaveit" >donthaveit
test_expect_success DONTHAVEIT 'unmet prerequisite causes test to be skipped' '
	donthaveit=no &&
	echo "$donthaveit" >donthaveit
'
haveitf="$(cat haveit)"
donthaveitf="$(cat donthaveit)"
if test $haveit$donthaveit != noyes || test $haveitf$donthaveitf != yesyes
then
	say "bug in test framework: prerequisite tags do not work reliably"
	exit 1
fi

# Stop with the fussing with files
TESTLIB_TEST_NO_SUBSHELL=1

test_set_prereq HAVETHIS
haveit=no
test_expect_success HAVETHIS,HAVEIT 'test runs if prerequisites are satisfied' '
	test_have_prereq HAVEIT &&
	test_have_prereq HAVETHIS &&
	haveit=yes
'
donthaveit=yes
test_expect_success HAVEIT,DONTHAVEIT 'unmet prerequisites causes test to be skipped' '
	donthaveit=no
'
donthaveiteither=yes
test_expect_success DONTHAVEIT,HAVEIT 'unmet prerequisites causes test to be skipped' '
	donthaveiteither=no
'
if test $haveit$donthaveit$donthaveiteither != yesyesyes
then
	say "bug in test framework: multiple prerequisite tags do not work reliably"
	exit 1
fi

test_lazy_prereq LAZY_TRUE true
havetrue=no
test_expect_success LAZY_TRUE 'test runs if lazy prereq is satisfied' '
	havetrue=yes
'
donthavetrue=yes
test_expect_success !LAZY_TRUE 'missing lazy prereqs skip tests' '
	donthavetrue=no
'

if test "$havetrue$donthavetrue" != yesyes
then
	say 'bug in test framework: lazy prerequisites do not work'
	exit 1
fi

test_lazy_prereq LAZY_FALSE false
nothavefalse=no
test_expect_success !LAZY_FALSE 'negative lazy prereqs checked' '
	nothavefalse=yes
'
havefalse=yes
test_expect_success LAZY_FALSE 'missing negative lazy prereqs will skip' '
	havefalse=no
'

if test "$nothavefalse$havefalse" != yesyes
then
	say 'bug in test framework: negative lazy prerequisites do not work'
	exit 1
fi

# Mostly done with the no subshell tests
sane_unset TESTLIB_TEST_NO_SUBSHELL

clean=no
test_expect_success 'tests clean up after themselves' '
	test_when_finished clean=yes
'

if test $clean != yes
then
	say "bug in test framework: basic cleanup command does not work reliably"
	exit 1
fi

test_expect_success 'tests clean up even on failures' "
	test_must_fail run_sub_test_lib_test \
		failing-cleanup 'Failing tests with cleanup commands' <<-\\EOF &&
	test_plan 2
	test_expect_success 'tests clean up even after a failure' '
		touch clean-after-failure &&
		test_when_finished rm clean-after-failure &&
		(exit 1)
	'
	test_expect_success 'failure to clean up causes the test to fail' '
		test_when_finished eval \"(exit 2)\"
	'
	test_done
	EOF
	check_sub_test_lib_test failing-cleanup <<-\\EOF
	> 1..2
	> not ok 1 - tests clean up even after a failure
	> #      failed: failing-cleanup.sh: 1 - tests clean up even after a failure
	> #
	> #      touch clean-after-failure &&
	> #      test_when_finished rm clean-after-failure &&
	> #      (exit 1)
	> #
	> not ok 2 - failure to clean up causes the test to fail
	> #      failed: failing-cleanup.sh: 2 - failure to clean up causes the test to fail
	> #
	> #      test_when_finished eval \"(exit 2)\"
	> #
	> # failing failed 2 among 2 test(s)
	EOF
"

################################################################
# Basics of the basics

test_v_git_mt ZERO_OID null

test_asv_cache '
# These are some common invalid and partial object IDs used in tests.
001	sha1	0000000000000000000000000000000000000001
001	sha256	0000000000000000000000000000000000000000000000000000000000000001
002	sha1	0000000000000000000000000000000000000002
002	sha256	0000000000000000000000000000000000000000000000000000000000000002
003	sha1	0000000000000000000000000000000000000003
003	sha256	0000000000000000000000000000000000000000000000000000000000000003
004	sha1	0000000000000000000000000000000000000004
004	sha256	0000000000000000000000000000000000000000000000000000000000000004
005	sha1	0000000000000000000000000000000000000005
005	sha256	0000000000000000000000000000000000000000000000000000000000000005
'

test_asv_cache '
path0f sha1 f87290f8eb2cbbea7857214459a0739927eab154
path0f sha256 638106af7c38be056f3212cbd7ac65bc1bac74f420ca5a436ff006a9d025d17d

path0s sha1 15a98433ae33114b085f3eb3bb03b832b3180a01
path0s sha256 3a24cc53cf68edddac490bbf94a418a52932130541361f685df685e41dd6c363

path2f sha1 3feff949ed00a62d9f7af97c15cd8a30595e7ac7
path2f sha256 2a7f36571c6fdbaf0e3f62751a0b25a3f4c54d2d1137b3f4af9cb794bb498e5f

path2s sha1 d8ce161addc5173867a3c3c730924388daedbc38
path2s sha256 18fd611b787c2e938ddcc248fabe4d66a150f9364763e9ec133dd01d5bb7c65a

path2d sha1 58a09c23e2ca152193f2786e06986b7b6712bdbe
path2d sha256 00e4b32b96e7e3d65d79112dcbea53238a22715f896933a62b811377e2650c17

path3f sha1 0aa34cae68d0878578ad119c86ca2b5ed5b28376
path3f sha256 09f58616b951bd571b8cb9dc76d372fbb09ab99db2393f5ab3189d26c45099ad

path3s sha1 8599103969b43aff7e430efea79ca4636466794f
path3s sha256 fce1aed087c053306f3f74c32c1a838c662bbc4551a7ac2420f5d6eb061374d0

path3d sha1 21ae8269cacbe57ae09138dcc3a2887f904d02b3
path3d sha256 9b60497be959cb830bf3f0dc82bcc9ad9e925a24e480837ade46b2295e47efe1

subp3f sha1 00fb5908cb97c2564a9783c0c64087333b3b464f
subp3f sha256 a1a9e16998c988453f18313d10375ee1d0ddefe757e710dcae0d66aa1e0c58b3

subp3s sha1 6649a1ebe9e9f1c553b66f5a6e74136a07ccc57c
subp3s sha256 81759d9f5e93c6546ecfcadb560c1ff057314b09f93fe8ec06e2d8610d34ef10

subp3d sha1 3c5e5399f3a333eddecce7a9b9465b63f65f51e2
subp3d sha256 76b4ef482d4fa1c754390344cf3851c7f883b27cf9bc999c6547928c46aeafb7

root sha1 087704a96baf1c2d1c869a8b084481e121c88b5b
root sha256 9481b52abab1b2ffeedbf9de63ce422b929f179c1b98ff7bee5f8f1bc0710751

simpletree sha1 7bb943559a305bdd6bdee2cef6e5df2413c3d30a
simpletree sha256 1710c07a6c86f9a3c7376364df04c47ee39e5a5e221fcdd84b743bc9bb7e2bc5
'

# updating a new file without --add should fail.
test_expect_success 'git update-index without --add should fail adding' '
	test_must_fail git update-index should-be-empty
'

# and with --add it should succeed, even if it is empty (it used to fail).
test_expect_success 'git update-index with --add should succeed' '
	git update-index --add should-be-empty
'

TESTLIB_TEST_NO_SUBSHELL=1
test_expect_success 'writing tree out with git write-tree' '
	tree=$(git write-tree)
'
sane_unset TESTLIB_TEST_NO_SUBSHELL

# we know the shape and contents of the tree and know the object ID for it.
test_expect_success 'validate object ID of a known tree' '
	test "$tree" = "$(test_asv simpletree)"
    '

# Removing paths.
test_expect_success 'git update-index without --remove should fail removing' '
	rm -f should-be-empty full-of-directories &&
	test_must_fail git update-index should-be-empty
'

test_expect_success 'git update-index with --remove should be able to remove' '
	git update-index --remove should-be-empty
'

# Empty tree can be written with recent write-tree.
TESTLIB_TEST_NO_SUBSHELL=1
test_tolerate_failure 'git write-tree should be able to write an empty tree' '
	tree=$(git write-tree)
'
sane_unset TESTLIB_TEST_NO_SUBSHELL
test_v_git_mt EMPTY_TREE tree

if test -n "$tree"
then
	test_result='test_expect_success'
else
	test_result='test_tolerate_failure'
fi
$test_result 'validate object ID of a known tree' '
	test "$tree" = $EMPTY_TREE
'

# Various types of objects

test_expect_success 'adding various types of objects with git update-index --add' '
	mkdir path2 path3 path3/subp3 &&
	paths="path0 path2/file2 path3/file3 path3/subp3/file3" &&
	(
		for p in $paths
		do
			echo "hello $p" >$p || exit 1
			test_ln_s_add "hello $p" ${p}sym || exit 1
		done
	) &&
	find path* ! -type d -print | xargs git update-index --add
'

# Show them and see that matches what we expect.
test_expect_success 'showing stage with git ls-files --stage' '
	git ls-files --stage >current
'

test_expect_success 'validate git ls-files output for a known tree' '
	cat >expected <<-EOF &&
	100644 $(test_asv path0f) 0	path0
	120000 $(test_asv path0s) 0	path0sym
	100644 $(test_asv path2f) 0	path2/file2
	120000 $(test_asv path2s) 0	path2/file2sym
	100644 $(test_asv path3f) 0	path3/file3
	120000 $(test_asv path3s) 0	path3/file3sym
	100644 $(test_asv subp3f) 0	path3/subp3/file3
	120000 $(test_asv subp3s) 0	path3/subp3/file3sym
	EOF
	test_cmp expected current
'

TESTLIB_TEST_NO_SUBSHELL=1
test_expect_success 'writing tree out with git write-tree' '
	tree=$(git write-tree)
'
sane_unset TESTLIB_TEST_NO_SUBSHELL

test_expect_success 'validate object ID for a known tree' '
	test "$tree" = "$(test_asv root)"
'

test_expect_success 'showing tree with git ls-tree' '
    git ls-tree $tree >current
'

test_expect_success 'git ls-tree output for a known tree' '
	cat >expected <<-EOF &&
	100644 blob $(test_asv path0f)	path0
	120000 blob $(test_asv path0s)	path0sym
	040000 tree $(test_asv path2d)	path2
	040000 tree $(test_asv path3d)	path3
	EOF
	test_cmp expected current
'

# This changed in ls-tree pathspec change -- recursive does
# not show tree nodes anymore.
test_expect_success 'showing tree with git ls-tree -r' '
	git ls-tree -r $tree >current
'

test_expect_success 'git ls-tree -r output for a known tree' '
	cat >expected <<-EOF &&
	100644 blob $(test_asv path0f)	path0
	120000 blob $(test_asv path0s)	path0sym
	100644 blob $(test_asv path2f)	path2/file2
	120000 blob $(test_asv path2s)	path2/file2sym
	100644 blob $(test_asv path3f)	path3/file3
	120000 blob $(test_asv path3s)	path3/file3sym
	100644 blob $(test_asv subp3f)	path3/subp3/file3
	120000 blob $(test_asv subp3s)	path3/subp3/file3sym
	EOF
	test_cmp expected current
'

# But with -r -t we can have both.
test_expect_success 'showing tree with git ls-tree -r -t' '
	git ls-tree -r -t $tree >current
'

test_expect_success 'git ls-tree -r output for a known tree' '
	cat >expected <<-EOF &&
	100644 blob $(test_asv path0f)	path0
	120000 blob $(test_asv path0s)	path0sym
	040000 tree $(test_asv path2d)	path2
	100644 blob $(test_asv path2f)	path2/file2
	120000 blob $(test_asv path2s)	path2/file2sym
	040000 tree $(test_asv path3d)	path3
	100644 blob $(test_asv path3f)	path3/file3
	120000 blob $(test_asv path3s)	path3/file3sym
	040000 tree $(test_asv subp3d)	path3/subp3
	100644 blob $(test_asv subp3f)	path3/subp3/file3
	120000 blob $(test_asv subp3s)	path3/subp3/file3sym
	EOF
	test_cmp expected current
'

TESTLIB_TEST_NO_SUBSHELL=1
test_expect_success 'writing partial tree out with git write-tree --prefix' '
	ptree=$(git write-tree --prefix=path3)
'
sane_unset TESTLIB_TEST_NO_SUBSHELL

test_expect_success 'validate object ID for a known tree' '
	test "$ptree" = $(test_asv path3d)
'

TESTLIB_TEST_NO_SUBSHELL=1
test_expect_success 'writing partial tree out with git write-tree --prefix' '
	ptree=$(git write-tree --prefix=path3/subp3)
'
sane_unset TESTLIB_TEST_NO_SUBSHELL

test_expect_success 'validate object ID for a known tree' '
	test "$ptree" = $(test_asv subp3d)
'

test_expect_success 'put invalid objects into the index' '
	rm -f .git/index &&
	suffix=$(echo $ZERO_OID | sed -e "s/^.//") &&
	cat >badobjects <<-EOF &&
	100644 blob $(test_asv 001)	dir/file1
	100644 blob $(test_asv 002)	dir/file2
	100644 blob $(test_asv 003)	dir/file3
	100644 blob $(test_asv 004)	dir/file4
	100644 blob $(test_asv 005)	dir/file5
	EOF
	git update-index --index-info <badobjects
'

test_expect_success 'writing this tree without --missing-ok' '
	test_must_fail git write-tree
'

test_expect_success 'writing this tree with --missing-ok' '
	git write-tree --missing-ok
'


################################################################
test_expect_success 'git read-tree followed by write-tree should be idempotent' '
	rm -f .git/index &&
	git read-tree $tree &&
	test -f .git/index &&
	newtree=$(git write-tree) &&
	test "$newtree" = "$tree"
'

test_expect_success 'validate git diff-files output for a known cache/work tree state' '
	cat >expected <<EOF &&
:100644 100644 $(test_asv path0f) $ZERO_OID M	path0
:120000 120000 $(test_asv path0s) $ZERO_OID M	path0sym
:100644 100644 $(test_asv path2f) $ZERO_OID M	path2/file2
:120000 120000 $(test_asv path2s) $ZERO_OID M	path2/file2sym
:100644 100644 $(test_asv path3f) $ZERO_OID M	path3/file3
:120000 120000 $(test_asv path3s) $ZERO_OID M	path3/file3sym
:100644 100644 $(test_asv subp3f) $ZERO_OID M	path3/subp3/file3
:120000 120000 $(test_asv subp3s) $ZERO_OID M	path3/subp3/file3sym
EOF
	git diff-files >current &&
	test_cmp current expected
'

test_expect_success 'git update-index --refresh should succeed' '
	git update-index --refresh
'

test_expect_success 'no diff after checkout and git update-index --refresh' '
	git diff-files >current &&
	cmp -s current /dev/null
'

################################################################
P=$(test_asv root)

TESTLIB_TEST_NO_SUBSHELL=1
test_expect_success 'git commit-tree records the correct tree in a commit' '
	commit0=$(echo NO | git commit-tree $P) &&
	tree=$(git show --pretty=raw $commit0 |
		 sed -n -e "s/^tree //p" -e "/^author /q") &&
	test "z$tree" = "z$P"
'
sane_unset TESTLIB_TEST_NO_SUBSHELL

test_expect_success 'git commit-tree records the correct parent in a commit' '
	commit1=$(echo NO | git commit-tree $P -p $commit0) &&
	parent=$(git show --pretty=raw $commit1 |
		sed -n -e "s/^parent //p" -e "/^author /q") &&
	test "z$commit0" = "z$parent"
'

test_expect_success 'git commit-tree omits duplicated parent in a commit' '
	commit2=$(echo NO | git commit-tree $P -p $commit0 -p $commit0) &&
	     parent=$(git show --pretty=raw $commit2 |
		sed -n -e "s/^parent //p" -e "/^author /q" |
		sort -u) &&
	test "z$commit0" = "z$parent" &&
	numparent=$(git show --pretty=raw $commit2 |
		sed -n -e "s/^parent //p" -e "/^author /q" |
		wc -l) &&
	test $numparent = 1
'

test_expect_success 'update-index D/F conflict' '
	mv path0 tmp &&
	mv path2 path0 &&
	mv tmp path2 &&
	git update-index --add --replace path2 path0/file2 &&
	numpath0=$(git ls-files path0 | wc -l) &&
	test $numpath0 = 1
'

test_expect_success 'very long name in the index handled sanely' '

	a=a && # 1
	a=$a$a$a$a$a$a$a$a$a$a$a$a$a$a$a$a && # 16
	a=$a$a$a$a$a$a$a$a$a$a$a$a$a$a$a$a && # 256
	a=$a$a$a$a$a$a$a$a$a$a$a$a$a$a$a$a && # 4096
	a=${a}q &&

	>path4 &&
	git update-index --add path4 &&
	(
		git ls-files -s path4 |
		sed -e "s/	.*/	/" |
		tr -d "\012" &&
		echo "$a"
	) | git update-index --index-info &&
	len=$(git ls-files "a*" | wc -c) &&
	test $len = 4098
'

# git_add_config "some.var=value"
# every ' in value must be replaced with the 4-character sequence '\'' before
# calling this function or Git will barf.  Will not be effective unless running
# Git version 1.7.3 or later.
git_add_config() {
	GIT_CONFIG_PARAMETERS="${GIT_CONFIG_PARAMETERS:+$GIT_CONFIG_PARAMETERS }'$1'" &&
	export GIT_CONFIG_PARAMETERS
}

git_sane_get_config() {
	git config --get "$1" || :
}

test_expect_success 'GIT_CONFIG_PARAMETERS works as expected' '
	val1="$(git_sane_get_config testgcp.val1)" &&
	val2="$(git_sane_get_config testgcp.val2)" &&
	test -z "$val1" && test -z "$val2" &&
	git_add_config "testgcp.val1=value1" &&
	val1="$(git_sane_get_config testgcp.val1)" &&
	val2="$(git_sane_get_config testgcp.val2)" &&
	test x"$val1" = x"value1" && test -z "$val2" &&
	git_add_config "testgcp.val2=value too" &&
	val1="$(git_sane_get_config testgcp.val1)" &&
	val2="$(git_sane_get_config testgcp.val2)" &&
	test x"$val1" = x"value1" && test x"$val2" = x"value too"
'

test_done
