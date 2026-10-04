#!/bin/sh

test_description='index cache-tree objects survive read-only TopGit commands

Regression for issue #26. Writing index trees into the temporary object store
leaves the index cache-tree referring to objects removed when tg exits.
'

. ./test-lib.sh

test_plan 3

test_expect_success 'setup indexed change on a topic branch' '
	test_commit initial tracked seed &&
	tg create --no-edit t/topic &&
	echo "indexed change" >tracked &&
	git add tracked
'

test_expect_success LASTOK 'files -i leaves a valid cached index tree' '
	echo tracked >expected &&
	tg files -i >actual &&
	test_cmp expected actual &&
	tree="$(git write-tree)" &&
	git cat-file -e "$tree^{tree}"
'

test_expect_success LASTOK 'later worktree and indexed patch commands succeed' '
	tg files -w >actual &&
	test_cmp expected actual &&
	tg patch -i >patch &&
	grep -q "indexed change" patch &&
	tg patch -w >patch &&
	grep -q "indexed change" patch
'

test_done
