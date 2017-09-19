#!/bin/sh

test_description='topgit_branches.awk functionality'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

ap="$(tg --awk-path)" && test -n "$ap" && test -d "$ap" || die
aptb="$ap/topgit_branches"
test -f "$aptb" && test -r "$aptb" && test -x "$aptb" || die

test_plan 16

input="fake_input.txt"
cat <<-EOT >"$input" || die
	10000000 garbage
	more garbage here
	even more garbage here
	yup missing it :
	20000001 whatever branch1 :
	20000002 commit
	20000003 commit
	20000004 tree
	20000005 tree
	30000001 something ebranch1 :
	30000002 commit
	30000002 commit
	30000003 tree
	30000003 tree
	40000001 tag abranch1 :
	40000002 commit
	40000003 commit
	40000004 tree
	40000004 tree
EOT
input2="input2.txt"
cp "$input" "$input2" || die
cat <<-EOT >>"$input2" || die
	50000001 blob branch2 :
	50000002 commit
	50000003 commit
	50000004 tree
	50000005 tree
	60000001 tree branch3 :
	60000002 commit
	60000003 commit
	60000004 tree
	60000005 tree
	70000001 commit branch4 :
	70000002 commit
	70000003 commit
	70000004 tree
	70000005 tree
	10000001 object check ?
	80000001 object branch5 :
	80000002 commit
	80000003 commit
	80000004 tree
	80000005 tree
EOT

test_expect_success 'topgit_branches runs' '
	# some stupid awks might not even compile it
	awk -f "$aptb" </dev/null
'

test_expect_success 'files are truncated' '
	echo one >one && test -s one &&
	awk -v brfile="one" -f "$aptb" </dev/null &&
	test ! -s one &&
	echo two >two && test -s two &&
	awk -v anfile="two" -f "$aptb" </dev/null &&
	test ! -s two &&
	echo one >one && test -s one &&
	echo two >two && test -s two &&
	awk -v brfile="one" -v anfile="two" -f "$aptb" </dev/null &&
	test ! -s one &&
	test ! -s two
'

test_expect_success 'bad/good input' '
	# the attempt to read four extra lines fails
	echo "bad input here :" >badinput.txt &&
	test_must_fail awk -f "$aptb" <badinput.txt &&
	cat <<-EOT >badinput.txt &&
		bad input here :
		5555 commit
		6666 commit
		1111 tree
	EOT
	test_must_fail awk -f "$aptb" <badinput.txt &&
	echo "2222 tree" >>badinput.txt &&
	# not bad anymore
	result="$(awk -f "$aptb" <badinput.txt)" &&
	test z"$result" = z"here"
'

test_expect_success 'no opts output okay' '
	printf "%s\n" branch1 ebranch1 abranch1 >expected &&
	awk -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	awk -v noann=0 -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt
'

test_expect_success 'noann output okay' '
	printf "%s\n" branch1 >expected &&
	awk -v noann=1 -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt
'

test_expect_success 'brfile/anfile output okay' '
	printf "%s\n" branch1 ebranch1 abranch1 >expected &&
	rm -f brfile &&
	awk -v brfile=brfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expected brfile &&
	awk -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expected brfile &&
	printf "%s\n" branch1 >expected &&
	printf "%s\n" ebranch1 abranch1 >expected2 &&
	rm -f brfile anfile &&
	awk -v noann=1 -v brfile=brfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expected brfile &&
	rm -f brfile anfile &&
	awk -v noann=1 -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expected brfile &&
	test_cmp expected2 anfile &&
	rm -f anfile &&
	printf "%s\n" branch1 ebranch1 abranch1 >expected &&
	awk -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expected2 anfile &&
	rm -f anfile &&
	printf "%s\n" branch1 >expected &&
	awk -v noann=1 -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expected2 anfile
'

test_expect_success 'exclude branches' '
	>expected &&
	awk -v exclbr="ebranch1 other abranch1 branch1" -f "$aptb" <"$input" >output.txt &&
	test ! -s output.txt &&
	printf "%s\n" branch1 abranch1 >expected &&
	awk -v exclbr="ebranch1 other xabranch1 xbranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" ebranch1 abranch1 >expected &&
	awk -v exclbr="xebranch1 other xabranch1 branch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" branch1 abranch1 >expected &&
	awk -v exclbr="ebranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt
'

test_expect_success 'noann=1 exclude branches' '
	>expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v exclbr="ebranch1 other abranch1 branch1" -f "$aptb" <"$input" >output.txt &&
	test ! -s output.txt &&
	printf "%s\n" branch1 >expected &&
	awk -v noann=1 -v exclbr="ebranch1 other xabranch1 xbranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	>expected &&
	awk -v noann=1 -v exclbr="xebranch1 other xabranch1 branch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" branch1 >expected &&
	awk -v noann=1 -v exclbr="ebranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt
'

test_expect_success 'exclude branches brfile/anfile' '
	printf "%s\n" branch1 ebranch1 abranch1 >expectedbr &&
	printf "%s\n" ebranch1 abranch1 >expectedan &&
	>expected &&
	rm -f brfile anfile &&
	awk -v exclbr="ebranch1 other abranch1 branch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test ! -s output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" branch1 abranch1 >expected &&
	rm -f brfile anfile &&
	awk -v exclbr="ebranch1 other xabranch1 xbranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" ebranch1 abranch1 >expected &&
	rm -f brfile anfile &&
	awk -v exclbr="xebranch1 other xabranch1 branch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" branch1 abranch1 >expected &&
	rm -f brfile anfile &&
	awk -v exclbr="ebranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile
'

