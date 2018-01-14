#!/bin/sh

test_description='unrelated orphan branches update okay'

. ./test-lib.sh

test_plan 4

test_expect_success 'setup' '
	git config rerere.enabled 1 &&
	git checkout --orphan t/branch &&
	tg create --no-deps --topmsg branch HEAD &&
	git checkout --orphan master &&
	git read-tree --empty &&
	git clean -f -q &&
	echo new one > new &&
	git add new &&
	git commit -m new1 &&
	git checkout --orphan master2 &&
	git read-tree --empty &&
	git clean -f -q &&
	echo new two > new &&
	git add new &&
	git commit -m new2
'

test_expect_success LASTOK 'add dependencies' '
	tg checkout -f t/branch &&
	git clean -f -q &&
	tg depend add --no-update master master2
'

test_expect_success LASTOK 'create resolution' '
	test_must_fail tg update t/branch &&
	echo new one > new &&
	echo new two >> new &&
	git add new &&
	git commit -m resolved &&
	tg update --abort
'

test_expect_success LASTOK 'update' '
	tg update t/branch
'

test_done
