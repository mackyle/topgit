#!/bin/sh

test_description='topgit_deps.awk functionality'

. ./test-lib.sh

ap="$(tg --awk-path)" && test -n "$ap" && test -d "$ap" || die
aptd="$ap/topgit_deps"
test -f "$aptd" && test -r "$aptd" && test -x "$aptd" || die

# Final output of topgit_deps_prepare looks like:
#
# 5e6bd1db23329803939ffa1e1f9052e678ea4a06 t/sample
#
# That output then gets piped through this:
#
# git cat-file --batch='%(objecttype) %(objectsize) %(rest)' | tr '\0' '\27'
#
# and fed to the topgit_deps script.  awk is not guaranteed to handle the
# NUL character so by running through tr (which is POSIXly supposed to) if
# some unfortunate blob is involved this topgit_deps script still has a
# chance of doing something correct with the result
#
# note that despite the format provided, "missing" will always be the second
# field output for missing objects

test_plan 40

v_blobify() { eval "$1="'"$(git hash-object -t blob -w --stdin)"'; }
v_blobify mtblob </dev/null || die
noeol="$(printf '%s' "noeol" | git hash-object -t blob -w --stdin)" || die
v_blobify mtline <<-EOT || die

	EOT
v_blobify looper <<-EOT || die
	looper
	EOT
v_blobify deps <<-EOT || die
	dep1
	dep2
	EOT
v_blobify alts <<-EOT || die
	alt1
	alt2
	EOT
v_blobify dupe2 <<-EOT || die
	dupe
	dupe
	EOT
v_blobify dupe3 <<-EOT || die
	dupe
	dupe
	dupe
	EOT
v_blobify dupe32 <<-EOT || die
	dupe
	two
	dupe
	two
	dupe
	EOT
v_blobify looperduper <<-EOT || die
	looper
	dupe
	two
	dupe
	two
	dupe
	looper
	EOT
v_blobify tens <<-EOT || die
	one
	two
	two
	three
	three
	four
	five
	five
	six
	seven
	seven
	eight
	nine
	ten
	EOT

doprep() {
	git cat-file --batch='%(objecttype) %(objectsize) %(rest)' |
	tr '\0' '\27'
}
dotgdeps() {
	doprep |
	awk -f "$aptd" "$@"
}

test_expect_success 'topgit_deps runs' '
	# some stupid awks might not even compile it
	awk -f "$aptd" </dev/null &&
	# and make sure the helper works too
	dotgdeps </dev/null
'

test_expect_success 'invalid anfile fails if read' '
	rm -f no-such-file &&
	test ! -e no-such-file &&
	>expected &&
	</dev/null dotgdeps -v anfile=no-such-file >actual &&
	test_cmp actual expected &&
	</dev/null dotgdeps -v withan=1 -v anfile=no-such-file >actual &&
	test_cmp actual expected &&
	echo "..." | test_must_fail dotgdeps -v anfile=no-such-file >actual &&
	test_cmp actual expected &&
	echo "..." | dotgdeps -v withan=1 -v anfile=no-such-file >actual &&
	test_cmp actual expected &&
	test ! -e no-such-file
'

test_expect_success 'invalid brfile fails if read' '
	rm -f no-such-file &&
	test ! -e no-such-file &&
	>expected &&
	</dev/null dotgdeps -v brfile=no-such-file >actual &&
	test_cmp actual expected &&
	</dev/null dotgdeps -v tgonly=1 -v brfile=no-such-file >actual &&
	test_cmp actual expected &&
	echo "..." |
	test_must_fail dotgdeps -v tgonly=1 -v brfile=no-such-file >actual &&
	test_cmp actual expected &&
	echo "..." | dotgdeps -v brfile=no-such-file >actual &&
	test_cmp actual expected &&
	test ! -e no-such-file
'

