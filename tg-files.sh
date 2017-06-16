#!/bin/sh
# TopGit - A different patch queue manager
# (c) Petr Baudis <pasky@suse.cz>  2008
# GPLv2

name=
head_from=


## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-i|-w)
		[ -z "$head_from" ] || die "-i and -w are mutually exclusive"
		head_from="$arg";;
	-*)
		echo "Usage: ${tgname:-tg} [...] files [-i | -w] [<name>]" >&2
		exit 1;;
	*)
		[ -z "$name" ] || die "name already specified ($name)"
		name="$arg";;
	esac
done


head="$(git symbolic-ref -q HEAD)" || :
head="${head#refs/heads/}"

[ -n "$name" ] ||
	name="${head:-HEAD}"
name="$(verify_topgit_branch "$name")"
base_rev="$(git rev-parse --short --verify "refs/$topbases/$name^0" -- 2>/dev/null)" ||
	die "not a TopGit-controlled branch"

if [ -n "$head_from" ] && [ "$name" != "$head" ]; then
	die "$head_from makes only sense for the current branch"
fi

[ -z "$head_from" ] || ensure_work_tree

b_tree=$(pretty_tree -t "$name" -b)
t_tree=$(pretty_tree -t "$name" $head_from)

git diff-tree --name-only -r $b_tree $t_tree

# vim:noet

