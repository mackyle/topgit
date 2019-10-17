#!/bin/sh

test_description='topgit_navigate.awk functionality'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

ap="$(tg --awk-path)" && test -n "$ap" && test -d "$ap" || die
aptn="$ap/topgit_navigate"
test -f "$aptn" && test -r "$aptn" && test -x "$aptn" || die

# Final output of topgit_deps looks like:
#
# t/top t/sub1
# t/top t/sub2
# t/top t/top   (only when withbr=1)
#
# In other words, the output from topgit_deps is simply
# a list of TopGit Directed Acyclic Graph edges pointing
# from the branch name in the first field (via its .topdeps
# file) to the branch name in the second field.
#
# Of course, if the rev=1 was passed to topgit_deps it's
# all output backwards, but that's really irrelevant to
# the testing performed by this test.

test_plan 37

# first arg is passed as `-v startb="$1"`
tgnav_() { awk -f "$aptn" "$@"; }
tgnav() { tgnav_ -v startb="$@"; }
tgnavmt() { tgnav none -v steps=0 "$@"; }

test_expect_success 'topgit_navigate runs' '
	# some stupid awks might not even compile it
	>expected &&
	awk -f "$aptn" -v steps=0 -v startb="none" </dev/null >actual &&
	test_cmp actual expected &&
	# and make sure the helper works too
	</dev/null tgnavmt >actual &&
	test_cmp actual expected
'

test_expect_success 'invalid brfile fails if read' '
        rm -f no-such-file &&
        test ! -e no-such-file &&
        >expected &&
        </dev/null tgnavmt -v brfile=no-such-file >actual &&
        test_cmp actual expected &&
        echo "..." | tgnavmt -v brfile=no-such-file >actual &&
        test_cmp actual expected &&
        </dev/null tgnavmt -v tgonly=1 -v brfile=no-such-file >actual &&
        test_cmp actual expected &&
        echo "..." | test_must_fail tgnavmt -v tgonly=1 -v brfile=no-such-file >actual &&
        test_cmp actual expected &&
        test ! -e no-such-file
'

test_expect_success 'invalid anfile fails if read' '
        rm -f no-such-file &&
        test ! -e no-such-file &&
        >expected &&
        </dev/null tgnavmt -v withan=1 -v anfile=no-such-file >actual &&
        test_cmp actual expected &&
        echo "..." | test_must_fail tgnavmt -v withan=1 -v anfile=no-such-file >actual &&
        test_cmp actual expected &&
        </dev/null tgnavmt -v anfile=no-such-file >actual &&
        test_cmp actual expected &&
        echo "..." | test_must_fail tgnavmt -v anfile=no-such-file >actual &&
        test_cmp actual expected &&
        test ! -e no-such-file
'

test_expect_success 'brfile unperturbed without rmbr' '
        echo "br file here" >brorig &&
        cat brorig >brfile &&
        >expected &&
        </dev/null tgnavmt -v brfile=brfile >actual &&
        test_cmp actual expected &&
        test_cmp brfile brorig &&
        echo "..." | tgnavmt -v brfile=brfile >actual &&
        test_cmp actual expected &&
        test_cmp brfile brorig &&
        </dev/null tgnavmt -v tgonly=1 -v brfile=brfile >actual &&
        test_cmp actual expected &&
        test_cmp brfile brorig &&
        echo "..." | tgnavmt -v tgonly=1 -v brfile=brfile >actual &&
        test_cmp actual expected &&
        test_cmp brfile brorig
'

test_expect_success 'anfile unperturbed without rman' '
        echo "an file here" >anorig &&
        cat anorig >anfile &&
        >expected &&
        </dev/null tgnavmt -v withan=1 -v anfile=anfile >actual &&
        test_cmp actual expected &&
        test_cmp anfile anorig &&
        echo "..." | tgnavmt -v withan=1 -v anfile=anfile >actual &&
        test_cmp actual expected &&
        test_cmp anfile anorig &&
        </dev/null tgnavmt -v anfile=anfile >actual &&
        test_cmp actual expected &&
        test_cmp anfile anorig &&
        echo "..." | tgnavmt -v anfile=anfile >actual &&
        test_cmp actual expected &&
        test_cmp anfile anorig
'

test_expect_success 'brfile removed with rmbr' '
        echo "br file here" >brorig &&
        cat brorig >brfile &&
        >expected &&
        </dev/null tgnavmt -v brfile=brfile -v rmbr=1 >actual &&
        test_cmp actual expected &&
        test ! -e brfile &&
        cat brorig >brfile &&
        echo "..." | tgnavmt -v brfile=brfile -v rmbr=1 >actual &&
        test_cmp actual expected &&
        test ! -e brfile &&
        cat brorig >brfile &&
        </dev/null tgnavmt -v tgonly=1 -v brfile=brfile -v rmbr=1 >actual &&
        test_cmp actual expected &&
        test ! -e brfile &&
        cat brorig >brfile &&
        echo "..." | tgnavmt -v tgonly=1 -v brfile=brfile -v rmbr=1 >actual &&
        test_cmp actual expected &&
        test ! -e brfile
'

