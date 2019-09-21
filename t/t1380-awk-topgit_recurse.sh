#!/bin/sh

test_description='topgit_recurse.awk functionality'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

ap="$(tg --awk-path)" && test -n "$ap" && test -d "$ap" || die
aptr="$ap/topgit_recurse"
test -f "$aptr" && test -r "$aptr" && test -x "$aptr" || die

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

test_plan 38

printf '%s\n' "ann1" >anlist1 || die
printf '%s\n' "ann1" "ann3" >anlist13 || die
printf '%s\n' "ann1" "ann3" "ann5" >anlist135 || die
printf '%s\n' "t/1" >brlist1 || die
printf '%s\n' "t/1" "t/3" >brlist13 || die
printf '%s\n' "t/1" "t/3" "t/5" >brlist135 || die
printf '%s\n' "hd1" >hdlist1 || die
printf '%s\n' "hd1" "hd3" >hdlist13 || die
printf '%s\n' "hd1" "hd3" "hd5" >hdlist135 || die
printf 'refs/heads/%s  junk  here\n' "hd1" >hdf1list1 || die
printf 'refs/heads/%s  junk  here\n' "hd1" "hd3" >hdf1list13 || die
printf 'refs/heads/%s  junk  here\n' "hd1" "hd3" "hd5" >hdf1list135 || die
printf ' junk here  refs/heads/%s too \n' "hd1" >hdf3list1 || die
printf ' junk here  refs/heads/%s too \n' "hd1" "hd3" >hdf3list13 || die
printf ' junk here  refs/heads/%s too \n' "hd1" "hd3" "hd5" >hdf3list135 || die
printf 'some junk here too refs/heads/%s\n' "hd1" >hdf5list1 || die
printf 'some junk here too refs/heads/%s\n' "hd1" "hd3" >hdf5list13 || die
printf 'some junk here too refs/heads/%s\n' "hd1" "hd3" "hd5" >hdf5list135 || die
printf '%s\n' "t/1" >rtlist1 || die
printf '%s\n' "t/1" "t/3" >rtlist13 || die
printf '%s\n' "t/1" "t/3" "t/5" >rtlist135 || die

# optional first "-m[<n>]" will be stripped and then -v multib=<n> passed
# where <n> defaults to 1 if not specified
# first non-option arg is required, MUST be non-empty and is passed
# as the "startb" value to the awk script
tgrecurse_() { awk -f "$aptr" "$@"; }
tgrecurse() {
	tgm_=
	case "$1" in "-m"|"-m"[0-9]|"-m"[0-9][0-9])
		tgm_="${1#??}"
		: "${tgm_:=1}"
		shift
	esac
	test x"$1" != x || die 'tgrecurse requires non-empty arg 1 (startb)'
	tgstartb_="$1"; shift
	tgrecurse_ ${tgm_:+-v} ${tgm_:+multib=$tgm_} -v startb="$tgstartb_" "$@"
}
tgrecursemt() { tgrecurse "none" -v filter=1 "$@"; }

test_expect_success 'topgit_recurse runs' '
	# some stupid awks might not even compile it
	>expected &&
	awk -f "$aptr" -v startb=none -v filter=1 </dev/null >actual &&
	test_cmp actual expected &&
	# and make sure the helper works too
	echo "1 0 0 0 none" >expected &&
	</dev/null tgrecurse "none" >actual &&
	test_cmp actual expected
'

test_expect_success 'invalid brfile fails if read' '
        rm -f no-such-file &&
        test ! -e no-such-file &&
        >expected &&
        </dev/null test_must_fail tgrecursemt -v brfile=no-such-file >actual &&
        test_cmp actual expected &&
        echo "..." |
        test_must_fail tgrecursemt -v brfile=no-such-file >actual &&
        test_cmp actual expected &&
        test ! -e no-such-file
'

test_expect_success 'invalid anfile fails if read' '
        rm -f no-such-file &&
        test ! -e no-such-file &&
        >expected &&
        </dev/null test_must_fail tgrecursemt -v anfile=no-such-file >actual &&
        test_cmp actual expected &&
        echo "..." |
        test_must_fail tgrecursemt -v anfile=no-such-file >actual &&
        test_cmp actual expected &&
        test ! -e no-such-file
'

test_expect_success 'invalid hdfile fails if read' '
        rm -f no-such-file &&
        test ! -e no-such-file &&
        >expected &&
        </dev/null test_must_fail tgrecursemt -v hdfile=no-such-file >actual &&
        test_cmp actual expected &&
        echo "..." |
        test_must_fail tgrecursemt -v hdfile=no-such-file >actual &&
        test_cmp actual expected &&
        test ! -e no-such-file
'

test_expect_success 'invalid rtfile fails if read' '
        rm -f no-such-file &&
        test ! -e no-such-file &&
        >expected &&
        </dev/null tgrecursemt -v rtfile=no-such-file >actual &&
        test_cmp actual expected &&
        echo "..." |
        tgrecursemt -v rtfile=no-such-file >actual &&
        test_cmp actual expected &&
        </dev/null test_must_fail tgrecurse "none" -v rtfile=no-such-file >actual &&
        test_cmp actual expected &&
        echo "..." |
        test_must_fail tgrecurse "none" -v rtfile=no-such-file >actual &&
        test_cmp actual expected &&
        test ! -e no-such-file
'

test_expect_success 'brfile unperturbed without rmbr' '
        echo "br file here" >brorig &&
        cat brorig >brfile &&
        >expected &&
        </dev/null tgrecursemt -v brfile=brfile >actual &&
        test_cmp actual expected &&
        test_cmp brfile brorig &&
        echo "..." | tgrecursemt -v brfile=brfile >actual &&
        test_cmp actual expected &&
        test_cmp brfile brorig
'

test_expect_success 'anfile unperturbed without rman' '
        echo "an file here" >anorig &&
        cat anorig >anfile &&
        >expected &&
        </dev/null tgrecursemt -v anfile=anfile >actual &&
        test_cmp actual expected &&
        test_cmp anfile anorig &&
        echo "..." | tgrecursemt -v anfile=anfile >actual &&
        test_cmp actual expected &&
        test_cmp anfile anorig
'

test_expect_success 'hdfile unperturbed without rmhd' '
        echo "hd file here" >hdorig &&
        cat hdorig >hdfile &&
        >expected &&
        </dev/null tgrecursemt -v hdfile=hdfile >actual &&
        test_cmp actual expected &&
        test_cmp hdfile hdorig &&
        echo "..." | tgrecursemt -v hdfile=hdfile >actual &&
        test_cmp actual expected &&
        test_cmp hdfile hdorig
'

test_expect_success 'rtfile unperturbed without rmrt' '
        echo "rt file here" >rtorig &&
        cat rtorig >rtfile &&
        >expected &&
        </dev/null tgrecursemt -v rtfile=rtfile >actual &&
        test_cmp actual expected &&
        test_cmp rtfile rtorig &&
        echo "..." | tgrecursemt -v rtfile=rtfile >actual &&
        test_cmp actual expected &&
        test_cmp hdfile hdorig &&
        echo "1 0 0 0 none" >expected &&
        </dev/null tgrecurse "none" -v rtfile=rtfile >actual &&
        test_cmp actual expected &&
        test_cmp hdfile hdorig &&
        echo "..." | tgrecurse "none" -v rtfile=rtfile >actual &&
        test_cmp actual expected &&
        test_cmp hdfile hdorig
