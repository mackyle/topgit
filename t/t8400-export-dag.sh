#!/bin/sh

test_description='test TopGit DAG exports (all 3 types)'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 5

tg_test_remote=yeehaw

test_expect_success 'setup' '
	test_create_repo thedag && cd thedag &&
	git config remote.yeehaw.url "." &&
	git config topgit.remote yeehaw &&
	git checkout --orphan lonesome &&
	git read-tree --empty &&
	test_tick &&
	git commit --allow-empty -m "lonesome empty place" &&
	git reset --hard &&
	tg_test_create_branches <<-EOT &&
		::release [RELEASE] build upon this
		lonesome

		+release some release commit
		:::release

		::first [PATCH] first level patch
		release

		+first commit on first
		:::first

		::second [PATCH] second first level patch
		release

		+second commit on second
		:::second

		::third [PATCH] third second level patch
		second

		+third commit on third
		:::third

		::fourth [PATCH] fourth first level patch
		release

		+fourth commit on fourth
		:::fourth

		::stage [STAGE] staging branch here
		release
		first
		third
		fourth
	EOT
	git symbolic-ref HEAD "$(tg --top-bases)/stage" &&
	git reset --hard &&
	git rm --force --ignore-unmatch -- .topmsg .topdeps &&
	git read-tree -m HEAD first &&
	git rm --force --ignore-unmatch -- .topmsg .topdeps &&
	git read-tree -m HEAD third &&
	git rm --force --ignore-unmatch -- .topmsg .topdeps &&
	git read-tree -m HEAD fourth &&
	git rm --force --ignore-unmatch -- .topmsg .topdeps &&
	newtree="$(git write-tree)" && test -n "$newtree" &&
	test_tick &&
	newcommit="$(git commit-tree -p HEAD -p first -p third -p fourth -m "mighty octopus" "$newtree")" &&
	test -n "$newcommit" && git update-ref HEAD "$newcommit" HEAD &&
	git checkout -f stage &&
	test_tick &&
	git merge -m "bases up" "$(tg --top-bases)/stage"
'

baretree="$(tg_test_bare_tree -C thedag stage)" || die "missing bare stage tree"

test_expect_success 'export --collapse' '
	cd thedag &&
	git checkout -f stage &&
	tg export --collapse collapse &&
	test_cmp_rev $baretree collapse^{tree}
'

test_expect_success 'export --linearize' '
	cd thedag &&
	git checkout -f stage &&
	tg export --linearize linearize &&
	test_cmp_rev $baretree linearize^{tree}
'

test_expect_success 'export --quilt' '
	git -C thedag checkout -f stage &&
	tg -C thedag export --quilt --strip --numbered "$PWD/quilt"
'

test_expect_success 'import quilt patches' '
	cd thedag &&
	git checkout -f -b quilt lonesome &&
	git am ../quilt/000*.diff &&
	test_cmp_rev $baretree quilt^{tree}
'

test_done