test_expect_success 'anfile unperturbed without rman' '
	echo "an file here" >anorig &&
	cat anorig >anfile &&
	>expected &&
	</dev/null dotgdeps -v anfile=anfile >actual &&
	test_cmp actual expected &&
	test_cmp anfile anorig &&
	</dev/null dotgdeps -v withan=1 -v anfile=anfile >actual &&
	test_cmp actual expected &&
	test_cmp anfile anorig &&
	echo "..." | dotgdeps -v anfile=anfile >actual &&
	test_cmp actual expected &&
	test_cmp anfile anorig &&
	echo "..." | dotgdeps -v withan=1 -v anfile=anfile >actual &&
	test_cmp actual expected &&
	test_cmp anfile anorig
'

test_expect_success 'brfile unperturbed without rmbr' '
	echo "br file here" >brorig &&
	cat brorig >brfile &&
	>expected &&
	</dev/null dotgdeps -v brfile=brfile >actual &&
	test_cmp actual expected &&
	test_cmp brfile brorig &&
	</dev/null dotgdeps -v tgonly=1 -v brfile=brfile >actual &&
	test_cmp actual expected &&
	test_cmp brfile brorig &&
	echo "..." | dotgdeps -v brfile=brfile >actual &&
	test_cmp actual expected &&
	test_cmp brfile brorig &&
	echo "..." | dotgdeps -v tgonly=1 -v brfile=brfile >actual &&
	test_cmp actual expected &&
	test_cmp brfile brorig
'

test_expect_success 'anfile removed with rman' '
	echo "an file here" >anorig &&
	>expected &&
	cat anorig >anfile &&
	</dev/null dotgdeps -v anfile=anfile -v rman=1 >actual &&
	test_cmp actual expected &&
	test ! -e anfile &&
	cat anorig >anfile &&
	</dev/null dotgdeps -v withan=1 -v anfile=anfile -v rman=1 >actual &&
	test_cmp actual expected &&
	test ! -e anfile &&
	cat anorig >anfile &&
	echo "..." | dotgdeps -v anfile=anfile -v rman=1 >actual &&
	test_cmp actual expected &&
	test ! -e anfile &&
	cat anorig >anfile &&
	echo "..." | dotgdeps -v withan=1 -v anfile=anfile -v rman=1 >actual &&
	test_cmp actual expected &&
	test ! -e anfile
'

test_expect_success 'brfile removed with rmbr' '
	echo "br file here" >brorig &&
	>expected &&
	cat brorig >brfile &&
	</dev/null dotgdeps -v brfile=brfile -v rmbr=1 >actual &&
	test_cmp actual expected &&
	test ! -e brfile &&
	cat brorig >brfile &&
	</dev/null dotgdeps -v tgonly=1 -v brfile=brfile -v rmbr=1 >actual &&
	test_cmp actual expected &&
	test ! -e brfile &&
	cat brorig >brfile &&
	echo "..." | dotgdeps -v brfile=brfile -v rmbr=1 >actual &&
	test_cmp actual expected &&
	test ! -e brfile &&
	cat brorig >brfile &&
	echo "..." | dotgdeps -v tgonly=1 -v brfile=brfile -v rmbr=1 >actual &&
	test_cmp actual expected &&
	test ! -e brfile
'

test_expect_success 'basic functionality' '
	echo "t/basic dep1" >expected &&
	echo "t/basic dep2" >>expected &&
	echo "$deps t/basic" | dotgdeps >actual &&
	test_cmp actual expected
'

test_expect_success 'basic noeol functionality' '
	echo "t/noeol1 noeol" >expected &&
	echo "t/basic dep1" >>expected &&
	echo "t/basic dep2" >>expected &&
	echo "t/noeol2 noeol" >>expected &&
	<<-EOT dotgdeps >actual &&
		$noeol t/noeol1
		$deps t/basic
		$noeol t/noeol2
	EOT
	test_cmp actual expected
'

