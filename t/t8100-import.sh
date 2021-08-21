#!/bin/sh

test_description='tg import tests'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 11

case "$test_hash_algo" in
sha1)
	startblob=1a2b97e
	oneblob=9a60eae
	;;
sha256)
	startblob=39390ba
	oneblob=1299efa
	;;
esac

test_expect_success 'default branch import' '
	test_create_repo r1 && cd r1 &&
	test_commit --notick start^here &&
	git branch base &&
	test_commit --notick one^ &&
	test_commit --notick two^ &&
	test_commit --notick three^ &&
	git checkout base &&
	tg import base..master &&
	printf "%s" "\
t/one [PATCH] one^
t/three [PATCH] three^
t/two [PATCH] two^
" > ../expected &&
	tg summary -v -l | tr -s "\\t" " " > ../actual &&
	test_diff ../expected ../actual &&
	printf "%s" "\
t/three
  t/two
    t/one
      base
" > ../expected &&
	tg summary --rdeps --heads > ../actual &&
	test_diff ../expected ../actual &&
	test_cmp_rev base "$(tg base t/one)" &&
	git diff --exit-code master t/three -- :/ :\!/.topdeps :\!/.topmsg
'

test_expect_success 'specified branch import' '
	test_create_repo r2 && cd r2 &&
	test_commit --notick start^here &&
	git branch base &&
	test_commit --notick one^ &&
	test_commit --notick two^ &&
	test_commit --notick three^ &&
	git checkout --orphan alt &&
	git read-tree --empty &&
	git commit --allow-empty -m "empty" &&
	git clean -d -f -x &&
	git checkout base &&
	tg import -d alt base..master &&
	printf "%s" "\
t/one [PATCH] one^
t/three [PATCH] three^
t/two [PATCH] two^
" > ../expected &&
	tg summary -v -l | tr -s "\\t" " " > ../actual &&
	test_diff ../expected ../actual &&
	printf "%s" "\
t/three
  t/two
    t/one
      alt
" > ../expected &&
	tg summary --rdeps --heads > ../actual &&
	test_diff ../expected ../actual &&
	test_cmp_rev alt "$(tg base t/one)" &&
	printf "%s" "\
diff --git a/start^here.t b/start^here.t
deleted file mode 100644
index $startblob..0000000
--- a/start^here.t
+++ /dev/null
@@ -1 +0,0 @@
-start^here
" > ../expected &&
	git diff master t/three -- :/ :\!/.topdeps :\!/.topmsg > ../actual &&
	test_diff ../expected ../actual
'

test_expect_success 'specified branch import HEAD relative range' '
	test_create_repo r3 && cd r3 &&
	test_commit --notick start^here &&
	git branch base &&
	test_commit --notick one^ &&
	test_commit --notick two^ &&
	test_commit --notick three^ &&
	git checkout --orphan alt &&
	git read-tree --empty &&
	git commit --allow-empty -m "empty" &&
	git clean -d -f -x &&
	git checkout master &&
	tg import -d alt HEAD~3..HEAD &&
	printf "%s" "\
t/one [PATCH] one^
t/three [PATCH] three^
t/two [PATCH] two^
" > ../expected &&
	tg summary -v -l | tr -s "\\t" " " > ../actual &&
	test_diff ../expected ../actual &&
	printf "%s" "\
t/three
  t/two
    t/one
      alt
" > ../expected &&
	tg summary --rdeps --heads > ../actual &&
	test_diff ../expected ../actual &&
	test_cmp_rev alt "$(tg base t/one)" &&
	printf "%s" "\
diff --git a/start^here.t b/start^here.t
deleted file mode 100644
index $startblob..0000000
--- a/start^here.t
+++ /dev/null
@@ -1 +0,0 @@
-start^here
" > ../expected &&
	git diff master t/three -- :/ :\!/.topdeps :\!/.topmsg > ../actual &&
	test_diff ../expected ../actual
'
test_expect_success 'specified branch import foo..HEAD implied relative range' '
	test_create_repo r4 && cd r4 &&
	test_commit --notick start^here &&
	git branch base &&
	test_commit --notick one^ &&
	test_commit --notick two^ &&
	test_commit --notick three^ &&
	git checkout --orphan alt &&
	git read-tree --empty &&
	git commit --allow-empty -m "empty" &&
	git clean -d -f -x &&
	git checkout master &&
	tg import -d alt HEAD~3.. &&
	printf "%s" "\
t/one [PATCH] one^
t/three [PATCH] three^
t/two [PATCH] two^
" > ../expected &&
	tg summary -v -l | tr -s "\\t" " " > ../actual &&
	test_diff ../expected ../actual &&
	printf "%s" "\
t/three
  t/two
    t/one
      alt
