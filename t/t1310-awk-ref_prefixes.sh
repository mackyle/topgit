#!/bin/sh

test_description='ref_prefixes.awk functionality'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

ap="$(tg --awk-path)" && test -n "$ap" && test -d "$ap" || die
aprp="$ap/ref_prefixes"
test -f "$aprp" && test -r "$aprp" && test -x "$aprp" || die

test_plan 14

test_expect_success 'ref_prefixes runs' '
	# some stupid awks might not even compile it
	awk -v prefix1="refs/a" -v prefix2="refs/b" -f "$aprp" </dev/null
'

test_expect_success 'ref_prefixes exit 66' '
	test_expect_code 66 \
	awk -v prefix1="refs/a" -v prefix2="refs/b" -v nodef=1 -f "$aprp" </dev/null
'

test_expect_success 'ref_prefixes exit 65' '
	test_expect_code 65 \
	awk -v prefix1="refs/a" -v prefix2="refs/b" -f "$aprp" <<-EOT
		refs/a/1
		refs/b/1
	EOT
'

test_expect_success 'ref_prefixes exit noerr 65' '
	awk -v prefix1="refs/a" -v prefix2="refs/b" -v noerr=1 -f "$aprp" <<-EOT
		refs/a/1
		refs/b/1
	EOT
'

test_expect_success 'ref_prefixes bad usage' '
	exec 0</dev/null &&
	test_must_fail awk -f "$aprp" &&
	test_must_fail awk -v prefix1="refs/a" -f "$aprp" &&
	test_must_fail awk -v prefix2="refs/b" -f "$aprp" &&
	test_must_fail awk -v prefix1="refs/a" -v prefix2="refs/a" -f "$aprp" &&
	test_must_fail awk -v prefix1="refs/a" -v prefix2="refs/b" -v prefixh="refs/a" -f "$aprp" &&
	test_must_fail awk -v prefix1="refs/a" -v prefix2="refs/b" -v prefixh="refs/b" -f "$aprp" &&
	test_must_fail awk -v prefix1="refx/a" -v prefix2="refs/b" -v prefixh="refs/c" -f "$aprp" &&
	test_must_fail awk -v prefix1="refs/a" -v prefix2="refx/b" -v prefixh="refs/c" -f "$aprp" &&
	test_must_fail awk -v prefix1="refs/a" -v prefix2="refs/b" -v prefixh="refx/c" -f "$aprp"
'

test_expect_success 'ref_prefixes no matches no default' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	val="$(test_expect_code 66 awk -v prefix1="refs/x" -v prefix2="refs/y" -v nodef=1 -f "$aprp" <input)" &&
	test z"$val" = z""
'

test_expect_success 'ref_prefixes no matches with default' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	val="$(awk -v prefix1="refs/x" -v prefix2="refs/y" -f "$aprp" <input)" &&
	test z"$val" = z"refs/x"
'

test_expect_success 'ref_prefixes two matches with error' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	val="$(test_expect_code 65 awk -v prefix1="refs/l" -v prefix2="refs/n" -f "$aprp" <input)" &&
	test z"$val" = z""
'

test_expect_success 'ref_prefixes two matches use default' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	val="$(awk -v prefix1="refs/n" -v prefix2="refs/l" -v noerr=1 -f "$aprp" <input)" &&
	test z"$val" = z"refs/n"
'

test_expect_success 'ref_prefixes two matches with prefixh with error' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
refs/h/b 0123
refs/h/2 0123
" &&	val="$(test_expect_code 65 awk -v prefix1="refs/l" -v prefix2="refs/n" -v prefixh="refs/h" -f "$aprp" <input)" &&
	test z"$val" = z""
'

test_expect_success 'ref_prefixes two matches with prefixh use default' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
refs/h/b 0123
refs/h/2 0123
" &&	val="$(awk -v prefix1="refs/l" -v prefix2="refs/n" -v prefixh="refs/h" -v noerr=1 -f "$aprp" <input)" &&
	test z"$val" = z"refs/l"
'

test_expect_success 'ref_prefixes no matches without prefixh use default' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	val="$(awk -v prefix1="refs/l" -v prefix2="refs/n" -v prefixh="refs/h" -f "$aprp" <input)" &&
	test z"$val" = z"refs/l"
'

test_expect_success 'ref_prefixes no matches without prefixh no default' '
	printf >input "%s" "\
refs/l/a 000A
refs/n/1 000a
refs/l/b 000b
refs/l/a 000A
refs/n/3 0003
refs/l/c 000C
refs/n/2 0002
refs/l/b 000B
" &&	val="$(test_expect_code 66 awk -v prefix1="refs/n" -v prefix2="refs/l" -v prefixh="refs/h" -v nodef=1 -f "$aprp" <input)" &&
	test z"$val" = z""
'

test_expect_success 'ref_prefixes matches with pckdrefs format' '
	printf >input "%s" "\
000A refs/l/a
000a refs/n/1
000b refs/l/b
000A refs/l/a
0003 refs/n/3
000C refs/l/c
0002 refs/n/2
000B refs/l/b
0123 refs/h/2
" &&	val="$(awk -v prefix1="refs/l" -v prefix2="refs/n" -v prefixh="refs/h" -v pckdrefs=1 -f "$aprp" <input)" &&
	test z"$val" = z"refs/n"
'

test_done
