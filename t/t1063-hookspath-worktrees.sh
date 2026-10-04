#!/bin/sh

test_description='configured hooks work in ordinary and linked worktrees'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

if vcmp "$git_version" '>=' "2.9"; then
	test_set_prereq GIT_2_9
fi

test_plan 19

check_hookspath_case() (
	layout="$1" head="$2" location="$3"
	repository="$layout-$head-$location-repo"
	checkout="$repository"
	test_create_repo "$repository" &&
	(cd "$repository" && test_commit initial tracked seed) || return
	base="$(git -C "$repository" symbolic-ref --short HEAD)" || return
	if [ "$layout" = linked ]; then
		checkout="$layout-$head-$location-linked"
		git -C "$repository" worktree add -b linked "$PWD/$checkout" "$base" || return
	fi
	if [ "$head" = detached ]; then
		git -C "$checkout" checkout --detach || return
	fi
	case "$location" in
		absolute) git -C "$checkout" config core.hooksPath "$PWD/$checkout/custom hooks" || return;;
		relative) git -C "$checkout" config core.hooksPath "custom hooks" || return;;
	esac
	mkdir -p "$checkout/nested" "$repository/.git/info" &&
	echo "*.existing text" >"$repository/.git/info/attributes" &&
	tg_test_setup_topgit -C "$checkout/nested" || return
	hooks="$(git -C "$checkout" rev-parse --git-path hooks)" || return
	case "$hooks" in /*);;*) hooks="$checkout/$hooks";; esac
	test -x "$hooks/pre-commit" &&
	grep -q "^[*][.]existing text$" "$repository/.git/info/attributes" &&
	git -C "$checkout" check-attr merge -- .topmsg .topdeps >actual &&
	printf "%s\n" ".topmsg: merge: ours" ".topdeps: merge: ours" >expected &&
	test_cmp expected actual || return
	if [ "$layout" = linked ]; then
		private="$(git -C "$checkout" rev-parse --git-dir)" &&
		test ! -e "$private/hooks" &&
		test ! -e "$private/info/attributes" || return
	fi
	cp "$hooks/pre-commit" expected-hook &&
	cp "$repository/.git/info/attributes" expected-attributes &&
	tg_test_setup_topgit -C "$checkout" &&
	test_cmp expected-hook "$hooks/pre-commit" &&
	test_cmp expected-attributes "$repository/.git/info/attributes" || return
	if [ "$head" = topic ]; then
		tg -C "$checkout" create --no-edit t/topic "$base" || return
	fi
	echo changed >"$checkout/tracked" &&
	git -C "$checkout" add tracked &&
	git -C "$checkout" commit -qm "with hook enabled" || return
	if [ "$head" = topic ]; then
		git -C "$checkout" rm .topmsg &&
		test_must_fail git -C "$checkout" commit -qm "invalid topic" >actual 2>&1 &&
		grep -q ".topmsg is missing" actual || return
	fi
)

for layout in main linked; do
	for head in ordinary detached topic; do
		for location in default absolute relative; do
			test_expect_success GIT_2_9 "$layout $head with $location hooks" '
				check_hookspath_case "$layout" "$head" "$location"
			'
		done
	done
done

test_expect_success GIT_2_9 'explicitly disabled hooks are not installed' '
	test_create_repo disabled &&
	git -C disabled config core.hooksPath /dev/null &&
	tg_test_setup_topgit -C disabled &&
	test ! -e disabled/.git/hooks/pre-commit
'

test_done
