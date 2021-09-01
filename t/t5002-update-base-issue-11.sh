#!/bin/sh

test_description='test update --base zeroing out patches

After using tg update --base on a [BASE] branch to cause
it to "accumulate" all of the updates and then merging it
throughout the rest of the branches, they should all
end up reporting a "0" in the `tg summary` output AND
none of the should disappear.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 8

squish() {
	tab="	" # single tab in there
	tr -s "$tab" " "
}

test_expect_success 'setup upstream' '
	test_create_repo upstream &&
	cd upstream &&
	test_commit "README file" README &&
	test_commit "add tiny.h" tiny.h "/* tiny h file */" &&
	test_commit "add tiny.c" tiny.c "/* tiny c file */" "U1.0" &&
	test_when_finished test_tick="$test_tick"
'

test_expect_success LASTOK 'setup tgtest' '
	test_create_repo tgtest &&
	cd tgtest &&
	tg_test_setup_topgit &&
	git remote add origin ../upstream &&
	git fetch &&
	git checkout -b frabjous "U1.0"
'

test_expect_success LASTOK 'create [BASE] and two [PATCH] tg branches' '
	cd tgtest &&
	tg_test_create_branch thebase -m "[BASE] the base" :HEAD &&
	git checkout -f thebase &&
	tg_test_create_branch t/feat1 thebase &&
	git checkout -f t/feat1 &&
	test_tick &&
	echo "/* changes */" >>tiny.c &&
	git commit -am "modify" &&
	tg_test_create_branch t/feat2 thebase &&
	git checkout -f t/feat2 &&
	test_tick &&
	echo "/* changes */" >>tiny.h &&
	git commit -am "modify" &&
	test_when_finished test_tick="$test_tick"
'

test_expect_success LASTOK 'create [STAGE] with both patches and tag' '
	cd tgtest &&
	tg_test_create_branch stage -m "[STAGE] combined patches" t/feat1 t/feat2 &&
	git checkout -f stage &&
	test_tick &&
	tg update &&
	test_tick &&
	git commit --amend --reset-author --no-edit &&
	test_tick &&
	git tag -a -m "tag S1.0" S1.0 &&
	git update-ref --no-deref HEAD HEAD HEAD &&
	test_when_finished test_tick="$test_tick"
'

printf "%s" "\
 0       stage                         	[STAGE] combined patches
         t/feat1                       	[PATCH] branch t/feat1
         t/feat2                       	[PATCH] branch t/feat2
 0       thebase                       	[BASE] the base
" > initial_summary.raw ||
	die failed to make initial_summary.raw
< initial_summary.raw squish > initial_summary ||
	die failed to make initial_summary

test_expect_success LASTOK 'summary has two non-zero patches' '
	tg -C tgtest summary > actual.raw &&
	squish < actual.raw > actual &&
	test_cmp actual initial_summary
'

test_expect_success LASTOK 'update thebase to tag' '
	cd tgtest &&
	test_tick &&
	tg update --base --no-edit thebase S1.0 &&
	git checkout -f thebase &&
	test_tick &&
	git commit --amend --reset-author --no-edit &&
	test_when_finished test_tick="$test_tick"
'

test_expect_success LASTOK 'update all dependents' '
	cd tgtest &&
	git checkout -f t/feat1 &&
	test_tick &&
	tg update &&
	test_tick &&
	git commit --amend --reset-author --no-edit &&
	git checkout -f t/feat2 &&
	test_tick &&
	tg update &&
	test_tick &&
	git commit --amend --reset-author --no-edit &&
	git checkout -f stage &&
	test_tick &&
	tg update &&
	test_tick &&
	git commit --amend --reset-author --no-edit &&
	git update-ref --no-deref HEAD HEAD HEAD &&
	test_when_finished test_tick="$test_tick"
'

printf "%s" "\
 0       stage                         	[STAGE] combined patches
 0       t/feat1                       	[PATCH] branch t/feat1
 0       t/feat2                       	[PATCH] branch t/feat2
 0       thebase                       	[BASE] the base
" > zero_summary.raw ||
	die failed to make zero_summary.raw
< zero_summary.raw squish > zero_summary ||
	die failed to make zero_summary

test_expect_success LASTOK 'summary has four zero patches' '
	tg -C tgtest summary > actual.raw &&
	squish < actual.raw > actual &&
	test_cmp actual zero_summary
'

test_done
