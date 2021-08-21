#!/bin/sh

test_description='wayback export'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 12

topbases="$(tg --top-bases)" && [ -n "$topbases" ] || die 'no --top-bases!'

test_expect_success 'setup' '
	test_create_repo patches &&
	cd patches &&
	tg_test_create_branch patch -m "the patch" : &&
	git checkout -f patch &&
	git tag patchbase &&
	test_commit "the patch v1" "patchfile" "first version of patch" patchv1 &&
	tg_test_create_tag t/first refs/heads/patch "$topbases/patch" &&
	git diff-tree -p HEAD^! >../patch1.patch &&
	git patch-id <../patch1.patch >../patch1.id &&
	tg patch patch >../patch1.tgpatch &&
	git patch-id <../patch1.tgpatch >../patch1.tgid &&
	test_diff ../patch1.id ../patch1.tgid &&
	printf "%s\n" "alternate patch" "I like this better" >patchfile &&
	git add patchfile &&
	test_tick &&
	git commit -m "new alternate patch" &&
	git diff patchbase HEAD >../patch2.patch &&
	git patch-id <../patch2.patch >../patch2.id &&
	tg patch patch >../patch2.tgpatch &&
	git patch-id <../patch2.tgpatch >../patch2.tgid &&
	test_diff ../patch2.id ../patch2.tgid &&
	git tag patchv2 &&
	cd .. &&
	git clone --mirror --no-shared patches patches.git
'

# this test is supposed to be about export, but export will end up calling
# patch for --linearize and --quilt modes so we test it first some more

test_expect_success 'patch first' '
	tg -C patches -w t/first patch patch >p1 &&
	git -C patches patch-id <p1 >p1.id &&
	test_diff patch1.id p1.id
'

test_expect_success 'patch second' '
	tg -C patches -w : patch patch >p2 &&
	git -C patches patch-id <p2 >p2.id &&
	test_diff patch2.id p2.id
'

# on to the export tests

test_expect_success 'tg export --linearize bare no go' '
	test_must_fail tg -C patches.git export --linearize out
'

test_expect_success 'tg export --collapse bare ok' '
	tg -C patches.git export --collapse out &&
	git -C patches.git diff-tree -p out^! >co.patch &&
	git -C patches.git patch-id <co.patch >co.id &&
	test_diff co.id patch2.id &&
	git -C patches.git update-ref -d refs/heads/out out
'

test_expect_success 'tg export --quilt bare ok' '
	mkdir qu &&
	tg -C patches.git export --quilt "$PWD/qu" &&
	git -C patches.git patch-id <qu/patch.diff >qu.id &&
	test_diff qu.id patch2.id
'

# now the "wayback" tests

test_expect_success 'tg export --collapse wayback first' '
	tg -C patches.git -w t/first export --collapse out &&
	git -C patches.git diff-tree -p out^! >wc1.patch &&
	git -C patches.git patch-id <wc1.patch >wc1.id &&
	test_diff wc1.id patch1.id &&
	git -C patches.git update-ref -d refs/heads/out out
'

test_expect_success 'tg export --collapse wayback second' '
	tg -C patches.git -w : export --collapse out &&
	git -C patches.git diff-tree -p out^! >wc2.patch &&
	git -C patches.git patch-id <wc2.patch >wc2.id &&
	test_diff wc2.id patch2.id &&
	git -C patches.git update-ref -d refs/heads/out out
'

test_expect_success 'tg export --linearize wayback first' '
	tg -C patches.git -w t/first export --linearize out &&
	git -C patches.git diff-tree -p out^! >wl1.patch &&
	git -C patches.git patch-id <wl1.patch >wl1.id &&
	test_diff wl1.id patch1.id &&
	git -C patches.git update-ref -d refs/heads/out out
'

test_expect_success 'tg export --linearize wayback second' '
	tg -C patches.git -w : export --linearize out &&
	git -C patches.git diff-tree -p out^! >wl2.patch &&
	git -C patches.git patch-id <wl2.patch >wl2.id &&
	test_diff wl2.id patch2.id &&
	git -C patches.git update-ref -d refs/heads/out out
'

test_expect_success 'tg export --quilt wayback first' '
	tg -C patches.git -w t/first export --quilt "$PWD/qu1" &&
	git -C patches.git patch-id <qu1/patch.diff >qu1.id &&
	test_diff qu1.id patch1.id
'

test_expect_success 'tg export --quilt wayback second' '
	tg -C patches.git -w : export --quilt "$PWD/qu2" &&
	git -C patches.git patch-id <qu2/patch.diff >qu2.id &&
	test_diff qu2.id patch2.id
'

test_done
