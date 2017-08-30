#!/bin/sh

test_description='tg update can create an octopus merge'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 4

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
	git checkout --orphan release &&
	git read-tree --empty &&
	git reset --hard &&
	test_commit "release~1" &&
	tg_test_create_branches <<-EOT &&
		t/patch1 [PATCH] alpha patch
		release

		t/patch2 [PATCH] beta patch
		release

		t/patch3 [PATCH] gamma patch
		release
	EOT
	git checkout -f t/patch1 &&
	test_commit "alpha~1" &&
	git checkout -f t/patch2 &&
	test_commit "beta~1" &&
	git checkout -f t/patch3 &&
	test_commit "gamma~1" &&
	tg_test_create_branch t/int -m "[INTERMEDIATE] extra level" t/patch2 &&
	tg_test_create_branch stage -m "[STAGE] staging branch" release t/patch1 t/int t/patch3 &&
	test_must_fail branch_is_up_to_date stage &&
	git gc --aggressive --prune=now &&
	cd .. &&
	cp -pR pristine octopus
'

cd octopus || die

test_expect_success 'tg update to make octopus' '
	tg update stage
'

test_expect_success 'verify 4-way octopus created' '
	tmp1="$(test_get_temp cmt)" &&
	tmp2="$(test_get_temp hdr)" &&
	tmp3="$(test_get_temp pnt)" &&
	git cat-file commit "$(tg --top-bases)/stage" >"$tmp1" &&
	sed -n "1,/^\$/p" <"$tmp1" >"$tmp2" &&
	sed -n "/^parent /p" <"$tmp2" >"$tmp3" &&
	lines="$(wc -l <"$tmp3")" &&
	test "$lines" -eq 4
'

test_expect_success 'verify all files present' '
	git diff --exit-code release:release~1.t stage:release~1.t &&
	git diff --exit-code t/patch1:alpha~1.t stage:alpha~1.t &&
	git diff --exit-code t/patch2:beta~1.t stage:beta~1.t &&
	git diff --exit-code t/patch3:gamma~1.t stage:gamma~1.t
'

test_done
