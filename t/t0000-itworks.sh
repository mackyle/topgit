#!/bin/sh

TEST_NO_CREATE_REPO=1

test_description='Test sanity of test framework.'

. ./test-lib.sh

subshell="$(cat <<'TEST'

	exec <>/dev/tty >&0 2>&1 &&
	echo "Hi!  You're in a subshell now!" &&
	PS1='(subshell)$ ' && export PS1 &&
	"${SHELL:-/bin/sh}" -i
TEST
)$LF"

#test_expect_success 'a sub shell' "$subshell"
test_expect_success 'it works' ':'
#test_tolerate_failure 'it fails' '! :'

test_done
