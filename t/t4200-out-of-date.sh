#!/bin/sh

test_description='out of date checking

TopGit branches can be out-of-date with respect to:
  1) one or more of their depedencies
  2) their remote base
  3) their base
  4) their remote

Check for each of these cases separately with both needs_update and
needs_update_check noting that (3) and (4) are never detected by
needs_update and may be disabled for needs_update_check.

Then check each case again using a higher level branch that has
a single dep in one of those states.

Annihilated branches should be ignored for the checks.  It is possible
for an annihilated branch to contain commits not contained by its
dependents if it was annihilated when non-empty and before those
updates had been merged into the dependent(s) base(s).  Check this too.
'


TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 59

switch_to_ref() {
	git symbolic-ref HEAD "$1" &&
	git reset --hard
}

test_expect_success 'setup' '
	test_create_repo outofdate && cd outofdate &&
	tg_test_create_branches <<-EOT &&
		movealong nothing to see here
		:
	
		t/dep the dep
		:

		+t/dep a commit on dep
		:::t/dep

		hasdep one out-of-date dep
		:
		t/dep

		hasbase base is ahead
		:

		rmt1::hasrmt1 remote base is ahead
		:

		rmt2::hasrmt2 remote head is ahead
		:

		+rmt2:hasrmt2 commit on remote head
		:::rmt2/hasrmt2
	EOT
	# have to do the bases by hand
	switch_to_ref "$(tg --top-bases)/hasbase" &&
	test_commit "commit on base" &&
	switch_to_ref "$(tg --top-bases -r rmt1)/hasrmt1" &&
	test_commit "commit on remote base" &&

	# make an up-to-date copy (kinda icky without using tg update)
	cd .. && cp -pR outofdate uptodate && cd uptodate &&
	# make it up-to-date with some -s ours merges
	switch_to_ref "$(tg --top-bases)/hasdep" &&
	test_merge "include dep updates" -s ours t/dep &&
	git checkout -f hasdep &&
	test_merge "include base changes" -s ours "$(tg --top-bases)/hasdep" &&
	git checkout -f hasbase &&
	test_merge "include base changes" -s ours "$(tg --top-bases)/hasbase" &&
	switch_to_ref "$(tg --top-bases)/hasrmt1" &&
	test_merge "include remote base changes" -s ours "$(tg --top-bases -r rmt1)/hasrmt1" &&
	git checkout -f hasrmt1 &&
	test_merge "include base changes" -s ours "$(tg --top-bases)/hasrmt1" &&
	# this last one is a little bit sticky
	git checkout --detach "$(tg --top-bases)/hasrmt2" &&
	test_merge "merge remote head changes onto local base" -s ours rmt2/hasrmt2 &&
	tomerge="$(git rev-parse --verify HEAD --)" &&
	git checkout -f hasrmt2 &&
	test_merge "include remote head changes" -s ours "$tomerge" &&
	cd .. &&

	# now make the upper level branches
	for repo in outofdate uptodate; do
		tg_test_create_branches -C "$repo" <<-EOT &&
			uphasdep dep with $repo dep
			hasdep

			uphasbase dep with $repo base
			hasbase

			uphasrmt1 dep with $repo remote base
			hasrmt1

			uphasrmt2 dep with $repo remote head
			hasrmt2
		EOT
		git -C "$repo" checkout -f movealong &&
		git -C "$repo" clean -d -x -f
	done
'

test_expect_success 'setup more' '
	test_create_repo more && cd more &&
	tg_test_create_branches <<-EOT &&
		dep1 first dep
		:

		+dep1 commit on first dep
		:::dep1

		dep2 second dep
		:

		dep3 third dep
		:

		+dep3 commit on third dep
		:::dep3

		combined branch with all
		dep1
		dep2
		dep3
	EOT
	switch_to_ref "$(tg --top-bases)/combined" &&
	test_merge "bring base up-to-date" -s ours dep2 dep3 &&
	git checkout -f combined &&
	test_merge "bring branch up-to-date" -s ours "$(tg --top-bases)/combined" &&
	git checkout -f dep2 &&
	test_commit "make dep2 dirty" &&
	newc="$(git commit-tree -p dep2 -m "annihilate dep2" "$(tg --top-bases)/dep2"^{tree})" &&
	git update-ref refs/heads/dep2 $newc dep2 &&
	git checkout -f --orphan orphan &&
	git read-tree --empty &&
	git clean -x -d -f
'

