#!/bin/sh

test_description='topgit_deps_prepare.awk functionality'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

ap="$(tg --awk-path)" && test -n "$ap" && test -d "$ap" || die
aptdp="$ap/topgit_deps_prepare"
test -f "$aptdp" && test -r "$aptdp" && test -x "$aptdp" || die

# Example use of topgit_deps_prepare:
#
# $ printf "%s\n" "refs/heads/{top-bases}/t/sample" |
#   awk -f "$(tg --awk-path)/ref_prepare" \
#    -v "topbases=refs/heads/{top-bases}" \
#    -v "chkblob=e69de29bb2d1d6434b8b29ae775ad8c2e48c5391" -v "depsblob=1" |
#   tee /dev/stderr |
#   git cat-file --batch-check="%(objectname) %(objecttype) %(rest)" |
#   tee /dev/stderr |
#   awk -f "$(tg --awk-path)/topgit_deps_prepare" \
#    -v "missing=e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
#
# e69de29bb2d1d6434b8b29ae775ad8c2e48c5391^{blob} check ?
# refs/heads/{top-bases}/t/sample t/sample :
# refs/heads/{top-bases}/t/sample^0
# refs/heads/t/sample^0
# refs/heads/{top-bases}/t/sample^{tree}
# refs/heads/t/sample^{tree}
# refs/heads/t/sample^{tree}:.topdeps
#
# e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 blob check ?
# c9f100930c289c97b21ad9b1a8145754d0543e72 commit t/sample :
# c9f100930c289c97b21ad9b1a8145754d0543e72 commit
# e999108a1ccecd83c8a0f83f1cb2d84053abc282 commit
# 3208ec7914a3bcb6da4ba32f54b2457d5ffd64fa tree
# 3431161db7d2a5adfcba4d91bcf81d10e5b432b2 tree
# 2ccee31ddc46c17d0aff9187a8e2d7fd9cfeaa47 blob
#
# 2ccee31ddc46c17d0aff9187a8e2d7fd9cfeaa47 t/sample
#
# Note that topgit_deps_prepare does not concern itself with the actual value
# of any of the hashes (other than for equality testing), but it does care
# about object types and whether things are "missing" or not.
#
# It also doesn't detect obviously corrupt input (both commits are the same
# but their trees are not).

test_plan 22

chkmb="checkblob"
cat <<-EOT >"$chkmb"
	12345678 blob check ?
EOT

cmd0="cmd0"
cat <<-EOT >"$cmd0" || die
	10000000 whatever cmd0 :
	10000002 commit
	10000003 commit
	10000004 tree
	10000005 tree
	10000006 blob
EOT
echo "10000006 cmd0" >"$cmd0.out" || die
echo "cmd0" >"$cmd0.br" || die

cmd1="cmd1"
cat <<-EOT >"$cmd1" || die
	10000000 whatever cmd1 :
	10000002 commit
	10000003 commit
	10000004 tree
	10000005 tree
	10000006 missing
EOT

cmd2="cmd2"
cat <<-EOT >"$cmd2" || die
	10000000 whatever cmd2 :
	10000002 commit
	10000003 commit
	10000004 tree
	10000004 tree
	10000006 missing
EOT

mt_base="one-rather-lengthy-and-unlikely-blob-name-for-sure"

test_expect_success 'test setup' '
	branch_base="some-very-long-branch-base-name-goes-here-for-sure" &&
	bn=10000000 &&
	>biginput && >bigoutput && >bigbrfile &&
	i=1 && while i=$(($i + 10)) && test $i -le 10000; do
		printf "%08d whatever %s-%d :\n" $(( $bn + $i )) "$branch_base" $(( $bn + $i )) >>biginput &&
		printf "%08d commit\n" $(( $bn + $i + 1 )) >>biginput &&
		printf "%08d commit\n" $(( $bn + $i + 2 )) >>biginput &&
		printf "%08d tree\n" $(( $bn + $i + 3 )) >>biginput &&
		printf "%08d tree\n" $(( $bn + $i + 3 )) >>biginput &&
		printf "%08d blob\n" $(( $bn + $i + 4 )) >>biginput &&
		printf "%s-%d\n" "$branch_base"  $(( $bn + $i )) >>bigbrfile &&
		printf "%s^{blob} %s-%d\n" "$mt_base" "$branch_base"  $(( $bn + $i )) >>bigoutput
	done &&
	cat bigbrfile bigoutput >bigcombined
'

test_expect_success 'topgit_deps_prepare runs' '
	# some stupid awks might not even compile it
	awk -f "$aptdp" </dev/null &&
	# and make sure various file arg combinations are accepted
	awk -f "$aptdp" </dev/null -v brfile=brfile && rm -f brfile &&
	awk -f "$aptdp" </dev/null -v anfile=anfile && rm -f anfile &&
	awk -f "$aptdp" </dev/null -v brfile=brfile -v anfile=anfile
'

test_expect_success 'output files always truncated' '
	echo brfile > brfile && test -s brfile &&
	echo anfile > anfile && test -s anfile &&
	awk -f "$aptdp" </dev/null -v brfile=brfile -v anfile=anfile &&
	test ! -s brfile &&
	test ! -s anfile
'

capture() {
	IFS= read -r line || return &&
	cat "$1" >"$2" &&
	printf '%s\n' "$line" >>"$2" &&
	cat >>"$2"
}

test_expect_success 'output brfile ordering' '
	>result &&
	awk -f "$aptdp" <biginput -v missing="$mt_base" -v brfile=brfile | capture brfile result &&
	test_cmp result bigcombined
'

test_expect_success 'output anfile ordering' '
	>result &&
	awk -f "$aptdp" <biginput -v missing="$mt_base" -v anfile=anfile | capture anfile result &&
	test_cmp result bigcombined
