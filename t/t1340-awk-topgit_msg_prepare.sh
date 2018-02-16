#!/bin/sh

test_description='topgit_msg_prepare.awk functionality'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

ap="$(tg --awk-path)" && test -n "$ap" && test -d "$ap" || die
aptmp="$ap/topgit_msg_prepare"
test -f "$aptmp" && test -r "$aptmp" && test -x "$aptmp" || die

# Example use of topgit_msg_prepare:
#
# $ printf "%s\n" "refs/heads/{top-bases}/t/sample" |
#   awk -f "$(tg --awk-path)/ref_prepare" \
#    -v "topbases=refs/heads/{top-bases}" \
#    -v "chkblob=e69de29bb2d1d6434b8b29ae775ad8c2e48c5391" -v "depsblob=1" \
#    -v "msgblob=1" | tee /dev/stderr |
#   git cat-file --batch-check="%(objectname) %(objecttype) %(rest)" |
#   tee /dev/stderr |
#   awk -f "$(tg --awk-path)/topgit_msg_prepare" \
#    -v "missing=e69de29bb2d1d6434b8b29ae775ad8c2e48c5391" \
#    -v "depsblob=2"
#
# e69de29bb2d1d6434b8b29ae775ad8c2e48c5391^{blob} check ?
# refs/heads/{top-bases}/t/sample t/sample :
# refs/heads/{top-bases}/t/sample^0
# refs/heads/t/sample^0
# refs/heads/{top-bases}/t/sample^{tree}
# refs/heads/t/sample^{tree}
# refs/heads/t/sample^{tree}:.topdeps
# refs/heads/t/sample^{tree}:.topmsg
#
# e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 blob check ?
# 9769d34b6ee3d539e4152f2629ec16c56108f82c commit t/sample :
# 9769d34b6ee3d539e4152f2629ec16c56108f82c commit
# d95cc1ed8dc6dcee3002573ca94e1d07f23889d0 commit
# 1afd3b1f70a1155465d1635a76fa49f96d23db2f tree
# 59344164440d5f71cb204b464c45ae4a14416b54 tree
# 2466de6787619f47fe41ced8608998462317f209 blob
# 5e6bd1db23329803939ffa1e1f9052e678ea4a06 blob
#
# 5e6bd1db23329803939ffa1e1f9052e678ea4a06 0 t/sample
#
# Note that topgit_msg_prepare does not concern itself with the actual value
# of any of the hashes (other than for equality testing), but it does care
# about object types and whether things are "missing" or not.
#
# It also doesn't detect obviously corrupt input (both commits are the same
# but their trees are not).

test_plan 30

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
	10000007 blob
EOT
echo "10000006 0 cmd0" >"$cmd0.out0" || die
echo "10000007 0 cmd0" >"$cmd0.out1" || die
echo "cmd0" >"$cmd0.br" || die

cmd1="cmd1"
cat <<-EOT >"$cmd1" || die
	10000000 whatever cmd1 :
	10000002 commit
	10000003 commit
	10000004 tree
	10000005 tree
	10000006 tag
	10000007 missing
EOT

cmd2="cmd2"
cat <<-EOT >"$cmd2" || die
	10000000 whatever cmd2 :
	10000002 commit
	10000003 commit
	10000004 tree
	10000004 tree
	10000006 missing
	10000007 missing
EOT

cmd3="cmd3"
cat <<-EOT >"$cmd3" || die
	10000000 whatever cmd3 :
	10000002 commit
	10000002 commit
	10000004 tree
	10000004 tree
	10000006 missing
	10000007 missing
EOT

cmd4="cmd4"
cat <<-EOT >"$cmd4" || die
	10000000 whatever cmd4 :
	10000002 commit
	10000003 commit
	10000004 tree
	10000005 tree
	10000006 missing
	10000007 missing
EOT

