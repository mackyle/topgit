#!/bin/sh

test_description='various sanity checks

Most of these are "tolerate_failure" checks
as there are workarounds in place for them.
'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 16

# required working

test_tolerate_failure 'POSIX tr to NUL processing' '
	printf "1x2x3x" | tr "x" "\\000" >lines3z &&
	val="$(xargs -0 <lines3z printf "%s\n" | wc -l)" &&
	test $val -eq 3
'

test_expect_success 'POSIX tr from NUL processing' '
	val="$(echo "x@@@y" | tr "x@y" "1\\0005" | tr "\\000" 2)" &&
	test z"$val" = z"12225"
'

# tolerated breakage

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

test_tolerate_failure 'POSIX awk pattern brace quantifiers' '
	# mawk stupidly does not support these
	# can you hear us mocking you mawk?
	result="$(echo not-mawk | awk "/^[a-z-]{5,}\$/")" &&
	test z"$result" = z"not-mawk"
'

test_tolerate_failure 'POSIX awk ENVIRON array' '
	EVAR="This  is  some  test  here" &&
	export EVAR &&
	val="$(awk "BEGIN{exit}END{print ENVIRON[\"EVAR\"]}")" &&
	test z"$val" = z"$EVAR"
'

test_tolerate_failure 'POSIX export unset var exports it' '
	say_color info "# POSIX is, regrettably, quite explicit about this" &&
	say_color info "# POSIX requires EVERY exported variable to be in child environment" &&
	unset NO_SUCH_VAR &&
	export NO_SUCH_VAR &&
	printenv NO_SUCH_VAR >/dev/null
'

v_count_words() { eval "${1:-scratch_}=\"$(( $# - 1 ))\""; }

test_expect_success 'count word function works' '
	sane_unset scratch_ &&
	v_count_words && test "$scratch_" = "-1" &&
	sane_unset scratch_ &&
	test "${scratch_+yes}" != "yes" &&
	v_count_words zero && test "$zero" = "0" &&
	v_count_words one 1 && test "$one" = "1" &&
	v_count_words one "a b c" && test "$one" = "1" &&
	v_count_words two    a   b      && test "$two" = "2" &&
	v_count_words three  three 2 1 && test "$three" = "3" &&
	line="\"a b c d\" e f g" &&
	eval v_count_words four "$line" && test "$four" = "4" &&
	line="\"a b c d\" e" &&
	v_count_words five $line && test "$five" = "5" &&
	test "${scratch_+yes}" != "yes"
'

test_done
