#!/bin/sh

test_description='test installation of pre-commit hook'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 19

has_tg_setup() {
	test -s "${1:-.}/.git/info/attributes" &&
	test -s "${1:-.}/.git/hooks/pre-commit" &&
	test -x "${1:-.}/.git/hooks/pre-commit" &&
	gcmd_="$(git -C "${1:-.}" config merge.ours.driver)" &&
	test z"$gcmd_" = z"touch %A"
}

has_no_tg_setup() {
	test ! -e "${1:-.}/.git/info/attributes" &&
	test ! -e "${1:-.}/.git/hooks/pre-commit" &&
	test_must_fail git -C "${1:-.}" config merge.ours.driver
}

test_expect_success 'setup_ours' '
	tab="	" && # single tab character in quotes
	test_create_repo r1 &&
	test ! -e r1/.git/info/attributes &&
	tg_test_include -C r1 &&
	cd r1 && setup_ours && cd .. &&
	test -f r1/.git/info/attributes &&
	test -r r1/.git/info/attributes &&
	grep -q "^[.]topmsg[ $tab][ $tab]*merge=ours$" r1/.git/info/attributes &&
	grep -q "^[.]topdeps[ $tab][ $tab]*merge=ours$" r1/.git/info/attributes &&
	gcmn="$(git -C r1 config merge.ours.name)" &&
	test -n "$gcmn" &&
	gcmd="$(git -C r1 config merge.ours.driver)" &&
	test -n "$gcmd" && test z"$gcmd" = z"touch %A" &&
	test ! -e r1/.git/hooks/pre-commit &&
	rm -rf r1
'

test_expect_success 'setup_hook pre-commit' '
	test_create_repo r2 &&
	test ! -e r2/.git/hooks/pre-commit &&
	tg_test_include -C r2 &&
	cd r2 && setup_hook "pre-commit" && cd .. &&
	test -f r2/.git/hooks/pre-commit &&
	test -x r2/.git/hooks/pre-commit &&
	sed -n 1p <r2/.git/hooks/pre-commit | grep -q "^#!" &&
	grep -F -q "${0##*/}" r2/.git/hooks/pre-commit &&
	grep -F -q "/pre-commit" r2/.git/hooks/pre-commit &&
	test $(wc -l <r2/.git/hooks/pre-commit) -eq 2 &&
	test ! -e r2/.git/info/attributes &&
	test_must_fail git -C r2 config merge.ours.name &&
	test_must_fail git -C r2 config merge.ours.driver &&
	rm -rf r2
'

TG_CMDS="
annihilate
base
checkout
contains
create
delete
depend
export
files
import
info
log
mail
next
patch
prev
push
rebase
remote
revert
status
summary
tag
update
"

tg_cmd_will_setup() {
	case "$1" in
		base|contains|info|log|rebase|revert|status|st|summary|tag)
			return 1
	esac
	return 0
}

test_expect_success 'no setup happens for help' '
	test_create_repo r3 && cd r3 &&
	say "# checking tg help variations" &&
	test_might_fail tg && has_no_tg_setup &&
	test_might_fail tg -h && has_no_tg_setup &&
	test_might_fail tg --help && has_no_tg_setup &&
	test_might_fail tg --bogus && has_no_tg_setup &&
	for cmd in $TG_CMDS; do
		say "# checking tg $cmd help variations" &&
		test_might_fail tg $cmd -h && has_no_tg_setup &&
		test_might_fail tg $cmd --help && has_no_tg_setup
	done &&
	has_no_tg_setup &&
	cd .. && rm -rf r3
'

test_expect_success 'no setup happens for exempted commands' '
	test_create_repo r4 && cd r4 &&
	for cmd in $TG_CMDS; do
		if ! tg_cmd_will_setup "$cmd"; then
			say "# checking tg $cmd does not do setup"
			test_might_fail tg $cmd && has_no_tg_setup &&
			test_might_fail tg $cmd --bogus-option-here && has_no_tg_setup
		fi
	done &&
	has_no_tg_setup &&
	cd .. && rm -rf r4
'

for cmd in $TG_CMDS; do
	if tg_cmd_will_setup "$cmd"; then
		test_expect_success "setup happens for tg $cmd" '
			rm -rf rt && test_create_repo rt && cd rt &&
			has_no_tg_setup &&
			test_might_fail tg $cmd &&
			test_might_fail tg $cmd --bogus-option-here &&
			has_tg_setup &&
			cd .. && rm -rf rt
		'
	fi
done

test_done
