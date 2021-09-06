#!/bin/sh

test_description='test update with thinned .topdeps

When fetching updates from a remote that brings in a
.topdeps file that has had dependency lines removed (and
removed properly with the necessary "revert" patch added to
the base) and simultaneously brings in an update to one of
the branches that depends on that dependency removal, make
sure the local update succeeds.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 8

test_expect_success 'setup upstream' '
	test_create_repo upstream &&
	cd upstream &&
	git checkout --orphan master &&
	test_commit "master upstream" master.txt &&
	test_when_finished test_tick=$test_tick
'

test_expect_success LASTOK 'setup collab1' '
	test_create_repo collab1 &&
	cd collab1 &&
	git checkout --orphan orphan &&
	git remote add origin ../upstream &&
	git fetch &&
	git update-ref refs/heads/master refs/remotes/origin/master &&
	git rev-parse --verify --quiet refs/heads/master -- >/dev/null &&
	tg_test_create_branch t/feature1 master &&
	git checkout -f t/feature1 &&
	test_commit "feature one" feature1.txt &&
	tg_test_create_branch t/feature2 master &&
	git checkout -f t/feature2 &&
	echo "master with feature2 added" >master.txt &&
	test_tick &&
	git commit -am "feature two" &&
	tg_test_create_branch stage -m "[STAGE] staging" t/feature1 t/feature2 &&
	git checkout -f stage &&
	test_tick &&
	tg update --no-stash &&
	test_tick &&
	git commit --amend --reset-author --no-edit &&
	test_when_finished test_tick=$test_tick
'

test_expect_success LASTOK 'setup collab2' '
	test_create_repo collab2 &&
	cd collab2 &&
	git checkout --orphan orphan &&
	git remote add origin ../upstream &&
	git remote add collab1 ../collab1 &&
	git remote update &&
	git update-ref refs/heads/master refs/remotes/origin/master &&
	git rev-parse --verify --quiet refs/heads/master -- >/dev/null &&
	tg remote --populate collab1 &&
	git checkout -f stage &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'collab1 remove t/feature1 dependency' '
	cd collab1 &&
	topbases="$(tg --top-bases)" &&
	test -n "$topbases" &&
	pfile="$(test_get_temp patch)" &&
	git checkout -f "$topbases/stage" &&
	git diff-tree --patch refs/heads/t/feature2 "$topbases/t/feature2" -- :/ :!/.topdeps :!/.topmsg >"$pfile" &&
	git apply <"$pfile" &&
	test_tick &&
	git commit -am "revert t/feature2 from stage base" &&
	git update-ref "$topbases/stage" HEAD &&
	git checkout -f stage &&
	test_tick &&
	tg update --no-stash &&
	test_tick &&
	echo "t/feature1" >.topdeps &&
	git commit -am "remove t/feature2 from .topdeps" &&
	test_when_finished test_tick=$test_tick
'

test_expect_success SETUP 'upstream add change' '
	cd upstream &&
	echo "master upstream with update" >master.txt &&
	test_tick &&
	git commit -am "update master" &&
	test_when_finished test_tick=$test_tick
'

test_expect_success SETUP 'collab1 fetch updates' '
	cd collab1 &&
	git remote update &&
	git update-ref refs/heads/master refs/remotes/origin/master &&
	git rev-parse --verify --quiet refs/heads/master -- >/dev/null &&
	git checkout -f t/feature1 &&
	test_tick &&
	tg update --no-stash &&
	git checkout -f stage &&
	test_tick &&
	tg update --no-stash &&
	test_tick &&
	git commit --amend --reset-author --no-edit &&
	test_when_finished test_tick=$test_tick
'

test_expect_success SETUP 'collab2 fetch updates' '
	cd collab2 &&
	git remote update &&
	git update-ref refs/heads/master refs/remotes/origin/master &&
	git rev-parse --verify --quiet refs/heads/master -- >/dev/null
'

test_expect_success LASTOK 'collab2 update stage' '
	cd collab2 &&
	git checkout -f stage &&
	test_tick &&
	tg update --no-stash
'

test_done
