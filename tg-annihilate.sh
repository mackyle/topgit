#!/bin/sh
# TopGit - A different patch queue manager
# (c) Petr Baudis <pasky@suse.cz>  2008
# (c) Per Cederqvist <ceder@lysator.liu.se>  2010
# GPLv2

force= # Whether to annihilate non-empty branch, or branch where only the base is left.


## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-f|--force)
		force=1;;
	*)
		echo "Usage: ${tgname:-tg} [...] annihilate [-f]" >&2
		exit 1;;
	esac
done


## Sanity checks

name="$(verify_topgit_branch HEAD)"

[ -z "$force" ] && { branch_empty "$name" || die "branch is non-empty: $name"; }

## Annihilate
mb="$(git merge-base "refs/top-bases/$name" "refs/heads/$name")"
git read-tree "$mb^{tree}"
# Need to pass --no-verify in order to inhibit TopGit's pre-commit hook to run,
# which would bark upon missing .top* files.
git commit --no-verify -m"TopGit branch $name annihilated."

# Propagate the dependencies through to dependents (if any), if they don't already have them
dependencies="$(tg prev -w)"
$tg next | while read dependent; do
	git checkout -f $dependent
	needupdate=
	for dependency in $dependencies; do
		! $tg depend add --no-update "$dependency" >/dev/null 2>&1 || needupdate=1
	done
	[ -z "$needupdate" ] || $tg update $dependent || :
done

info "If you have shared your work, you might want to run ${tgname:-tg} push $name now."
git status

# vim:noet