" > ../expected &&
	tg summary --rdeps --heads > ../actual &&
	test_diff ../expected ../actual &&
	test_cmp_rev alt "$(tg base t/one)" &&
	printf "%s" "\
diff --git a/start^here.t b/start^here.t
deleted file mode 100644
index $startblob..0000000
--- a/start^here.t
+++ /dev/null
@@ -1 +0,0 @@
-start^here
" > ../expected &&
	git diff master t/three -- :/ :\!/.topdeps :\!/.topmsg > ../actual &&
	test_diff ../expected ../actual
'

test_expect_success 'specified branch import HEAD..foo implied relative range' '
	test_create_repo r5 && cd r5 &&
	test_commit --notick start^here &&
	git branch base &&
	test_commit --notick one^ &&
	test_commit --notick two^ &&
	test_commit --notick three^ &&
	git checkout --orphan alt &&
	git read-tree --empty &&
	git commit --allow-empty -m "empty" &&
	git clean -d -f -x &&
	git checkout base &&
	tg import -d alt ..master &&
	printf "%s" "\
t/one [PATCH] one^
t/three [PATCH] three^
t/two [PATCH] two^
" > ../expected &&
	tg summary -v -l | tr -s "\\t" " " > ../actual &&
	test_diff ../expected ../actual &&
	printf "%s" "\
t/three
  t/two
    t/one
      alt
" > ../expected &&
	tg summary --rdeps --heads > ../actual &&
	test_diff ../expected ../actual &&
	test_cmp_rev alt "$(tg base t/one)" &&
	printf "%s" "\
diff --git a/start^here.t b/start^here.t
deleted file mode 100644
index $startblob..0000000
--- a/start^here.t
+++ /dev/null
@@ -1 +0,0 @@
-start^here
" > ../expected &&
	git diff master t/three -- :/ :\!/.topdeps :\!/.topmsg > ../actual &&
	test_diff ../expected ../actual
'

test_expect_success 'specified branch import HEAD relative single commit range' '
	test_create_repo r6 && cd r6 &&
	test_commit --notick start^here &&
	git branch base &&
	test_commit --notick one^ &&
	test_commit --notick two^ &&
	git tag "test#2" &&
	test_commit --notick three^ &&
	git checkout --orphan alt &&
	git read-tree --empty &&
	git commit --allow-empty -m "empty" &&
	git clean -d -f -x &&
	git checkout master &&
	tg import -d alt HEAD~^\! &&
	printf "%s" "\
t/two [PATCH] two^
" > ../expected &&
	tg summary -v -l | tr -s "\\t" " " > ../actual &&
	test_diff ../expected ../actual &&
	printf "%s" "\
t/two
  alt
" > ../expected &&
	tg summary --rdeps --heads > ../actual &&
	test_diff ../expected ../actual &&
	test_cmp_rev alt "$(tg base t/two)" &&
	printf "%s" "\
diff --git a/one^.t b/one^.t
deleted file mode 100644
index $oneblob..0000000
--- a/one^.t
+++ /dev/null
@@ -1 +0,0 @@
-one^
diff --git a/start^here.t b/start^here.t
deleted file mode 100644
index $startblob..0000000
--- a/start^here.t
+++ /dev/null
@@ -1 +0,0 @@
-start^here
" > ../expected &&
	git diff "test#2" t/two -- :/ :\!/.topdeps :\!/.topmsg > ../actual &&
	test_diff ../expected ../actual
'

test_expect_success 'default unrelated branch import' '
	test_create_repo r7 && cd r7 &&
	test_commit --notick start^here &&
	git branch base &&
	test_commit --notick one^ &&
	test_commit --notick two^ &&
	test_commit --notick three^ &&
	git checkout --orphan alt &&
	git read-tree --empty &&
	git commit --allow-empty -m "empty" &&
	git clean -d -f -x &&
	tg import base..master &&
	printf "%s" "\
t/one [PATCH] one^
t/three [PATCH] three^
t/two [PATCH] two^
" > ../expected &&
	tg summary -v -l | tr -s "\\t" " " > ../actual &&
	test_diff ../expected ../actual &&
	printf "%s" "\
t/three
  t/two
    t/one
      alt
