#!/bin/sh

test_description='check tg tag reflog operations'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

TZ=PST8PDT && export TZ || die

if vcmp "$git_version" '>=' "2.5"; then
	test_set_prereq "GIT_2_5"
fi

git_231_plus=
if vcmp "$git_version" '>=' "2.31"; then
	git_231_plus=1
	test_set_prereq "GIT_2_31"
fi

test_plan 48

commit_empty_root() {
	_gt="$(git mktree </dev/null)" &&
	test_tick &&
	_gc="$(git commit-tree -m "$*" "$_gt")" &&
	git update-ref HEAD "$_gc" ""
}

commit_orphan() {
	_gt="$(git write-tree)" &&
	test_tick &&
	_gc="$(git commit-tree -m "$*" "$_gt")" &&
	git update-ref HEAD "$_gc" HEAD
}

# replace `git symbolic-ref HEAD refs/heads/foo`
# with `sane_reattach_ref HEAD refs/heads/foo`
sane_reattach_ref() {
	_rlc="$(git reflog show "$1" -- | wc -l)" &&
	git symbolic-ref "$1" "$2" &&
	_rlc2="$(git reflog show "$1" -- | wc -l)" &&
	if test x"$_rlc" != x"$_rlc2"; then
		git reflog delete "$1@{0}" &&
		_rlc2="$(git reflog show "$1" -- | wc -l)" &&
		test x"$_rlc" = x"$_rlc2"
	fi
}

test_expect_success 'setup main' '
	test_create_repo main &&
	cd main &&
	git config core.abbrev 8 &&
	git config log.decorate 0 &&
	commit_empty_root "empty" &&
	mtcommit="$(git rev-parse --verify HEAD)" && test -n "$mtcommit" &&
	test_when_finished mtcommit="$mtcommit" &&
	echo file1 >file1 &&
	git add file1 &&
	commit_orphan "file 1" &&
	git read-tree --empty &&
	echo file2 >file2 &&
	hash2="$(git hash-object -w --stdin -t blob <file2)" && test -n "$hash2" &&
	test_when_finished hash2="$hash2" &&
	git add file2 &&
	commit_orphan "file 2" &&
	git read-tree --empty &&
	echo file3 >file3 &&
	git add file3 &&
	commit_orphan "file 3" &&
	git read-tree --empty &&
	echo file4 >file4 &&
	git add file4 &&
	commit_orphan "file 4" &&
	c4="$(git rev-parse --verify HEAD)" && test -n "$c4" &&
	git read-tree --empty &&
	echo file5 >file5 &&
	hash5="$(git hash-object -w --stdin -t blob <file5)" && test -n "$hash5" &&
	test_when_finished hash5="$hash5" &&
	git add file5 &&
	commit_orphan "file 5" &&
	git read-tree --empty &&
	echo file6 >file6 &&
	git add file6 &&
	commit_orphan "file 6" &&
	git read-tree --empty &&
	echo file7 >file7 &&
	git add file7 &&
	commit_orphan "file 7" &&
	c7="$(git rev-parse --verify HEAD)" && test -n "$c7" &&
	git update-ref --no-deref -m "detaching to c4" HEAD "$c4" HEAD &&
	git update-ref --no-deref -m "attaching back to c7" HEAD "$c7" HEAD &&
	sane_reattach_ref HEAD refs/heads/master &&
	echo "$hash2" >objs &&
	echo "$hash5" >>objs &&
	pack="$(git pack-objects <objs .git/objects/pack/pack)" && test -n "$pack" &&
	test -s ".git/objects/pack/pack-$pack.idx" &&
	test -s ".git/objects/pack/pack-$pack.pack" &&
	git prune-packed &&
	rm objs &&
	test_when_finished objpack="pack-$pack"
'

test_expect_success 'LASTOK GIT_2_5' 'setup linked' '
	git --git-dir=main/.git worktree add --no-checkout -b linked linked "$mtcommit" &&
	cd linked &&
	# there should be a HEAD@{0} now but there probably is not
	# remove it just in case so this test does not break if it ever gets fixed
	test_might_fail git reflog delete HEAD@{0} &&
	git update-ref -d refs/heads/linked &&
	commit_empty_root "empty linked" &&
	# get rid of "magic" HEAD ref log entry added because its symref was deleted
	test_might_fail git reflog delete HEAD@{1} &&
	git read-tree --empty &&
	echo file7 >file7 &&
	git add file7 &&
	commit_orphan "file 7" &&
	git read-tree --empty &&
	echo file6 >file6 &&
	git add file6 &&
	commit_orphan "file 6" &&
	git read-tree --empty &&
	echo file5 >file5 &&
	git add file5 &&
	commit_orphan "file 5" &&
	git read-tree --empty &&
	echo file4 >file4 &&
	git add file4 &&
	commit_orphan "file 4" &&
	c4="$(git rev-parse --verify HEAD)" && test -n "$c4" &&
	git read-tree --empty &&
	echo file3 >file3 &&
	git add file3 &&
	commit_orphan "file 3" &&
	git read-tree --empty &&
	echo file2 >file2 &&
	git add file2 &&
	commit_orphan "file 2" &&
	git read-tree --empty &&
	echo file1 >file1 &&
	git add file1 &&
	commit_orphan "file 1" &&
	c1="$(git rev-parse --verify HEAD)" && test -n "$c1" &&
	git update-ref --no-deref -m "detaching to linked c4" HEAD "$c4" HEAD &&
	git update-ref --no-deref -m "attaching back to linked c1" HEAD "$c1" HEAD &&
	sane_reattach_ref HEAD refs/heads/linked
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >HEAD_main.log || die
commit dd1016e3aedddb592ab8b1075dc5957c2c770c57
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: attaching back to c7
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 7

commit 40403e00fa16ee338d54ab86d67dde8b8017312d
Reflog: HEAD@{1} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: detaching to c4
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit dd1016e3aedddb592ab8b1075dc5957c2c770c57
Reflog: HEAD@{2} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 7

commit 84b1e4e6dd88903b38db5c1e41bcb048abafa044
Reflog: HEAD@{3} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:19:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:19:13 2005 -0700

    file 6

commit 8238c7e733e43fb89537cf4cae44d31a5438acd6
Reflog: HEAD@{4} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:18:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:18:13 2005 -0700

    file 5

commit 40403e00fa16ee338d54ab86d67dde8b8017312d
Reflog: HEAD@{5} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit feeb764a0c96556642f118177871e09693a1ea2c
Reflog: HEAD@{6} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:16:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:16:13 2005 -0700

    file 3

commit c0ed6e70c9c2edcaa98118b9c26a98e4f9beba3c
Reflog: HEAD@{7} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:15:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:15:13 2005 -0700

    file 2

commit c18fcef2dd73f7969b45b108d061309b670c886c
Reflog: HEAD@{8} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 1

commit b63866e540ea13ef92d9eaad23c571912019da41
Reflog: HEAD@{9} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:13:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:13:13 2005 -0700

    empty
EOT

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >HEAD_linked.log || die
commit 04eea982f4572b35c7cbb6597f5d777661f15e60
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: attaching back to linked c1
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 1

commit 40403e00fa16ee338d54ab86d67dde8b8017312d
Reflog: HEAD@{1} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: detaching to linked c4
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit 04eea982f4572b35c7cbb6597f5d777661f15e60
Reflog: HEAD@{2} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 1

commit 4d776c6492d2e482e7d5a7673eec6a003e1f2f28
Reflog: HEAD@{3} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:19:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:19:13 2005 -0700

    file 2

commit 602d59a7ea59e60a4776c39f5cefde1e250e7e21
Reflog: HEAD@{4} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:18:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:18:13 2005 -0700

    file 3

