#!/bin/sh

test_description='check diff_added_lines finds all added lines'

. ./test-lib.sh

test_plan 20

test_expect_success 'diff generates dreaded "\ No newline at end of file"' '
	printf "%s" "" >file1 &&
	printf "%s" "newline" >file2 &&
	printf "%s" "\
diff --git file1 file2
index e69de29bb2d1d643..8010d218a3d3561b 100644
--- file1
+++ file2
@@ -0,0 +1 @@
+newline
\\ No newline at end of file
" >expected &&
	test_expect_code 1 test_diff file1 file2 >actual &&
	test_diff expected actual
'

# if $3 is non-empty use --ignore-space-at-eol
diff_strings() {
	printf "%s" "$1" >file1 &&
	printf "%s" "$2" >file2 &&
	ec_=0 &&
	test_diff ${3:+--ignore-space-at-eol} file1 file2 || ec_=$?
	test $ec_ -eq 0 || test $ec_ -eq 1 || die
	return 0
}

test_expect_success 'no added lines for two empty files' '
	tg_test_include &&
	printf "%s" "" >expected &&
	diff_strings "" "" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line added to empty file' '
	tg_test_include &&
	printf "%s\n" "newline" >expected &&
	diff_strings "" "newline
" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line w/o nl added to empty file' '
	tg_test_include &&
	printf "%s\n" "newline" >expected &&
	diff_strings "" "newline" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'two lines added to empty file' '
	tg_test_include &&
	printf "%s\n" "line1" "line2" >expected &&
	diff_strings "" "line1
line2
" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'two lines w/o final nl added to empty file' '
	tg_test_include &&
	printf "%s\n" "line1" "line2" >expected &&
	diff_strings "" "line1
line2" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line prepended to one line file' '
	tg_test_include &&
	printf "%s\n" "newline" >expected &&
	diff_strings "\
original
" "\
newline
original
" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line appended to one line file' '
	tg_test_include &&
	printf "%s\n" "newline" >expected &&
	diff_strings "\
original
" "\
original
newline
" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line appended w/o nl to one line file' '
	tg_test_include &&
	printf "%s\n" "newline" >expected &&
	diff_strings "\
original
" "\
original
newline" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line prepended and appended to one line file' '
	tg_test_include &&
	printf "%s\n" "newline1" "newline2" >expected &&
	diff_strings "\
original
" "\
newline1
original
newline2
" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line prepended and appended w/o nl to one line file' '
	tg_test_include &&
	printf "%s\n" "newline1" "newline2" >expected &&
	diff_strings "\
original
" "\
newline1
original
newline2" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line prepended to one line w/o nl file' '
	tg_test_include &&
	printf "%s\n" "newline" >expected &&
	diff_strings "\
original" "\
newline
original" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line appended to one line w/o nl file' '
	tg_test_include &&
	# the original shows up as a "+" because it got a nl added after it
	printf "%s\n" "original" "newline" >expected &&
	diff_strings "\
original" "\
original
newline
" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line appended to one line w/o nl file w/ opt' '
	tg_test_include &&
	printf "%s\n" "newline" >expected &&
	diff_strings "\
original" "\
original
newline
" 1 | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line appended w/o nl to one line w/o nl file' '
	tg_test_include &&
	# the original shows up as a "+" because it got a nl added after it
	printf "%s\n" "original" "newline" >expected &&
	diff_strings "\
original" "\
original
newline" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line appended w/o nl to one line w/o nl file w/ opt' '
	tg_test_include &&
	printf "%s\n" "newline" >expected &&
	diff_strings "\
original" "\
original
newline" 1 | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line prepended and appended to one line w/o nl file' '
	tg_test_include &&
	# the original shows up as a "+" because it got a nl added after it
	printf "%s\n" "newline1" "original" "newline2" >expected &&
	diff_strings "\
original" "\
newline1
original
newline2
" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line prepended and appended to one line w/o nl file w/ opt' '
	tg_test_include &&
	printf "%s\n" "newline1" "newline2" >expected &&
	diff_strings "\
original" "\
newline1
original
newline2
" 1 | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line prepended and appended w/o nl to one line w/o nl file' '
	tg_test_include &&
	# the original shows up as a "+" because it got a nl added after it
	printf "%s\n" "newline1" "original" "newline2" >expected &&
	diff_strings "\
original" "\
newline1
original
newline2" | diff_added_lines >actual &&
	test_diff expected actual
'

test_expect_success 'one line prepended and appended w/o nl to one line w/o nl file w/ opt' '
	tg_test_include &&
	printf "%s\n" "newline1" "newline2" >expected &&
	diff_strings "\
original" "\
newline1
original
newline2" 1 | diff_added_lines >actual &&
	test_diff expected actual
'

test_done
