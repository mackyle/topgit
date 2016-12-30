#!/bin/sh

TEST_NO_CREATE_REPO=1

test_description='Test sanity of test framework

1 - it works

    Just a basic test that always succeeds

2 - it works on stdin

    Another basic test but read using the magic -
'

. ./test-lib.sh

test_expect_success 'it works' ':'
test_expect_success 'it works on stdin' - <<-'EOT'
	: && # no more quoting issues but 'tis a bit slower!
	:    # unpaired " are allowed too!
EOT

test_done
