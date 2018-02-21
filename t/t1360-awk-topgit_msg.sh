#!/bin/sh

test_description='topgit_msg.awk functionality'

. ./test-lib.sh

ap="$(tg --awk-path)" && test -n "$ap" && test -d "$ap" || die
aptm="$ap/topgit_msg"
test -f "$aptm" && test -r "$aptm" && test -x "$aptm" || die

# Final output of topgit_msg_prepare looks like:
#
# 5e6bd1db23329803939ffa1e1f9052e678ea4a06 0 t/sample
#
# where the "0" can actually be in the range 0-4 inclusive.
# That output then gets piped through this:
#
# git cat-file --batch='%(objecttype) %(objectsize) %(rest)' | tr '\0' '\27'
#
# and fed to the topgit_msg script.  awk is not guaranteed to handle the
# NUL character so by running through tr (which is POSIXly supposed to) if
# some unfortunate blob is involved this topgit_msg script still has a
# chance of doing something correct with the result
#
# note that despite the format provided, "missing" will always be the second
# field output for missing objects

test_plan 42

v_blobify() { eval "$1="'"$(git hash-object -t blob -w --stdin)"'; }
v_blobify mtblob </dev/null || die

doprep() {
	git cat-file --batch='%(objecttype) %(objectsize) %(rest)' |
	tr '\0' '\27'
}
dotgmsg() {
	doprep |
	awk -f "$aptm" "$@"
}

v_blobify mtsubj <<-EOT || die
	Subject:
	EOT
v_blobify wrapabc <<-EOT || die
	Subject:
	 a
	  b
	   c
	EOT
v_blobify first <<-EOT || die
	Subject: first
	EOT
v_blobify wonky <<-EOT || die
	subJeCT:   first
	EOT
v_blobify second <<-EOT || die
	Subject: second
	EOT
v_blobify third <<-EOT || die
	Subject: third
	EOT
v_blobify doubleup <<-EOT || die
	This:
	Double-up: line
	 one
	X-other:
	double-UP:
	 line two
	EOT

printf "%s\n" \
	"$first 0 t/first"	\
	"$second 0 t/second"	\
	"$third 0 t/third"	|
doprep >cat123 || die

test_expect_success 'topgit_msg runs' '
	# some stupid awks might not even compile it
	awk -f "$aptm" </dev/null &&
	# and make sure the helper works too
	dotgmsg </dev/null
'

test_expect_success 'first subject' '
	echo "t/first 0 first" >expected &&
	echo "$first 0 t/first" | dotgmsg >actual &&
	test_cmp actual expected
'

test_expect_success 'second subject' '
	echo "t/second 0 second" >expected &&
	echo "$second 0 t/second" | dotgmsg >actual &&
	test_cmp actual expected
'

test_expect_success 'third subject' '
	echo "t/third 0 third" >expected &&
	echo "$third 0 t/third" | dotgmsg >actual &&
	test_cmp actual expected
'

test_expect_success 'third subject colfmt' '
	printf "%-39s\t%s\n" "t/third 0" "third" >expected &&
	echo "$third 0 t/third" |
	dotgmsg -v colfmt=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'third subject colfmt nokind' '
	printf "%-39s\t%s\n" "t/third" "third" >expected &&
	echo "$third 0 t/third" |
	dotgmsg -v colfmt=1 -v nokind=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'third subject colfmt noname' '
	printf "%-39s\t%s\n" "0" "third" >expected &&
	echo "$third 0 t/third" |
	dotgmsg -v colfmt=1 -v noname=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'third subject colfmt nokind noname' '
	echo "third" >expected &&
	echo "$third 0 t/third" |
	dotgmsg -v colfmt=1 -v nokind=1 -v noname=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'two subjects' '
	echo "t/first 0 first" >expected &&
	echo "t/second 0 second" >>expected &&
	printf "%s\n" "$first 0 t/first" "$second 0 t/second" |
	dotgmsg >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects' '
	echo "t/first 0 first" >expected &&
	echo "t/second 0 second" >>expected &&
	echo "t/third 0 third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$second 0 t/second"	\
		"$third 0 t/third"	|
	dotgmsg >actual &&
	test_cmp actual expected
'

