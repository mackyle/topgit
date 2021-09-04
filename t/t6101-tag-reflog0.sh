#!/bin/sh

test_description='check tg tag reflog @{0} drops'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

if vcmp "$git_version" '>=' "2.5"; then
	test_set_prereq "GIT_2_5"
fi

git_231_plus=
if vcmp "$git_version" '>=' "2.31"; then
	git_231_plus=1
fi

test_plan 7

# replace `git symbolic-ref HEAD refs/heads/foo`
# with `sane_reattach_ref HEAD refs/heads/foo`
sane_reattach_ref() {
	_rlc="$(git reflog show "$1" -- | wc -l)" &&
	git symbolic-ref "$1" "$2" &&
	_rlc2="$(git reflog show "$1" -- | wc -l)" &&
	if test x"$_rlc" != x"$_rlc2"; then
		git reflog delete "$1@{0}" &&
		_rlc2="$(git reflog show "$1" -- | wc -l)" &&
		test x"$_rlc" = x"$_rlc2"
	fi
}

test_expect_success 'setup main' '
	test_create_repo main &&
	cd main &&
	git checkout --orphan slithy &&
	test_commit sfile1 &&
	test_commit sfile2 &&
	test_commit sfile3 &&
	test_commit sfile4 &&
	test_commit sfile5 &&
	rlcnt=$(git log --oneline -g slithy | wc -l) &&
	test $rlcnt -eq 5 &&
	git reflog delete slithy@{4} &&
	git reflog delete slithy@{2} &&
	git reflog delete slithy@{0} &&
	rlcnt=$(git log --oneline -g slithy | wc -l) &&
	test $rlcnt -eq 2 &&
	while git rev-parse --verify --quiet HEAD@{1} --; do
		git reflog delete HEAD@{0} >/dev/null 2>&1 || :
	done &&
	{ git reflog delete HEAD@{0} >/dev/null 2>&1 || :; } &&
	git checkout --orphan frabjous &&
	# there might, or might not be a garbage @{0} entry in the reflog for HEAD
	{ git reflog delete HEAD@{0} >/dev/null 2>&1 || :; } &&
	test_commit file1 &&
	test_commit file2 &&
	test_commit file3 &&
	test_commit file4 &&
	test_commit file5 &&
	rlcnt=$(git log --oneline -g HEAD | wc -l) &&
	test $rlcnt -eq 5 &&
	git reflog delete HEAD@{4} &&
	git reflog delete HEAD@{2} &&
	git reflog delete HEAD@{0} &&
	rlcnt=$(git log --oneline -g HEAD | wc -l) &&
	test $rlcnt -eq 2 &&
	test_when_finished test_tick=$test_tick
'

test_expect_success 'LASTOK GIT_2_5' 'setup linked' '
	cd main &&
	mttree="$(git mktree </dev/null)" &&
	test -n "$mttree" &&
	test_tick &&
	mtcommit="$(git commit-tree -m "empty commit" "$mttree")" &&
	test -n "$mtcommit" &&
	cd .. &&
	git --git-dir=main/.git worktree add --detach linked "$mtcommit" &&
	cd linked &&
	# there might, or might not be a garbage @{0} entry in the reflog for HEAD
	{ git reflog delete HEAD@{0} >/dev/null 2>&1 || :; } &&
	git checkout --orphan outgrabe &&
	test_commit ofile1 &&
	test_commit ofile2 &&
	test_commit ofile3 &&
	test_commit ofile4 &&
	test_commit ofile5 &&
	rlcnt=$(git log --oneline -g outgrabe | wc -l) &&
	test $rlcnt -eq 5 &&
	git reflog delete outgrabe@{4} &&
	git reflog delete outgrabe@{2} &&
	git reflog delete outgrabe@{0} &&
	rlcnt=$(git log --oneline -g outgrabe | wc -l) &&
	test $rlcnt -eq 2 &&
	while git rev-parse --verify --quiet HEAD@{1} --; do
		git reflog delete HEAD@{0} >/dev/null 2>&1 || :
	done &&
	{ git reflog delete HEAD@{0} >/dev/null 2>&1 || :; } &&
	git checkout --orphan linked &&
	# there might, or might not be a garbage @{0} entry in the reflog for HEAD
	{ git reflog delete HEAD@{0} >/dev/null 2>&1 || :; } &&
	test_commit lfile1 &&
	test_commit lfile2 &&
	test_commit lfile3 &&
	test_commit lfile4 &&
	test_commit lfile5 &&
	rlcnt=$(git log --oneline -g HEAD | wc -l) &&
	test $rlcnt -eq 5 &&
	git reflog delete HEAD@{4} &&
	git reflog delete HEAD@{2} &&
	git reflog delete HEAD@{0} &&
	rlcnt=$(git log --oneline -g HEAD | wc -l) &&
	test $rlcnt -eq 2 &&
	test_when_finished test_tick=$test_tick
