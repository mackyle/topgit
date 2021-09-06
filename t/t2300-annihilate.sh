#!/bin/sh

test_description='tg annihilate tests'

. ./test-lib.sh

test_plan 7

# true if $1 is contained by (or the same as) $2
# this is never slower than merge-base --is-ancestor and is often slightly faster
contained_by() {
        [ "$(git rev-list --count --max-count=1 "$1" --not "$2" --)" = "0" ]
}

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

expfile="$(test_get_temp expected)" || die
actfile="$(test_get_temp actual)" || die

test_expect_success 'setup' '
	tg_test_create_branches <<-EOT &&
		t/lefta
		:

		t/leftb
		:

		t/righta
		:

		t/rightb
		:
	EOT
	git checkout -f t/lefta &&
	test_commit "left eh" lefta.txt &&
	git checkout -f t/leftb &&
	test_commit "left be" leftb.txt &&
	git checkout -f t/righta &&
	test_commit "right eh" righta.txt &&
	git checkout -f t/rightb &&
	test_commit "right be" rightb.txt &&
	tg_test_create_branches <<-EOT &&
		t/int0
		t/lefta
		t/leftb

		t/int1
		t/righta
		t/rightb
	EOT
	git checkout -f t/int0 &&
	test_tick &&
	tg update --no-stash &&
	test_tick &&
	git commit --amend --reset-author --no-edit --only -- &&
	git checkout -f t/int1 &&
	test_tick &&
	tg update --no-stash &&
	test_tick &&
	git commit --amend --reset-author --no-edit --only -- &&
	test_commit "int won" int1.txt &&
	tg_test_create_branch stage -m "[STAGE] all together now" t/int0 t/int1 &&
	git checkout -f stage &&
	test_tick &&
	tg update --no-stash &&
	test_tick &&
	git commit --amend --reset-author --no-edit --only -- &&
	printf "%s\n" stage t/int0 t/int1 t/lefta t/leftb t/righta t/rightb >"$expfile" &&
	tg summary --terse >"$actfile" &&
	test_cmp "$actfile" "$expfile" &&
	branch_is_up_to_date stage &&
	test_when_finished test_tick=$test_tick &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'modify t/leftb' '
	branch_is_up_to_date stage &&
	git checkout -f t/leftb &&
	test_commit "left ex" leftx.txt &&
	test_must_fail branch_is_up_to_date stage &&
	test_when_finished test_tick=$test_tick
'

test_expect_success SETUP 'annihilate int0 works' '
	test_tick &&
	tg annihilate --no-stash t/int0 &&
	printf "%s\n" stage t/int1 t/lefta t/leftb t/righta t/rightb >"$expfile" &&
	tg summary --terse >"$actfile" &&
	test_cmp "$actfile" "$expfile" &&
	branch_is_up_to_date stage &&
	test_when_finished test_tick=$test_tick
'

test_expect_success SETUP 'annihilate int1 fails' '
	test_must_fail tg annihilate --no-stash t/int1 &&
	printf "%s\n" stage t/int1 t/lefta t/leftb t/righta t/rightb >"$expfile" &&
	tg summary --terse >"$actfile" &&
	test_cmp "$actfile" "$expfile"
'

test_expect_success SETUP 'modify t/rightb' '
	branch_is_up_to_date stage &&
	git checkout -f t/rightb &&
	test_commit "right ex" rightx.txt &&
	test_must_fail branch_is_up_to_date stage &&
	test_when_finished test_tick=$test_tick
'

test_expect_success SETUP 'anniliate --force int1 succeeds' '
	test_tick &&
	tg annihilate --no-stash --force t/int1 &&
	printf "%s\n" stage t/lefta t/leftb t/righta t/rightb >"$expfile" &&
	tg summary --terse >"$actfile" &&
	test_cmp "$actfile" "$expfile" &&
	branch_is_up_to_date stage &&
	test_when_finished test_tick=$test_tick
'

test_expect_success SETUP 'verify branch up-to-date containment' '
	topbases="$(tg --top-bases)" &&
	test -n "$topbases" &&
	contained_by "$topbases/t/lefta" refs/heads/t/lefta &&
	contained_by "$topbases/t/leftb" refs/heads/t/leftb &&
	contained_by "$topbases/t/righta" refs/heads/t/righta &&
	contained_by "$topbases/t/rightb" refs/heads/t/rightb &&
	contained_by refs/heads/t/lefta "$topbases/stage" &&
	contained_by refs/heads/t/leftb "$topbases/stage" &&
	contained_by refs/heads/t/righta "$topbases/stage" &&
	contained_by refs/heads/t/rightb "$topbases/stage" &&
	contained_by "$topbases/stage" refs/heads/stage
'

test_done