data1="data1"
cat <<-EOT >"$data1" || die
	10000000 garbage
	more garbage here
	even more garbage here
	yup missing it :
	20000001 whatever k0 :
	20000002 commit
	20000003 commit
	20000004 tree
	20000005 tree
	20000007 blob
	30000001 whatever k1 :
	30000002 commit
	30000003 commit
	30000004 tree
	30000005 tree
	30000007 missing
	40000001 whatever k2 :
	40000002 commit
	40000003 commit
	40000004 tree
	40000004 tree
	40000007 blob
	50000001 whatever k3 :
	50000002 commit
	50000002 commit
	50000004 tree
	50000004 tree
	50000007 blob
	60000001 whatever k4 :
	60000002 commit
	60000003 commit
	60000004 tree
	60000005 tree
	60000007 missing
EOT

data2="data2"
cat <<-EOT >"$data2" || die
	10000000 garbage
	more garbage here
	even more garbage here
	yup missing it :
	20000001 whatever k0 :
	20000002 commit
	20000003 commit
	20000004 tree
	20000005 tree
	20000006 blob
	20000007 blob
	30000001 whatever k1 :
	30000002 commit
	30000003 commit
	30000004 tree
	30000005 tree
	30000006 blob
	30000007 missing
	40000001 whatever k2 :
	40000002 commit
	40000003 commit
	40000004 tree
	40000004 tree
	40000006 blob
	40000007 blob
	50000001 whatever k3 :
	50000002 commit
	50000002 commit
	50000004 tree
	50000004 tree
	50000006 blob
	50000007 blob
	60000001 whatever k4 :
	60000002 commit
	60000003 commit
	60000004 tree
	60000005 tree
	60000006 missing
	60000007 missing
EOT

data3="data3"
cat <<-EOT >"$data3" || die
	10000000 garbage
	more garbage here
	even more garbage here
	yup missing it :
	20000001 whatever k0 :
	20000002 commit
	20000003 commit
	20000004 tree
	20000005 tree
	20000006 tag
	20000007 blob
	30000001 whatever k1 :
	30000002 commit
	30000003 commit
	30000004 tree
	30000005 tree
	30000006 tag
	30000007 missing
	40000001 whatever k2 :
	40000002 commit
	40000003 commit
	40000004 tree
	40000004 tree
	40000006 tag
	40000007 blob
	50000001 whatever k3 :
	50000002 commit
	50000002 commit
	50000004 tree
	50000004 tree
	50000006 tag
	50000007 blob
	60000001 whatever k4 :
	60000002 commit
	60000003 commit
	60000004 tree
	60000005 tree
	60000006 missing
	60000007 missing
EOT
cat <<-EOT >"$data3.d0"
	other^{blob} 1 k0
	other^{blob} 1 k1
	other^{blob} 2 k2
	other^{blob} 3 k3
	other^{blob} 1 k4
EOT
cat <<-EOT >"$data3.d1"
	20000007 0 k0
	other^{blob} 1 k1
	other^{blob} 2 k2
	other^{blob} 3 k3
	other^{blob} 1 k4
EOT
cat <<-EOT >"$data3.d2"
	20000007 0 k0
	other^{blob} 1 k1
	other^{blob} 2 k2
	other^{blob} 3 k3
	other^{blob} 4 k4
EOT

data3r="data3r"
cat <<-EOT >"$data3r" || die
	10000000 garbage
	more garbage here
	even more garbage here
	yup missing it :
	20000001 whatever k0 :
	20000002 commit
	20000003 commit
	20000004 tree
	20000005 tree
	20000007 blob
	20000006 tag
	30000001 whatever k1 :
	30000002 commit
	30000003 commit
	30000004 tree
	30000005 tree
	30000007 missing
	30000006 tag
	40000001 whatever k2 :
	40000002 commit
	40000003 commit
	40000004 tree
	40000004 tree
	40000007 blob
	40000006 tag
	50000001 whatever k3 :
	50000002 commit
	50000002 commit
	50000004 tree
	50000004 tree
	50000007 blob
	50000006 tag
	60000001 whatever k4 :
	60000002 commit
	60000003 commit
	60000004 tree
	60000005 tree
	60000007 missing
	60000006 missing