test_expect_success 'basic functionality rev' '
	echo "dep2 t/basic" >expected &&
	echo "dep1 t/basic" >>expected &&
	echo "$deps t/basic" | dotgdeps -v rev=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'basic functionality withbr' '
	echo "t/basic dep1" >expected &&
	echo "t/basic dep2" >>expected &&
	echo "t/basic t/basic" >>expected &&
	echo "$deps t/basic" | dotgdeps -v withbr=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'basic functionality withbr rev' '
	echo "t/basic t/basic" >expected &&
	echo "dep2 t/basic" >>expected &&
	echo "dep1 t/basic" >>expected &&
	echo "$deps t/basic" | dotgdeps -v withbr=1 -v rev=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'multi functionality' '
	echo "t/basic dep1" >expected &&
	echo "t/basic dep2" >>expected &&
	echo "t/multi alt1" >>expected &&
	echo "t/multi alt2" >>expected &&
	<<-EOT dotgdeps >actual &&
		$deps t/basic
		$alts t/multi
	EOT
	test_cmp actual expected
'

test_expect_success 'multi functionality rev' '
	echo "dep2 t/basic" >expected &&
	echo "dep1 t/basic" >>expected &&
	echo "alt2 t/multi" >>expected &&
	echo "alt1 t/multi" >>expected &&
	<<-EOT dotgdeps -v rev=1 >actual &&
		$deps t/basic
		$alts t/multi
	EOT
	test_cmp actual expected
'

test_expect_success 'multi functionality withbr' '
	echo "t/basic dep1" >expected &&
	echo "t/basic dep2" >>expected &&
	echo "t/basic t/basic" >>expected &&
	echo "t/multi alt1" >>expected &&
	echo "t/multi alt2" >>expected &&
	echo "t/multi t/multi" >>expected &&
	<<-EOT dotgdeps -v withbr=1 >actual &&
		$deps t/basic
		$alts t/multi
	EOT
	test_cmp actual expected
'

test_expect_success 'multi functionality rev withbr' '
	echo "t/basic t/basic" >expected &&
	echo "dep2 t/basic" >>expected &&
	echo "dep1 t/basic" >>expected &&
	echo "t/multi t/multi" >>expected &&
	echo "alt2 t/multi" >>expected &&
	echo "alt1 t/multi" >>expected &&
	<<-EOT dotgdeps -v rev=1 -v withbr=1 >actual &&
		$deps t/basic
		$alts t/multi
	EOT
	test_cmp actual expected
'

test_expect_success 'self loop omitted' '
	>expected &&
	echo "$looper looper" | dotgdeps >actual &&
	test_cmp actual expected
'

test_expect_success 'self loop omitted withbr' '
	echo "looper looper" >expected &&
	echo "$looper looper" | dotgdeps -v withbr=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'dupes omitted' '
	echo "t/check dupe" >expected &&
	echo "$dupe2 t/check" | dotgdeps >actual &&
	test_cmp actual expected &&
	echo "$dupe3 t/check" | dotgdeps >actual &&
	test_cmp actual expected
'

test_expect_success 'dupes omitted withbr' '
	echo "t/check dupe" >expected &&
	echo "t/check t/check" >>expected &&
	echo "$dupe2 t/check" | dotgdeps -v withbr=1 >actual &&
	test_cmp actual expected &&
	echo "$dupe3 t/check" | dotgdeps -v withbr=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'multi dupes omitted' '
	echo "t/check dupe" >expected &&
	echo "t/check dupe" >>expected &&
	echo "t/check2 dupe" >>expected &&
	echo "t/check2 dupe" >>expected &&
	<<-EOT dotgdeps >actual &&
		$dupe2 t/check
		$dupe2 t/check
		$dupe3 t/check2
		$dupe3 t/check2
	EOT
	test_cmp actual expected
'

