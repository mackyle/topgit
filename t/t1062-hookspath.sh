#!/bin/sh

test_description='test core.hooksPath management'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

if vcmp "$git_version" '>=' "2.9"; then
        test_set_prereq GIT_2_9
fi

test_plan 16

write_dummy_script() {
	write_script "$@" <<\EOT
exit 0
EOT
}

write_dummy_file() {
	echo "# dummy file $1" >"$1"
}

matches() {
	eval "case \"$1\" in $2) return 0; esac"
	return 1
}

do_mergesetup() {
        test_might_fail tg -C "$1" update no-such-branch-name 2>&1
}

do_status() {
        test_might_fail tg -C "$1" status 2>&1
}

test_expect_success 'setup' '
	mkdir _global _global/hooks insidious insidious/_global insidious/_global/hooks &&
	ln -s _global/hooks globhookdir &&
	ln -s . insidious/subdir &&
	git init -q --template "$PWD/_global/hooks" --bare insidious/_global &&
	write_dummy_script _global/hooks/pre-auto-gc &&
	write_dummy_script _global/hooks/pre-receive &&
	write_dummy_script _global/hooks/update &&
	write_dummy_script _global/hooks/post-commit &&
	write_dummy_script _global/hooks/post-receive &&
	write_dummy_file _global/hooks/prepare-commit-msg &&
	write_dummy_script _global/hooks/commit-msg.sh &&
	test_create_repo r1 &&
	test_create_repo r2 &&
	mkdir r2/.git/hooks &&
	test_create_repo r3 &&
	mkdir r3/.git/hooks &&
	(cd r3/.git/hooks && ln -s ../../../_global/hooks/* ./) &&
	rm r3/.git/hooks/prepare-commit-msg r3/.git/hooks/commit-msg.sh &&
	test_create_repo r4 &&
	mkdir r4/.git/hooks &&
	cp _global/hooks/* r4/.git/hooks/ &&
	rm r4/.git/hooks/prepare-commit-msg r4/.git/hooks/commit-msg.sh &&
	cp r4/.git/hooks/* insidious/_global/hooks/ &&
	test ! -d r5 &&
	cp -R r3 r5 &&
	test -d r5/.git/hooks &&
	rm r5/.git/hooks/update &&
	test ! -d r6 &&
	cp -R r4 r6 &&
	test -d r6/.git/hooks &&
	rm r6/.git/hooks/update &&
	test ! -d r7 &&
	cp -R r4 r7 &&
	test -d r7/.git/hooks &&
	echo different >> r7/.git/hooks/update &&
	test ! -d r8 &&
	cp -R r4 r8 &&
	test -d r8/.git/hooks &&
	echo notexec > r8/.git/hooks/update &&
	chmod a-x r8/.git/hooks/update
'

test_expect_success GIT_2_9 'relative hookspath' '
	test_config -C r2 core.hooksPath "" &&
	bad= &&
	for rpath in hooks .git/hooks ../_global/hooks ../../_global/hooks; do
		git -C r2 config core.hooksPath "$rpath" &&
		result="$(set +vx && do_mergesetup r2)" &&
		matches "$result" "*\"ignoring non-absolute core.hooks\"[Pp]\"ath\"*" || {
			bad=1 &&
			break
		}
	done &&
	test -z "$bad"
'

test_expect_success GIT_2_9 'no such hookspath' '
	test_config -C r2 core.hooksPath "" &&
	bad= &&
	for rpath in hooks .git/hooks ../_global/hooks ../../_global/hooks; do
		git -C r2 config core.hooksPath "$PWD/ns1/ns2/ns3/ns4/$rpath" &&
		result="$(set +vx && do_mergesetup r2)" &&
		matches "$result" "*\"ignoring non-existent core.hooks\"[Pp]\"ath\"*" || {
			bad=1 &&
			break
		}
	done &&
	test -z "$bad"
'

test_expect_success GIT_2_9 'our absolute hooks' '
	test_config -C r2 core.hooksPath "" &&
	bad= &&
	for rpath in hooks hooks/../hooks ../.git/hooks ../../r2/.git/hooks; do
		git -C r2 config core.hooksPath "$PWD/r2/.git/$rpath" &&
		result="$(set +vx && do_mergesetup r2)" &&
		newcp="$(git -C r2 config core.hooksPath)" &&
		test "$PWD/r2/.git/$rpath" = "$newcp" &&
		! matches "$result" "*\" warning: \"*" || {
			bad=1 &&
			break
		}
	done &&
	test -z "$bad"
'

test_expect_success GIT_2_9 'no gratuitous hookspath' '
	bad= &&
	for rpath in r?; do
		do_mergesetup $rpath >/dev/null &&
		test_must_fail git config -C $rpath --get core.hooksPath >/dev/null || {
			bad=1 &&
			break
		}
	done &&
	test -z "$bad"
'

friendly="r3 r4"

for repo in r?; do
case " $friendly " in *" $repo "*);;*) continue; esac
test_expect_success GIT_2_9 'adjusted "friendly" hookspath '"$repo" '
	test_config -C $repo core.hooksPath "" &&
	bad= &&
	for gpath in _global/hooks globhookdir; do
		rm -f "$gpath/pre-commit" &&
		git -C $repo config core.hooksPath "$PWD/$gpath" &&
		result="$(set +vx && do_mergesetup $repo)" &&
		newcp="$(git -C $repo config core.hooksPath)" &&
		test "$PWD/$gpath" != "$newcp" &&
		test "$(cd "$PWD/$repo/.git/hooks" && pwd -P)" = "$(cd "$newcp" && pwd -P)" &&
		! matches "$result" "*\" warning: \"*" || {
			bad=1 &&
			break
		}
	done &&
	test -z "$bad"
'
done

for repo in r?; do
case " $friendly " in *" $repo "*);;*) continue; esac
test_expect_success GIT_2_9 'unadjusted "friendly" hookspath '"$repo" '
	test_config -C $repo core.hooksPath "" &&
	bad= &&
	for gpath in _global/hooks globhookdir; do
		rm -f "$gpath/pre-commit" &&
		git -C $repo config core.hooksPath "$PWD/$gpath" &&
		result="$(set +vx && do_status $repo)" &&
		newcp="$(git -C $repo config core.hooksPath)" &&
		test "$PWD/$gpath" = "$newcp" &&
		! matches "$result" "*\" warning: \"*" || {
			bad=1 &&
			break
		}
	done &&
	test -z "$bad"
'
done

for repo in r?; do
case " $friendly " in *" $repo "*) continue; esac
test_expect_success GIT_2_9 '"unfriendly" hookspath '"$repo" '
	test_config -C $repo core.hooksPath "" &&
	bad= &&
	for gpath in _global/hooks globhookdir; do
		rm -f "$gpath/pre-commit" &&
		git -C $repo config core.hooksPath "$PWD/$gpath" &&
		result="$(set +vx && do_mergesetup $repo)" &&
		newcp="$(git -C $repo config core.hooksPath)" &&
		test "$PWD/$gpath" = "$newcp" &&
		! matches "$result" "*\" warning: \"*" || {
			bad=1 &&
			break
		}
	done &&
	test -z "$bad"
'
done

test_expect_success GIT_2_9 'insidious hookspath' '
	git -C insidious/_global config core.hooksPath "$PWD/insidious/subdir/_global/hooks" &&
	do_mergesetup insidious/_global >/dev/null &&
	newcp="$(git -C insidious/_global config core.hooksPath)" &&
	test "$PWD/insidious/subdir/_global/hooks" = "$newcp"
'

test_done
