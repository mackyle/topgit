#!/bin/sh

test_description='tg update remote branches'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 7

tg_test_remote=uranus

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
	git config remote.uranus.url "." &&
	git config topgit.remote uranus &&
	git for-each-ref --format="%(refname)" >refs &&
	awk <refs >refs2 "
		{ orig = \$0 }
		\$0 ~ /\/heads\// {
			sub(/\/heads\//, \"/remotes/uranus/\")
			print \$0, orig
			next
		}
		\$0 ~ /\/top-bases\// {
			sub(/\/top-bases\//, \"/remotes/uranus/top-bases/\")
			print \$0, orig
			next
		}
		\$0 ~ /\/heads\/\{top-bases\}\// {
			sub(/\/heads\/\{top-bases\}\//, \"/remotes/uranus/{top-bases}/\")
			print \$0, orig
			next
		}
	" &&
	while read -r newref oldref; do
		echo "oldref = $oldref" &&
		echo "newref = $newref" &&
		git update-ref "$newref" "$oldref" ""
	done <refs2 &&
	rm -f refs refs2 &&
	branch_is_up_to_date stage &&
	git gc --aggressive --prune=now
'

test_expect_success 'remote level 1 dep' '
	cp -pR pristine level1 &&
	cd level1 &&
	git symbolic-ref HEAD refs/remotes/uranus/t/patch1 &&
	git reset --hard &&
	git tag oldalpha &&
	echo "amend alpha" >> "alpha~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend alpha" &&
	git tag newalpha &&
	test_must_fail git diff --exit-code oldalpha:alpha~1.t newalpha:alpha~1.t &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	test_must_fail git diff --exit-code oldalpha:alpha~1.t stage:alpha~1.t &&
	git diff --exit-code newalpha:alpha~1.t stage:alpha~1.t
'

test_expect_success 'remote level 2 dep' '
	cp -pR pristine level2 &&
	cd level2 &&
	git symbolic-ref HEAD refs/remotes/uranus/t/patch2 &&
	git reset --hard &&
	git tag oldbeta &&
	echo "amend beta" >> "beta~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend beta" &&
	git tag newbeta &&
	test_must_fail git diff --exit-code oldbeta:beta~1.t newbeta:beta~1.t &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	test_must_fail git diff --exit-code oldbeta:beta~1.t stage:beta~1.t &&
	git diff --exit-code newbeta:beta~1.t stage:beta~1.t
'

test_expect_failure 'remote level 1 base' '
	cp -pR pristine level1base &&
	cd level1base &&
	git symbolic-ref HEAD "$(tg --top-bases -r)/t/patch1" &&
	git reset --hard &&
	git tag oldrelease &&
	echo "amend release" >> "release~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend release on t/patch1 base" &&
	git tag newrelease &&
	test_must_fail git diff --exit-code oldrelease:release~1.t newrelease:release~1.t &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	test_must_fail git diff --exit-code oldrelease:release~1.t stage:release~1.t &&
	git diff --exit-code newrelease:release~1.t stage:release~1.t
'

test_expect_failure 'remote level 2 base' '
	cp -pR pristine level2base &&
	cd level2base &&
	git symbolic-ref HEAD "$(tg --top-bases -r)/t/patch2" &&
	git reset --hard &&
	git tag oldrelease &&
	echo "amend release" >> "release~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend release on t/patch2 base" &&
	git tag newrelease &&
	test_must_fail git diff --exit-code oldrelease:release~1.t newrelease:release~1.t &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	test_must_fail git diff --exit-code oldrelease:release~1.t stage:release~1.t &&
	git diff --exit-code newrelease:release~1.t stage:release~1.t
'

test_expect_failure 'remote intermediate base' '
	cp -pR pristine intbase &&
	cd intbase &&
	git symbolic-ref HEAD "$(tg --top-bases -r)/t/int" &&
	git reset --hard &&
	git tag oldbeta &&
	echo "amend beta" >> "beta~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend beta on t/int base" &&
	git tag newbeta &&
	test_must_fail git diff --exit-code oldbeta:beta~1.t newbeta:beta~1.t &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	test_must_fail git diff --exit-code oldbeta:beta~1.t stage:beta~1.t &&
	git diff --exit-code newbeta:beta~1.t stage:beta~1.t
'

test_expect_failure 'remote stage base' '
	cp -pR pristine stagebase &&
	cd stagebase &&
	git symbolic-ref HEAD "$(tg --top-bases -r)/stage" &&
	git reset --hard &&
	git tag oldalpha &&
	echo "amend alpha" >> "alpha~1.t" &&
	git add -u &&
	test_tick &&
	git commit -m "amend alpha on stage base" &&
	git tag newalpha &&
	test_must_fail git diff --exit-code oldalpha:alpha~1.t newalpha:alpha~1.t &&
	test_must_fail branch_is_up_to_date stage &&
	tg update stage &&
	branch_is_up_to_date stage &&
	test_must_fail git diff --exit-code oldalpha:alpha~1.t stage:alpha~1.t &&
	git diff --exit-code newalpha:alpha~1.t stage:alpha~1.t
'

test_done