test_expect_success 'setup solitary' '
	test_create_repo solitary &&
	tg_test_create_branch -C solitary solitary : &&
	tg_test_create_branch -C solitary +solitary -m "one solitary commit" :::solitary
'

# branch_needs_update level 1

test_expect_success 'branch_needs_update hasdep outofdate' '
	echo "t/dep hasdep" > expected &&
	test_must_fail branch_needs_update -C outofdate hasdep > actual &&
	test_diff expected actual &&
	test_must_fail branch_needs_update -C outofdate -r rmt1 hasdep > actual &&
	test_diff expected actual &&
	test_must_fail branch_needs_update -C outofdate -r rmt2 hasdep > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update hasdep uptodate' '
	> expected &&
	branch_needs_update -C uptodate hasdep > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt1 hasdep > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt2 hasdep > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update hasbase outofdate' '
	> expected &&
	branch_needs_update -C outofdate hasbase > actual &&
	test_diff expected actual &&
	branch_needs_update -C outofdate -r rmt1 hasbase > actual &&
	test_diff expected actual &&
	branch_needs_update -C outofdate -r rmt2 hasbase > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update hasbase uptodate' '
	> expected &&
	branch_needs_update -C uptodate hasbase > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt1 hasbase > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt2 hasbase > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update hasrmt1 outofdate' '
	> expected &&
	echo ":refs/remotes/rmt1/top-bases/hasrmt1 hasrmt1" > expected-base &&
	branch_needs_update -C outofdate hasrmt1 > actual &&
	test_diff expected actual &&
	test_must_fail branch_needs_update -C outofdate -r rmt1 hasrmt1 > actual &&
	test_diff expected-base actual &&
	branch_needs_update -C outofdate -r rmt2 hasrmt1 > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update hasrmt1 uptodate' '
	> expected &&
	branch_needs_update -C uptodate hasrmt1 > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt1 hasrmt1 > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt2 hasrmt1 > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update hasrmt2 outofdate' '
	> expected &&
	branch_needs_update -C outofdate hasrmt2 > actual &&
	test_diff expected actual &&
	branch_needs_update -C outofdate -r rmt1 hasrmt2 > actual &&
	test_diff expected actual &&
	branch_needs_update -C outofdate -r rmt2 hasrmt2 > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update hasrmt2 uptodate' '
	> expected &&
	branch_needs_update -C uptodate hasrmt2 > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt1 hasrmt2 > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt2 hasrmt2 > actual &&
	test_diff expected actual
'

# branch_needs_update level 2

test_expect_success 'branch_needs_update uphasdep outofdate' '
	echo "t/dep hasdep uphasdep" > expected &&
	test_must_fail branch_needs_update -C outofdate uphasdep > actual &&
	test_diff expected actual &&
	test_must_fail branch_needs_update -C outofdate -r rmt1 uphasdep > actual &&
	test_diff expected actual &&
	test_must_fail branch_needs_update -C outofdate -r rmt2 uphasdep > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update uphasdep uptodate' '
	> expected &&
	branch_needs_update -C uptodate uphasdep > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt1 uphasdep > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt2 uphasdep > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update uphasbase outofdate' '
	echo ": hasbase uphasbase" > expected &&
	test_must_fail branch_needs_update -C outofdate uphasbase > actual &&
	test_diff expected actual &&
	test_must_fail branch_needs_update -C outofdate -r rmt1 uphasbase > actual &&
	test_diff expected actual &&
	test_must_fail branch_needs_update -C outofdate -r rmt2 uphasbase > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update uphasbase uptodate' '
	> expected &&
	branch_needs_update -C uptodate uphasbase > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt1 uphasbase > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt2 uphasbase > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update uphasrmt1 outofdate' '
	> expected &&
	echo ":refs/remotes/rmt1/top-bases/hasrmt1 hasrmt1 uphasrmt1" > expected-base &&
	branch_needs_update -C outofdate uphasrmt1 > actual &&
	test_diff expected actual &&
	test_must_fail branch_needs_update -C outofdate -r rmt1 uphasrmt1 > actual &&
	test_diff expected-base actual &&
	branch_needs_update -C outofdate -r rmt2 uphasrmt1 > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update uphasrmt1 uptodate' '
	> expected &&
	branch_needs_update -C uptodate uphasrmt1 > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt1 uphasrmt1 > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt2 uphasrmt1 > actual &&
	test_diff expected actual
'