test_expect_success 'anfile removed with rman' '
        echo "an file here" >anorig &&
        cat anorig >anfile &&
        >expected &&
        </dev/null tgnavmt -v withan=1 -v anfile=anfile -v rman=1 >actual &&
        test_cmp actual expected &&
        test ! -e anfile &&
        cat anorig >anfile &&
        echo "..." | tgnavmt -v withan=1 -v anfile=anfile -v rman=1 >actual &&
        test_cmp actual expected &&
        test ! -e anfile &&
        cat anorig >anfile &&
        </dev/null tgnavmt -v anfile=anfile -v rman=1 >actual &&
        test_cmp actual expected &&
        test ! -e anfile &&
        cat anorig >anfile &&
        echo "..." | tgnavmt -v anfile=anfile -v rman=1 >actual &&
        test_cmp actual expected &&
        test ! -e anfile
'

test_expect_success 'brfile works' '
	printf "%s\n" "last" >brlist &&
	printf "%s\n" "last mid" "mid first" >graph &&
	echo "mid last" >expected &&
	<graph tgnav "first" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "first" -v steps=1 -v brfile=brlist >actual &&
	test_cmp actual expected &&
	echo "last last" >expected &&
	<graph tgnav "first" -v steps=1 -v brfile=brlist -v tgonly=1 >actual &&
	test_cmp actual expected &&
	echo "first last" >expected &&
	<graph tgnav "first" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph tgnav "first" -v steps=0 -v brfile=brlist >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "first" -v steps=0 -v brfile=brlist -v tgonly=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "first" -v steps=0 -v tgonly=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'anfile works' '
	printf "%s\n" "mid1b" >anlist &&
	cat <<-EOT >graph &&
		top mid1
		mid1 mid1a
		mid1 mid1b
		mid1 mid1c
	EOT
	echo "mid1b top" >expected &&
	<graph tgnav "mid1a" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "mid1a" -v steps=1 -v anfile=anlist -v withan=1 >actual &&
	test_cmp actual expected &&
	echo "mid1c top" >expected &&
	<graph tgnav "mid1a" -v steps=1 -v anfile=anlist >actual &&
	test_cmp actual expected &&
	echo "mid1b top" >expected &&
	<graph tgnav "mid1b" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph tgnav "mid1b" -v steps=0 -v anfile=anlist -v withan=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "mid1b" -v steps=0 -v withan=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "mid1b" -v steps=0 -v anfile=anlist >actual &&
	test_cmp actual expected
'

test_expect_success 'anfile works redux' '
	printf "%s\n" "mid1" >anlist &&
	cat <<-EOT >graph &&
		top mid1
		mid1 mid1a
		mid1 mid1b
		mid1 mid1c
	EOT
	echo "mid1b top" >expected &&
	<graph tgnav "mid1b" -v steps=0 >actual &&
	test_cmp actual expected &&
	echo "mid1c top" >expected &&
	<graph tgnav "mid1b" -v steps=1 >actual &&
	test_cmp actual expected &&
	echo "mid1c mid1c" >expected &&
	<graph tgnav "mid1c" -v steps=1 -v pin=1 -v anfile=anlist >actual &&
	test_cmp actual expected &&
	<graph tgnav "mid1c" -v steps=1 -v pin=1 -v anfile=anlist -v withan=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'brfile + anfile works' '
	printf "%s\n" "top" "mid1" "mid2" >brlist &&
	printf "%s\n" "mid1" "mid2b" >anlist &&
	cat <<-EOT >graph &&
		top mid1
		top mid2
		mid1 mid1a
		mid1 mid1b
		mid1 mid1c
		mid2 mid2a
		mid2 mid2b
		mid2 mid2c
	EOT
	echo "mid2b top" >expected &&
	<graph tgnav "mid1b" -v steps=4 >actual &&
	test_cmp actual expected &&
	<graph tgnav "mid1b" -v steps=4 -v brfile=brlist >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "mid1b" -v steps=4 -v tgonly=1 >actual &&
	test_cmp actual expected &&
	echo "mid2 top" >expected &&
	<graph tgnav "mid1b" -v steps=2 -v brfile=brlist -v tgonly=1 >actual &&
	test_cmp actual expected &&
	echo "mid1b top" >expected &&
	<graph tgnav "mid2b" -v steps=4 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo "mid2b top" >expected &&
	<graph tgnav "mid2b" -v steps=0 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "mid2b" -v steps=0 -v rev=1 -v withan=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "mid2b" -v steps=0 -v rev=1 -v anfile=anlist -v withan=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "mid2b" -v steps=0 -v rev=1 -v anfile=anlist >actual &&
	test_cmp actual expected &&
	echo "mid2a top" >expected &&
	<graph tgnav "mid2c" -v steps=1 -v rev=1 -v anfile=anlist >actual &&
	test_cmp actual expected &&
	echo "mid1 top" >expected &&
	<graph tgnav "mid2c" -v steps=3 -v rev=1 -v withan=1 -v anfile=anlist >actual &&
	test_cmp actual expected &&
	echo "mid2b top" >expected &&
	<graph tgnav "top" -v steps=3 -v rev=1 -v anfile=anlist -v withan=1 -v brfile=brlist >actual &&
	test_cmp actual expected &&
	echo "mid2a top" >expected &&
	<graph tgnav "top" -v steps=3 -v rev=1 -v anfile=anlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	echo "mid1 top" >expected &&
	<graph tgnav "top" -v steps=2 -v rev=1 -v anfile=anlist -v withan=1 -v brfile=brlist -v tgonly=1 >actual &&
	test_cmp actual expected &&
	echo "mid2 top" >expected &&
	<graph tgnav "top" -v steps=1 -v rev=1 -v anfile=anlist -v brfile=brlist -v tgonly=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'tgonly works' '
	printf "%s\n" top mid1 mid1b mid2 mid2c >brlist &&
	cat <<-EOT >graph &&
		top mid1
		top mid2
		mid1 mid1a
		mid1 mid1b
		mid1 mid1c
		mid2 mid2a
		mid2 mid2b
		mid2 mid2c
	EOT
	printf "%s\n" mid1a mid1b mid1c mid2a mid2b mid2c >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "" -v steps=1 -v tgonly=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" mid1b mid2c >expected &&
	<graph tgnav "" -v steps=1 -v brfile=brlist -v tgonly=1 >actual &&
	test_cmp actual expected &&
	echo top >expected &&
	<graph tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "" -v steps=-1 -v tgonly=1 >actual &&
	test_cmp actual expected &&
	echo top >expected &&
	<graph tgnav "" -v steps=-1 -v brfile=brlist -v tgonly=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'withan works' '
	printf "%s\n" mid1 mid1c mid2a mid2b >anlist &&
	cat <<-EOT >graph &&
		top mid1
		top mid2
		mid1 mid1a
		mid1 mid1b
		mid1 mid1c
		mid2 mid2a
		mid2 mid2b
		mid2 mid2c
	EOT
	printf "%s\n" mid1a mid1b mid1c mid2a mid2b mid2c >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v withan=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v withan=1 -v anfile=anlist >actual &&
	printf "%s\n" mid1 mid1a mid1b mid1c mid2a mid2b mid2c >expected &&
	test_cmp actual expected &&
	printf "%s\n" mid1a mid1b mid2c >expected &&
	<graph tgnav "" -v steps=1 -v withan=0 -v anfile=anlist >actual &&
	test_cmp actual expected &&
	echo top >expected &&
	<graph tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=-1 -v withan=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" top mid1a mid1b mid1c >expected &&
	<graph tgnav "" -v steps=-1 -v withan=1 -v anfile=anlist >actual &&
	test_cmp actual expected &&
	printf "%s\n" top mid1a mid1b >expected &&
	<graph tgnav "" -v steps=-1 -v withan=0 -v anfile=anlist >actual &&
	test_cmp actual expected
