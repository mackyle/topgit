#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) 2008 Petr Baudis <pasky@suse.cz>
# Copyright (C) 2009 Bert Wesarg <Bert.Wesarg@googlemail.com>
# Copyright (C) 2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved
# License GPLv2

USAGE="\
Usage: ${tgname:-tg} [...] next [-v] [-i | -w] [-a | -n <steps>] [<name>]"

usage()
{
	[ -z "$2" ] || printf '%s\n' "$2" >&2
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

script='
NF == 1 { print }
NF > 1 {
	names = ""
	for (i = 2; i <= NF; ++i) names = names ", " $i
	print $1 " [" substr(names, 3) "]"
}'

# Parse options

all=
steps=
head_from=
verbose=
aremutex="are mutually exclusive"

docount()
{
	case "$2" in
		[1-9]*)
			[ "$2" = "${2%%[!0-9]*}" ] ||
			usage 1 "invalid $1 step count"
			steps=$(( 0 + $2 ))
			[ "$steps" != "0" ] ||
			usage 1 "invalid $1 step count (0 not allowed)"
			;;
		"")
			usage 1 "invalid $1 step count (may not be empty string)"
			;;
		*)
			usage 1 "invalid $1 step count (must be positive number)"
			;;
	esac
}

while [ $# -gt 0 ]; do case "$1" in
	-h|--help)
		usage
		;;
	-v|--verbose)
		verbose=1
		;;
	-i|-w)
		[ -z "$head_from" ] || usage 1 "-i and -w $aremutex"
		head_from="$1"
		;;
	-a|--all)
		[ -z "$steps" ] || usage 1 "-a and -n $aremutex"
		all=1
		;;
	--count=*)
		[ -z "$all" ] || usage 1 "--count= and -a $aremutex"
		docount "--count=" "${1#--count=}"
		;;
	--count|-n)
		[ -z "$all" ] || usage 1 "$1 and -a $aremutex"
		[ $# -ge 2 ] || usage 1 "$1 requires an argument"
		docount "$1" "$2"
		shift
		;;
	-?*)
		usage 1 "Unknown option: $1"
		;;
	*)
		break
		;;
esac; shift; done
[ $# -ne 0 ] || set -- "HEAD"
[ $# -eq 1 ] || usage 1 "at most one branch name argument is allowed"
v_verify_topgit_branch name "$1"
[ -z "$all" ] || steps="-1"
[ -n "$steps" ] || steps="1"

tdopt=
[ -z "$head_from" ] || v_get_tdopt tdopt "$head_from"
oneopt="-1"
verbcmd=
if [ -n "$verbose" ]; then
	oneopt=
	verbcmd='| awk "$script"'
fi
eval navigate_deps "$tdopt" "$oneopt" '-n -t -s="$steps" -- "$name"' "$verbcmd"
