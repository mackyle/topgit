#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) 2008 Petr Baudis <pasky@suse.cz>
# Copyright (C) 2017,2018 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved
# License GPLv2

force= # Whether to delete non-empty branch, or branch where only the base is left.
stash= # tgstash refs before changes
name=

if [ "$(git config --get --bool topgit.autostash 2>/dev/null)" != "false" ]; then
	# topgit.autostash is true (or unset)
	stash=1
fi

## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-f|--force)
		force=$(( $force +1 ));;
	--stash)
		stash=1;;
	--no-stash)
		stash=;;
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
branchrev="$(git rev-parse --verify "refs/heads/$name^0" -- 2>/dev/null)" ||
	if [ -n "$force" ]; then
		info "invalid branch name: $name; assuming it has been deleted already"
	else
		die "invalid branch name: $name"
	fi
baserev="$(git rev-parse --verify "refs/$topbases/$name^0" -- 2>/dev/null)" ||
	die "not a TopGit topic branch: $name"
! headsym="$(git symbolic-ref -q HEAD)" || [ "$headsym" != "refs/heads/$name" ] || {
	[ -n "$force" ] && [ "$force" -ge 2 ] || die "cannot delete your current branch"
	warn "detaching HEAD to delete current branch"
	git update-ref -m "tgdelete: detach HEAD to delete $name" --no-deref HEAD "$branchrev"
	git --no-pager log -n 1 --format=format:'HEAD is now at %h... %s' HEAD
}

[ -z "$force" ] && { branch_empty "$name" || die "branch is non-empty: $name"; }

# Quick'n'dirty check whether branch is required
[ -n "$force" ] || ! tg summary --tgish-only --deps | cut -d ' ' -f2- | tr ' ' '\n' | grep -Fxq -- "$name" ||
	die "some branch depends on $name"

ensure_ident_available

# always auto stash even if it's just to the anonymous stash TG_STASH

stashmsg="tgdelete: autostash before delete branch $name"
if [ -n "$stash" ]; then
	tg tag -q -q -m "$stashmsg" --stash $name &&
	stashhash="$(git rev-parse --quiet --verify refs/tgstash --)" &&
	[ -n "$stashhash" ] &&
	[ "$(git cat-file -t "$stashhash" -- 2>/dev/null)" = "tag" ] ||
	die "requested --stash failed"
else
	tg tag --anonymous $name &&
	stashhash="$(git rev-parse --quiet --verify TG_STASH --)" &&
	[ -n "$stashhash" ] &&
	[ "$(git cat-file -t "$stashhash" -- 2>/dev/null)" = "tag" ] ||
	die "anonymous --stash failed"
fi

## Wipe out

git update-ref -d "refs/$topbases/$name" "$baserev"
[ -z "$branchrev" ] || git update-ref -d "refs/heads/$name" "$branchrev"
