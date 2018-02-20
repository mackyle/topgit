#!/bin/sh

test_description='test tg revert --list --short mode'

. ./test-lib.sh

test_plan 25

mtblob="$(git hash-object --stdin </dev/null)" || die
hashlen="${#mtblob}"
test $hashlen -ge 40 || die

awklen() {
	awk '{sub(/ +/,""); print length($0)}'
}

test_expect_success 'setup' '
	tg_test_create_branches <<-EOT &&
		one
		:::

		two
		:::

		three
		:::

		four
		:::

		t/branch
		one
		two
		three
		four
	EOT
	tg_test_create_tag t/tag &&
	test_when_finished test_set_prereq SETUP
'

for hastmpdir in "" 1; do

if [ -n "$hastmpdir" ]; then
	mkdir tgtmpdir || die
	TG_TMPDIR="$PWD/tgtmpdir" && export TG_TMPDIR || die
fi

test_expect_failure SETUP 'full length hash only'"${hastmpdir:+ (persistent temp dir)}" '
	printf "%s\n" "$hashlen" "$hashlen" "$hashlen" "$hashlen" "$hashlen" "$hashlen" >expected &&
	tg revert --list --hash t/tag >list &&
	awklen <list >actual &&
	test_cmp actual expected
'

for len in 16 17 18 19 20; do
test_expect_success SETUP "length $len hash only${hastmpdir:+ (persistent temp dir)}" '
	printf "%s\n" '"\"$len\" \"$len\" \"$len\" \"$len\" \"$len\" \"$len\""' >expected &&
	tg revert --list --hash --short='"\"$len\""' t/tag >list &&
	awklen <list >actual &&
	test_cmp actual expected
'
done

test_expect_success SETUP 'full length rdeps hash only'"${hastmpdir:+ (persistent temp dir)}" '
	printf "%s\n" "$hashlen" "$hashlen" "$hashlen" "$hashlen" "$hashlen" >expected &&
	tg revert --list --hash --rdeps t/tag >list &&
	awklen <list >actual &&
	test_cmp actual expected
'

for len in 16 17 18 19 20; do
expecting=test_expect_success
[ -z "$hastmpdir" ] || expecting=test_expect_failure
$expecting SETUP "length $len rdeps hash only${hastmpdir:+ (persistent temp dir)}" '
	printf "%s\n" '"\"$len\" \"$len\" \"$len\" \"$len\" \"$len\""' >expected &&
	tg revert --list --hash --rdeps --short='"\"$len\""' t/tag >list &&
	awklen <list >actual &&
	test_cmp actual expected
'
done

done

test_done
