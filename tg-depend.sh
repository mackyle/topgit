#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015
# All rights reserved.
# GPLv2

USAGE="Usage: ${tgname:-tg} [...] depend add [--no-update | --no-commit] <name>"

name=

usage()
{
	printf '%s\n' "$USAGE" >&2
	exit 1
}

## Parse options

subcmd="$1"
case "$subcmd" in
	-h|--help|"")
		usage;;
	add)
		;;
	*)
		die "unknown subcommand ($subcmd)";;
esac
shift

noupdate=
nocommit=
while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	--no-update)
		noupdate=1;;
	--no-commit)
		nocommit=1;;
	-*)
		usage;;
	*)
		[ -z "$name" ] || die "name already specified ($name)"
		name="$arg";;
	esac
done


## Sanity checks

[ -n "$name" ] || die "no branch name specified"
branchrev="$(git rev-parse --verify "refs/heads/$name" -- 2>/dev/null)" ||
	die "invalid branch name: $name"

# Check that we are on a TopGit branch.
current_name="$(verify_topgit_branch HEAD)"

## Record new dependency
depend_add()
{
	[ "$name" = "$current_name" ] &&
		die "$name cannot depend on itself."

	{ $tg summary --deps; echo "$current_name" "$name"; } |
		tsort >/dev/null ||
		die "$tgname: that dependency would introduce a dependency loop"

	grep -F -x -e "$name" "$root_dir/.topdeps" >/dev/null &&
		die "$tgname: $current_name already depends on $name"

	echo "$name" >>"$root_dir/.topdeps"
	git add -f "$root_dir/.topdeps"
	msg=".topdeps: add new dependency $name"
	[ -z "$nocommit" ] || {
		[ -s "$git_dir/MERGE_MSG" ] || printf '%s\n' "$msg" >"$git_dir/MERGE_MSG"
		info "added new dependency $name to .topdeps and staged it"
		info "run \`git commit\` then \`tg update\` to complete addition"
		exit 0
	}
	git commit -m "$msg" "$root_dir/.topdeps"
	[ -z "$noupdate" ] || {
		info "be sure to run \`tg update\` at some point"
		exit 0
	}
	(ensure_clean_tree) || {
		warn "skipping needed \`tg update\` since worktree is dirty"
		warn "be sure to run \`tg update\` when worktree is clean"
		exit 1
	}
	$tg update
}

depend_$subcmd

# vim:noet