commit 40403e00fa16ee338d54ab86d67dde8b8017312d
Reflog: HEAD@{5} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit 0a45d4757beafde42dba7b9e228f4fca4d2c2570
Reflog: HEAD@{6} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:16:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:16:13 2005 -0700

    file 5

commit e053b7d1bf32cbf73d07ebccef4f717375b27af8
Reflog: HEAD@{7} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:15:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:15:13 2005 -0700

    file 6

commit 2849f113c66cbf3c9521e90be3bc7e39fce8db16
Reflog: HEAD@{8} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 7

commit fce870c7720ff513ea5dd3c60d6972ed70c41d1f
Reflog: HEAD@{9} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:13:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:13:13 2005 -0700

    empty linked
EOT

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >master.log
commit dd1016e3aedddb592ab8b1075dc5957c2c770c57
Reflog: master@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 7

commit 84b1e4e6dd88903b38db5c1e41bcb048abafa044
Reflog: master@{1} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:19:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:19:13 2005 -0700

    file 6

commit 8238c7e733e43fb89537cf4cae44d31a5438acd6
Reflog: master@{2} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:18:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:18:13 2005 -0700

    file 5

commit 40403e00fa16ee338d54ab86d67dde8b8017312d
Reflog: master@{3} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit feeb764a0c96556642f118177871e09693a1ea2c
Reflog: master@{4} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:16:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:16:13 2005 -0700

    file 3

commit c0ed6e70c9c2edcaa98118b9c26a98e4f9beba3c
Reflog: master@{5} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:15:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:15:13 2005 -0700

    file 2

commit c18fcef2dd73f7969b45b108d061309b670c886c
Reflog: master@{6} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 1

commit b63866e540ea13ef92d9eaad23c571912019da41
Reflog: master@{7} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:13:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:13:13 2005 -0700

    empty
EOT

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >linked.log
commit 04eea982f4572b35c7cbb6597f5d777661f15e60
Reflog: linked@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 1

commit 4d776c6492d2e482e7d5a7673eec6a003e1f2f28
Reflog: linked@{1} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:19:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:19:13 2005 -0700

    file 2

commit 602d59a7ea59e60a4776c39f5cefde1e250e7e21
Reflog: linked@{2} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:18:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:18:13 2005 -0700

    file 3

commit 40403e00fa16ee338d54ab86d67dde8b8017312d
Reflog: linked@{3} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit 0a45d4757beafde42dba7b9e228f4fca4d2c2570
Reflog: linked@{4} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:16:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:16:13 2005 -0700

    file 5

commit e053b7d1bf32cbf73d07ebccef4f717375b27af8
Reflog: linked@{5} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:15:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:15:13 2005 -0700

    file 6

commit 2849f113c66cbf3c9521e90be3bc7e39fce8db16
Reflog: linked@{6} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 7

commit fce870c7720ff513ea5dd3c60d6972ed70c41d1f
Reflog: linked@{7} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:13:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:13:13 2005 -0700

    empty linked
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >HEAD_main.log || die
commit e784e427bc756c7dab3c5c993ce172605b03911f4a4cee2b472f5eaf47439f1f
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: attaching back to c7
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 7

commit e2552eeb08597fac52b221ecdcdda3d73b298adf066bd68a75e6d78b5c3ae0a8
Reflog: HEAD@{1} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: detaching to c4
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit e784e427bc756c7dab3c5c993ce172605b03911f4a4cee2b472f5eaf47439f1f
Reflog: HEAD@{2} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 7

commit 201a80d1dac354e3bf8f5ffd8d6ed3bf45425d25903e51c5b5fe581ed1915b2b
Reflog: HEAD@{3} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:19:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:19:13 2005 -0700

    file 6

commit 71acff480527a965010d8d59c50ed31ccff26637eb259ecd29aeb48f90dbcbd6
Reflog: HEAD@{4} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:18:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:18:13 2005 -0700

    file 5

commit e2552eeb08597fac52b221ecdcdda3d73b298adf066bd68a75e6d78b5c3ae0a8
Reflog: HEAD@{5} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit 196f1299c911ab944da342f5df818d2c930c84a6efecf6ab73e074abec73aa1c
Reflog: HEAD@{6} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:16:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:16:13 2005 -0700

    file 3

commit 7dec28d627784a76bef56727ce0da16f78c9bf93c4ee21d63c26bfe19aec525b
Reflog: HEAD@{7} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:15:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:15:13 2005 -0700

    file 2

commit ecf5cd744123c8f322d61b4a97d18d75f1c25440ca838a9654decff6b8697226
Reflog: HEAD@{8} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 1

commit 079309f2fa99f1dc84e7d2b40b25766e2e6ff4da86bc8f2be31487085cc9359a
Reflog: HEAD@{9} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:13:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:13:13 2005 -0700

    empty
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >HEAD_linked.log || die
commit 6fda165d8aaa203d2bf9a67dcd750ac6e273489ea89e174866c1170d81cf2f73
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: attaching back to linked c1
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 1

commit e2552eeb08597fac52b221ecdcdda3d73b298adf066bd68a75e6d78b5c3ae0a8
Reflog: HEAD@{1} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: detaching to linked c4
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit 6fda165d8aaa203d2bf9a67dcd750ac6e273489ea89e174866c1170d81cf2f73
Reflog: HEAD@{2} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 1

commit 1a6140d409f963b95143d6d2ca04ceb547c798938ddac9e34f4be143c3de2e0e
Reflog: HEAD@{3} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:19:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:19:13 2005 -0700

    file 2

commit a45e681849307b92993a9798ae71198df602a16281a29810fc1180139e426e89
Reflog: HEAD@{4} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:18:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:18:13 2005 -0700

    file 3

commit e2552eeb08597fac52b221ecdcdda3d73b298adf066bd68a75e6d78b5c3ae0a8
Reflog: HEAD@{5} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit 8575f83fcc048762d2e22aebed05a05bc0d7bada62665eacf83fbff2afb88a7a
Reflog: HEAD@{6} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:16:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:16:13 2005 -0700

    file 5

commit 821fd1740f7c0903282e1f7e16b90891732f6f1480dd997591462a4514cc1d5a
Reflog: HEAD@{7} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:15:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:15:13 2005 -0700

    file 6

commit e2473e861fd48f0ece81fdbd760dde169c6e00c57b426f85853b59203760214b
Reflog: HEAD@{8} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 7

commit a6345fe47a02ec4a2f0f5b749104a44dddff871fcea90b2525b0a5eb1af946e2
Reflog: HEAD@{9} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:13:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:13:13 2005 -0700

    empty linked
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >master.log
commit e784e427bc756c7dab3c5c993ce172605b03911f4a4cee2b472f5eaf47439f1f
Reflog: master@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 7

commit 201a80d1dac354e3bf8f5ffd8d6ed3bf45425d25903e51c5b5fe581ed1915b2b
Reflog: master@{1} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:19:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:19:13 2005 -0700

    file 6

commit 71acff480527a965010d8d59c50ed31ccff26637eb259ecd29aeb48f90dbcbd6
Reflog: master@{2} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:18:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:18:13 2005 -0700

    file 5

commit e2552eeb08597fac52b221ecdcdda3d73b298adf066bd68a75e6d78b5c3ae0a8
Reflog: master@{3} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit 196f1299c911ab944da342f5df818d2c930c84a6efecf6ab73e074abec73aa1c
Reflog: master@{4} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:16:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:16:13 2005 -0700

    file 3

commit 7dec28d627784a76bef56727ce0da16f78c9bf93c4ee21d63c26bfe19aec525b
Reflog: master@{5} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:15:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:15:13 2005 -0700

    file 2

commit ecf5cd744123c8f322d61b4a97d18d75f1c25440ca838a9654decff6b8697226
Reflog: master@{6} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 1

