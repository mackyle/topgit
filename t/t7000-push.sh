#!/bin/sh

test_description='check tg push'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

# We are not testing `git push` here, we are testing
# that `tg push` delivers the correct arguments to `git push`

mkdir gitshim || die
write_script gitshim/git <<\EOT || die
if [ "$1" = "push" ]; then
	shift
	printf '%s\n' "$@"
	exit 0
fi
exec "$GIT_PATH" "$@"
EOT
GIT_SHIM_DIR="$PWD/gitshim"
tgshim() {
	GIT_PATH="$GIT_PATH" PATH="$GIT_SHIM_DIR:$PATH" tg "$@"
}

topbases="$(tg --top-bases)" && topbases="${topbases#refs/}" && [ -n "$topbases" ] || die

test_plan 24

test_expect_success 'setup' '
	test_create_repo empty &&
	test_create_repo detached &&
	test_create_repo nontg &&
	test_create_repo combined &&
	mkdir testshim &&
	cd testshim &&
	cat <<-EOT >expected &&
		--dry-run
		--force
		some-remote
		some-ref
	EOT
	tgshim -c topgit.alias.git=!git git push --dry-run --force some-remote some-ref >actual &&
	test_cmp actual expected &&
	git version --build-options >expected &&
	tgshim -c topgit.alias.git=!git git version --build-options >actual &&
	test_cmp actual expected &&
	cd ../detached &&
	test_commit detached &&
	git update-ref --no-deref HEAD HEAD HEAD &&
	git update-ref -d refs/heads/master &&
	cd ../nontg &&
	test_commit one &&
	test_commit two &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/other &&
	test_commit o1 &&
	test_commit o2 &&
	cd ../combined &&
	tg_test_create_branch remote1::t/branch1 : &&
	git checkout -f t/branch1 &&
	test_commit tgb1a &&
	test_commit tgb1b &&
	tg_test_create_branch t/branch2 : &&
	git checkout -f t/branch2 &&
	test_commit tgb2a &&
	test_commit tgb2b &&
	git update-ref refs/remotes/remote2/t/branch2 HEAD "" &&
	git update-ref refs/remotes/remote2/${topbases#heads/}/t/branch2 "$(tg base t/branch2)" "" &&
	git checkout -f refs/remotes/remote2/t/branch2 &&
	git symbolic-ref HEAD refs/remotes/remote2/t/branch2 &&
	test_commit aheadb2 &&
	tg_test_create_branch t/branch3 : &&
	git checkout -f t/branch3 &&
	test_commit tgb3a &&
	test_commit tgb3b &&
	git update-ref refs/remotes/remote3/t/branch3 HEAD "" &&
	git update-ref refs/remotes/remote3/${topbases#heads/}/t/branch3 "$(tg base t/branch3)" "" &&
	git checkout -f "refs/remotes/remote3/${topbases#heads/}/t/branch3" &&
	git symbolic-ref HEAD "refs/remotes/remote3/${topbases#heads/}/t/branch3" &&
	test_commit aheadb3 &&
	tg_test_create_branch remote4:t/dep : &&
	tg_test_create_branch remote4:t/branch4 :refs/remotes/remote4/t/dep t/dep &&
	git checkout -f refs/remotes/remote4/t/dep &&
	git symbolic-ref HEAD refs/remotes/remote4/t/dep &&
	test_commit adep &&
	tg_test_create_branch t/branch4 :refs/remotes/remote4/t/dep &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/t/mt &&
	test_commit mt &&
	git update-ref --no-deref HEAD HEAD HEAD &&
	git update-ref "refs/$topbases/t/mt" HEAD "" &&
	git update-ref "refs/$topbases/t/mtann" HEAD "" &&
	test_commit notmt &&
	anc="$(git commit-tree -m makeann -p HEAD t/mt^{tree})" && test -n "$anc" &&
	git update-ref refs/heads/t/mtann "$anc" "" &&
	git read-tree --empty &&
	git symbolic-ref HEAD "refs/$topbases/t/fullann" &&
	test_commit fullann &&
	echo "t/holdboth" >.topdeps &&
	git add .topdeps &&
	test_tick &&
	git commit -m "topdeps in base" &&
	git update-ref refs/heads/t/fullann HEAD "" &&
	git symbolic-ref HEAD "refs/heads/t/fullann" &&
	test_commit fullcommit &&
	anc="$(git commit-tree -m makefullann -p HEAD "refs/$topbases/t/fullann^{tree}")" && test -n "$anc" &&
	git update-ref HEAD "$anc" HEAD &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/master2 &&
	test_commit m1 &&
	test_commit m2 &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/other2 &&
	test_commit o1 &&
	test_commit o2 &&
	git read-tree --empty &&
	git symbolic-ref HEAD "refs/$topbases/t/orphanbase" &&
	test_commit tgorphanbase &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/tgbranch1 &&
	test_commit tgbefore1 &&
	tg_test_create_branch t/both1 tgbranch1 &&
	git checkout -f t/both1 &&
	test_commit both1 &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/tgbranch2 &&
	test_commit tgbefore2 &&
	tg_test_create_branch t/both2 tgbranch2 &&
	git checkout -f t/both2 &&
	test_commit both2 &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/master3 &&
	test_commit first &&
	tg_test_create_branch t/branch master3 &&
	test_commit second &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/base1 &&
	test_commit base1 &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/base2 &&
	test_commit base2 &&
	tg_test_create_branch t/abranch1 base1 &&
	git checkout -f t/abranch1 &&
	test_commit abranch1 &&
	anc="$(git commit-tree -m "annihilate" -p HEAD "$(git rev-parse --verify "refs/$topbases/t/abranch1^{tree}" --)")" &&
	test -n "$anc" &&
	git update-ref -m "annihilate branch" HEAD "$anc" HEAD &&
	tg_test_create_branch t/hold1 t/abranch1 &&
	tg_test_create_branch t/abranch2 base2 &&
	git checkout -f t/abranch2 &&
	test_commit abranch2 &&
	tg_test_create_branch t/hold2 t/abranch2 &&
	tg_test_create_branch t/holdboth t/branch t/abranch1 t/abranch2 &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'empty fails' '
	cd empty &&
	test_must_fail tg push -r . &&
	test_must_fail tg push -r . --all
'

test_expect_success SETUP 'detached fails' '
	cd detached &&
	test_must_fail tg push -r . &&
	test_must_fail tg push -r . --all
'

test_expect_success SETUP 'branch plus --all fails' '
	cd nontg &&
	test_must_fail tg push -r . -a HEAD &&
	test_must_fail tg push -r . --all HEAD &&
	test_must_fail tg push -r . HEAD --all &&
	test_must_fail tg push -r . @ -a &&
	test_must_fail tg push -r . other -a &&
	test_must_fail tg push -r . -a master
'

test_expect_success SETUP 'nontg okay' '
	cd nontg &&
	test_must_fail tg push -r . --all &&
	cat <<-EOT >expected &&
		origin
		refs/heads/other
	EOT
	tgshim push -r origin >actual &&
	test_cmp actual expected &&
	tgshim push -r origin HEAD >actual &&
	test_cmp actual expected &&
	tgshim push -r origin @ >actual &&
	test_cmp actual expected &&
	tgshim push -r origin other >actual &&
	test_cmp actual expected &&
	tgshim push -r origin @ HEAD other >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		origin
		refs/heads/master
	EOT
	tgshim push -r origin master >actual &&
	test_cmp actual expected &&
	tgshim push -r origin master master >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		origin
		refs/heads/master
		refs/heads/other
	EOT
	tgshim push -r origin master other >actual &&
	test_cmp actual expected &&
	tgshim push -r origin master HEAD >actual &&
	test_cmp actual expected &&
	tgshim push -r origin master @ >actual &&
	test_cmp actual expected &&
	tgshim push -r origin other master >actual &&
	test_cmp actual expected &&
	tgshim push -r origin HEAD master >actual &&
	test_cmp actual expected &&
	tgshim push -r origin @ master >actual &&
	test_cmp actual expected &&
	tgshim push -r origin other master HEAD >actual &&
	test_cmp actual expected &&
	tgshim push -r origin master other master HEAD >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'nontg --tgish-only fails' '
	cd nontg &&
	test_must_fail tg push -r . --tgish-only &&
	test_must_fail tg push -r . --tgish-only HEAD &&
	test_must_fail tg push -r . --tgish-only @ &&
	test_must_fail tg push -r . --tgish-only master &&
	test_must_fail tg push -r . --tgish-only other &&
	test_must_fail tg push -r . --tgish-only --all
'

test_expect_success SETUP 'correct remote' '
	cd nontg &&
	test_must_fail tg push &&
	test_must_fail tg -c topgit.remote=remote1 -u push &&
	test_must_fail tg -c topgit.remote=remote1 -r remote1 -u push &&
	test_must_fail tg -r remote1 -u push &&
	printf "%s\n" remote1 refs/heads/other >expected &&
	tgshim -c topgit.remote=remote1 push >actual &&
	test_cmp actual expected &&
	tgshim -r remote1 push >actual &&
	test_cmp actual expected &&
	tgshim -r remote1 -c topgit.remote=remote2 push >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.remote=remote2 -r remote1 push >actual &&
	test_cmp actual expected &&
	printf "%s\n" remote2 refs/heads/other >expected &&
	tgshim -c topgit.pushremote=remote2 push >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.pushremote=remote2 -c topgit.remote=remote1 push >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.pushremote=remote2 -c topgit.remote=remote1 -u push >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.pushremote=remote2 -r remote1 push >actual &&
	test_cmp actual expected &&
	printf "%s\n" remote3 refs/heads/other >expected &&
	tgshim -c topgit.pushremote=remote2 -c topgit.remote=remote1 push -r remote3 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.pushremote=remote2 -c topgit.remote=remote1 -u push -r remote3 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.remote=remote1 push -r remote3 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.remote=remote1 -u push -r remote3 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.pushremote=remote2 push -r remote3 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.pushremote=remote2 -u push -r remote3 >actual &&
	test_cmp actual expected &&
	tgshim push -r remote3 >actual &&
	test_cmp actual expected &&
	tgshim -r remote1 push -r remote3 >actual &&
	test_cmp actual expected &&
	tgshim -r remote1 -c topgit.remote=remote2 push -r remote3 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'pass options' '
	cd nontg &&
	for opt in "-4" "--ipv4" "--ipv6" "-6" "--dry-run" "--force" "--atomic" "--signed" "--signed=" "--signed=..."; do
		printf "%s\n" "$opt" origin refs/heads/other >expected &&
		tgshim push -r origin $opt >actual &&
		test_cmp actual expected || return
	done &&
	printf "%s\n" "-4" "-6" "--dry-run" "--force" "--atomic" "--signed=yes" origin refs/heads/other >expected &&
	tgshim push --force -r origin --ipv6 --atomic --signed -4 -6 --force --dry-run --signed=yes >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'nontg push' '
	cd combined &&
	for b in base1 base2 master2 master3 other2 tgbranch1 tgbranch2; do
		printf "%s\n" origin "refs/heads/$b" >expected &&
		tgshim push -r origin $b >actual &&
		test_cmp actual expected || return
	done
'

test_expect_success SETUP 'tg base up-to-date push' '
	cd combined &&
	for b in t/abranch1 t/branch1 t/branch2 t/branch3 t/branch4 t/fullann t/mt t/mtann; do
		printf "%s\n" origin "refs/heads/$b" "refs/$topbases/$b" >expected &&
		tgshim push -r origin $b >actual &&
		test_cmp actual expected || return
	done
'

test_expect_success SETUP 'tg --no-deps up-to-date push' '
	cd combined &&
	for b in \
		t/abranch1 t/abranch2 t/both1 t/both2 t/branch1 t/branch2 t/branch3 t/branch4 \
		t/fullann t/hold1 t/hold2 t/mt t/mtann
	do
		printf "%s\n" origin "refs/heads/$b" "refs/$topbases/$b" >expected &&
		tgshim push -r origin --no-deps $b >actual &&
		test_cmp actual expected || return
	done
'

test_expect_success SETUP 'tg t/branch needs --allow-outdated' '
	cd combined &&
	test_must_fail tg push -r . t/branch &&
	test_must_fail tg push -r . --tgish-only t/branch &&
	test_must_fail tg push -r . --no-deps t/branch &&
	test_must_fail tg push -r . --no-deps --tgish-only t/branch &&
	cat <<-EOT >expected &&
		origin
		refs/heads/master3
		refs/heads/t/branch
		refs/$topbases/t/branch
	EOT
	tgshim push -r origin --allow-outdated t/branch >actual &&
	test_cmp actual expected &&
	printf "%s\n" origin "refs/heads/t/branch" "refs/$topbases/t/branch" >expected &&
	tgshim push -r origin --allow-outdated --tgish-only t/branch >actual &&
	test_cmp actual expected &&
	tgshim push -r origin --allow-outdated --no-deps t/branch >actual &&
	test_cmp actual expected &&
	tgshim push -r origin --allow-outdated --no-deps --tgish-only t/branch >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'tg t/holdboth needs --allow-outdated' '
	cd combined &&
	test_must_fail tg push -r . t/holdboth &&
	test_must_fail tg push -r . --no-deps t/holdboth &&
	test_must_fail tg push -r . --tgish-only t/holdboth &&
	test_must_fail tg push -r . --no-deps --tgish-only t/holdboth &&
	cat <<-EOT >expected &&
		origin
		refs/heads/base2
		refs/heads/master3
		refs/heads/t/abranch1
		refs/heads/t/abranch2
		refs/heads/t/branch
		refs/heads/t/holdboth
		refs/$topbases/t/abranch1
		refs/$topbases/t/abranch2
		refs/$topbases/t/branch
		refs/$topbases/t/holdboth
	EOT
	tgshim push -r origin --allow-outdated t/holdboth >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		origin
		refs/heads/t/abranch1
		refs/heads/t/abranch2
		refs/heads/t/branch
		refs/heads/t/holdboth
		refs/$topbases/t/abranch1
		refs/$topbases/t/abranch2
		refs/$topbases/t/branch
		refs/$topbases/t/holdboth
	EOT
	tgshim push -r origin --allow-outdated --tgish-only t/holdboth >actual &&
	test_cmp actual expected &&
	printf "%s\n" origin "refs/heads/t/holdboth" "refs/$topbases/t/holdboth" >expected &&
	tgshim push -r origin --allow-outdated --no-deps t/holdboth >actual &&
	test_cmp actual expected &&
	tgshim push -r origin --allow-outdated --no-deps --tgish-only t/holdboth >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'tg empty push' '
	cd combined &&
	printf "%s\n" origin "refs/heads/t/mt" "refs/$topbases/t/mt" >expected &&
	tgshim push -r origin t/mt >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'tg annihilated empty push' '
	cd combined &&
	printf "%s\n" origin "refs/heads/t/mtann" "refs/$topbases/t/mtann" >expected &&
	tgshim push -r origin t/mtann >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'tg annihilated full push' '
	cd combined &&
	printf "%s\n" origin "refs/heads/t/fullann" "refs/$topbases/t/fullann" >expected &&
	tgshim push -r origin t/fullann >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'outdated --all push fails' '
	cd combined &&
	test_must_fail tg push -r . --all &&
	test_must_fail tg push -r . --no-deps --all &&
	test_must_fail tg push -r . --tgish-only --all &&
	test_must_fail tg push -r . --no-deps --tgish-only --all
'

test_expect_success SETUP '--allow-outdated --all --no-deps' '
	cd combined &&
	cat <<-EOT >expected &&
		origin
		refs/heads/t/abranch2
		refs/heads/t/both1
		refs/heads/t/both2
		refs/heads/t/branch
		refs/heads/t/branch1
		refs/heads/t/branch2
		refs/heads/t/branch3
		refs/heads/t/branch4
		refs/heads/t/hold1
		refs/heads/t/hold2
		refs/heads/t/holdboth
		refs/$topbases/t/abranch2
		refs/$topbases/t/both1
		refs/$topbases/t/both2
		refs/$topbases/t/branch
		refs/$topbases/t/branch1
		refs/$topbases/t/branch2
		refs/$topbases/t/branch3
		refs/$topbases/t/branch4
		refs/$topbases/t/hold1
		refs/$topbases/t/hold2
		refs/$topbases/t/holdboth
	EOT
	tgshim push -r origin --allow-outdated --all --no-deps >actual &&
	test_cmp actual expected &&
	tgshim push -r origin --tgish-only --allow-outdated --all --no-deps >actual &&
	test_cmp actual expected
'

test_expect_success SETUP '--allow-outdated --all --tgish-only' '
	cd combined &&
	cat <<-EOT >expected &&
		origin
		refs/heads/t/abranch1
		refs/heads/t/abranch2
		refs/heads/t/both1
		refs/heads/t/both2
		refs/heads/t/branch
		refs/heads/t/branch1
		refs/heads/t/branch2
		refs/heads/t/branch3
		refs/heads/t/branch4
		refs/heads/t/hold1
		refs/heads/t/hold2
		refs/heads/t/holdboth
		refs/$topbases/t/abranch1
		refs/$topbases/t/abranch2
		refs/$topbases/t/both1
		refs/$topbases/t/both2
		refs/$topbases/t/branch
		refs/$topbases/t/branch1
		refs/$topbases/t/branch2
		refs/$topbases/t/branch3
		refs/$topbases/t/branch4
		refs/$topbases/t/hold1
		refs/$topbases/t/hold2
		refs/$topbases/t/holdboth
	EOT
	tgshim push -r origin --allow-outdated --all --tgish-only >actual &&
	test_cmp actual expected
'

test_expect_success SETUP '--allow-outdated --all' '
	cd combined &&
	cat <<-EOT >expected &&
		origin
		refs/heads/base2
		refs/heads/master3
		refs/heads/t/abranch1
		refs/heads/t/abranch2
		refs/heads/t/both1
		refs/heads/t/both2
		refs/heads/t/branch
		refs/heads/t/branch1
		refs/heads/t/branch2
		refs/heads/t/branch3
		refs/heads/t/branch4
		refs/heads/t/hold1
		refs/heads/t/hold2
		refs/heads/t/holdboth
		refs/heads/tgbranch1
		refs/heads/tgbranch2
		refs/$topbases/t/abranch1
		refs/$topbases/t/abranch2
		refs/$topbases/t/both1
		refs/$topbases/t/both2
		refs/$topbases/t/branch
		refs/$topbases/t/branch1
		refs/$topbases/t/branch2
		refs/$topbases/t/branch3
		refs/$topbases/t/branch4
		refs/$topbases/t/hold1
		refs/$topbases/t/hold2
		refs/$topbases/t/holdboth
	EOT
	tgshim push -r origin --allow-outdated --all >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 't/branch1 with remote checks' '
	cd combined &&
	cat <<-EOT >expected &&
		origin
		refs/heads/t/branch1
		refs/$topbases/t/branch1
	EOT
	tgshim push -r origin t/branch1 >actual &&
	test_cmp actual expected &&
	tgshim -r remote1 push -r origin t/branch1 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.remote=remote2 push -r origin t/branch1 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.remote=remote3 push -r origin t/branch1 >actual &&
	test_cmp actual expected &&
	tgshim -r remote4 push -r origin t/branch1 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 't/branch2 with remote checks' '
	cd combined &&
	cat <<-EOT >expected &&
		origin
		refs/heads/t/branch2
		refs/$topbases/t/branch2
	EOT
	tgshim push -r origin t/branch2 >actual &&
	test_cmp actual expected &&
	tgshim -r remote1 push -r origin t/branch2 >actual &&
	test_cmp actual expected &&
	test_must_fail tg -c topgit.remote=remote2 push -r origin t/branch2 &&
	test_must_fail tg -r remote2 push -r origin t/branch2 &&
	tgshim -c topgit.remote=remote2 push -r origin --allow-outdated t/branch2 >actual &&
	test_cmp actual expected &&
	tgshim -r remote2 push -r origin --allow-outdated t/branch2 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.remote=remote2 -u push -r origin t/branch2 >actual &&
	test_cmp actual expected &&
	tgshim -r remote2 -u push -r origin t/branch2 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.remote=remote3 push -r origin t/branch2 >actual &&
	test_cmp actual expected &&
	tgshim -r remote4 push -r origin t/branch2 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 't/branch3 with remote checks' '
	cd combined &&
	cat <<-EOT >expected &&
		origin
		refs/heads/t/branch3
		refs/$topbases/t/branch3
	EOT
	tgshim push -r origin t/branch3 >actual &&
	test_cmp actual expected &&
	tgshim -r remote1 push -r origin t/branch3 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.remote=remote2 push -r origin t/branch3 >actual &&
	test_cmp actual expected &&
	test_must_fail tg -c topgit.remote=remote3 push -r origin t/branch3 &&
	test_must_fail tg -r remote3 push -r origin t/branch3 &&
	tgshim -c topgit.remote=remote3 push -r origin --allow-outdated t/branch3 >actual &&
	test_cmp actual expected &&
	tgshim -r remote3 push -r origin --allow-outdated t/branch3 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.remote=remote3 -u push -r origin t/branch3 >actual &&
	test_cmp actual expected &&
	tgshim -r remote3 -u push -r origin t/branch3 >actual &&
	test_cmp actual expected &&
	tgshim -r remote4 push -r origin t/branch3 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 't/branch4 with remote checks' '
	cd combined &&
	cat <<-EOT >expected &&
		origin
		refs/heads/t/branch4
		refs/$topbases/t/branch4
	EOT
	tgshim push -r origin t/branch4 >actual &&
	test_cmp actual expected &&
	tgshim -r remote1 push -r origin t/branch4 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.remote=remote2 push -r origin t/branch4 >actual &&
	test_cmp actual expected &&
	tgshim -r remote3 -u push -r origin t/branch4 >actual &&
	test_cmp actual expected &&
	test_must_fail tg -c topgit.remote=remote4 push -r origin t/branch4 &&
	test_must_fail tg -r remote4 push -r origin t/branch4 &&
	tgshim -c topgit.remote=remote4 push -r origin --allow-outdated t/branch4 >actual &&
	test_cmp actual expected &&
	tgshim -r remote4 push -r origin --allow-outdated t/branch4 >actual &&
	test_cmp actual expected &&
	tgshim -c topgit.remote=remote4 -u push -r origin t/branch4 >actual &&
	test_cmp actual expected &&
	tgshim -r remote4 -u push -r origin t/branch4 >actual &&
	test_cmp actual expected
'

test_done
