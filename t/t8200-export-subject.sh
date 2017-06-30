#!/bin/sh

test_description='test export subject handling'

. ./test-lib.sh

test_plan 44

tmp="$(test_get_temp commit)" || die

getsubj() {
	git cat-file commit "$1" >"$tmp" &&
	<"$tmp" awk '
		BEGIN {hdr=1}
		hdr {if ($0 == "") hdr=0; next}
		!hdr {print; exit}
	'
}

striptopsubj() {
	grep -v -i 'subject:' <.topmsg >"$tmp" &&
	cat "$tmp" >.topmsg
}

test_expect_success 'strip patch' '
	tg_test_create_branches <<-EOT &&
		t/patch [PATCH] just a patch
		:

		+t/patch commit on patch
		:::t/patch
	EOT
	git checkout -f t/patch &&
	tg export e/patch &&
	subj="$(getsubj e/patch)" &&
	test z"$subj" = z"just a patch"
'

test_expect_success 'fsck' '
	git fsck --no-progress --no-dangling
'

test_expect_success 'bad modes' '
	git checkout -f t/patch &&
	test_must_fail tg export -s bad no-such-branch &&
	test_must_fail tg export -s tg -s bad no-such-branch &&
	test_must_fail tg -c topgit.subjectmode=keep export -s bad no-such-branch &&
	test_must_fail tg -c topgit.subjectmode=bad export no-such-branch
'

test_expect_success 'strip patch sp' '
	tg_test_create_branches <<-EOT &&
		t/patchsp [PATCH ] [PATCH] just a patch sp
		:

		+t/patchsp commit on patchsp
		:::t/patchsp
	EOT
	git checkout -f t/patchsp &&
	tg export e/patchsp &&
	subj="$(getsubj e/patchsp)" &&
	test z"$subj" = z"[PATCH] just a patch sp"
'
test_expect_success 'strip patch tab' '
	tg_test_create_branches <<-EOT &&
		t/patchtab [PATCH	] [PATCH] just a patch tab
		:

		+t/patchtab commit on patchtab
		:::t/patchtab
	EOT
	git checkout -f t/patchtab &&
	striptopsubj &&
	printf "%s\n" "SuBjEcT: 	[PATCH	] [PATCH]	just a patch tab 	" >>.topmsg &&
	git commit -m "fuss with .topmsg" .topmsg &&
	tg export e/patchtab &&
	subj="$(getsubj e/patchtab)" &&
	test z"$subj" = z"[PATCH] just a patch tab"
'

test_expect_success 'strip patch x' '
	tg_test_create_branches <<-EOT &&
		t/patchx [PATCHx] [PATCH] just a patch x
		:

		+t/patchx commit on patchx
		:::t/patchx
	EOT
	git checkout -f t/patchx &&
	tg export e/patchx &&
	subj="$(getsubj e/patchx)" &&
	test z"$subj" = z"[PATCH] just a patch x"
'

test_expect_success 'strip patch stuff' '
	tg_test_create_branches <<-EOT &&
		t/patchstuff [pAtChX stuff goes here ] [PATCH] just a patch stuff
		:

		+t/patchstuff commit on patchstuff
		:::t/patchstuff
	EOT
	git checkout -f t/patchstuff &&
	tg export e/patchstuff &&
	subj="$(getsubj e/patchstuff)" &&
	test z"$subj" = z"[PATCH] just a patch stuff"
'

test_expect_success 'strip pfx patch' '
	tg_test_create_branches <<-EOT &&
		t/pfxpatch [RFC/PATCH] just a pfxpatch
		:

		+t/pfxpatch commit on pfxpatch
		:::t/pfxpatch
	EOT
	git checkout -f t/pfxpatch &&
	tg -c topgit.subjectPrefix=XFc/ export e/pfxpatch &&
	subj="$(getsubj e/pfxpatch)" &&
	test z"$subj" = z"[RFC/PATCH] just a pfxpatch" &&
	tg -c topgit.subjectPrefix=rFc/ export --force e/pfxpatch &&
	subj="$(getsubj e/pfxpatch)" &&
	test z"$subj" = z"just a pfxpatch"
'