'

test_expect_success 'integer steps only' '
	echo "a b" >graph &&
	echo "a a" >expected &&
	<graph tgnav "a" -v steps=0 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph test_must_fail tgnav "a" -v steps="" >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "" -v steps="" >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps="-1.0" >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps="1.0" >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps="1." >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps=".0" >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps="." >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps="1/2" >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps=" 1" >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps=" -1" >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps="1 " >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps="-1 " >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps=" 1 " >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "a" -v steps=" -1 " >actual &&
	test_cmp actual expected &&
	echo "a a" >expected &&
	<graph tgnav "a" -v steps="-1" >actual &&
	test_cmp actual expected &&
	<graph tgnav "a" -v steps="-2" >actual &&
	test_cmp actual expected &&
	<graph tgnav "a" -v steps="-9999" >actual &&
	test_cmp actual expected &&
	<graph tgnav "b" -v steps="1" >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "b" -v steps="2" >actual &&
	test_cmp actual expected &&
	<graph tgnav "b" -v steps="3" >actual &&
	test_cmp actual expected &&
	<graph tgnav "b" -v steps="99" >actual &&
	test_cmp actual expected &&
	<graph tgnav "b" -v steps="9999" >actual &&
	test_cmp actual expected
'

test_expect_success 'zero steps requires non-empty start' '
	printf "%s\n" "a b" "c d" >graph &&
	echo "a a" >expected &&
	<graph tgnav "a" -v steps=0 >actual &&
	test_cmp actual expected &&
	echo "b a" >expected &&
	<graph tgnav "b" -v steps=0 >actual &&
	test_cmp actual expected &&
	echo "c c" >expected &&
	<graph tgnav "c" -v steps=0 >actual &&
	test_cmp actual expected &&
	echo "d c" >expected &&
	<graph tgnav "d" -v steps=0 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph test_must_fail tgnav "" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "" -v steps=0 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "" -v steps=0 -v pin=1 >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "" -v steps=0 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav " " -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav "  " -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph test_must_fail tgnav " 	 " -v steps=0 >actual &&
	test_cmp actual expected
'

