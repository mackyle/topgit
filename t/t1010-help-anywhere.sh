#!/bin/sh

test_description='tg help commands work anywhere

It should be possible to, for example, use `tg tag -h` outside a Git
repository without error.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 11

test_expect_success 'test setup' '
	mkdir norepo &&
	test_create_repo repo
'

totalin="$PWD/ti"
totalout="$PWD/to"
fullin="$PWD/fi"
fullout="$PWD/fo"
briefin="$PWD/bi"
briefout="$PWD/bo"

test_expect_success 'total help in repo' '
	cd repo &&
	tg help tg >"$totalin"
'

test_expect_success 'total help outside repo' '
	cd norepo &&
	tg help tg >"$totalout"
'

test_expect_success 'total help okay' '
	test -s "$totalin" &&
	test -s "$totalout" &&
	test_cmp "$totalin" "$totalout"
'

test_expect_success 'full help in repo' '
	cd repo &&
	tg help update >"$fullin"
'

test_expect_success 'full help outside repo' '
	cd norepo &&
	tg help update >"$fullout"
'

test_expect_success 'full help okay' '
	test -s "$fullin" &&
	test -s "$fullout" &&
	test_cmp "$fullin" "$fullout"
'

test_expect_success 'brief help in repo' '
	cd repo &&
	tg update -h >"$briefin"
'

test_expect_success 'brief help outside repo' '
	cd norepo &&
	tg update -h >"$briefout"
'

test_expect_success 'brief help okay' '
	test -s "$briefin" &&
	test -s "$briefout" &&
	test_cmp "$briefin" "$briefout"
'

test_expect_success 'sane help line counts' '
	test_line_count -ge 1 "$briefout" &&
	test_line_count -le 5 "$briefout" &&
	test_line_count -ge 10 "$fullout" &&
	test_line_count -lt 100 "$fullout" &&
	test_line_count -gt 1000 "$totalout"
'

test_done
