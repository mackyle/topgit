#!/bin/sh

test_description='tg contains'

. ./test-lib.sh

test_plan 19

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
	git config topgit.remote origin &&
	git checkout --orphan empty &&
	test_tick &&
	git commit --allow-empty -m empty &&
	mtc="$(git rev-parse --verify HEAD)" &&
	git tag empty &&
	git checkout --orphan build &&
	git update-ref -d refs/heads/empty &&
	# remote1
	make_commits "remote1" &&
	git update-ref refs/remotes/origin/remote1 HEAD &&
	# remote2
	new_branch build &&
	make_commits "remote2" &&
	git update-ref refs/remotes/origin/remote2 HEAD &&
	# local1
	new_branch build &&
	make_commits "local1" &&
	git branch -m local1 &&
	# local2
	new_branch build &&
	make_commits "local2" &&
	git branch -m local2 &&
	# tgremote1
	new_branch build &&
	make_commits "tgremotepre1" &&
	tg_test_create_branch origin:tgremote1 :HEAD &&
	git update-ref HEAD refs/remotes/origin/tgremote1 &&
	make_commits "tgremote1" &&
	git update-ref refs/remotes/origin/tgremote1 HEAD &&
	make_commits "tgremotepost1" &&
	# tgremote2
	make_commits "tgremotepre2" &&
	tg_test_create_branch origin:tgremote2 :HEAD tgremote1 &&
	git update-ref HEAD refs/remotes/origin/tgremote2 &&
	make_commits "tgremote2" &&
	git update-ref refs/remotes/origin/tgremote2 HEAD &&
	make_commits "tgremotepost2" &&
	# tglocal1
	new_branch build &&
	make_commits "tglocalpre1" &&
	tg_test_create_branch tglocal1 :HEAD &&
	git checkout -f tglocal1 &&
	make_commits "tglocal1" &&
	git checkout -f -B build &&
	make_commits "tglocalpost1" &&
	# tglocal2
	make_commits "tglocalpre2" &&
	tg_test_create_branch tglocal2 :HEAD tglocal1 &&
	git checkout -f tglocal2 &&
	make_commits "tglocal2" &&
	git checkout -f -B build &&
	make_commits "tglocalpost2" &&
	# tgbranch1 local+remote
	new_branch build &&
	make_commits "tgbranchpre1" &&
	tg_test_create_branch origin::tgbranch1 :HEAD &&
	git checkout -f tgbranch1 &&
	make_commits "tgbranch1" &&
	git update-ref refs/remotes/origin/tgbranch1 HEAD &&
	git checkout -f HEAD^0 &&
	make_commits "tgbranchlpost1" &&
	git checkout -f tgbranch1^0 &&
	make_commits "tgbranchrpost1" &&
	# tgbranch2 remote
	make_commits "tgbranchrpre2" &&
	tg_test_create_branch origin:tgbranch2 :HEAD tgbranch1 &&
	git update-ref HEAD refs/remotes/origin/tgbranch2 &&
	make_commits "tgbranchr2" &&
	git update-ref refs/remotes/origin/tgbranch2 HEAD &&
	make_commits "tgbranchrpost2" &&
	# tgbranch2 local
	git checkout -f tgbranchlpost1after &&
	git merge -s ours -m "merge tgbranchrpost1" tgbranchrpost1after &&
	make_commits "tgbranchlpre2" &&
	tg_test_create_branch tgbranch2 :HEAD tgbranch1 &&
	git checkout -f tgbranch2 &&
	make_commits "tgbranchl2" &&
	git checkout -f HEAD^0 &&
	make_commits "tgbranchlpost2" &&
	new_branch build &&
	make_commits "tgcombinedpre" &&
	tg_test_create_branch origin::tgcombined :HEAD tglocal1 tgbranch1 &&
	git checkout -f HEAD^0 &&
	make_commits "tgcombinedpost" &&
	git checkout -B build &&
	git repack -a -d &&
	git pack-refs --prune --all &&
	refcnt=$(git for-each-ref | wc -l) &&
	test "$refcnt" = 166 &&
	topbases="$(tg --top-bases)" &&
	topbases="${topbases#refs/}" &&
	test -n "$topbases" &&
	test_when_finished topbases="$topbases" &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'no non-TopGit local branch matches' '
	for r in local1a local1b local1m local2a local2b local2m; do
		h="$(git rev-parse --verify -q $r)" &&
		{ tb="$(tg contains $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains -r $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains -r --ann $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --no-strict -r --ann $r)" || :; } &&
		test -z "$tb" || return
	done
'

test_expect_success SETUP 'no non-TopGit remote branch matches' '
	for r in remote1a remote1b remote1m remote2a remote2b remote2m; do
		h="$(git rev-parse --verify -q $r)" &&
		{ tb="$(tg contains $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains -r $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains -r --ann $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --no-strict -r --ann $r)" || :; } &&
		test -z "$tb" || return
	done
'

test_expect_success SETUP 'no --strict match for commits outside local tg branches' '
	for r in tglocalpre1a tglocalpre1b tglocalpre1m tglocalpost1b tglocalpre2a tglocalpost2m; do
		h="$(git rev-parse --verify -q $r)" &&
		{ tb="$(tg contains --strict $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --strict -r $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --strict -r --ann $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --strict --ann $r)" || :; } &&
		test -z "$tb" || return
	done
'

