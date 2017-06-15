#!/bin/sh

test_description='tg create tests'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 14

test_recreate_repo_cd() {
	! [ -e "$1" ] || rm -rf "$1"
	! [ -e "$1" ] || { chmod -R u+rw "$1"; rm -rf "$1"; }
	! [ -e "$1" ] || die
	test_create_repo "$1" &&
	cd "$1"
}

shell() { bash -i <>/dev/tty >&0 2>&1; }

test_expect_success 'tg create works' '
	test_recreate_repo_cd r0 &&
	test_commit first &&
	tg create --topmsg subject:tgbranch tgb &&
	printf "%s\n" first >expected &&
	test_diff expected first.t &&
	printf "%s\n" subject:tgbranch >expected &&
	test_diff expected .topmsg &&
	printf "%s\n" master >expected &&
	test_diff expected .topdeps &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2
'

test_expect_success 'tg create bad usage' '
	test_recreate_repo_cd r0 &&
	test_must_fail tg create &&
	test_must_fail tg create --no-deps &&
	test_must_fail tg create --base &&
	test_must_fail tg create HEAD &&
	test_must_fail tg create @ &&
	test_must_fail tg create --no-deps foo bar &&
	test_commit first^1 &&
	git branch master2 &&
	test_must_fail tg create master &&
	test_must_fail tg create HEAD &&
	test_must_fail tg create @ &&
	test_must_fail tg create tgbranch xmaster &&
	test_must_fail tg create tgbranch master xmaster &&
	test_must_fail tg create tgbranch xmaster master &&
	test_must_fail tg create --no-deps tgbranch xmaster master &&
	test_must_fail tg create --no-deps tgbranch master xmaster
'

test_expect_success 'tg create reformats subject and works on unborn HEAD' '
	test_recreate_repo_cd r0 &&
	tg create --no-deps --topmsg first HEAD &&
	test z"$(git symbolic-ref HEAD)" = z"refs/heads/master" &&
	test -e .topdeps && test ! -s .topdeps &&
	printf "%s\n" "Subject: [ROOT] first" >expected &&
	test_diff expected .topmsg &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2 # still two with empty base commit
'

test_expect_success 'tg create reformats subject and works on unborn @' '
	test_recreate_repo_cd r0 &&
	tg create --no-deps --topmsg first @ &&
	test z"$(git symbolic-ref HEAD)" = z"refs/heads/master" &&
	test -e .topdeps && test ! -s .topdeps &&
	printf "%s\n" "Subject: [ROOT] first" >expected &&
	test_diff expected .topmsg &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2 # still two with empty base commit
'

test_expect_success 'tg create reformats subject and works on unborn master' '
	test_recreate_repo_cd r0 &&
	tg create --no-deps --topmsg first master &&
	test z"$(git symbolic-ref HEAD)" = z"refs/heads/master" &&
	test -e .topdeps && test ! -s .topdeps &&
	printf "%s\n" "Subject: [ROOT] first" >expected &&
	test_diff expected .topmsg &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2 # still two with empty base commit
'

test_expect_success 'tg create reformats subject and works on unborn anything' '
	test_recreate_repo_cd r0 &&
	tg create --no-deps --topmsg first anything &&
	test z"$(git symbolic-ref HEAD)" = z"refs/heads/anything" &&
	test -e .topdeps && test ! -s .topdeps &&
	printf "%s\n" "Subject: [ROOT] first" >expected &&
	test_diff expected .topmsg &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2 # still two with empty base commit
'

test_expect_success 'tg create --no-deps reformats subject as [BASE]' '
	test_recreate_repo_cd r0 &&
	test_commit first &&
	tg create --no-deps --topmsg first tgb HEAD &&
	test -e .topdeps && test ! -s .topdeps &&
	printf "%s\n" "Subject: [BASE] first" >expected &&
	test_diff expected .topmsg &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2
'

test_expect_success 'tg create --base reformats subject as [BASE]' '
	test_recreate_repo_cd r0 &&
	test_commit first &&
	tg create --no-deps --topmsg first tgb HEAD &&
	test -e .topdeps && test ! -s .topdeps &&
	printf "%s\n" "Subject: [BASE] first" >expected &&
	test_diff expected .topmsg &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2
'

test_expect_success 'tg create --base works with explicit branch' '
	test_recreate_repo_cd r0 &&
	test_commit first &&
	tg create --no-deps --topmsg first tgb master &&
	test -e .topdeps && test ! -s .topdeps &&
	printf "%s\n" "Subject: [BASE] first" >expected &&
	test_diff expected .topmsg &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2
'

test_expect_success 'tg create --base works with explicit non-HEAD branch' '
	test_recreate_repo_cd r0 &&
	test_commit first &&
	git branch start &&
	test_commit second &&
	tg create --no-deps --topmsg first tgb start &&
	test -e .topdeps && test ! -s .topdeps &&
	printf "%s\n" "Subject: [BASE] first" >expected &&
	test_diff expected .topmsg &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2
'

test_expect_success 'tg create --base works with explicit non-branch ref' '
	test_recreate_repo_cd r0 &&
	test_commit first && # creates tag "first"
	git branch start &&
	test_commit second &&
	tg create --no-deps --topmsg first tgb first^0 &&
	test -e .topdeps && test ! -s .topdeps &&
	printf "%s\n" "Subject: [BASE] first" >expected &&
	test_diff expected .topmsg &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2
'

test_expect_success 'tg create --base works with explicit non-branch ref' '
	test_recreate_repo_cd r0 &&
	test_commit first && # creates tag "first"
	git branch start &&
	test_commit second &&
	tg create --no-deps --topmsg first tgb first^0 &&
	test -e .topdeps && test ! -s .topdeps &&
	printf "%s\n" "Subject: [BASE] first" >expected &&
	test_diff expected .topmsg &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2
'

test_expect_success 'tg create with @' '
	test_recreate_repo_cd r0 &&
	test_commit first^one &&
	git checkout master && # should be nop
	tg create --topmsg subject:t/master t/master @ &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 2	
'

test_expect_success 'tg create multiple deps' '
	test_recreate_repo_cd r0 &&
	test_commit first^one &&
	git branch first &&
	test_commit second^one &&
	tg create --topmsg subject:multi tgb first @ &&
	printf "%s\n" first master >expected &&
	test_diff expected .topdeps &&
	printf "%s\n" "subject:multi" >expected &&
	test_diff expected .topmsg &&
	cnt="$(git rev-list --count HEAD)" &&
	test $cnt -eq 4 &&
	test_cmp_rev first HEAD^^ &&
	test_cmp_rev master HEAD^2 &&
	cnt="$(git rev-list --count HEAD^)" &&
	test $cnt -eq 2
'

test_done