test_expect_success 'branch_needs_update uphasrmt2 outofdate' '
	> expected &&
	echo ":refs/remotes/rmt2/hasrmt2 hasrmt2 uphasrmt2" > expected-remote &&
	branch_needs_update -C outofdate uphasrmt2 > actual &&
	test_diff expected actual &&
	branch_needs_update -C outofdate -r rmt1 uphasrmt2 > actual &&
	test_diff expected actual &&
	test_must_fail branch_needs_update -C outofdate -r rmt2 uphasrmt2 > actual &&
	test_diff expected-remote actual
'

test_expect_success 'branch_needs_update uphasrmt2 uptodate' '
	> expected &&
	branch_needs_update -C uptodate uphasrmt2 > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt1 uphasrmt2 > actual &&
	test_diff expected actual &&
	branch_needs_update -C uptodate -r rmt2 uphasrmt2 > actual &&
	test_diff expected actual
'

# needs_update_check level 1

test_expect_success 'needs_update_check hasdep outofdate' '
	printf "%s\n" "t/dep hasdep" "hasdep" "t/dep" ":" >expected &&
	needs_update_check -C outofdate hasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt1 hasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt2 hasdep > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check --no-self hasdep outofdate' '
	printf "%s\n" "t/dep hasdep" "hasdep" "t/dep" ":" >expected &&
	needs_update_check -C outofdate --no-self hasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt1 hasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt2 hasdep > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check hasdep uptodate' '
	printf "%s\n" "t/dep hasdep" ":" ":" ":" >expected &&
	needs_update_check -C uptodate hasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt1 hasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt2 hasdep > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check hasbase outofdate' '
	printf "%s\n" "hasbase" "hasbase" ":" ":" >expected &&
	needs_update_check -C outofdate hasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt1 hasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt2 hasbase > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check --no-self hasbase outofdate' '
	printf "%s\n" "hasbase" ":" ":" ":" >expected &&
	needs_update_check -C outofdate --no-self hasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt1 hasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt2 hasbase > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check hasbase uptodate' '
	printf "%s\n" "hasbase" ":" ":" ":" >expected &&
	needs_update_check -C uptodate hasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt1 hasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt2 hasbase > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check hasrmt1 outofdate' '
	printf "%s\n" "hasrmt1" ":" ":" ":" >expected &&
	printf "%s\n" "hasrmt1" "hasrmt1" ":" ":" >expected-remote &&
	needs_update_check -C outofdate hasrmt1 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt1 hasrmt1 > actual &&
	test_diff expected-remote actual &&
	needs_update_check -C outofdate -r rmt2 hasrmt1 > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check --no-self hasrmt1 outofdate' '
	printf "%s\n" "hasrmt1" ":" ":" ":" >expected &&
	needs_update_check -C outofdate --no-self hasrmt1 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt1 hasrmt1 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt2 hasrmt1 > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check hasrmt1 uptodate' '
	printf "%s\n" "hasrmt1" ":" ":" ":" >expected &&
	needs_update_check -C uptodate hasrmt1 > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt1 hasrmt1 > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt2 hasrmt1 > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check hasrmt2 outofdate' '
	printf "%s\n" "hasrmt2" ":" ":" ":" >expected &&
	printf "%s\n" "hasrmt2" "hasrmt2" ":" ":" >expected-remote &&
	needs_update_check -C outofdate hasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt1 hasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt2 hasrmt2 > actual &&
	test_diff expected-remote actual
'

test_expect_success 'needs_update_check --no-self hasrmt2 outofdate' '
	printf "%s\n" "hasrmt2" ":" ":" ":" >expected &&
	needs_update_check -C outofdate --no-self hasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt1 hasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt2 hasrmt2 > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check hasrmt2 uptodate' '
	printf "%s\n" "hasrmt2" ":" ":" ":" >expected &&
	needs_update_check -C uptodate hasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt1 hasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt2 hasrmt2 > actual &&
	test_diff expected actual
'

# needs_update_check level 2