EOT
cat <<-EOT >"$data3r.d0"
	20000007 0 k0
	other^{blob} 1 k1
	other^{blob} 2 k2
	other^{blob} 3 k3
	other^{blob} 1 k4
EOT
cat <<-EOT >"$data3r.d1"
	other^{blob} 1 k0
	other^{blob} 1 k1
	other^{blob} 2 k2
	other^{blob} 3 k3
	other^{blob} 1 k4
EOT
cat <<-EOT >"$data3r.d2"
	other^{blob} 1 k0
	other^{blob} 1 k1
	other^{blob} 2 k2
	other^{blob} 3 k3
	other^{blob} 4 k4
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
		printf "%s^{blob} 2 %s-%d\n" "$mt_base" "$branch_base"  $(( $bn + $i )) >>bigoutput
	done &&
	cat bigbrfile bigoutput >bigcombined
'

test_expect_success 'topgit_msg_prepare runs' '
	# some stupid awks might not even compile it
	awk -f "$aptmp" </dev/null &&
	# and make sure various file arg combinations are accepted
	awk -f "$aptmp" </dev/null -v brfile=brfile && rm -f brfile &&
	awk -f "$aptmp" </dev/null -v anfile=anfile && rm -f anfile &&
	awk -f "$aptmp" </dev/null -v brfile=brfile -v anfile=anfile
'

test_expect_success 'output files always truncated' '
	echo brfile > brfile && test -s brfile &&
	echo anfile > anfile && test -s anfile &&
	awk -f "$aptmp" </dev/null -v brfile=brfile -v anfile=anfile &&
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
	awk -f "$aptmp" <biginput -v withan=1 -v missing="$mt_base" -v brfile=brfile | capture brfile result &&
	test_cmp result bigcombined
'

test_expect_success 'output anfile ordering' '
	>result &&
	awk -f "$aptmp" <biginput -v withan=1 -v missing="$mt_base" -v anfile=anfile | capture anfile result &&
	test_cmp result bigcombined
'

test_expect_success 'anfile only' '
	awk -f "$aptmp" <biginput -v anfile=anlist >out &&
	test ! -s out && test_cmp anlist bigbrfile
'

test_expect_success 'anfile only one out' '
	cat "$cmd0" biginput | awk -f "$aptmp" -v anfile=anlist >out &&
	test_cmp out "$cmd0.out0" && test_cmp anlist bigbrfile
'

test_expect_success 'empty brfile only' '
	awk -f "$aptmp" <biginput -v brfile=brlist >out &&
	test ! -s out && test -e brlist && test ! -s brlist
'

test_expect_success 'one in brfile only' '
	cat "$cmd0" biginput | awk -f "$aptmp" -v brfile=brlist >out &&
	test_cmp out "$cmd0.out0" && test_cmp brlist "$cmd0.br"
'

test_expect_success 'withan=1 brfile only' '
	awk -f "$aptmp" <biginput -v withan=1 -v brfile=brlist >out &&
	test ! -s out && test_cmp brlist bigbrfile
'

test_expect_success 'anfile and empty brfile' '
	awk -f "$aptmp" <biginput -v anfile=anlist -v brfile=brlist >out &&
	test ! -s out && test_cmp anlist bigbrfile && test -e brlist && test ! -s brlist
'

test_expect_success 'anfile and one in brfile' '
	cat "$cmd0" biginput | awk -f "$aptmp" -v anfile=anlist -v brfile=brlist >out &&
	test_cmp out "$cmd0.out0" && test_cmp anlist bigbrfile && test_cmp brlist "$cmd0.br"
'

