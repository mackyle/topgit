#!/bin/sh

TEST_NO_CREATE_REPO=1

test_description='Test for git mailinfo -b bug

1 - git mailinfo (default)

2 - git mailinfo -k (keep everything)

3,4,5,6,7 - git mailinfo -b (blast blanks and [PATCH] tags)

    This last can easily be made to fatal out (6 & 7)
'

. ./test-lib.sh

test_plan 7

test_expect_success 'git mailinfo no options' '
	subj="$(echo "Subject: [PATCH] [other] [PATCH] message" |
		git mailinfo /dev/null /dev/null)" &&
	test z"$subj" = z"Subject: message"
'

test_expect_success 'git mailinfo -k' '
	subj="$(echo "Subject: [PATCH] [other] [PATCH] message" |
		git mailinfo -k /dev/null /dev/null)" &&
	test z"$subj" = z"Subject: [PATCH] [other] [PATCH] message"
'

test_expect_success 'git mailinfo -b no [PATCH]' '
	subj="$(echo "Subject: [other] message" |
		git mailinfo -b /dev/null /dev/null)" &&
	test z"$subj" = z"Subject: [other] message"
'

test_expect_success 'git mailinfo -b leading [PATCH]' '
	subj="$(echo "Subject: [PATCH] [other] message" |
		git mailinfo -b /dev/null /dev/null)" &&
	test z"$subj" = z"Subject: [other] message"
'

test_expect_success 'git mailinfo -b double [PATCH]' '
	subj="$(echo "Subject: [PATCH] [PATCH] message" |
		git mailinfo -b /dev/null /dev/null)" &&
	test z"$subj" = z"Subject: message"
'

# git v2.38.2 and later have fixed these two
# see git commit 3ef1494685dea925
# "mailinfo -b: fix an out of bounds access" 2022-10-03

test_2382_success='test_expect_success'
vcmp "$git_version" '>=' "2.38.2" || test_2382_success='test_expect_failure'

$test_2382_success 'git mailinfo -b trailing [PATCH]' '
	subj="$(echo "Subject: [other] [PATCH] message" |
		git mailinfo -b /dev/null /dev/null)" &&
	test z"$subj" = z"Subject: [other] message"
'

$test_2382_success 'git mailinfo -b separated double [PATCH]' '
	subj="$(echo "Subject: [PATCH] [other] [PATCH] message" |
		git mailinfo -b /dev/null /dev/null)" &&
	test z"$subj" = z"Subject: [other] message"
'

test_done
