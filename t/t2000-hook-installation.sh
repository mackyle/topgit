#!/bin/sh

test_description='test installation of pre-commit hook'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 21

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

has_no_tg_setup_bare() {
	test ! -e "${1:-.}/info/attributes" &&
	test ! -e "${1:-.}/hooks/pre-commit" &&
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

tgshell="$PWD/tgsh"
>"$tgshell" || die

test_expect_success 'setup_hook pre-commit' '
	test_create_repo r2 &&
	test ! -e r2/.git/hooks/pre-commit &&
	tg_test_include -C r2 &&
	cd r2 && setup_hook "pre-commit" && cd .. &&
	test -f r2/.git/hooks/pre-commit &&
	test -x r2/.git/hooks/pre-commit &&
	test ! -e r2/.git/hooks/pre-commit-chain &&
	sed -n 1p <r2/.git/hooks/pre-commit | tee "$tgshell" | grep -q "^#!" &&
	grep -F -q "${0##*/}" r2/.git/hooks/pre-commit &&
	grep -F -q "/pre-commit" r2/.git/hooks/pre-commit &&
	test $(wc -l <r2/.git/hooks/pre-commit) -eq 2 &&
	test ! -e r2/.git/info/attributes &&
	test_must_fail git -C r2 config merge.ours.name &&
	test_must_fail git -C r2 config merge.ours.driver &&
	rm -rf r2
'

read -r tgshellbin <"$tgshell" || die
write_script dummy.sh "${tgshellbin#??}" <<-EOT || die
	echo "dummy.sh here"
EOT

test_expect_success LASTOK 'setup_hook pre-commit edits matching shell once' '
	rm -rf r2 && test_create_repo r2 &&
	test ! -e r2/.git/hooks/pre-commit &&
	mkdir -p r2/.git/hooks &&
	cat "$tgshell" >r2/.git/hooks/pre-commit &&
	echo "echo editme" >>r2/.git/hooks/pre-commit &&
	chmod a+x r2/.git/hooks/pre-commit &&
	tg_test_include -C r2 &&
	# kludge here for some broken ancient sh implementations
	sane_unset -f cat &&
	cd r2 && setup_hook "pre-commit" && cd .. &&
	test -f r2/.git/hooks/pre-commit &&
	test -x r2/.git/hooks/pre-commit &&
	test ! -e r2/.git/hooks/pre-commit-chain &&
	lines=$(wc -l <r2/.git/hooks/pre-commit) &&
	test ${lines:-0} -gt 2 &&
	cd r2 && setup_hook "pre-commit" && cd .. &&
	lines2=$(wc -l <r2/.git/hooks/pre-commit) &&
	test "$lines" = "$lines2" &&
	rm -rf r2
'

test_expect_success 'setup_hook pre-commit chains symlink' '
	rm -rf r2 && test_create_repo r2 &&
	test ! -e r2/.git/hooks/pre-commit &&
	mkdir -p r2/.git/hooks &&
	ln -s ../../../dummy.sh r2/.git/hooks/pre-commit &&
	tg_test_include -C r2 &&
	cd r2 && setup_hook "pre-commit" && cd .. &&
	test -f r2/.git/hooks/pre-commit &&
	test -x r2/.git/hooks/pre-commit &&
	test -e r2/.git/hooks/pre-commit-chain &&
	rm -rf r2
'

test_expect_success 'setup_hook pre-commit chains dead symlink' '
	rm -rf r2 && test_create_repo r2 &&
	test ! -e r2/.git/hooks/pre-commit &&
	mkdir -p r2/.git/hooks &&
	ln -s ../../../dummy-no-such.sh r2/.git/hooks/pre-commit &&
	tg_test_include -C r2 &&
	cd r2 && setup_hook "pre-commit" && cd .. &&
	test -f r2/.git/hooks/pre-commit &&
	test -x r2/.git/hooks/pre-commit &&
	{ test -e r2/.git/hooks/pre-commit-chain || test -L r2/.git/hooks/pre-commit-chain; } &&
	rm -rf r2
'

test_expect_success 'setup_hook pre-commit chains multply-linked' '
	rm -rf r2 && test_create_repo r2 &&
	test ! -e r2/.git/hooks/pre-commit &&
	mkdir -p r2/.git/hooks &&
	ln dummy.sh r2/.git/hooks/pre-commit &&
	tg_test_include -C r2 &&
	cd r2 && setup_hook "pre-commit" && cd .. &&
	test -f r2/.git/hooks/pre-commit &&
	test -x r2/.git/hooks/pre-commit &&
	test -e r2/.git/hooks/pre-commit-chain &&
	rm -rf r2
'

test_expect_success 'setup_hook pre-commit chains non-executable' '
	rm -rf r2 && test_create_repo r2 &&
	test ! -e r2/.git/hooks/pre-commit &&
	mkdir -p r2/.git/hooks &&
	cp -p dummy.sh r2/.git/hooks/pre-commit &&
	chmod a-x r2/.git/hooks/pre-commit &&
	tg_test_include -C r2 &&
	cd r2 && setup_hook "pre-commit" && cd .. &&
	test -f r2/.git/hooks/pre-commit &&
	test -x r2/.git/hooks/pre-commit &&
	test -e r2/.git/hooks/pre-commit-chain &&
	rm -rf r2
'

test_expect_success 'setup_hook pre-commit chains non-writable' '
	rm -rf r2 && test_create_repo r2 &&
	test ! -e r2/.git/hooks/pre-commit &&
	mkdir -p r2/.git/hooks &&
	cp -p dummy.sh r2/.git/hooks/pre-commit &&
	chmod a-w r2/.git/hooks/pre-commit &&
	tg_test_include -C r2 &&
	cd r2 && setup_hook "pre-commit" && cd .. &&
	test -f r2/.git/hooks/pre-commit &&
	test -x r2/.git/hooks/pre-commit &&
	test -e r2/.git/hooks/pre-commit-chain &&
	rm -rf r2
'

test_expect_success 'setup_hook pre-commit chains non-readable' '
	rm -rf r2 && test_create_repo r2 &&
	test ! -e r2/.git/hooks/pre-commit &&
	mkdir -p r2/.git/hooks &&
	cp -p dummy.sh r2/.git/hooks/pre-commit &&
	chmod a-r r2/.git/hooks/pre-commit &&
	tg_test_include -C r2 &&
	cd r2 && setup_hook "pre-commit" && cd .. &&
	test -f r2/.git/hooks/pre-commit &&
	test -x r2/.git/hooks/pre-commit &&
	test -e r2/.git/hooks/pre-commit-chain &&
	rm -rf r2
'

TG_CMDS="
--version
--status
--hooks-path
--exec-path
--awk-path
--top-bases
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
shell
status
summary
tag
update
version
"

tg_cmd_will_setup() {
	case "$1" in
		--version|--status|--hooks-path|--exec-path|--awk-path|--top-bases| \
		base|contains|export|files|info|log|mail|next|patch|prev|rebase|revert|shell|status|st|summary|tag|version)
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
		test_might_fail </dev/null tg $cmd -h && has_no_tg_setup &&
		test_might_fail </dev/null tg $cmd --help && has_no_tg_setup || return
	done &&
	has_no_tg_setup &&
	cd .. && rm -rf r3
'

test_expect_success 'no setup happens for exempted commands' '
	test_create_repo r4 && cd r4 &&
	for cmd in $TG_CMDS; do
		if ! tg_cmd_will_setup "$cmd"; then
			say "# checking tg $cmd does not do setup"
			test_might_fail </dev/null tg $cmd && has_no_tg_setup &&
			test_might_fail </dev/null tg $cmd --bogus-option-here && has_no_tg_setup || return
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
			test_might_fail </dev/null tg $cmd &&
			test_might_fail </dev/null tg $cmd --bogus-option-here &&
			has_tg_setup &&
			cd .. && rm -rf rt
		'
	fi
done

# Note that the initial branch name in r5 does
# not affect these tests in any way
test_expect_success 'no setup happens in bare repository' '
	git init --bare --quiet r5 && cd r5 &&
	for cmd in $TG_CMDS; do
		say "# checking tg $cmd does not do setup in bare repo"
		test_might_fail </dev/null tg $cmd && has_no_tg_setup_bare &&
		test_might_fail </dev/null tg $cmd --bogus-option-here && has_no_tg_setup_bare || return
	done &&
	has_no_tg_setup_bare &&
	cd .. && rm -rf r5
'

test_done