commit 079309f2fa99f1dc84e7d2b40b25766e2e6ff4da86bc8f2be31487085cc9359a
Reflog: master@{7} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:13:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:13:13 2005 -0700

    empty
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >linked.log
commit 6fda165d8aaa203d2bf9a67dcd750ac6e273489ea89e174866c1170d81cf2f73
Reflog: linked@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 1

commit 1a6140d409f963b95143d6d2ca04ceb547c798938ddac9e34f4be143c3de2e0e
Reflog: linked@{1} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:19:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:19:13 2005 -0700

    file 2

commit a45e681849307b92993a9798ae71198df602a16281a29810fc1180139e426e89
Reflog: linked@{2} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:18:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:18:13 2005 -0700

    file 3

commit e2552eeb08597fac52b221ecdcdda3d73b298adf066bd68a75e6d78b5c3ae0a8
Reflog: linked@{3} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:17:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:17:13 2005 -0700

    file 4

commit 8575f83fcc048762d2e22aebed05a05bc0d7bada62665eacf83fbff2afb88a7a
Reflog: linked@{4} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:16:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:16:13 2005 -0700

    file 5

commit 821fd1740f7c0903282e1f7e16b90891732f6f1480dd997591462a4514cc1d5a
Reflog: linked@{5} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:15:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:15:13 2005 -0700

    file 6

commit e2473e861fd48f0ece81fdbd760dde169c6e00c57b426f85853b59203760214b
Reflog: linked@{6} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 7

commit a6345fe47a02ec4a2f0f5b749104a44dddff871fcea90b2525b0a5eb1af946e2
Reflog: linked@{7} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: 
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:13:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:13:13 2005 -0700

    empty linked
EOT

test_expect_success LASTOK 'verify setup' '
	test -f "main/.git/objects/pack/$objpack.idx" &&
	test -f "main/.git/objects/pack/$objpack.pack" &&
	cd main &&
	mv -f ".git/objects/pack/$objpack.idx" ".git/objects/pack/$objpack.no" &&
	test_must_fail git fsck --full &&
	mv -f ".git/objects/pack/$objpack.no" ".git/objects/pack/$objpack.idx" &&
	git fsck --full &&
	git log -g --pretty=fuller HEAD >actual &&
	test_cmp actual ../HEAD_main.log &&
	git log -g --pretty=fuller master >actual &&
	test_cmp actual ../master.log &&
	if test_have_prereq GIT_2_5; then
		cd ../linked &&
		git log -g --pretty=fuller HEAD >actual &&
		test_cmp actual ../HEAD_linked.log &&
		git log -g --pretty=fuller linked >actual &&
		test_cmp actual ../linked.log
	fi &&
	test_when_finished test_set_prereq SETUP
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tgHEAD_main.log || die
=== 2005-04-07 ===
dd1016e3 15:20:13 (commit) HEAD@{0}: attaching back to c7
40403e00 15:20:13 (commit) HEAD@{1}: detaching to c4
dd1016e3 15:20:13 (commit) HEAD@{2}: file 7
84b1e4e6 15:19:13 (commit) HEAD@{3}: file 6
8238c7e7 15:18:13 (commit) HEAD@{4}: file 5
40403e00 15:17:13 (commit) HEAD@{5}: file 4
feeb764a 15:16:13 (commit) HEAD@{6}: file 3
c0ed6e70 15:15:13 (commit) HEAD@{7}: file 2
c18fcef2 15:14:13 (commit) HEAD@{8}: file 1
b63866e5 15:13:13 (commit) HEAD@{9}: empty
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tgHEAD_main.log || die
=== 2005-04-07 ===
e784e427 15:20:13 (commit) HEAD@{0}: attaching back to c7
e2552eeb 15:20:13 (commit) HEAD@{1}: detaching to c4
e784e427 15:20:13 (commit) HEAD@{2}: file 7
201a80d1 15:19:13 (commit) HEAD@{3}: file 6
71acff48 15:18:13 (commit) HEAD@{4}: file 5
e2552eeb 15:17:13 (commit) HEAD@{5}: file 4
196f1299 15:16:13 (commit) HEAD@{6}: file 3
7dec28d6 15:15:13 (commit) HEAD@{7}: file 2
ecf5cd74 15:14:13 (commit) HEAD@{8}: file 1
079309f2 15:13:13 (commit) HEAD@{9}: empty
EOT

test_expect_success SETUP 'tag -g HEAD' '
	cd main &&
	tg tag -g HEAD >actual &&
	test_cmp actual ../tgHEAD_main.log
'

test_expect_success SETUP 'tag -g --no-type HEAD' '
	cd main &&
	sed "s/(commit) //" <../tgHEAD_main.log >expected &&
	tg tag -g --no-type HEAD >actual &&
	test_cmp actual expected
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tgmaster.log || die
=== 2005-04-07 ===
dd1016e3 15:20:13 (commit) master@{0}: file 7
84b1e4e6 15:19:13 (commit) master@{1}: file 6
8238c7e7 15:18:13 (commit) master@{2}: file 5
40403e00 15:17:13 (commit) master@{3}: file 4
feeb764a 15:16:13 (commit) master@{4}: file 3
c0ed6e70 15:15:13 (commit) master@{5}: file 2
c18fcef2 15:14:13 (commit) master@{6}: file 1
b63866e5 15:13:13 (commit) master@{7}: empty
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tgmaster.log || die
=== 2005-04-07 ===
e784e427 15:20:13 (commit) master@{0}: file 7
201a80d1 15:19:13 (commit) master@{1}: file 6
71acff48 15:18:13 (commit) master@{2}: file 5
e2552eeb 15:17:13 (commit) master@{3}: file 4
196f1299 15:16:13 (commit) master@{4}: file 3
7dec28d6 15:15:13 (commit) master@{5}: file 2
ecf5cd74 15:14:13 (commit) master@{6}: file 1
079309f2 15:13:13 (commit) master@{7}: empty
EOT

test_expect_success SETUP 'tag -g master' '
	cd main &&
	tg tag -g master >actual &&
	test_cmp actual ../tgmaster.log
'

test_expect_success SETUP 'tag -g --no-type master' '
	cd main &&
	sed "s/(commit) //" <../tgmaster.log >expected &&
	tg tag -g --no-type master >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'rev-parse --verify master@{0..7}' '
	cd main &&
	test_must_fail git rev-parse --verify master@{8} -- &&
	case "$test_hash_algo" in
	sha1)
	test_cmp_rev b63866e5 master@{7} &&
	test_cmp_rev c18fcef2 master@{6} &&
	test_cmp_rev c0ed6e70 master@{5} &&
	test_cmp_rev feeb764a master@{4} &&
	test_cmp_rev 40403e00 master@{3} &&
	test_cmp_rev 8238c7e7 master@{2} &&
	test_cmp_rev 84b1e4e6 master@{1} &&
	test_cmp_rev dd1016e3 master@{0}
	;;
	sha256)
	test_cmp_rev 079309f2 master@{7} &&
	test_cmp_rev ecf5cd74 master@{6} &&
	test_cmp_rev 7dec28d6 master@{5} &&
	test_cmp_rev 196f1299 master@{4} &&
	test_cmp_rev e2552eeb master@{3} &&
	test_cmp_rev 71acff48 master@{2} &&
	test_cmp_rev 201a80d1 master@{1} &&
	test_cmp_rev e784e427 master@{0}
	;;*) die unknown hash "$test_hash_algo"
	esac &&
	test_cmp_rev master master@{0}
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tgHEAD_linked.log || die
=== 2005-04-07 ===
04eea982 15:20:13 (commit) HEAD@{0}: attaching back to linked c1
40403e00 15:20:13 (commit) HEAD@{1}: detaching to linked c4
04eea982 15:20:13 (commit) HEAD@{2}: file 1
4d776c64 15:19:13 (commit) HEAD@{3}: file 2
602d59a7 15:18:13 (commit) HEAD@{4}: file 3
40403e00 15:17:13 (commit) HEAD@{5}: file 4
0a45d475 15:16:13 (commit) HEAD@{6}: file 5
e053b7d1 15:15:13 (commit) HEAD@{7}: file 6
2849f113 15:14:13 (commit) HEAD@{8}: file 7
fce870c7 15:13:13 (commit) HEAD@{9}: empty linked
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tgHEAD_linked.log || die
=== 2005-04-07 ===
6fda165d 15:20:13 (commit) HEAD@{0}: attaching back to linked c1
e2552eeb 15:20:13 (commit) HEAD@{1}: detaching to linked c4
6fda165d 15:20:13 (commit) HEAD@{2}: file 1
1a6140d4 15:19:13 (commit) HEAD@{3}: file 2
a45e6818 15:18:13 (commit) HEAD@{4}: file 3
e2552eeb 15:17:13 (commit) HEAD@{5}: file 4
8575f83f 15:16:13 (commit) HEAD@{6}: file 5
821fd174 15:15:13 (commit) HEAD@{7}: file 6
e2473e86 15:14:13 (commit) HEAD@{8}: file 7
a6345fe4 15:13:13 (commit) HEAD@{9}: empty linked
EOT

