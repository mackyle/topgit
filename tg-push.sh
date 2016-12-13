#!/bin/sh
# TopGit - A different patch queue manager
# GPLv2

## Parse options

recurse_deps=true
tgish_deps_only=false
dry_run=
force=
push_all=false
branches=

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	--no-deps)
		recurse_deps=false;;
	--dry-run)
		dry_run=--dry-run;;
	-f|--force)
		force=--force;;
	--tgish-only)
		tgish_deps_only=true;;
	-a|--all)
		push_all=true;;
	-h|--help)
		echo "Usage: ${tgname:-tg} [...] push [--dry-run] [--force] [--no-deps] [--tgish-only] [-r <remote>] [-a | --all | <branch>...]"
		exit 0;;
	-r)
		remote="$1"
		shift
		;;
	*)
		branches="${branches:+$branches }$(strip_ref "$arg")";;
	esac
done

if [ -z "$remote" ]; then
	remote="$base_remote"
fi

if [ -z "$remote" ]; then
	die "no remote location given. Either use -r remote argument or set topgit.remote"
fi

if [ -z "$branches" ]; then
	if $push_all; then
		branches="$(non_annihilated_branches | paste -s -d " ")"
	else
		branches="$(verify_topgit_branch HEAD)"
	fi
else
	oldbranches="$branches"
	branches=
	while read name && [ -n "$name" ]; do
		if [ "$name" = "HEAD" ]; then
			sr="$(git symbolic-ref --quiet HEAD || :)"
			[ -n "$sr" ] || die "cannot push a detached HEAD"
			case "$sr" in refs/heads/*) :;; *)
				die "HEAD is a symref to other than refs/heads/..."
			esac
			branches="${branches:+$branches }${sr#refs/heads/}"
		else
			ref_exists "refs/heads/$name" || die "no such ref: refs/heads/$name"
			branches="${branches:+$branches }$name"
		fi
	done <<-EOT
	$(sed 'y/ /\n/' <<-LIST
	$oldbranches
	LIST
	)
	EOT
	unset oldbranches
fi

_listfile="$(get_temp tg-push-listfile)"

push_branch()
{
	# FIXME should we abort on missing dependency?
	[ -z "$_dep_missing" ] || return 0

	# if so desired omit non tgish deps
	$tgish_deps_only && [ -z "$_dep_is_tgish" ] && return 0

	# filter out plain SHA1s.  These don't need to be pushed explicitly as
	# the patches that depend on the sha1 have it already in their ancestry.
	is_sha1 "$_dep" && return 0

	echol "$_dep" >> "$_listfile"
	[ -z "$_dep_is_tgish" ] ||
		echo "$topbases/$_dep" >> "$_listfile"
}

no_remotes=1
while read name && [ -n "$name" ]; do
	# current branch
	# re-use push_branch, which expects some pre-defined variables
	_dep="$name"
	_dep_is_tgish=1
	_dep_missing=
	ref_exists "refs/$topbases/$_dep" ||
		_dep_is_tgish=
	push_branch "$name"

	# deps but only if branch is tgish
	$recurse_deps && [ -n "$_dep_is_tgish" ] &&
		recurse_deps push_branch "$name"
done <<EOT
$(sed 'y/ /\n/' <<LIST
$branches
LIST
)
EOT

# remove multiple occurrences of the same branch
sort -u "$_listfile" | xargs git push $dry_run $force "$remote"