# The only kind of "bad" input that's detected is not enough lines after
# the starting 4-field ':' line
test_expect_success 'bad input detected' '
	echo "0001 commit branch :" >input &&
	test_must_fail awk -f "$aptmp" <input &&
	echo "0002 commit" >>input &&
	test_must_fail awk -f "$aptmp" <input &&
	echo "0003 commit" >>input &&
	test_must_fail awk -f "$aptmp" <input &&
	echo "0004 tree" >>input &&
	test_must_fail awk -f "$aptmp" <input &&
	echo "0005 tree" >>input &&
	test_must_fail awk -f "$aptmp" <input &&
	echo "0006 blob" >>input &&
	awk -f "$aptmp" <input &&
	test_must_fail awk -f "$aptmp" <input -v depsblob=1 &&
	test_must_fail awk -f "$aptmp" <input -v depsblob=2 &&
	echo "0007 blob" >>input &&
	awk -f "$aptmp" <input &&	
	awk -f "$aptmp" <input -v depsblob=1 &&
	awk -f "$aptmp" <input -v depsblob=2
'

test_expect_success 'missing command does not run' '
	rm -f run* &&
	awk -f "$aptmp" <"$cmd0" -v misscmd="echo r0>>run0" >out0 &&
	awk -f "$aptmp" <"$cmd0" -v depsblob=1 -v misscmd="echo r0>>run0" >out1 &&
	test_cmp "$cmd0.out0" out0 && test_cmp "$cmd0.out1" out1 && test ! -e run0 &&
	awk -f "$aptmp" <"$cmd1" -v depsblob=1 -v misscmd="echo r1>>run1" >out &&
	test ! -s out && test ! -e run1 &&
	awk -f "$aptmp" <"$cmd2" -v misscmd="echo r2>>run2" >out &&
	awk -f "$aptmp" <"$cmd2" -v missing=other -v misscmd="echo r2>>run2" >>out &&
	awk -f "$aptmp" <"$cmd2" -v withmt=1 -v missing=other -v misscmd="echo r2>>run2" >>out &&
	test ! -s out && test ! -e run2 &&
	awk -f "$aptmp" <"$cmd3" -v misscmd="echo r3>>run3" >out &&
	awk -f "$aptmp" <"$cmd3" -v missing=other -v misscmd="echo r3>>run3" >>out &&
	awk -f "$aptmp" <"$cmd3" -v withan=1 -v withmt=0 -v missing=other -v misscmd="echo r3>>run3" >>out &&
	test ! -s out && test ! -e run3 &&
	awk -f "$aptmp" <"$cmd4" -v misscmd="echo r4>>run4" >out &&
	test ! -s out && test ! -e run4 &&
	cat "$chkmb" "$cmd0" | awk -f "$aptmp" -v missing=12345678 -v misscmd="echo r0>>run0" >out0a &&
	cat "$chkmb" "$cmd0" | awk -f "$aptmp" -v missing=other -v misscmd="echo r0>>run0" >out0b &&
	test_cmp "$cmd0.out0" out0a && test_cmp "$cmd0.out0" out0b &&
	test ! -e run0 &&
	echo "12345678^{blob} 1 cmd1" >expected &&
	cat "$chkmb" "$cmd1" | awk -f "$aptmp" -v depsblob=1 -v missing=12345678 -v misscmd="echo r1>>run1" >out &&
	test ! -e run1 && test_cmp out expected &&
	echo "12345678^{blob} 2 cmd2" >expected &&
	cat "$chkmb" "$cmd2" | awk -f "$aptmp" -v withan=1 -v missing=12345678 -v misscmd="echo r2>>run2" >out &&
	test ! -e run2 && test_cmp out expected &&
	echo "12345678^{blob} 3 cmd3" >expected &&
	cat "$chkmb" "$cmd3" | awk -f "$aptmp" -v withmt=1 -v missing=12345678 -v misscmd="echo r3>>run3" >out &&
	test ! -e run3 && test_cmp out expected &&
	echo "12345678^{blob} 1 cmd4" >expected &&
	echo "12345678^{blob} 1 cmd4" >>expected &&
	echo "12345678^{blob} 4 cmd4" >>expected &&
	cat "$chkmb" "$cmd4" | awk -f "$aptmp" -v missing=12345678 -v misscmd="echo r4>>run4" >out &&
	cat "$chkmb" "$cmd4" | awk -f "$aptmp" -v missing=12345678 -v misscmd="echo r4>>run4" -v depsblob=1 >>out &&
	cat "$chkmb" "$cmd4" | awk -f "$aptmp" -v missing=12345678 -v misscmd="echo r4>>run4" -v depsblob=2 >>out &&
	test ! -e run4 && test_cmp out expected
