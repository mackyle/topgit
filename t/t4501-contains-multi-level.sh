#!/bin/sh

test_description='tg contains multi-level

Test the behavior of tg contains when the branch
name and/or the remote name contains multiple
levels (i.e. separated with "/" components).
'

. ./test-lib.sh

test_plan 7

make_commits() {
	test_commit "${1}initial" &&
	test_commit "${1}a" && {
	br="$(git symbolic-ref -q HEAD)" ||
	br="$(git rev-parse --verify -q HEAD)"; } &&
	git checkout --detach -f HEAD^ &&
	test_commit "${1}b" &&
	mc="$(git rev-parse --verify HEAD)" &&
	git checkout -f "${br#refs/heads/}" &&
	git merge -m "merge ${1}a and ${1}b" "$mc" &&
	git tag "${1}m" &&
	test_commit "${1}after"
}

new_branch() {
	git checkout --detach empty &&
	{ git update-ref -d "refs/heads/$1" >/dev/null 2>&1 || :; } &&
	git checkout --orphan "$1"
}

test_expect_success 'setup' '
	git config core.logallrefupdates false &&
	git config advice.detachedHead false &&
	git checkout --orphan empty &&
	test_tick &&
	git commit --allow-empty -m empty &&
	mtc="$(git rev-parse --verify HEAD)" &&
	git tag empty &&
	git checkout --orphan build &&
	git update-ref -d refs/heads/empty &&
	# first/second/third/fourth
	new_branch build &&
	make_commits "fstfpre" &&
	tg_test_create_branch first/second/third/fourth :HEAD &&
	git checkout -f first/second/third/fourth &&
	make_commits "fstf" &&
	git checkout -f -B build &&
	make_commits "fstfpost" &&
	# unu alpha
	new_branch build &&
	make_commits "uapre" &&
	tg_test_create_branch alpha:unu :HEAD &&
	git update-ref HEAD refs/remotes/alpha/unu &&
	make_commits "unu@alpha" &&
	git update-ref refs/remotes/alpha/unu HEAD &&
	make_commits "uapost" &&
	# du/tri/kvar alpha
	new_branch build &&
	make_commits "dtkapre" &&
	tg_test_create_branch alpha:du/tri/kvar :HEAD &&
	git update-ref HEAD refs/remotes/alpha/du/tri/kvar &&
	make_commits "du_tri_kvar@alpha" &&
	git update-ref refs/remotes/alpha/du/tri/kvar HEAD &&
	make_commits "dtkapost" &&
	# unu beta/gamma/delta
	new_branch build &&
	make_commits "ubgdpre" &&
	tg_test_create_branch beta/gamma/delta:unu :HEAD &&
	git update-ref HEAD refs/remotes/beta/gamma/delta/unu &&
	make_commits "unu@beta_gamma_delta" &&
	git update-ref refs/remotes/beta/gamma/delta/unu HEAD &&
	make_commits "ubgdpost" &&
	# du/tri/kvar beta/gamma/delta
	new_branch build &&
	make_commits "dtkbgdpre" &&
	tg_test_create_branch beta/gamma/delta:du/tri/kvar :HEAD &&
	git update-ref HEAD refs/remotes/beta/gamma/delta/du/tri/kvar &&
	make_commits "du_tri_kvar@beta_gamma_delta" &&
	git update-ref refs/remotes/beta/gamma/delta/du/tri/kvar HEAD &&
	make_commits "dtkbgdpost" &&
	git checkout -f empty &&
	git update-ref -d refs/heads/build &&
	git repack -a -d &&
	git pack-refs --prune --all &&
	refcnt=$(git for-each-ref | wc -l) &&
	test "$refcnt" = 86 &&
	topbases="$(tg --top-bases)" &&
	topbases="${topbases#refs/}" &&
	test -n "$topbases" &&
	test_when_finished topbases="$topbases" &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'non-remote multi-level contains' '
	h="$(git rev-parse --verify -q fstfb)" &&
	tb="$(tg contains -v -r --ann $h)" &&
	test "$tb" = "first/second/third/fourth [first/second/third/fourth]"
'

test_expect_success SETUP 'non-remote multi-level contains --no-strict' '
	h="$(git rev-parse --verify -q fstfpreb)" &&
	{ tb="$(tg contains -v --strict -r --ann $h)" || :; } &&
	test -z "$tb" &&
	tb="$(tg contains -v --no-strict -r --ann $h)" &&
	test "$tb" = "first/second/third/fourth [first/second/third/fourth]"
'

test_expect_success SETUP 'remote single-level contains fails without -r' '
	h="$(git rev-parse --verify -q unu@alpham)" &&
	{ tb="$(tg contains -v --strict --ann $h)" || :; } &&
	test -z "$tb" &&
	{ tb="$(tg contains -v --no-strict --ann $h)" || :; } &&
	test -z "$tb" &&
	tb="$(tg contains -v --strict -r --ann $h)" &&
	test "$tb" = "remotes/alpha/unu" &&
	tb="$(tg contains -v --no-strict -r --ann $h)" &&
	test "$tb" = "remotes/alpha/unu"
'

test_expect_success SETUP 'remote multi-level branch single-level remote' '
	h="$(git rev-parse --verify -q du_tri_kvar@alphab)" &&
	tb="$(tg contains -v --strict -r --ann $h)" &&
	test "$tb" = "remotes/alpha/du/tri/kvar" &&
	tb="$(tg contains -v --no-strict -r --ann $h)" &&
	test "$tb" = "remotes/alpha/du/tri/kvar"
'

test_expect_failure SETUP 'remote single-level branch multi-level remote' '
	h="$(git rev-parse --verify -q unu@beta_gamma_deltaa)" &&
	tb="$(tg contains -v --strict -r --ann $h)" &&
	test "$tb" = "remotes/beta/gamma/delta/unu" &&
	tb="$(tg contains -v --no-strict -r --ann $h)" &&
	test "$tb" = "remotes/beta/gamma/delta/unu"
'

test_expect_failure SETUP 'remote multi-level branch multi-level remote' '
	h="$(git rev-parse --verify -q du_tri_kvar@beta_gamma_deltam)" &&
	tb="$(tg contains -v --strict -r --ann $h)" &&
	test "$tb" = "remotes/beta/gamma/delta/du/tri/kvar" &&
	tb="$(tg contains -v --no-strict -r --ann $h)" &&
	test "$tb" = "remotes/beta/gamma/delta/du/tri/kvar"
'

test_done
