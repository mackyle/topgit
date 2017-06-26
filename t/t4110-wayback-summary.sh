#!/bin/sh

test_description='summary wayback in time'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 7

sqt="$(test_get_temp squish)" || die not squishy

reset_repo() {
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/orphan
}

squish() {
	tab="	" # single tab in there
	"$@" >"$sqt" || return
	<"$sqt" tr -s "$tab" " "
}

topbases="$(tg --top-bases)" && test -n "$topbases" || die 'no top-bases!'

test_expect_success 'setup' '
	test_create_repo pristine && cd pristine &&
	git checkout --orphan rootcommit &&
	git read-tree --empty &&
	test_tick &&
	git commit --allow-empty -m "empty root commit" &&
	git tag rootcommit &&
	tg_test_create_tag t/root &&
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
	tg_test_create_tag t/branches &&
	tg_test_create_tag t/branches-only "refs/heads/branch*" &&
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
	EOT
	tg_test_create_tag t/midway &&
	tg_test_create_branches <<-EOT &&
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
	tg_test_create_tag t/reused &&
	tg_test_create_branches <<-EOT &&
		boring just a boring commit here move along
		:::

		t/subjmiss
		boring

		t/subjmt
		boring
	EOT
	tg_test_create_tag t/boring1 refs/heads/boring "refs/heads/t/subj*" "$topbases/t/subj*" &&
	tg_test_create_tag t/all1 &&
	git checkout -f annihilated &&
	test_tick &&
	git commit --allow-empty -m "annihilated not empty" &&
	git checkout -f t/branch2 &&
	<.topmsg grep -v -i subject >.topmsg2 &&
	mv -f .topmsg2 .topmsg &&
	printf "%s\n" "subject:[PATCH] branch2" "	topgit" >> .topmsg &&
	git add .topmsg &&
	test_tick &&
	git commit -m ".topmsg: no space after subject colon" &&
	git checkout -f t/subjmiss &&
	<.topmsg grep -v -i subject >.topmsg2 &&
	mv -f .topmsg2 .topmsg &&
	git add .topmsg &&
	test_tick &&
	git commit -m ".topmsg: whoops, no subject: here" &&
	git checkout -f t/subjmt &&
	<.topmsg grep -v -i subject >.topmsg2 &&
	mv -f .topmsg2 .topmsg &&
	printf "%s\n" "subJECT:  	" >> .topmsg &&
	git add .topmsg &&
	test_tick &&
	git commit -m ".topmsg: subject of emptyness" &&
	tg_test_create_tag t/boring2 refs/heads/boring "refs/heads/t/subj*" "$topbases/t/subj*" &&
	tg_test_create_tag t/all2 &&
	reset_repo &&
	git clean -x -d -f &&
	cd .. &&
	cp -pR pristine copy
'

printf "%s" "\
refs/heads/annihilated
refs/heads/basebare
refs/heads/boring
refs/heads/branch1
refs/heads/branch2
refs/heads/branch3
refs/heads/reused-1level1
refs/heads/reused-1level2
refs/heads/reused-2level1
refs/heads/reused-2level2
refs/heads/reused-multi
refs/heads/root
refs/heads/rootbare
refs/heads/rootcommit
refs/heads/rootdeps
refs/heads/rootmsg
refs/heads/t/branch1
refs/heads/t/branch2
refs/heads/t/branch3
refs/heads/t/subjmiss
refs/heads/t/subjmt
" > all_refsh || die failed to make all_refsh

printf "%s" "\
$topbases/annihilated
$topbases/basebare
$topbases/reused-1level1
$topbases/reused-1level2
$topbases/reused-2level1
$topbases/reused-2level2
$topbases/reused-multi
$topbases/root
$topbases/rootbare
$topbases/rootdeps
$topbases/rootmsg
$topbases/t/branch1
$topbases/t/branch2
$topbases/t/branch3
$topbases/t/subjmiss
$topbases/t/subjmt
" > all_refsb || die failed to make all_refsb

printf "%s" "\
refs/tags/branch1-start
refs/tags/branch2-start
refs/tags/branch3-start
refs/tags/rootcommit
refs/tags/t/all1
refs/tags/t/all2
refs/tags/t/boring1
refs/tags/t/boring2
refs/tags/t/branches
refs/tags/t/branches-only
refs/tags/t/midway
refs/tags/t/reused
refs/tags/t/root
" > all_refst || die failed to make all_refst

if test "$topbases" = "refs/top-bases"; then
	cat all_refsh all_refst all_refsb > all_refs
else
	cat all_refsh all_refsb all_refst > all_refs
fi || die failed to make all_refs