test_expect_success 'needs_update_check uphasdep outofdate' '
	printf "%s\n" "t/dep hasdep uphasdep" "hasdep uphasdep" "t/dep" ":" >expected &&
	needs_update_check -C outofdate uphasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt1 uphasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt2 uphasdep > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check --no-self uphasdep outofdate' '
	printf "%s\n" "t/dep hasdep uphasdep" "hasdep uphasdep" "t/dep" ":" >expected &&
	needs_update_check -C outofdate --no-self uphasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt1 uphasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt2 uphasdep > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check --no-same uphasdep outofdate' '
	printf "%s\n" "t/dep hasdep uphasdep" "hasdep uphasdep" "t/dep" ":" >expected &&
	needs_update_check -C outofdate --no-same uphasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-same -r rmt1 uphasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-same -r rmt2 uphasdep > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check uphasdep uptodate' '
	printf "%s\n" "t/dep hasdep uphasdep" ":" ":" ":" >expected &&
	needs_update_check -C uptodate uphasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt1 uphasdep > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt2 uphasdep > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check uphasbase outofdate' '
	printf "%s\n" "hasbase uphasbase" "hasbase uphasbase" ":" ":" >expected &&
	needs_update_check -C outofdate uphasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt1 uphasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt2 uphasbase > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check --no-self uphasbase outofdate' '
	printf "%s\n" "hasbase uphasbase" "hasbase uphasbase" ":" ":" >expected &&
	needs_update_check -C outofdate --no-self uphasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt1 uphasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt2 uphasbase > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check --no-same uphasbase outofdate' '
	printf "%s\n" "hasbase uphasbase" "uphasbase" ":" ":" >expected &&
	needs_update_check -C outofdate --no-same uphasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-same -r rmt1 uphasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-same -r rmt2 uphasbase > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check uphasbase uptodate' '
	printf "%s\n" "hasbase uphasbase" ":" ":" ":" >expected &&
	needs_update_check -C uptodate uphasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt1 uphasbase > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt2 uphasbase > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check uphasrmt1 outofdate' '
	printf "%s\n" "hasrmt1 uphasrmt1" ":" ":" ":" >expected &&
	printf "%s\n" "hasrmt1 uphasrmt1" "hasrmt1 uphasrmt1" ":" ":" >expected-remote &&
	needs_update_check -C outofdate uphasrmt1 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt1 uphasrmt1 > actual &&
	test_diff expected-remote actual &&
	needs_update_check -C outofdate -r rmt2 uphasrmt1 > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check --no-self uphasrmt1 outofdate' '
	printf "%s\n" "hasrmt1 uphasrmt1" ":" ":" ":" >expected &&
	printf "%s\n" "hasrmt1 uphasrmt1" "hasrmt1 uphasrmt1" ":" ":" >expected-remote &&
	needs_update_check -C outofdate --no-self uphasrmt1 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt1 uphasrmt1 > actual &&
	test_diff expected-remote actual &&
	needs_update_check -C outofdate --no-self -r rmt2 uphasrmt1 > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check --no-same uphasrmt1 outofdate' '
	printf "%s\n" "hasrmt1 uphasrmt1" ":" ":" ":" >expected &&
	printf "%s\n" "hasrmt1 uphasrmt1" "uphasrmt1" ":" ":" >expected-remote &&
	needs_update_check -C outofdate --no-same uphasrmt1 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-same -r rmt1 uphasrmt1 > actual &&
	test_diff expected-remote actual &&
	needs_update_check -C outofdate --no-same -r rmt2 uphasrmt1 > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check uphasrmt1 uptodate' '
	printf "%s\n" "hasrmt1 uphasrmt1" ":" ":" ":" >expected &&
	needs_update_check -C uptodate uphasrmt1 > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt1 uphasrmt1 > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt2 uphasrmt1 > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check uphasrmt2 outofdate' '
	printf "%s\n" "hasrmt2 uphasrmt2" ":" ":" ":" >expected &&
	printf "%s\n" "hasrmt2 uphasrmt2" "hasrmt2 uphasrmt2" ":" ":" >expected-remote &&
	needs_update_check -C outofdate uphasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt1 uphasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate -r rmt2 uphasrmt2 > actual &&
	test_diff expected-remote actual
'

test_expect_success 'needs_update_check --no-self uphasrmt2 outofdate' '
	printf "%s\n" "hasrmt2 uphasrmt2" ":" ":" ":" >expected &&
	printf "%s\n" "hasrmt2 uphasrmt2" "hasrmt2 uphasrmt2" ":" ":" >expected-remote &&
	needs_update_check -C outofdate --no-self uphasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt1 uphasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-self -r rmt2 uphasrmt2 > actual &&
	test_diff expected-remote actual
'

test_expect_success 'needs_update_check --no-same uphasrmt2 outofdate' '
	printf "%s\n" "hasrmt2 uphasrmt2" ":" ":" ":" >expected &&
	printf "%s\n" "hasrmt2 uphasrmt2" "uphasrmt2" ":" ":" >expected-remote &&
	needs_update_check -C outofdate --no-same uphasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-same -r rmt1 uphasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C outofdate --no-same -r rmt2 uphasrmt2 > actual &&
	test_diff expected-remote actual
