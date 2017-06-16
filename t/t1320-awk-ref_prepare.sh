#!/bin/sh

test_description='ref_prepare.awk functionality'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

ap="$(tg --awk-path)" && test -n "$ap" && test -d "$ap" || die
aprp="$ap/ref_prepare"
test -f "$aprp" && test -r "$aprp" && test -x "$aprp" || die

test_plan 20

test_expect_success 'ref_prepare runs' '
	# some stupid awks might not even compile it
	awk -v topbases="a" -v headbase="b" -f "$aprp" </dev/null
'

test_expect_success 'ref_prepare bad usage' '
	exec </dev/null &&
	test_must_fail awk -f "$aprp" &&
	test_must_fail awk -v topbases="bad" -f "$aprp" &&
	test_must_fail awk -v topbases="bad" -f "$aprp" &&
	test_must_fail awk -v topbases="/" -v headbase="x" -f "$aprp" &&
	test_must_fail awk -v topbases="a" -v headbase="/" -f "$aprp"
'

test_expect_success 'leaves refs file alone' '
	echo notouchy > list &&
	awk -v topbases="refs" -v refsfile="list" -f "$aprp" </dev/null &&
	test z"$(cat list)" = z"notouchy"
'

test_expect_success 'leaves refs file alone without rmrf' '
	echo notouchy > list &&
	awk -v topbases="refs" -v refsfile="list" -f "$aprp" </dev/null &&
	awk -v topbases="refs" -v refsfile="list" -v rmrf=0 -f "$aprp" </dev/null &&
	test z"$(cat list)" = z"notouchy"
'

test_expect_success 'refs file removed on request' '
	echo notouchy > list &&
	echo hi | awk -v topbases="refs" -v refsfile="list" -v rmrf=1 -f "$aprp" &&
	test ! -e list
'

test_expect_success 'removes refs file on request even if not read' '
	echo notouchy > list &&
	awk -v topbases="refs" -v refsfile="list" -v rmrf=1 -f "$aprp" </dev/null &&
	test ! -e list
'

test_expect_success 'only bases recognized' '
	printf "%s" "\
b/3 3 :
b/3^0
h/3^0
b/3^{tree}
h/3^{tree}
b/0 0 :
b/0^0
h/0^0
b/0^{tree}
h/0^{tree}
" > expected &&
	printf "%s\n" h/1 h/2 b b/ b/3 c/4 b/0 |
	awk -v topbases=b -v headbase=h -f "$aprp" > actual &&
	test_diff expected actual
'

test_expect_success 'chkblob on request' '
	printf "%s" "\
0666^{blob} check ?
b/3 3 :
b/3^0
h/3^0
b/3^{tree}
h/3^{tree}
" > expected &&
	printf "%s\n" h/1 h/2 b b/ b/3 c/4 |
	awk -v topbases=b -v headbase=h -v chkblob=0666 -f "$aprp" > actual &&
	test_diff expected actual
'

test_expect_success 'depsblob on request' '
	printf "%s" "\
b/3 3 :
b/3^0
h/3^0
b/3^{tree}
h/3^{tree}
h/3^{tree}:.topdeps
" > expected &&
	printf "%s\n" h/1 h/2 b b/ b/3 c/4 |
	awk -v topbases=b -v headbase=h -v depsblob=1 -f "$aprp" > actual &&
	test_diff expected actual
'

test_expect_success 'msgblob on request' '
	printf "%s" "\
b/3 3 :
b/3^0
h/3^0
b/3^{tree}
h/3^{tree}
h/3^{tree}:.topmsg
" > expected &&
	printf "%s\n" h/1 h/2 b b/ b/3 c/4 |
	awk -v topbases=b -v headbase=h -v msgblob=1 -f "$aprp" > actual &&
	test_diff expected actual
'

test_expect_success 'both .top blobs on request' '
	printf "%s" "\
b/3 3 :
b/3^0
h/3^0
b/3^{tree}
h/3^{tree}
h/3^{tree}:.topdeps
h/3^{tree}:.topmsg
" > expected &&
	printf "%s\n" h/1 h/2 b b/ b/3 c/4 |
	awk -v topbases=b -v headbase=h -v msgblob=1 -v depsblob=1 -f "$aprp" > actual &&
	test_diff expected actual
'

test_expect_success 'all blobs on request' '
	printf "%s" "\
0666^{blob} check ?
b/3 3 :
b/3^0
h/3^0
b/3^{tree}
h/3^{tree}
h/3^{tree}:.topdeps
h/3^{tree}:.topmsg
" > expected &&
	printf "%s\n" h/1 h/2 b b/ b/3 c/4 |
	awk -v topbases=b -v headbase=h -v chkblob=0666 -v msgblob=1 -v depsblob=1 -f "$aprp" > actual &&
	test_diff expected actual
'

test_expect_success 'sensible default headbase' '
	printf "%s\n" refs/tb/1/2/3 |
	awk -v topbases=refs/tb -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/heads/1/2/3^0" &&
	printf "%s\n" refs/tb/1/2/3 |
	awk -v topbases=refs/tb/1 -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/heads/2/3^0" &&
	printf "%s\n" refs/tb/1/2/3 |
	awk -v topbases=refs/tb/1/2 -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/heads/3^0"
'

test_expect_success 'non-remote remote has no default headbase' '
	exec </dev/null &&
	test_must_fail awk -v topbases=refs/remotes/tb -f "$aprp" &&
	test_must_fail awk -v topbases=refs/remotes -f "$aprp"
'