test_expect_success 'SETUP GIT_2_5' 'tag -g HEAD [linked]' '
	cd linked &&
	tg tag -g HEAD >actual &&
	test_cmp actual ../tgHEAD_linked.log
'

test_expect_success 'SETUP GIT_2_5' 'tag -g --no-type HEAD [linked]' '
	cd linked &&
	sed "s/(commit) //" <../tgHEAD_linked.log >expected &&
	tg tag -g --no-type HEAD >actual &&
	test_cmp actual expected
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tglinked.log || die
=== 2005-04-07 ===
04eea982 15:20:13 (commit) linked@{0}: file 1
4d776c64 15:19:13 (commit) linked@{1}: file 2
602d59a7 15:18:13 (commit) linked@{2}: file 3
40403e00 15:17:13 (commit) linked@{3}: file 4
0a45d475 15:16:13 (commit) linked@{4}: file 5
e053b7d1 15:15:13 (commit) linked@{5}: file 6
2849f113 15:14:13 (commit) linked@{6}: file 7
fce870c7 15:13:13 (commit) linked@{7}: empty linked
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tglinked.log || die
=== 2005-04-07 ===
6fda165d 15:20:13 (commit) linked@{0}: file 1
1a6140d4 15:19:13 (commit) linked@{1}: file 2
a45e6818 15:18:13 (commit) linked@{2}: file 3
e2552eeb 15:17:13 (commit) linked@{3}: file 4
8575f83f 15:16:13 (commit) linked@{4}: file 5
821fd174 15:15:13 (commit) linked@{5}: file 6
e2473e86 15:14:13 (commit) linked@{6}: file 7
a6345fe4 15:13:13 (commit) linked@{7}: empty linked
EOT

test_expect_success 'SETUP GIT_2_5' 'tag -g linked' '
	cd linked &&
	tg tag -g linked >actual &&
	test_cmp actual ../tglinked.log &&
	cd ../main &&
	tg tag -g linked >actual &&
	test_cmp actual ../tglinked.log
'

test_expect_success 'SETUP GIT_2_5' 'tag --no-type -g linked' '
	cd linked &&
	sed "s/(commit) //" <../tglinked.log >expected &&
	tg tag -g --no-type linked >actual &&
	test_cmp actual expected &&
	cd ../main &&
	tg tag -g --no-type linked >actual &&
	test_cmp actual ../linked/expected
'

test_expect_success 'SETUP GIT_2_5' 'rev-parse --verify linked@{0..7}' '
	cd linked &&
	test_must_fail git rev-parse --verify linked@{8} -- &&
	case "$test_hash_algo" in
	sha1)
	test_cmp_rev fce870c7 linked@{7} &&
	test_cmp_rev 2849f113 linked@{6} &&
	test_cmp_rev e053b7d1 linked@{5} &&
	test_cmp_rev 0a45d475 linked@{4} &&
	test_cmp_rev 40403e00 linked@{3} &&
	test_cmp_rev 602d59a7 linked@{2} &&
	test_cmp_rev 4d776c64 linked@{1} &&
	test_cmp_rev 04eea982 linked@{0}
	;;
	sha256)
	test_cmp_rev a6345fe4 linked@{7} &&
	test_cmp_rev e2473e86 linked@{6} &&
	test_cmp_rev 821fd174 linked@{5} &&
	test_cmp_rev 8575f83f linked@{4} &&
	test_cmp_rev e2552eeb linked@{3} &&
	test_cmp_rev a45e6818 linked@{2} &&
	test_cmp_rev 1a6140d4 linked@{1} &&
	test_cmp_rev 6fda165d linked@{0}
	;;*) die unknown hash "$test_hash_algo"
	esac &&
	test_cmp_rev linked linked@{0}
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tgHEAD_main_1.log || die
=== 2005-04-07 ===
dd1016e3 15:20:13 (commit) HEAD@{0}: attaching back to c7
dd1016e3 15:20:13 (commit) HEAD@{1}: file 7
84b1e4e6 15:19:13 (commit) HEAD@{2}: file 6
8238c7e7 15:18:13 (commit) HEAD@{3}: file 5
40403e00 15:17:13 (commit) HEAD@{4}: file 4
feeb764a 15:16:13 (commit) HEAD@{5}: file 3
c0ed6e70 15:15:13 (commit) HEAD@{6}: file 2
c18fcef2 15:14:13 (commit) HEAD@{7}: file 1
b63866e5 15:13:13 (commit) HEAD@{8}: empty
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tgHEAD_main_1.log || die
=== 2005-04-07 ===
e784e427 15:20:13 (commit) HEAD@{0}: attaching back to c7
e784e427 15:20:13 (commit) HEAD@{1}: file 7
201a80d1 15:19:13 (commit) HEAD@{2}: file 6
71acff48 15:18:13 (commit) HEAD@{3}: file 5
e2552eeb 15:17:13 (commit) HEAD@{4}: file 4
196f1299 15:16:13 (commit) HEAD@{5}: file 3
7dec28d6 15:15:13 (commit) HEAD@{6}: file 2
ecf5cd74 15:14:13 (commit) HEAD@{7}: file 1
079309f2 15:13:13 (commit) HEAD@{8}: empty
EOT

test_expect_success SETUP 'tag --drop HEAD@{1}' '
	cd main &&
	tg tag --drop HEAD@{1} &&
	tg tag -g HEAD >actual &&
	test_cmp actual ../tgHEAD_main_1.log
'

test_expect_success SETUP 'tag --drop HEAD@{9} fails' '
	cd main &&
	test_must_fail tg tag --drop HEAD@{9}
'

test_expect_success SETUP 'tag --drop HEAD@{8}' '
	cd main &&
	sed <../tgHEAD_main_1.log -n "1,9p" >expected &&
	tg tag --drop HEAD@{8} &&
	tg tag -g HEAD >actual &&
	test_cmp actual expected
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tgmaster_3.log || die
=== 2005-04-07 ===
dd1016e3 15:20:13 (commit) master@{0}: file 7
84b1e4e6 15:19:13 (commit) master@{1}: file 6
8238c7e7 15:18:13 (commit) master@{2}: file 5
feeb764a 15:16:13 (commit) master@{3}: file 3
c0ed6e70 15:15:13 (commit) master@{4}: file 2
c18fcef2 15:14:13 (commit) master@{5}: file 1
b63866e5 15:13:13 (commit) master@{6}: empty
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tgmaster_3.log || die
=== 2005-04-07 ===
e784e427 15:20:13 (commit) master@{0}: file 7
201a80d1 15:19:13 (commit) master@{1}: file 6
71acff48 15:18:13 (commit) master@{2}: file 5
196f1299 15:16:13 (commit) master@{3}: file 3
7dec28d6 15:15:13 (commit) master@{4}: file 2
ecf5cd74 15:14:13 (commit) master@{5}: file 1
079309f2 15:13:13 (commit) master@{6}: empty
EOT

