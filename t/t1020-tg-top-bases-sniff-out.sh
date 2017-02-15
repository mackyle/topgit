#!/bin/sh

test_description='tg --top-bases gets the right answer

We also use this to test the functionality of the tg -c option.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

GIT_CEILING_DIRECTORIES="$PWD" && export GIT_CEILING_DIRECTORIES

test_plan 7

test_expect_success 'test setup' '
	test_create_repo noset-mt &&
	test_create_repo noset-refs &&
	test_create_repo noset-heads &&
	test_create_repo noset-both &&
	test_create_repo refs &&
	test_create_repo heads &&
	git -C refs config topgit.top-bases refs &&
	git -C heads config topgit.top-bases heads &&
	test "$(cd refs && git config topgit.top-bases)" = "refs" &&
	test "$(cd heads && git config topgit.top-bases)" = "heads" &&
	test "$(cd noset-mt && git config --get topgit.top-bases)" = "" &&
	test "$(cd noset-refs && git config --get topgit.top-bases)" = "" &&
	test "$(cd noset-heads && git config --get topgit.top-bases)" = "" &&
	test "$(cd noset-both && git config --get topgit.top-bases)" = "" &&
	(cd noset-refs && test_commit initial) &&
	(cd noset-heads && test_commit initial) &&
	(cd noset-both && test_commit initial) &&
	git -C noset-refs update-ref refs/heads/t/branch master &&
	git -C noset-refs update-ref refs/top-bases/t/branch master &&
	git -C noset-heads update-ref refs/heads/t/branch master &&
	git -C noset-heads update-ref refs/heads/{top-bases}/t/branch master &&
	git -C noset-both update-ref refs/heads/t/branch master &&
	git -C noset-both update-ref refs/top-bases/t/branch master &&
	git -C noset-both update-ref refs/heads/{top-bases}/t/branch master &&
	git -C noset-refs rev-parse --verify t/branch >/dev/null &&
	git -C noset-refs rev-parse --verify top-bases/t/branch >/dev/null &&
	git -C noset-heads rev-parse --verify t/branch >/dev/null &&
	git -C noset-heads rev-parse --verify {top-bases}/t/branch >/dev/null &&
	git -C noset-both rev-parse --verify t/branch >/dev/null &&
	git -C noset-both rev-parse --verify top-bases/t/branch >/dev/null &&
	git -C noset-both rev-parse --verify {top-bases}/t/branch >/dev/null
'

test_expect_success 'hard-coded refs bases' '
	test "$(tg -C refs --top-bases)" = "refs/top-bases" &&
	test "$(tg -C noset-mt -c topgit.top-bases=refs --top-bases)" = "refs/top-bases" &&
	test "$(tg -C noset-mt -c topgit.top-bases=heads -c topgit.top-bases=refs --top-bases)" = "refs/top-bases"
'

test_expect_success 'hard-coded heads bases' '
	test "$(tg -C heads --top-bases)" = "refs/heads/{top-bases}" &&
	test "$(tg -C noset-mt -c topgit.top-bases=heads --top-bases)" = "refs/heads/{top-bases}" && 
	test "$(tg -C noset-mt -c topgit.top-bases=refs -c topgit.top-bases=heads --top-bases)" = "refs/heads/{top-bases}"
'

test_expect_success 'both is confusing and override' '
	test_must_fail tg -C noset-both --top-bases >/dev/null 2>&1 &&
	test "$(tg -C noset-both -c topgit.top-bases=refs --top-bases)" = "refs/top-bases" &&
	test "$(tg -C noset-both -c topgit.top-bases=heads --top-bases)" = "refs/heads/{top-bases}"
'

test_expect_success 'auto detect refs and override' '
	test "$(tg -C noset-refs --top-bases)" = "refs/top-bases" &&
	test "$(tg -C noset-refs -c topgit.top-bases=heads --top-bases)" = "refs/heads/{top-bases}"
'

test_expect_success 'auto detect heads and override' '
	test "$(tg -C noset-heads --top-bases)" = "refs/heads/{top-bases}" &&
	test "$(tg -C noset-heads -c topgit.top-bases=refs --top-bases)" = "refs/top-bases"
'

test_expect_success 'default is refs until 0.20.0' '
	test "$(tg -C noset-mt --top-bases)" = "refs/top-bases"
'

test_done