'

test_expect_success 'needs_update_check uphasrmt2 uptodate' '
	printf "%s\n" "hasrmt2 uphasrmt2" ":" ":" ":" >expected &&
	needs_update_check -C uptodate uphasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt1 uphasrmt2 > actual &&
	test_diff expected actual &&
	needs_update_check -C uptodate -r rmt2 uphasrmt2 > actual &&
	test_diff expected actual
'

# annihilated branch checks

test_expect_success 'branch_needs_update more combined' '
	> expected &&
	branch_needs_update -C more combined > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check more combined' '
	printf "%s\n" "dep1 dep2 dep3 combined" ":" ":" ":" >expected &&
	needs_update_check -C more combined > actual &&
	test_diff expected actual
'

# solitary branch checks

test_expect_success 'branch_needs_update solitary' '
	> expected &&
	branch_needs_update -C solitary solitary > actual &&
	test_diff expected actual
'

test_expect_success 'needs_update_check solitary' '
	printf "%s\n" "solitary" ":" ":" ":" >expected &&
	needs_update_check -C solitary solitary > actual &&
	test_diff expected actual
'

# check summary after checking the machinery itself

squish() {
	tab="	" # single tab in there
	tr -s "$tab" " "
}

printf "%s" "\
      B  hasbase                       	[PATCH] base is ahead
 0  D    hasdep                        	[PATCH] one out-of-date dep
 0       hasrmt1                       	[PATCH] remote base is ahead
 0       hasrmt2                       	[PATCH] remote head is ahead
>0       movealong                     	[PATCH] nothing to see here
       * t/dep                         	[PATCH] the dep
 0  D    uphasbase                     	[PATCH] dep with outofdate base
 0  D    uphasdep                      	[PATCH] dep with outofdate dep
 0       uphasrmt1                     	[PATCH] dep with outofdate remote base
 0       uphasrmt2                     	[PATCH] dep with outofdate remote head
" > outofdate_summary.raw ||
	die failed to make outofdate_summary.raw
< outofdate_summary.raw squish > outofdate_summary ||
	die failed to make outofdate_summary

printf "%s" "\
  l   B  hasbase                       	[PATCH] base is ahead
 0l D    hasdep                        	[PATCH] one out-of-date dep
 0rR     hasrmt1                       	[PATCH] remote base is ahead
 0l      hasrmt2                       	[PATCH] remote head is ahead
>0l      movealong                     	[PATCH] nothing to see here
  l    * t/dep                         	[PATCH] the dep
 0l D    uphasbase                     	[PATCH] dep with outofdate base
 0l D    uphasdep                      	[PATCH] dep with outofdate dep
 0l D    uphasrmt1                     	[PATCH] dep with outofdate remote base
 0l      uphasrmt2                     	[PATCH] dep with outofdate remote head
" > outofdate_summary_rmt1.raw ||
	die failed to make outofdate_summary_rmt1.raw
< outofdate_summary_rmt1.raw squish > outofdate_summary_rmt1 ||
	die failed to make outofdate_summary_rmt1

printf "%s" "\
  l   B  hasbase                       	[PATCH] base is ahead
 0l D    hasdep                        	[PATCH] one out-of-date dep
 0l      hasrmt1                       	[PATCH] remote base is ahead
 0rR     hasrmt2                       	[PATCH] remote head is ahead
>0l      movealong                     	[PATCH] nothing to see here
  l    * t/dep                         	[PATCH] the dep
 0l D    uphasbase                     	[PATCH] dep with outofdate base
 0l D    uphasdep                      	[PATCH] dep with outofdate dep
 0l      uphasrmt1                     	[PATCH] dep with outofdate remote base
 0l D    uphasrmt2                     	[PATCH] dep with outofdate remote head
" > outofdate_summary_rmt2.raw ||
	die failed to make outofdate_summary_rmt2.raw
< outofdate_summary_rmt2.raw squish > outofdate_summary_rmt2 ||
	die failed to make outofdate_summary_rmt2

printf "%s" "\
         hasbase                       	[PATCH] base is ahead
 0       hasdep                        	[PATCH] one out-of-date dep
 0       hasrmt1                       	[PATCH] remote base is ahead
 0       hasrmt2                       	[PATCH] remote head is ahead