'

test_expect_success 'brfile removed with rmbr' '
        echo "br file here" >brorig &&
        cat brorig >brfile &&
        >expected &&
        </dev/null tgrecursemt -v brfile=brfile -v rmbr=1 >actual &&
        test_cmp actual expected &&
        test ! -e brfile &&
        cat brorig >brfile &&
        echo "..." | tgrecursemt -v brfile=brfile -v rmbr=1 >actual &&
        test_cmp actual expected &&
        test ! -e brfile
'

test_expect_success 'anfile removed with rman' '
        echo "an file here" >anorig &&
        cat anorig >anfile &&
        >expected &&
        </dev/null tgrecursemt -v anfile=anfile -v rman=1 >actual &&
        test_cmp actual expected &&
        test ! -e anfile &&
        cat anorig >anfile &&
        echo "..." | tgrecursemt -v anfile=anfile -v rman=1 >actual &&
        test_cmp actual expected &&
        test ! -e anfile
'

test_expect_success 'hdfile removed with rmhd' '
        echo "hd file here" >hdorig &&
        cat hdorig >hdfile &&
        >expected &&
        </dev/null tgrecursemt -v hdfile=hdfile -v rmhd=1 >actual &&
        test_cmp actual expected &&
        test ! -e hdfile &&
        cat hdorig >hdfile &&
        echo "..." | tgrecursemt -v hdfile=hdfile -v rmhd=1 >actual &&
        test_cmp actual expected &&
        test ! -e hdfile
'

test_expect_success 'rtfile removed with rmrt' '
        echo "rt file here" >rtorig &&
        cat rtorig >rtfile &&
        >expected &&
        </dev/null tgrecursemt -v rtfile=rtfile -v rmrt=1 >actual &&
        test_cmp actual expected &&
        test ! -e rtfile &&
        cat rtorig >rtfile &&
        echo "..." | tgrecursemt -v rtfile=rtfile -v rmrt=1 >actual &&
        test_cmp actual expected &&
        test ! -e rtfile &&
        cat rtorig >rtfile &&
        echo "1 0 0 0 none" >expected &&
        </dev/null tgrecurse "none" -v rtfile=rtfile -v rmrt=1 >actual &&
        test_cmp actual expected &&
        test ! -e rtfile &&
        cat rtorig >rtfile &&
        echo "..." | tgrecurse "none" -v rtfile=rtfile -v rmrt=1 >actual &&
        test_cmp actual expected &&
        test ! -e rtfile
'

test_expect_success 'hdfile works' '
	>expected &&
	echo "1 0 0 0 hd3" >expectedM3 &&
	echo "1 0 0 0 hd5" >expectedM5 &&
	echo "0 0 1 0 hd1" >expectedB1 &&
	echo "0 0 1 0 hd3" >expectedB3 &&
	echo "0 0 1 0 hd5" >expectedB5 &&
	echo "hd1" | tgrecurse "hd1" -v hdfile=hdlist1 >actual &&
	test_cmp actual expected &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdlist1 >actual &&
	test_cmp actual expectedM3 &&
	echo "hd5" | tgrecurse "hd5" -v hdfile=hdlist135 >actual &&
	test_cmp actual expected &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdlist13 >actual &&
	test_cmp actual expected &&
	echo "hd5" | tgrecurse "hd5" -v hdfile=hdlist13 >actual &&
	test_cmp actual expectedM5 &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdlist135 >actual &&
	test_cmp actual expected &&
	echo "hd1" | tgrecurse "hd1" -v hdfile=hdlist1 -v withbr=1 >actual &&
	test_cmp actual expectedB1 &&
	echo "hd5" | tgrecurse "hd5" -v hdfile=hdlist135 -v withbr=1 >actual &&
	test_cmp actual expectedB5 &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdlist13 -v withbr=1 >actual &&
	test_cmp actual expectedB3 &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdlist135 -v withbr=1 >actual &&
	test_cmp actual expectedB3
'

test_expect_success 'hdfile cut works' '
	>expected &&
	echo "1 0 0 0 hd3" >expectedM3 &&
	echo "0 0 1 0 hd3" >expectedB3 &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdlist135 -v cuthd=1 >actual &&
	test_cmp actual expectedM3 &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdf1list135 -v cuthd=2 >actual &&
	test_cmp actual expectedM3 &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdf3list135 -v cuthd=1 >actual &&
	test_cmp actual expectedM3 &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdf5list135 -v cuthd=4 >actual &&
	test_cmp actual expectedM3 &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdf1list135 -v cuthd=1 >actual &&
	test_cmp actual expected &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdf3list135 -v cuthd=3 >actual &&
	test_cmp actual expected &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdf5list135 -v cuthd=5 >actual &&
	test_cmp actual expected &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdf1list135 -v cuthd=1 -v withbr=1 >actual &&
	test_cmp actual expectedB3 &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdf3list135 -v cuthd=3 -v withbr=1 >actual &&
	test_cmp actual expectedB3 &&
	echo "hd3" | tgrecurse "hd3" -v hdfile=hdf5list135 -v cuthd=5 -v withbr=1 >actual &&
	test_cmp actual expectedB3
'

test_expect_success 'brfile works' '
	cat <<-EOT >expected &&
		0 0 1 0 t/5 t/3 t/1
		0 1 0 0 t/3 t/1
		0 0 1 1 t/5 t/1
	EOT
	printf "%s\n" "t/1 t/3" "t/1 t/5" "t/3 t/5" |
	tgrecurse "t/1" -v hdfile=brlist135 -v brfile=brlist13 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 0 1 0 t/5 t/3 t/1
		0 1 0 0 t/3 t/1
		0 0 1 1 t/5 t/1
		0 1 0 0 t/1
	EOT
	printf "%s\n" "t/1 t/3" "t/1 t/5" "t/3 t/5" |
	tgrecurse "t/1" -v withbr=1 -v hdfile=brlist135 -v brfile=brlist13 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 0 0 t/3 t/1
	EOT
	printf "%s\n" "t/1 t/3" "t/1 t/5" "t/3 t/5" |
	tgrecurse "t/1" -v hdfile=brlist135 -v brfile=brlist13 -v tgonly=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 0 0 t/3 t/1
		0 1 0 0 t/1
	EOT
	printf "%s\n" "t/1 t/3" "t/1 t/5" "t/3 t/5" |
	tgrecurse "t/1" -v withbr=1 -v hdfile=brlist135 -v brfile=brlist13 -v tgonly=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'anfile works' '
	cat hdlist135 brlist135 anlist135 >hdlist &&
	cat anlist135 >anlist &&
	echo "t/5" >>anlist &&
	echo "ann7" >>anlist &&
	cat <<-EOT >graph &&
		t/1 t/3
		t/1 hd1
		t/1 ann1
		t/3 t/5
		t/3 ann3
		t/3 ann5
		t/3 hd3
		t/5 ann7
		t/5 hd5
		t/5 hd7
	EOT
	cat <<-EOT >expected &&
		1 0 0 0 ann7 t/5 t/3 t/1
		0 0 1 0 hd5 t/5 t/3 t/1
		1 0 0 0 hd7 t/5 t/3 t/1
		0 1 0 0 t/5 t/3 t/1
		0 0 1 0 ann3 t/3 t/1
		0 0 1 0 ann5 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 1 0 0 t/3 t/1
		0 0 1 0 hd1 t/1
		0 0 1 0 ann1 t/1
		0 1 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 >actual &&
	test_cmp actual expected &&
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v withan=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 2 0 t/5 t/3 t/1
		0 1 2 0 ann3 t/3 t/1
		0 1 2 0 ann5 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 1 0 0 t/3 t/1
		0 0 1 0 hd1 t/1
		0 1 2 0 ann1 t/1
		0 1 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v anfile=anlist -v withan=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 0 1 0 hd3 t/3 t/1
		0 1 0 0 t/3 t/1
		0 0 1 0 hd1 t/1
		0 1 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v anfile=anlist -v withan=0 >actual &&
	test_cmp actual expected &&
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v anfile=anlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 0 1 0 hd3 t/3 t/1
		0 1 0 0 t/3 t/1
		0 0 1 0 hd1 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v anfile=anlist >actual &&
	test_cmp actual expected