test_expect_success SETUP 'tag --drop master@{3}' '
	cd main &&
	tg tag --drop master@{3} &&
	tg tag -g master >actual &&
	test_cmp actual ../tgmaster_3.log
'

test_expect_success SETUP 'tag --drop master@{7} fails' '
	cd main &&
	test_must_fail tg tag --drop master@{7}
'

test_expect_success SETUP 'tag --drop master@{6}' '
	cd main &&
	sed <../tgmaster_3.log -n "1,7p" >expected &&
	tg tag --drop master@{6} &&
	tg tag -g master >actual &&
	test_cmp actual expected
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tgHEAD_linked_1.log || die
=== 2005-04-07 ===
04eea982 15:20:13 (commit) HEAD@{0}: attaching back to linked c1
04eea982 15:20:13 (commit) HEAD@{1}: file 1
4d776c64 15:19:13 (commit) HEAD@{2}: file 2
602d59a7 15:18:13 (commit) HEAD@{3}: file 3
40403e00 15:17:13 (commit) HEAD@{4}: file 4
0a45d475 15:16:13 (commit) HEAD@{5}: file 5
e053b7d1 15:15:13 (commit) HEAD@{6}: file 6
2849f113 15:14:13 (commit) HEAD@{7}: file 7
fce870c7 15:13:13 (commit) HEAD@{8}: empty linked
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tgHEAD_linked_1.log || die
=== 2005-04-07 ===
6fda165d 15:20:13 (commit) HEAD@{0}: attaching back to linked c1
6fda165d 15:20:13 (commit) HEAD@{1}: file 1
1a6140d4 15:19:13 (commit) HEAD@{2}: file 2
a45e6818 15:18:13 (commit) HEAD@{3}: file 3
e2552eeb 15:17:13 (commit) HEAD@{4}: file 4
8575f83f 15:16:13 (commit) HEAD@{5}: file 5
821fd174 15:15:13 (commit) HEAD@{6}: file 6
e2473e86 15:14:13 (commit) HEAD@{7}: file 7
a6345fe4 15:13:13 (commit) HEAD@{8}: empty linked
EOT

test_expect_success 'SETUP GIT_2_5' 'tag --drop HEAD@{1} [linked]' '
	cd linked &&
	tg tag --drop HEAD@{1} &&
	tg tag -g HEAD >actual &&
	test_cmp actual ../tgHEAD_linked_1.log
'

test_expect_success 'SETUP GIT_2_5' 'tag --drop HEAD@{9} [linked] fails' '
	cd linked &&
	test_must_fail tg tag --drop HEAD@{9}
'

test_expect_success 'SETUP GIT_2_5' 'tag --drop HEAD@{8} [linked]' '
	cd linked &&
	sed <../tgHEAD_linked_1.log -n "1,9p" >expected &&
	tg tag --drop HEAD@{8} &&
	tg tag -g HEAD >actual &&
	test_cmp actual expected
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tglinked_2.log || die
=== 2005-04-07 ===
04eea982 15:20:13 (commit) linked@{0}: file 1
4d776c64 15:19:13 (commit) linked@{1}: file 2
40403e00 15:17:13 (commit) linked@{2}: file 4
0a45d475 15:16:13 (commit) linked@{3}: file 5
e053b7d1 15:15:13 (commit) linked@{4}: file 6
2849f113 15:14:13 (commit) linked@{5}: file 7
fce870c7 15:13:13 (commit) linked@{6}: empty linked
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tglinked_2.log || die
=== 2005-04-07 ===
6fda165d 15:20:13 (commit) linked@{0}: file 1
1a6140d4 15:19:13 (commit) linked@{1}: file 2
e2552eeb 15:17:13 (commit) linked@{2}: file 4
8575f83f 15:16:13 (commit) linked@{3}: file 5
821fd174 15:15:13 (commit) linked@{4}: file 6
e2473e86 15:14:13 (commit) linked@{5}: file 7
a6345fe4 15:13:13 (commit) linked@{6}: empty linked
EOT

test_expect_success 'SETUP GIT_2_5' 'tag --drop linked@{2}' '
	cd linked &&
	tg tag --drop linked@{2} &&
	tg tag -g linked >actual &&
	test_cmp actual ../tglinked_2.log
'

test_expect_success 'SETUP GIT_2_5' 'tag --drop linked@{7} fails' '
	cd linked &&
	test_must_fail tg tag --drop linked@{7}
'

test_expect_success 'SETUP GIT_2_5' 'tag --drop linked@{6}' '
	cd linked &&
	sed <../tglinked_2.log -n "1,7p" >expected &&
	tg tag --drop linked@{6} &&
	tg tag -g linked >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'tag --drop master@{0}' '
	cd main &&
	m0="$(git rev-parse --verify master@{0})" && test -n "$m0" &&
	m1="$(git rev-parse --verify master@{1})" && test -n "$m1" &&
	m="$(git rev-parse --verify master)" && test -n "$m" &&
	test "$m" = "$m0" &&
	test "$m0" != "$m1" &&
	tg tag --drop master@{0} &&
	m0new="$(git rev-parse --verify master@{0})" && test -n "$m0new" &&
	mnew="$(git rev-parse --verify master)" && test -n "$mnew" &&
	test "$mnew" = "$m0new" &&
	test "$m0new" = "$m1"
'

test_expect_success 'SETUP GIT_2_5' 'tag --drop linked@{0}' '
	cd linked &&
	l0="$(git rev-parse --verify linked@{0})" && test -n "$l0" &&
	l1="$(git rev-parse --verify linked@{1})" && test -n "$l1" &&
	l="$(git rev-parse --verify linked)" && test -n "$l" &&
	test "$l" = "$l0" &&
	test "$l0" != "$l1" &&
	tg tag --drop linked@{0} &&
	l0new="$(git rev-parse --verify linked@{0})" && test -n "$l0new" &&
	lnew="$(git rev-parse --verify linked)" && test -n "$lnew" &&
	test "$lnew" = "$l0new" &&
	test "$l0new" = "$l1"
'

test_expect_success SETUP 'rev-parse --verify master@{0..4}' '
	cd main &&
	test_must_fail git rev-parse --verify master@{5} -- &&
	case "$test_hash_algo" in
	sha1)
	test_cmp_rev c18fcef2 master@{4} &&
	test_cmp_rev c0ed6e70 master@{3} &&
	test_cmp_rev feeb764a master@{2} &&
	test_cmp_rev 8238c7e7 master@{1} &&
	test_cmp_rev 84b1e4e6 master@{0}
	;;
	sha256)
	test_cmp_rev ecf5cd74 master@{4} &&
	test_cmp_rev 7dec28d6 master@{3} &&
	test_cmp_rev 196f1299 master@{2} &&
	test_cmp_rev 71acff48 master@{1} &&
	test_cmp_rev 201a80d1 master@{0}
	;;*) die unknown hash "$test_hash_algo"
	esac &&
	test_cmp_rev master master@{0}
'