test_expect_success 'zero steps works' '
	cat <<-EOT >graph &&
		a b
		b c
		b w
		b d
		c e
		m n
		m p
		m w
		w z
	EOT
	echo "e a" >expected &&
	<graph tgnav "e" -v steps=0 >actual &&
	test_cmp actual expected &&
	echo "p m" >expected &&
	<graph tgnav "p" -v steps=0 >actual &&
	test_cmp actual expected &&
	echo "w a m" >expected &&
	<graph tgnav "w" -v steps=0 >actual &&
	test_cmp actual expected &&
	echo "z a m" >expected &&
	<graph tgnav "z" -v steps=0 >actual &&
	test_cmp actual expected &&
	echo "w" >anlist &&
	echo "z z" >expected &&
	<graph tgnav "z" -v steps=0 -v anfile=anlist >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "w" -v steps=0 -v anfile=anlist >actual &&
	test_cmp actual expected &&
	echo "w a m" >expected &&
	<graph tgnav "w" -v steps=0 -v anfile=anlist -v withan=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" w a m >brlist &&
	<graph tgnav "w" -v steps=0 -v brfile=brlist -v tgonly=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" w a m >brlist &&
	echo "z a m" >expected &&
	<graph tgnav "z" -v steps=0 -v brfile=brlist -v tgonly=0 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "z" -v steps=0 -v brfile=brlist -v tgonly=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'step nil to heads' '
	cat <<-EOT >graph &&
		a b
		b c
		d e
		e f
		f x
		g h
		h x
	EOT
	printf "%s\n" a d g >expected &&
	<graph tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo b >anlist &&
	printf "%s\n" a c d g >expected &&
	<graph tgnav "" -v steps=1 -v rev=1 -v anfile=anlist >actual &&
	test_cmp actual expected &&
	echo d >anlist &&
	<graph tgnav "" -v steps=1 -v rev=1 -v anfile=anlist >actual &&
	printf "%s\n" a e g >expected &&
	test_cmp actual expected &&
	printf "%s\n" a e d g >expected &&
	<graph tgnav "" -v steps=1 -v rev=1 -v anfile=anlist -v withan=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "" -v steps=-1 -v tgonly=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" a g >brlist &&
	printf "%s\n" a g >expected &&
	<graph tgnav "" -v steps=-1 -v tgonly=1 -v brfile=brlist >actual &&
	test_cmp actual expected
'

test_expect_success 'step nil to roots' '
	cat <<-EOT >graph &&
		a b
		b c
		d e
		e f
		f x
		g h
		h x
	EOT
	printf "%s\n" c x >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=-1 -v rev=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" a b d e f g h >brlist &&
	>expected &&
	<graph tgnav "" -v steps=1 -v tgonly=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v tgonly=1 -v brfile=brlist >actual &&
	test_cmp actual expected &&
	echo x >>brlist &&
	echo x >expected &&
	<graph tgnav "" -v steps=1 -v tgonly=1 -v brfile=brlist >actual &&
	test_cmp actual expected &&
	echo f >anlist &&
	printf "%s\n" c f x >expected &&
	<graph tgnav "" -v steps=1 -v anfile=anlist -v withan=1 >actual &&
	test_cmp actual expected &&
	echo x >anlist &&
	echo c >expected &&
	<graph tgnav "" -v steps=1 -v anfile=anlist -v xwithan=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'step nil to firsts' '
	cat <<-EOT >graph &&
		e a
		e b
		e c
		e d
		i f
		i g
		i h
	EOT
	printf "%s\n" a b c d f g h >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" a f >expected &&
	<graph tgnav "" -v steps=-1 -v rev=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'step forward' '
	cat <<-EOT >graph &&
		a b
		b c
		r s
		s t
		t b
		w x
		x b
	EOT
	echo "b a r w" >expected &&
	<graph tgnav "c" -v steps=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		a a
		t r
		x w
	EOT
	<graph tgnav "c" -v steps=2 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		s r
		w w
	EOT
	<graph tgnav "c" -v steps=3 >actual &&
	test_cmp actual expected &&
	echo "r r" >expected &&
	<graph tgnav "c" -v steps=4 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "c" -v steps=5 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		a a
		r r
		w w
	EOT
	<graph tgnav "c" -v steps=-1 >actual &&
	test_cmp actual expected
'

test_expect_success 'step backward' '
	cat <<-EOT >graph &&
		a b
		b c
		r s
		s b
		w x
		x y
		y b
	EOT
	echo "b a" >expected &&
	<graph tgnav "a" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo "c a" >expected &&
	<graph tgnav "a" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "a" -v steps=-1 -v rev=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "a" -v steps=3 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo "c a r w" >expected &&
	<graph tgnav "b" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "b" -v steps=-1 -v rev=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "b" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	###
	echo "s r" >expected &&
	<graph tgnav "r" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo "b r" >expected &&
	<graph tgnav "r" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "s" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo "c r" >expected &&
	<graph tgnav "r" -v steps=3 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "s" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "r" -v steps=-1 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "s" -v steps=-1 -v rev=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "r" -v steps=4 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "s" -v steps=3 -v rev=1 >actual &&
	test_cmp actual expected &&
	###
	echo "x w" >expected &&
	<graph tgnav "w" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo "y w" >expected &&
	<graph tgnav "w" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "x" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo "b w" >expected &&
	<graph tgnav "w" -v steps=3 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "x" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "y" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo "c w" >expected &&
	<graph tgnav "w" -v steps=4 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "x" -v steps=3 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "y" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "w" -v steps=-1 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "x" -v steps=-1 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "y" -v steps=-1 -v rev=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "w" -v steps=5 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "x" -v steps=4 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "y" -v steps=3 -v rev=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'step nil forward' '
	cat <<-EOT >graph &&
		a b
		b c
		r s
		s t
		t b
		w x
		x b
	EOT
	echo "b a r w" >expected &&
	<graph tgnav "" -v steps=2 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		a a
		t r
		x w
	EOT
	<graph tgnav "" -v steps=3 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		s r
		w w
	EOT
	<graph tgnav "" -v steps=4 >actual &&
	test_cmp actual expected &&
	echo "r r" >expected &&
	<graph tgnav "" -v steps=5 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "" -v steps=6 >actual &&
	test_cmp actual expected
