#!/bin/sh

test_description='check summary output'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 29

reset_repo() {
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/orphan
}

squish() {
	tab="	" # single tab in there
	tr -s "$tab" " "
}

test_expect_success 'setup' '
	test_create_repo pristine && cd pristine &&
	git checkout --orphan rootcommit &&
	git read-tree --empty &&
	test_tick &&
	git commit --allow-empty -m "empty root commit" &&
	git tag rootcommit &&
	git checkout --orphan branch1 &&
	git read-tree --empty &&
	test_commit branch1-start &&
	git checkout --orphan branch2 &&
	git read-tree --empty &&
	test_commit branch2-start &&
	git checkout --orphan branch3 &&
	git read-tree --empty &&
	test_commit branch3-start &&
	reset_repo &&
	git clean -x -d -f &&
	tg_test_create_branches <<-EOT &&
		rootbare bare empty root
		::

		rootmsg topmsg root
		:~

		rootdeps --no-topmsg topdeps root
		:

		root standard root branch
		:

		annihilated annihilated branch
		::

		basebare bare base
		::rootcommit

		+basebare bare base
		:::basebare

		t/branch1 branch1 topgit
		branch1

		t/branch2 branch2 topgit
		branch2

		t/branch3 branch3 topgit
		branch3

		reused-1level1 reused with one tg branch below
		t/branch1

		reused-2level1 reused with two tg branches below
		t/branch1
		t/branch2

		reused-1level2 reused with one tg branch below
		reused-1level1

		reused-2level2 reused with two tg branches below
		reused-1level1
		reused-2level1

		reused-multi multi-level reuse
		reused-2level1
		t/branch3
		reused-2level2

	EOT
	git checkout -f annihilated &&
	test_tick &&
	git commit --allow-empty -m "annihilated not empty" &&
	reset_repo &&
	git clean -x -d -f &&
	cd .. &&
	cp -pR pristine copy
'

test_expect_success 'bad usage' '
	cd copy && reset_repo &&

	# HEAD is unborn
	test_must_fail tg summary --rdeps && # bad HEAD default
	test_must_fail tg summary --rdeps-once && # bad HEAD default
	test_must_fail tg summary --rdeps-full && # bad HEAD default
	test_must_fail tg summary --with-deps && # bad HEAD default
	test_must_fail tg summary --without-deps && # bad HEAD default
	test_must_fail tg summary --deps-only && # bad HEAD default
	test_must_fail tg summary --deps HEAD && # bad HEAD (--deps does not default)

	git update-ref --no-deref HEAD branch1 &&

	# HEAD is detached
	test_must_fail tg summary --rdeps && # bad HEAD default
	test_must_fail tg summary --rdeps-once && # bad HEAD default
	test_must_fail tg summary --rdeps-full && # bad HEAD default
	test_must_fail tg summary --with-deps && # bad HEAD default
	test_must_fail tg summary --without-deps && # bad HEAD default
	test_must_fail tg summary --deps-only && # bad HEAD default
	test_must_fail tg summary --deps HEAD && # bad HEAD (--deps does not default)

	git symbolic-ref HEAD refs/heads/branch3 &&

	# HEAD is a non-TopGit branch
	test_must_fail tg summary --rdeps && # bad HEAD default
	test_must_fail tg summary --rdeps-once && # bad HEAD default
	test_must_fail tg summary --rdeps-full && # bad HEAD default
	test_must_fail tg summary --with-deps && # bad HEAD default
	test_must_fail tg summary --without-deps && # bad HEAD default
	test_must_fail tg summary --deps-only && # bad HEAD default
	test_must_fail tg summary --deps HEAD && # bad HEAD (--deps does not default)

	: # placeholder
'