'

test_expect_success LASTOK 'verify setup' '
	cd main &&
	mh="$(git rev-parse --verify HEAD --)" &&
	test -n "$mh" &&
	mh0="$(git rev-parse --verify HEAD@{0} --)" &&
	test -n "$mh0" &&
	sh="$(git rev-parse --verify slithy --)" &&
	test -n "$sh" &&
	sh0="$(git rev-parse --verify slithy@{0} --)" &&
	test -n "$sh0" &&
	if test_have_prereq GIT_2_5; then
		cd ../linked &&
		lh="$(git rev-parse --verify HEAD --)" &&
		test -n "$lh" &&
		lh0="$(git rev-parse --verify HEAD@{0} --)" &&
		test -n "$lh0" &&
		oh="$(git rev-parse --verify outgrabe --)" &&
		test -n "$oh" &&
		oh0="$(git rev-parse --verify outgrabe@{0} --)" &&
		test -n "$oh0" &&
		cd ../main
	else
		lh="not" &&
		lh0="available" &&
		oh="no" &&
		oh0="linked worktrees"
	fi &&
	if
		test "$mh0" != "$mh" && test "$sh0" != "$sh" &&
		test "$lh0" != "$lh" && test "$oh0" != "$oh"
	then
		test_when_finished test_set_prereq AT0DISTINCT
	fi
'

test_expect_success AT0DISTINCT 'ref [symref] preserved when dropping different @{0}' '
	cd main &&
	h="$(git rev-parse --verify HEAD --)" &&
	test -n "$h" &&
	h0="$(git rev-parse --verify HEAD@{0} --)" &&
	test -n "$h0" &&
	test "$h" != "$h0" &&
	tgx tag --drop HEAD@{0} &&
	hp="$(git rev-parse --verify HEAD --)" &&
	test -n "$hp" &&
	h0p="$(git rev-parse --verify HEAD@{0} --)" &&
	test -n "$h0p" &&
	test "$h" = "$hp" &&
	test "$h0p" != "$h0"
'

test_expect_success AT0DISTINCT,GIT_2_5 'ref [symref] preserved when dropping different @{0} [linked]' '
	cd linked &&
	h="$(git rev-parse --verify HEAD --)" &&
	test -n "$h" &&
	h0="$(git rev-parse --verify HEAD@{0} --)" &&
	test -n "$h0" &&
	test "$h" != "$h0" &&
	tg tag --drop HEAD@{0} &&
	hp="$(git rev-parse --verify HEAD --)" &&
	test -n "$hp" &&
	h0p="$(git rev-parse --verify HEAD@{0} --)" &&
	test -n "$h0p" &&
	test "$h" = "$hp" &&
	test "$h0p" != "$h0"
'

test_expect_success AT0DISTINCT 'ref [actual] preserved when dropping different @{0}' '
	cd main &&
	h="$(git rev-parse --verify slithy --)" &&
	test -n "$h" &&
	h0="$(git rev-parse --verify slithy@{0} --)" &&
	test -n "$h0" &&
	test "$h" != "$h0" &&
	tgx tag --drop slithy@{0} &&
	hp="$(git rev-parse --verify slithy --)" &&
	test -n "$hp" &&
	h0p="$(git rev-parse --verify slithy@{0} --)" &&
	test -n "$h0p" &&
	test "$h" = "$hp" &&
	test "$h0p" != "$h0"
'

test_expect_success AT0DISTINCT,GIT_2_5 'ref [actual] preserved when dropping different @{0} [linked]' '
	cd linked &&
	h="$(git rev-parse --verify outgrabe --)" &&
	test -n "$h" &&
	h0="$(git rev-parse --verify outgrabe@{0} --)" &&
	test -n "$h0" &&
	test "$h" != "$h0" &&
	tg tag --drop outgrabe@{0} &&
	hp="$(git rev-parse --verify outgrabe --)" &&
	test -n "$hp" &&
	h0p="$(git rev-parse --verify outgrabe@{0} --)" &&
	test -n "$h0p" &&
	test "$h" = "$hp" &&
	test "$h0p" != "$h0"
'

test_done
