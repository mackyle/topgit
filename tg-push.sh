#!/bin/sh
# TopGit - A different patch queue manager
# GPLv2

## Parse options

recurse_deps=1
tgish_deps_only=
dry_run=
force=
push_all=
outofdateok=
branches=
remote=
signedopt=
atomicopt=
opt4=
opt6=

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	--no-deps)
		recurse_deps=;;
	--dry-run)
		dry_run=--dry-run;;
	-f|--force)
		force=--force;;
	--signed|--signed=*)
		signedopt="$arg";;
	--atomic)
		atomicopt="$arg";;
	-4|--ipv4)
		opt4="$arg";;
	-6|--ipv6)
		opt6="$arg";;
	--tgish-only)
		tgish_deps_only=1;;
	-a|--all)
		push_all=1;;
	--allow-outdated)
		outofdateok=1;;
	-h|--help)
		echo "Usage: ${tgname:-tg} [...] push [--dry-run] [--force] [--no-deps] [--tgish-only] [-r <pushRemote>] [-a | --all | <branch>...]"
		exit 0;;
	-r)
		remote="$1"
		shift
		;;
	*)
		v_strip_ref arg "$arg"
		branches="${branches:+$branches }$arg";;
	esac
done
[ -z "$push_all" ] || [ -z "$branches" ] || die "branch names not allowed with --all"

[ -n "$remote" ] || remote="$(git config topgit.pushremote 2>/dev/null)" || :
[ -n "$remote" ] || remote="$base_remote"

if [ -z "$remote" ]; then
	warn "either use -r <pushRemote> argument or set topgit.[push]remote"
	die "no push remote location given"
fi

[ -n "$branches$push_all" ] || branches="HEAD"
if [ -n "$push_all" ]; then
	branches="$(non_annihilated_branches | paste -s -d " " -)"
else
	oldbranches="$branches"
	branches=
	while read name && [ -n "$name" ]; do
		if [ "$name" = "HEAD" ] || [ "$name" = "@" ]; then
			sr="$(git symbolic-ref --quiet HEAD)" || :
			[ -n "$sr" ] || die "cannot push a detached HEAD"
			case "$sr" in refs/heads/*);;*)
				die "HEAD is a symref to other than refs/heads/..."
			esac
			ref_exists "$sr" || die "HEAD ($sr) is unborn"
			b="${sr#refs/heads/}"
		else
			ref_exists "refs/heads/$name" || die "no such ref: refs/heads/$name"
			b="$name"
		fi
		case " $branches " in *" $b "*);;*)
			branches="${branches:+$branches }$b"
		esac
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
	[ -z "$tgish_deps_only" ] || [ -n "$_dep_is_tgish" ] || return 0

	# filter out plain SHA1s.  These don't need to be pushed explicitly as
	# the patches that depend on the sha1 have it already in their ancestry.
	! is_sha1 "$_dep" || return 0

	echol "refs/heads/$_dep" >> "$_listfile"
	[ -z "$_dep_is_tgish" ] ||
		echo "refs/$topbases/$_dep" >> "$_listfile"
}

if [ -z "$outofdateok" ]; then
	needs_update_check_clear
	needs_update_check $branches
	if [ -n "$needs_update_behind" ]; then
		printf 'branch not up-to-date: %s\n' $needs_update_behind >&2
		die "all branches to be pushed must be up-to-date (try --allow-outdated)"
	fi
fi

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
	[ -z "$recurse_deps" ] || [ -z "$_dep_is_tgish" ] ||
		recurse_deps push_branch "$name"
done <<EOT
$(sed 'y/ /\n/' <<LIST
$branches
LIST
)
EOT

[ -s "$_listfile" ] || die "nothing to push"

# remove multiple occurrences of the same branch
sort -u "$_listfile" |
sed 's,[^A-Za-z0-9/_.+-],\\&,g' |
xargs git push $opt4 $opt6 $dry_run $force $atomicopt $signedopt "$remote"