'

test_expect_success 'step nil backward' '
	cat <<-EOT >graph &&
		a b
		b c
		r s
		s b
		w x
		x y
		y b
	EOT
	cat <<-EOT >expected &&
		b a
		s r
		x w
	EOT
	<graph tgnav "" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		c a
		b r
		y w
	EOT
	<graph tgnav "" -v steps=3 -v rev=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		c r
		b w
	EOT
	<graph tgnav "" -v steps=4 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo "c w" >expected &&
	<graph tgnav "" -v steps=5 -v rev=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "" -v steps=6 -v rev=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'pin works' '
	cat <<-EOT >graph &&
		a b
		r s
		s t
		t b
		w x
		x b
	EOT
	>expected &&
	<graph tgnav "a" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "a" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo "a a" >expected &&
	<graph tgnav "a" -v steps=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "a" -v steps=99 -v pin=1 >actual &&
	test_cmp actual expected &&
	echo "b a" >expected &&
	<graph tgnav "a" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		a a
		t r
		x w
	EOT
	<graph tgnav "b" -v steps=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		s r
		w w
	EOT
	<graph tgnav "b" -v steps=2 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		a a
		s r
		w w
	EOT
	<graph tgnav "b" -v steps=2 -v pin=1 >actual &&
	test_cmp actual expected &&
	echo "r r" >expected &&
	<graph tgnav "b" -v steps=3 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		a a
		r r
		w w
	EOT
	<graph tgnav "b" -v steps=3 -v pin=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "b" -v steps=99 -v pin=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "b" -v steps=4 >actual &&
	test_cmp actual expected &&
	###
	echo "b c" >>graph &&
	echo "c a r w" >expected &&
	<graph tgnav "b" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "b" -v steps=2 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "b" -v steps=99 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "b" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "b" -v steps=2 -v rev=1 -v pin=1 >actual &&
	###
	echo "r r" >expected &&
	<graph tgnav "t" -v steps=2 >actual &&
	test_cmp actual expected &&
	<graph tgnav "t" -v steps=3 -v pin=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "t" -v steps=99 -v pin=1 >actual &&
	test_cmp actual expected &&
	echo "c r" >expected &&
	<graph tgnav "t" -v steps=2 -v rev=1 >actual &&
	<graph tgnav "t" -v steps=3 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "t" -v steps=99 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "t" -v steps=99 -v rev=1 -v pin=5 >actual &&
	test_cmp actual expected &&
	<graph tgnav "t" -v steps=99 -v rev=1 -v pin=-1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "t" -v steps=99 -v rev=1 -v pin="true" >actual &&
	test_cmp actual expected &&
	<graph tgnav "t" -v steps=99 -v rev=1 -v pin="is true" >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "t" -v steps=3 >actual &&
	test_cmp actual expected &&
	<graph tgnav "t" -v steps=3 -v rev=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'multi startb' '
	cat <<-EOT >graph &&
		a b
		r s
		s t
		t b
		w x
		x b
	EOT
	echo "b a r w" >expected &&
	<graph tgnav "b" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph tgnav "b b b b" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph tgnav "b x t a" -v steps=1 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	echo "b w r a" >expected &&
	<graph tgnav "b x t a" -v steps=1 -v rev=1 -v pin=0 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		r r
		s r
		t r
		b a r w
	EOT
	<graph tgnav "r s t b" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph tgnav "r s t b" -v steps=0 -v pin=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		r r
		s r
		a a
		t r
		x w
	EOT
	<graph tgnav "r s t b" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "r s t b" -v steps=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		r r
		s r
		w w
	EOT
	<graph tgnav "r s t b" -v steps=2 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		r r
		a a
		s r
		w w
	EOT
	<graph tgnav "r s t b" -v steps=2 -v pin=1 >actual &&
	test_cmp actual expected &&
	echo "r r" >expected &&
	<graph tgnav "r s t b" -v steps=3 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		r r
		a a
		w w
	EOT
	<graph tgnav "r s t b" -v steps=3 -v pin=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "r s t b" -v steps=99 -v pin=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "r s t b" -v steps=4 >actual &&
	test_cmp actual expected &&
	###
	cat <<-EOT >expected &&
		s r
		t r
		b r
	EOT
	<graph tgnav "r s t b" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		s r
		t r
		b r a w
	EOT
	<graph tgnav "r s t b" -v steps=1 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t r
		b r
	EOT
	<graph tgnav "r s t b" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t r
		b r a w
	EOT
	<graph tgnav "r s t b" -v steps=2 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	echo "b r" >expected &&
	<graph tgnav "r s t b" -v steps=3 -v rev=1 >actual &&
	test_cmp actual expected &&
	echo "b r a w" >expected &&
	<graph tgnav "r s t b" -v steps=3 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "r s t b" -v steps=4 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "r s t b" -v steps=99 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "r s t b" -v steps=4 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "r s t b" -v steps=99 -v rev=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'fldone works' '
	cat <<-EOT >graph &&
		a b
		r s
		s t
		t b
		w x
		x b
	EOT
	printf "%s\n" a r w >expected &&
	<graph tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=-1 -v fldone=1 >actual &&
	test_cmp actual expected &&
	echo b >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v fldone=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		r r
		s r
		t r
		b a r w
	EOT
	<graph tgnav "r s t b" -v steps=0 >actual &&
	test_cmp actual expected &&
	printf "%s\n" r s t b >expected &&
	<graph tgnav "r s t b" -v steps=0 -v fldone=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "r s t b" -v steps=0 -v fldone=true >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t r
		b r a w
	EOT
	<graph tgnav "r s t b" -v steps=2 -v rev=1 -v pin=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" t b >expected &&
	<graph tgnav "r s t b" -v steps=2 -v rev=1 -v pin=1 -v fldone=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" r s w >expected &&
	<graph tgnav "r s t b" -v steps=2 -v fldone=true >actual &&
	test_cmp actual expected
