#!/bin/sh

test_description='tg update --skip-missing branches'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 7

uctmp="$(test_get_temp update-check)" || die

branch_is_up_to_date() {
	needs_update_check "$@" >"$uctmp" &&
	{
		read -r uc_processed &&
		read -r uc_behind &&
		read -r uc_ahead &&
		read -r uc_partial
	} <"$uctmp" &&
	test z"$uc_behind" = z":"
}

test_expect_success 'setup' '
	test_create_repo pristine &&
	cd pristine &&
	git config core.logallrefupdates false &&
	git checkout --orphan release &&
	git read-tree --empty &&
	git reset --hard &&
	test_commit "release~1" &&
	tg_test_create_branches <<-EOT &&
		t/patch1 [PATCH] alpha patch
		release

		t/patch2 [PATCH] beta patch
		release
	EOT
	git checkout -f t/patch1 &&
	test_commit "alpha~1" &&
	tg_test_create_branch t/int -m "[INTERMEDIATE] extra level" t/patch2 &&
	git checkout -f t/patch2 &&
	test_commit "beta~1" &&
	tg_test_create_branch stage -m "[STAGE] staging branch" release t/patch1 t/int &&
	test_must_fail branch_is_up_to_date stage &&
	git repack -afd &&
	git prune --expire=now &&
	git pack-refs --prune --all &&
	test_when_finished test_tick=$test_tick &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'tg update succeeds with nothing missing' '
	cp -pR pristine succeeds &&
	cd succeeds &&
	tg update --no-stash stage &&
	branch_is_up_to_date stage
'

test_expect_success SETUP 'tg update fails with missing dependency' '
	cp -pR pristine fails &&
	cd fails &&
	git checkout -f stage &&
	git branch -M t/patch2 t-missing/patch2 &&
	test_must_fail tg update --no-stash stage
'

test_expect_failure SETUP,LASTOK 'tg update --skip-missing succeeds with missing dependency' '
	cd fails &&
	test_might_fail tg update --abort >/dev/null 2>&1 &&
	git checkout -f stage &&
	tg update --no-stash --skip-missing stage
'

test_expect_success SETUP,LASTOK 'branch up-to-date with missing depedency' '
	cd fails &&
	git checkout -f stage &&
	branch_is_up_to_date stage
'

test_expect_success SETUP,LASTOK 'branch out of date after restoring branch' '
	cd fails &&
	git checkout -f stage &&
	git branch -M t-missing/patch2 t/patch2 &&
	test_must_fail branch_is_up_to_date stage
'

test_expect_success SETUP,LASTOK 'tg update finally succeeds completely' '
	cd fails &&
	git checkout -f stage &&
	tg update --no-stash stage &&
	branch_is_up_to_date stage
'

test_done
