#!/bin/sh

test_description='use of -i/-w options with tg commands that support them

These are the -i and -w options that cause the index or working tree to be
used, respectively, not any other meanings they might have.

Specifically files, mail, next, patch, prev and summary subcommands.
'

. ./test-lib.sh

test_plan 64

trim() {
	_cmd="$1"
	shift
	_ec=0
	eval "$_cmd "'"$@" >_tmp' || _ec=$?
	tr -s '\t ' ' ' <_tmp
	return $_ec
}

from="$(git var GIT_AUTHOR_IDENT)" && test -n "$from" || die
from="${from%>*}>"

REAL_GIT="$( { "unset" -f git; } >/dev/null 2>&1 || :; command -v "${GIT_PATH:-git}" )" || die

test_expect_success 'setup' '
	git config core.abbrev 16 &&
	mkdir -p .git/info &&
	printf "%s\n" _tmp actual expected >.git/info/exclude &&
	tg_test_create_branches <<-EOT &&
		branch1
		:::

		t/branch1
		branch1

		branch2
		:::

		t/branch2
		branch2

		branch3
		:::

		t/branch3
		branch3

		branch4
		:::

		t/branch4
		branch4

		branch5
		:::

		t/branch5
		branch5

		t/primary
		t/branch1

		t/secondary
		t/branch2

	EOT
	git checkout -f t/secondary &&
	git clean -f &&
		>f3 && >f4 && >f5 &&
		git add f3 f4 f5 &&
		test_tick &&
		git commit -m "f3-5" &&
	tg_test_create_branches <<-EOT &&
		t/primary2
		t/primary

		t/secondary2
		t/secondary

	EOT
	echo t/branch2 >expected &&
	test_cmp .topdeps expected &&
	echo "From: $from" >expected &&
	echo "Subject: [PATCH] branch t/secondary" >>expected &&
	test_cmp .topmsg expected &&
	mkdir -p .git/dummy && test -d .git/dummy &&
	write_script .git/dummy/git <<-EOT &&
		test "\$1" = "send-email" && test \$# -ge 2 &&
		eval exec cat "\\"\\\$\$#\\"" ||
		exec "${REAL_GIT:-false}" "\$@"
	EOT
	PATH="$PWD/.git/dummy:$PATH" \
	command git send-email foo bar you hoo .topmsg >actual &&
	test_cmp actual expected
'

case "$test_hash_algo" in
sha1)
	primarybase=8e476c63c7ef4558
	secondarybase=8f7ce5c9f088954c
	;;
sha256)
	primarybase=597e7c92a7237dd5
	secondarybase=1ed0c61ee3ddc0dc
	;;
esac

test_expect_success LASTOK 'verify setup' '
	cat <<-EOT >expected &&
		t/branch3
		 branch3

		t/branch4
		 branch4

		t/branch5
		 branch5

		t/primary2
		 t/primary
		 t/branch1
		 branch1

		t/secondary2
		 t/secondary
		 t/branch2
		 branch2
	EOT
	trim tg summary --rdeps --heads >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		 0 t/branch1 [PATCH] branch t/branch1
		 0 t/branch2 [PATCH] branch t/branch2
		 0 t/branch3 [PATCH] branch t/branch3
		 0 t/branch4 [PATCH] branch t/branch4
		 0 t/branch5 [PATCH] branch t/branch5
		 0 t/primary [PATCH] branch t/primary
		 0 t/primary2 [PATCH] branch t/primary2
		> t/secondary [PATCH] branch t/secondary
		 0 t/secondary2 [PATCH] branch t/secondary2
	EOT
	trim tg summary >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		Topic Branch: t/primary (1/1 commit)
		Subject: [PATCH] branch t/primary
		Dependents: t/primary2
		Base: $primarybase
		Depends: t/branch1
		Up-to-date.
	EOT
	trim tg info -v t/primary >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		Topic Branch: t/secondary (2/2 commits)
		Subject: [PATCH] branch t/secondary
		Dependents: t/secondary2
		Base: $secondarybase
		Depends: t/branch2
		Up-to-date.
	EOT
	trim tg info -v t/secondary >actual &&
	test_cmp actual expected