test_expect_success 'multi dupes omitted withbr' '
	echo "t/check dupe" >expected &&
	echo "t/check t/check" >>expected &&
	echo "t/check dupe" >>expected &&
	echo "t/check t/check" >>expected &&
	echo "t/check2 dupe" >>expected &&
	echo "t/check2 t/check2" >>expected &&
	echo "t/check2 dupe" >>expected &&
	echo "t/check2 t/check2" >>expected &&
	<<-EOT dotgdeps -v withbr=1 >actual &&
		$dupe2 t/check
		$dupe2 t/check
		$dupe3 t/check2
		$dupe3 t/check2
	EOT
	test_cmp actual expected
'

test_expect_success 'super multi loop dupes omitted' '
	echo "t/check dupe" >expected &&
	echo "t/check two" >>expected &&
	echo "looper dupe" >>expected &&
	echo "looper two" >>expected &&
	<<-EOT dotgdeps >actual &&
		$dupe32 t/check
		$looperduper looper
	EOT
	test_cmp actual expected
'

test_expect_success 'super multi loop dupes omitted rev' '
	echo "two t/check" >expected &&
	echo "dupe t/check" >>expected &&
	echo "two looper" >>expected &&
	echo "dupe looper" >>expected &&
	<<-EOT dotgdeps -v rev=1 >actual &&
		$dupe32 t/check
		$looperduper looper
	EOT
	test_cmp actual expected
'

test_expect_success 'super multi loop dupes omitted withbr' '
	echo "t/check dupe" >expected &&
	echo "t/check two" >>expected &&
	echo "t/check t/check" >>expected &&
	echo "looper dupe" >>expected &&
	echo "looper two" >>expected &&
	echo "looper looper" >>expected &&
	<<-EOT dotgdeps -v withbr=1 >actual &&
		$dupe32 t/check
		$looperduper looper
	EOT
	test_cmp actual expected
'

test_expect_success 'super multi loop dupes omitted rev withbr' '
	echo "t/check t/check" >expected &&
	echo "two t/check" >>expected &&
	echo "dupe t/check" >>expected &&
	echo "looper looper" >>expected &&
	echo "two looper" >>expected &&
	echo "dupe looper" >>expected &&
	<<-EOT dotgdeps -v rev=1 -v withbr=1 >actual &&
		$dupe32 t/check
		$looperduper looper
	EOT
	test_cmp actual expected
'

test_expect_success 'exclbr other' '
	for b in one two three four five six seven eight nine ten; do
		echo "t/excl $b"
	done >expected &&
	echo "$tens t/excl" | dotgdeps -v exclbr="other" >actual &&
	test_cmp actual expected
'

test_expect_success 'exclbr even' '
	for b in one three five seven nine; do
		echo "t/excl $b"
	done >expected &&
	echo "$tens t/excl" |
	dotgdeps -v exclbr="two four six eight ten" >actual &&
	test_cmp actual expected
'

test_expect_success 'exclbr odd' '
	for b in two four six eight ten; do
		echo "t/excl $b"
	done >expected &&
	echo "$tens t/excl" |
	dotgdeps -v exclbr="one three five seven nine" >actual &&
	test_cmp actual expected
'

test_expect_success 'exclbr primes' '
	for b in one four six eight nine ten; do
		echo "t/excl $b"
	done >expected &&
	echo "$tens t/excl" |
	dotgdeps -v exclbr="two three five seven" >actual &&
	test_cmp actual expected
'

test_expect_success 'inclbr other' '
	>expected &&
	echo "$tens t/excl" | dotgdeps -v inclbr="other" >actual &&
	test_cmp actual expected
'

test_expect_success 'inclbr even' '
	for b in two four six eight ten; do
		echo "t/excl $b"
	done >expected &&
	echo "$tens t/excl" |
	dotgdeps -v inclbr="two four six eight ten" >actual &&
	test_cmp actual expected
'

test_expect_success 'inclbr odd' '
	for b in one three five seven nine; do
		echo "t/excl $b"
	done >expected &&
	echo "$tens t/excl" |
	dotgdeps -v inclbr="one three five seven nine" >actual &&
	test_cmp actual expected
'

