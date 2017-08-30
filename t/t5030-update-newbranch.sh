#!/bin/sh

test_description='tg update remote sets up newly added branch'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 6

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

		:t/patch3 [PATCH] gamma patch
		release
	EOT
	git checkout -f t/patch1 &&
	test_commit "alpha~1" &&
	git checkout -f t/patch2 &&
	test_commit "beta~1" &&
	git symbolic-ref HEAD refs/remotes/uranus/t/patch3 &&
	git reset --hard &&
	test_commit "gamma~1" &&
	git symbolic-ref HEAD refs/remotes/uranus/proposed &&
	git read-tree --empty &&
	git reset --hard &&
	test_commit "proposed~1" &&
	git symbolic-ref HEAD "$(tg --top-bases -r uranus)/orphan" &&
	git read-tree --empty &&
	git reset --hard &&
	test_commit "orphan~1" &&
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
		\$0 ~ /^refs\/remotes\// { next }
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

test_expect_success 'unknown branch fails' '
	cp -pR pristine unknown &&
	cd unknown &&
	git symbolic-ref HEAD refs/remotes/uranus/stage &&
	git reset --hard &&
	echo "t/patch-unknown" >> .topdeps &&
	git add -u &&
	test_tick &&
	git commit -m ".topdeps: add t/patch-unknown dependency" &&
	test_might_fail tg update stage &&
	test_must_fail tg update stage
'

test_expect_success 'non-tgish remote branch fails' '
	cp -pR pristine nontgish &&
	cd nontgish &&
	git symbolic-ref HEAD refs/remotes/uranus/stage &&
	git reset --hard &&
	echo "proposed" >> .topdeps &&
	git add -u &&
	test_tick &&
	git commit -m ".topdeps: add proposed dependency" &&
	test_might_fail tg update stage &&
	test_must_fail tg update stage
'

test_expect_success 'orphan remote branch base fails' '
	cp -pR pristine nontgish &&
	cd nontgish &&
	git symbolic-ref HEAD refs/remotes/uranus/stage &&
	git reset --hard &&
	echo "orphan" >> .topdeps &&
	git add -u &&
	test_tick &&
	git commit -m ".topdeps: add orphan dependency" &&
	test_might_fail tg update stage &&
	test_must_fail tg update stage
'

test_expect_success 'blocked base remote branch setup fails' '
	cp -pR pristine blockingbase &&
	cd blockingbase &&
	git update-ref "$(tg --top-bases)/t/patch3" release "" &&
	git symbolic-ref HEAD refs/remotes/uranus/stage &&
	git reset --hard &&
	echo "t/patch3" >> .topdeps &&
	git add -u &&
	test_tick &&
	git commit -m ".topdeps: add t/patch3 dependency" &&
	test_might_fail tg update stage &&
	test_must_fail tg update stage
'

test_expect_success 'auto setup local branch' '
	cp -pR pristine autosetup &&
	cd autosetup &&
	git symbolic-ref HEAD refs/remotes/uranus/stage &&
	git reset --hard &&
	echo "t/patch3" >> .topdeps &&
	git add -u &&
	test_tick &&
	git commit -m ".topdeps: add t/patch3 dependency" &&
	tg update stage &&
	cmt="$(git rev-parse --verify refs/heads/stage)" && test -n "$cmt" &&
	tg update stage &&
	cmt2="$(git rev-parse --verify refs/heads/stage)" && test -n "$cmt2" &&
	test z"$cmt" = z"$cmt2" &&
	test_cmp_rev "$(tg --top-bases -r)/t/patch3" "$(tg --top-bases)/t/patch3" &&
	test_cmp_rev refs/remotes/uranus/t/patch3 refs/heads/t/patch3
'

test_done