'

test_expect_success LASTOK 'setup index and working tree' '
	echo "From: $from" >.topmsg &&
	echo "Subject: [PATCH] branch t/tertiary" >>.topmsg &&
	echo t/branch3 >.topdeps &&
	echo file3 >f3 &&
	git rm f4 f5 &&
	git add .topdeps .topmsg f3 &&
	echo "From: $from" >.topmsg &&
	echo "Subject: [PATCH] branch t/quaternary" >>.topmsg &&
	echo t/branch4 >.topdeps &&
	echo t/branch5 >>.topdeps &&
	rm -f f3 &&
	echo file4 >f4 &&
	echo file5 >f5 &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'files' '
	cat <<-EOT >expected &&
		f3
		f4
		f5
	EOT
	tg files >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'files -i' '
	cat <<-EOT >expected &&
		f3
	EOT
	tg files -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'files -w' '
	cat <<-EOT >expected &&
		f4
		f5
	EOT
	tg files -w >actual &&
	test_cmp actual expected
'

# tg mail uses tg patch so test tg patch and follow up with tg mail

case "$test_hash_algo" in
sha1)
	f1f2f3blob=e69de29bb2d1d643
	;;
sha256)
	f1f2f3blob=473a0f4c3be8a936
	;;
esac

test_expect_success SETUP 'patch' '
	cat <<-EOT >expected &&
From: Te s t (Author) <test@example.net>
Subject: [PATCH] branch t/secondary

---
 f3 | 0
 f4 | 0
 f5 | 0
 3 files changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 f3
 create mode 100644 f4
 create mode 100644 f5

diff --git a/f3 b/f3
new file mode 100644
index 0000000000000000..$f1f2f3blob
diff --git a/f4 b/f4
new file mode 100644
index 0000000000000000..$f1f2f3blob
diff --git a/f5 b/f5
new file mode 100644
index 0000000000000000..$f1f2f3blob

-- 
tg: ($secondarybase..) t/secondary (depends on: t/branch2)
	EOT
	tg patch >actual &&
	test_cmp actual expected
'

test_expect_success SETUP,LASTOK 'mail' '
	PATH="$PWD/.git/dummy:$PATH" && export PATH &&
	tg mail >actual &&
	test_cmp actual expected
'

case "$test_hash_algo" in
sha1)
	f3blob=7c8ac2f8d82a1eb5
	;;
sha256)
	f3blob=7b6de9267ded53f0
	;;
esac

test_expect_success SETUP 'patch -i' '
	cat <<-EOT >expected &&
From: Te s t (Author) <test@example.net>
Subject: [PATCH] branch t/tertiary

---
 f3 | 1 +
 1 file changed, 1 insertion(+)
 create mode 100644 f3

diff --git a/f3 b/f3
new file mode 100644
index 0000000000000000..$f3blob
--- /dev/null
+++ b/f3
@@ -0,0 +1 @@
+file3

-- 
tg: ($secondarybase..) t/secondary (depends on: t/branch3)
	EOT
	tg patch -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP,LASTOK 'mail -i' '
	PATH="$PWD/.git/dummy:$PATH" && export PATH &&
	tg mail -i >actual &&
	test_cmp actual expected
'
case "$test_hash_algo" in
sha1)
	f4blob=bfd6a6583f9a9ac5
	f5blob=4806cb9df135782b
	;;
sha256)
	f4blob=a76920b2c5d13460
	f5blob=343656d54d3d9c28
	;;
esac

test_expect_success SETUP 'patch -w' '
	cat <<-EOT >expected &&
From: Te s t (Author) <test@example.net>
Subject: [PATCH] branch t/quaternary

---
 f4 | 1 +
 f5 | 1 +
 2 files changed, 2 insertions(+)
 create mode 100644 f4
 create mode 100644 f5