test_expect_success 'five subjects all kinds' '
	echo "t/first 0 first" >expected &&
	echo "t/firstx 1 branch t/firstx (missing .topmsg)" >>expected &&
	echo "t/second 2 branch t/second (annihilated)" >>expected &&
	echo "t/third 3 branch t/third (no commits)" >>expected &&
	echo "t/firsty 4 branch t/firsty (bare branch)" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$first 1 t/firstx"	\
		"$second 2 t/second"	\
		"$third 3 t/third"	\
		"$first 4 t/firsty"	|
	dotgmsg -v withan=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects exclbr second' '
	echo "t/first 0 first" >expected &&
	echo "t/third 0 third" >>expected &&
	<cat123 awk -f "$aptm" -v "exclbr=t/second" >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects inclbr second' '
	echo "t/second 0 second" >expected &&
	<cat123 awk -f "$aptm" -v "inclbr=t/second" >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects inclbr first and second' '
	echo "t/first 0 first" >expected &&
	echo "t/second 0 second" >>expected &&
	<cat123 awk -f "$aptm" -v "inclbr=t/second t/first" >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects exclbr second and third' '
	echo "t/first 0 first" >expected &&
	<cat123 awk -f "$aptm" -v "exclbr=t/third t/second" >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects inclbr second and third exclbr second' '
	echo "t/third 0 third" >expected &&
	<cat123 awk -f "$aptm" -v "inclbr=t/second t/third" -v "exclbr=t/second" >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects only1' '
	echo "t/first 0 first" >expected &&
	<cat123 awk -f "$aptm" -v only1=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects only1 inclbr' '
	echo "t/first 0 first" >expected &&
	<cat123 awk -f "$aptm" -v only1=1 -v "inclbr=t/first" >actual &&
	test_cmp actual expected &&
	echo "t/second 0 second" >expected &&
	<cat123 awk -f "$aptm" -v only1=1 -v "inclbr=t/second" >actual &&
	test_cmp actual expected &&
	echo "t/third 0 third" >expected &&
	<cat123 awk -f "$aptm" -v only1=1 -v "inclbr=t/third" >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects only1 exclbr' '
	echo "t/first 0 first" >expected &&
	<cat123 awk -f "$aptm" -v only1=1 -v "exclbr=t/second" >actual &&
	test_cmp actual expected &&
	echo "t/second 0 second" >expected &&
	<cat123 awk -f "$aptm" -v only1=1 -v "exclbr=t/third t/first" >actual &&
	test_cmp actual expected &&
	echo "t/third 0 third" >expected &&
	<cat123 awk -f "$aptm" -v only1=1 -v "exclbr=t/second t/first" >actual &&
	test_cmp actual expected &&
	echo "t/third 0 third" >expected &&
	<cat123 awk -f "$aptm" -v only1=1 -v "exclbr=t/first t/second" >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects no kind' '
	echo "t/first first" >expected &&
	echo "t/second second" >>expected &&
	echo "t/third third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$second 0 t/second"	\
		"$third 0 t/third"	|
	dotgmsg -v nokind=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects no name' '
	echo "0 first" >expected &&
	echo "0 second" >>expected &&
	echo "0 third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$second 0 t/second"	\
		"$third 0 t/third"	|
	dotgmsg -v noname=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects no kind and no name' '
	echo "first" >expected &&
	echo "second" >>expected &&
	echo "third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$second 0 t/second"	\
		"$third 0 t/third"	|
	dotgmsg -v nokind=1 -v noname=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects middle missing' '
	echo "t/first 0 first" >expected &&
	echo "t/third 0 third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"		\
		"555${second#???} 0 t/second"	\
		"$third 0 t/third"		|
	dotgmsg >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects middle no keyword' '
	echo "t/first 0 first" >expected &&
	echo "t/second 0 branch t/second (missing \"Subject:\" in .topmsg)" >>expected &&
	echo "t/third 0 third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$mtblob 0 t/second"	\
		"$third 0 t/third"	|
	dotgmsg >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects middle empty keyword' '
	echo "t/first 0 first" >expected &&
	echo "t/second 0 branch t/second (empty \"Subject:\" in .topmsg)" >>expected &&
	echo "t/third 0 third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$mtsubj 0 t/second"	\
		"$third 0 t/third"	|
	dotgmsg >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects middle K==1' '
	echo "t/first 0 first" >expected &&
	echo "t/second 1 branch t/second (missing .topmsg)" >>expected &&
	echo "t/third 0 third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$second 1 t/second"	\
		"$third 0 t/third"	|
	dotgmsg >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects middle K==2' '
	echo "t/first 0 first" >expected &&
	echo "t/second 2 branch t/second (annihilated)" >>expected &&
	echo "t/third 0 third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$second 2 t/second"	\
		"$third 0 t/third"	|
	dotgmsg -v withan=1 -v withmt=0 >actual &&
	test_cmp actual expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$second 2 t/second"	\
		"$second 3 t/bogus"	\
		"$third 0 t/third"	|
	dotgmsg -v withan=1 -v withmt=0 >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects middle K==3' '
	echo "t/first 0 first" >expected &&
	echo "t/second 3 branch t/second (no commits)" >>expected &&
	echo "t/third 0 third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$second 3 t/second"	\
		"$third 0 t/third"	|
	dotgmsg -v withmt=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$second 2 t/bogus"	\
		"$second 3 t/second"	\
		"$third 0 t/third"	|
	dotgmsg -v withmt=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects middle K==4' '
	echo "t/first 0 first" >expected &&
	echo "t/second 4 branch t/second (bare branch)" >>expected &&
	echo "t/third 0 third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$second 4 t/second"	\
		"$third 0 t/third"	|
	dotgmsg >actual &&
	test_cmp actual expected
'

test_expect_success 'three subjects middle wrapped' '
	echo "t/first 0 first" >expected &&
	echo "t/second 0 a b c" >>expected &&
	echo "t/third 0 third" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$wrapabc 0 t/second"	\
		"$third 0 t/third"	|
	dotgmsg >actual &&
	test_cmp actual expected