'

test_expect_success 'input order maintained on output' '
	# only relevant for heads/roots shortcut
	# the heads or roots are to be output in the same
	# order they occurred in the input stream
	printf "%s\n" a b c >expected &&
	printf "%s\n" "a a" "b b" "c c" |
	tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "a a" "b b" "c c" |
	tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" a c b >expected &&
	printf "%s\n" "a a" "c c" "b b" |
	tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "a a" "c c" "b b" |
	tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" b a c >expected &&
	printf "%s\n" "b b" "a a" "c c" |
	tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "b b" "a a" "c c" |
	tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" b c a >expected &&
	printf "%s\n" "b b" "c c" "a a" |
	tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "b b" "c c" "a a" |
	tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" c a b >expected &&
	printf "%s\n" "c c" "a a" "b b" |
	tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "c c" "a a" "b b" |
	tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" c b a >expected &&
	printf "%s\n" "c c" "b b" "a a" |
	tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "c c" "b b" "a a" |
	tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected
'

test_expect_success 'no default loop check for heads/roots' '
	cat <<-EOT >graph &&
		a b
		b c
		c b
		c d
	EOT
	printf "%s\n" "a b" "b a" >graph2 &&
	>expected &&
	<graph test_must_fail tgnav "a" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph2 test_must_fail tgnav "a" -v steps=0 >actual &&
	test_cmp actual expected &&
	echo d >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	echo a >expected &&
	<graph tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph2 tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph2 tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	<graph2 tgnav "" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'default loop check' '
	cat <<-EOT >graph &&
		a b
		b c
		c b
		c d
	EOT
	printf "%s\n" "a b" "b a" >graph2 &&
	>expected &&
	<graph test_expect_code 65 tgnav "" -v steps=-1 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "" -v steps=2 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "a" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "a" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "a" -v steps=2 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "a" -v steps=2 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "a" -v steps=-1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "b" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "b" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "b" -v steps=2 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "b" -v steps=-1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "b" -v steps=0 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "b" -v steps=1 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "b" -v steps=2 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "b" -v steps=-1 -v rev=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "c" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "c" -v steps=0 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "d" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "d" -v steps=0 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "a" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "a" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "a" -v steps=1 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "a" -v steps=2 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "a" -v steps=2 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "a" -v steps=-1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "b" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "b" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "b" -v steps=2 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "b" -v steps=-1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "b" -v steps=-1 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "none" -v steps=0 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "none" -v steps=0 -v chklps=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'forced loop check' '
	cat <<-EOT >graph &&
		a b
		b c
		c b
		c d
	EOT
	printf "%s\n" "a b" "b a" >graph2 &&
	>expected &&
	<graph test_expect_code 65 tgnav "" -v steps=1 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "" -v steps=-1 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "" -v steps=1 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "" -v steps=-1 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "" -v steps=1 -v rev=1 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph test_expect_code 65 tgnav "" -v steps=-1 -v rev=1 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "" -v steps=1 -v rev=1 -v chklps=1 >actual &&
	test_cmp actual expected &&
	<graph2 test_expect_code 65 tgnav "" -v steps=-1 -v rev=1 -v chklps=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'inclbr' '
	cat <<-EOT >graph &&
		a b
		b c
		c d
		d e
	EOT
	echo e >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v inclbr="b d" >actual &&
	test_cmp actual expected &&
	echo a >expected &&
	<graph tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=-1 -v inclbr="b d" >actual &&
	test_cmp actual expected &&
	echo d >expected &&
	<graph tgnav "" -v steps=1 -v inclbr=c >actual &&
	test_cmp actual expected &&
	echo b >expected &&
	<graph tgnav "" -v steps=-1 -v inclbr=c >actual &&
	test_cmp actual expected &&
	printf "%s\n" b e >expected &&
	<graph tgnav "" -v steps=1 -v inclbr="e a" >actual &&
	test_cmp actual expected &&
	printf "%s\n" a d >expected &&
	<graph tgnav "" -v steps=-1 -v inclbr="e a" >actual &&
	test_cmp actual expected &&
	echo "b b" >expected &&
	<graph tgnav "c" -v steps=1 -v inclbr=c >actual &&
	test_cmp actual expected &&
	echo "d b" >expected &&
	<graph tgnav "c" -v steps=1 -v rev=1 -v inclbr=c >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "c" -v steps=2 -v inclbr=c >actual &&
	test_cmp actual expected &&
	<graph tgnav "c" -v steps=2 -v rev=1 -v inclbr=c >actual &&
	test_cmp actual expected
