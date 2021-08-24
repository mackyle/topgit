#!/bin/sh

test_description='tg update --continue works after merge resolution'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 5

sq="'"

test_expect_success 'setup' '
	test_create_repo conflict &&
	cd conflict &&
	git checkout --orphan fractious &&
	git read-tree --empty &&
	git reset --hard &&
	test_commit "fractious~1" &&
	tg_test_create_branches <<-EOT &&
		t/patch1a [PATCH] patch 1 a
		fractious

		t/patch1b [PATCH] patch 1 b
		fractious

		t/mergeab [STAGE] merge patch 1 a & 1 b
		t/patch1a
		t/patch1b
	EOT
	topbases="$(tg --top-bases)" &&
	topbases="${topbases#refs/heads/}" &&
	[ -n "$topbases" ] &&
	test_when_finished topbases="$topbases" &&
	mergeab_base="$(tg base t/mergeab)" &&
	test_when_finished mergeab_base="$mergeab_base" &&
	git checkout -f t/patch1a &&
	test_commit "alpha" conflict &&
	git checkout -f t/patch1b &&
	test_commit "beta" conflict &&
	cat <<EOT >expected &&
Topic Branch: t/mergeab (1/1 commit)
Subject: [STAGE] merge patch 1 a & 1 b
Dependents: [none]
Base: $mergeab_base
Depends: t/patch1a
         t/patch1b
Needs update from:
	t/patch1a (1/1 commit)
	t/patch1b (2/2 commits)
EOT
	tg info -v t/mergeab >actual &&
	test_cmp actual expected &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'tg update creates conflict' '
	cd conflict &&
	test_must_fail tg update t/mergeab &&
	mergeab_base="$(tg base t/mergeab)" &&
	test_when_finished mergeab_base="$mergeab_base" &&
	cat <<EOT >expected &&
HEAD -> $topbases/t/mergeab [$mergeab_base]
tg update in progress; currently updating branch ${sq}t/mergeab${sq}
You are currently updating as a result of:
  tg update t/mergeab
  (use "tg update --continue" to continue)
  (use "tg update --skip" to skip this branch and continue)
  (use "tg update --stop" to stop and retain changes so far)
  (use "tg update --abort" to restore pre-update state)
git merge in progress
fix conflicts and then "git commit" the result
EOT
	tg status >actual &&
	test_cmp actual expected
'

test_expect_success SETUP,LASTOK 'tg status changes with no conflicts' -<<\EOS
	cd conflict &&
	echo alphabeta >conflict &&
	git add conflict &&
	cat <<EOT >expected &&
HEAD -> $topbases/t/mergeab [$mergeab_base]
tg update in progress; currently updating branch 't/mergeab'
You are currently updating as a result of:
  tg update t/mergeab
  (use "tg update --continue" to continue)
  (use "tg update --skip" to skip this branch and continue)
  (use "tg update --stop" to stop and retain changes so far)
  (use "tg update --abort" to restore pre-update state)
git merge in progress
all conflicts fixed; run "git commit" to record result
EOT
	tg status >actual &&
	test_cmp actual expected
EOS

test_expect_success SETUP,LASTOK 'tg status changes with git merge done' -<<\EOS
	cd conflict &&
	git commit -m 'no conflict' &&
	mergeab_base="$(tg base t/mergeab)" &&
	test_when_finished mergeab_base="$mergeab_base" &&
	cat <<EOT >expected &&
HEAD -> $topbases/t/mergeab [$mergeab_base]
tg update in progress; currently updating branch 't/mergeab'
You are currently updating as a result of:
  tg update t/mergeab
  (use "tg update --continue" to continue)
  (use "tg update --skip" to skip this branch and continue)
  (use "tg update --stop" to stop and retain changes so far)
  (use "tg update --abort" to restore pre-update state)
working directory is clean; non-ignored, untracked files present
EOT
	tg status >actual &&
	test_cmp actual expected
EOS

test_expect_success SETUP,LASTOK 'tg update --continue succeeds' -<<\EOS
	cd conflict &&
	cat <<EOT >expected &&
tg: The base is up-to-date.
tg: Updating t/mergeab against new base...
Merge made by the 'trivial aggressive' strategy.
 1 file changed, 1 insertion(+)
EOT
	tg update --continue >actual &&
	test_cmp actual expected &&
	patch1b="$(git rev-parse --verify --short t/patch1b)" &&
	final="$(git rev-parse --verify --short t/mergeab)" &&
	cat <<EOT >expected &&
HEAD -> t/patch1b [$patch1b]
working directory is clean; non-ignored, untracked files present
EOT
	tg status >actual &&
	test_cmp actual expected &&
	cat <<EOT >expected &&
HEAD -> t/mergeab [$final]
working directory is clean; non-ignored, untracked files present
EOT
	git checkout -f t/mergeab &&
	tg status >actual &&
	test_cmp actual expected
EOS

test_done