'

test_expect_success 'rtfile works' '
	cat hdlist135 brlist135 anlist135 >hdlist &&
	cat anlist135 >anlist &&
	echo "t/5" >>anlist &&
	echo "ann7" >>anlist &&
	cat <<-EOT >>rtlist &&
		hd1
		hd5
		t/3
		t/1
		t/5
	EOT
	cat <<-EOT >graph &&
		t/1 t/3
		t/1 hd1
		t/1 ann1
		t/3 t/5
		t/3 ann3
		t/3 ann5
		t/3 hd3
		t/5 ann7
		t/5 hd5
		t/5 hd7
	EOT
	cat <<-EOT >expected &&
		0 1 2 0 t/5 t/3 t/1
		0 1 2 0 ann3 t/3 t/1
		0 1 2 0 ann5 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 1 0 0 t/3 t/1
		0 0 1 0 hd1 t/1
		0 1 2 0 ann1 t/1
		0 1 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v anfile=anlist -v withan=1 >actual &&
	test_cmp actual expected &&
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v anfile=anlist -v withan=1 -v usermt=":refs/remotes/origin" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 2 0 t/5 t/3 t/1
		0 1 2 0 ann3 t/3 t/1
		0 1 2 0 ann5 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 2 0 0 t/3 t/1
		0 0 1 0 hd1 t/1
		0 1 2 0 ann1 t/1
		0 2 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v anfile=anlist -v withan=1 -v rtfile=rtlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 0 0 0 :refs/remotes/origin/t/1 t/1
		0 0 0 0 :refs/remotes/origin/t/3 t/3 t/1
		0 1 2 0 t/5 t/3 t/1
		0 1 2 0 ann3 t/3 t/1
		0 1 2 0 ann5 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 2 0 0 t/3 t/1
		0 0 1 0 hd1 t/1
		0 1 2 0 ann1 t/1
		0 2 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v anfile=anlist -v withan=1 -v rtfile=rtlist -v usermt=":refs/remotes/origin" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 0 0 0 :refs/remotes/origin/t/1 t/1
		0 0 0 0 :refs/remotes/origin/t/3 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 2 0 0 t/3 t/1
		0 0 1 0 hd1 t/1
		0 2 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v anfile=anlist -v rtfile=rtlist -v usermt=":refs/remotes/origin" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 0 0 0 :refs/remotes/origin/t/1 t/1
		0 0 0 0 :refs/remotes/origin/t/3 t/3 t/1
		0 0 0 0 :refs/remotes/origin/t/5 t/5 t/3 t/1
		1 0 0 0 ann7 t/5 t/3 t/1
		0 0 1 0 hd5 t/5 t/3 t/1
		1 0 0 0 hd7 t/5 t/3 t/1
		0 2 0 0 t/5 t/3 t/1
		0 0 1 0 ann3 t/3 t/1
		0 0 1 0 ann5 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 2 0 0 t/3 t/1
		0 0 1 0 hd1 t/1
		0 0 1 0 ann1 t/1
		0 2 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist -v usermt=":refs/remotes/origin" >actual &&
	test_cmp actual expected &&
	printf "%s\n" t/1 t/5 >rtlist &&
	cat <<-EOT >expected &&
		1 0 0 0 ann7 t/5 t/3 t/1
		1 0 0 0 hd7 t/5 t/3 t/1
		0 2 0 0 t/5 t/3 t/1
		0 1 0 0 t/3 t/1
		0 2 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist -v usermt=":refs/remotes/origin" -v tgonly=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'preord option works' '
	cat brlist135 hdlist135 >hdlist &&
	cat anlist135 >anlist &&
	echo "hd1" >>anlist &&
	cat <<-EOT >graph &&
		t/1 hd1
		t/1 t/3
		t/1 ann1
		t/3 ann3
		t/3 t/5
		t/3 hd3
		t/5 ann5
		hd3 hd5
	EOT
	cat <<-EOT >expected &&
		0 0 0 0 :refs/remotes/origin/t/1 t/1
		0 1 2 0 hd1 t/1
		0 0 0 0 :refs/remotes/origin/t/3 t/3 t/1
		1 0 0 0 ann3 t/3 t/1
		1 0 0 0 ann5 t/5 t/3 t/1
		0 1 1 0 t/5 t/3 t/1
		0 0 1 0 hd5 hd3 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 2 0 0 t/3 t/1
		1 0 0 0 ann1 t/1
		0 2 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 2 0 0 t/1
		0 0 0 0 :refs/remotes/origin/t/1 t/1
		0 1 2 0 hd1 t/1
		0 2 0 0 t/3 t/1
		0 0 0 0 :refs/remotes/origin/t/3 t/3 t/1
		1 0 0 0 ann3 t/3 t/1
		0 1 1 0 t/5 t/3 t/1
		1 0 0 0 ann5 t/5 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 0 1 0 hd5 hd3 t/3 t/1
		1 0 0 0 ann1 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v preord=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'startb with path works' '
	cat brlist135 hdlist135 >hdlist &&
	cat <<-EOT >graph &&
		t/1 t/3
		t/3 t/5
		t/5 hd1
		t/5 hd3
		t/5 hd5
	EOT
	cat <<-EOT >expected &&
		0 0 1 0 hd1 t/5 t/3 t/1
		0 0 1 0 hd3 t/5 t/3 t/1
		0 0 1 0 hd5 t/5 t/3 t/1
		0 1 0 0 t/5 t/3 t/1
		0 1 0 0 t/3 t/1
		0 1 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 >actual &&
	test_cmp actual expected &&
	base="t/1" &&
	for comp in a b/c d/e/f g/h/i/j; do
		base="$base $comp" &&
		sed <expected "s,\$, $comp," >expected2 &&
		mv -f expected2 expected &&
		<graph tgrecurse "$base" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 >actual &&
		test_cmp actual expected
	done
'