test_expect_success SETUP 'no --strict match for commits outside remote-only tg branches' '
	for r in tgremotepre1a tgremotepre1b tgremotepre1m tgremotepost1b tgremotepre2a tgremotepost2m; do
		h="$(git rev-parse --verify -q $r)" &&
		{ tb="$(tg contains --strict $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --strict -r $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --strict -r --ann $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --strict --ann $r)" || :; } &&
		test -z "$tb" || return
	done
'

test_expect_success SETUP 'no --strict match for commits outside local+remote tg branches' '
	for r in tgbranchpre1a tgbranchpre1b tgbranchpre1m tgbranchlpost1b tgbranchrpost1b \
		 tgbranchrpre2m tgbranchrpost2m tgbranchlpre2m tgbranchlpost2a tgbranchlpost2b; do
		h="$(git rev-parse --verify -q $r)" &&
		{ tb="$(tg contains --strict $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --strict -r $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --strict -r --ann $r)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --strict --ann $r)" || :; } &&
		test -z "$tb" || return
	done
'

test_expect_success SETUP 'contains matches tglocal1' '
	for r in tglocal1a tglocal1b tglocal1m; do
		h="$(git rev-parse --verify -q $r)" &&
		tb="$(tg contains --strict $r)" &&
		test "$tb" = "tglocal1" &&
		tb="$(tg contains --no-strict -r --ann $r)" &&
		test "$tb" = "tglocal1" || return
	done
'

test_expect_success SETUP 'contains matches tglocal2' '
	for r in tglocal2a tglocal2b tglocal2m; do
		h="$(git rev-parse --verify -q $r)" &&
		tb="$(tg contains --strict $r)" &&
		test "$tb" = "tglocal2" &&
		tb="$(tg contains --no-strict -r --ann $r)" &&
		test "$tb" = "tglocal2" || return
	done
'

test_expect_success SETUP 'contains matches tgremote1 only with -r' '
	for r in tgremote1a tgremote1b tgremote1m; do
		h="$(git rev-parse --verify -q $r)" &&
		{ tb="$(tg contains --strict $r)" || :; } &&
		test -z "$tb" &&
		tb="$(tg contains -r $r)" &&
		test "$tb" = "remotes/origin/tgremote1" &&
		tb="$(tg contains --no-strict -r --ann $r)" &&
		test "$tb" = "remotes/origin/tgremote1" || return
	done
'

test_expect_success SETUP 'contains matches tgremote2 only with -r' '
	for r in tgremote2a tgremote2b tgremote2m; do
		h="$(git rev-parse --verify -q $r)" &&
		{ tb="$(tg contains --strict $r)" || :; } &&
		test -z "$tb" &&
		tb="$(tg contains -r $r)" &&
		test "$tb" = "remotes/origin/tgremote2" &&
		tb="$(tg contains --no-strict -r --ann $r)" &&
		test "$tb" = "remotes/origin/tgremote2" || return
	done
'

test_expect_success SETUP 'contains never remote match if local match' '
	for r in tgbranch1a tgbranch1b tgbranch1m; do
		h="$(git rev-parse --verify -q $r)" &&
		tb="$(tg contains $r)" &&
		test "$tb" = "tgbranch1" &&
		tb="$(tg contains --no-strict -r --ann $r)" &&
		test "$tb" = "tgbranch1" || return
	done
'

test_expect_success SETUP 'contains local bases only with --no-strict' '
	for r in tglocal1 tglocal2 tgbranch1 tgbranch2; do
		h="$(git rev-parse --verify -q "refs/$topbases/$r")" &&
		{ tb="$(tg contains --strict -r --ann $h)" || :; } &&
		test -z "$tb" &&
		tb="$(tg contains --no-strict $h)" &&
		test "$tb" = "$r" || return
	done
'

test_expect_success SETUP 'contains remote bases only with --no-strict -r' '
	for r in tgremote1 tgremote2; do
		h="$(git rev-parse --verify -q "refs/remotes/origin/${topbases#heads/}/$r")" &&
		{ tb="$(tg contains --strict -r --ann $h)" || :; } &&
		test -z "$tb" &&
		{ tb="$(tg contains --no-strict --ann $h)" || :; } &&
		test -z "$tb" &&
		tb="$(tg contains --no-strict -r $h)" &&
		test "$tb" = "remotes/origin/$r" || return
	done
'

test_expect_success SETUP 'contains -v local one head' '
	tb="$(tg contains -v tglocal2b)" &&
	test "$tb" = "tglocal2 [tglocal2]"
'

test_expect_success SETUP 'contains -v local+remote one head' '
	tb="$(tg contains -v tgbranchl2b)" &&
	test "$tb" = "tgbranch2 [tgbranch2]"
'

test_expect_success SETUP 'contains -v remote no heads' '
	{ tb="$(tg contains -v --no-strict --ann tgremote2b)" || :; } &&
	test -z "$tb" &&
	tb="$(tg contains -v -r tgremote2b)" &&
	test "$tb" = "remotes/origin/tgremote2"
'

test_expect_success SETUP 'contains -v local+remote out-of-date no heads' '
	{ tb="$(tg contains -v --no-strict --ann tgbranchr2b)" || :; } &&
	test -z "$tb" &&
	tb="$(tg contains -v -r tgbranchr2b)" &&
	test "$tb" = "remotes/origin/tgbranch2"
'

test_expect_success SETUP 'contains -v two heads local' '
	tb="$(tg contains -v tglocal1b)" &&
	test "$tb" = "tglocal1 [tgcombined, tglocal2]"
'

test_expect_success SETUP 'contains -v two heads local+remote' '
	tb="$(tg contains -v tgbranch1b)" &&
	test "$tb" = "tgbranch1 [tgbranch2, tgcombined]"
'

test_done