printf "%s" "\
         basebare                      	branch basebare (missing .topmsg)
 0       reused-1level1                	[PATCH] reused with one tg branch below
 0       reused-1level2                	[PATCH] reused with one tg branch below
 0  D  * reused-2level1                	[PATCH] reused with two tg branches below
 0  D  * reused-2level2                	[PATCH] reused with two tg branches below
 0  D    reused-multi                  	[PATCH] multi-level reuse
 0       root                          	[PATCH] standard root branch
 0       rootdeps                      	branch rootdeps (missing .topmsg)
 0       rootmsg                       	[PATCH] topmsg root
 0       t/branch1                     	[PATCH] branch1 topgit
 0     * t/branch2                     	[PATCH] branch2 topgit
 0     * t/branch3                     	[PATCH] branch3 topgit
" > pristine_full_summary.raw ||
	die failed to make pristine_full_summary.raw
< pristine_full_summary.raw squish > pristine_full_summary ||
	die failed to make pristine_full_summary

printf "%s" "\
 0       reused-1level1                	[PATCH] reused with one tg branch below
 0  D  * reused-2level1                	[PATCH] reused with two tg branches below
 0  D  * reused-2level2                	[PATCH] reused with two tg branches below
 0  D    reused-multi                  	[PATCH] multi-level reuse
 0       t/branch1                     	[PATCH] branch1 topgit
 0     * t/branch2                     	[PATCH] branch2 topgit
 0     * t/branch3                     	[PATCH] branch3 topgit
" > pristine_multi_summary.raw ||
	die failed to make pristine_multi_summary.raw
< pristine_multi_summary.raw squish > pristine_multi_summary ||
	die failed to make pristine_multi_summary

printf "%s" "\
 0  D    reused-2level1                	[PATCH] reused with two tg branches below
 0       t/branch1                     	[PATCH] branch1 topgit
 0     * t/branch2                     	[PATCH] branch2 topgit
" > pristine_2level1_summary.raw ||
	die failed to make pristine_2level1_summary.raw
< pristine_2level1_summary.raw squish > pristine_2level1_summary ||
	die failed to make pristine_2level1_summary

printf "%s" "\
basebare
reused-1level1
reused-1level2
reused-2level1
reused-2level2
reused-multi
root
rootdeps
rootmsg
t/branch1
t/branch2
t/branch3
" >pristine_list || die failed to make pristine_list

printf "%s" "\
reused-1level1 t/branch1
reused-1level2 reused-1level1
reused-2level1 t/branch1
reused-2level1 t/branch2
reused-2level2 reused-1level1
reused-2level2 reused-2level1
reused-multi reused-2level1
reused-multi t/branch3
reused-multi reused-2level2
" >pristine_deps || die failed to make pristine_deps

printf "%s" "\
basebare
branch1
branch2
branch3
reused-1level1
reused-1level2
reused-2level1
reused-2level2
reused-multi
root
rootdeps
rootmsg
t/branch1
t/branch2
t/branch3
" >pristine_deps_only_all || die failed to make pristine_deps_only_all

printf "%s" "\
reused-multi
reused-2level2
reused-2level1
reused-1level2
reused-1level1
t/branch3
t/branch2
t/branch1
branch3
branch2
branch1
" >pristine_sort || die failed to make pristine_sort

printf "%s" \
'# GraphViz output; pipe to:
#   | dot -Tpng -o <output>
# or
#   | dot -Txlib

digraph G {

graph [
  rankdir = "TB"
  label="TopGit Layout\n\n\n"
  fontsize = 14
  labelloc=top
  pad = "0.5,0.5"
];

"reused-1level1" -> "t/branch1";
"reused-1level2" -> "reused-1level1";
"reused-2level1" -> "t/branch1";
"reused-2level1" -> "t/branch2";
"reused-2level2" -> "reused-1level1";
"reused-2level2" -> "reused-2level1";
"reused-multi" -> "reused-2level1";
"reused-multi" -> "t/branch3";
"reused-multi" -> "reused-2level2";
"t/branch1" -> "branch1";
"t/branch2" -> "branch2";
"t/branch3" -> "branch3";
}
' >pristine_graphviz || die failed to make pristine_graphviz

