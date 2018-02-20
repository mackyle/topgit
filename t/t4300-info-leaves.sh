#!/bin/sh

test_description='test tg info --leaves functionality'

. ./test-lib.sh

test_plan 11

test_expect_success 'setup' '
	tg_test_create_branches <<-EOT &&
		one
		:::

		two
		:::

		three
		:::

		two-plus-two
		:::two

		+two-plus-two
		:::two-plus-two

		four
		:::

		+four
		:::four

		t/base-four-up-up
		:four

		+four
		:::four

		t/base-four-up
		:four

		+four
		:::four

		t/one
		one

		t/two
		two

		t/three
		three

		t/two-deps
		one
		two

		t/three-deps
		one
		two
		three

		t/three-two
		t/three
		t/two

		whatever
		:::

		t/annihilated
		whatever

		t/complex
		two-plus-two
		one
		t/base-four-up
		t/three-two

		t/complex-too
		two-plus-two
		one
		t/annihilated
		t/base-four-up
		t/three-two
	EOT
	newcmt="$(git commit-tree -m annihilate $(tg base t/annihilated)^{tree})" &&
	git update-ref refs/heads/t/annihilated "$newcmt" refs/heads/t/annihilated &&
	git tag four-tagged-light four^^ &&
	git tag -am tagged four-tagged four^ &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'one leaf' '
	echo refs/heads/one >expected &&
	tg info --leaves t/one >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'two leaf' '
	echo refs/heads/two >expected &&
	tg info --leaves t/two >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'three leaf' '
	echo refs/heads/three >expected &&
	tg info --leaves t/three >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'two leaves' '
	echo refs/heads/one >expected &&
	echo refs/heads/two >>expected &&
	tg info --leaves t/two-deps >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'three leaves' '
	echo refs/heads/one >expected &&
	echo refs/heads/two >>expected &&
	echo refs/heads/three >>expected &&
	tg info --leaves t/three-deps >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'two leaves backwards' '
	echo refs/heads/three >expected &&
	echo refs/heads/two >>expected &&
	tg info --leaves t/three-two >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'one lightweight base' '
	echo "$(tg --top-bases)/t/base-four-up-up" >expected &&
	tg info --leaves t/base-four-up-up >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'one annotated base' '
	echo refs/tags/four-tagged >expected &&
	tg info --leaves t/base-four-up >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'complex leaves' '
	cat <<-EOT >expected-complex &&
		refs/heads/two-plus-two
		refs/heads/one
		refs/tags/four-tagged
		refs/heads/three
		refs/heads/two
	EOT
	test_when_finished test_set_prereq EXPCMPX &&
	tg info --leaves t/complex >actual &&
	test_cmp actual expected-complex
'

test_expect_success 'SETUP EXPCMPX' 'complex leaves w/o annihilated' '
	test -s expected-complex &&
	tg info --leaves t/complex-too >actual &&
	test_cmp actual expected-complex
'

test_done
