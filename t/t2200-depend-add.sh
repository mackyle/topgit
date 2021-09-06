#!/bin/sh

test_description='tg depend add tests'

. ./test-lib.sh

test_plan 4

# true if $1 is contained by (or the same as) $2
# this is never slower than merge-base --is-ancestor and is often slightly faster
contained_by() {
        [ "$(git rev-list --count --max-count=1 "$1" --not "$2" --)" = "0" ]
}

test_expect_success 'setup' '
	tg_test_create_branches <<-EOT &&
		t/one
		:

		t/two
		:

		t/tri
		:

		t/six
		:

		stage
		:
	EOT
	git checkout -f t/one &&
	test_commit "test one" one.txt &&
	git checkout -f t/two &&
	test_commit "test two" two.txt &&
	git checkout -f t/tri &&
	test_commit "test tri" tri.txt &&
	git checkout -f t/six &&
	test_commit "test six" six.txt &&
	test_when_finished test_tick=$test_tick &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'add multiple deps' '
	git checkout -f stage &&
	test_tick &&
	tg -c topgit.autostash=false depend add t/one t/two t/tri t/six &&
	test_when_finished test_tick=$test_tick &&
	test_when_finished test_set_prereq ADDED
'

test_expect_success ADDED 'four deps added' '
	printf "%s\n" t/one t/two t/tri t/six >expected &&
	test_cmp .topdeps expected
'

test_expect_success ADDED 'dependencies are contained in base' '
	topbases="$(tg --top-bases)" &&
	test -n "$topbases" &&
	contained_by refs/heads/t/one "$topbases/stage" &&
	contained_by refs/heads/t/two "$topbases/stage" &&
	contained_by refs/heads/t/tri "$topbases/stage" &&
	contained_by refs/heads/t/six "$topbases/stage" &&
	contained_by "$topbases/stage" refs/heads/stage
'

test_done
