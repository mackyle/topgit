#!/bin/sh

test_description='various sanity checks

Most of these are "tolerate_failure" checks
as there are workarounds in place for them.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 10

test_tolerate_failure 'POSIX unset behavior' '
	test z"$(unset it && unset it && echo good || echo bad)" = z"good"
'

test_tolerate_failure 'POSIX exec behavior' '
	test z"$(false() { :; }; (exec false) && echo "bad" || echo "good")" = z"good"
'

test_tolerate_failure 'POSIX eval behavior' '
	setec() { ! : || eval "ec=\$?"; } &&
	setec && test z"$ec" = z"1"
'

test_tolerate_failure 'POSIX trap EXIT behavior' '
	nomsg() { trap "echo bad" EXIT; } &&
	result="$(nomsg && trap - EXIT)" &&
	test z"${result:-good}" = z"good"
'

test_tolerate_failure 'POSIX alias' '
	alias some=alias
'

test_tolerate_failure LASTOK 'POSIX unalias -a (no subshell)' '
	alias some=alias &&
	unalias -a
'

test_tolerate_failure LASTOK 'POSIX unalias -a (subshell w/o aliases)' '
	unalias -a
'

test_tolerate_failure 'POSIX function redir ops' '
	redir() {
		echo bad stderr >&2
		echo bad stdout
	} >/dev/null 2>&1 &&
	test z"$(redir && echo good)" = z"good"
'

test_tolerate_failure 'unsettable LINENO' '
	{ unset LINENO || :; }
'

test_tolerate_failure 'working awk implementation' '
	# mawk will have a segmentation fault with this
	awk "
function f1(a1) {}
function f2(a2) {
	f1(a2);
	for (;;) break;
}
function f3() {
	f2(a3);
	a3[1];
}
BEGIN { exit; }
"'

test_done