test_expect_success 'strip pfx patch sp' '
	tg_test_create_branches <<-EOT &&
		t/pfxpatchsp [BUG PATCH ] [PATCH] just a pfxpatch sp
		:

		+t/pfxpatchsp commit on pfxpatchsp
		:::t/pfxpatchsp
	EOT
	git checkout -f t/pfxpatchsp &&
	tg export e/pfxpatchsp &&
	subj="$(getsubj e/pfxpatchsp)" &&
	test z"$subj" = z"[BUG PATCH ] [PATCH] just a pfxpatch sp" &&
	tg -c topgit.subjectPrefix=Bug export --force e/pfxpatchsp &&
	subj="$(getsubj e/pfxpatchsp)" &&
	test z"$subj" = z"[PATCH] just a pfxpatch sp"
'

test_expect_success 'strip pfx patch tab' '
	tg_test_create_branches <<-EOT &&
		t/pfxpatchtab [DoxPATCH	] [PATCH] just a pfxpatch tab
		:

		+t/pfxpatchtab commit on pfxpatchtab
		:::t/pfxpatchtab
	EOT
	git checkout -f t/pfxpatchtab &&
	striptopsubj &&
	printf "%s\n" "SuBjEcT: 	[DoxPATCH	] [PATCH]	just a pfxpatch tab 	" >>.topmsg &&
	git commit -m "fuss with .topmsg" .topmsg &&
	tg export e/pfxpatchtab &&
	subj="$(getsubj e/pfxpatchtab)" &&
	test z"$subj" = z"[DoxPATCH ] [PATCH] just a pfxpatch tab" &&
	tg -c topgit.subjectprefix=doX export --force e/pfxpatchtab &&
	subj="$(getsubj e/pfxpatchtab)" &&
	test z"$subj" = z"[PATCH] just a pfxpatch tab"
'

test_expect_success 'strip pfx patch x' '
	tg_test_create_branches <<-EOT &&
		t/pfxpatchx [?PATCHx] [PATCH] just a pfxpatch x
		:

		+t/pfxpatchx commit on pfxpatchx
		:::t/pfxpatchx
	EOT
	git checkout -f t/pfxpatchx &&
	tg export e/pfxpatchx &&
	subj="$(getsubj e/pfxpatchx)" &&
	test z"$subj" = z"[?PATCHx] [PATCH] just a pfxpatch x" &&
	tg -c topgit.subjectprefix="?" export --force e/pfxpatchx &&
	subj="$(getsubj e/pfxpatchx)" &&
	test z"$subj" = z"[PATCH] just a pfxpatch x"
'

test_expect_success 'strip pfx patch stuff' '
	tg_test_create_branches <<-EOT &&
		t/pfxpatchstuff [-  pAtChX stuff goes here ] [PATCH] just a pfxpatch stuff
		:

		+t/pfxpatchstuff commit on pfxpatchstuff
		:::t/pfxpatchstuff
	EOT
	git checkout -f t/pfxpatchstuff &&
	tg export e/pfxpatchstuff &&
	subj="$(getsubj e/pfxpatchstuff)" &&
	test z"$subj" = z"[- pAtChX stuff goes here ] [PATCH] just a pfxpatch stuff" &&
	tg -c topgit.sUbJECtPREfix=- export --force e/pfxpatchstuff &&
	subj="$(getsubj e/pfxpatchstuff)" &&
	test z"$subj" = z"[PATCH] just a pfxpatch stuff"
'

test_expect_success 'strip multi patch' '
	tg_test_create_branches <<-EOT &&
		t/patchmulti [PATCH] [PATCH] [PATCH] just a multi-patch
		:

		+t/patchmulti commit on patchmulti
		:::t/patchmulti
	EOT
	git checkout -f t/patchmulti &&
	tg -c topgit.subjectmode=mailinfo export e/patchmulti &&
	subj="$(getsubj e/patchmulti)" &&
	test z"$subj" = z"just a multi-patch"
'

test_expect_success 'strip multi brackets' '
	tg_test_create_branches <<-EOT &&
		t/multi [PATCH] [PATCHv2] [PATCHv3 1/2] [OTHER] [tag] [whatever] [here] just a mess
		:

		+t/multi commit on multi
		:::t/multi
	EOT
	git checkout -f t/multi &&
	tg export -s mailinfo e/multi &&
	subj="$(getsubj e/multi)" &&
	test z"$subj" = z"just a mess"
'

test_expect_success 'strip multi brackets only' '
	tg_test_create_branches <<-EOT &&
		t/multistop [PATCH] [PATCHv2] [PATCHv3 1/2] [OTHER] stop [tag] [whatever] [here] just a mess
		:

		+t/multistop commit on multistop
		:::t/multistop
	EOT
	git checkout -f t/multistop &&
	tg -c topgit.subjectmode=keep export -s mailinfo e/multistop &&
	subj="$(getsubj e/multistop)" &&
	test z"$subj" = z"stop [tag] [whatever] [here] just a mess"