printf "%s" "\
refs/heads/annihilated
refs/heads/basebare
refs/heads/boring
refs/heads/branch1
refs/heads/branch2
refs/heads/branch3
refs/heads/reused-1level1
refs/heads/reused-1level2
refs/heads/reused-2level1
refs/heads/reused-2level2
refs/heads/reused-multi
refs/heads/root
refs/heads/rootbare
refs/heads/rootcommit
refs/heads/rootdeps
refs/heads/rootmsg
refs/heads/t/branch1
refs/heads/t/branch2
refs/heads/t/branch3
refs/heads/t/subjmiss
refs/heads/t/subjmt
$topbases/annihilated
$topbases/basebare
$topbases/reused-1level1
$topbases/reused-1level2
$topbases/reused-2level1
$topbases/reused-2level2
$topbases/reused-multi
$topbases/root
$topbases/rootbare
$topbases/rootdeps
$topbases/rootmsg
$topbases/t/branch1
$topbases/t/branch2
$topbases/t/branch3
$topbases/t/subjmiss
$topbases/t/subjmt
" > all_tg_refs || die failed to make all_tg_refs

printf "%s" "\
refs/heads/annihilated
refs/heads/basebare
refs/heads/branch1
refs/heads/branch2
refs/heads/branch3
refs/heads/root
refs/heads/rootbare
refs/heads/rootcommit
refs/heads/rootdeps
refs/heads/rootmsg
refs/heads/t/branch1
refs/heads/t/branch2
refs/heads/t/branch3
$topbases/annihilated
$topbases/basebare
$topbases/root
$topbases/rootbare
$topbases/rootdeps
$topbases/rootmsg
$topbases/t/branch1
$topbases/t/branch2
$topbases/t/branch3
" > midway_refs || die failed to make midway_refs

printf "%s" "\
refs/heads/annihilated
refs/heads/basebare
refs/heads/branch1
refs/heads/branch2
refs/heads/branch3
refs/heads/reused-1level1
refs/heads/reused-1level2
refs/heads/reused-2level1
refs/heads/reused-2level2
refs/heads/reused-multi
refs/heads/root
refs/heads/rootbare
refs/heads/rootcommit
refs/heads/rootdeps
refs/heads/rootmsg
refs/heads/t/branch1
refs/heads/t/branch2
refs/heads/t/branch3
$topbases/annihilated
$topbases/basebare
$topbases/reused-1level1
$topbases/reused-1level2
$topbases/reused-2level1
$topbases/reused-2level2
$topbases/reused-multi
$topbases/root
$topbases/rootbare
$topbases/rootdeps
$topbases/rootmsg
$topbases/t/branch1
$topbases/t/branch2
$topbases/t/branch3
" > reused_refs || die failed to make reused_refs

printf "%s" "\
refs/heads/boring
refs/heads/t/subjmiss
refs/heads/t/subjmt
$topbases/t/subjmiss
$topbases/t/subjmt
" > boring_refs || die failed to make boring_refs