test_expect_success 'startb with multib works' '
	cat brlist135 hdlist135 >hdlist &&
	cat <<-EOT >graph &&
		t/1 t/3
		t/1 hd1
		t/3 hd3
		t/5 hd5
	EOT
	cat <<-EOT >expected &&
		0 0 1 0 hd3 t/3 t/1
		0 1 0 0 t/3 t/1
		0 0 1 0 hd1 t/1
		0 1 0 0 t/1
	EOT
	<graph tgrecurse -m "t/1" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 0 1 0 hd5 t/5
		0 1 0 0 t/5
		0 0 1 0 hd3 t/3
		0 1 0 0 t/3
		0 0 1 1 hd3 t/3 t/1
		0 1 0 1 t/3 t/1
		0 0 1 0 hd1 t/1
		0 1 0 0 t/1
		0 0 1 2 hd3 t/3
		0 1 0 2 t/3
		0 0 1 1 hd5 t/5
		0 1 0 1 t/5
	EOT
	<graph tgrecurse -m2 "t/5 t/3 t/1 t/3 t/5" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 0 0 t/5
		0 0 1 0 hd5 t/5
		0 1 0 0 t/3
		0 0 1 0 hd3 t/3
		0 1 0 0 t/1
		0 1 0 1 t/3 t/1
		0 0 1 1 hd3 t/3 t/1
		0 0 1 0 hd1 t/1
		0 1 0 2 t/3
		0 0 1 2 hd3 t/3
		0 1 0 1 t/5
		0 0 1 1 hd5 t/5
	EOT
	<graph tgrecurse -m2 "t/5 t/3 t/1 t/3 t/5" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v preord=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 0 1 0 hd5 t/5
		0 1 0 0 t/5
		0 0 1 0 hd3 t/3
		0 1 0 0 t/3
		0 0 1 1 hd3 t/3 t/1
		0 1 0 1 t/3 t/1
		0 0 1 0 hd1 t/1
		0 1 0 0 t/1
	EOT
	<graph tgrecurse -m1 "t/5 t/3 t/1 t/3 t/5" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 0 0 t/5
		0 0 1 0 hd5 t/5
		0 1 0 0 t/3
		0 0 1 0 hd3 t/3
		0 1 0 0 t/1
		0 1 0 1 t/3 t/1
		0 0 1 1 hd3 t/3 t/1
		0 0 1 0 hd1 t/1
	EOT
	<graph tgrecurse -m1 "t/5 t/3 t/1 t/3 t/5" -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v preord=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'leaves only works' '
	cat brlist135 >brlist &&
	printf "%s\n" "t/7" "t/11" >>brlist &&
	cat hdlist135 brlist anlist135 >hdlist &&
	cat anlist135 >anlist &&
	echo "t/5" >>anlist &&
	echo "ann7" >>anlist &&
	cat <<-EOT >>rtlist &&
		hd1
		hd5
		t/3
		t/1
		t/5
		t/11
	EOT
	cat <<-EOT >graph &&
		t/1 t/3
		t/1 hd1
		t/1 ann1
		t/3 t/5
		t/3 ann3
		t/3 ann5
		t/3 hd3
		t/5 ann7
		t/5 hd5
		t/5 hd7
	EOT
	cat <<-EOT >expected &&
		0 1 1 0 t/7
		0 0 1 0 hd3 t/3 t/1
		0 0 1 0 hd1 t/1
		0 2 1 0 t/11
	EOT
	<graph tgrecurse -m "t/7 t/1 t/11" -v hdfile=hdlist -v brfile=brlist -v withbr=1 -v anfile=anlist -v withan=1 -v leaves=1 -v rtfile=rtlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 1 0 t/7
		1 0 0 0 t/13
		0 2 1 0 t/11
	EOT
	<graph tgrecurse -m "t/7 t/1 t/13 t/11" -v hdfile=hdlist -v brfile=brlist -v withbr=1 -v anfile=anlist -v withan=1 -v leaves=1 -v rtfile=rtlist -v tgonly=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'tgonly works' '
	cat brlist1 hdlist1 >hdlist &&
	echo "1 0 0 0 hd1" >expected &&
	echo "1 0 0 0 t/1" >>expected &&
	</dev/null tgrecurse -m "hd1 t/1" -v withbr=1 >actual &&
	test_cmp actual expected &&
	</dev/null tgrecurse -m "hd1 t/1" -v withbr=1 -v tgonly=1 >actual &&
	test_cmp actual expected &&
	</dev/null tgrecurse -m "hd1 t/1" -v withbr=1 -v tgonly=1 -v brfile=brlist1 >actual &&
	test_cmp actual expected &&
	>expected &&
	</dev/null tgrecurse -m "hd1 t/1" -v withbr=1 -v tgonly=1 -v hdfile=hdlist >actual &&
	test_cmp actual expected &&
	echo "0 1 1 0 t/1" >expected &&
	</dev/null tgrecurse -m "hd1 t/1" -v withbr=1 -v tgonly=1 -v hdfile=hdlist -v brfile=brlist1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "0 1 1 0 hd1" "0 1 1 0 t/1" >expected &&
	</dev/null tgrecurse -m "hd1 t/1" -v withbr=1 -v tgonly=1 -v hdfile=hdlist -v brfile=hdlist >actual &&
	test_cmp actual expected &&
	echo "0 2 1 0 t/1" >expected &&
	</dev/null tgrecurse -m "hd1 t/1" -v withbr=1 -v tgonly=1 -v hdfile=hdlist -v brfile=brlist1 -v rtfile=brlist1 >actual &&
	test_cmp actual expected &&
	echo "0 1 2 0 t/1" >expected &&
	</dev/null tgrecurse -m "hd1 t/1" -v withbr=1 -v tgonly=1 -v hdfile=hdlist -v brfile=brlist1 -v rtfile=brlist1 -v withan=1 -v anfile=brlist1 >actual &&
	test_cmp actual expected &&
	echo "0 1 2 1 t/1" >>expected &&
	</dev/null tgrecurse -m2 "t/1 hd1 t/1" -v withbr=1 -v tgonly=1 -v hdfile=hdlist -v brfile=brlist1 -v rtfile=brlist1 -v withan=1 -v anfile=brlist1 >actual &&
	test_cmp actual expected
'

test_expect_success 'once only node' '
	cat brlist135 >brlist &&
	echo "t/7" >>brlist &&
	cat brlist hdlist135 >hdlist &&
	printf "%s\n" hd7 hd11 >>hdlist &&
	cat <<-EOT >graph &&
		t/1 t/3
		t/1 t/7
		t/1 hd1
		t/3 t/5
		t/3 t/7
		t/3 hd3
		t/5 hd5
		t/5 t/7
		t/7 hd7
		t/7 hd11
	EOT
	cat <<-EOT >expected &&
		0 1 0 0 t/1
		0 1 0 0 t/3 t/1
		0 1 0 0 t/5 t/3 t/1
		0 0 1 0 hd5 t/5 t/3 t/1
		0 1 0 0 t/7 t/5 t/3 t/1
		0 0 1 0 hd7 t/7 t/5 t/3 t/1
		0 0 1 0 hd11 t/7 t/5 t/3 t/1
		0 1 0 1 t/7 t/3 t/1
		0 0 1 1 hd7 t/7 t/3 t/1
		0 0 1 1 hd11 t/7 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 1 0 2 t/7 t/1
		0 0 1 2 hd7 t/7 t/1
		0 0 1 2 hd11 t/7 t/1
		0 0 1 0 hd1 t/1
	EOT
	<graph tgrecurse "t/1" -v withbr=1 -v preord=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 0 1 0 hd5 t/5 t/3 t/1
		0 0 1 0 hd7 t/7 t/5 t/3 t/1
		0 0 1 0 hd11 t/7 t/5 t/3 t/1
		0 1 0 0 t/7 t/5 t/3 t/1
		0 1 0 0 t/5 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 1 0 0 t/3 t/1
		0 0 1 0 hd1 t/1
		0 1 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v withbr=1 -v once=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 0 0 t/1
		0 1 0 0 t/3 t/1
		0 1 0 0 t/5 t/3 t/1
		0 0 1 0 hd5 t/5 t/3 t/1
		0 1 0 0 t/7 t/5 t/3 t/1
		0 0 1 0 hd7 t/7 t/5 t/3 t/1
		0 0 1 0 hd11 t/7 t/5 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 0 1 0 hd1 t/1
	EOT
	<graph tgrecurse "t/1" -v withbr=1 -v preord=1 -v once=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected
'

test_expect_success 'once only node filter=2' '
	cat brlist135 >brlist &&
	echo "t/7" >>brlist &&
	cat brlist hdlist135 >hdlist &&
	printf "%s\n" hd7 hd11 >>hdlist &&
	cat <<-EOT >graph &&
		t/1 t/3
		t/1 t/7
		t/1 hd1
		t/3 t/5
		t/3 t/7
		t/3 hd3
		t/5 hd5
		t/5 t/7
		t/7 hd7
		t/7 hd11
	EOT
	cat <<-EOT >expected &&
		t/1 t/1
		t/1 t/3
		t/3 t/5
		t/5 hd5
		t/5 t/7
		t/7 hd7
		t/7 hd11
		t/3 t/7
		t/7 hd7
		t/7 hd11
		t/3 hd3
		t/1 t/7
		t/7 hd7
		t/7 hd11
		t/1 hd1
	EOT
	<graph tgrecurse "t/1" -v filter=2 -v withbr=1 -v preord=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/5 hd5
		t/7 hd7
		t/7 hd11
		t/5 t/7
		t/3 t/5
		t/3 hd3
		t/1 t/3
		t/1 hd1
		t/1 t/1
	EOT
	<graph tgrecurse "t/1" -v filter=2 -v withbr=1 -v once=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/1 t/1
		t/1 t/3
		t/3 t/5
		t/5 hd5
		t/5 t/7
		t/7 hd7
		t/7 hd11
		t/3 hd3
		t/1 hd1
	EOT
	<graph tgrecurse "t/1" -v filter=2 -v withbr=1 -v preord=1 -v once=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected
'

test_expect_success 'once only node filter=1' '
	cat brlist135 >brlist &&
	echo "t/7" >>brlist &&
	cat brlist hdlist135 >hdlist &&
	printf "%s\n" hd7 hd11 >>hdlist &&
	cat <<-EOT >graph &&
		t/1 t/3
		t/1 t/7
		t/1 hd1
		t/3 t/5
		t/3 t/7
		t/3 hd3
		t/5 hd5
		t/5 t/7
		t/7 hd7
		t/7 hd11
	EOT
	cat <<-EOT >expected &&
		t/1
		t/3
		t/5
		hd5
		t/7
		hd7
		hd11
		t/7
		hd7
		hd11
		hd3
		t/7
		hd7
		hd11
		hd1
	EOT
	<graph tgrecurse "t/1" -v filter=1 -v withbr=1 -v preord=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		hd5
		hd7
		hd11
		t/7
		t/5
		hd3
		t/3
		hd1
		t/1
	EOT
	<graph tgrecurse "t/1" -v filter=1 -v withbr=1 -v once=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/1
		t/3
		t/5
		hd5
		t/7
		hd7
		hd11
		hd3
		hd1
	EOT
	<graph tgrecurse "t/1" -v filter=1 -v withbr=1 -v preord=1 -v once=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected
'

test_expect_success 'once only deps' '
	cat brlist135 >brlist &&
	echo "t/7" >>brlist &&
	cat brlist hdlist135 >hdlist &&
	printf "%s\n" hd7 hd11 >>hdlist &&
	cat <<-EOT >graph &&
		t/1 t/3
		t/1 t/7
		t/1 hd1
		t/3 t/5
		t/3 t/7
		t/3 hd3
		t/5 hd5
		t/5 t/7
		t/7 hd7
		t/7 hd11
	EOT
	cat <<-EOT >expected &&
		0 0 1 0 hd5 t/5 t/3 t/1
		0 0 1 0 hd7 t/7 t/5 t/3 t/1
		0 0 1 0 hd11 t/7 t/5 t/3 t/1
		0 1 0 0 t/7 t/5 t/3 t/1
		0 1 0 0 t/5 t/3 t/1
		0 0 1 1 hd7 t/7 t/3 t/1
		0 0 1 1 hd11 t/7 t/3 t/1
		0 1 0 1 t/7 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 1 0 0 t/3 t/1
		0 0 1 2 hd7 t/7 t/1
		0 0 1 2 hd11 t/7 t/1
		0 1 0 2 t/7 t/1
		0 0 1 0 hd1 t/1
		0 1 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v withbr=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 0 1 0 hd5 t/5 t/3 t/1
		0 0 1 0 hd7 t/7 t/5 t/3 t/1
		0 0 1 0 hd11 t/7 t/5 t/3 t/1
		0 1 0 0 t/7 t/5 t/3 t/1
		0 1 0 0 t/5 t/3 t/1
		0 1 0 1 t/7 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 1 0 0 t/3 t/1
		0 1 0 2 t/7 t/1
		0 0 1 0 hd1 t/1
		0 1 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v withbr=1 -v once=-1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 0 0 t/1
		0 1 0 0 t/3 t/1
		0 1 0 0 t/5 t/3 t/1
		0 0 1 0 hd5 t/5 t/3 t/1
		0 1 0 0 t/7 t/5 t/3 t/1
		0 0 1 0 hd7 t/7 t/5 t/3 t/1
		0 0 1 0 hd11 t/7 t/5 t/3 t/1
		0 1 0 1 t/7 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 1 0 2 t/7 t/1
		0 0 1 0 hd1 t/1
	EOT
	<graph tgrecurse "t/1" -v withbr=1 -v preord=1 -v once=-1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected
'

test_expect_success 'once only deps filter=2' '
	cat brlist135 >brlist &&
	echo "t/7" >>brlist &&
	cat brlist hdlist135 >hdlist &&
	printf "%s\n" hd7 hd11 >>hdlist &&
	cat <<-EOT >graph &&
		t/1 t/3
		t/1 t/7
		t/1 hd1
		t/3 t/5
		t/3 t/7
		t/3 hd3
		t/5 hd5
		t/5 t/7
		t/7 hd7
		t/7 hd11
	EOT
	cat <<-EOT >expected &&
		t/5 hd5
		t/7 hd7
		t/7 hd11
		t/5 t/7
		t/3 t/5
		t/7 hd7
		t/7 hd11
		t/3 t/7
		t/3 hd3
		t/1 t/3
		t/7 hd7
		t/7 hd11
		t/1 t/7
		t/1 hd1
		t/1 t/1
	EOT
	<graph tgrecurse "t/1" -v filter=2 -v withbr=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/5 hd5
		t/7 hd7
		t/7 hd11
		t/5 t/7
		t/3 t/5
		t/3 t/7
		t/3 hd3
		t/1 t/3
		t/1 t/7
		t/1 hd1
		t/1 t/1
	EOT
	<graph tgrecurse "t/1" -v filter=2 -v withbr=1 -v once=-1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/1 t/1
		t/1 t/3
		t/3 t/5
		t/5 hd5
		t/5 t/7
		t/7 hd7
		t/7 hd11
		t/3 t/7
		t/3 hd3
		t/1 t/7
		t/1 hd1
	EOT
	<graph tgrecurse "t/1" -v filter=2 -v withbr=1 -v preord=1 -v once=-1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected
