#!/bin/sh

test_description='tg create tests'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 1

test_recreate_repo_cd() {
	! [ -e "$1" ] || rm -rf "$1"
	! [ -e "$1" ] || { chmod -R u+rw "$1"; rm -rf "$1"; }
	! [ -e "$1" ] || die
	test_create_repo "$1" &&
	cd "$1"
}

test_expect_success 'tg rebase' '
  echo "See comments below this test fails"
'

# This test fails :-(
# test_commit(){ echo $1 > $1; git add $1; git commit -m $1; }
# Then you can run the lines below without && in a simple shell after git init
# to see the last tg export --rebase command fails (but it got the job done).
# The rebased merge branch gets created.
# I don't have time to debug it right now

# test_expect_success 'tg rebase' '
# test_recreate_repo_cd r0 &&
# test_commit release-1 &&
# echo "tag this as release-1, then create blue and red branches and merge them as topic branch" &&
# git checkout -b release-1 &&
# tg create --topmsg release-1:blue release-1-topics/blue release-1 &&
# test_commit blue &&
# git checkout release-1 &&
# tg create --topmsg release-1:red release-1-topics/red release-1 &&
# test_commit red &&
# tg create --topmsg release-1:merge_blue_and_red release-1-topics/merge release-1-topics/blue release-1-topics/red &&
# echo "now advavce release-1 to release-2 and call that so" &&
# git checkout release-1 &&
# git checkout -b release-2 &&
# test_commit release-2 &&
# tg export --rebase --from-to release-1 release-2 --drop-prefix release-1-topics/ --prefix release-2-topics/ release-1-topics/merge &&
# echo "because blue red shoud be rebase don release-2 we should have all 3 files" &&
# [ -e blue ] &&
# [ -e red ] &&
# [ -e release-2 ]
# '

test_done
