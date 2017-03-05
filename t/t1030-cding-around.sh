#!/bin/sh

test_description='tg -C used multiple times works properly'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 3

test_expect_success 'test setup' '
	test_create_repo refs &&
	test_create_repo heads &&
	git -C refs config topgit.top-bases refs &&
	git -C heads config topgit.top-bases heads &&
	test "$(cd refs && git config topgit.top-bases)" = "refs" &&
	test "$(cd heads && git config topgit.top-bases)" = "heads" &&
	mkdir sub &&
	mkdir sub/dir
'

match_str() {
	test "$1" = "$2"
}

test_expect_success 'tg -C gets to refs' '
	match_str "refs/top-bases" "$(tg -C refs --top-bases)" &&
	cd sub &&
	match_str "refs/top-bases" "$(tg -C dir -C .. -C ../refs --top-bases)"
'

test_expect_success 'tg -C gets to heads' '
	match_str "refs/heads/{top-bases}" "$(tg -C heads --top-bases)" &&
	cd sub &&
	match_str "refs/heads/{top-bases}" "$(tg -C dir -C .. -C ../heads --top-bases)"
'

test_done