'

test_expect_success 'strip clean subject 1' '
	tg_test_create_branches <<-EOT &&
		t/cleanup [ M E S S ] j  usta   m  e ss
		:

		+t/cleanup commit on cleanup
		:::t/cleanup
	EOT
	git checkout -f t/cleanup &&
	striptopsubj &&
	printf "%s\n" "SuBjEcT:     [Some]    [  M e s ]   here  it  is   " >>.topmsg &&
	git commit -m "fuss with .topmsg" .topmsg &&
	tg export -s keep -s mailinfo e/cleanup &&
	subj="$(getsubj e/cleanup)" &&
	test z"$subj" = z"here it is"
'

test_expect_success 'strip clean subject 2' '
	tg_test_create_branches <<-EOT &&
		t/cleanuptoo [ M E S S ] j  usta   m  e ss
		:

		+t/cleanuptoo commit on cleanuptoo
		:::t/cleanuptoo
	EOT
	git checkout -f t/cleanuptoo &&
	striptopsubj &&
	printf "%s\n" "SuBjEcT:      	:[Some]    [  M e s ] 	  here  it  is   " >>.topmsg &&
	git commit -m "fuss with .topmsg" .topmsg &&
	tg export -s mailinfo e/cleanuptoo &&
	subj="$(getsubj e/cleanuptoo)" &&
	test z"$subj" = z"here it is"
'

test_expect_success 'strip clean not a subject' '
	tg_test_create_branches <<-EOT &&
		t/cleanupnada [ M E S S ] j  usta   m  e ss
		:

		+t/cleanupnada commit on cleanupnada
		:::t/cleanupnada
	EOT
	git checkout -f t/cleanupnada &&
	striptopsubj &&
	# keywords are only valid when the ":" is attached to them w/o whitespace
	# that means there is no subject and in that case the subject is expected
	# to default to the TopGit branch name NOT the first line of .topmsg!
	printf "%s\n" "SuBjEcT      :[Some]    [  M e s ]   here  it  is   " >>.topmsg &&
	git commit -m "fuss with .topmsg" .topmsg &&
	tg export -s mailinfo e/cleanupnada &&
	subj="$(getsubj e/cleanupnada)" &&
	test z"$subj" = z"t/cleanupnada"
'

test_expect_success 'strip clean cfws subject' '
	tg_test_create_branches <<-EOT &&
		t/cfws [l8r] fill in
		:

		+t/cfws commit on cfws
		:::t/cfws
	EOT
	git checkout -f t/cfws &&
	striptopsubj &&
	printf "%s\n" "SUBject: [Patch]" " [Me]" " First off:" " this should (not?) work " >>.topmsg &&
	git commit -m "fuss with .topmsg" .topmsg &&
	tg export -s mailinfo e/cfws &&
	subj="$(getsubj e/cfws)" &&
	test z"$subj" = z"First off: this should (not?) work"
'

test_expect_success 'keep subject' '
	tg_test_create_branches <<-EOT &&
		t/keep [PATCH]	[ M E S S ] j  usta   m  e ss
		:

		+t/keep commit on keep
		:::t/keep
	EOT
	git checkout -f t/keep &&
	striptopsubj &&
	printf "%s\n" "subject:     	 	 :[Some]  	  [  M e s ] 	  here  it  is  	 " >>.topmsg &&
	git commit -m "fuss with .topmsg" .topmsg &&
	tg export -s keep e/keep &&
	subj="$(getsubj e/keep)" &&
	test z"$subj" = z":[Some]  	  [  M e s ] 	  here  it  is"
'

test_expect_success 'trim subject' '
	tg_test_create_branches <<-EOT &&
		t/trim [PATCH]	[ M E S S ] j  usta   m  e ss
		:

		+t/trim commit on trim
		:::t/trim
	EOT
	git checkout -f t/trim &&
	striptopsubj &&
	printf "%s\n" "subject:     	 	 :[Some]  	  [  M	e s ] 	  here  it  is  	 " >>.topmsg &&
	git commit -m "fuss with .topmsg" .topmsg &&
	tg export -s trim e/trim &&
	tg export -s ws e/ws &&
	subj="$(getsubj e/trim)" &&
	test z"$subj" = z":[Some] [ M e s ] here it is" &&
	subj="$(getsubj e/ws)" &&
	test z"$subj" = z":[Some] [ M e s ] here it is"
'

