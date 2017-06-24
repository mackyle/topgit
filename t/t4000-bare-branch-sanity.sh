#!/bin/sh

test_description='make sure bare branches show up'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

obj_count() {
	set -- $(git -C "${1:-.}" count-objects) || die git count-objects failed
	test z"${1%%[!0-9]*}" != z || die git count-objects returned nothing
	echo "${1%%[!0-9]*}"
}

test_plan 18

test_expect_success 'setup r0 (contains empty blob and tree)' '
	test_create_repo r0 && cd r0 &&
	tg_test_create_branches <<-EOT &&
		t/begin start here
		:
		
		t/branch use the base
		t/begin
		boo
		
		boo bare branch
		::
	EOT
	git checkout -f t/begin &&
	test_commit hi &&
	git checkout -f t/branch &&
	test_commit gotit &&
	git checkout -f boo &&
	test_commit "boo boo" &&
	git checkout --orphan unborn &&
	git read-tree --empty &&
	git clean -d -x -f
'

test_expect_success 'setup r1 (does not contain empty blob or tree)' '
	test_create_repo r1 && cd r1 &&
	test_commit initial &&
	git checkout --orphan barely &&
	git read-tree --empty &&
	git clean -d -x -f &&
	test_commit bare^commit &&
	tg_test_create_branches <<-EOT &&
		t/begin start here
		:~master
		
		t/branch use the base
		t/begin
		boo
		
		boo bare branch
		::barely
	EOT
	git checkout -f t/begin &&
	test_commit hi &&
	git checkout -f t/branch &&
	test_commit gotit &&
	git checkout -f boo &&
	test_commit "boo boo" &&
	git checkout --orphan unborn &&
	git read-tree --empty &&
	git clean -d -x -f
'

test_expect_success 'setup r2 (read-only copy of r1)' '
	{ [ -d r1 ] || die missing setup r1 repo; } &&
	{ [ ! -e r2 ] || chmod -R u+rw r2; } &&
	rm -rf r2 &&
	cp -pR r1 r2 &&
	chmod -R a-w r2
'

# should have same results whether empty blob and tree object are present or not
# r2 is a read-only copy of r1 to make things more challenging

for repo in r0 r1 r2; do

test_expect_success "($repo) "'tg summary --rdeps --heads' '
	printf "%s" "\
t/branch
  t/begin
  boo
" > expected &&
	tg -C $repo summary --rdeps --heads > actual &&
	test_diff expected actual
'

test_expect_success "($repo) "'tg summary --list' '
	printf "%s" "\
boo
t/begin
t/branch
" > expected &&
	tg -C $repo summary --list > actual &&
	test_diff expected actual
'

test_expect_success "($repo) "'tg summary --verbpse --list' '
	ocntb="$(obj_count $repo)" &&
	printf "%s" "\
boo branch boo (bare branch)
t/begin [PATCH] start here
t/branch [PATCH] use the base
" > expected &&
	tg -C $repo summary --verbose --list > actual.raw &&
	tab="	" && # a single tab in there
	< actual.raw tr -s "$tab" " " > actual &&
	test_diff expected actual &&
	ocnta="$(obj_count $repo)" &&
	test $ocntb -eq $ocnta
'

test_expect_success "($repo) "'tg summary' '
	printf "%s" "\
 * boo branch boo (bare branch)
 * t/begin [PATCH] start here
 D t/branch [PATCH] use the base
" > expected &&
	tg -C $repo summary > actual.raw &&
	tab="	" && # a single tab in there
	< actual.raw tr -s "$tab" " " > actual &&
	test_diff expected actual
'

test_expect_success "($repo) "'tg info --series' '
	tab="	" && # a single tab in there
	printf "%s" "\
* t/begin [PATCH] start here
 boo branch boo (bare branch)
 t/branch [PATCH] use the base
" > expected &&
	tg -C $repo info --series t/begin > actual.raw &&
	< actual.raw tr -s "$tab" " " > actual &&
	test_diff expected actual &&
	printf "%s" "\
 t/begin [PATCH] start here
* boo branch boo (bare branch)
 t/branch [PATCH] use the base
" > expected &&
	tg -C $repo info --series boo > actual.raw &&
	< actual.raw tr -s "$tab" " " > actual &&
	test_diff expected actual &&
	printf "%s" "\
t/begin [PATCH] start here
boo branch boo (bare branch)
t/branch [PATCH] use the base
" > expected &&
	tg -C $repo info --series t/branch > actual.raw &&
	< actual.raw tr -s "$tab" " " > actual &&
	test_diff expected actual
'

done

test_done
