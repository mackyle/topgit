#!/bin/sh

test_description='use of -i/-w options with tg commands that support them

These are the -i and -w options that cause the index or working tree to be
used, respectively, not any other meanings they might have.

Specifically files, mail, next, patch, prev and summary subcommands.
'

. ./test-lib.sh

test_plan 36

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
		Base: 8e476c63c7ef4558
		Depends: t/branch1
		Up-to-date.
	EOT
	trim tg info -v t/primary >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		Topic Branch: t/secondary (2/2 commits)
		Subject: [PATCH] branch t/secondary
		Dependents: t/secondary2
		Base: 8f7ce5c9f088954c
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

test_expect_success SETUP 'patch' '
	cat <<-\EOT >expected &&
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
index 0000000000000000..e69de29bb2d1d643
diff --git a/f4 b/f4
new file mode 100644
index 0000000000000000..e69de29bb2d1d643
diff --git a/f5 b/f5
new file mode 100644
index 0000000000000000..e69de29bb2d1d643

-- 
tg: (8f7ce5c9f088954c..) t/secondary (depends on: t/branch2)
	EOT
	tg patch >actual &&
	test_cmp actual expected
'

test_expect_success SETUP,LASTOK 'mail' '
	PATH="$PWD/.git/dummy:$PATH" && export PATH &&
	tg mail >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'patch -i' '
	cat <<-\EOT >expected &&
From: Te s t (Author) <test@example.net>
Subject: [PATCH] branch t/tertiary

---
 f3 | 1 +
 1 file changed, 1 insertion(+)
 create mode 100644 f3

diff --git a/f3 b/f3
new file mode 100644
index 0000000000000000..7c8ac2f8d82a1eb5
--- /dev/null
+++ b/f3
@@ -0,0 +1 @@
+file3

-- 
tg: (8f7ce5c9f088954c..) t/secondary (depends on: t/branch3)
	EOT
	tg patch -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP,LASTOK 'mail -i' '
	PATH="$PWD/.git/dummy:$PATH" && export PATH &&
	tg mail -i >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'patch -w' '
	cat <<-\EOT >expected &&
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
index 0000000000000000..bfd6a6583f9a9ac5
--- /dev/null
+++ b/f4
@@ -0,0 +1 @@
+file4
diff --git a/f5 b/f5
new file mode 100644
index 0000000000000000..4806cb9df135782b
--- /dev/null
+++ b/f5
@@ -0,0 +1 @@
+file5

-- 
tg: (8f7ce5c9f088954c..) t/secondary (depends on: t/branch4 t/branch5)
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

test_done
