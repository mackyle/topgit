#!/bin/sh

test_description='tg status

Make sure tg status detects everything it should.
'

. ./test-lib.sh

test_plan 17

test_asv_cache '
	master	sha1	0665c39
	master	sha256	6b313f8
'
test_v_asv mastr7 master

unborn='HEAD -> master [unborn]
working directory is clean'

bareub='HEAD -> master [unborn]'

born="HEAD -> master [$mastr7]
working directory is clean"

bare="HEAD -> master [$mastr7]"

headborn="HEAD -> master [$mastr7]
"
allfixed='
all conflicts fixed; run "git commit" to record result'

unignored="; non-ignored, untracked files present"

moof="; currently updating branch 'moof'"

resultof='
You are currently updating as a result of:
  '

lf='
'

updatecmds='
  (use "tg update --continue" to continue)
  (use "tg update --skip" to skip this branch and continue)
  (use "tg update --stop" to stop and retain changes so far)
  (use "tg update --abort" to restore pre-update state)'

workclean='
working directory is clean'


test_expect_success 'tg status unborn' '
	test "$unborn" = "$(tg status)"
'
test_expect_success 'tg status unborn (bare)' '
	test "$bareub" = "$(tg -C .git -c core.bare=true status 2>&1)"
'

test_expect_success 'tg status unborn untracked' '
	>not-ignored &&
	test "$unborn$unignored" = "$(tg status)" &&
	rm not-ignored
'

test_tick || die

test_expect_success LASTOK 'tg status born' '
	test_commit --notick initial &&
	test "$born" = "$(tg status)"
'

test_expect_success LASTOK 'tg status born (bare)' '
	test "$bare" = "$(tg -C .git -c core.bare=true status 2>&1)"
'

test_expect_success 'tg status born untracked' '
	>not-ignored &&
	test "$born$unignored" = "$(tg status)" &&
	rm not-ignored
'

test_expect_success LASTOK 'tg status merge' '
	>.git/MERGE_HEAD &&
	test "${headborn}git merge in progress$allfixed" = "$(tg status)" &&
	rm -f .git/MERGE_HEAD
'

test_expect_success LASTOK 'tg status am' '
	mkdir .git/rebase-apply &&
	>.git/rebase-apply/applying &&
	test "${headborn}git am in progress" = "$(tg status)" &&
	rm -rf .git/rebase-apply
'

test_expect_success LASTOK 'tg status rebase apply' '
	mkdir .git/rebase-apply &&
	test "${headborn}git rebase in progress" = "$(tg status)" &&
	rm -rf .git/rebase-apply
'

test_expect_success LASTOK 'tg status rebase merge' '
	mkdir .git/rebase-merge &&
	test "${headborn}git rebase in progress" = "$(tg status)" &&
	rm -rf .git/rebase-merge
'

test_expect_success LASTOK 'tg status cherry-pick' '
	>.git/CHERRY_PICK_HEAD &&
	test "${headborn}git cherry-pick in progress" = "$(tg status)" &&
	rm -f .git/CHERRY_PICK_HEAD
'

test_expect_success LASTOK 'tg status bisect' '
	>.git/BISECT_LOG &&
	test "${headborn}git bisect in progress" = "$(tg status)" &&
	rm -f .git/BISECT_LOG
'

test_expect_success LASTOK 'tg status revert' '
	>.git/REVERT_HEAD &&
	test "${headborn}git revert in progress" = "$(tg status)" &&
	rm -f .git/REVERT_HEAD
'

test_expect_success LASTOK 'tg status update' '
	mkdir .git/tg-update &&
	>.git/tg-update/name &&
	test "${headborn}tg update in progress$updatecmds$workclean" = "$(tg status)" &&
	rm -rf .git/tg-update
'

test_expect_success LASTOK 'tg status update moof' '
	mkdir .git/tg-update &&
	echo moof >.git/tg-update/name &&
	test "${headborn}tg update in progress$moof$updatecmds$workclean" = "$(tg status)" &&
	rm -rf .git/tg-update
'

test_expect_success LASTOK 'tg status update moofing moof' '
	mkdir .git/tg-update &&
	echo moof >.git/tg-update/name &&
	echo moof >.git/tg-update/names &&
	echo "moofing moof" > .git/tg-update/fullcmd &&
	test "${headborn}tg update in progress$moof${resultof}moofing moof$updatecmds$workclean" = "$(tg status)" &&
	rm -rf .git/tg-update
'

test_expect_success LASTOK 'tg status update moofing moof woof' '
	mkdir .git/tg-update &&
	echo moof >.git/tg-update/name &&
	echo moof woof >.git/tg-update/names &&
	echo moof >.git/tg-update/processed &&
	echo "moofing moof" > .git/tg-update/fullcmd &&
	test "${headborn}tg update in progress$moof${resultof}moofing moof${lf}1 of 2 branches updated so far$updatecmds$workclean" = "$(tg status)" &&
	rm -rf .git/tg-update
'

test_done