test_expect_success 'SETUP GIT_2_5' 'rev-parse --verify linked@{0..4}' '
	cd linked &&
	test_must_fail git rev-parse --verify linked@{5} -- &&
	case "$test_hash_algo" in
	sha1)
	test_cmp_rev 2849f113 linked@{4} &&
	test_cmp_rev e053b7d1 linked@{3} &&
	test_cmp_rev 0a45d475 linked@{2} &&
	test_cmp_rev 40403e00 linked@{1} &&
	test_cmp_rev 4d776c64 linked@{0}
	;;
	sha256)
	test_cmp_rev e2473e86 linked@{4} &&
	test_cmp_rev 821fd174 linked@{3} &&
	test_cmp_rev 8575f83f linked@{2} &&
	test_cmp_rev e2552eeb linked@{1} &&
	test_cmp_rev 1a6140d4 linked@{0}
	;;*) die unknown hash "$test_hash_algo"
	esac &&
	test_cmp_rev linked linked@{0}
'

test_expect_success '!GIT_2_31 SETUP' 'tag --drop symref HEAD@{0}' '
	cd main &&
	h0="$(git rev-parse --verify HEAD@{0})" && test -n "$h0" &&
	h1="$(git rev-parse --verify HEAD@{1})" && test -n "$h1" &&
	h="$(git rev-parse --verify HEAD)" && test -n "$h" &&
	test "$h" = "$h0" &&
	test "$h0" != "$h1" &&
	tg tag --drop HEAD@{0} &&
	h0new="$(git rev-parse --verify HEAD@{0})" && test -n "$h0new" &&
	hnew="$(git rev-parse --verify HEAD)" && test -n "$hnew" &&
	test "$hnew" = "$h0new" &&
	test "$h0new" = "$h0"
'

test_expect_success '!GIT_2_31 SETUP GIT_2_5' 'tag --drop symref HEAD@{0} [linked]' '
	cd linked &&
	h0="$(git rev-parse --verify HEAD@{0})" && test -n "$h0" &&
	h1="$(git rev-parse --verify HEAD@{1})" && test -n "$h1" &&
	h="$(git rev-parse --verify HEAD)" && test -n "$h" &&
	test "$h" = "$h0" &&
	test "$h0" != "$h1" &&
	tg tag --drop HEAD@{0} &&
	h0new="$(git rev-parse --verify HEAD@{0})" && test -n "$h0new" &&
	hnew="$(git rev-parse --verify HEAD)" && test -n "$hnew" &&
	test "$hnew" = "$h0new" &&
	test "$h0new" = "$h0"
'

test_expect_success '!GIT_2_31 SETUP' 'tag --drop detached HEAD@{0}' '
	cd main &&
	git update-ref -m detach --no-deref HEAD HEAD HEAD &&
	h0="$(git rev-parse --verify HEAD@{0})" && test -n "$h0" &&
	h1="$(git rev-parse --verify HEAD@{1})" && test -n "$h1" &&
	h="$(git rev-parse --verify HEAD)" && test -n "$h" &&
	test "$h" = "$h0" &&
	test "$h0" != "$h1" &&
	tg tag --drop HEAD@{0} &&
	h0new="$(git rev-parse --verify HEAD@{0})" && test -n "$h0new" &&
	hnew="$(git rev-parse --verify HEAD)" && test -n "$hnew" &&
	test "$hnew" = "$h0new" &&
	test "$h0new" = "$h1"
'

test_expect_success '!GIT_2_31 SETUP GIT_2_5' 'tag --drop detached HEAD@{0} [linked]' '
	cd linked &&
	git update-ref -m detach --no-deref HEAD HEAD HEAD &&
	h0="$(git rev-parse --verify HEAD@{0})" && test -n "$h0" &&
	h1="$(git rev-parse --verify HEAD@{1})" && test -n "$h1" &&
	h="$(git rev-parse --verify HEAD)" && test -n "$h" &&
	test "$h" = "$h0" &&
	test "$h0" != "$h1" &&
	tg tag --drop HEAD@{0} &&
	h0new="$(git rev-parse --verify HEAD@{0})" && test -n "$h0new" &&
	hnew="$(git rev-parse --verify HEAD)" && test -n "$hnew" &&
	test "$hnew" = "$h0new" &&
	test "$h0new" = "$h1"
'