'

test_expect_success 'exclbr' '
	cat <<-EOT >graph &&
		a b
		b c
		c d
		d e
	EOT
	printf "%s\n" b e >expected &&
	<graph tgnav "" -v steps=1 -v exclbr="c" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=-1 -v rev=1 -v exclbr="c" >actual &&
	test_cmp actual expected &&
	printf "%s\n" a d >expected &&
	<graph tgnav "" -v steps=-1 -v exclbr="c" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v rev=1 -v exclbr="c" >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "" -v steps=1 -v exclbr="b d" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=-1 -v exclbr="b d" >actual &&
	test_cmp actual expected &&
	echo "c b" >expected &&
	<graph tgnav "e" -v steps=2 -v exclbr="a" >actual &&
	test_cmp actual expected &&
	echo "d b" >expected &&
	<graph tgnav "b" -v steps=2 -v rev=1 -v exclbr="a" >actual &&
	test_cmp actual expected
'

test_expect_success 'inclbr + exclbr' '
	cat <<-EOT >graph &&
	a b
	b c
	m n
	n o
	o c
	c d
	d e
	d f
	d g
	f h
	f i
	w x
	w y
	w z
	x 1
	x 2
	y 3
	y 4
	z 1
	z 5
	EOT
	printf "%s\n" e g h i 1 2 3 4 5 >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" a m w >expected &&
	<graph tgnav "" -v steps=-1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" d 1 5 >expected &&
	<graph tgnav "" -v steps=1 -v inclbr="c z" >actual &&
	test_cmp actual expected &&
	printf "%s\n" b o w >expected &&
	<graph tgnav "" -v steps=-1 -v inclbr="c z" >actual &&
	test_cmp actual expected &&
	printf "%s\n" c h i 1 2 3 4 5 >expected &&
	<graph tgnav "" -v steps=1 -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	printf "%s\n" a m f x y z >expected &&
	<graph tgnav "" -v steps=-1 -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	printf "%s\n" c 1 5 >expected &&
	<graph tgnav "" -v steps=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	printf "%s\n" b o z >expected &&
	<graph tgnav "" -v steps=-1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		b b
		o o
		5 z
		z z
	EOT
	<graph tgnav "" -v steps=2 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		c b o
		5 z
	EOT
	<graph tgnav "" -v steps=2 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "z z" >expected &&
	<graph tgnav "" -v steps=3 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "1 z" >expected &&
	<graph tgnav "" -v steps=3 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	>expected &&
	<graph tgnav "" -v steps=4 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=4 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "c" -v steps=2 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "b" -v steps=2 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "o" -v steps=2 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "5" -v steps=2 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "5" -v steps=2 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "1" -v steps=1 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "1" -v steps=3 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "z" -v steps=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "z" -v steps=3 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "c b o" >expected &&
	<graph tgnav "c" -v steps=0 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "c" -v steps=0 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		b b
		o o
	EOT
	<graph tgnav "c" -v steps=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "b b" >expected &&
	<graph tgnav "b" -v steps=0 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "b" -v steps=0 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "c b" >expected &&
	<graph tgnav "b" -v steps=1 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "o o" >expected &&
	<graph tgnav "o" -v steps=0 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "o" -v steps=0 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "c o" >expected &&
	<graph tgnav "o" -v steps=1 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "5 z" >expected &&
	<graph tgnav "5" -v steps=0 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "5" -v steps=0 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "1 z" >expected &&
	<graph tgnav "5" -v steps=1 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "z z" >expected &&
	<graph tgnav "5" -v steps=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "1 z" >expected &&
	<graph tgnav "1" -v steps=0 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "1" -v steps=0 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "5 z" >expected &&
	<graph tgnav "1" -v steps=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "z z" >expected &&
	<graph tgnav "1" -v steps=2 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "z z" >expected &&
	<graph tgnav "z" -v steps=0 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "z" -v steps=0 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "5 z" >expected &&
	<graph tgnav "z" -v steps=1 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected &&
	echo "1 z" >expected &&
	<graph tgnav "z" -v steps=2 -v rev=1 -v inclbr="c z" -v exclbr="d w" >actual &&
	test_cmp actual expected
'

test_expect_success 'pruneb positive refs' '
	cat <<-EOT >graph &&
	a b
	b c
	m n
	n o
	o c
	c d
	d e
	d f
	d g
	f h
	f i
	w x
	w y
	w z
	x 1
	x 2
	y 3
	y 4
	z 1
	z 5
	EOT
	printf "%s\n" e g h i 1 2 3 4 5 >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" 1 2 3 4 5 >expected &&
	<graph tgnav "" -v steps=1 -v pruneb="w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v pruneb="^ ^w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v pruneb="^ ^ w" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v pruneb="^ ^ ^ ^w" >actual &&
	test_cmp actual expected &&
	printf "%s\n" 1 3 4 5 >expected &&
	<graph tgnav "" -v steps=1 -v pruneb="y z" >actual &&
	test_cmp actual expected &&
	echo c >expected &&
	<graph tgnav "" -v steps=-1 -v pruneb="c" >actual &&
	test_cmp actual expected &&
	printf "%s\n" e f g >expected &&
	<graph tgnav "" -v steps=-1 -v pruneb="e f g" >actual &&
	test_cmp actual expected &&
	printf "%s\n" e g h i >expected &&
	<graph tgnav "" -v steps=1 -v pruneb="c" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v pruneb="e f g" >actual &&
	test_cmp actual expected &&
	printf "%s\n" h i >expected &&
	<graph tgnav "" -v steps=1 -v pruneb="f" >actual &&
	test_cmp actual expected
