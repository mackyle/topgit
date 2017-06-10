#!/bin/sh

test_description='tg --top-bases gets the right answer

We also use this to test the functionality of the tg -c option.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 18

test_expect_success 'no repo refs bases default' '
	test_must_fail tg status >/dev/null 2>&1 &&
	test "$(tg --top-bases)" = "refs/top-bases"
'

test_expect_success 'no repo hard-coded refs bases' '
	test_must_fail tg status >/dev/null 2>&1 &&
	test_must_fail tg -c topgit.top-bases=bad --top-bases &&
	test "$(tg -c topgit.top-bases=refs --top-bases)" = "refs/top-bases" &&
	test "$(tg -c topgit.top-bases=heads -c topgit.top-bases=refs --top-bases)" = "refs/top-bases"
'

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

sane_unset tg_test_bases

test_expect_success '--top-bases -r fails with no remote' '
	test_must_fail tg -C noset-mt --top-bases -r &&
	test_must_fail tg -C noset-refs --top-bases -r &&
	test_must_fail tg -C noset-heads --top-bases -r &&
	test_must_fail tg -C noset-both --top-bases -r
'

test_expect_success '--top-bases -r succeeds with no remote refs' '
	tg -C noset-mt --top-bases -r origin &&
	result="$(tg -C noset-refs --top-bases -r origin)" &&
	test z"$result" = z"refs/remotes/origin/top-bases" &&
	result="$(tg -C noset-heads --top-bases -r origin)" &&
	test z"$result" = z"refs/remotes/origin/{top-bases}"
'

test_expect_success '--top-bases -r fails with schizo local bases' '
	test_must_fail tg -C noset-both --top-bases -r origin
'

test_expect_success 'setup remote branches' '
	tg_test_bases=refs &&
	tg_test_create_branch -C noset-mt rmtrefs:brefs :: &&
	tg_test_create_branch -C noset-mt rmtboth:brefs :: &&
	tg_test_create_branch -C noset-refs rmtrefs:brefs :: &&
	tg_test_create_branch -C noset-refs rmtboth:brefs :: &&
	tg_test_create_branch -C noset-heads rmtrefs:brefs :: &&
	tg_test_create_branch -C noset-heads rmtboth:brefs :: &&
	tg_test_create_branch -C noset-both rmtrefs:brefs :: &&
	tg_test_create_branch -C noset-both rmtboth:brefs :: &&
	tg_test_bases=heads &&
	tg_test_create_branch -C noset-mt rmtheads:bheads :: &&
	tg_test_create_branch -C noset-mt rmtboth:bheads :: &&
	tg_test_create_branch -C noset-refs rmtheads:bheads :: &&
	tg_test_create_branch -C noset-refs rmtboth:bheads :: &&
	tg_test_create_branch -C noset-heads rmtheads:bheads :: &&
	tg_test_create_branch -C noset-heads rmtboth:bheads :: &&
	tg_test_create_branch -C noset-both rmtheads:bheads :: &&
	tg_test_create_branch -C noset-both rmtboth:bheads :: &&
	unset tg_test_bases
'

test_expect_success '--top-bases -r fails with schizo local bases' '
	test_must_fail tg -C noset-both --top-bases -r origin
'

test_expect_success '--top-bases -r fails with schizo remote bases' '
	test_must_fail tg -C noset-mt --top-bases -r rmtboth
'

test_expect_success '--top-bases -r favors local bases location' '
	result="$(tg -C noset-refs -r rmtrefs --top-bases -r)" &&
	test z"$result" = z"refs/remotes/rmtrefs/top-bases" &&
	result="$(tg -C noset-refs -c topgit.remote=rmtheads --top-bases -r)" &&
	test z"$result" = z"refs/remotes/rmtheads/top-bases" &&
	result="$(tg -C noset-heads -c topgit.remote=rmtrefs --top-bases -r)" &&
	test z"$result" = z"refs/remotes/rmtrefs/{top-bases}" &&
	result="$(tg -C noset-heads -r rmtheads --top-bases -r)" &&
	test z"$result" = z"refs/remotes/rmtheads/{top-bases}"
'

test_expect_success '--top-bases -r autodetects remote bases location' '
	result="$(tg -C noset-mt --top-bases -r rmtrefs)" &&
	test z"$result" = z"refs/remotes/rmtrefs/top-bases" &&
	result="$(tg -C noset-mt --top-bases -r rmtheads)" &&
	test z"$result" = z"refs/remotes/rmtheads/{top-bases}"
'

test_expect_success '--top-bases -r topgit.top-bases override trumps all' '
	for repo in noset-mt noset-refs noset-heads noset-both; do
		for rmt in rmtrefs rmtheads rmtboth; do
			result="$(tg -c topgit.top-bases=refs -C "$repo" --top-bases -r "$rmt")" &&
			test z"$result" = z"refs/remotes/$rmt/top-bases" &&
			result="$(tg -c topgit.top-bases=heads -C "$repo" --top-bases -r "$rmt")" &&
			test z"$result" = z"refs/remotes/$rmt/{top-bases}"
		done
	done
'

test_done
