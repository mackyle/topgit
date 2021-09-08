#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) 2021 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved
# GPLv2

USAGE="\
Usage: ${tgname:-tg} [...] files [-i | -w] [<name>]
Options:
    -i                  use TopGit metadata from index instead of HEAD branch
    -w                  use metadata from working directory instead of branch"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

name=
head_from=

## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-h|--help)
		usage;;
	-i|-w)
		[ -z "$head_from" ] || die "-i and -w are mutually exclusive"
		head_from="$arg";;
	-*)
		usage 1;;
	*)
		[ -z "$name" ] || die "name already specified ($name)"
		name="$arg";;
	esac
done

head="$(git symbolic-ref -q HEAD)" || :
head="${head#refs/heads/}"

[ -n "$name" ] ||
	name="${head:-HEAD}"
v_verify_topgit_branch name "$name"
base_rev="$(git rev-parse --short --verify "refs/$topbases/$name^0" -- 2>/dev/null)" ||
	die "not a TopGit-controlled branch"

if [ -n "$head_from" ] && [ "$name" != "$head" ]; then
	die "$head_from makes only sense for the current branch"
fi

[ -z "$head_from" ] || ensure_work_tree

v_pretty_tree b_tree -t "$name" -b
v_pretty_tree t_tree -t "$name" $head_from

git diff-tree --name-only -r $b_tree $t_tree
