#!/bin/sh

test_description='basic tg do-nothing commands work anywhere

The basic `tg version` `tg precheck` and friends should all work just fine
in or not in a Git repository without complaint.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 8

test_expect_success 'test setup' '
	mkdir norepo &&
	test_create_repo repo
'

test_expect_success 'version' '
	(cd norepo && test -n "$(tg version)") &&
	(cd repo && test -n "$(tg version)")
'

test_expect_success 'precheck' '
	(cd norepo && tg precheck) &&
	(cd repo && tg precheck)
'

test_expect_success 'hook include' '
	tg__include=1 && export tg__include &&
	(cd norepo && test_might_fail tg 2>/dev/null) &&
	(cd repo && tg)
'

test_expect_success 'hooks path' '
	(cd norepo && test -d "$(tg --hooks-path)") &&
	(cd repo && test -d "$(tg --hooks-path)")
'	

test_expect_success 'help outside repo' '
	cd norepo &&
	tg help >/dev/null &&
	tg -h >/dev/null &&
	tg --help >/dev/null &&
	tg help tg >/dev/null
'

test_expect_success 'help inside repo' '
	cd repo &&
	tg help >/dev/null &&
	tg -h >/dev/null &&
	tg --help >/dev/null &&
	tg help tg >/dev/null
'

test_expect_success 'bad options' '
	(
		cd norepo &&
		test_must_fail tg --no-such-option &&
		test_must_fail tg -r &&
		test_must_fail tg -C &&
		test_must_fail tg -c
	) >/dev/null 2>&1 &&
	(
		cd repo &&
		test_must_fail tg --no-such-option &&
		test_must_fail tg -r &&
		test_must_fail tg -C &&
		test_must_fail tg -c
	) >/dev/null 2>&1
'

test_done
