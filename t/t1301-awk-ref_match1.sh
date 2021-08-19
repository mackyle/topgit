#!/bin/sh

test_description='ref_match.awk functionality with trailer chars 0x21-0x2E'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

ap="$(tg --awk-path)" && test -n "$ap" && test -d "$ap" || die
aprm="$ap/ref_match"
test -f "$aprm" && test -r "$aprm" && test -x "$aprm" || die

test_plan 5

test_expect_success 'ref_match runs' '
	# some stupid awks might not even compile it
	awk -f "$aprm" </dev/null
'

test_expect_success 'ref_match normal order specials' '
	printf >input "%s" "\
refs/t! 0001
refs/t) 0009
refs/t+ 000b
refs/t( 0008
refs/t- 000d
refs/t\$ 0004
refs/t'\'' 0007
refs/t* 000A
refs/t% 0005
refs/t& 0006
refs/t\\ 003c
refs/t. 000e
refs/t# 0003
refs/t, 000C
refs/t\" 0002
" &&	printf >expect "%s" "\
0001 object	refs/t!
0002 object	refs/t\"
0003 object	refs/t#
0004 object	refs/t\$
0005 object	refs/t%
0006 object	refs/t&
0007 object	refs/t'\''
0008 object	refs/t(
0009 object	refs/t)
000a object	refs/t*
000b object	refs/t+
000c object	refs/t,
000d object	refs/t-
000e object	refs/t.
003c object	refs/t\\
" &&	awk -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match pckdrefs order specials' '
	printf >input "%s" "\
0001 refs/t!
0009 refs/t)
000b refs/t+
0008 refs/t(
000d refs/t-
0004 refs/t\$
0007 refs/t'\''
000A refs/t*
0005 refs/t%
0006 refs/t&
003c refs/t\\
000e refs/t.
0003 refs/t#
000C refs/t,
0002 refs/t\"
" &&	printf >expect "%s" "\
0001 object	refs/t!
0002 object	refs/t\"
0003 object	refs/t#
0004 object	refs/t\$
0005 object	refs/t%
0006 object	refs/t&
0007 object	refs/t'\''
0008 object	refs/t(
0009 object	refs/t)
000a object	refs/t*
000b object	refs/t+
000c object	refs/t,
000d object	refs/t-
000e object	refs/t.
003c object	refs/t\\
" &&	awk -v pckdrefs=1 -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match normal order specials versus slash' '
	printf >input "%s" "\
refs/a-a 00aA
refs/a 000a
refs/2 0002
refs/f 000F
refs/1+1 0011
refs/d 000d
refs/d\$d 00dD
refs/b.b 00Bb
refs/1 0001
refs/3%3 0033
refs/c#c 00cC
refs/b 000B
refs/2&2 0022
refs/f,f 00Ff
refs/c 000c
refs/3 0003
" &&	printf >expect "%s" "\
0001 object	refs/1
0011 object	refs/1+1
0002 object	refs/2
0022 object	refs/2&2
0003 object	refs/3
0033 object	refs/3%3
000a object	refs/a
00aa object	refs/a-a
000b object	refs/b
00bb object	refs/b.b
000c object	refs/c
00cc object	refs/c#c
000d object	refs/d
00dd object	refs/d\$d
000f object	refs/f
00ff object	refs/f,f
" &&	awk -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'ref_match pckdrefs order specials versus slash' '
	printf >input "%s" "\
00aA refs/a-a
000a refs/a
0002 refs/2
000F refs/f
0011 refs/1+1
000d refs/d
00dD refs/d\$d
00Bb refs/b.b
0001 refs/1
0033 refs/3%3
00cC refs/c#c
000B refs/b
0022 refs/2&2
00Ff refs/f,f
000c refs/c
0003 refs/3
" &&	printf >expect "%s" "\
0001 object	refs/1
0011 object	refs/1+1
0002 object	refs/2
0022 object	refs/2&2
0003 object	refs/3
0033 object	refs/3%3
000a object	refs/a
00aa object	refs/a-a
000b object	refs/b
00bb object	refs/b.b
000c object	refs/c
00cc object	refs/c#c
000d object	refs/d
00dd object	refs/d\$d
000f object	refs/f
00ff object	refs/f,f
" &&	awk -v pckdrefs=1 -f "$aprm" <input >actual &&
	test_cmp expect actual
'

test_done