'

test_expect_success 'five subjects all kinds kwregex=subject' '
	echo "t/first 0 first" >expected &&
	echo "t/firstx 1 branch t/firstx (missing .topmsg)" >>expected &&
	echo "t/second 2 branch t/second (annihilated)" >>expected &&
	echo "t/third 3 branch t/third (no commits)" >>expected &&
	echo "t/firsty 4 branch t/firsty (bare branch)" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$mtblob 1 t/firstx"	\
		"$mtblob 2 t/second"	\
		"$mtblob 3 t/third"	\
		"$mtblob 4 t/firsty"	|
	doprep >five &&
	<five awk -f "$aptm" -v withan=1 -v kwregex="Subject" >actual &&
	test_cmp actual expected &&
	<five awk -f "$aptm" -v withan=1 -v kwregex="subject" >actual &&
	test_cmp actual expected &&
	<five awk -f "$aptm" -v withan=1 -v kwregex="sUbJeCt" >actual &&
	test_cmp actual expected
'

test_expect_success 'five subjects all kinds kwregex=(subject)' '
	echo "t/first 0 first" >expected &&
	echo "t/firstx 1 " >>expected &&
	echo "t/second 2 " >>expected &&
	echo "t/third 3 " >>expected &&
	echo "t/firsty 4 " >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$mtblob 1 t/firstx"	\
		"$mtblob 2 t/second"	\
		"$mtblob 3 t/third"	\
		"$mtblob 4 t/firsty"	|
	doprep >five &&
	<five awk -f "$aptm" -v withan=1 -v kwregex="(sUbJeCt)" >actual &&
	test_cmp actual expected
'

test_expect_success 'five subjects all kinds kwregex=(subject) nokind noname' '
	echo "first" >expected &&
	echo "" >>expected &&
	echo "" >>expected &&
	echo "" >>expected &&
	echo "" >>expected &&
	printf "%s\n" \
		"$first 0 t/first"	\
		"$mtblob 1 t/firstx"	\
		"$mtblob 2 t/second"	\
		"$mtblob 3 t/third"	\
		"$mtblob 4 t/firsty"	|
	doprep >five &&
	<five awk -f "$aptm" -v withan=1 -v nokind=1 -v noname=1 -v kwregex="(sUbJeCt)" >actual &&
	test_cmp actual expected
'

test_expect_success 'five subjects all kinds kwregex=+subject nokind noname' '
	echo "Subject: first" >expected &&
	printf "%s\n" \
		"$wonky 0 t/first"	\
		"$mtblob 1 t/firstx"	\
		"$mtblob 2 t/second"	\
		"$mtblob 3 t/third"	\
		"$mtblob 4 t/firsty"	|
	doprep >five &&
	<five awk -f "$aptm" -v withan=1 -v nokind=1 -v noname=1 -v kwregex="+sUbJeCt" >actual &&
	test_cmp actual expected &&
	<five awk -f "$aptm" -v withan=1 -v nokind=1 -v noname=1 -v kwregex="+(sUbJeCt)" >actual &&
	test_cmp actual expected
'

test_expect_success 'double-up kwregex' '
	echo "line one" >expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v kwregex="DOUBle-uP" >actual &&
	test_cmp actual expected
'

test_expect_success 'double-up kwregex empty' '
	echo "" >expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v kwregex="this" >actual &&
	test_cmp actual expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v kwregex="no-such-keyword" >actual &&
	test_cmp actual expected
'

test_expect_success 'double-up kwregex only1 empty' '
	>expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v only1=1 -v kwregex="this" >actual &&
	test_cmp actual expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v only1=1 -v kwregex="no-such-keyword" >actual &&
	test_cmp actual expected
'

test_expect_success 'double-up kwregex+ empty' '
	echo "This:" >expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v kwregex="+this" >actual &&
	test_cmp actual expected &&
	>expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v kwregex="+no-such-keyword" >actual &&
	test_cmp actual expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v kwregex="+Double" >actual &&
	test_cmp actual expected
'

test_expect_success 'double-up kwregex+' '
	echo "Double-Up: line one" >expected &&
	echo "Double-Up: line two" >>expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v kwregex="+DOUBle-uP" >actual &&
	test_cmp actual expected
'

test_expect_success 'double-up kwregex+ wildcard' '
	echo "Double-Up: line one" >expected &&
	echo "X-Other:" >>expected &&
	echo "Double-Up: line two" >>expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v kwregex="+[dx].*" >actual &&
	test_cmp actual expected
'

test_expect_success 'double-up kwregex match all' '
	echo "" >expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v kwregex=".*" >actual &&
	test_cmp actual expected
'

test_expect_success 'double-up kwregex+ match all' '
	echo "This:" >expected &&
	echo "Double-Up: line one" >>expected &&
	echo "X-Other:" >>expected &&
	echo "Double-Up: line two" >>expected &&
	printf "%s\n" "$doubleup 0 whatever" |
	dotgmsg -v nokind=1 -v noname=1 -v kwregex="+.*" >actual &&
	test_cmp actual expected
'

test_done
