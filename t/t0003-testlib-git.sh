#!/bin/sh

test_description='check git test library utility functions

Although the focus of this test suite as a whole is testing TopGit,
several of the utility functions are convenient front-ends for Git
routines.

Those are not tested by the testlib-basic tests so test the Git
functions here.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 28

# This isn't really necessary, but this is the "Git" test...
case "$(git version)" in
	[Gg][Ii][Tt]" "[Vv][Ee][Rr][Ss][Ii][Oo][Nn]" "[1-9]*)
		;;
	*)
		error "'git' seems to be missing"\!
		;;
esac

GAI="$(git var GIT_AUTHOR_IDENT | sed 's/>.*/>/')" && [ -n "$GAI" ] &&
GCI="$(git var GIT_COMMITTER_IDENT | sed 's/>.*/>/')" && [ -n "$GAI" ] ||
error "failed to get GIT_AUTHOR_IDENT and/or GIT_COMMITTER_IDENT"\!

cleanrefs() {
	git pack-refs --all &&
	rm -f .git/packed-refs &&
	! test -e .git/packed-refs &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/master &&
	! git rev-parse --verify --quiet refs/heads/master --
}

cleanconfig() {
    cat .git/config.bak > .git/config
}

test_expect_success 'no initial tick' '
	test z"${test_tick:-none}" = z"none"
'

test_expect_success 'tick once' '
	test_tick &&
	test z"$test_tick" = z"1112911993"
'

test_expect_success 'tick twice' '
	test_tick &&
	test_tick &&
	test $test_tick -eq $((1112911993 + 60))
'

test_expect_success 'test_create_repo' '
	test_create_repo repo &&
	test -d repo &&
	frd="$(cd repo && pwd -P)" &&
	gtl="$(git -C repo rev-parse --show-toplevel)" &&
	test -n "$gtl" &&
	gtl="$(cd "$gtl" && pwd -P)" && test -n "$gtl" &&
	test "$frd" = "$gtl" &&
	rm -rf repo
'

test_expect_success 'commands fail with no repo' '
	! test_config foo.bar tar &&
	! test_unconfig foo.bar &&
	! test_commit &&
	! test_merge foo &&
	! test_cmp_rev HEAD HEAD &&
	test_clear_when_finished
'

test_expect_success 'set global config without repo' '
	git config --global yesuch.config global &&
	test z"global" = z"$(git config yesuch.config)"
'

test_expect_success 'test_unconfig --global unset without repo' '
	test_unconfig --global yesuch.config &&
	test z = z"$(git config yesuch.global || :)"
'

test_expect_success 'test_unconfig --global already unset without repo' '
	test_unconfig --global yesuch.config &&
	test z = z"$(git config yesuch.global || :)"
'

git init --quiet --template="$EMPTY_DIRECTORY" &&
cp .git/config .git/config.bak ||
error "failed to initialize top repo"

test_expect_success 'test_unconfig already unset' '
	test_unconfig nosuch.config &&
	test z = z"$(git config nosuch.config || :)"
'

test_expect_success 'set local repo config' '
	git config nosuch.config not &&
	test z"not" = z"$(git config nosuch.config)"
'

test_expect_success 'test_unconfig' '
	test_unconfig nosuch.config &&
	test z = z"$(git config nosuch.config || :)"
'

test_expect_success 'nosuch.config exists not' '
	cleanconfig &&
	test_must_fail git config nosuch.config
'

test_expect_success 'test_config sets config' '
	cleanconfig &&
	test_config nosuch.config not &&
	cfg="$(git config nosuch.config)" &&
	test z"not" = z"$cfg"
'

test_expect_success LASTOK 'test_config auto unsets config' '
	test_must_fail git config nosuch.config
'

test_expect_success 'set multivalued config' '
	cleanconfig &&
	test_config nosuch.config not1 &&
	git config --add nosuch.config not2 &&
	test 2 -eq $(git config --get-all nosuch.config | wc -l)
'

test_expect_success LASTOK 'test_config auto unsets all config' '
	test_must_fail git config nosuch.config
'

test_expect_success 'test_config_global sets config' '
	cleanconfig &&
	test_config_global nosuch.config not &&
	cfg="$(git config --global nosuch.config)" &&
	test z"not" = z"$cfg"
