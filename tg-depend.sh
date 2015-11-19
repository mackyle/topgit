#!/bin/sh
# TopGit - A different patch queue manager
# (c) Petr Baudis <pasky@suse.cz>  2008
# GPLv2

name=

usage()
{
	echo "Usage: ${tgname:-tg} [...] depend add <name>" >&2
	exit 1
}

## Parse options

subcmd="$1"
case "$subcmd" in
	-h|"")
		usage;;
	add)
		;;
	*)
		die "unknown subcommand ($subcmd)";;
esac
shift

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
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
	git commit -m ".topdeps: add new dependency $name" "$root_dir/.topdeps"
	(ensure_clean_tree) || {
		warn "skipping needed \`tg update\` since worktree is dirty"
		warn "be sure to run \`tg update\` when worktree is clean"
		exit 1
	}
	$tg update
}

depend_$subcmd

# vim:noet