squish printf "%s" "\
annihilated                            	branch annihilated (annihilated)
basebare                               	branch basebare (bare branch)
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
t/subjmiss                             	branch t/subjmiss (missing \"Subject:\" in .topmsg)
t/subjmt                               	branch t/subjmt (empty \"Subject:\" in .topmsg)
" > pristine_full_list || die failed to make pristine_full_list

squish printf "%s" "\
annihilated                            	branch annihilated (annihilated)
basebare                               	branch basebare (bare branch)
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
t/subjmiss                             	[PATCH] branch t/subjmiss
t/subjmt                               	[PATCH] branch t/subjmt
" > pristine_boring_list || die failed to make pristine_boring_list

squish printf "%s" "\
annihilated                            	branch annihilated (no commits)
basebare                               	branch basebare (bare branch)
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
t/subjmiss                             	branch t/subjmiss (missing \"Subject:\" in .topmsg)
t/subjmt                               	branch t/subjmt (empty \"Subject:\" in .topmsg)
" > pristine_fullb4_list || die failed to make pristine_fullb4_list

squish printf "%s" "\
annihilated                            	branch annihilated (no commits)
basebare                               	branch basebare (bare branch)
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
t/subjmiss                             	[PATCH] branch t/subjmiss
t/subjmt                               	[PATCH] branch t/subjmt
" > pristine_boringb4_list || die failed to make pristine_boring_list

squish printf "%s" "\
annihilated                            	branch annihilated (no commits)
basebare                               	branch basebare (bare branch)
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
t/subjmiss                             	branch t/subjmiss (missing \"Subject:\" in .topmsg)
t/subjmt                               	branch t/subjmt (empty \"Subject:\" in .topmsg)
" > pristine_fullb4b1_list || die failed to make pristine_fullb4b1_list

squish printf "%s" "\
annihilated                            	branch annihilated (no commits)
basebare                               	branch basebare (bare branch)
root                                   	[PATCH] standard root branch
rootbare                               	branch rootbare (no commits)
rootdeps                               	branch rootdeps (missing .topmsg)
rootmsg                                	[PATCH] topmsg root
t/branch1                              	[PATCH] branch1 topgit
t/branch2                              	[PATCH] branch2 topgit
t/branch3                              	[PATCH] branch3 topgit
" > pristine_midway_list || die failed to make pristine_midway_list

squish printf "%s" "\
annihilated                            	branch annihilated (no commits)
basebare                               	branch basebare (bare branch)
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
" > pristine_reused_list || die failed to make pristine_reused_list

squish printf "%s" "\
t/subjmiss                             	[PATCH] branch t/subjmiss
t/subjmt                               	[PATCH] branch t/subjmt
" > pristine_boring1_list || die failed to make pristine_boring1_list

squish printf "%s" "\
t/subjmiss                             	branch t/subjmiss (missing \"Subject:\" in .topmsg)
t/subjmt                               	branch t/subjmt (empty \"Subject:\" in .topmsg)
" > pristine_boring2_list || die failed to make pristine_boring2_list

squish printf "%s" "\
         basebare                      	branch basebare (bare branch)
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
 0       t/subjmiss                    	branch t/subjmiss (missing \"Subject:\" in .topmsg)
 0       t/subjmt                      	branch t/subjmt (empty \"Subject:\" in .topmsg)
" > pristine_full_summary || die failed to make pristine_full_summary

squish printf "%s" "\
         basebare                      	branch basebare (bare branch)
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
 0       t/subjmiss                    	[PATCH] branch t/subjmiss
 0       t/subjmt                      	[PATCH] branch t/subjmt
" > pristine_boring_summary || die failed to make pristine_boring_summary

squish printf "%s" "\
         basebare                      	branch basebare (bare branch)
 0       root                          	[PATCH] standard root branch
 0       rootdeps                      	branch rootdeps (missing .topmsg)
 0       rootmsg                       	[PATCH] topmsg root
 0       t/branch1                     	[PATCH] branch1 topgit
 0       t/branch2                     	[PATCH] branch2 topgit
 0       t/branch3                     	[PATCH] branch3 topgit
" > pristine_midway_summary || die failed to make pristine_midway_summary

squish printf "%s" "\
         basebare                      	branch basebare (bare branch)
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
" > pristine_reused_summary || die failed to make pristine_reused_summary

squish printf "%s" "\
 0       t/subjmiss                    	[PATCH] branch t/subjmiss
 0       t/subjmt                      	[PATCH] branch t/subjmt
" > pristine_boring1_summary || die failed to make pristine_boring1_summary

squish printf "%s" "\
 0       t/subjmiss                    	branch t/subjmiss (missing \"Subject:\" in .topmsg)
 0       t/subjmt                      	branch t/subjmt (empty \"Subject:\" in .topmsg)
" > pristine_boring2_summary || die failed to make pristine_boring2_summary

test_expect_success 'verify list' '
	squish tg -C copy summary -vvl >actual &&
	test_diff pristine_full_list actual &&
	squish tg -C copy -w : summary -vvl > actual &&
	test_diff pristine_full_list actual &&
	squish tg -C copy -w : summary -vvl > actual &&
	test_diff pristine_full_list actual &&
	squish tg -C copy -w : shell tg summary -vvl > actual &&
	test_diff pristine_full_list actual &&
	squish tg -C copy -w t/all2 summary -vvl > actual &&
	test_diff pristine_full_list actual &&
	squish tg -C copy -w t/all2 shell tg summary -vvl> actual &&
	test_diff pristine_full_list actual
'

test_expect_success 'verify summary' '
	squish tg -C copy summary >actual &&
	test_diff pristine_full_summary actual &&
	squish tg -C copy -w : summary > actual &&
	test_diff pristine_full_summary actual &&
	squish tg -C copy -w : summary > actual &&
	test_diff pristine_full_summary actual &&
	squish tg -C copy -w : shell tg summary > actual &&
	test_diff pristine_full_summary actual &&
	squish tg -C copy -w t/all2 summary > actual &&
	test_diff pristine_full_summary actual &&
	squish tg -C copy -w t/all2 shell tg summary > actual &&
	test_diff pristine_full_summary actual
'

test_expect_success 'wayback list' '
	>expected &&
	for wtag in t/root t/branches t/branches-only; do
		squish tg -C copy -w "$wtag" summary -vvl >actual &&
		test_diff pristine_full_list actual &&
		tg -C copy -w ":$wtag" summary -vvl >actual &&
		test_diff expected actual
	done &&
	squish tg -C copy -w t/midway summary -vvl >actual &&
	test_diff pristine_fullb4_list actual &&
	squish tg -C copy -w :t/midway summary -vvl >actual &&
	test_diff pristine_midway_list actual &&
	squish tg -C copy -w t/reused summary -vvl >actual &&
	test_diff pristine_fullb4_list actual &&
	squish tg -C copy -w :t/reused summary -vvl >actual &&
	test_diff pristine_reused_list actual &&
	squish tg -C copy -w t/boring1 summary -vvl >actual &&
	test_diff pristine_boring_list actual &&
	squish tg -C copy -w :t/boring1 summary -vvl >actual &&
	test_diff pristine_boring1_list actual &&
	squish tg -C copy -w t/all1 summary -vvl >actual &&
	test_diff pristine_boringb4_list actual &&
	squish tg -C copy -w :t/all1 summary -vvl >actual &&
	test_diff pristine_boringb4_list actual &&
	squish tg -C copy -w t/boring2 summary -vvl >actual &&
	test_diff pristine_full_list actual &&
	squish tg -C copy -w :t/boring2 summary -vvl >actual &&
	test_diff pristine_boring2_list actual
'

test_expect_success 'wayback summary' '
	>expected &&
	for wtag in t/root t/branches t/branches-only; do
		squish tg -C copy -w "$wtag" summary >actual &&
		test_diff pristine_full_summary actual &&
		tg -C copy -w ":$wtag" summary >actual &&
		test_diff expected actual
	done &&
	squish tg -C copy -w t/midway summary >actual &&
	test_diff pristine_full_summary actual &&
	squish tg -C copy -w :t/midway summary >actual &&
	test_diff pristine_midway_summary actual &&
	squish tg -C copy -w t/reused summary >actual &&
	test_diff pristine_full_summary actual &&
	squish tg -C copy -w :t/reused summary >actual &&
	test_diff pristine_reused_summary actual &&
	squish tg -C copy -w t/boring1 summary >actual &&
	test_diff pristine_boring_summary actual &&
	squish tg -C copy -w :t/boring1 summary >actual &&
	test_diff pristine_boring1_summary actual &&
	squish tg -C copy -w t/all1 summary >actual &&
	test_diff pristine_boring_summary actual &&
	squish tg -C copy -w :t/all1 summary >actual &&
	test_diff pristine_boring_summary actual &&
	squish tg -C copy -w t/boring2 summary >actual &&
	test_diff pristine_full_summary actual &&
	squish tg -C copy -w :t/boring2 summary >actual &&
	test_diff pristine_boring2_summary actual
'

test_expect_success 'wayback refs' '
	printf "%s\n" "refs/heads/rootcommit" >expected &&
	tg -C copy -w t/root shell git for-each-ref --format="%\\(refname\\)" > actual &&
	test_diff all_refs actual &&
	tg -C copy -w :t/root shell git for-each-ref --format="%\\(refname\\)" > actual &&
	test_diff expected actual &&
	printf "%s\n" "refs/heads/branch1" "refs/heads/branch2" "refs/heads/branch3" \
		"refs/heads/rootcommit" >expected &&
	tg -C copy -w t/branches shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff all_refs actual &&
	tg -C copy -w :t/branches shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff expected actual &&
	printf "%s\n" "refs/heads/branch1" "refs/heads/branch2" "refs/heads/branch3" >expected &&
	tg -C copy -w t/branches-only shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff all_refs actual &&
	tg -C copy -w :t/branches-only shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff expected actual &&
	tg -C copy -w t/midway shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff all_refs actual &&
	tg -C copy -w :t/midway shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff midway_refs actual &&
	tg -C copy -w t/reused shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff all_refs actual &&
	tg -C copy -w :t/reused shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff reused_refs actual &&
	tg -C copy -w t/all1 shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff all_refs actual &&
	tg -C copy -w :t/all1 shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff all_tg_refs actual &&
	tg -C copy -w t/boring1 shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff all_refs actual &&
	tg -C copy -w :t/boring1 shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff boring_refs actual &&
	tg -C copy -w t/all2 shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff all_refs actual &&
	tg -C copy -w :t/all2 shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff all_tg_refs actual &&
	tg -C copy -w t/boring2 shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff all_refs actual &&
	tg -C copy -w :t/boring2 shell -q git for-each-ref --format="%(refname)" > actual &&
	test_diff boring_refs actual
'

test_expect_success 'wayback directory refs' '
	tg -C copy -w :t/midway shell --directory "$PWD/newdir" : &&
	git -C newdir for-each-ref --format="%(refname)" > actual &&
	test_diff midway_refs actual
'

test_done
