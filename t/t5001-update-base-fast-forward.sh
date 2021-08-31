#!/bin/sh

test_description='tg update --base fast-forward tests

Some have expressed a temptation to use `tg update --base branch branch`
in order to "empty" out the patch content of a TopGit topic branch.

This has, however, consequences with regard to the .topdeps and .topmsg
files.

Hence these tests.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 12

glst() { git ls-tree --full-tree --name-only "$1" -- :/.topdeps :/.topmsg; }

test_expect_success 'setup t/frabjous' '
	test_create_repo r &&
	cd r &&
	tg_test_setup_topgit &&
	tg_test_create_branch t/frabjous : &&
	git checkout -f t/frabjous &&
	test_commit "test file" file test &&
	echo file >../expected &&
	tg files >../actual &&
	test_cmp ../actual ../expected &&
	tgb="$(tg base)" &&
	>../expected &&
	glst "$tgb" >../actual &&
	test_cmp ../actual ../expected &&
	printf "%s\n" .topdeps .topmsg >../expected &&
	glst HEAD >../actual &&
	test_cmp ../actual ../expected &&
	test_when_finished test_tick="$test_tick"
'

test_expect_success LASTOK 'commit on top of base' '
	cd r &&
	git checkout -f "$(tg base t/frabjous)" &&
	test_commit "base file" base base addtobase &&
	test_when_finished test_tick="$test_tick"
'

test_expect_success LASTOK 'update base with new commit' '
	cd r &&
	test_tick &&
	tg update --no-stash --base --no-edit t/frabjous addtobase &&
	test_when_finished test_tick="$test_tick"
'

test_expect_success LASTOK 'branch files just "file"' '
	cd r &&
	echo file >../expected &&
	tg files t/frabjous >../actual &&
	test_cmp ../actual ../expected
'

test_expect_success LASTOK 'branch with .topdeps and .topmsg files' '
	cd r &&
	printf "%s\n" .topdeps .topmsg >../expected &&
	glst t/frabjous >../actual &&
	test_cmp ../actual ../expected
'

test_expect_success LASTOK 'base without .topdeps and .topmsg files' '
	cd r &&
	>../expected &&
	glst "$(tg base t/frabjous)" >../actual &&
	test_cmp ../actual ../expected
'

test_expect_success LASTOK 'add new commit to branch' '
	cd r &&
	git checkout -f t/frabjous &&
	test_commit "extra file" extra &&
	test_when_finished test_tick="$test_tick"
'

test_expect_success LASTOK 'branch files just "extra" and "file"' '
	cd r &&
	printf "%s\n" extra file >../expected &&
	tg files t/frabjous >../actual &&
	test_cmp ../actual ../expected
'

test_expect_success LASTOK 'fast forward base to branch' '
	cd r &&
	test_tick &&
	tg update --no-stash --base --no-edit t/frabjous t/frabjous^0 &&
	test_when_finished test_tick="$test_tick"
'

test_expect_success LASTOK 'branch files empty' '
	cd r &&
	>../expected &&
	tg files t/frabjous >../actual &&
	test_cmp ../actual ../expected
'

test_expect_success LASTOK 'branch with .topdeps and .topmsg files redux' '
	cd r &&
	printf "%s\n" .topdeps .topmsg >../expected &&
	glst t/frabjous >../actual &&
	test_cmp ../actual ../expected
'

test_expect_success LASTOK 'base without .topdeps and .topmsg files redux' '
	cd r &&
	>../expected &&
	glst "$(tg base t/frabjous)" >../actual &&
	test_cmp ../actual ../expected
'

test_done