'

test_expect_success LASTOK 'test_config_global auto unsets config' '
	test_must_fail git config nosuch.config
'

test_expect_success 'set multivalued global config' '
	cleanconfig &&
	test_config_global nosuch.config not1 &&
	git config --global --add nosuch.config not2 &&
	test 2 -eq $(git config --global --get-all nosuch.config | wc -l)
'

test_expect_success LASTOK 'test_config_global auto unsets all config' '
	test_must_fail git config nosuch.config
'

test_expect_success 'test_commit --notick' '
	cleanrefs &&
	test_commit --notick notick &&
	git rev-parse --verify master -- &&
	git rev-parse --verify notick -- &&
	test -e notick.t &&
	test z"notick" = z"$(cat notick.t)" &&
	test z"notick" = z"$(git log --format="format:%B" -n 1)" &&
	test z"1112911993" != z"$(git log --format="format:%ct" -n 1)"
'

test_expect_success 'test_commit (with tick)' '
	cleanrefs &&
	test_commit withtick &&
	git rev-parse --verify master -- &&
	git rev-parse --verify withtick -- &&
	test -e withtick.t &&
	test z"withtick" = z"$(cat withtick.t)" &&
	test z"withtick" = z"$(git log --format="format:%B" -n 1)" &&
	test z"1112911993" = z"$(git log --format="format:%ct" -n 1)"
'

test_expect_success 'test_commit no defaults' '
	cleanrefs &&
	test_commit nodefs no_defs.t no_defs_contents no_defs_tag &&
	git rev-parse --verify master -- &&
	git rev-parse --verify no_defs_tag -- &&
	test -e no_defs.t &&
	test z"no_defs_contents" = z"$(cat no_defs.t)" &&
	test z"nodefs" = z"$(git log --format="format:%B" -n 1)"
'

test_expect_success 'test_commit --signoff' '
	cleanrefs &&
	test_commit --signoff signoff &&
	git rev-parse --verify master -- &&
	git rev-parse --verify signoff -- &&
	test -e signoff.t &&
	test z"signoff" = z"$(cat signoff.t)" &&
	test z"signoff" = z"$(git log --format="format:%B" -n 1 | sed -n 1p)" &&
	test z"$GCI" = \
		z"$(git log --format="format:%B" -n 1 | sed -n "/^Signed-off-by:/s/^.*: *//p")"
'

test_expect_success 'test_commit no tag' '
	cleanrefs &&
	test_commit notag no_tag.t no_tag_contents "" &&
	git rev-parse --verify master -- &&
	test_must_fail git rev-parse --verify --quiet notag -- &&
	test -e no_tag.t &&
	test z"no_tag_contents" = z"$(cat no_tag.t)" &&
	test z"notag" = z"$(git log --format="format:%B" -n 1)"
'

test_expect_success 'test_commit skip ~ tag' '
	cleanrefs &&
	test_commit skip~tag &&
	git rev-parse --verify master -- &&
	test_must_fail git rev-parse --verify --quiet skip~tag -- &&
	test -e skip~tag.t &&
	test z"skip~tag" = z"$(cat skip~tag.t)" &&
	test z"skip~tag" = z"$(git log --format="format:%B" -n 1)"
'

test_expect_success 'test_commit skip " " tag' '
	cleanrefs &&
	test_commit "skip tag" &&
	git rev-parse --verify master -- &&
	test_must_fail git rev-parse --verify --quiet "skip tag" -- &&
	test -e "skip tag.t" &&
	test z"skip tag" = z"$(cat "skip tag.t")" &&
	test z"skip tag" = z"$(git log --format="format:%B" -n 1)"
'

test_expect_success 'test_merge' '
	test_commit base &&
	test_commit one^file &&
	git checkout -b topic base &&
	test_commit merge^me &&
	git checkout master &&
	test_merge merged topic &&
	test_debug git show-ref &&
	test_debug git log $color --oneline --graph --decorate --date-order --branches --tags &&
	test 2 -eq $(git log --format="format:%p" -n 1 | wc -w) &&
	test_cmp_rev HEAD master &&
	test_cmp_rev master merged
'

test_done