test_expect_success SETUP 'staleify two log entries' '
	cd main &&
	git rev-list --no-walk --objects master@{1} >/dev/null 2>&1 &&
	git rev-list --no-walk --objects master@{3} >/dev/null 2>&1 &&
	rm -f .git/objects/pack/*.idx &&
	test_must_fail git rev-list --no-walk --objects master@{1} >/dev/null 2>&1 &&
	test_must_fail git rev-list --no-walk --objects master@{3} >/dev/null 2>&1
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tgmaster_fix1.log || die
=== 2005-04-07 ===
feeb764a 15:16:13 (commit) master@{0}: file 3
c0ed6e70 15:15:13 (commit) master@{1}: file 2
c18fcef2 15:14:13 (commit) master@{2}: file 1
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tgmaster_fix1.log || die
=== 2005-04-07 ===
196f1299 15:16:13 (commit) master@{0}: file 3
7dec28d6 15:15:13 (commit) master@{1}: file 2
ecf5cd74 15:14:13 (commit) master@{2}: file 1
EOT

test_expect_success SETUP 'tag --drop master@{0} --stale-fix 1' '
	cd main &&
	tg tag --drop master@{0} &&
	tg tag -g master >actual &&
	test_cmp actual ../tgmaster_fix1.log
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tgmaster_fix2.log || die
=== 2005-04-07 ===
c18fcef2 15:14:13 (commit) master@{0}: file 1
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tgmaster_fix2.log || die
=== 2005-04-07 ===
ecf5cd74 15:14:13 (commit) master@{0}: file 1
EOT

test_expect_success SETUP 'tag --drop master@{0} --stale-fix 2' '
	cd main &&
	tg tag --drop master@{0} &&
	tg tag -g master >actual &&
	test_cmp actual ../tgmaster_fix2.log
'

test_expect_success SETUP 'tag --drop master@{0} final entry' '
	cd main &&
	tg tag --drop master@{0} &&
	test_must_fail tg tag -g master &&
	test_must_fail tg tag --drop master@{0} &&
	git rev-parse --verify master -- >/dev/null
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tglinked_0.log || die
=== 2005-04-07 ===
40403e00 15:17:13 (commit) linked@{0}: file 4
0a45d475 15:16:13 (commit) linked@{1}: file 5
e053b7d1 15:15:13 (commit) linked@{2}: file 6
2849f113 15:14:13 (commit) linked@{3}: file 7
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tglinked_0.log || die
=== 2005-04-07 ===
e2552eeb 15:17:13 (commit) linked@{0}: file 4
8575f83f 15:16:13 (commit) linked@{1}: file 5
821fd174 15:15:13 (commit) linked@{2}: file 6
e2473e86 15:14:13 (commit) linked@{3}: file 7
EOT

test_expect_success 'SETUP GIT_2_5' 'tag --drop linked@{0} broken' '
	cd linked &&
	tg tag --drop linked@{0} &&
	tg tag -g linked >actual &&
	test_cmp actual ../tglinked_0.log
'

test "$test_hash_algo" != "sha1" ||
cat <<\EOT >tglinked_fix1.log || die
=== 2005-04-07 ===
e053b7d1 15:15:13 (commit) linked@{0}: file 6
2849f113 15:14:13 (commit) linked@{1}: file 7
EOT

test "$test_hash_algo" != "sha256" ||
cat <<\EOT >tglinked_fix1.log || die
=== 2005-04-07 ===
821fd174 15:15:13 (commit) linked@{0}: file 6
e2473e86 15:14:13 (commit) linked@{1}: file 7
EOT

test_expect_success 'SETUP GIT_2_5' 'tag --drop linked@{0} --stale-fix 1' '
	cd linked &&
	tg tag --drop linked@{0} &&
	tg tag -g linked >actual &&
	test_cmp actual ../tglinked_fix1.log
'

test_expect_success 'SETUP GIT_2_5' 'tag --drop linked@{0} final entries' '
	cd linked &&
	tg tag --drop linked@{0} &&
	tg tag --drop linked@{0} &&
	test_must_fail tg tag -g linked &&
	test_must_fail tg tag --drop linked@{0} &&
	git rev-parse --verify linked -- >/dev/null
'

! { test "$test_hash_algo" = "sha1" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_pre2 || die
=== 2005-04-07 ===
dd1016e3 15:20:13 (commit) HEAD@{0}: file 7
8238c7e7 15:18:13 (commit) HEAD@{1}: file 5
c0ed6e70 15:15:13 (commit) HEAD@{2}: file 2
c18fcef2 15:14:13 (commit) HEAD@{3}: file 1
EOT

! { test "$test_hash_algo" = "sha1" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_double || die
=== 2005-04-07 ===
c18fcef2 15:14:13 (commit) HEAD@{0}: file 1
EOT

! { test "$test_hash_algo" = "sha256" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_pre2 || die
=== 2005-04-07 ===
e784e427 15:20:13 (commit) HEAD@{0}: file 7
71acff48 15:18:13 (commit) HEAD@{1}: file 5
7dec28d6 15:15:13 (commit) HEAD@{2}: file 2
ecf5cd74 15:14:13 (commit) HEAD@{3}: file 1
EOT

! { test "$test_hash_algo" = "sha256" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_double || die
=== 2005-04-07 ===
ecf5cd74 15:14:13 (commit) HEAD@{0}: file 1
EOT

! { test "$test_hash_algo" = "sha1" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_pre2 || die
=== 2005-04-07 ===
dd1016e3 15:20:13 (commit) HEAD@{0}: attaching back to c7
84b1e4e6 15:19:13 (commit) HEAD@{1}: file 6
feeb764a 15:16:13 (commit) HEAD@{2}: file 3
c0ed6e70 15:15:13 (commit) HEAD@{3}: file 2
c18fcef2 15:14:13 (commit) HEAD@{4}: file 1
EOT

! { test "$test_hash_algo" = "sha1" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_double || die
=== 2005-04-07 ===
84b1e4e6 15:19:13 (commit) HEAD@{0}: file 6
feeb764a 15:16:13 (commit) HEAD@{1}: file 3
c0ed6e70 15:15:13 (commit) HEAD@{2}: file 2
c18fcef2 15:14:13 (commit) HEAD@{3}: file 1
EOT

! { test "$test_hash_algo" = "sha256" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_pre2 || die
=== 2005-04-07 ===
e784e427 15:20:13 (commit) HEAD@{0}: attaching back to c7
201a80d1 15:19:13 (commit) HEAD@{1}: file 6
196f1299 15:16:13 (commit) HEAD@{2}: file 3
7dec28d6 15:15:13 (commit) HEAD@{3}: file 2
ecf5cd74 15:14:13 (commit) HEAD@{4}: file 1
EOT

! { test "$test_hash_algo" = "sha256" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_double || die
=== 2005-04-07 ===
201a80d1 15:19:13 (commit) HEAD@{0}: file 6
196f1299 15:16:13 (commit) HEAD@{1}: file 3
7dec28d6 15:15:13 (commit) HEAD@{2}: file 2
ecf5cd74 15:14:13 (commit) HEAD@{3}: file 1
EOT

test_expect_success SETUP 'tag --drop detached HEAD@{0} double stale' '
	cd main &&
	tg tag --drop HEAD@{4} &&
	tg tag --drop HEAD@{3} &&
	tg tag --drop HEAD@{1} &&
	tg tag -g HEAD >actual &&
	test_cmp actual ../tgHEAD_main_pre2 &&
	tg tag --drop HEAD@{0} &&
	tg tag -g HEAD >actual &&
	test_cmp actual ../tgHEAD_main_double &&
	if test -z "$git_231_plus"; then
		test_must_fail git rev-parse --verify --quiet HEAD@{1} -- >/dev/null
	else
		test_must_fail git rev-parse --verify --quiet HEAD@{4} -- >/dev/null &&
		git rev-parse --verify HEAD@{3} -- >/dev/null &&
		git rev-parse --verify HEAD@{2} -- >/dev/null &&
		git rev-parse --verify HEAD@{1} -- >/dev/null
	fi &&
	git rev-parse --verify HEAD@{0} -- >/dev/null &&
	git rev-parse --verify HEAD -- >/dev/null
'

! { test "$test_hash_algo" = "sha1" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_only || die
=== 2005-04-07 ===
04eea982 15:20:13 (commit) HEAD@{0}: file 1
4d776c64 15:19:13 (commit) HEAD@{1}: file 2
0a45d475 15:16:13 (commit) HEAD@{2}: file 5
EOT

! { test "$test_hash_algo" = "sha256" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_only || die
=== 2005-04-07 ===
6fda165d 15:20:13 (commit) HEAD@{0}: file 1
1a6140d4 15:19:13 (commit) HEAD@{1}: file 2
8575f83f 15:16:13 (commit) HEAD@{2}: file 5
EOT

! { test "$test_hash_algo" = "sha1" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_only || die
=== 2005-04-07 ===
04eea982 15:20:13 (commit) HEAD@{0}: attaching back to linked c1
04eea982 15:20:13 (commit) HEAD@{1}: file 1
40403e00 15:17:13 (commit) HEAD@{2}: file 4
2849f113 15:14:13 (commit) HEAD@{3}: file 7
EOT

! { test "$test_hash_algo" = "sha256" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_only || die
=== 2005-04-07 ===
6fda165d 15:20:13 (commit) HEAD@{0}: attaching back to linked c1
6fda165d 15:20:13 (commit) HEAD@{1}: file 1
e2552eeb 15:17:13 (commit) HEAD@{2}: file 4
e2473e86 15:14:13 (commit) HEAD@{3}: file 7
EOT

test_expect_success 'SETUP GIT_2_5' 'tag --drop detached HEAD@{0} [linked] all stale' '
	cd linked &&
	tg tag --drop HEAD@{6} &&
	tg tag --drop HEAD@{5} &&
	tg tag --drop HEAD@{3} &&
	tg tag --drop HEAD@{2} &&
	tg tag -g HEAD >actual &&
	test_cmp actual ../tgHEAD_linked_only &&
	tg tag --drop HEAD@{0} &&
	if test -z "$git_231_plus"; then
		test_must_fail git rev-parse --verify --quiet HEAD@{0} -- >/dev/null
	else
		test_must_fail git rev-parse --verify --quiet HEAD@{3} -- >/dev/null
		git rev-parse --verify HEAD@{2} -- >/dev/null &&
		git rev-parse --verify HEAD@{1} -- >/dev/null &&
		git rev-parse --verify HEAD@{0} -- >/dev/null
	fi &&
	git rev-parse --verify HEAD -- >/dev/null
'

! { test "$test_hash_algo" = "sha1" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_new || die
=== 2005-04-07 ===
c18fcef2 15:14:13 (commit) HEAD@{0}: allons master
b63866e5 15:13:13 (commit) HEAD@{1}: to empty main
c18fcef2 15:14:13 (commit) HEAD@{2}: file 1
EOT

! { test "$test_hash_algo" = "sha256" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_new || die
=== 2005-04-07 ===
ecf5cd74 15:14:13 (commit) HEAD@{0}: allons master
079309f2 15:13:13 (commit) HEAD@{1}: to empty main
ecf5cd74 15:14:13 (commit) HEAD@{2}: file 1
EOT

! { test "$test_hash_algo" = "sha1" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_new || die
=== 2005-04-07 ===
b63866e5 15:14:13 (commit) HEAD@{0}: allons master
b63866e5 15:13:13 (commit) HEAD@{1}: to empty main
84b1e4e6 15:19:13 (commit) HEAD@{2}: file 6
feeb764a 15:16:13 (commit) HEAD@{3}: file 3
c0ed6e70 15:15:13 (commit) HEAD@{4}: file 2
c18fcef2 15:14:13 (commit) HEAD@{5}: file 1
EOT

! { test "$test_hash_algo" = "sha256" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_new || die
=== 2005-04-07 ===
079309f2 15:14:13 (commit) HEAD@{0}: allons master
079309f2 15:13:13 (commit) HEAD@{1}: to empty main
201a80d1 15:19:13 (commit) HEAD@{2}: file 6
196f1299 15:16:13 (commit) HEAD@{3}: file 3
7dec28d6 15:15:13 (commit) HEAD@{4}: file 2
ecf5cd74 15:14:13 (commit) HEAD@{5}: file 1
EOT

test_expect_success SETUP 'rebuild HEAD log' '
	cd main &&
	test_tick &&
	git update-ref -m "to empty main" HEAD "$mtcommit" HEAD &&
	test_tick &&
	git update-ref -m "allons master" HEAD master HEAD &&
	tg tag -g HEAD >actual &&
	test_cmp actual ../tgHEAD_main_new
'

! { test "$test_hash_algo" = "sha1" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_new || die
=== 2005-04-07 ===
04eea982 15:15:13 (commit) HEAD@{0}: HEAD back
2849f113 15:14:13 (commit) HEAD@{1}: allons linked
b63866e5 15:13:13 (commit) HEAD@{2}: to empty linked
EOT

! { test "$test_hash_algo" = "sha256" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_new || die
=== 2005-04-07 ===
6fda165d 15:15:13 (commit) HEAD@{0}: HEAD back
e2473e86 15:14:13 (commit) HEAD@{1}: allons linked
079309f2 15:13:13 (commit) HEAD@{2}: to empty linked
EOT

! { test "$test_hash_algo" = "sha1" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_new || die
=== 2005-04-07 ===
2849f113 15:15:13 (commit) HEAD@{0}: HEAD back
b63866e5 15:14:13 (commit) HEAD@{1}: allons linked
b63866e5 15:13:13 (commit) HEAD@{2}: to empty linked
04eea982 15:20:13 (commit) HEAD@{3}: file 1
40403e00 15:17:13 (commit) HEAD@{4}: file 4
2849f113 15:14:13 (commit) HEAD@{5}: file 7
EOT

! { test "$test_hash_algo" = "sha256" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_new || die
=== 2005-04-07 ===
e2473e86 15:15:13 (commit) HEAD@{0}: HEAD back
079309f2 15:14:13 (commit) HEAD@{1}: allons linked
079309f2 15:13:13 (commit) HEAD@{2}: to empty linked
6fda165d 15:20:13 (commit) HEAD@{3}: file 1
e2552eeb 15:17:13 (commit) HEAD@{4}: file 4
e2473e86 15:14:13 (commit) HEAD@{5}: file 7
EOT

test_expect_success 'SETUP GIT_2_5' 'rebuild HEAD log [linked]' '
	cd linked &&
	cur="$(git rev-parse --verify HEAD)" && test -n "$cur" &&
	test_tick &&
	git update-ref -m "to empty linked" HEAD "$mtcommit" HEAD &&
	test_tick &&
	git update-ref -m "allons linked" HEAD linked HEAD &&
	test_tick &&
	git update-ref -m "HEAD back" HEAD "$cur" &&
	tg tag -g HEAD >actual &&
	test_cmp actual ../tgHEAD_linked_new
'

! { test "$test_hash_algo" = "sha1" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_cleared || die
commit c18fcef2dd73f7969b45b108d061309b670c886c
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: allons master
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 1
EOT

! { test "$test_hash_algo" = "sha256" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_cleared || die
commit ecf5cd744123c8f322d61b4a97d18d75f1c25440ca838a9654decff6b8697226
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: allons master
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 1
EOT

! { test "$test_hash_algo" = "sha1" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_cleared || die
commit b63866e540ea13ef92d9eaad23c571912019da41
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: allons master
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:13:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:13:13 2005 -0700

    empty
EOT

! { test "$test_hash_algo" = "sha256" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_main_cleared || die
commit 079309f2fa99f1dc84e7d2b40b25766e2e6ff4da86bc8f2be31487085cc9359a
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: allons master
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:13:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:13:13 2005 -0700

    empty
EOT

test_expect_success SETUP 'tag --clear HEAD' '
	cd main &&
	tg tag --clear HEAD &&
	head -n 2 <../tgHEAD_main_new >expected &&
	tg tag -g HEAD >actual &&
	test_cmp actual expected &&
	tg tag --clear HEAD &&
	tg tag -g HEAD >actual &&
	test_cmp actual expected &&
	git log -g --pretty=fuller HEAD >actual &&
	test_cmp actual ../tgHEAD_main_cleared
'

! { test "$test_hash_algo" = "sha1" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_cleared || die
commit 04eea982f4572b35c7cbb6597f5d777661f15e60
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: HEAD back
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 1
EOT

! { test "$test_hash_algo" = "sha256" && test -z "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_cleared || die
commit 6fda165d8aaa203d2bf9a67dcd750ac6e273489ea89e174866c1170d81cf2f73
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: HEAD back
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:20:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:20:13 2005 -0700

    file 1
EOT

! { test "$test_hash_algo" = "sha1" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_cleared || die
commit 2849f113c66cbf3c9521e90be3bc7e39fce8db16
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: HEAD back
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 7
EOT

! { test "$test_hash_algo" = "sha256" && test -n "$git_231_plus"; } ||
cat <<\EOT >tgHEAD_linked_cleared || die
commit e2473e861fd48f0ece81fdbd760dde169c6e00c57b426f85853b59203760214b
Reflog: HEAD@{0} (Fra mewor k (Committer) <framework@example.org>)
Reflog message: HEAD back
Author:     Te s t (Author) <test@example.net>
AuthorDate: Thu Apr 7 15:14:13 2005 -0700
Commit:     Fra mewor k (Committer) <framework@example.org>
CommitDate: Thu Apr 7 15:14:13 2005 -0700

    file 7
EOT

test_expect_success 'SETUP GIT_2_5' 'tag --clear HEAD [linked]' '
	cd linked &&
	tg tag --clear HEAD &&
	head -n 2 <../tgHEAD_linked_new >expected &&
	tg tag -g HEAD >actual &&
	test_cmp actual expected &&
	tg tag --clear HEAD &&
	tg tag -g HEAD >actual &&
	test_cmp actual expected &&
	git log -g --pretty=fuller HEAD >actual &&
	test_cmp actual ../tgHEAD_linked_cleared
'

test_tolerate_failure 'SETUP GIT_2_5' 'tag --clear HEAD w/o log fails [linked]' '
	cd linked &&
	git rev-parse --verify HEAD@{0} >/dev/null -- &&
	tg tag --clear HEAD &&
	tg tag --drop HEAD@{0} &&
	test_must_fail git rev-parse --verify HEAD@{0} -- &&
	test_must_fail tg tag --clear HEAD
'

test_tolerate_failure SETUP 'tag --clear HEAD w/o log fails' '
	cd main &&
	git rev-parse --verify HEAD@{0} >/dev/null -- &&
	tg tag --clear HEAD &&
	tg tag --drop HEAD@{0} &&
	test_must_fail git rev-parse --verify HEAD@{0} -- &&
	test_must_fail tg tag --clear HEAD
'

test_done
