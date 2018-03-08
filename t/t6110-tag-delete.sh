#!/bin/sh

test_description='test tg tag --delete'

. ./test-lib.sh

test_plan 9

test_expect_success 'no delete unborn HEAD' '
	test_must_fail tg tag --delete HEAD &&
	test_must_fail tg tag --delete HEad &&
	test_must_fail tg tag --delete @
'

test_expect_success 'birth a HEAD' '
	test_commit "one head here" &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'no delete symref HEAD' '
	test_must_fail tg tag --delete HEAD &&
	test_must_fail tg tag --delete HEad &&
	test_must_fail tg tag --delete @
'

test_expect_success SETUP 'no delete symref HEAD offers advice' '
	test_must_fail tg tag --delete HEAD 2>advice &&
	grep -q "did you mean to delete \"master\"" advice &&
	test_must_fail tg tag --delete @ 2>advice &&
	grep -q "did you mean to delete \"master\"" advice
'

test_expect_success SETUP 'no delete detached HEAD' '
	git update-ref --no-deref HEAD HEAD HEAD &&
	test_must_fail tg tag --delete HEAD &&
	test_must_fail tg tag --delete HEad &&
	test_must_fail tg tag --delete @
'

test_expect_success SETUP 'reattach HEAD' '
	git symbolic-ref HEAD refs/heads/master
'

test_expect_success SETUP 'disallowed suffix offers advice' '
	test_must_fail tg tag --delete master@{0} 2>advice &&
	grep -q "try --drop" advice &&
	test_must_fail tg tag --clear master@{0} 2>advice &&
	grep -q "try --drop" advice
'

test_expect_success SETUP 'delete embedded symref only' '
	git symbolic-ref refs/remotes/origin/HEAD refs/heads/master &&
	tg tag --delete origin &&
	test_must_fail git rev-parse --quiet --verify refs/remotes/origin/HEAD -- &&
	git rev-parse --verify refs/heads/master -- >/dev/null &&
	git symbolic-ref refs/remotes/origin/HEAD refs/heads/master &&
	tg tag --delete origin/HEAD &&
	test_must_fail git rev-parse --quiet --verify refs/remotes/origin/HEAD -- &&
	git rev-parse --verify refs/heads/master -- >/dev/null &&
	git symbolic-ref refs/remotes/origin/HEAD refs/heads/master &&
	tg tag --delete remotes/origin/HEAD &&
	test_must_fail git rev-parse --quiet --verify refs/remotes/origin/HEAD -- &&
	git rev-parse --verify refs/heads/master -- >/dev/null &&
	git symbolic-ref refs/remotes/origin/HEAD refs/heads/master &&
	tg tag --delete refs/remotes/origin/HEAD &&
	test_must_fail git rev-parse --quiet --verify refs/remotes/origin/HEAD -- &&
	git rev-parse --verify refs/heads/master -- >/dev/null
'

test_expect_success SETUP 'delete normal branch' '
	test_must_fail tg tag --delete other >/dev/null 2>&1 &&
	git update-ref refs/heads/other master &&
	git rev-parse --verify --quiet other -- >/dev/null &&
	tg tag --delete other &&
	test_must_fail git rev-parse --verify --quiet heads/other -- >/dev/null &&
	test_must_fail tg tag --delete heads/other >/dev/null 2>&1 &&
	git update-ref refs/heads/other master &&
	git rev-parse --verify --quiet heads/other -- >/dev/null &&
	tg tag --delete heads/other &&
	test_must_fail git rev-parse --verify --quiet refs/heads/other -- >/dev/null &&
	test_must_fail tg tag --delete refs/heads/other >/dev/null 2>&1 &&
	git update-ref refs/heads/other master &&
	git rev-parse --verify --quiet refs/heads/other -- >/dev/null &&
	tg tag --delete refs/heads/other &&
	test_must_fail git rev-parse --verify --quiet refs/heads/other -- >/dev/null
'

test_done