diff --git a/f4 b/f4
new file mode 100644
index 0000000000000000..$f4blob
--- /dev/null
+++ b/f4
@@ -0,0 +1 @@
+file4
diff --git a/f5 b/f5
new file mode 100644
index 0000000000000000..$f5blob
--- /dev/null
+++ b/f5
@@ -0,0 +1 @@
+file5

-- 
tg: ($secondarybase..) t/secondary (depends on: t/branch4 t/branch5)
	EOT
	tg patch -w >actual &&
	test_cmp actual expected
'

test_expect_success SETUP,LASTOK 'mail -w' '
	PATH="$PWD/.git/dummy:$PATH" && export PATH &&
	tg mail -w >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'prev' '
	echo t/branch2 >expected &&
	tg prev >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'prev -i' '
	echo t/branch3 >expected &&
	tg prev -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'prev -w' '
	echo t/branch5 >expected &&
	tg prev -w >actual &&
	test_cmp actual expected &&
	echo t/branch4 >expected &&
	tg prev -w -n 2 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'next' '
	echo t/secondary2 >expected &&
	tg next >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'next -i' '
	echo t/secondary >expected &&
	tg next -i t/branch3 >actual &&
	test_cmp actual expected &&
	>expected &&
	tg next -i t/branch2 >actual &&
	test_cmp actual expected &&
	tg next -i t/branch4 >actual &&
	test_cmp actual expected &&
	tg next -i t/branch5 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'next -w' '
	echo t/branch5 >expected &&
	tg next -w t/branch4 >actual &&
	test_cmp actual expected &&
	echo t/secondary >expected &&
	tg next -w t/branch5 >actual &&
	test_cmp actual expected &&
	>expected &&
	tg next -w t/branch2 >actual &&
	test_cmp actual expected &&
	tg next -w t/branch3 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary --deps-only' '
	cat <<-\EOT >expected &&
		branch2
		t/branch2
		t/secondary
	EOT
	tg summary --deps-only >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary --deps-only -i' '
	cat <<-\EOT >expected &&
		branch3
		t/branch3
		t/secondary
	EOT
	tg summary --deps-only -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary --deps-only -w' '
	cat <<-\EOT >expected &&
		branch4
		branch5
		t/branch4
		t/branch5
		t/secondary
	EOT
	tg summary --deps-only -w >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary --deps' '
	cat <<-\EOT >expected &&
t/branch1 branch1
t/branch2 branch2
t/branch3 branch3
t/branch4 branch4
t/branch5 branch5
t/primary t/branch1
t/primary2 t/primary
t/secondary t/branch2
t/secondary2 t/secondary
	EOT
	tg summary --deps >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary --deps -i' '
	cat <<-\EOT >expected &&
t/branch1 branch1
t/branch2 branch2
t/branch3 branch3
t/branch4 branch4
t/branch5 branch5
t/primary t/branch1
t/primary2 t/primary
t/secondary t/branch3
t/secondary2 t/secondary
	EOT
	tg summary --deps -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary --deps -w' '
	cat <<-\EOT >expected &&
t/branch1 branch1
t/branch2 branch2
t/branch3 branch3
t/branch4 branch4
t/branch5 branch5
t/primary t/branch1
t/primary2 t/primary
t/secondary t/branch4
t/secondary t/branch5
t/secondary2 t/secondary
	EOT
	tg summary --deps -w >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary --rdeps --heads' '
	cat <<\EOT >expected &&
t/branch3
  branch3

t/branch4
  branch4

t/branch5
  branch5

t/primary2
  t/primary
    t/branch1
      branch1

t/secondary2
  t/secondary
    t/branch2
      branch2
EOT
	tg summary --rdeps --heads >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary --rdeps --heads -i' '
	cat <<\EOT >expected &&
t/branch2
  branch2

t/branch4
  branch4

t/branch5
  branch5

t/primary2
  t/primary
    t/branch1
      branch1

t/secondary2
  t/secondary
    t/branch3
      branch3
EOT
	tg summary --rdeps --heads -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary --rdeps --heads -w' '
	cat <<\EOT >expected &&
t/branch2
  branch2

