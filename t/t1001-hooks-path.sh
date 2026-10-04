#!/bin/sh

test_description='hooks path lookup does not need Git or initialize a repository'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 3

test_expect_success 'setup repository and failing Git shim' '
	mkdir outside no-git &&
	test_create_repo repo &&
	tg --hooks-path >expected &&
	write_script no-git/git <<-\EOF
		echo called >"$LOOKUP_MARKER"
		exit 99
	EOF
'

test_expect_success LASTOK 'lookup succeeds without invoking Git inside or outside a repo' '
	lookup_bin="$PWD/no-git" &&
	lookup_marker="$PWD/git-was-called" &&
	for directory in outside repo; do
		(cd "$directory" &&
		 PATH="$lookup_bin" LOOKUP_MARKER="$lookup_marker" \
		 "$TG_TEST_FULL_PATH" --hooks-path) >actual &&
		test_cmp expected actual || return
	done &&
	test ! -e "$lookup_marker"
'

test_expect_success 'lookup does not install hooks or merge attributes' '
	test ! -e repo/.git/info/attributes &&
	test ! -e repo/.git/hooks/pre-commit &&
	tg -C repo --hooks-path >actual &&
	test_cmp expected actual &&
	test ! -e repo/.git/info/attributes &&
	test ! -e repo/.git/hooks/pre-commit &&
	test_must_fail git -C repo config merge.ours.driver
'

test_done