printf "%s" "\
basebare
reused-1level2
reused-multi
root
rootdeps
rootmsg
" >pristine_heads || die failed to make pristine_heads

printf "%s" "\
basebare                               	branch basebare (missing .topmsg)
reused-1level1                         	[PATCH] reused with one tg branch below
reused-1level2                         	[PATCH] reused with one tg branch below
reused-2level1                         	[PATCH] reused with two tg branches below
reused-2level2                         	[PATCH] reused with two tg branches below
reused-multi                           	[PATCH] multi-level reuse
root                                   	[PATCH] standard root branch
rootbare                               	branch rootbare (no commits)
rootdeps                               	branch rootdeps (missing .topmsg)
rootmsg                                	[PATCH] topmsg root
t/branch1                              	[PATCH] branch1 topgit
t/branch2                              	[PATCH] branch2 topgit
t/branch3                              	[PATCH] branch3 topgit
" > pristine_list_verbose.raw ||
	die failed to make pristine_list_verbose.raw
< pristine_list_verbose.raw squish > pristine_list_verbose ||
	die failed to make pristine_list_verbose

printf "%s" "\
         basebare                      	branch basebare (missing .topmsg)
 0       reused-1level2                	[PATCH] reused with one tg branch below
 0  D    reused-multi                  	[PATCH] multi-level reuse
 0       root                          	[PATCH] standard root branch
 0       rootdeps                      	branch rootdeps (missing .topmsg)
 0       rootmsg                       	[PATCH] topmsg root
" > pristine_heads_only.raw ||
	die failed to make pristine_heads_only.raw
< pristine_heads_only.raw squish > pristine_heads_only ||
	die failed to make pristine_heads_only

printf "%s" "\
annihilated                            	branch annihilated (annihilated)
basebare                               	branch basebare (missing .topmsg)
reused-1level1                         	[PATCH] reused with one tg branch below
reused-1level2                         	[PATCH] reused with one tg branch below
reused-2level1                         	[PATCH] reused with two tg branches below
reused-2level2                         	[PATCH] reused with two tg branches below
reused-multi                           	[PATCH] multi-level reuse
root                                   	[PATCH] standard root branch
rootbare                               	branch rootbare (no commits)
rootdeps                               	branch rootdeps (missing .topmsg)
rootmsg                                	[PATCH] topmsg root
t/branch1                              	[PATCH] branch1 topgit
t/branch2                              	[PATCH] branch2 topgit
t/branch3                              	[PATCH] branch3 topgit
" > pristine_list_verbose2.raw ||
	die failed to make pristine_list_verbose2.raw
< pristine_list_verbose2.raw squish > pristine_list_verbose2 ||
	die failed to make pristine_list_verbose2

printf "%s" "\
basebare

reused-1level2
  reused-1level1
    t/branch1
      branch1

reused-multi
  reused-2level1
    t/branch1
      branch1
    t/branch2
      branch2
  t/branch3
    branch3
  reused-2level2
    reused-1level1
      t/branch1
        branch1
    reused-2level1
      t/branch1
        branch1
      t/branch2
        branch2

root

rootdeps

rootmsg
" >pristine_rdeps_full_heads || die failed to make pristine_rdeps_full_heads

printf "%s" "\
basebare

reused-1level2
  reused-1level1
    t/branch1
      branch1

reused-multi
  reused-2level1
    t/branch1
      branch1
    t/branch2
      branch2
  t/branch3
    branch3
  reused-2level2
    reused-1level1
      t/branch1^
    reused-2level1^

root

rootdeps

rootmsg
" >pristine_rdeps_once_heads || die failed to make pristine_rdeps_once_heads

printf "%s" "\
reused-multi
  reused-2level1
    t/branch1
      branch1
    t/branch2
      branch2
  t/branch3
    branch3
  reused-2level2
    reused-1level1
      t/branch1
        branch1
    reused-2level1
      t/branch1
        branch1
      t/branch2
        branch2
