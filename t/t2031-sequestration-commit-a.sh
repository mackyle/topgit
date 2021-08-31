#!/bin/sh

test_description='verify sequestration works properly with commit -a'

. ./test-lib.sh

test_plan 4

tmp="$(test_get_temp -d cmp)" && [ -n "$tmp" ] && [ -d "$tmp" ] || die

test_expect_success 'setup' '
        tg_test_setup_topgit &&
	tg_test_create_branch t/frabjous : &&
	git checkout -f t/frabjous &&
	test_commit "test commit" file test
'

test_expect_success LASTOK 'modified status as expected' '
	>"$tmp/expected" &&
	git status --porcelain >"$tmp/actual" &&
	test_cmp "$tmp/actual" "$tmp/expected" &&
	printf "%s\n" "" "patch description" >>.topmsg &&
	echo file >>file &&
	printf "%s\n" " M .topmsg" " M file" >"$tmp/expected" &&
	git status --porcelain >"$tmp/actual" &&
	test_cmp "$tmp/actual" "$tmp/expected"
'

test_expect_failure LASTOK 'commit -a sequesters .topmsg' '
	h0="$(git rev-parse --verify HEAD --)" && test -n "$h0" &&
	test_must_fail git commit -am test &&
	h1="$(git rev-parse --verify HEAD --)" && test -n "$h1" &&
	test "$h0" != "$h1" &&
	printf "%s\n" " M file" >"$tmp/expected" &&
	git status --porcelain >"$tmp/actual" &&
	test_cmp "$tmp/actual" "$tmp/expected"
'

test_expect_success LASTOK 'commit once more, with feeling' '
	h0="$(git rev-parse --verify HEAD --)" && test -n "$h0" &&
	git commit -am test &&
	h1="$(git rev-parse --verify HEAD --)" && test -n "$h1" &&
	test "$h0" != "$h1" &&
	>"$tmp/expected" &&
	git status --porcelain >"$tmp/actual" &&
	test_cmp "$tmp/actual" "$tmp/expected"
'

test_done
