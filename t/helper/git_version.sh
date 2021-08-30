#!/bin/sh
# TopGit git_version helper command
# Copyright (C) 2015,2017,2021 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

USAGE="Usage: ${0##*/} [<optional> <prefix> <message>]"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

test "$1" != "-h" && test "$1" != "--help" || usage 1

set -e

root=
cleanup() {
	[ -z "$root" ] || rm -rf "$root"
}
root="$(mktemp -d "/tmp/testpreq$$.XXXXXX")" &&
test -d "$root" && test -w "$root" || exit 1

prefix_msg="$*"
test -z "$prefix_msg" || prefix_msg="$prefix_msg "
set -- --root="$root"

test_description='git_version helper'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

TESTLIB_EXIT_OK=1
trap cleanup EXIT
rm -rf "$root"
root=

test -n "$git_version" || exit 1
printf '%s\n' "$prefix_msg$git_version"
exit 0