" >pristine_rdeps_full_multi || die failed to make pristine_rdeps_full_multi

printf "%s" "\
reused-multi
  reused-2level1
    t/branch1
      branch1
    t/branch2
      branch2
  t/branch3
    branch3
  reused-2level2
    reused-1level1
      t/branch1^
    reused-2level1^
" >pristine_rdeps_once_multi || die failed to make pristine_rdeps_once_multi

printf "%s" "\
reused-2level2
  reused-1level1
    t/branch1
      branch1
  reused-2level1
    t/branch1
      branch1
    t/branch2
      branch2
" >pristine_rdeps_full_2level2 || die failed to make pristine_rdeps_full_2level2

printf "%s" "\
reused-2level2
  reused-1level1
    t/branch1
      branch1
  reused-2level1
    t/branch1^
    t/branch2
      branch2
" >pristine_rdeps_once_2level2 || die failed to make pristine_rdeps_once_2level2

test_expect_success 'list' '
	cd copy && reset_repo &&
	tg summary --list > actual.raw &&
	squish < actual.raw > actual &&
	test_diff ../pristine_list actual
'

test_expect_success 'list verbose' '
	cd copy && reset_repo &&
	tg summary --verbose --list > actual.raw &&
	squish < actual.raw > actual &&
	test_diff ../pristine_list_verbose actual
'

test_expect_success 'list verbose verbose' '
	cd copy && reset_repo &&
	tg summary --verbose --verbose --list > actual.raw &&
	squish < actual.raw > actual &&
	test_diff ../pristine_list_verbose2 actual
'

test_expect_success 'deps' '
	cd copy && reset_repo &&
	tg summary --deps > actual &&
	test_diff ../pristine_deps actual
'

test_expect_success 'deps only all' '
	cd copy && reset_repo &&
	tg summary --deps-only --all > actual &&
	test_diff ../pristine_deps_only_all actual
'

test_expect_success 'sort' '
	cd copy && reset_repo &&
	# the problem with tsort is that it is only guaranteed to produce "a"
	# topological sort.  If there is more than one possible correct answer
	# which one it produces is left unspecified (i.e. up to the
	# implementation).  So we sort the output.  Ugh.
	sort < ../pristine_sort > expected &&
	tg summary --sort > actual.raw &&
	sort < actual.raw > actual &&
	test_diff expected actual &&
	# but then we also generate a "--sort" output for reused-1level2 which
	# we do NOT sort because it has only one valid topological ordering
	# which should therefore provide the best of both worlds.
	printf "%s" "\
reused-1level2
reused-1level1
t/branch1
branch1
" > expected &&
	tg summary --sort reused-1level2 > actual &&
	test_diff expected actual
'

test_expect_success 'graphviz' '
	cd copy && reset_repo &&
	tg summary --graphviz > actual &&
	test_diff ../pristine_graphviz actual
'

test_expect_success 'heads' '
	cd copy && reset_repo &&
	tg summary --heads > actual &&
	test_diff ../pristine_heads actual
'

test_expect_success 'summary heads only' '
	cd copy && reset_repo &&
	tg summary --heads-only > actual.raw &&
	squish < actual.raw > actual &&
	test_diff ../pristine_heads_only actual
'

test_expect_success 'summary with orphan HEAD' '
	cd copy && reset_repo &&
	tg summary > actual.raw &&
	squish < actual.raw > actual &&
	test_diff ../pristine_full_summary actual
'

test_expect_success 'summary with detached HEAD' '
	cd copy && reset_repo &&
	git update-ref --no-deref HEAD t/branch1 &&
	tg summary > actual.raw &&
	squish < actual.raw > actual &&
	test_diff ../pristine_full_summary actual
'

test_expect_success 'summary with non-TopGit HEAD' '
	cd copy && reset_repo &&
	git symbolic-ref HEAD refs/heads/branch2 &&
	tg summary > actual.raw &&
	squish < actual.raw > actual &&
	test_diff ../pristine_full_summary actual
