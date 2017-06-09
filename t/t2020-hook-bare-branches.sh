#!/bin/sh

test_description='verify hook support for bare branches'

. ./test-lib.sh

test_plan 6

# makes sure tg_test_setup_topgit will work on non-bin-wrappers testees
PATH="${TG_TEST_FULL_PATH%/*}:$PATH" && export PATH

test_expect_success 'setup' '
	tg_test_setup_topgit &&
	test_commit base &&
	tg_test_create_branch tgb ::master &&
	test_tick && test_when_finished test_tick=$test_tick &&
	git checkout tgb
'

test_expect_failure 'new bare commit allowed' '
	test_commit "commit on already bare branch should work" xyz
'

test_expect_success 'setup tag' '
	git tag start
'

test_expect_success 'bare forbids adding .topdeps' '
	git reset --hard start &&
	echo master >.topdeps &&
	git add .topdeps &&
	test_must_fail git commit -m "add .topdeps"
'

test_expect_success 'bare forbids adding .topmsg' '
	git reset --hard start &&
	echo foo >.topmsg &&
	git add .topmsg &&
	test_must_fail git commit -m "add .topmsg"
'

test_expect_failure 'bare forbids adding .topdeps & .topmsg' '
	git reset --hard start &&
	echo foo >.topmsg &&
	git add .topmsg &&
	echo master >.topdeps &&
	git add .topdeps &&
	test_must_fail git commit -m "add .topdeps & .topmsg"
'

test_done
