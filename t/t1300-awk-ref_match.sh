#!/bin/sh

test_description='ref_match.awk functionality'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

ap="$(tg --awk-path)" && test -n "$ap" && test -d "$ap" || die
aprm="$ap/ref_match"
test -f "$aprm" && test -r "$aprm" && test -x "$aprm" || die

test_plan 21

test_expect_success 'ref_match runs' '
	# some stupid awks might not even compile it
	awk -f "$aprm" </dev/null
'

test_expect_success 'ref_match normal order' '
	printf >input "%s" "\
refs/1 0001
refs/b 000b
refs/a 000A
refs/3 0003
refs/c 000C
refs/2 0002
" &&	printf >expect "%s" "\
0001 object	refs/1
0002 object	refs/2
0003 object	refs/3
000a object	refs/a
000b object	refs/b
000c object	refs/c
" &&	awk -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match pckdrefs order' '
	printf >input "%s" "\
0001 refs/1
000b refs/b
000A refs/a
0003 refs/3
000C refs/c
0002 refs/2
" &&	printf >expect "%s" "\
0001 object	refs/1
0002 object	refs/2
0003 object	refs/3
000a object	refs/a
000b object	refs/b
000c object	refs/c
" &&	awk -v pckdrefs=1 -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match duplicate elimination' '
	printf >input "%s" "\
refs/a 000A
refs/1 0001
refs/b 000b
refs/a 000A
refs/3 0003
refs/c 000C
refs/2 0002
refs/b 000B
" &&	printf >expect "%s" "\
0001 object	refs/1
0002 object	refs/2
0003 object	refs/3
000a object	refs/a
000b object	refs/b
000c object	refs/c
" &&	awk -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match duplicate retention' '
	printf >input "%s" "\
refs/a 000A
refs/1 0001
refs/b 000b
refs/a 000A
refs/3 0003
refs/c 000C
refs/2 0002
refs/b 000B
" &&	printf >expect "%s" "\
0001 object	refs/1
0002 object	refs/2
0003 object	refs/3
000a object	refs/a
000a object	refs/a
000b object	refs/b
000b object	refs/b
000c object	refs/c
" &&	awk -v dupesok=1 -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match formatted output' '
	printf >input "%s" "\
refs/a 000A
refs/1 0001
refs/b 000b
refs/a 000A
refs/3 0003
refs/c 000C
refs/2 0002
refs/b 000B
" &&	printf >expect "%s" "\
refs/1  <%>  0001
object
refs/2  <%>  0002
object
refs/3  <%>  0003
object
refs/a  <%>  000a
object
refs/b  <%>  000b
object
refs/c  <%>  000c
object
" &&	awk -v matchfmt="%(refname)  %3c%%%3E  %(objectname)%0a%(objecttype)" -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match formatted output with repeats' '
	printf >input "%s" "\
refs/a 000A
refs/1 0001
refs/b 000b
refs/a 000A
refs/3 0003
refs/c 000C
refs/2 0002
refs/b 000B
" &&	printf >expect "%s" "\
refs/1  <%>  0001
objectrefs/1
refs/2  <%>  0002
objectrefs/2
refs/3  <%>  0003
objectrefs/3
refs/a  <%>  000a
objectrefs/a
refs/b  <%>  000b
objectrefs/b
refs/c  <%>  000c
objectrefs/c
" &&	awk -v matchfmt="%(refname)  %3c%%%3E  %(objectname)%0a%(objecttype)%(refname)" -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match sort reversed' '
	printf >input "%s" "\
refs/a 000A
refs/1 0001
refs/b 000b
refs/a 000A
refs/3 0003
refs/c 000C
refs/2 0002
refs/b 000B
" &&	printf >expect "%s" "\
000c object	refs/c
000b object	refs/b
000a object	refs/a
0003 object	refs/3
0002 object	refs/2
0001 object	refs/1
" &&	awk -v sortkey="-refname" -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match sort reversed with dupes' '
	printf >input "%s" "\
refs/a 000A
refs/1 0001
refs/b 000b
refs/a 000A
refs/3 0003
refs/c 000C
refs/2 0002
refs/b 000B
" &&	printf >expect "%s" "\
000c object	refs/c
000b object	refs/b
000b object	refs/b
000a object	refs/a
000a object	refs/a
0003 object	refs/3
0002 object	refs/2
0001 object	refs/1
" &&	awk -v sortkey="-refname" -v dupesok=1 -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match one exact pattern' '
	printf >input "%s" "\
refs/a 000A
refs/1 0001
refs/b 000b
refs/a 000A
refs/3 0003
refs/c 000C
refs/2 0002
refs/b 000B
" &&	printf >expect "%s" "\
000a object	refs/a
" &&	awk -v patterns="refs/a" -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match one exact pattern one input' '
	printf >input "%s" "\
refs/a 000a
" &&	printf >expect "%s" "\
000a object	refs/a
" &&	awk -v patterns="refs/a" -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match one exact pattern one input with slash' '
	printf >input "%s" "\
refs/a 000a
" &&	printf >expect "%s" "\
000a object	refs/a
" &&	awk -v patterns="refs/a/" -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match one prefix pattern' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 0001
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	printf >expect "%s" "\
000a object	refs/l/a
000b object	refs/l/b
000c object	refs/l/c
" &&	awk -v patterns="refs/l" -f "$aprm" <input >actual &&
	test_cmp expect actual