test_expect_success 'noann=1 exclude branches brfile/anfile' '
	printf "%s\n" branch1 >expectedbr &&
	printf "%s\n" ebranch1 abranch1 >expectedan &&
	>expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v exclbr="ebranch1 other abranch1 branch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test ! -s output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" branch1 >expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v exclbr="ebranch1 other xabranch1 xbranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	>expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v exclbr="xebranch1 other xabranch1 branch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" branch1 >expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v exclbr="ebranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile
'

test_expect_success 'include branches' '
	printf "%s\n" branch1 >expected &&
	awk -v inclbr="xebranch1 other xabranch1 branch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" abranch1 >expected &&
	awk -v inclbr="xebranch1 other abranch1 xbranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" ebranch1 >expected &&
	awk -v inclbr="ebranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" branch1 ebranch1 >expected &&
	awk -v inclbr="ebranch1 branch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" branch1 abranch1 >expected &&
	awk -v inclbr="branch1 abranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" ebranch1 abranch1 >expected &&
	awk -v inclbr="abranch1 ebranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" branch1 ebranch1 abranch1 >expected &&
	awk -v inclbr="abranch1 branch1 ebranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt
'

test_expect_success 'noann=1 include branches' '
	printf "%s\n" branch1 >expected &&
	awk -v noann=1 -v inclbr="xebranch1 other xabranch1 branch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	>expected &&
	awk -v noann=1 -v inclbr="xebranch1 other abranch1 xbranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	>expected &&
	awk -v noann=1 -v inclbr="ebranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" branch1 >expected &&
	awk -v noann=1 -v inclbr="ebranch1 branch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" branch1 >expected &&
	awk -v noann=1 -v inclbr="branch1 abranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	>expected &&
	awk -v noann=1 -v inclbr="abranch1 ebranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" branch1 >expected &&
	awk -v noann=1 -v inclbr="abranch1 branch1 ebranch1" -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt
'

test_expect_success 'include branches brfile/anfile' '
	printf "%s\n" branch1 ebranch1 abranch1 >expectedbr &&
	printf "%s\n" ebranch1 abranch1 >expectedan &&
	printf "%s\n" branch1 >expected &&
	rm -f brfile anfile &&
	awk -v inclbr="xebranch1 other xabranch1 branch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" abranch1 >expected &&
	rm -f brfile anfile &&
	awk -v inclbr="xebranch1 other abranch1 xbranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" ebranch1 >expected &&
	rm -f brfile anfile &&
	awk -v inclbr="ebranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" branch1 ebranch1 >expected &&
	rm -f brfile anfile &&
	awk -v inclbr="ebranch1 branch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" branch1 abranch1 >expected &&
	rm -f brfile anfile &&
	awk -v inclbr="branch1 abranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" ebranch1 abranch1 >expected &&
	rm -f brfile anfile &&
	awk -v inclbr="abranch1 ebranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" branch1 ebranch1 abranch1 >expected &&
	rm -f brfile anfile &&
	awk -v inclbr="abranch1 branch1 ebranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile
'

test_expect_success 'noann=1 include branches brfile/anfile' '
	printf "%s\n" branch1 >expectedbr &&
	printf "%s\n" ebranch1 abranch1 >expectedan &&
	printf "%s\n" branch1 >expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v inclbr="xebranch1 other xabranch1 branch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	>expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v inclbr="xebranch1 other abranch1 xbranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	>expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v inclbr="ebranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" branch1 >expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v inclbr="ebranch1 branch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" branch1 >expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v inclbr="branch1 abranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	>expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v inclbr="abranch1 ebranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" branch1 >expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v inclbr="abranch1 branch1 ebranch1" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr brfile &&
	test_cmp expectedan anfile
'

test_expect_success 'noann=0/1 include/exclude branches' '
	printf "%s\n" branch1 ebranch1 abranch1 branch3 branch5 >expected &&
	awk -v inclbr="branch1 branch2 branch3 branch4 branch5 ebranch1 abranch1" -v exclbr="branch2 branch4" -f "$aptb" <"$input2" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" branch1 branch3 branch5 >expected &&
	awk -v noann=1 -v inclbr="branch1 branch2 branch3 branch4 branch5 ebranch1 abranch1" -v exclbr="branch2 branch4" -f "$aptb" <"$input2" >output.txt &&
	test_cmp expected output.txt &&
	printf "%s\n" branch1 ebranch1 abranch1 branch2 branch3 branch4 branch5 >expectedbr
'

test_expect_success 'noann=0/1 include/exclude branches brfile/anfile' '
	printf "%s\n" branch1 ebranch1 abranch1 branch2 branch3 branch4 branch5 >expectedbr0 &&
	printf "%s\n" branch1 branch2 branch3 branch4 branch5 >expectedbr1 &&
	printf "%s\n" ebranch1 abranch1 >expectedan &&
	printf "%s\n" branch1 ebranch1 abranch1 branch3 branch5 >expected &&
	rm -f brfile anfile &&
	awk -v inclbr="branch1 branch2 branch3 branch4 branch5 ebranch1 abranch1" -v exclbr="branch2 branch4" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input2" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr0 brfile &&
	test_cmp expectedan anfile &&
	printf "%s\n" branch1 branch3 branch5 >expected &&
	rm -f brfile anfile &&
	awk -v noann=1 -v inclbr="branch1 branch2 branch3 branch4 branch5 ebranch1 abranch1" -v exclbr="branch2 branch4" -v brfile=brfile -v anfile=anfile -f "$aptb" <"$input2" >output.txt &&
	test_cmp expected output.txt &&
	test_cmp expectedbr1 brfile &&
	test_cmp expectedan anfile
'

test_done
