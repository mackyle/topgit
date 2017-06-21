#!/bin/sh

test_description='test export subject handling'

. ./test-lib.sh

test_plan 8

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

test_expect_success 'strip multi patch' '
	tg_test_create_branches <<-EOT &&
		t/patchmulti [PATCH] [PATCH] [PATCH] just a multi-patch
		:

		+t/patchmulti commit on patchmulti
		:::t/patchmulti
	EOT
	git checkout -f t/patchmulti &&
	tg export e/patchmulti &&
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
	tg export e/multi &&
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
	tg export e/multistop &&
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
	tg export e/cleanup &&
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
	tg export e/cleanuptoo &&
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
	printf "%s\n" "SuBjEcT      :[Some]    [  M e s ]   here  it  is   " >>.topmsg &&
	git commit -m "fuss with .topmsg" .topmsg &&
	tg export e/cleanupnada &&
	subj="$(getsubj e/cleanupnada)" &&
	test z"$subj" = z"SuBjEcT      :[Some]    [  M e s ]   here  it  is"
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
	tg export e/cfws &&
	subj="$(getsubj e/cfws)" &&
	test z"$subj" = z"First off: this should (not?) work"
'

test_done
