#!/bin/sh

test_description="test update with fast-forwarding base

While technically the situation could arise when dealing
strictly with local branches, it's much, much, much more
likely to arise when dealing with remote bases.

When updating the local base and the remote branch's base
is merged in as the first dependency and that results in
a fast forward, and there's still at least one other
update to merge in that cannot fast forward; when creating
the merge commit, the first parent must not be the original
commit, it must be the commit that was fast-forwarded to.

Failure to do this correctly results in the remote base
not being contained by the local base although things seem
to work (more or less) because the remote branch contains its
remote base and when that remote branch gets merged into the
local branch that ends up pulling in the remote base changes
into the local branch, but not in proper order.
"

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 9

# true if $1 is contained by (or the same as) $2
# this is never slower than merge-base --is-ancestor and is often slightly faster
contained_by() {
        [ "$(git rev-list --count --max-count=1 "$1" --not "$2" --)" = "0" ]
}

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
	test_commit "feature two" feature2.txt &&
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

test_expect_success SETUP 'collab2 add to feature1' '
	cd collab2 &&
	git checkout -f t/feature1 &&
	echo "more feature1" >> feature1.txt &&
	test_tick &&
	git commit -am "update feature1" &&
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

test_expect_success LASTOK 'collab2 stage base contains remote stage base and deps' '
	cd collab2 &&
	topbases="$(tg --top-bases)" &&
	test -n "$topbases" &&
	rtopbases="$(tg --top-bases -r)" &&
	test -n "$rtopbases" &&
	contained_by refs/heads/t/feature1 "$topbases/stage" &&
	contained_by refs/heads/t/feature2 "$topbases/stage" &&
	contained_by "$rtopbases/stage" "$topbases/stage"
'

test_done
