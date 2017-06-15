#!/bin/sh

test_description='test miscellaneous tg.sh behaviors'

. ./test-lib.sh

test_plan 1

test_expect_success 'no empty GIT_OBJECT_DIRECTORY' '
	tg_test_include &&
	{
		test z"${GIT_OBJECT_DIRECTORY}" != z ||
		test z"${GIT_OBJECT_DIRECTORY+set}" != z"set"
	} &&
	test_must_fail printenv GIT_OBJECT_DIRECTORY >/dev/null
'

test_done