'

test_expect_success 'anfile only' '
	awk -f "$aptdp" <biginput -v anfile=anlist >out &&
	test ! -s out && test_cmp anlist bigbrfile
'

test_expect_success 'anfile only one out' '
	cat "$cmd0" biginput | awk -f "$aptdp" -v anfile=anlist >out &&
	test_cmp out "$cmd0.out" && test_cmp anlist bigbrfile
'

test_expect_success 'noann=1 empty brfile' '
	awk -f "$aptdp" <biginput -v noann=1 -v brfile=brlist >out &&
	test ! -s out && test -e brlist && test ! -s brlist
'

test_expect_success 'one in brfile only' '
	cat "$cmd0" biginput | awk -f "$aptdp" -v noann=1 -v brfile=brlist >out &&
	test_cmp out "$cmd0.out" && test_cmp brlist "$cmd0.br"
'

test_expect_success 'brfile only' '
	awk -f "$aptdp" <biginput -v brfile=brlist >out &&
	test ! -s out && test_cmp brlist bigbrfile
'

test_expect_success 'anfile and noann=1 empty brfile' '
	awk -f "$aptdp" <biginput -v noann=1 -v anfile=anlist -v brfile=brlist >out &&
	test ! -s out && test_cmp anlist bigbrfile && test -e brlist && test ! -s brlist
'

test_expect_success 'anfile and one in brfile' '
	cat "$cmd0" biginput | awk -f "$aptdp" -v noann=1 -v anfile=anlist -v brfile=brlist >out &&
	test_cmp out "$cmd0.out" && test_cmp anlist bigbrfile && test_cmp brlist "$cmd0.br"
'

# The only kind of "bad" input that's detected is not enough lines after
# the starting 4-field ':' line
test_expect_success 'bad input detected' '
	echo "0001 commit branch :" >input &&
	test_must_fail awk -f "$aptdp" <input &&
	echo "0002 commit" >>input &&
	test_must_fail awk -f "$aptdp" <input &&
	echo "0003 commit" >>input &&
	test_must_fail awk -f "$aptdp" <input &&
	echo "0004 tree" >>input &&
	test_must_fail awk -f "$aptdp" <input &&
	echo "0005 tree" >>input &&
	test_must_fail awk -f "$aptdp" <input &&
	echo "0006 blob" >>input &&
	awk -f "$aptdp" <input &&
	echo "0007 blob" >>input &&
	awk -f "$aptdp" <input
'

test_expect_success 'missing command does not run' '
	rm -f run* &&
	awk -f "$aptdp" <"$cmd0" -v misscmd="echo r0>>run0" >out &&
	test_cmp "$cmd0.out" out && test ! -e run0 &&
	awk -f "$aptdp" <"$cmd1" -v misscmd="echo r1>>run1" >out &&
	test ! -s out && test ! -e run1 &&
	awk -f "$aptdp" <"$cmd2" -v misscmd="echo r2>>run2" >out &&
	awk -f "$aptdp" <"$cmd2" -v noann=1 -v missing=other -v misscmd="echo r2>>run2" >>out &&
	test ! -s out && test ! -e run2 &&
	cat "$chkmb" "$cmd0" | awk -f "$aptdp" -v missing=12345678 -v misscmd="echo r0>>run0" >outa &&
	cat "$chkmb" "$cmd0" | awk -f "$aptdp" -v missing=other -v misscmd="echo r0>>run0" >outb &&
	test_cmp "$cmd0.out" outa && test_cmp "$cmd0.out" outb && test ! -e run0 &&
	echo "12345678^{blob} cmd1" >expected &&
	cat "$chkmb" "$cmd1" | awk -f "$aptdp" -v missing=12345678 -v misscmd="echo r1>>run1" >out &&
	test ! -e run1 && test_cmp out expected &&
	echo "12345678^{blob} cmd2" >expected &&
	cat "$chkmb" "$cmd2" | awk -f "$aptdp" -v missing=12345678 -v misscmd="echo r2>>run2" >out &&
	test ! -e run2 && test_cmp out expected
'

test_expect_success 'missing command does run' '
	rm -f run* &&
	<"$cmd1" awk -f "$aptdp" -v missing=12345678 -v misscmd="echo r1>>run1" &&
	test -s run1 && read -r l <run1 && test "$l" = "r1" &&
	<"$cmd2" awk -f "$aptdp" -v missing=12345678 -v misscmd="echo r2>>run2" &&
	test -s run2 && read -r l <run2 && test "$l" = "r2"
'

test_expect_success 'missing command runs once' '
	rm -f run* &&
	cat "$cmd1" "$cmd2" | awk -f "$aptdp" -v missing=12345678 -v misscmd="echo r1>>run1" &&
	echo "r1" >expected &&
	test -s run1 && test_cmp run1 expected
'

test_expect_success 'none out' '
	<biginput awk -f "$aptdp" >out &&
	test ! -s out
'

test_expect_success 'none out noann=1' '
	<biginput awk -f "$aptdp" -v noann=1 -v missing=other >out &&
	test ! -s out
'

test_expect_success 'only one out' '
	<"$cmd0" awk -f "$aptdp" >out &&
	test_cmp out "$cmd0.out"
'

test_expect_success 'only one out of many' '
	cat "$cmd0" biginput | awk -f "$aptdp" >out &&
	test_cmp out "$cmd0.out"
'

test_expect_success 'only one out of many noann=1' '
	cat "$cmd0" biginput | awk -f "$aptdp" -v noann=1 -v missing=other >out &&
	test_cmp out "$cmd0.out"
'

test_expect_success 'many out' '
	<biginput awk -f "$aptdp" -v "missing=$mt_base" >out &&
	test_cmp out bigoutput
'

test_done