test_expect_success 'patch mode just one' '
	tg_test_create_branches <<-EOT &&
		t/patch1 [PATCH] just a patch
		:

		+t/patch1 commit on patch1
		:::t/patch1
	EOT
	git checkout -f t/patch1 &&
	tg export -s patch e/patch1 &&
	subj="$(getsubj e/patch1)" &&
	test z"$subj" = z"just a patch" &&
	tg -c topgit.subjectPrefix=xyz export --force -s patch e/patch1 &&
	subj="$(getsubj e/patch1)" &&
	test z"$subj" = z"just a patch" &&
	tg export --force -s tg e/patch1 &&
	subj="$(getsubj e/patch1)" &&
	test z"$subj" = z"just a patch" &&
	tg -c topgit.subjectPrefix=xyz export --force -s tg e/patch1 &&
	subj="$(getsubj e/patch1)" &&
	test z"$subj" = z"just a patch"
'

test_expect_success 'patch mode just one prefixed' '
	tg_test_create_branches <<-EOT &&
		t/patch_xyz [XyZ pAtCh] just a patch
		:

		+t/patch_xyz commit on patch_xyz
		:::t/patch_xyz
	EOT
	git checkout -f t/patch_xyz &&
	tg export -s patch e/patch_xyz &&
	subj="$(getsubj e/patch_xyz)" &&
	test z"$subj" = z"[XyZ pAtCh] just a patch" &&
	tg -c topgit.subjectPrefix=xyz export --force -s patch e/patch_xyz &&
	subj="$(getsubj e/patch_xyz)" &&
	test z"$subj" = z"just a patch" &&
	tg export --force -s topgit e/patch_xyz &&
	subj="$(getsubj e/patch_xyz)" &&
	test z"$subj" = z"[XyZ pAtCh] just a patch" &&
	tg -c topgit.subjectPrefix=xyz export --force -s topgit e/patch_xyz &&
	subj="$(getsubj e/patch_xyz)" &&
	test z"$subj" = z"just a patch"
'

test_expect_success 'patch mode just one prefixed no space' '
	tg_test_create_branches <<-EOT &&
		t/patchxyz [XyZpAtCh] just a patch
		:

		+t/patchxyz commit on patchxyz
		:::t/patchxyz
	EOT
	git checkout -f t/patchxyz &&
	tg export -s patch e/patchxyz &&
	subj="$(getsubj e/patchxyz)" &&
	test z"$subj" = z"[XyZpAtCh] just a patch" &&
	tg -c topgit.subjectPrefix=xyz export --force -s patch e/patchxyz &&
	subj="$(getsubj e/patchxyz)" &&
	test z"$subj" = z"just a patch" &&
	tg export --force e/patchxyz &&
	subj="$(getsubj e/patchxyz)" &&
	test z"$subj" = z"[XyZpAtCh] just a patch" &&
	tg -c topgit.subjectPrefix=xyz export --force e/patchxyz &&
	subj="$(getsubj e/patchxyz)" &&
	test z"$subj" = z"just a patch"
'

test_expect_success 'patch mode non first' '
	tg_test_create_branches <<-EOT &&
		t/patchl8r not [PATCH] just a patch
		:

		+t/patchl8r commit on patchl8r
		:::t/patchl8r
	EOT
	git checkout -f t/patchl8r &&
	tg export -s patch e/patchl8r &&
	subj="$(getsubj e/patchl8r)" &&
	test z"$subj" = z"not [PATCH] just a patch" &&
	tg export --force e/patchl8r &&
	subj="$(getsubj e/patchl8r)" &&
	test z"$subj" = z"not [PATCH] just a patch"
'

test_expect_success 'patch mode just first' '
	tg_test_create_branches <<-EOT &&
		t/patch2 [pAtCh]   [PATCH]  just	a	patch
		:

		+t/patch2 commit on patch2
		:::t/patch2
	EOT
	git checkout -f t/patch2 &&
	tg export -s patch e/patch2 &&
	subj="$(getsubj e/patch2)" &&
	test z"$subj" = z"[PATCH] just a patch" &&
	git checkout -f t/patch2 &&
	tg export --force e/patch2 &&
	subj="$(getsubj e/patch2)" &&
	test z"$subj" = z"[PATCH] just a patch"
'