'

test_expect_success 'summary with TopGit HEAD' '
	cd copy && reset_repo &&
	< ../pristine_full_summary sed "/reused-2level1/s/^ />/" > expected &&
	git symbolic-ref HEAD refs/heads/reused-2level1 &&
	tg summary > actual.raw &&
	squish < actual.raw > actual &&
	test_diff expected actual
'

test_expect_success 'summary with TopGit base HEAD' '
	cd copy && reset_repo &&
	< ../pristine_full_summary sed "/reused-2level1/s/^ />/" > expected &&
	git symbolic-ref HEAD "$(tg --top-bases)/reused-2level1" &&
	tg summary > actual.raw &&
	squish < actual.raw > actual &&
	test_diff expected actual
'

test_expect_success 'rdeps heads' '
	cd copy && reset_repo &&
	tg summary --rdeps --heads > actual &&
	test_diff ../pristine_rdeps_once_heads actual
'

test_expect_success 'rdeps-once heads' '
	cd copy && reset_repo &&
	tg summary --rdeps-once --heads > actual &&
	test_diff ../pristine_rdeps_once_heads actual
'

test_expect_success 'rdeps-full heads' '
	cd copy && reset_repo &&
	tg summary --rdeps-full --heads > actual &&
	test_diff ../pristine_rdeps_full_heads actual
'

test_expect_success 'rdeps-once reused-multi' '
	cd copy && reset_repo &&
	tg summary --rdeps-once reused-multi > actual &&
	test_diff ../pristine_rdeps_once_multi actual
'

test_expect_success 'rdeps-full reused-multi' '
	cd copy && reset_repo &&
	tg summary --rdeps-full reused-multi > actual &&
	test_diff ../pristine_rdeps_full_multi actual
'

test_expect_success 'rdeps-once reused-2level2' '
	cd copy && reset_repo &&
	tg summary --rdeps-once reused-2level2 > actual &&
	test_diff ../pristine_rdeps_once_2level2 actual
'

test_expect_success 'rdeps-full reused-2level2' '
	cd copy && reset_repo &&
	tg summary --rdeps-full reused-2level2 > actual &&
	test_diff ../pristine_rdeps_full_2level2 actual
'

test_expect_success 'summary with-deps multi' '
	cd copy && reset_repo &&
	tg summary --with-deps reused-multi > actual.raw &&
	squish < actual.raw > actual &&
	test_diff ../pristine_multi_summary actual
'

test_expect_success 'summary with-related multi' '
	cd copy && reset_repo &&
	tg summary --with-related reused-multi > actual.raw &&
	squish < actual.raw > actual &&
	test_diff ../pristine_multi_summary actual
'

test_expect_success 'summary with-deps 2level1' '
	cd copy && reset_repo &&
	tg summary --with-deps reused-2level1 > actual.raw &&
	squish < actual.raw > actual &&
	test_diff ../pristine_2level1_summary actual
'

test_expect_success 'summary with-related 2level1' '
	cd copy && reset_repo &&
	tg summary --with-related reused-2level1 > actual.raw &&
	squish < actual.raw > actual &&
	test_diff ../pristine_multi_summary actual
'

test_expect_success 'summary @ with 2level1 HEAD' '
	cd copy && reset_repo &&
	< ../pristine_multi_summary sed "/reused-2level1/s/^ />/" > expected &&
	git symbolic-ref HEAD "refs/heads/reused-2level1" &&
	tg summary @ > actual.raw &&
	squish < actual.raw > actual &&
	test_diff expected actual
'

test_expect_success 'summary @ @ with 2level1 HEAD' '
	cd copy && reset_repo &&
	< ../pristine_2level1_summary sed "/reused-2level1/s/^ />/" > expected &&
	git symbolic-ref HEAD "refs/heads/reused-2level1" &&
	tg summary @ @ > actual.raw &&
	squish < actual.raw > actual &&
	test_diff expected actual
'

test_done