" > ../expected &&
	tg summary --rdeps --heads > ../actual &&
	test_diff ../expected ../actual &&
	test_cmp_rev alt "$(tg base t/one)" &&
	printf "%s" "\
diff --git a/start^here.t b/start^here.t
deleted file mode 100644
index $startblob..0000000
--- a/start^here.t
+++ /dev/null
@@ -1 +0,0 @@
-start^here
" > ../expected &&
	git diff master t/three -- :/ :\!/.topdeps :\!/.topmsg > ../actual &&
	test_diff ../expected ../actual
'

test_expect_success 'HEAD unrelated branch import' '
	test_create_repo r8 && cd r8 &&
	test_commit --notick start^here &&
	git branch base &&
	test_commit --notick one^ &&
	test_commit --notick two^ &&
	test_commit --notick three^ &&
	git checkout --orphan alt &&
	git read-tree --empty &&
	git commit --allow-empty -m "empty" &&
	git clean -d -f -x &&
	tg import -d HEAD base..master &&
	printf "%s" "\
t/one [PATCH] one^
t/three [PATCH] three^
t/two [PATCH] two^
" > ../expected &&
	tg summary -v -l | tr -s "\\t" " " > ../actual &&
	test_diff ../expected ../actual &&
	printf "%s" "\
t/three
  t/two
    t/one
      alt
" > ../expected &&
	tg summary --rdeps --heads > ../actual &&
	test_diff ../expected ../actual &&
	test_cmp_rev alt "$(tg base t/one)" &&
	printf "%s" "\
diff --git a/start^here.t b/start^here.t
deleted file mode 100644
index $startblob..0000000
--- a/start^here.t
+++ /dev/null
@@ -1 +0,0 @@
-start^here
" > ../expected &&
	git diff master t/three -- :/ :\!/.topdeps :\!/.topmsg > ../actual &&
	test_diff ../expected ../actual
'

test_expect_success '@ unrelated branch import' '
	test_create_repo r9 && cd r9 &&
	test_commit --notick start^here &&
	git branch base &&
	test_commit --notick one^ &&
	test_commit --notick two^ &&
	test_commit --notick three^ &&
	git checkout --orphan alt &&
	git read-tree --empty &&
	git commit --allow-empty -m "empty" &&
	git clean -d -f -x &&
	tg import -d HEAD base..master &&
	printf "%s" "\
t/one [PATCH] one^
t/three [PATCH] three^
t/two [PATCH] two^
" > ../expected &&
	tg summary -v -l | tr -s "\\t" " " > ../actual &&
	test_diff ../expected ../actual &&
	printf "%s" "\
t/three
  t/two
    t/one
      alt
" > ../expected &&
	tg summary --rdeps --heads > ../actual &&
	test_diff ../expected ../actual &&
	test_cmp_rev alt "$(tg base t/one)" &&
	printf "%s" "\
diff --git a/start^here.t b/start^here.t
deleted file mode 100644
index $startblob..0000000
--- a/start^here.t
+++ /dev/null
@@ -1 +0,0 @@
-start^here
" > ../expected &&
	git diff master t/three -- :/ :\!/.topdeps :\!/.topmsg > ../actual &&
	test_diff ../expected ../actual
'

test_expect_success 'detached HEAD import fails' '
	test_create_repo r10 && cd r10 &&
	test_commit --notick start^here &&
	git branch base &&
	test_commit --notick one^ &&
	test_commit --notick two^ &&
	test_commit --notick three^ &&
	git checkout --orphan alt &&
	git read-tree --empty &&
	git commit --allow-empty -m "empty" &&
	git clean -d -f -x &&
	git checkout --detach HEAD &&
	test_must_fail tg import base..master &&
	test_must_fail tg import -d HEAD base..master &&
	test_must_fail tg import -d @ base..master
'

auh_opt=
! vcmp "$git_version" '>=' "2.9" || auh_opt="--allow-unrelated-histories"

test_expect_success 'single commit range requires exactly one parent' '
	test_create_repo r11 && cd r11 &&
	test_commit --notick start^here &&
	git branch base &&
	git checkout --orphan alt &&
	git read-tree --empty &&
	git commit --allow-empty -m empty &&
	git clean -d -f -x &&
	git checkout master &&
	git merge $auh_opt -m merged alt &&
	test_must_fail tg import HEAD^\! &&
	test_must_fail tg import base^\!
'

test_done
