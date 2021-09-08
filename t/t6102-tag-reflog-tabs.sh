#!/bin/sh

test_description='check tg tag reflog -g with tabs'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 4

tab='	' # single tab in there

squish() { tr -s "$tab" " " | sed 's/  *$//'; }

unset_names() {
	unset GIT_AUTHOR_NAME || :
	unset GIT_AUTHOR_EMAIL || :
	unset GIT_COMMITTER_NAME || :
	unset GIT_COMMITTER_EMAIL || :
} >/dev/null 2>&1

# $1 is name of file (and contents)
# $2 is commit message
# $3 is update-ref message
# requires a pre-existing commit on HEAD
test_commit_dual_msg() {
	printf '%s\n' "$1" >"$1" &&
	git add "$1" &&
	_tcdmt="$(git write-tree)" &&
	test -n "$_tcdmt" &&
	test_tick &&
	_tcdmc="$(git commit-tree </dev/null ${2:+-m} ${2:+"$2"} -p HEAD "$_tcdmt")" &&
	test -n "$_tcdmc" &&
	test_tick &&
	git update-ref ${3:+-m} ${3:+"$3"} HEAD "$_tcdmc" HEAD
}

test_expect_success 'setup main' '
	test_create_repo main &&
	cd main &&
	unset_names &&
	git config user.name "I $tab l<o>ve $tab tabs!" &&
	git config user.email "Some $tab L<o>ving $tab Place!" &&
	git checkout --orphan slithy &&
	while git reflog delete HEAD@{1} >/dev/null 2>&1; do :; done &&
	{ git reflog delete HEAD@{0} >/dev/null 2>&1 || :; } &&

	echo slithy > slithy &&
	git add slithy &&
	thetree="$(git write-tree)" &&
	test -n "$thetree" &&
	test_tick &&
	thecommit="$(git commit-tree -m "slithy $tab is $tab here" "$thetree")" &&
	test -n "$thecommit" &&
	test_tick &&
	git update-ref -m "0th $tab update $tab <slithy>" HEAD "$thecommit" &&
	git rev-parse --verify HEAD -- >/dev/null &&
	cslithy="$(git rev-parse --verify --short HEAD)" &&
	test -n "$cslithy" &&
	test_when_finished cslithy="$cslithy" &&

	echo outgrabe > outgrabe &&
	git add outgrabe &&
	thetree="$(git write-tree)" &&
	test -n "$thetree" &&
	test_tick &&
	thecommit="$(git commit-tree -m "outgrabe $tab is $tab here" -p "$cslithy" "$thetree")" &&
	test -n "$thecommit" &&
	test_tick &&
	git update-ref HEAD "$thecommit" && # NO MESSAGE THIS TIME
	git rev-parse --verify HEAD -- >/dev/null &&
	coutgrabe="$(git rev-parse --verify --short HEAD)" &&
	test -n "$coutgrabe" &&
	test_when_finished coutgrabe="$coutgrabe" &&

	test_commit_dual_msg "fir${tab}st" "1st $tab commit" "1st $tab u<p>date" &&
	cfirst="$(git rev-parse --verify --short HEAD)" &&
	test -n "$cfirst" &&
	test_when_finished cfirst="$cfirst" &&

	test_commit_dual_msg "sec${tab}nd" "2nd $tab commit" "2nd $tab up<d>ate" &&
	csecond="$(git rev-parse --verify --short HEAD)" &&
	test -n "$csecond" &&
	test_when_finished csecond="$csecond" &&

	test_commit_dual_msg "thi${tab}rd" "3rd $tab commit" "3rd $tab upd<a>te" &&
	cthird="$(git rev-parse --verify --short HEAD)" &&
	test -n "$cthird" &&
	test_when_finished cthird="$cthird" &&

	test_commit_dual_msg "four${tab}th" "4th $tab commit" "4th $tab <update> 1234567890 +0000" &&
	cfourth="$(git rev-parse --verify --short HEAD)" &&
	test -n "$cfourth" &&
	test_when_finished cfourth="$cfourth" &&

	test_commit_dual_msg "fif${tab}th${tab}empty" "" "" &&
	cfifth="$(git rev-parse --verify --short HEAD)" &&
	test -n "$cfifth" &&
	test_when_finished cfifth="$cfifth" &&

	squish <<-EOT >../expected &&
		$cfifth HEAD@{0}:
		$cfourth HEAD@{1}: 4th <update> 1234567890 +0000
		$cthird HEAD@{2}: 3rd upd<a>te
		$csecond HEAD@{3}: 2nd up<d>ate
		$cfirst HEAD@{4}: 1st u<p>date
		$coutgrabe HEAD@{5}:
		$cslithy HEAD@{6}: 0th update <slithy>
	EOT
	git log -g --oneline --abbrev-commit --no-decorate HEAD | squish >../actual &&
	test_cmp ../actual ../expected &&
	test_when_finished test_tick=$test_tick &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'tg tag -g log' '
	cd main &&
	squish <<-EOT >../expected &&
		=== 2005-04-07 ===
		$cfifth 22:26:13 (commit) HEAD@{0}:
		$cfourth 22:24:13 (commit) HEAD@{1}: 4th <update> 1234567890 +0000
		$cthird 22:22:13 (commit) HEAD@{2}: 3rd upd<a>te
		$csecond 22:20:13 (commit) HEAD@{3}: 2nd up<d>ate
		$cfirst 22:18:13 (commit) HEAD@{4}: 1st u<p>date
		$coutgrabe 22:16:13 (commit) HEAD@{5}: outgrabe 	 is 	 here
		$cslithy 22:14:13 (commit) HEAD@{6}: 0th update <slithy>
	EOT
	tg tag -g HEAD | squish >../actual &&
	test_cmp ../actual ../expected
'

test_expect_success LASTOK,SETUP 'tg tag -g --reflog-message matches' '
	cd main &&
	tg tag -g --reflog-message HEAD | squish >../actual &&
	test_cmp ../actual ../expected
'

test_expect_success SETUP 'tg tag -g --commit-message log' '
	cd main &&
	squish <<-EOT >../expected2 &&
		=== 2005-04-07 ===
		$cfifth 22:26:13 (commit) HEAD@{0}:
		$cfourth 22:24:13 (commit) HEAD@{1}: 4th 	 commit
		$cthird 22:22:13 (commit) HEAD@{2}: 3rd 	 commit
		$csecond 22:20:13 (commit) HEAD@{3}: 2nd 	 commit
		$cfirst 22:18:13 (commit) HEAD@{4}: 1st 	 commit
		$coutgrabe 22:16:13 (commit) HEAD@{5}: outgrabe 	 is 	 here
		$cslithy 22:14:13 (commit) HEAD@{6}: slithy 	 is 	 here
	EOT
	tg tag -g --commit-message HEAD | squish >../actual2 &&
	test_cmp ../actual2 ../expected2
'

test_done