test_expect_success 'inclbr primes' '
	for b in two three five seven; do
		echo "t/excl $b"
	done >expected &&
	echo "$tens t/excl" |
	dotgdeps -v inclbr="two three five seven" >actual &&
	test_cmp actual expected
'

test_expect_success 'inclbr odd exclbr primes' '
	echo "t/incexc one" >expected &&
	echo "t/incexc nine" >>expected &&
	echo "t/excinc one" >>expected &&
	echo "t/excinc nine" >>expected &&
	<<-EOT dotgdeps -v inclbr="one three five seven nine" \
		-v exclbr="two three five seven" >actual &&
		$tens t/incexc
		$tens t/excinc
	EOT
	test_cmp actual expected
'

test_expect_success 'exclbr even inclbr primes rev withbr' '
	echo "seven t/excinc" >expected &&
	echo "five t/excinc" >>expected &&
	echo "three t/excinc" >>expected &&
	echo "t/incexc t/incexc" >>expected &&
	echo "nine t/incexc" >>expected &&
	echo "seven t/incexc" >>expected &&
	echo "five t/incexc" >>expected &&
	echo "three t/incexc" >>expected &&
	echo "one t/incexc" >>expected &&
	<<-EOT dotgdeps -v rev=1 -v withbr=1 \
		-v exclbr="two four six eight ten" \
		-v inclbr="two three t/incexc five seven" >actual &&
		$tens t/excinc
		$tens t/incexc
	EOT
	test_cmp actual expected
'

test_expect_success 'exclbr branch deps inclbr rev' '
	echo "seven t/second" >expected &&
	<<-EOT dotgdeps -v rev=1 -v exclbr=t/first -v inclbr=seven >actual &&
		$tens t/first
		$tens t/second
	EOT
	test_cmp actual expected
'

test_expect_success 'anfile works' '
	echo "t/top dep1" >expected &&
	echo "t/top dep2" >>expected &&
	echo "t/top t/top" >>expected &&
	echo "dep1 dep1" >>expected &&
	echo "dep2 dep2" >>expected &&
	echo "dep1" >anfile &&
	<<-EOT dotgdeps -v withbr=1 >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected &&
	<<-EOT dotgdeps -v withbr=1 -v withan=1 -v anfile=anfile >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected &&
	echo "t/top dep2" >expected &&
	echo "t/top t/top" >>expected &&
	echo "dep2 dep2" >>expected &&
	<<-EOT dotgdeps -v withbr=1 -v anfile=anfile >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected &&
	echo "t/top dep1" >expected &&
	echo "t/top dep2" >>expected &&
	<<-EOT dotgdeps >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected &&
	<<-EOT dotgdeps -v withan=1 -v anfile=anfile >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected &&
	echo "t/top dep2" >expected &&
	<<-EOT dotgdeps -v anfile=anfile >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected
'

test_expect_success 'brfile works' '
	echo "t/top dep1" >expected &&
	echo "t/top dep2" >>expected &&
	echo "t/top t/top" >>expected &&
	echo "dep1 dep1" >>expected &&
	echo "dep2 dep2" >>expected &&
	echo "t/top" >brfile &&
	<<-EOT dotgdeps -v withbr=1 >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected &&
	<<-EOT dotgdeps -v withbr=1 -v brfile=brfile >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected &&
	echo "t/top t/top" >expected &&
	<<-EOT dotgdeps -v withbr=1 -v brfile=brfile -v tgonly=1 >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected &&
	echo "t/top dep1" >expected &&
	echo "t/top dep2" >>expected &&
	<<-EOT dotgdeps >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected &&
	<<-EOT dotgdeps -v brfile=brfile >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected &&
	>expected &&
	<<-EOT dotgdeps -v brfile=brfile -v tgonly=1 >actual &&
		$deps t/top
		$mtblob dep1
		$mtblob dep2
	EOT
	test_cmp actual expected
'

