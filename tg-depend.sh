#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015
# All rights reserved.
# GPLv2

USAGE="Usage: ${tgname:-tg} [...] depend add [--no-update | --no-commit] <name>..."

names=

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
ensure_work_tree

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
		names="${names:+$names }$arg";;
	esac
done


## Sanity checks

[ -n "$names" ] || die "no branch name specified"
oldnames="$names "
names=
while
	name="${oldnames%% *}"
	oldnames="${oldnames#* }"
	[ -n "$name" ]
do
	case " $names " in *" $name "*) continue; esac
	git rev-parse --quiet --verify "refs/heads/$name" -- >/dev/null ||
	die "invalid branch name: $name"
	names="${names:+$names }$name"
done
unset oldnames

# Check that we are on a TopGit branch.
v_verify_topgit_branch current_name HEAD

check_cycle_name()
{
	[ "$current_name" != "$_dep" ] ||
		die "$tgname: that dependency ($newly_added) would introduce a dependency loop"
}

check_new_dep()
{
	[ "$1" != "$current_name" ] ||
		die "$current_name cannot depend on itself."
	! grep -F -q -x -e "$1" "$root_dir/.topdeps" ||
		die "$tgname: $current_name already depends on $1"
	# deps can be non-tgish but we can't run recurse_deps() on them
	ref_exists "refs/$topbases/$1" || return 0
	no_remotes=1
	newly_added="$1"
	recurse_deps check_cycle_name "$newly_added"
}

## Record new dependency
depend_add()
{
	[ -z "$(git status --porcelain -- :/.topdeps)" ] ||
		die ".topdeps has uncommitted changes"
	# We are "read-only" and cacheable until the first change
	tg_read_only=1
	v_create_ref_cache
	for name in $names; do
		check_new_dep "$name"
	done
	[ -n "$nocommit" ] || ensure_ident_available
	newdepsfile="$(get_temp newdeps)"
	! [ -e "$root_dir/.topdeps" ] || awk '{print}' <"$root_dir/.topdeps" >"$newdepsfile"
	for name in $names; do
		echol "$name" >>"$newdepsfile"
	done
	cat "$newdepsfile" >"$root_dir/.topdeps"
	git add -f "$root_dir/.topdeps"
	case "$names" in
	*" "*)
		msg=".topdeps: add dependencies: $names";;
	*)
		msg=".topdeps: add new dependency $name";;
	esac
	[ -z "$nocommit" ] || {
		[ -s "$git_dir/MERGE_MSG" ] || printf '%s\n' "$msg" >"$git_dir/MERGE_MSG"
		info "updated .topdeps and staged the change"
		info "run \`git commit\` then \`tg update\` to complete addition"
		exit 0
	}
	become_non_cacheable
	git commit -m "$msg" "$root_dir/.topdeps"
	[ -z "$noupdate" ] || {
		info "be sure to run \`tg update\` at some point"
		exit 0
	}
	(ensure_clean_tree) || {
		warn "skipping needed \`tg update\` since working directory is dirty"
		warn "be sure to run \`tg update\` when working directory is clean"
		exit 1
	}
	set -- "$current_name"
	. "$TG_INST_CMDDIR"/tg-update
}

depend_$subcmd