t/branch3
  branch3

t/primary2
  t/primary
    t/branch1
      branch1

t/secondary2
  t/secondary
    t/branch4
      branch4
    t/branch5
      branch5
EOT
	tg summary --rdeps --heads -w >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary -vl' '
	cat <<\EOT >expected &&
t/branch1 [PATCH] branch t/branch1
t/branch2 [PATCH] branch t/branch2
t/branch3 [PATCH] branch t/branch3
t/branch4 [PATCH] branch t/branch4
t/branch5 [PATCH] branch t/branch5
t/primary [PATCH] branch t/primary
t/primary2 [PATCH] branch t/primary2
t/secondary [PATCH] branch t/secondary
t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg summary -vl >actual &&
	test_cmp actual expected &&
	trim tg summary -vvl >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary -vl -i' '
	cat <<\EOT >expected &&
t/branch1 [PATCH] branch t/branch1
t/branch2 [PATCH] branch t/branch2
t/branch3 [PATCH] branch t/branch3
t/branch4 [PATCH] branch t/branch4
t/branch5 [PATCH] branch t/branch5
t/primary [PATCH] branch t/primary
t/primary2 [PATCH] branch t/primary2
t/secondary [PATCH] branch t/tertiary
t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg summary -vl -i >actual &&
	test_cmp actual expected &&
	trim tg summary -vvl -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary -vl -w' '
	cat <<\EOT >expected &&
t/branch1 [PATCH] branch t/branch1
t/branch2 [PATCH] branch t/branch2
t/branch3 [PATCH] branch t/branch3
t/branch4 [PATCH] branch t/branch4
t/branch5 [PATCH] branch t/branch5
t/primary [PATCH] branch t/primary
t/primary2 [PATCH] branch t/primary2
t/secondary [PATCH] branch t/quaternary
t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg summary -vl -w >actual &&
	test_cmp actual expected &&
	trim tg summary -vvl -w >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary @' '
	cat <<\EOT >expected &&
 0 t/branch2 [PATCH] branch t/branch2
> t/secondary [PATCH] branch t/secondary
 0 t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg summary @ >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary -i @' '
	cat <<\EOT >expected &&
 0 * t/branch3 [PATCH] branch t/branch3
> D t/secondary [PATCH] branch t/tertiary
 0 D t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg summary -i @ >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary -w @' '
	cat <<\EOT >expected &&
 0 * t/branch4 [PATCH] branch t/branch4
 0 * t/branch5 [PATCH] branch t/branch5
> D t/secondary [PATCH] branch t/quaternary
 0 D t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg summary -w @ >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary' '
	cat <<\EOT >expected &&
 0 t/branch1 [PATCH] branch t/branch1
 0 t/branch2 [PATCH] branch t/branch2
 0 t/branch3 [PATCH] branch t/branch3
 0 t/branch4 [PATCH] branch t/branch4
 0 t/branch5 [PATCH] branch t/branch5
 0 t/primary [PATCH] branch t/primary
 0 t/primary2 [PATCH] branch t/primary2
> t/secondary [PATCH] branch t/secondary
 0 t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg summary >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary -i' '
	cat <<\EOT >expected &&
 0 t/branch1 [PATCH] branch t/branch1
 0 t/branch2 [PATCH] branch t/branch2
 0 * t/branch3 [PATCH] branch t/branch3
 0 t/branch4 [PATCH] branch t/branch4
 0 t/branch5 [PATCH] branch t/branch5
 0 t/primary [PATCH] branch t/primary
 0 t/primary2 [PATCH] branch t/primary2
> D t/secondary [PATCH] branch t/tertiary
 0 D t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg summary -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'summary -w' '
	cat <<\EOT >expected &&
 0 t/branch1 [PATCH] branch t/branch1
 0 t/branch2 [PATCH] branch t/branch2
 0 t/branch3 [PATCH] branch t/branch3
 0 * t/branch4 [PATCH] branch t/branch4
 0 * t/branch5 [PATCH] branch t/branch5
 0 t/primary [PATCH] branch t/primary
 0 t/primary2 [PATCH] branch t/primary2
