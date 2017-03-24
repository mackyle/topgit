#!/bin/sh
# TopGit - A different patch queue manager
# (c) Petr Baudis <pasky@suse.cz>  2008
# GPLv2

force= # Whether to delete non-empty branch, or branch where only the base is left.
name=


## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-f|--force)
		force=$(( $force +1 ));;
	-*)
		echo "Usage: ${tgname:-tg} [...] delete [-f] <name>" >&2
		exit 1;;
	*)
		[ -z "$name" ] || die "name already specified ($name)"
		name="$arg";;
	esac
done


## Sanity checks

[ -n "$name" ] || die "no branch name specified"
branchrev="$(git rev-parse --verify "refs/heads/$name" -- 2>/dev/null)" ||
	if [ -n "$force" ]; then
		info "invalid branch name: $name; assuming it has been deleted already"
	else
		die "invalid branch name: $name"
	fi
baserev="$(git rev-parse --verify "refs/$topbases/$name" -- 2>/dev/null)" ||
	die "not a TopGit topic branch: $name"
! headsym="$(git symbolic-ref -q HEAD)" || [ "$headsym" != "refs/heads/$name" ] || {
	[ -n "$force" ] && [ "$force" -ge 2 ] || die "cannot delete your current branch"
	warn "detaching HEAD to delete current branch"
	git update-ref -m "tgdelete: detach HEAD to delete $name" --no-deref HEAD "$branchrev"
	git log -n 1 --format=format:'HEAD is now at %h... %s' HEAD
}

[ -z "$force" ] && { branch_empty "$name" || die "branch is non-empty: $name"; }

# Quick'n'dirty check whether branch is required
[ -z "$force" ] && { $tg summary --deps | cut -d' ' -f2- | tr ' ' '\n' | grep -Fxq -- "$name" && die "some branch depends on $name"; }

## Wipe out

git update-ref -d "refs/$topbases/$name" "$baserev"
[ -z "$branchrev" ] || git update-ref -d "refs/heads/$name" "$branchrev"

# vim:noet