>0       movealong                     	[PATCH] nothing to see here
         t/dep                         	[PATCH] the dep
 0       uphasbase                     	[PATCH] dep with uptodate base
 0       uphasdep                      	[PATCH] dep with uptodate dep
 0       uphasrmt1                     	[PATCH] dep with uptodate remote base
 0       uphasrmt2                     	[PATCH] dep with uptodate remote head
" > uptodate_summary.raw ||
	die failed to make uptodate_summary.raw
< uptodate_summary.raw squish > uptodate_summary ||
	die failed to make uptodate_summary

printf "%s" "\
  l      hasbase                       	[PATCH] base is ahead
 0l      hasdep                        	[PATCH] one out-of-date dep
 0rL     hasrmt1                       	[PATCH] remote base is ahead
 0l      hasrmt2                       	[PATCH] remote head is ahead
>0l      movealong                     	[PATCH] nothing to see here
  l      t/dep                         	[PATCH] the dep
 0l      uphasbase                     	[PATCH] dep with uptodate base
 0l      uphasdep                      	[PATCH] dep with uptodate dep
 0l      uphasrmt1                     	[PATCH] dep with uptodate remote base
 0l      uphasrmt2                     	[PATCH] dep with uptodate remote head
" > uptodate_summary_rmt1.raw ||
	die failed to make uptodate_summary_rmt1.raw
< uptodate_summary_rmt1.raw squish > uptodate_summary_rmt1 ||
	die failed to make uptodate_summary_rmt1

printf "%s" "\
  l      hasbase                       	[PATCH] base is ahead
 0l      hasdep                        	[PATCH] one out-of-date dep
 0l      hasrmt1                       	[PATCH] remote base is ahead
 0rL     hasrmt2                       	[PATCH] remote head is ahead
>0l      movealong                     	[PATCH] nothing to see here
  l      t/dep                         	[PATCH] the dep
 0l      uphasbase                     	[PATCH] dep with uptodate base
 0l      uphasdep                      	[PATCH] dep with uptodate dep
 0l      uphasrmt1                     	[PATCH] dep with uptodate remote base
 0l      uphasrmt2                     	[PATCH] dep with uptodate remote head
" > uptodate_summary_rmt2.raw ||
	die failed to make uptodate_summary_rmt2.raw
< uptodate_summary_rmt2.raw squish > uptodate_summary_rmt2 ||
	die failed to make uptodate_summary_rmt2

printf "%s" "\
 0       combined                      	[PATCH] branch with all
         dep1                          	[PATCH] first dep
         dep3                          	[PATCH] third dep
" > more_summary.raw ||
	die failed to make more_summary.raw
< more_summary.raw squish > more_summary ||
	die failed to make more_summary

printf "%s" "\
         solitary                      	[PATCH] branch solitary
" > solitary_summary.raw ||
	die failed to make solitary_summary.raw
< solitary_summary.raw squish > solitary_summary ||
	die failed to make solitary_summary

test_expect_success 'summary outofdate' '
	tg -C outofdate summary > actual.raw &&
	<actual.raw squish >actual &&
	test_diff outofdate_summary actual
'

test_expect_success 'summary outofdate rmt1' '
	tg -C outofdate -r rmt1 summary > actual.raw &&
	<actual.raw squish >actual &&
	test_diff outofdate_summary_rmt1 actual
'

test_expect_success 'summary outofdate rmt2' '
	tg -C outofdate -r rmt2 summary > actual.raw &&
	<actual.raw squish >actual &&
	test_diff outofdate_summary_rmt2 actual
'

test_expect_success 'summary uptodate' '
	tg -C uptodate summary > actual.raw &&
	<actual.raw squish >actual &&
	test_diff uptodate_summary actual
'

test_expect_success 'summary uptodate rmt1' '
	tg -C uptodate -r rmt1 summary > actual.raw &&
	<actual.raw squish >actual &&
	test_diff uptodate_summary_rmt1 actual
'

test_expect_success 'summary uptodate rmt2' '
	tg -C uptodate -r rmt2 summary > actual.raw &&
	<actual.raw squish >actual &&
	test_diff uptodate_summary_rmt2 actual
'

test_expect_success 'more summary' '
	tg -C more summary > actual.raw &&
	<actual.raw squish >actual &&
	test_diff more_summary actual
'

test_expect_success 'solitary summary' '
	tg -C solitary summary > actual.raw &&
	<actual.raw squish >actual &&
	test_diff solitary_summary actual
'

test_done
