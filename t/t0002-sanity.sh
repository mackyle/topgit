#!/bin/sh

test_description='various sanity checks

Most of these are "tolerate_failure" checks
as there are workarounds in place for them.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 1

test_tolerate_failure 'POSIX unset behavior' '
	test z"$(unset it && unset it && echo good || echo bad)" = z"good"
'

test_done