'

test_expect_success 'once only deps filter=1' '
	cat brlist135 >brlist &&
	echo "t/7" >>brlist &&
	cat brlist hdlist135 >hdlist &&
	printf "%s\n" hd7 hd11 >>hdlist &&
	cat <<-EOT >graph &&
		t/1 t/3
		t/1 t/7
		t/1 hd1
		t/3 t/5
		t/3 t/7
		t/3 hd3
		t/5 hd5
		t/5 t/7
		t/7 hd7
		t/7 hd11
	EOT
	cat <<-EOT >expected &&
		hd5
		hd7
		hd11
		t/7
		t/5
		hd7
		hd11
		t/7
		hd3
		t/3
		hd7
		hd11
		t/7
		hd1
		t/1
	EOT
	<graph tgrecurse "t/1" -v filter=1 -v withbr=1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		hd5
		hd7
		hd11
		t/7
		t/5
		t/7
		hd3
		t/3
		t/7
		hd1
		t/1
	EOT
	<graph tgrecurse "t/1" -v filter=1 -v withbr=1 -v once=-1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/1
		t/3
		t/5
		hd5
		t/7
		hd7
		hd11
		t/7
		hd3
		t/7
		hd1
	EOT
	<graph tgrecurse "t/1" -v filter=1 -v withbr=1 -v preord=1 -v once=-1 -v hdfile=hdlist -v brfile=brlist >actual &&
	test_cmp actual expected
'

test_expect_success 'filter=0' '
	cat brlist135 hdlist135 >hdlist &&
	cat anlist135 >anlist &&
	echo "hd1" >>anlist &&
	cat <<-EOT >graph &&
		t/1 hd1
		t/1 t/3
		t/1 ann1
		t/3 ann3
		t/3 t/1
		t/3 t/5
		t/3 hd3
		t/5 ann5
		hd3 hd5
	EOT
	cat <<-EOT >expected &&
		0 0 0 0 :refs/remotes/origin/t/1 t/1
		0 1 2 0 hd1 t/1
		0 0 0 0 :refs/remotes/origin/t/3 t/3 t/1
		1 0 0 0 ann3 t/3 t/1
		:loop: t/1 t/3 t/1
		1 0 0 0 ann5 t/5 t/3 t/1
		0 1 1 0 t/5 t/3 t/1
		0 0 1 0 hd5 hd3 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		0 2 0 0 t/3 t/1
		1 0 0 0 ann1 t/1
		0 2 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v filter=0 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 2 0 hd1 t/1
		1 0 0 0 ann3 t/3 t/1
		:loop: t/1 t/3 t/1
		1 0 0 0 ann5 t/5 t/3 t/1
		0 1 1 0 t/5 t/3 t/1
		0 2 0 0 t/3 t/1
		1 0 0 0 ann1 t/1
		0 2 0 0 t/1
	EOT
	<graph tgrecurse "t/1" -v filter=0 -v tgonly=1 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		1 0 0 0 ann3 t/3 t/1
		:loop: t/1 t/3 t/1
		1 0 0 0 ann5 t/5 t/3 t/1
		0 1 1 0 t/5 t/3 t/1
		0 0 1 0 hd5 hd3 t/3 t/1
		0 0 1 0 hd3 t/3 t/1
		1 0 0 0 ann1 t/1
	EOT
	<graph tgrecurse "t/1" -v filter=0 -v leaves=1 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		1 0 0 0 ann3 t/3 t/1
		:loop: t/1 t/3 t/1
		1 0 0 0 ann5 t/5 t/3 t/1
		0 1 1 0 t/5 t/3 t/1
		1 0 0 0 ann1 t/1
	EOT
	<graph tgrecurse "t/1" -v filter=0 -v tgonly=1 -v leaves=1 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'filter=2' '
	cat brlist135 hdlist135 >hdlist &&
	cat anlist135 >anlist &&
	echo "hd1" >>anlist &&
	cat <<-EOT >graph &&
		t/1 hd1
		t/1 t/3
		t/1 ann1
		t/3 ann3
		t/3 t/1
		t/3 t/5
		t/3 hd3
		t/5 ann5
		hd3 hd5
	EOT
	cat <<-EOT >expected &&
		t/1 hd1
		:loop: t/1 t/3 t/1
		t/3 t/5
		hd3 hd5
		t/3 hd3
		t/1 t/3
		t/1 t/1
	EOT
	<graph tgrecurse "t/1" -v filter=2 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/1 hd1
		:loop: t/1 t/3 t/1
		t/3 t/5
		t/1 t/3
		t/1 t/1
	EOT
	<graph tgrecurse "t/1" -v filter=2 -v tgonly=1 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		:loop: t/1 t/3 t/1
		t/3 t/5
		hd3 hd5
		t/3 hd3
	EOT
	<graph tgrecurse "t/1" -v filter=2 -v leaves=1 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		:loop: t/1 t/3 t/1
		t/3 t/5
	EOT
	<graph tgrecurse "t/1" -v filter=2 -v tgonly=1 -v leaves=1 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'filter=1' '
	cat brlist135 hdlist135 >hdlist &&
	cat anlist135 >anlist &&
	echo "hd1" >>anlist &&
	cat <<-EOT >graph &&
		t/1 hd1
		t/1 t/3
		t/1 ann1
		t/3 ann3
		t/3 t/1
		t/3 t/5
		t/3 hd3
		t/5 ann5
		hd3 hd5
	EOT
	cat <<-EOT >expected &&
		hd1
		:loop: t/1 t/3 t/1
		t/5
		hd5
		hd3
		t/3
		t/1
	EOT
	<graph tgrecurse "t/1" -v filter=1 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		hd1
		:loop: t/1 t/3 t/1
		t/5
		t/3
		t/1
	EOT
	<graph tgrecurse "t/1" -v filter=1 -v tgonly=1 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		:loop: t/1 t/3 t/1
		t/5
		hd5
		hd3
	EOT
	<graph tgrecurse "t/1" -v filter=1 -v leaves=1 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		:loop: t/1 t/3 t/1
		t/5
	EOT
	<graph tgrecurse "t/1" -v filter=1 -v tgonly=1 -v leaves=1 -v hdfile=hdlist -v brfile=brlist135 -v withbr=1 -v rtfile=rtlist13 -v usermt=:refs/remotes/origin/ -v anfile=anlist -v withan=1 -v showlp=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'filter with path' '
	cat <<-EOT >graph &&
		t/1 t/3
		t/3 t/5
	EOT
	cat <<-EOT >expected &&
		t/3 t/5
		t/1 t/3
	EOT
	<graph tgrecurse "t/1 extra path" -v filter=2 -v hdfile=brlist135 -v brfile=brlist135 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/5" "t/3" >expected &&
	<graph tgrecurse "t/1 extra path" -v filter=1 -v hdfile=brlist135 -v brfile=brlist135 >actual &&
	test_cmp actual expected
