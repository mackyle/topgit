#!/bin/sh
# TopGit test_have_prereq helper command
# Copyright (C) 2015,2017,2021 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

USAGE="Usage: ${0##*/} <PREREQ>..."

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

test $# -gt 0 || usage 1

set -e

root=
cleanup() {
	[ -z "$root" ] || rm -rf "$root"
}
root="$(mktemp -d "/tmp/testpreq$$.XXXXXX")" &&
test -d "$root" && test -w "$root" || exit 1

prereqs_to_test="$*"
set -- --root="$root"

test_description='test_have_prereq helper'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

TESTLIB_EXIT_OK=1

ec=0
test_have_prereq "$prereqs_to_test" || ec=$?

trap cleanup EXIT
rm -rf "$root"
root=
exit ${ec:-0}