'

test_expect_success 'pruneb negative refs' '
	cat <<-EOT >graph &&
	a b
	b c
	m n
	n o
	o c
	c d
	d e
	d f
	d g
	f h
	f i
	w x
	w y
	w z
	x 1
	x 2
	y 3
	y 4
	z 1
	z 5
	EOT
	printf "%s\n" e g h i 1 2 3 4 5 >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" a m w >expected &&
	<graph tgnav "" -v steps=-1 -v pruneb="^c ^z" >actual &&
	test_cmp actual expected &&
	printf "%s\n" b o 2 3 4 >expected &&
	<graph tgnav "" -v steps=1 -v pruneb="^c ^z" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v pruneb="^ c z" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v pruneb="^ ^ ^c ^z" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v pruneb="^c ^ z" >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=1 -v pruneb="^ c ^ ^z" >actual &&
	test_cmp actual expected &&
	printf "%s\n" b n 1 2 5 >expected &&
	<graph tgnav "" -v steps=1 -v pruneb="^ o y" >actual &&
	test_cmp actual expected &&
	echo m >expected &&
	<graph tgnav "" -v steps=-1 -v pruneb="^ a w" >actual &&
	test_cmp actual expected
'

test_expect_success 'pruneb positive and negative refs' '
	cat <<-EOT >graph &&
	a b
	b c
	m n
	n o
	o c
	c d
	d e
	d f
	d g
	f h
	f i
	w x
	w y
	w z
	x 1
	x 2
	y 3
	y 4
	z 1
	z 5
	EOT
	printf "%s\n" e g h i 1 2 3 4 5 >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" e g >expected &&
	<graph tgnav "" -v steps=1 -v pruneb="b n ^ f" >actual &&
	test_cmp actual expected &&
	printf "%s\n" b n >expected &&
	<graph tgnav "" -v steps=-1 -v pruneb="b n ^ f" >actual &&
	test_cmp actual expected &&
	echo o >expected &&
	<graph tgnav "" -v steps=-1 -v pruneb="o ^ e g" >actual &&
	test_cmp actual expected &&
	printf "%s\n" h i >expected &&
	<graph tgnav "" -v steps=1 -v pruneb="o ^ e g" >actual &&
	test_cmp actual expected &&
	printf "%s\n" 2 3 4 5 >expected &&
	<graph tgnav "" -v steps=1 -v pruneb="^1 x y z" >actual &&
	test_cmp actual expected &&
	printf "%s\n" y 1 2 5 >expected &&
	<graph tgnav "" -v steps=1 -v pruneb="^ 3 4 ^x ^y ^z" >actual &&
	test_cmp actual expected &&
	printf "%s\n" x y z >expected &&
	<graph tgnav "" -v steps=-1 -v pruneb="^ 3 4 ^x ^y ^z" >actual &&
	test_cmp actual expected
'

test_expect_success 'pruneb positive and negative refs + inclbr/exclbr' '
	cat <<-EOT >graph &&
	a b
	b c
	m n
	n o
	o c
	c d
	d e
	d f
	d g
	f h
	f i
	w x
	w y
	w z
	x 1
	x 2
	y 3
	y 4
	z 1
	z 5
	EOT
	printf "%s\n" e g h i 1 2 3 4 5 >expected &&
	<graph tgnav "" -v steps=1 >actual &&
	test_cmp actual expected &&
	echo d >expected &&
	<graph tgnav "" -v steps=-1 -v inclbr=d -v exclbr=c -v pruneb=^c >actual &&
	test_cmp actual expected &&
	<graph tgnav "" -v steps=-1 -v inclbr="e f g" -v exclbr=h -v pruneb=^c >actual &&
	test_cmp actual expected &&
	printf "%s\n" e g i >expected &&
	<graph tgnav "" -v steps=1 -v inclbr="e f g" -v exclbr=h -v pruneb=^c >actual &&
	test_cmp actual expected &&
	printf "%s\n" e f g >expected &&
	<graph tgnav "" -v steps=1 -v inclbr=d -v exclbr=c -v pruneb=^c >actual &&
	test_cmp actual expected &&
	echo n >expected &&
	<graph tgnav "" -v steps=-1 -v inclbr="d o" -v exclbr=f -v pruneb=^c >actual &&
	test_cmp actual expected &&
	echo o >expected &&
	<graph tgnav "" -v steps=1 -v inclbr="d o" -v exclbr=f -v pruneb=^c >actual &&
	test_cmp actual expected &&
	printf "%s\n" h i 1 2 >expected &&
	<graph tgnav "" -v steps=1 -v exclbr="c z" -v pruneb="f x" >actual &&
	test_cmp actual expected &&
	printf "%s\n" f x >expected &&
	<graph tgnav "" -v steps=-1 -v exclbr="c z" -v pruneb="f x" >actual &&
	test_cmp actual expected
'

test_done
