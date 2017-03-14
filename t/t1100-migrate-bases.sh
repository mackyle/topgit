#!/bin/sh

test_description='tg migrate-bases tests'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 10

test_tick || die

branches='b1 b2 b3'
refs_new="$PWD/refs_new"
refs_old="$PWD/refs_old"
spec_new="$PWD/spec_new"
spec_old="$PWD/spec_old"

setup_refs() {
	(
		tb="top-bases" &&
		if [ "$1" = "--reverse" ]; then
			tb="heads/{top-bases}"
			shift
		fi &&
		cd "$1" &&
		test_commit --notick initial &&
		for b in $branches; do
			git update-ref "refs/heads/$b" initial &&
			git update-ref "refs/$tb/$b" initial || exit 1
		done &&
		if [ -n "$2" ]; then
			git symbolic-ref HEAD "refs/$tb/$b"
		fi &&
		git config remote.origin.url . &&
		git config --add remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" &&
		git config --add remote.origin.fetch "+refs/$tb/*:refs/remotes/origin/${tb#heads/}/*"
	)
	test $? -eq 0
}

show_refnames() {
	git -C "$1" for-each-ref --format="%(refname)" &&
	printf 'HEAD -> ' &&
	git -C "$1" symbolic-ref HEAD
}

show_refspecs() {
	git -C "$1" config --get-regexp '^remote\..*fetch\.*'
}

test_expect_success 'setup' '
	test_create_repo r1 &&
	test_create_repo r2 &&
	test_create_repo r3 &&
	test_create_repo r4 &&
	test_create_repo r5 &&
	test_create_repo r6 &&
	test_create_repo r7 &&
	test_create_repo r8 &&
	setup_refs r1 &&
	setup_refs r2 &&
	setup_refs r3 &&
	setup_refs --reverse r4 &&
	setup_refs --reverse r5 &&
	setup_refs --reverse r6 &&
	show_refnames r1 > "$refs_old" &&
	show_refspecs r1 > "$spec_old" &&
	show_refnames r4 > "$refs_new" &&
	show_refspecs r4 > "$spec_new" &&
	setup_refs r7 1 &&
	setup_refs --reverse r8 1 &&
	show_refnames r7 > "$refs_old-HEAD" &&
	show_refnames r8 > "$refs_new-HEAD"
'

test_expect_success 'invalid options' '
	test_must_fail tg -C r1 migrate-bases --dry-run --no-remotes --remotes-only &&
	test_must_fail tg -C r1 migrate-bases --force --no-remotes --remotes-only &&
	test_must_fail tg -C r1 migrate-bases --no-remotes --remotes-only &&
	test_must_fail tg -C r1 migrate-bases --remotes-only --no-remotes &&
	test_must_fail tg -C r1 migrate-bases --no-remotes &&
	test_must_fail tg -C r1 migrate-bases --remotes-only &&
	test_must_fail tg -C r1 migrate-bases
'

test_expect_success 'migrate old (refs only) to new' '
	show_refnames r1 >refs &&
	show_refspecs r1 >spec &&
	test_cmp refs refs_old &&
	test_cmp spec spec_old &&
	tg -C r1 migrate-bases --dry-run --no-remotes &&
	test_cmp refs refs_old &&
	test_cmp spec spec_old &&
	tg -C r1 migrate-bases --force --no-remotes &&
	show_refnames r1 >refs &&
	show_refspecs r1 >spec &&
	test_cmp refs refs_new &&
	test_cmp spec spec_old
'

test_expect_success 'migrate old (remotes only) to new' '
	show_refnames r2 >refs &&
	show_refspecs r2 >spec &&
	test_cmp refs refs_old &&
	test_cmp spec spec_old &&
	tg -C r2 migrate-bases --dry-run --remotes-only &&
	test_cmp refs refs_old &&
	test_cmp spec spec_old &&
	tg -C r2 migrate-bases --force --remotes-only &&
	show_refnames r2 >refs &&
	show_refspecs r2 >spec &&
	test_cmp refs refs_old &&
	test_cmp spec spec_new
'

test_expect_success 'migrate old (refs & remotes) to new' '
	show_refnames r3 >refs &&
	show_refspecs r3 >spec &&
	test_cmp refs refs_old &&
	test_cmp spec spec_old &&
	tg -C r3 migrate-bases --dry-run &&
	test_cmp refs refs_old &&
	test_cmp spec spec_old &&
	tg -C r3 migrate-bases --force &&
	show_refnames r3 >refs &&
	show_refspecs r3 >spec &&
	test_cmp refs refs_new &&
	test_cmp spec spec_new
'

test_expect_success 'migrate new (refs only) to old' '
	show_refnames r4 >refs &&
	show_refspecs r4 >spec &&
	test_cmp refs refs_new &&
	test_cmp spec spec_new &&
	tg -C r4 migrate-bases --dry-run --reverse --no-remotes &&
	test_cmp refs refs_new &&
	test_cmp spec spec_new &&
	tg -C r4 migrate-bases --force --reverse --no-remotes &&
	show_refnames r4 >refs &&
	show_refspecs r4 >spec &&
	test_cmp refs refs_old &&
	test_cmp spec spec_new
'

test_expect_success 'migrate new (remotes only) to old' '
	show_refnames r5 >refs &&
	show_refspecs r5 >spec &&
	test_cmp refs refs_new &&
	test_cmp spec spec_new &&
	tg -C r5 migrate-bases --dry-run --remotes-only --reverse &&
	test_cmp refs refs_new &&
	test_cmp spec spec_new &&
	tg -C r5 migrate-bases --force --remotes-only --reverse &&
	show_refnames r5 >refs &&
	show_refspecs r5 >spec &&
	test_cmp refs refs_new &&
	test_cmp spec spec_old
'

test_expect_success 'migrate new (refs & remotes) to old' '
	show_refnames r6 >refs &&
	show_refspecs r6 >spec &&
	test_cmp refs refs_new &&
	test_cmp spec spec_new &&
	tg -C r6 migrate-bases --reverse --dry-run &&
	test_cmp refs refs_new &&
	test_cmp spec spec_new &&
	tg -C r6 migrate-bases --reverse --force &&
	show_refnames r6 >refs &&
	show_refspecs r6 >spec &&
	test_cmp refs refs_old &&
	test_cmp spec spec_old
'

test_expect_success 'migrate old top-bases HEAD symref to new' '
	tg -C r7 migrate-bases --force &&
	show_refnames r7 >refs &&
	test_cmp refs refs_new-HEAD
'

test_expect_success 'migrate new top-bases HEAD symref to old' '
	tg -C r8 migrate-bases --force --reverse &&
	show_refnames r8 >refs &&
	test_cmp refs refs_old-HEAD
'

test_done