> D t/secondary [PATCH] branch t/quaternary
 0 D t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg summary -w >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info' '
	cat <<EOT >expected &&
Topic Branch: t/secondary (2/2 commits)
Subject: [PATCH] branch t/secondary
Base: $secondarybase
Depends: t/branch2
Up-to-date.
EOT
	trim tg info >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info -i' '
	cat <<EOT >expected &&
Topic Branch: t/secondary (2/2 commits)
Subject: [PATCH] branch t/tertiary
Base: $secondarybase
Depends: t/branch3
Needs update from:
 t/branch3 (2/2 commits)
EOT
	trim tg info -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info -w' '
	cat <<EOT >expected &&
Topic Branch: t/secondary (2/2 commits)
Subject: [PATCH] branch t/quaternary
Base: $secondarybase
Depends: t/branch4
 t/branch5
Needs update from:
 t/branch4 (2/2 commits)
 t/branch5 (2/2 commits)
EOT
	trim tg info -w >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info -v' '
	cat <<EOT >expected &&
Topic Branch: t/secondary (2/2 commits)
Subject: [PATCH] branch t/secondary
Dependents: t/secondary2
Base: $secondarybase
Depends: t/branch2
Up-to-date.
EOT
	trim tg info -v >actual &&
	test_cmp actual expected
'

case "$test_hash_algo" in
sha1)
	quaternarybase=8f7ce5c9f088954c
	branch2base=64ef3d8ae1560635
	branch3base=231a8797a3d0de74
	branch4base=f6890848ee0253af
	branch5base=261e548eac1f8d28
	;;
sha256)
	quaternarybase=1ed0c61ee3ddc0dc
	branch2base=341670e4d25e58c8
	branch3base=80b378eef7859f1e
	branch4base=6d0162e00d6052c2
	branch5base=864390011614c02a
	;;
esac

test_expect_success SETUP 'info -v -i' '
	cat <<EOT >expected &&
Topic Branch: t/secondary (2/2 commits)
Subject: [PATCH] branch t/tertiary
Dependents: t/secondary2
Base: $secondarybase
Depends: t/branch3
Needs update from:
 t/branch3 (2/2 commits)
EOT
	trim tg info -v -i >actual &&
	test_cmp actual expected &&
	cat <<EOT >expected &&
Topic Branch: t/branch3 (1/1 commit)
Subject: [PATCH] branch t/branch3
Dependents: t/secondary
Base: $branch3base
Depends: branch3
Up-to-date.
EOT
	trim tg info -v -i t/branch3 >actual &&
	test_cmp actual expected &&
	cat <<EOT >expected &&
Topic Branch: t/branch2 (1/1 commit)
Subject: [PATCH] branch t/branch2
Dependents: [none]
Base: $branch2base
Depends: branch2
Up-to-date.
EOT
	trim tg info -v -i t/branch2 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info -v -w' '
	cat <<EOT >expected &&
Topic Branch: t/secondary (2/2 commits)
Subject: [PATCH] branch t/quaternary
Dependents: t/secondary2
Base: $quaternarybase
Depends: t/branch4
 t/branch5
Needs update from:
 t/branch4 (2/2 commits)
 t/branch5 (2/2 commits)
EOT
	trim tg info -v -w >actual &&
	test_cmp actual expected &&
	cat <<EOT >expected &&
Topic Branch: t/branch4 (1/1 commit)
Subject: [PATCH] branch t/branch4
Dependents: t/secondary
Base: $branch4base
Depends: branch4
Up-to-date.
EOT
	trim tg info -v -w t/branch4 >actual &&
	test_cmp actual expected &&
	cat <<EOT >expected &&
Topic Branch: t/branch5 (1/1 commit)
Subject: [PATCH] branch t/branch5
Dependents: t/secondary
Base: $branch5base
Depends: branch5
Up-to-date.
EOT
	trim tg info -v -w t/branch5 >actual &&
	test_cmp actual expected &&
	cat <<EOT >expected &&
