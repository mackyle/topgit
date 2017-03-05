#!/bin/sh

TEST_NO_CREATE_REPO=1

test_description='Test sanity of test framework

1 - it works

    Just a basic test that always succeeds

2 - it works on stdin

    Another basic test but read using the magic -

3 - empty test fails

    An empty test script does not change the exit code and
    the testing library arranges for the exit code to be 1
    at the beginning of the test so an empty test should
    always fail

4 - git rev-parse --git-dir fails

    GIT_CEILING_DIRECTORIES should be set properly to avoid
    finding the repository containing the tests themselves
    so verify that it does indeed fail.
'

. ./test-lib.sh

test_plan 4

test_expect_success 'it works' ':'
test_expect_success 'it works on stdin' - <<-'EOT'
	: && # no more quoting issues but 'tis a bit slower!
	:    # unpaired " are allowed too!
EOT
test_expect_failure 'empty test fails' ''
test_expect_success 'git rev-parse --git-dir fails' '
	test_must_fail git rev-parse --git-dir
'

test_done
