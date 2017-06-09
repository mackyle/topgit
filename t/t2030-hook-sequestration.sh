#!/bin/sh

test_description='verify hook sequestration works properly'

. ./test-lib.sh

test_plan 11

# makes sure tg_test_setup_topgit will work on non-bin-wrappers testees
PATH="${TG_TEST_FULL_PATH%/*}:$PATH" && export PATH

test_expect_success 'setup' '
	tg_test_setup_topgit &&
	test_commit base &&
	git branch master2 &&
	git branch master3 &&
	git branch master4 &&
	git branch master5 &&
	git branch master6 &&
	git branch master7 &&
	tg_test_create_branch tgb1 master &&
	tg_test_create_branch tgb2 tgb1 &&
	test_tick && test_when_finished test_tick=$test_tick &&
	git checkout tgb1
'

count_commits() {
	git rev-list --count --first-parent HEAD --
}

test_expect_success '.topdeps only does not sequester' '
	git reset --hard &&
	cnt1="$(count_commits)" &&
	echo master2 >> .topdeps &&
	git add .topdeps &&
	git commit -m "modify .topdeps" &&
	cnt2="$(count_commits)" &&
	test $(( $cnt1 + 1 )) -eq $cnt2
'

test_expect_success '.topmsg only does not sequester' '
	git reset --hard &&
	cnt1="$(count_commits)" &&
	echo "do dah do dah do dah doo" >> .topmsg &&
	git add .topmsg &&
	git commit -m "modify .topmsg" &&
	cnt2="$(count_commits)" &&
	test $(( $cnt1 + 1 )) -eq $cnt2
'

test_expect_success '.topdeps & .topmsg only does not sequester' '
	git reset --hard &&
	cnt1="$(count_commits)" &&
	echo master3 >> .topdeps &&
	git add .topdeps &&
	echo "doo dah doo do dah doo" >> .topmsg &&
	git add .topmsg &&
	git commit -m "modify .topdeps & .topmsg" &&
	cnt2="$(count_commits)" &&
	test $(( $cnt1 + 1 )) -eq $cnt2
'

test_expect_success 'non .top* commit does not sequester' '
	git reset --hard &&
	cnt1="$(count_commits)" &&
	test_commit hello &&
	cnt2="$(count_commits)" &&
	test $(( $cnt1 + 1 )) -eq $cnt2
'

test_expect_success '.topdeps and other sequesters' '
	git reset --hard &&
	cnt1="$(count_commits)" &&
	echo master4 >> .topdeps &&
	git add .topdeps &&
	echo other1 > other1 &&
	git add other1 &&
	test_must_fail git commit -m "modify .topdeps and add other1" &&
	cnt2="$(count_commits)" &&
	test $(( $cnt1 + 1 )) -eq $cnt2 &&
	git commit -m "just add other1" &&
	cnt3="$(count_commits)" &&
	test $(( $cnt1 + 2 )) -eq $cnt3
'

test_expect_success '.topmsg and other sequesters' '
	git reset --hard &&
	git config --bool topgit.sequester true &&
	cnt1="$(count_commits)" &&
	echo "do dah do dah do dah do dah doo" >> .topmsg &&
	git add .topmsg &&
	echo other2 > other2 &&
	git add other2 &&
	test_must_fail git commit -m "modify .topdeps and add other2" &&
	cnt2="$(count_commits)" &&
	test $(( $cnt1 + 1 )) -eq $cnt2 &&
	git commit -m "just add other2" &&
	cnt3="$(count_commits)" &&
	test $(( $cnt1 + 2 )) -eq $cnt3
'

test_expect_success '.topdeps and .topmsg and other sequesters' '
	git reset --hard &&
	cnt1="$(count_commits)" &&
	echo master5 >> .topdeps &&
	git add .topdeps &&
	echo "do dah do dah do dah doo" >> .topmsg &&
	git add .topmsg &&
	echo other3 > other3 &&
	git add other3 &&
	test_must_fail git commit -m "modify .topdeps and add other3" &&
	cnt2="$(count_commits)" &&
	test $(( $cnt1 + 1 )) -eq $cnt2 &&
	git commit -m "just add other3" &&
	cnt3="$(count_commits)" &&
	test $(( $cnt1 + 2 )) -eq $cnt3
'

test_expect_success '.topdeps and other sequester bypass' '
	git reset --hard &&
	git config --bool topgit.sequester false &&
	cnt1="$(count_commits)" &&
	echo master6 >> .topdeps &&
	git add .topdeps &&
	echo other4 > other4 &&
	git add other4 &&
	git commit -m "modify .topdeps and add other4" &&
	cnt2="$(count_commits)" &&
	test $(( $cnt1 + 1 )) -eq $cnt2
'

test_expect_success '.topmsg and other sequester bypass' '
	git reset --hard &&
	cnt1="$(count_commits)" &&
	echo "doo dah doo do dah doo" >> .topmsg &&
	git add .topmsg &&
	echo other5 > other5 &&
	git add other5 &&
	git commit -m "modify .topmsg and add other5" &&
	cnt2="$(count_commits)" &&
	test $(( $cnt1 + 1 )) -eq $cnt2
'

test_expect_success '.topdeps and .topmsg and other sequester bypass' '
	git reset --hard &&
	cnt1="$(count_commits)" &&
	echo master7 >> .topdeps &&
	git add .topdeps &&
	echo "do dah do dah do dah do dah doo" >> .topmsg &&
	git add .topmsg &&
	echo other6 > other6 &&
	git add other6 &&
	git commit -m "modify .topdeps and .topmsg and add other6" &&
	cnt2="$(count_commits)" &&
	test $(( $cnt1 + 1 )) -eq $cnt2
'

test_done
