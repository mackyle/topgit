#!/bin/sh

test_description='tg update non-remote branches'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 8

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
	EOT
	git checkout -f t/patch1 &&
	test_commit "alpha~1" &&
	git checkout -f t/patch2 &&
	test_commit "beta~1" &&
	tg_test_create_branch t/int -m "[INTERMEDIATE] extra level" t/patch2 &&
	tg_test_create_branch stage -m "[STAGE] staging branch" release t/patch1 t/int &&
	test_must_fail branch_is_up_to_date stage &&
	git symbolic-ref HEAD "$(tg --top-bases)/stage" &&
	git reset --hard &&
	git rm --force --ignore-unmatch -- .topmsg .topdeps &&
	git read-tree -m release t/patch1 t/int &&
	git rm --force --ignore-unmatch -- .topmsg .topdeps &&
	newtree="$(git write-tree)" && test -n "$newtree" &&
	test_tick &&
	newcommit="$(git commit-tree -p HEAD -p t/patch1 -p t/int -m "mighty octopus" "$newtree")" &&
	test -n "$newcommit" && git update-ref HEAD "$newcommit" HEAD &&
	git checkout -f stage &&
	test_tick &&
	git merge -m "bases up" "$(tg --top-bases)/stage" &&
	branch_is_up_to_date stage &&
	git gc --aggressive --prune=now
'

test_expect_success 'non-tgish dep' '
	cp -pR pristine nontgish &&
	cd nontgish &&
	git checkout -f release &&
	echo "amend" >> "release~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend file" &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	git diff --exit-code release:release~1.t stage:release~1.t
'

test_expect_success 'level 1 dep' '
	cp -pR pristine level1 &&
	cd level1 &&
	git checkout -f t/patch1 &&
	echo "amend alpha" >> "alpha~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend alpha" &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	git diff --exit-code t/patch1:alpha~1.t stage:alpha~1.t
'

test_expect_success 'level 2 dep' '
	cp -pR pristine level2 &&
	cd level2 &&
	git checkout -f t/patch2 &&
	echo "amend beta" >> "beta~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend beta" &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	git diff --exit-code t/patch2:beta~1.t stage:beta~1.t
'

test_expect_success 'level 1 base' '
	cp -pR pristine level1base &&
	cd level1base &&
	git symbolic-ref HEAD "$(tg --top-bases)/t/patch1" &&
	git reset --hard &&
	echo "amend release" >> "release~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend release on t/patch1 base" &&
	git tag newrelease &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	test_must_fail git diff --exit-code release:release~1.t stage:release~1.t &&
	git diff --exit-code newrelease:release~1.t stage:release~1.t
'

test_expect_success 'level 2 base' '
	cp -pR pristine level2base &&
	cd level2base &&
	git symbolic-ref HEAD "$(tg --top-bases)/t/patch2" &&
	git reset --hard &&
	echo "amend release" >> "release~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend release on t/patch2 base" &&
	git tag newrelease &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	test_must_fail git diff --exit-code release:release~1.t stage:release~1.t &&
	git diff --exit-code newrelease:release~1.t stage:release~1.t
'

test_expect_success 'intermediate base' '
	cp -pR pristine intbase &&
	cd intbase &&
	git symbolic-ref HEAD "$(tg --top-bases)/t/int" &&
	git reset --hard &&
	echo "amend beta" >> "beta~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend beta on t/int base" &&
	git tag newbeta &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	test_must_fail git diff --exit-code t/patch2:beta~1.t stage:beta~1.t &&
	git diff --exit-code newbeta:beta~1.t stage:beta~1.t
'

test_expect_success 'stage base' '
	cp -pR pristine stagebase &&
	cd stagebase &&
	git symbolic-ref HEAD "$(tg --top-bases)/stage" &&
	git reset --hard &&
	echo "amend alpha" >> "alpha~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend alpha on stage base" &&
	git tag newalpha &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	test_must_fail git diff --exit-code t/patch1:alpha~1.t stage:alpha~1.t &&
	git diff --exit-code newalpha:alpha~1.t stage:alpha~1.t
'

test_done