'

test_expect_success 'filter with multib' '
	cat <<-EOT >graph &&
		t/1 t/3
		t/3 t/5
	EOT
	cat <<-EOT >expected &&
		t/3 t/5
		t/3 t/5
		t/1 t/3
	EOT
	<graph tgrecurse -m "t/3 t/1" -v filter=2 -v hdfile=brlist135 -v brfile=brlist135 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/5" "t/5" "t/3" >expected &&
	<graph tgrecurse -m "t/3 t/1" -v filter=1 -v hdfile=brlist135 -v brfile=brlist135 >actual &&
	test_cmp actual expected
'

test_expect_success 'loop detection' '
	cat <<-EOT >graph &&
		t/1 t/3
		t/3 t/1
		t/3 t/5
		t/5 t/1
		t/5 t/3
	EOT
	cat <<-EOT >expected &&
		:loop: t/1 t/3 t/1
		:loop: t/1 t/5 t/3 t/1
		:loop: t/3 t/5 t/3 t/1
	EOT
	<graph tgrecurse "t/1" -v leaves=1 -v showlp=1 -v hdfile=brlist135 -v brfile=brlist135 >actual &&
	test_cmp actual expected &&
	<graph tgrecurse "t/1" -v preord=1 -v leaves=1 -v showlp=1 -v hdfile=brlist135 -v brfile=brlist135 >actual &&
	test_cmp actual expected &&
	<graph tgrecurse "t/1" -v filter=2 -v leaves=1 -v showlp=1 -v hdfile=brlist135 -v brfile=brlist135 >actual &&
	test_cmp actual expected &&
	<graph tgrecurse "t/1" -v preord=1 -v filter=2 -v leaves=1 -v showlp=1 -v hdfile=brlist135 -v brfile=brlist135 >actual &&
	test_cmp actual expected &&
	<graph tgrecurse "t/1" -v filter=1 -v leaves=1 -v showlp=1 -v hdfile=brlist135 -v brfile=brlist135 >actual &&
	test_cmp actual expected &&
	<graph tgrecurse "t/1" -v preord=1 -v filter=1 -v leaves=1 -v showlp=1 -v hdfile=brlist135 -v brfile=brlist135 >actual &&
	test_cmp actual expected
'

test_expect_success 'inclbr' '
	cat brlist135 - <<-EOT >brlist &&
		t/2
		t/4
		t/6
		t/7
		t/8
		t/9
		t/A
	EOT
	cat brlist hdlist135 - <<-EOT >hdlist &&
		hd2
		hd4
		hd6
		hd7
		hd8
		hd9
	EOT
	cat <<-EOT >graph &&
		t/1 t/2
		t/1 hd1
		t/1 t/4
		t/2 hd2
		t/2 t/3
		t/4 t/5
		t/4 hd4
		t/3 t/6
		t/3 hd3
		t/3 t/7
		t/5 t/8
		t/5 hd5
		t/5 t/9
		t/6 hd6
		t/7 hd7
		t/8 hd8
		t/9 hd9
		t/A t/1
	EOT
	dotgr() { <graph tgrecurse_ -v hdfile=hdlist -v brfile=brlist -v withbr=1 \
		-v startb="$@"; } &&
	cat <<-EOT >expected &&
		0 1 1 0 t/1 t/A
		0 1 0 0 t/A
	EOT
	dotgr "t/A" -v inclbr="t/A" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 0 0 t/A
		0 1 1 0 t/1 t/A
	EOT
	dotgr "t/A" -v preord=1 -v inclbr="t/A" >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/A t/1" "t/A t/A" >expected &&
	dotgr "t/A" -v inclbr="t/A" -v filter=2 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/A t/A" "t/A t/1" >expected &&
	dotgr "t/A" -v preord=1 -v inclbr="t/A" -v filter=2 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/1" "t/A" >expected &&
	dotgr "t/A" -v inclbr="t/A" -v filter=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/A" "t/1" >expected &&
	dotgr "t/A" -v preord=1 -v inclbr="t/A" -v filter=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 1 0 t/2 t/1 t/A
		0 0 1 0 hd1 t/1 t/A
		0 1 1 0 t/4 t/1 t/A
		0 1 0 0 t/1 t/A
	EOT
	dotgr "t/A" -v inclbr="t/1" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 0 0 t/1 t/A
		0 1 1 0 t/2 t/1 t/A
		0 0 1 0 hd1 t/1 t/A
		0 1 1 0 t/4 t/1 t/A
	EOT
	dotgr "t/A" -v preord=1 -v inclbr="t/1" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/1 t/2
		t/1 hd1
		t/1 t/4
		t/A t/1
	EOT
	dotgr "t/A" -v inclbr="t/1" -v filter=2 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/A t/1
		t/1 t/2
		t/1 hd1
		t/1 t/4
	EOT
	dotgr "t/A" -v preord=1 -v inclbr="t/1" -v filter=2 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/2" "hd1" "t/4" "t/1" >expected &&
	dotgr "t/A" -v inclbr="t/1" -v filter=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/1" "t/2" "hd1" "t/4" >expected &&
	dotgr "t/A" -v preord=1 -v inclbr="t/1" -v filter=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/A t/1
		t/1 t/2
		t/1 hd1
		t/1 t/4
		t/4 t/5
		t/5 t/8
		t/5 hd5
		t/5 t/9
	EOT
	dotgr "t/A" -v preord=1 -v inclbr="t/5 t/1" -v filter=2 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/1 t/2
		t/2 hd2
		t/2 t/3
		t/3 t/6
		t/3 hd3
		t/3 t/7
	EOT
	dotgr "t/1" -v preord=1 -v inclbr="t/2 t/3" -v filter=2 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/3 t/6
		t/6 hd6
		t/3 t/7
		t/7 hd7
		t/5 t/8
		t/8 hd8
		t/5 t/9
		t/9 hd9
	EOT
	dotgr "t/3 t/5" -v multib=1 -v preord=1 -v inclbr="t/6 t/7 t/8 t/9" -v filter=2 >actual &&
	test_cmp actual expected
'