test_expect_success 'topgit mode stage' '
	tg_test_create_branches <<-EOT &&
		t/stage [STAGE] just a patch
		:

		+t/stage commit on stage
		:::t/stage
	EOT
	git checkout -f t/stage &&
	tg export -s patch e/stage &&
	subj="$(getsubj e/stage)" &&
	test z"$subj" = z"[STAGE] just a patch" &&
	tg export --force e/stage &&
	subj="$(getsubj e/stage)" &&
	test z"$subj" = z"just a patch"
'

test_expect_success 'topgit mode pfx stage' '
	tg_test_create_branches <<-EOT &&
		t/pfxstage [PSTAGE] just a pfxpatch
		:

		+t/pfxstage commit on pfxstage
		:::t/pfxstage
	EOT
	git checkout -f t/pfxstage &&
	tg export e/pfxstage &&
	subj="$(getsubj e/pfxstage)" &&
	test z"$subj" = z"[PSTAGE] just a pfxpatch" &&
	tg -c topgit.subjectprefix=p export --force -s patch e/pfxstage &&
	subj="$(getsubj e/pfxstage)" &&
	test z"$subj" = z"[PSTAGE] just a pfxpatch" &&
	tg -c topgit.subjectprefix=p export --force e/pfxstage &&
	subj="$(getsubj e/pfxstage)" &&
	test z"$subj" = z"just a pfxpatch"
'

test_expect_success 'topgit mode stage sp' '
	tg_test_create_branches <<-EOT &&
		t/stagesp [STAGE ] just a patch sp
		:

		+t/stagesp commit on stagesp
		:::t/stagesp
	EOT
	git checkout -f t/stagesp &&
	tg export e/stagesp &&
	subj="$(getsubj e/stagesp)" &&
	test z"$subj" = z"[STAGE ] just a patch sp"
'

test_expect_success 'topgit mode base' '
	tg_test_create_branches <<-EOT &&
		t/base [BASE] just a patch
		:

		+t/base commit on base
		:::t/base
	EOT
	git checkout -f t/base &&
	tg export -s patch e/base &&
	subj="$(getsubj e/base)" &&
	test z"$subj" = z"[BASE] just a patch" &&
	tg export --force e/base &&
	subj="$(getsubj e/base)" &&
	test z"$subj" = z"just a patch"
'

test_expect_success 'topgit mode pfx base' '
	tg_test_create_branches <<-EOT &&
		t/pfxbase [PBASE] just a pfxpatch
		:

		+t/pfxbase commit on pfxbase
		:::t/pfxbase
	EOT
	git checkout -f t/pfxbase &&
	tg export e/pfxbase &&
	subj="$(getsubj e/pfxbase)" &&
	test z"$subj" = z"[PBASE] just a pfxpatch" &&
	tg -c topgit.subjectprefix=p export --force -s patch e/pfxbase &&
	subj="$(getsubj e/pfxbase)" &&
	test z"$subj" = z"[PBASE] just a pfxpatch" &&
	tg -c topgit.subjectprefix=p export --force e/pfxbase &&
	subj="$(getsubj e/pfxbase)" &&
	test z"$subj" = z"just a pfxpatch"
'

test_expect_success 'topgit mode base sp' '
	tg_test_create_branches <<-EOT &&
		t/basesp [BASE ] just a patch sp
		:

		+t/basesp commit on basesp
		:::t/basesp
	EOT
	git checkout -f t/basesp &&
	tg export e/basesp &&
	subj="$(getsubj e/basesp)" &&
	test z"$subj" = z"[BASE ] just a patch sp"
'

test_expect_success 'topgit mode release' '
	tg_test_create_branches <<-EOT &&
		t/release [RELEASE] just a patch
		:

		+t/release commit on release
		:::t/release
	EOT
	git checkout -f t/release &&
	tg export -s patch e/release &&
	subj="$(getsubj e/release)" &&
	test z"$subj" = z"[RELEASE] just a patch" &&
	tg export --force e/release &&
	subj="$(getsubj e/release)" &&
	test z"$subj" = z"just a patch"
'

test_expect_success 'topgit mode pfx release' '
	tg_test_create_branches <<-EOT &&
		t/pfxrelease [PRELEASE] just a pfxrelease
		:

		+t/pfxrelease commit on pfxrelease
		:::t/pfxrelease
	EOT
	git checkout -f t/pfxrelease &&
	tg export e/pfxrelease &&
	subj="$(getsubj e/pfxrelease)" &&
	test z"$subj" = z"[PRELEASE] just a pfxrelease" &&
	tg -c topgit.subjectprefix=p export --force -s patch e/pfxrelease &&
	subj="$(getsubj e/pfxrelease)" &&
	test z"$subj" = z"[PRELEASE] just a pfxrelease" &&
	tg -c topgit.subjectprefix=p export --force e/pfxrelease &&
	subj="$(getsubj e/pfxrelease)" &&
	test z"$subj" = z"just a pfxrelease"