Topic Branch: t/branch2 (1/1 commit)
Subject: [PATCH] branch t/branch2
Dependents: [none]
Base: $branch2base
Depends: branch2
Up-to-date.
EOT
	trim tg info -v -w t/branch2 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info -v -v' '
	cat <<EOT >expected &&
Topic Branch: t/secondary (2/2 commits)
Subject: [PATCH] branch t/secondary
Dependents: t/secondary2
Base: $secondarybase
Depends: t/branch2
Up-to-date.
EOT
	trim tg info -v -v >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info -v -v -i' '
	cat <<EOT >expected &&
Topic Branch: t/secondary (2/2 commits)
Subject: [PATCH] branch t/tertiary
Dependents: t/secondary2
Base: $secondarybase
Depends: t/branch3
Needs update from:
 t/branch3 (2/2 commits)
EOT
	trim tg info -v -v -i >actual &&
	test_cmp actual expected &&
	cat <<EOT >expected &&
Topic Branch: t/branch3 (1/1 commit)
Subject: [PATCH] branch t/branch3
Dependents: t/secondary [needs merge]
Base: $branch3base
Depends: branch3
Up-to-date.
EOT
	trim tg info -v -v -i t/branch3 >actual &&
	test_cmp actual expected &&
	cat <<EOT >expected &&
Topic Branch: t/branch2 (1/1 commit)
Subject: [PATCH] branch t/branch2
Dependents: [none]
Base: $branch2base
Depends: branch2
Up-to-date.
EOT
	trim tg info -v -v -i t/branch2 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info -v -v -w' '
	cat <<EOT >expected &&
Topic Branch: t/secondary (2/2 commits)
Subject: [PATCH] branch t/quaternary
Dependents: t/secondary2
Base: $secondarybase
Depends: t/branch4
 t/branch5
Needs update from:
 t/branch4 (2/2 commits)
 t/branch5 (2/2 commits)
EOT
	trim tg info -v -v -w >actual &&
	test_cmp actual expected &&
	cat <<EOT >expected &&
Topic Branch: t/branch4 (1/1 commit)
Subject: [PATCH] branch t/branch4
Dependents: t/secondary [needs merge]
Base: $branch4base
Depends: branch4
Up-to-date.
EOT
	trim tg info -v -v -w t/branch4 >actual &&
	test_cmp actual expected &&
	cat <<EOT >expected &&
Topic Branch: t/branch5 (1/1 commit)
Subject: [PATCH] branch t/branch5
Dependents: t/secondary [needs merge]
Base: $branch5base
Depends: branch5
Up-to-date.
EOT
	trim tg info -v -v -w t/branch5 >actual &&
	test_cmp actual expected &&
	cat <<EOT >expected &&
Topic Branch: t/branch2 (1/1 commit)
Subject: [PATCH] branch t/branch2
Dependents: [none]
Base: $branch2base
Depends: branch2
Up-to-date.
EOT
	trim tg info -v -v -w t/branch2 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --dependencies' '
	cat <<-\EOT >expected &&
		t/branch2
	EOT
	tg info --dependencies >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --dependencies -i' '
	cat <<-\EOT >expected &&
		t/branch3
	EOT
	tg info --dependencies -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --dependencies -w' '
	cat <<-\EOT >expected &&
		t/branch4
		t/branch5
	EOT
	tg info --dependencies -w >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --dependents' '
	cat <<-\EOT >expected &&
		t/secondary2
	EOT
	tg info --dependents >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/secondary
	EOT
	tg info --dependents t/branch2 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --dependents -i' '
	cat <<-\EOT >expected &&
		t/secondary2
	EOT
	tg info --dependents -i >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/secondary
	EOT
	tg info --dependents -i t/branch3 >actual &&
	test_cmp actual expected &&
	>expected &&
	tg info --dependents -i t/branch2 >actual &&
	test_cmp actual expected &&
	tg info --dependents -i t/branch4 >actual &&
	test_cmp actual expected &&
	tg info --dependents -i t/branch5 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --dependents -w' '
	cat <<-\EOT >expected &&
		t/secondary2
	EOT
	tg info --dependents -w >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/secondary
	EOT
	tg info --dependents -w t/branch4 >actual &&
	test_cmp actual expected &&
	tg info --dependents -w t/branch5 >actual &&
	test_cmp actual expected &&
	>expected &&
	tg info --dependents -w t/branch2 >actual &&
	test_cmp actual expected &&
	tg info --dependents -w t/branch3 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --series' '
	cat <<\EOT >expected &&
 t/branch2 [PATCH] branch t/branch2