test_expect_success 'exclbr' '
	cat brlist135 - <<-EOT >brlist &&
		t/2
		t/4
		t/6
		t/7
		t/8
		t/9
		t/A
	EOT
	cat brlist hdlist135 - <<-EOT >hdlist &&
		hd2
		hd4
		hd6
		hd7
		hd8
		hd9
	EOT
	cat <<-EOT >graph &&
		t/1 t/2
		t/1 hd1
		t/1 t/4
		t/2 hd2
		t/2 t/3
		t/4 t/5
		t/4 hd4
		t/3 t/6
		t/3 hd3
		t/3 t/7
		t/5 t/8
		t/5 hd5
		t/5 t/9
		t/6 hd6
		t/7 hd7
		t/8 hd8
		t/9 hd9
		t/A t/1
	EOT
	dotgr() { <graph tgrecurse_ -v hdfile=hdlist -v brfile=brlist -v withbr=1 \
		-v startb="$@"; } &&
	>expected &&
	dotgr "t/A" -v exclbr="t/A" >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/A" >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v exclbr="t/A -v filter=2" >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/A -v filter=2" >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v exclbr="t/A" -v filter=1 >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/A" -v filter=1 >actual &&
	test_cmp actual expected &&
	echo "0 1 1 0 t/A" >expected &&
	dotgr "t/A" -v exclbr="t/1" >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/1" >actual &&
	test_cmp actual expected &&
	echo "t/A t/A" >expected &&
	dotgr "t/A" -v exclbr="t/1" -v filter=2 >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/1" -v filter=2 >actual &&
	test_cmp actual expected &&
	echo "t/A" >expected &&
	dotgr "t/A" -v exclbr="t/1" -v filter=1 >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/1" -v filter=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 0 1 0 hd1 t/1 t/A
		0 1 0 0 t/1 t/A
		0 1 0 0 t/A
	EOT
	dotgr "t/A" -v exclbr="t/4 t/2" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 0 0 t/A
		0 1 0 0 t/1 t/A
		0 0 1 0 hd1 t/1 t/A
	EOT
	dotgr "t/A" -v preord=1 -v exclbr="t/4 t/2" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/1 hd1
		t/A t/1
		t/A t/A
	EOT
	dotgr "t/A" -v exclbr="t/4 t/2" -v filter=2 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/A t/A
		t/A t/1
		t/1 hd1
	EOT
	dotgr "t/A" -v preord=1 -v exclbr="t/4 t/2" -v filter=2 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "hd1" "t/1" "t/A" >expected &&
	dotgr "t/A" -v exclbr="t/4 t/2" -v filter=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/A" "t/1" "hd1" >expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/4 t/2" -v filter=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 1 0 t/6 t/3
		0 1 1 0 t/7 t/3
		0 1 0 0 t/3
		0 1 1 0 t/8 t/5
		0 1 1 0 t/9 t/5
		0 1 0 0 t/5
	EOT
	dotgr "t/3 t/5" -v multib=1 -v exclbr="hd3 hd5 hd6 hd7 hd8 hd9" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 0 0 t/3
		0 1 1 0 t/6 t/3
		0 1 1 0 t/7 t/3
		0 1 0 0 t/5
		0 1 1 0 t/8 t/5
		0 1 1 0 t/9 t/5
	EOT
	dotgr "t/3 t/5" -v multib=1 -v preord=1 -v exclbr="hd3 hd5 hd6 hd7 hd8 hd9" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/3 t/6
		t/3 t/7
		t/3 t/3
		t/5 t/8
		t/5 t/9
		t/5 t/5
	EOT
	dotgr "t/3 t/5" -v multib=1 -v exclbr="hd3 hd5 hd6 hd7 hd8 hd9" -v filter=2 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/3 t/3
		t/3 t/6
		t/3 t/7
		t/5 t/5
		t/5 t/8
		t/5 t/9
	EOT
	dotgr "t/3 t/5" -v multib=1 -v preord=1 -v exclbr="hd3 hd5 hd6 hd7 hd8 hd9" -v filter=2 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/6" "t/7" "t/3" "t/8" "t/9" "t/5" >expected &&
	dotgr "t/3 t/5" -v multib=1 -v exclbr="hd3 hd5 hd6 hd7 hd8 hd9" -v filter=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/3" "t/6" "t/7" "t/5" "t/8" "t/9" >expected &&
	dotgr "t/3 t/5" -v multib=1 -v preord=1 -v exclbr="hd3 hd5 hd6 hd7 hd8 hd9" -v filter=1 >actual &&
	test_cmp actual expected
'

test_expect_success 'inclbr + exclbr' '
	cat brlist135 - <<-EOT >brlist &&
		t/2
		t/4
		t/6
		t/7
		t/8
		t/9
		t/A
	EOT
	cat brlist hdlist135 - <<-EOT >hdlist &&
		hd2
		hd4
		hd6
		hd7
		hd8
		hd9
	EOT
	cat <<-EOT >graph &&
		t/1 t/2
		t/1 hd1
		t/1 t/4
		t/2 hd2
		t/2 t/3
		t/4 t/5
		t/4 hd4
		t/3 t/6
		t/3 hd3
		t/3 t/7
		t/5 t/8
		t/5 hd5
		t/5 t/9
		t/6 hd6
		t/7 hd7
		t/8 hd8
		t/9 hd9
		t/A t/1
	EOT
	dotgr() { <graph tgrecurse_ -v hdfile=hdlist -v brfile=brlist -v withbr=1 \
		-v startb="$@"; } &&
	>expected &&
	dotgr "t/A" -v exclbr="t/A" -v inclbr="t/A" >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/A" -v inclbr="t/A" >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v exclbr="t/A -v filter=2" -v inclbr="t/A" >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/A -v inclbr="t/A" -v filter=2" >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v exclbr="t/A" -v inclbr="t/A" -v filter=1 >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/A" -v inclbr="t/A" -v filter=1 >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v exclbr="t/1" -v inclbr="t/1" >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/1" -v inclbr="t/1" >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v exclbr="t/1" -v inclbr="t/1" -v filter=2 >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/1" -v inclbr="t/1" -v filter=2 >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v exclbr="t/1" -v inclbr="t/1" -v filter=1 >actual &&
	test_cmp actual expected &&
	dotgr "t/A" -v preord=1 -v exclbr="t/1" -v inclbr="t/1" -v filter=1 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 1 0 t/6 t/3
		0 0 1 0 hd3 t/3
		0 1 0 0 t/3
		0 0 1 0 hd5 t/5
		0 1 1 0 t/9 t/5
		0 1 0 0 t/5
	EOT
	dotgr "t/3 t/5" -v multib=1 -v exclbr="t/7 t/8" -v inclbr="t/3 t/5" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		0 1 0 0 t/3
		0 1 1 0 t/6 t/3
		0 0 1 0 hd3 t/3
		0 1 0 0 t/5
		0 0 1 0 hd5 t/5
		0 1 1 0 t/9 t/5
	EOT
	dotgr "t/3 t/5" -v multib=1 -v preord=1 -v exclbr="t/7 t/8" -v inclbr="t/3 t/5" >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/3 t/6
		t/3 hd3
		t/3 t/3
		t/5 hd5
		t/5 t/9
		t/5 t/5
	EOT
	dotgr "t/3 t/5" -v multib=1 -v exclbr="t/7 t/8" -v inclbr="t/3 t/5" -v filter=2 >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		t/3 t/3
		t/3 t/6
		t/3 hd3
		t/5 t/5
		t/5 hd5
		t/5 t/9
	EOT
	dotgr "t/3 t/5" -v multib=1 -v preord=1 -v exclbr="t/7 t/8" -v inclbr="t/3 t/5" -v filter=2 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/6" "hd3" "t/3" "hd5" "t/9" "t/5" >expected &&
	dotgr "t/3 t/5" -v multib=1 -v exclbr="t/7 t/8" -v inclbr="t/3 t/5" -v filter=1 >actual &&
	test_cmp actual expected &&
	printf "%s\n" "t/3" "t/6" "hd3" "t/5" "hd5" "t/9" >expected &&
	dotgr "t/3 t/5" -v multib=1 -v preord=1 -v exclbr="t/7 t/8" -v inclbr="t/3 t/5" -v filter=1 >actual &&
	test_cmp actual expected
'

test_done
