#!/bin/sh

test_description='tg update --base mode tests'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_clone_repo_cd() {
	[ -d "r0" ] || die missing setup-created r0 repo
	! [ -e "$1" ] || rm -rf "$1"
	! [ -e "$1" ] || { chmod -R u+rw "$1"; rm -rf "$1"; }
	! [ -e "$1" ] || die
	cp -pR r0 "$1" &&
	cd "$1"
}

get_msg() {
	git --no-pager log --no-color -n 1 --format=format:%B "$@"
}

test_plan 9

test_expect_success 'setup' '
	test_create_repo r0 && cd r0 &&
	test_commit first &&
	test_commit second &&
	git checkout --orphan annie &&
	git read-tree --empty &&
	test_commit orphan &&
	git checkout -f -b alt first &&
	test_commit third &&
	tg_test_create_branch tgbase -m "[BASE] tgbase" :first &&
	git checkout -f tgbase &&
	git clean -x -d -f
'

test_expect_success 'related update allowed' '
	test_clone_repo_cd r1 &&
	EDITOR="echo editor >" && export EDITOR &&
	tg update -f --base tgbase alt
'

test_expect_success 'non-fast-forward update denied' '
	test_clone_repo_cd r1 &&
	EDITOR="echo editor >" && export EDITOR &&
	test_must_fail tg update --base tgbase orphan
'

test_expect_success 'non-fast-forward allowed with -f' '
	test_clone_repo_cd r1 &&
	EDITOR="echo editor >" && export EDITOR &&
	tg update -f --base tgbase orphan
'

test_expect_success 'related update custom message' '
	test_clone_repo_cd r1 &&
	EDITOR="echo editor >" && export EDITOR &&
	tg update -f --base -m message tgbase alt &&
	test z"message" = z"$(get_msg tgbase)"
'

test_expect_success 'related update custom message file' '
	test_clone_repo_cd r1 &&
	EDITOR="echo editor >" && export EDITOR &&
	printf "%s" "\
merging it in now...

yes we are.
too.
" >expect &&
	tg update -f --base -F expect tgbase alt &&
	get_msg tgbase >actual &&
	test_diff expect actual
'

test_expect_success 'related update --no-edit' '
	test_clone_repo_cd r1 &&
	EDITOR="echo editor >" && export EDITOR &&
	tg update -f --base --no-edit tgbase alt &&
	test z"tg update --base tgbase alt" = z"$(get_msg tgbase)"
'

test_expect_success 'related update --edit' '
	test_clone_repo_cd r1 &&
	EDITOR="f(){ cp \"\$1\" \"$PWD/editmsg\";echo editor >\"\$1\";};f" && export EDITOR &&
	tg update -f --base --edit tgbase alt &&
	test z"editor" = z"$(get_msg tgbase)" &&
	test z"tg update --base tgbase alt" = z"$(git stripspace -s <editmsg)"
'

test_expect_success 'related update --edit --message' '
	test_clone_repo_cd r1 &&
	EDITOR="f(){ cp \"\$1\" \"$PWD/editmsg\";echo editor >\"\$1\";};f" && export EDITOR &&
	tg update -f --base --edit --message "lah dee dah" tgbase alt &&
	test z"editor" = z"$(get_msg tgbase)" &&
	test z"lah dee dah" = z"$(git stripspace -s <editmsg)"
'

test_done