'

test_expect_success 'topgit mode release sp' '
	tg_test_create_branches <<-EOT &&
		t/releasesp [RELEASE ] just a release sp
		:

		+t/releasesp commit on releasesp
		:::t/releasesp
	EOT
	git checkout -f t/releasesp &&
	tg export e/releasesp &&
	subj="$(getsubj e/releasesp)" &&
	test z"$subj" = z"[RELEASE ] just a release sp"
'

test_expect_success 'topgit mode root' '
	tg_test_create_branches <<-EOT &&
		t/root [ROOT] just a patch
		:

		+t/root commit on root
		:::t/root
	EOT
	git checkout -f t/root &&
	tg export -s patch e/root &&
	subj="$(getsubj e/root)" &&
	test z"$subj" = z"[ROOT] just a patch" &&
	tg export --force e/root &&
	subj="$(getsubj e/root)" &&
	test z"$subj" = z"just a patch"
'

test_expect_success 'topgit mode pfx root' '
	tg_test_create_branches <<-EOT &&
		t/pfxroot [PROOT] just a pfxpatch
		:

		+t/pfxroot commit on pfxroot
		:::t/pfxroot
	EOT
	git checkout -f t/pfxroot &&
	tg export e/pfxroot &&
	subj="$(getsubj e/pfxroot)" &&
	test z"$subj" = z"[PROOT] just a pfxpatch" &&
	tg -c topgit.subjectprefix=p export --force -s patch e/pfxroot &&
	subj="$(getsubj e/pfxroot)" &&
	test z"$subj" = z"[PROOT] just a pfxpatch" &&
	tg -c topgit.subjectprefix=p export --force e/pfxroot &&
	subj="$(getsubj e/pfxroot)" &&
	test z"$subj" = z"just a pfxpatch"
'

test_expect_success 'topgit mode root sp' '
	tg_test_create_branches <<-EOT &&
		t/rootsp [ROOT ] just a patch sp
		:

		+t/rootsp commit on rootsp
		:::t/rootsp
	EOT
	git checkout -f t/rootsp &&
	tg export e/rootsp &&
	subj="$(getsubj e/rootsp)" &&
	test z"$subj" = z"[ROOT ] just a patch sp"
'

test_expect_success 'topgit mode not a patch' '
	tg_test_create_branches <<-EOT &&
		t/pnap [PATC ] not a patch
		:

		+t/pnap commit on pnap
		:::t/pnap
	EOT
	git checkout -f t/pnap &&
	tg export e/pnap &&
	subj="$(getsubj e/pnap)" &&
	test z"$subj" = z"[PATC ] not a patch"
'

test_expect_success 'topgit mode not a stage' '
	tg_test_create_branches <<-EOT &&
		t/snap [STAG] not a stage
		:

		+t/snap commit on snap
		:::t/snap
	EOT
	git checkout -f t/snap &&
	tg export e/snap &&
	subj="$(getsubj e/snap)" &&
	test z"$subj" = z"[STAG] not a stage"
'

test_expect_success 'topgit mode not a base' '
	tg_test_create_branches <<-EOT &&
		t/bnap [BASF] not a base
		:

		+t/bnap commit on bnap
		:::t/bnap
	EOT
	git checkout -f t/bnap &&
	tg export e/bnap &&
	subj="$(getsubj e/bnap)" &&
	test z"$subj" = z"[BASF] not a base"
'

test_expect_success 'topgit mode not a release' '
	tg_test_create_branches <<-EOT &&
		t/bnar [RELEASF] not a release
		:

		+t/bnar commit on bnar
		:::t/bnar
	EOT
	git checkout -f t/bnar &&
	tg export e/bnar &&
	subj="$(getsubj e/bnar)" &&
	test z"$subj" = z"[RELEASF] not a release"
'

test_expect_success 'topgit mode not a root' '
	tg_test_create_branches <<-EOT &&
		t/rnap [ROO] not a root
		:

		+t/rnap commit on rnap
		:::t/rnap
	EOT
	git checkout -f t/rnap &&
	tg export e/rnap &&
	subj="$(getsubj e/rnap)" &&
	test z"$subj" = z"[ROO] not a root"
'

test_expect_success 'wrap-up fsck' '
	git fsck --no-progress --no-dangling
'

test_done