'

test_expect_success 'missing command does run' '
	rm -f run* &&
	<"$cmd1" awk -f "$aptmp" -v depsblob=1 -v missing=12345678 -v misscmd="echo r1>>run1" &&
	test -s run1 && read -r l <run1 && test "$l" = "r1" &&
	<"$cmd2" awk -f "$aptmp" -v withan=1 -v withmt=0 -v missing=12345678 -v misscmd="echo r2>>run2" &&
	test -s run2 && read -r l <run2 && test "$l" = "r2" &&
	<"$cmd3" awk -f "$aptmp" -v withmt=1 -v missing=12345678 -v misscmd="echo r3>>run3" &&
	test -s run3 && read -r l <run3 && test "$l" = "r3" &&
	<"$cmd4" awk -f "$aptmp" -v missing=12345678 -v misscmd="echo r4a>>run4" &&
	<"$cmd4" awk -f "$aptmp" -v missing=12345678 -v misscmd="echo r4b>>run4" -v depsblob=1 &&
	<"$cmd4" awk -f "$aptmp" -v missing=12345678 -v misscmd="echo r4c>>run4" -v depsblob=2 &&
	{ read -r l1 && read -r l2 && read -r l3; } <run4 &&
	test "$l1" = "r4a" && test "$l2" = "r4b" && test "$l3" = "r4c"
'

test_expect_success 'missing command runs once' '
	rm -f run* &&
	cat "$cmd1" "$cmd2" "$cmd3" "$cmd4" |
	awk -f "$aptmp" -v depsblob=2 -v withan=1 -v missing=12345678 -v misscmd="echo r1>>run1" &&
	echo "r1" >expected &&
	test -s run1 && test_cmp run1 expected
'

test_expect_success 'depsblob=0..2' '
	<"$data3" awk -f "$aptmp" -v withan=1 -v missing=other >out &&
	test_cmp out "$data3.d0" &&
	<"$data3" awk -f "$aptmp" -v depsblob=0 -v withan=1 -v missing=other >out &&
	test_cmp out "$data3.d0" &&
	<"$data3" awk -f "$aptmp" -v depsblob=1 -v withan=1 -v missing=other >out &&
	test_cmp out "$data3.d1" &&
	<"$data3" awk -f "$aptmp" -v depsblob=2 -v withan=1 -v missing=other >out &&
	test_cmp out "$data3.d2" &&
	<"$data3r" awk -f "$aptmp" -v withan=1 -v missing=other >out &&
	test_cmp out "$data3r.d0" &&
	<"$data3r" awk -f "$aptmp" -v depsblob=0 -v withan=1 -v missing=other >out &&
	test_cmp out "$data3r.d0" &&
	<"$data3r" awk -f "$aptmp" -v depsblob=1 -v withan=1 -v missing=other >out &&
	test_cmp out "$data3r.d1" &&
	<"$data3r" awk -f "$aptmp" -v depsblob=2 -v withan=1 -v missing=other >out &&
	test_cmp out "$data3r.d2"
'