test_expect_success 'single-level remote names default okay' '
	printf "%s\n" refs/remotes/o/tb/3 |
	awk -v topbases=refs/remotes/o/tb -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/remotes/o/3^0" &&
	printf "%s\n" refs/remotes/longer/tb/3 |
	awk -v topbases=refs/remotes/longer/tb -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/remotes/longer/3^0" &&
	printf "%s\n" refs/remotes/o/tb/3/4 |
	awk -v topbases=refs/remotes/o/tb -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/remotes/o/3/4^0" &&
	printf "%s\n" refs/remotes/longer/tb/3/4/5 |
	awk -v topbases=refs/remotes/longer/tb -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/remotes/longer/3/4/5^0" &&
	printf "%s\n" refs/remotes/longer/tb/not/bad |
	awk -v topbases=refs/remotes/longer/tb -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/remotes/longer/not/bad^0"
'

test_expect_success 'multi-level remote names default okay' '
	printf "%s\n" refs/remotes/o/there/tb/3 |
	awk -v topbases=refs/remotes/o/there/tb -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/remotes/o/there/3^0" &&
	printf "%s\n" refs/remotes/o/there/tb/3/4/5 |
	awk -v topbases=refs/remotes/o/there/tb -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/remotes/o/there/3/4/5^0" &&
	printf "%s\n" refs/remotes/o/there/somewhere/tb/3 |
	awk -v topbases=refs/remotes/o/there/somewhere/tb -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/remotes/o/there/somewhere/3^0" &&
	printf "%s\n" refs/remotes/o/there/somewhere/tb/3/4 |
	awk -v topbases=refs/remotes/o/there/somewhere/tb -f "$aprp" >actual &&
	h="$(sed -n 3p <actual)" &&
	test z"$h" = z"refs/remotes/o/there/somewhere/3/4^0"
'

test_expect_success 'teeout copy works' '
	printf "%s" "\
b/3 3 :
b/3^0
h/3^0
b/3^{tree}
h/3^{tree}
h/3^{tree}:.topdeps
h/3^{tree}:.topmsg
b/0 0 :
b/0^0
h/0^0
b/0^{tree}
h/0^{tree}
h/0^{tree}:.topdeps
h/0^{tree}:.topmsg
" > expected &&
	printf "%s\n" h/1 h/2 b b/ b/3 c/4 b/0 |
	awk -v topbases=b -v headbase=h -v depsblob=1 -v msgblob=1 -v teeout=copy -f "$aprp" > actual &&
	test_diff expected actual &&
	test_diff expected copy
'

test_expect_success 'teeout copy works on substs' '
	printf "%s" "\
b/3 3 :
b/3^0
h/3^0
b/3^{tree}
h/3^{tree}
1234^{blob}
h/3^{tree}:.topmsg
b/0 0 :
b/0^0
h/0^0
b/0^{tree}
h/0^{tree}
h/0^{tree}:.topdeps
4321^{blob}
" > expected &&
	printf "%s\n" h/1 h/2 b b/ b/3 c/4 b/0 |
	awk -v topbases=b -v headbase=h -v depsblob=1 -v msgblob=1 -v teeout=copy \
	  -v topdeps=3:1234 -v topmsg=0:4321 -f "$aprp" > actual &&
	test_diff expected actual &&
	test_diff expected copy
'

test_expect_success 'teeout copy works on substs with refsfile' '
	printf "%s" "\
refs/b/3 b333
refs/h/3 f333 just junk here
refs/h/0 f000
refs/b/0 b000
" > refslist &&
	printf "%s" "\
b333 3 :
b333^0
f333^0
b333^{tree}
f333^{tree}
1234^{blob}
f333^{tree}:.topmsg
? not :
?^0
?^0
?^{tree}
?^{tree}
?^{tree}:.topdeps
?^{tree}:.topmsg
b000 0 :
b000^0
f000^0
b000^{tree}
f000^{tree}
f000^{tree}:.topdeps
4321^{blob}
" > expected &&
	printf "%s\n" refs/h/1 refs/h/2 refs/b refs/b/ refs/b/3 refs/b/not refs/c/4 refs/b/0 |
	awk -v topbases=refs/b -v headbase=refs/h -v depsblob=1 -v msgblob=1 -v teeout=copy \
	  -v topdeps=3:1234 -v topmsg=0:4321 -v refsfile=refslist -f "$aprp" > actual &&
	test_diff expected actual &&
	test_diff expected copy
'

test_expect_success 'teeout copy works on substs with pckdrefs refsfile' '
	printf "%s" "\
b333 refs/b/3
f333 refs/h/3 just junk here
f000 refs/h/0
b000 refs/b/0
" > refslist &&
	printf "%s" "\
b333 3 :
b333^0
f333^0
b333^{tree}
f333^{tree}
1234^{blob}
f333^{tree}:.topmsg
? not :
?^0
?^0
?^{tree}
?^{tree}
?^{tree}:.topdeps
?^{tree}:.topmsg
b000 0 :
b000^0
f000^0
b000^{tree}
f000^{tree}
f000^{tree}:.topdeps
4321^{blob}
" > expected &&
	printf "%s\n" refs/h/1 refs/h/2 refs/b refs/b/ refs/b/3 refs/b/not refs/c/4 refs/b/0 |
	awk -v topbases=refs/b -v headbase=refs/h -v depsblob=1 -v msgblob=1 -v teeout=copy \
	  -v topdeps=3:1234 -v topmsg=0:4321 -v refsfile=refslist -v pckdrefs=1 -f "$aprp" > actual &&
	test_diff expected actual &&
	test_diff expected copy
'

test_done
