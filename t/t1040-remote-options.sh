#!/bin/sh

test_description='tg -r and -u do the right thing

These are a bit tricky to test, but the `tg info` command will show a
"Remote Mate:" line if a matching remote is present so we check for that.

We do also check use of topgit.remote directly here as well and whether
it is set properly by `tg remote`.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 8

test_expect_success 'test setup' '
	test_create_repo mt-remote &&
	test_create_repo remote &&
	test_create_repo noremote &&
	(cd remote && test_commit initial && >.topmsg && >.topdeps && git add -A && test_commit second) &&
	(cd noremote && test_commit initial && >.topmsg && >.topdeps && git add -A && test_commit second) &&
	git -C remote update-ref refs/heads/t/branch master &&
	git -C remote update-ref refs/heads/{top-bases}/t/branch initial &&
	git -C remote update-ref refs/remotes/origin/t/branch master &&
	git -C remote update-ref refs/remotes/origin/{top-bases}/t/branch initial &&
	git -C noremote update-ref refs/heads/t/branch master &&
	git -C noremote update-ref refs/heads/{top-bases}/t/branch initial &&
	git -C remote rev-parse --verify t/branch >/dev/null &&
	git -C remote rev-parse --verify {top-bases}/t/branch >/dev/null &&
	git -C remote rev-parse --verify remotes/origin/t/branch >/dev/null &&
	git -C remote rev-parse --verify remotes/origin/{top-bases}/t/branch >/dev/null &&
	git -C noremote rev-parse --verify t/branch >/dev/null &&
	git -C noremote rev-parse --verify {top-bases}/t/branch >/dev/null &&
	git -C mt-remote config remote.upstream.url . &&
	git -C mt-remote config remote.downstream.url . &&
	test "$(cd mt-remote && git config remote.upstream.url)" = "." &&
	test "$(cd mt-remote && git config remote.downstream.url)" = "."
'

# remote_info <dir> [<options>]
remote_info() {
	ri="$(tg -C "$@" info t/branch | grep "^Remote Mate:")" || :
	ri="${ri#Remote Mate: }"
	ri="${ri%/t/branch}"
	[ -z "$ri" ] || echo "$ri"
}

test_expect_success 'no remote if no remotes' '
	test "$(remote_info noremote)" = "" &&
	test "$(remote_info noremote -r origin)" = "" &&
	test "$(remote_info noremote -r nosuch)" = "" &&
	test "$(remote_info noremote -c topgit.remote=origin)" = "" &&
	test "$(remote_info noremote -c topgit.remote=nosuch)" = ""
'

test_expect_success 'no remote without topgit.remote' '
	test "$(remote_info remote)" = "" &&
	test "$(remote_info remote -r origin -u)" = "" &&
	test "$(remote_info remote -u -c topgit.remote=origin)" = ""
'

test_expect_success 'remote mate with topgit.remote' '
	test "$(remote_info remote -r bad -r origin)" = "origin" &&
	test "$(remote_info remote -c topgit.remote=nosuch -c topgit.remote=origin)" = "origin" &&
	test "$(remote_info remote -r origin -c topgit.remote=nosuch -c topgit.remote=other)" = "origin"
'

test_expect_success 'using -u overrides configed topgit.remote' '
	git -C remote config topgit.remote origin &&
	test "$(cd remote && git config topgit.remote)" = "origin" &&
	test "$(remote_info remote)" = "origin" &&
	test "$(remote_info remote -u)" = ""
'

test_expect_success 'tg remote non-populating does not set topgit.remote' '
	tg -C mt-remote remote upstream &&
	test "$(git -C mt-remote config --get topgit.remote)" = "" &&
	tg -C mt-remote remote downstream &&
	test "$(git -C mt-remote config --get topgit.remote)" = ""
'

test_expect_success 'tg remote --populate sets and changes topgit.remote' '
	tg -C mt-remote remote --populate upstream &&
	test "$(git -C mt-remote config --get topgit.remote)" = "upstream" &&
	tg -C mt-remote remote --populate downstream &&
	test "$(git -C mt-remote config --get topgit.remote)" = "downstream"
'

test_expect_success 'tg remote --populate with bad remote leaves topgit.remote unchanged' '
	test_must_fail tg -C mt-remote remote --populate nosuch >/dev/null 2>&1 &&
	test "$(git -C mt-remote config --get topgit.remote)" = "downstream"
'

test_done