'
test_expect_success 'ref_match two patterns' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 0001
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	printf >expect "%s" "\
000a object	refs/l/a
000b object	refs/l/b
000c object	refs/l/c
0001 object	refs/n/1
0002 object	refs/n/2
0003 object	refs/n/3
" &&	awk -v patterns="refs/n refs/l" -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match output limit' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 0001
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	printf >expect "%s" "\
000a object	refs/l/a
000b object	refs/l/b
000c object	refs/l/c
0001 object	refs/n/1
" &&	awk -v patterns="refs/n refs/l" -v maxout=4 -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match objectname sort' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	printf >expect "%s" "\
0002 object	refs/n/2
0003 object	refs/n/3
000a object	refs/l/a
000a object	refs/n/1
000b object	refs/l/b
000c object	refs/l/c
" &&	awk -v sortkey="objectname" -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match objectname sort with dupes' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	printf >expect "%s" "\
0002 object	refs/n/2
0003 object	refs/n/3
000a object	refs/l/a
000a object	refs/l/a
000a object	refs/n/1
000b object	refs/l/b
000b object	refs/l/b
000c object	refs/l/c
" &&	awk -v sortkey="objectname" -v dupesok=1 -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match objectname sort with dupes reversed' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	printf >expect "%s" "\
000c object	refs/l/c
000b object	refs/l/b
000b object	refs/l/b
000a object	refs/l/a
000a object	refs/l/a
000a object	refs/n/1
0003 object	refs/n/3
0002 object	refs/n/2
" &&	awk -v sortkey="-objectname" -v dupesok=1 -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match -refname,-objectname sort with dupes' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	printf >expect "%s" "\
000c object	refs/l/c
000b object	refs/l/b
000b object	refs/l/b
000a object	refs/n/1
000a object	refs/l/a
000a object	refs/l/a
0003 object	refs/n/3
0002 object	refs/n/2
" &&	awk -v sortkey="-refname,-objectname" -v dupesok=1 -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match -refname,-objectname sort no dupes' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	printf >expect "%s" "\
000c object	refs/l/c
000b object	refs/l/b
000a object	refs/n/1
000a object	refs/l/a
0003 object	refs/n/3
0002 object	refs/n/2
" &&	awk -v sortkey="-refname,-objectname" -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match -refname,objectname sort no dupes' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	printf >expect "%s" "\
0002 object	refs/n/2
0003 object	refs/n/3
000a object	refs/n/1
000a object	refs/l/a
000b object	refs/l/b
000c object	refs/l/c
" &&	awk -v sortkey="-refname,objectname" -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_done
