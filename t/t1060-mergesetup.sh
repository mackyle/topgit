#!/bin/sh

test_description='test tg merge setup behavior

All non-read-only tg commands set up the merge configuration as well
as the pre-commit hook and repository attributes.  This is called
the "mergesetup".

Make sure it works properly in a top-level as well as subdirectory.
It probably should not work in a bare repo but it does so test that too.

The Git 2.5+ worktree stuff also throws a wrench into things.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

if vcmp "$git_version" '>=' "2.5"; then
	test_set_prereq GIT_2_5
fi

if vcmp "$git_version" '>=' "2.9"; then
	test_set_prereq GIT_2_9
fi

test_plan 10

# Note that the initial branch name in bare.git does
# not affect these tests in any way
test_expect_success 'test setup' '
	git init --bare --quiet --template="$EMPTY_DIRECTORY" bare.git &&
	test_create_repo r1 &&
	test_create_repo r2 &&
	mkdir r2/subdir &&
	test_create_repo r3 &&
	(cd r3 && test_commit initial) &&
	test_create_repo r4 &&
	mkdir r4/subdir &&
	(cd r4 && test_commit initial)
'

test_expect_success GIT_2_5 'test setup worktrees' '
	git -C r3 worktree add "$PWD/w3" >/dev/null 2>&1 &&
	git -C r4 worktree add "$PWD/w4" >/dev/null 2>&1 &&
	mkdir w4/subdir
'

test_expect_success GIT_2_9 'test setup hookspath' '
	test_create_repo hooksrepo &&
	mkdir hookspath &&
	git -C hooksrepo config core.hooksPath "$PWD/hookspath"
'

test_expect_failure GIT_2_5 'rev-parse --git-common-dir is broken!' '
	gcd="$(cd r2/subdir && git rev-parse --git-common-dir)" &&
	test -n "$gcd" &&
	test -d "$gcd" &&
	test "$(cd "$gcd" && pwd -P)" = "$(cd r2/.git && pwd -P)"
'

mergesetup_is_ok() {
	test -n "$(git -C "$1" config --get merge.ours.name)" &&
	test -n "$(git -C "$1" config --get merge.ours.driver)" &&
	test -s "$1/info/attributes" &&
	test -s "${2:-$1/hooks}/pre-commit" &&
	test -f "${2:-$1/hooks}/pre-commit" &&
	test -x "${2:-$1/hooks}/pre-commit" &&
	grep -q .topmsg "$1/info/attributes" &&
	grep -q .topdeps "$1/info/attributes" &&
	grep -q -- --hooks-path "${2:-$1/hooks}/pre-commit"
}

do_mergesetup() {
	test_might_fail tg -C "$1" update no-such-branch-name >/dev/null 2>&1
}

test_expect_success 'no bare mergesetup' '
	test_must_fail mergesetup_is_ok bare.git &&
	do_mergesetup bare.git &&
	test_must_fail mergesetup_is_ok bare.git
'

test_expect_success 'mergesetup normal top level' '
	test_must_fail mergesetup_is_ok r1/.git &&
	do_mergesetup r1 &&
	mergesetup_is_ok r1/.git
'

test_expect_success 'mergesetup normal subdir' '
	test_must_fail mergesetup_is_ok r2/.git &&
	do_mergesetup r2/subdir &&
	mergesetup_is_ok r2/.git
'

test_expect_success GIT_2_5 'mergesetup worktree top level' '
	test_must_fail mergesetup_is_ok r3/.git &&
	do_mergesetup w3 &&
	mergesetup_is_ok r3/.git
'

test_expect_success GIT_2_5 'mergesetup worktree subdir' '
	test_must_fail mergesetup_is_ok r4/.git &&
	do_mergesetup w4/subdir &&
	mergesetup_is_ok r4/.git
'

test_expect_success GIT_2_9 'mergesetup hookspath' '
	test_must_fail mergesetup_is_ok hooksrepo/.git hookspath &&
	do_mergesetup hooksrepo &&
	mergesetup_is_ok hooksrepo/.git hookspath
'

test_done
