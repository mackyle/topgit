#!/bin/sh

test_description='test --no-edit and --topmsg etc. modes of tg create'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_recreate_repo_cd() {
	! [ -e "$1" ] || rm -rf "$1"
	! [ -e "$1" ] || { chmod -R u+rw "$1"; rm -rf "$1"; }
	! [ -e "$1" ] || die
	test_create_repo "$1" &&
	cd "$1"
}

tmf="$(test_get_temp topmsg)" || die

test_plan 12

test_expect_success 'root create --topmsg with "subject:"' '
	test_recreate_repo_cd r0 &&
	tg create --no-deps --topmsg "  SuBjEcT :  My  Subject  " HEAD &&
	printf "%s\n" "SuBjEcT :  My  Subject" >expect &&
	test_diff expect .topmsg
'

test_expect_success 'root create --topmsg without "subject:"' '
	test_recreate_repo_cd r0 &&
	tg create --no-deps --topmsg "  My  Subject  " HEAD &&
	printf "%s\n" "Subject: [ROOT] My  Subject" >expect &&
	test_diff expect .topmsg
'

test_expect_success 'root create --topmsg-file with "subject:"' '
	test_recreate_repo_cd r0 &&
	printf "%s\n" "From: somewhere" "Out: there" "sUbJeCt  :   My  Subj  " "#more" >"$tmf" &&
	tg create --no-deps --topmsg-file "$tmf" HEAD &&
	git stripspace <"$tmf" >expect &&
	test_diff expect .topmsg
'

test_expect_success 'root create --topmsg-file without "subject:"' '
	test_recreate_repo_cd r0 &&
	printf "%s\n" "From: somewhere" "Out: there" "" "sUbJeCt  :   My  Subj  " "#more" >"$tmf" &&
	tg create --no-deps --topmsg-file "$tmf" HEAD &&
	# this is very ugly, but it is not a freaking AI!
	{ printf "%s\n" "Subject: [ROOT] From: somewhere" "" &&
	sed -n "2,\$p" <"$tmf"; } | git stripspace >expect &&
	test_diff expect .topmsg
'

test_expect_success 'base create --topmsg with "subject:"' '
	test_recreate_repo_cd r0 &&
	test_commit first^one &&
	tg create --no-deps --topmsg "  SuBjEcT :  My  Subject  " tgb &&
	printf "%s\n" "SuBjEcT :  My  Subject" >expect &&
	test_diff expect .topmsg
'

test_expect_success 'base create --topmsg without "subject:"' '
	test_recreate_repo_cd r0 &&
	test_commit first^one &&
	tg create --no-deps --topmsg "  My  Subject  " tgb &&
	printf "%s\n" "Subject: [BASE] My  Subject" >expect &&
	test_diff expect .topmsg
'

test_expect_success 'patch create --topmsg with "subject:"' '
	test_recreate_repo_cd r0 &&
	test_commit first^one &&
	tg create --topmsg "  SuBjEcT :  My  Subject  " tgb &&
	printf "%s\n" "SuBjEcT :  My  Subject" >expect &&
	test_diff expect .topmsg
'

test_expect_success 'patch create --topmsg without "subject:"' '
	test_recreate_repo_cd r0 &&
	test_commit first^one &&
	tg create --topmsg "  My  Subject  " tgb &&
	printf "%s\n" "Subject: [PATCH] My  Subject" >expect &&
	test_diff expect .topmsg
'

test_expect_success 'patch create --no-edit' '
	test_recreate_repo_cd r0 &&
	test_commit first^one &&
	bcnt="$(git rev-list --count --all)" &&
	EDITOR="echo x >" && export EDITOR &&
	tg create --no-edit tgb &&
	acnt="$(git rev-list --count --all)" &&
	test $acnt -gt $bcnt &&
	printf "%s" "\
From: Te s t (Author) <test@example.net>
Subject: [PATCH] tgb
" >expect &&
	test_diff expect .topmsg
'

test_expect_success 'patch create EDITOR=:' '
	test_recreate_repo_cd r0 &&
	test_commit first^one &&
	bcnt="$(git rev-list --count --all)" &&
	EDITOR=: && export EDITOR &&
	tg create tgb &&
	acnt="$(git rev-list --count --all)" &&
	test $acnt -gt $bcnt &&
	printf "%s" "\
From: Te s t (Author) <test@example.net>
Subject: [PATCH] tgb
" >expect &&
	test_diff expect .topmsg
'

test_expect_success 'format.signoff=true patch create --no-edit' '
	test_recreate_repo_cd r0 &&
	test_commit first^one &&
	bcnt="$(git rev-list --count --all)" &&
	EDITOR="echo x >" && export EDITOR &&
	tg -c format.signoff=1 create --no-edit tgb &&
	acnt="$(git rev-list --count --all)" &&
	test $acnt -gt $bcnt &&
	printf "%s" "\
From: Te s t (Author) <test@example.net>
Subject: [PATCH] tgb

Signed-off-by: Te s t (Author) <test@example.net>
" >expect &&
	test_diff expect .topmsg
'

test_expect_success 'format.signoff=true patch create EDITOR=:' '
	test_recreate_repo_cd r0 &&
	test_commit first^one &&
	EDITOR=":" && export EDITOR &&
	bcnt="$(git rev-list --count --all)" &&
	tg -c format.signoff=1 create tgb &&
	acnt="$(git rev-list --count --all)" &&
	test $acnt -gt $bcnt &&
	printf "%s" "\
From: Te s t (Author) <test@example.net>
Subject: [PATCH] tgb

Signed-off-by: Te s t (Author) <test@example.net>
" >expect &&
	test_diff expect .topmsg
'

test_done
