#!/bin/sh

test_description='tg contains environment

Test the behavior of tg contains when unexpected
environment variables are present.
'

. ./test-lib.sh

test_plan 11

test_expect_success 'setup' '
	git config core.logallrefupdates false &&
	git config advice.detachedHead false &&
	git checkout --orphan empty &&
	test_tick &&
	git commit --allow-empty -m empty &&
	test_commit alfa &&
	tg_test_create_branch t/alpha :HEAD &&
	topbases="$(tg --top-bases)" &&
	test -n "$topbases" &&
	test_when_finished topbases="$topbases" &&
	git checkout t/alpha &&
	git update-ref -d refs/heads/empty &&
	test_commit bravo &&
	tg_test_create_branch t/beta t/alpha &&
	git checkout t/beta &&
	test_commit charlie &&
	tg_test_create_branch t/gamma t/alpha &&
	git checkout t/gamma &&
	test_commit foxtrot &&
	tg_test_create_branch t/epsilon t/beta t/gamma &&
	git symbolic-ref HEAD "$topbases/t/epsilon" &&
	git reset --hard &&
	test_tick &&
	git cat-file blob t/gamma:foxtrot.t > foxtrot.t &&
	git add foxtrot.t &&
	nt="$(git write-tree)" &&
	cmt="$(git commit-tree -p t/epsilon -p t/gamma -m add_dep_to_base "$nt")" &&
	git update-ref HEAD "$cmt" &&
	git checkout t/epsilon &&
	test_tick &&
	git merge --no-commit --no-ff -m add_dep "$topbases/t/epsilon" &&
	git checkout t/epsilon .topmsg .topdeps &&
	git commit --no-edit &&
	test_commit golf &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'tg contains non-topgit alfa' '
	tc="$(test_must_fail tg contains alfa)" &&
	test "$tc" = ""
'

test_expect_success SETUP 'tg contains bravo' '
	tc="$(tg contains bravo)" &&
	test "$tc" = "t/alpha"
'

test_expect_success SETUP 'tg contains charlie' '
	tc="$(tg contains charlie)" &&
	test "$tc" = "t/beta"
'

test_expect_success SETUP 'tg contains foxtrot' '
	tc="$(tg contains foxtrot)" &&
	test "$tc" = "t/gamma"
'

test_expect_success SETUP 'tg contains golf' '
	tc="$(tg contains golf)" &&
	test "$tc" = "t/epsilon"
'

mindepth=-1
export mindepth

# already using test_must_fail, badenv will have no effect
test_expect_success SETUP 'badenv tg contains non-topgit alfa' '
	tc="$(test_must_fail tg contains alfa)" &&
	test "$tc" = ""
'

test_expect_success SETUP 'badenv tg contains bravo' '
	tc="$(tg contains bravo)" &&
	test "$tc" = "t/alpha"
'

test_expect_success SETUP 'badenv tg contains charlie' '
	tc="$(tg contains charlie)" &&
	test "$tc" = "t/beta"
'

test_expect_success SETUP 'badenv tg contains foxtrot' '
	tc="$(tg contains foxtrot)" &&
	test "$tc" = "t/gamma"
'

test_expect_success SETUP 'badenv tg contains golf' '
	tc="$(tg contains golf)" &&
	test "$tc" = "t/epsilon"
'

test_done