test_expect_success 'no K=1..4 without -v missing' '
	echo "20000007 0 k0" >expected &&
	<"$data1" awk -f "$aptmp" >out &&
	test_cmp out expected &&
	<"$data1" awk -f "$aptmp" -v withan=1 >out &&
	test_cmp out expected &&
	<"$data1" awk -f "$aptmp" -v withmt=1 >out &&
	test_cmp out expected &&
	<"$data1" awk -f "$aptmp" -v withan=1 -v withmt=1 >out &&
	test_cmp out expected
'

test_expect_success 'K=0,1 output' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 1 k4" >>expected &&
	<"$data1" awk -f "$aptmp" -v missing=other >out &&
	test_cmp out expected
'

test_expect_success 'K=0,1 output depsblob=1' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 1 k4" >>expected &&
	<"$data2" awk -f "$aptmp" -v missing=other -v depsblob=1 >out &&
	test_cmp out expected
'

test_expect_success 'K=0,1,4 output depsblob=2' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 4 k4" >>expected &&
	<"$data2" awk -f "$aptmp" -v missing=other -v depsblob=2 >out &&
	test_cmp out expected
'
test_expect_success 'K=0..3 output' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 2 k2" >>expected &&
	echo "other^{blob} 3 k3" >>expected &&
	echo "other^{blob} 1 k4" >>expected &&
	<"$data1" awk -f "$aptmp" -v withan=1 -v missing=other >out &&
	test_cmp out expected
'

test_expect_success 'K=0..3 output depsblob=1' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 2 k2" >>expected &&
	echo "other^{blob} 3 k3" >>expected &&
	echo "other^{blob} 1 k4" >>expected &&
	<"$data2" awk -f "$aptmp" -v withan=1 -v missing=other -v depsblob=1 >out &&
	test_cmp out expected
'

test_expect_success 'K=0..4 output depsblob=2' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 2 k2" >>expected &&
	echo "other^{blob} 3 k3" >>expected &&
	echo "other^{blob} 4 k4" >>expected &&
	<"$data2" awk -f "$aptmp" -v withan=1 -v missing=other -v depsblob=4 >out &&
	test_cmp out expected
'

test_expect_success 'K=0..2 output' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 2 k2" >>expected &&
	echo "other^{blob} 1 k4" >>expected &&
	<"$data1" awk -f "$aptmp" -v withan=1 -v withmt=0 -v missing=other >out &&
	test_cmp out expected
'

test_expect_success 'K=0..2 output depsblob=1' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 2 k2" >>expected &&
	echo "other^{blob} 1 k4" >>expected &&
	<"$data2" awk -f "$aptmp" -v withan=1 -v withmt=0 -v missing=other -v depsblob=1 >out &&
	test_cmp out expected
'

test_expect_success 'K=0..2,4 output depsblob=2' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 2 k2" >>expected &&
	echo "other^{blob} 4 k4" >>expected &&
	<"$data2" awk -f "$aptmp" -v withan=1 -v withmt=0 -v missing=other -v depsblob=2 >out &&
	test_cmp out expected
'

test_expect_success 'K=0,1,3 output' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 3 k3" >>expected &&
	echo "other^{blob} 1 k4" >>expected &&
	<"$data1" awk -f "$aptmp" -v withmt=1 -v missing=other >out &&
	test_cmp out expected
'

test_expect_success 'K=0,1,3 output depsblob=1' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 3 k3" >>expected &&
	echo "other^{blob} 1 k4" >>expected &&
	<"$data2" awk -f "$aptmp" -v withmt=1 -v missing=other -v depsblob=1 >out &&
	test_cmp out expected
'

test_expect_success 'K=0,1,3,4 output depsblob=2' '
	echo "20000007 0 k0" >expected &&
	echo "other^{blob} 1 k1" >>expected &&
	echo "other^{blob} 3 k3" >>expected &&
	echo "other^{blob} 4 k4" >>expected &&
	<"$data2" awk -f "$aptmp" -v withmt=1 -v missing=other -v depsblob=2 >out &&
	test_cmp out expected
'

test_done