* t/secondary [PATCH] branch t/secondary
 t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg info --series >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --series -i' '
	cat <<\EOT >expected &&
 t/branch3 [PATCH] branch t/branch3
* t/secondary [PATCH] branch t/tertiary
 t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg info --series -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --series -w' '
	cat <<\EOT >expected &&
 t/branch4 [PATCH] branch t/branch4
 t/branch5 [PATCH] branch t/branch5
* t/secondary [PATCH] branch t/quaternary
 t/secondary2 [PATCH] branch t/secondary2
EOT
	trim tg info --series -w >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --leaves' '
	cat <<-\EOT >expected &&
		refs/heads/branch2
	EOT
	tg info --leaves >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --leaves -i' '
	cat <<-\EOT >expected &&
		refs/heads/branch3
	EOT
	tg info --leaves -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --leaves -w' '
	cat <<-\EOT >expected &&
		refs/heads/branch4
		refs/heads/branch5
	EOT
	tg info --leaves -w >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --heads' '
	cat <<-\EOT >expected &&
		t/secondary2
	EOT
	tg info --heads >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --heads -i' '
	cat <<-\EOT >expected &&
		t/secondary2
	EOT
	tg info --heads -i >actual &&
	test_cmp actual expected &&
	tg info --heads -i t/branch3 >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/branch2
	EOT
	tg info --heads -i t/branch2 >actual &&
	cat <<-\EOT >expected &&
		t/branch4
	EOT
	tg info --heads -i t/branch4 >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/branch5
	EOT
	tg info --heads -i t/branch5 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'info --heads -w' '
	cat <<-\EOT >expected &&
		t/secondary2
	EOT
	tg info --heads -w >actual &&
	test_cmp actual expected &&
	tg info --heads -w t/branch4 >actual &&
	test_cmp actual expected &&
	tg info --heads -w t/branch5 >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/branch2
	EOT
	tg info --heads -w t/branch2 >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/branch3
	EOT
	tg info --heads -w t/branch3 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'setup detached HEAD' '
	git update-ref --no-deref HEAD HEAD^0 HEAD^0 &&
	test_must_fail git symbolic-ref HEAD >/dev/null 2>&1 &&
	test_when_finished test_set_prereq SETUP2
'

test_expect_success SETUP2 'detached info --heads' '
	cat <<-\EOT >expected &&
		t/secondary2
	EOT
	tg info --heads >actual &&
	test_cmp actual expected
'

test_expect_success SETUP2 'detached info --heads -i' '
	cat <<-\EOT >expected &&
		t/secondary2
	EOT
	tg info --heads -i >actual &&
	test_cmp actual expected &&
	tg info --heads -i t/branch2 >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/branch3
	EOT
	tg info --heads -i t/branch3 >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/branch4
	EOT
	tg info --heads -i t/branch4 >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/branch5
	EOT
	tg info --heads -i t/branch5 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP2 'detached info --heads -w' '
	cat <<-\EOT >expected &&
		t/secondary2
	EOT
	tg info --heads -w >actual &&
	test_cmp actual expected &&
	tg info --heads -w t/branch2 >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/branch3
	EOT
	tg info --heads -w t/branch3 >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/branch4
	EOT
	tg info --heads -w t/branch4 >actual &&
	test_cmp actual expected &&
	cat <<-\EOT >expected &&
		t/branch5
	EOT
	tg info --heads -w t/branch5 >actual &&
	test_cmp actual expected
'

test_done