test_expect_success 'anfile + brfile works' '
	<<-EOT cat >input &&
		$dupe32 t/top
		$deps dupe
		$alts two
		$mtblob dep1
		$mtblob dep2
		$mtblob alt1
		$mtblob alt2
	EOT
	echo "dep1" >anfl &&
	echo "alt2" >>anfl &&
	echo "t/top" >brfl &&
	echo "dupe" >>brfl &&
	echo "two" >>brfl &&
	echo "alt2" >>brfl &&
	<<-EOT cat >expected &&
		t/top dupe
		t/top two
		t/top t/top
		dupe dep1
		dupe dep2
		dupe dupe
		two alt1
		two alt2
		two two
		dep1 dep1
		dep2 dep2
		alt1 alt1
		alt2 alt2
	EOT
	<input dotgdeps -v withbr=1 >actual &&
	test_cmp actual expected &&
	<input dotgdeps -v withbr=1 -v brfile=brfl >actual &&
	test_cmp actual expected &&
	<input dotgdeps -v withbr=1 -v anfile=anfl -v withan=1 >actual &&
	test_cmp actual expected &&
	<input dotgdeps -v withbr=1 -v brfile=brfl -v anfile=anfl -v withan=1 >actual &&
	test_cmp actual expected &&
	<<-EOT cat >expected &&
		t/top dupe
		t/top two
		t/top t/top
		dupe dupe
		two alt2
		two two
		alt2 alt2
	EOT
	<input dotgdeps -v withbr=1 -v brfile=brfl -v tgonly=1 >actual &&
	test_cmp actual expected &&
	<input dotgdeps -v withbr=1 -v brfile=brfl -v anfile=anfl -v withan=1 -v tgonly=1 >actual &&
	test_cmp actual expected &&
	<<-EOT cat >expected &&
		t/top dupe
		t/top two
		t/top t/top
		dupe dep2
		dupe dupe
		two alt1
		two two
		dep2 dep2
		alt1 alt1
	EOT
	<input dotgdeps -v withbr=1 -v anfile=anfl >actual &&
	test_cmp actual expected &&
	<input dotgdeps -v withbr=1 -v brfile=brfl -v anfile=anfl >actual &&
	test_cmp actual expected &&
	<<-EOT cat >expected &&
		t/top dupe
		t/top two
		t/top t/top
		dupe dupe
		two two
	EOT
	<input dotgdeps -v withbr=1 -v brfile=brfl -v anfile=anfl -v tgonly=1 >actual &&
	test_cmp actual expected &&

	# again but now without withbr=1

	<<-EOT cat >expected &&
		t/top dupe
		t/top two
		dupe dep1
		dupe dep2
		two alt1
		two alt2
	EOT
	<input dotgdeps >actual &&
	test_cmp actual expected &&
	<input dotgdeps -v brfile=brfl >actual &&
	test_cmp actual expected &&
	<input dotgdeps -v anfile=anfl -v withan=1 >actual &&
	test_cmp actual expected &&
	<input dotgdeps -v brfile=brfl -v anfile=anfl -v withan=1 >actual &&
	test_cmp actual expected &&
	<<-EOT cat >expected &&
		t/top dupe
		t/top two
		two alt2
	EOT
	<input dotgdeps -v brfile=brfl -v tgonly=1 >actual &&
	test_cmp actual expected &&
	<input dotgdeps -v brfile=brfl -v anfile=anfl -v withan=1 -v tgonly=1 >actual &&
	test_cmp actual expected &&
	<<-EOT cat >expected &&
		t/top dupe
		t/top two
		dupe dep2
		two alt1
	EOT
	<input dotgdeps -v anfile=anfl >actual &&
	test_cmp actual expected &&
	<input dotgdeps -v brfile=brfl -v anfile=anfl >actual &&
	test_cmp actual expected &&
	<<-EOT cat >expected &&
		t/top dupe
		t/top two
	EOT
	<input dotgdeps -v brfile=brfl -v anfile=anfl -v tgonly=1 >actual &&
	test_cmp actual expected
'

test_done
