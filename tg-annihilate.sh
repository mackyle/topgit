#!/bin/sh
# TopGit - A different patch queue manager
# (C) Petr Baudis <pasky@suse.cz>  2008
# (C) Per Cederqvist <ceder@lysator.liu.se>  2010
# (C) Kyle J. McKay <mackyle@gmail.com>  2017
# All rights reserved.
# GPLv2

force= # Whether to annihilate non-empty branch, or branch where only the base is left.
update=1 # Whether to run tg update on affected branches
stash= # tgstash refs before changes

if [ "$(git config --get --bool topgit.autostash 2>/dev/null)" != "false" ]; then
	# topgit.autostash is true (or unset)
	stash=1
fi

## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-f|--force)
		force=1;;
	--stash)
		stash=1;;
	--no-stash)
		stash=;;
	--no-update)
		update=;;
	--update)
		update=1;;
	*)
		echo "Usage: ${tgname:-tg} [...] annihilate [-f] [--no-update]" >&2
		exit 1;;
	esac
done


## Sanity checks

v_verify_topgit_branch name HEAD
! branch_annihilated "$name" || die "TopGit branch $name is already annihilated."

[ -z "$force" ] && { branch_empty "$name" || die "branch is non-empty: $name"; }

## Annihilate
ensure_clean_tree
ensure_clean_topfiles
ensure_ident_available
alldeps="$(get_temp alldeps)"
tg --no-pager summary --deps >"$alldeps" || die "tg summary --deps failed"

# always auto stash even if it's just to the anonymous stash TG_STASH

stashbr="$(awk -v annb="$name" '
	NF == 2 {
		if ($1 == annb && $2 != "" && $2 != annb) print $2
		if ($2 == annb && $1 != "" && $1 != annb) print $1
	}
' <"$alldeps" | sort -u)"
stashmsg="tgannihilate: autostash before annihilate branch $name"
if [ -n "$stash" ]; then
	tg tag -q -q -m "$stashmsg" --stash $name $stashbr &&
	stashhash="$(git rev-parse --quiet --verify refs/tgstash --)" &&
	[ -n "$stashhash" ] &&
	[ "$(git cat-file -t "$stashhash" -- 2>/dev/null)" = "tag" ] ||
	die "requested --stash failed"
else
	tg tag --anonymous $name $stashbr &&
	stashhash="$(git rev-parse --quiet --verify TG_STASH --)" &&
	[ -n "$stashhash" ] &&
	[ "$(git cat-file -t "$stashhash" -- 2>/dev/null)" = "tag" ] ||
	die "anonymous --stash failed"
fi

mb="$(git merge-base "refs/$topbases/$name" "refs/heads/$name")"
git read-tree "$mb^{tree}"
# Need to pass --no-verify in order to inhibit TopGit's pre-commit hook to run,
# which would bark upon missing .top* files.
git commit --no-verify -m"TopGit branch $name annihilated."

# Propagate the dependencies through to dependents (if any), if they don't already have them
dependencies="$(awk -v annb="$name" 'NF == 2 && $2 != "" && $1 == annb { print $2 }' <"$alldeps")"
updatelist=
while read dependent && [ -n "$dependent" ]; do
	# to avoid ambiguity with checkout -f we must use symbolic-ref + reset
	git symbolic-ref HEAD "refs/heads/$dependent"
	git reset -q --hard
	needupdate=
	while read dependency && [ -n "$dependency" ]; do
		! tg depend add --no-update "$dependency" >/dev/null 2>&1 || needupdate=1
	done <<-EOT
	$dependencies
	EOT
	[ -z "$needupdate" ] || updatelist="${updatelist:+$updatelist }$dependent"
done <<EOT
$(awk -v annb="$name" 'NF == 2 && $1 != "" && $2 == annb { print $1 }' <"$alldeps")
EOT

info "branch successfully annihilated: $name"
now="now"
if [ -n "$updatelist" ]; then
	if [ -n "$update" ]; then
		now="after the update completes"
	else
		info "skipping update because --no-update given"
		info "be sure to update affected branches: $updatelist"
		now="after updating"
	fi
fi
info "If you have shared your work, you might want to run ${tgname:-tg} push $name $now."
if [ -n "$updatelist" ] && [ -n "$update" ]; then
	info "now updating affected branches: $updatelist"
	set -- $updatelist
	. "$TG_INST_CMDDIR"/tg-update
fi
