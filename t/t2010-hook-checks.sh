#!/bin/sh

test_description='verify hook restrictions are working'

. ./test-lib.sh

test_plan 13

# makes sure tg_test_setup_topgit will work on non-bin-wrappers testees
PATH="${TG_TEST_FULL_PATH%/*}:$PATH" && export PATH

test_expect_success 'setup' '
	tg_test_setup_topgit &&
	test_commit base &&
	git branch master2 &&
	tg_test_create_branch tgb1 master &&
	tg_test_create_branch tgb2 tgb1 &&
	test_tick && test_when_finished test_tick=$test_tick &&
	git checkout tgb1
'

test_expect_success '.topdeps required' '
	git reset --hard &&
	git rm .topdeps &&
	test_must_fail git commit -m "remove .topdeps"
'

test_expect_success '.topmsg required' '
	git reset --hard &&
	git rm .topmsg &&
	test_must_fail git commit -m "remove .topmsg"
'

test_expect_success '.topdeps & .topmsg required' '
	git reset --hard &&
	git rm .topdeps .topmsg &&
	test_must_fail git commit -m "remove .topdeps & .topmsg"
'

test_expect_success 'unknown .topdeps branch forbidden' '
	git reset --hard &&
	echo foo >> .topdeps &&
	git add .topdeps &&
	test_must_fail git commit -m "add unknown branch"
'

test_expect_success 'unknown .topdeps branch w/o nl forbidden' '
	git reset --hard &&
	printf "%s" foo >> .topdeps &&
	git add .topdeps &&
	test_must_fail git commit -m "add unknown branch"
'

test_expect_success 'duplicate .topdeps branch forbidden' '
	git reset --hard &&
	echo master >> .topdeps &&
	git add .topdeps &&
	test_must_fail git commit -m "add duplicate branch"
'

test_expect_success 'duplicate .topdeps branch w/o nl forbidden' '
	git reset --hard &&
	printf "%s" master >> .topdeps &&
	git add .topdeps &&
	test_must_fail git commit -m "add duplicate branch"
'

test_expect_success 'looping .topdeps branch forbidden' '
	git reset --hard &&
	echo tgb2 >> .topdeps &&
	git add .topdeps &&
	test_must_fail git commit -m "add looping branch"
'

test_expect_success 'looping .topdeps branch w/o nl forbidden' '
	git reset --hard &&
	printf "%s" tgb2 >> .topdeps &&
	git add .topdeps &&
	test_must_fail git commit -m "add looping branch"
'

test_expect_success 'existing branch .topdeps addition okay' '
	git reset --hard &&
	echo master2 >> .topdeps &&
	git add .topdeps &&
	git commit -m "add known branch"
'

test_expect_success '.topdeps can be empty' '
	git reset --hard &&
	rm -f .topdeps &&
	touch .topdeps &&
	git add .topdeps &&
	git commit -m "empty out .topdeps"
'

test_expect_success '.topmsg cannot be empty' '
	git reset --hard &&
	rm -f .topmsg &&
	touch .topmsg &&
	git add .topmsg &&
	test_must_fail git commit -m "empty out .topmsg"
'

test_done
