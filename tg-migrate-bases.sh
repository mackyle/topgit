#!/bin/sh

# tg--migrate-bases -- migrate from old top-bases to new {top-bases}
# Copyright (C) 2017 Kyle J. McKay
# All rights reserved.
# License GPLv2+

USAGE="\
Usage: ${tgname:-tg} [...] migrate-bases (--dry-run | --force) [--no-remotes | --remotes-only]"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

## Parse options

dryrun=
force=
noremotes=
remotesonly=
reverse=
orphans=1

while [ $# -gt 0 ]; do case "$1" in
	-h|--help)
		usage
		;;
	-n|--dry-run|--dryrun)
		dryrun=1
		;;
	-f|--force)
		force=1
		;;
	--no-remotes)
		noremotes=1
		;;
	--remotes-only)
		remotesonly=1
		;;
	--reverse)
		reverse=1
		;;
	--orphans|--orphan)
		orphans=1
		;;
	--no-orphans|--no-orphan)
		orphans=
		;;
	-?*)
		echo "Unknown option: $1" >&2
		usage 1
		;;
esac; shift; done

[ "$dryrun$force" = "1" ] || usage 1
[ "$noremotes$remotesonly" != "11" ] || usage 1
[ $# -eq 0 ] || usage 1

remotes=
[ -n "$noremotes" ] || remotes="$(git remote)" || :

if [ -z "$reverse" ]; then
	oldbases="top-bases"
	oldbasesrx="top-bases"
	newbases="heads/{top-bases}"
	newbasesrx="heads/[{]top-bases[}]"
else
	oldbases="heads/{top-bases}"
	oldbasesrx="heads/[{]top-bases[}]"
	newbases="top-bases"
	newbasesrx="top-bases"
fi

refpats=
[ -n "$remotesonly" ] || refpats="refs/$oldbases"
[ -z "$remotes" ] || refpats="$refpats$(printf " refs/remotes/%s/${oldbases#heads/}" $remotes)"
[ -n "$refpats" ] || exit 0

topbraces="{top-bases}"
not_orphan_base() {
	_check=
	case "$1" in
		"refs/top-bases"/[!/]*)
			_check="refs/heads/${1#refs/top-bases/}"
			;;
		"refs/heads/{top-bases}"/[!/]*)
			_check="refs/heads/${1#refs/heads/$topbraces/}"
			;;
		"refs/remotes"/[!/]*)
			_rb="${1#refs/remotes/}"
			_rn="${_rb%%/*}"
			_rr="${_rb#*/}"
			case "$_rr" in
				"top-bases"/[!/]*)
					_check="refs/remotes/$_rn/${_rr#top-bases/}"
					;;
				"{top-bases}"/[!/]*)
					_check="refs/remotes/$_rn/${_rr#$topbraces/}"
					;;
			esac
			;;
	esac
	[ -n "$_check" ] || return 1
	git rev-parse --verify --quiet "$_check" -- >/dev/null
}

v_transform_base() {
	_newb=
	case "$2" in
		"refs/top-bases"/[!/]*)
			_newb="refs/heads/{top-bases}/${2#refs/top-bases/}"
			_wasrevdir=
			_wasremote=
			;;
		"refs/heads/{top-bases}"/[!/]*)
			_newb="refs/top-bases/${2#refs/heads/$topbraces/}"
			_wasremote=
			_wasrevdir=1
			;;
		"refs/remotes"/[!/]*)
			_rb="${2#refs/remotes/}"
			_rn="${_rb%%/*}"
			_rr="${_rb#*/}"
			case "$_rr" in
				"top-bases"/[!/]*)
					_newb="refs/remotes/$_rn/{top-bases}/${_rr#top-bases/}"
					_wasrevdir=
					_wasremote=1
					;;
				"{top-bases}"/[!/]*)
					_newb="refs/remotes/$_rn/top-bases/${_rr#$topbraces/}"
					_wasrevdir=1
					_wasremote=1
					;;
			esac
			;;
	esac
	if [ -n "$_newb" ] && [ -n "$1" ]; then
		eval "$1="'"$_newb"'
		return 0
	fi
	[ -z "$1" ] || eval "$1="
	return 1
}

for r in $remotes; do
	nv="+refs/$newbases/*:refs/remotes/$r/${newbases#heads/}/*"
	if rf="$(git config --get-all "remote.$r.fetch" \
		"\\+?refs/(top-bases|heads/[{]top-bases[}])/\\*:refs/remotes/$r/(top-bases|[{]top-bases[}])/\\*")" &&
		[ "$rf" != "$nv" ]; then
		echo "remote.$r.fetch:"
		printf '    %s\n' $rf
		printf ' -> %s\n' "$nv"
		if [ -n "$force" ]; then
			git config --replace-all "remote.$r.fetch" "$nv" \
				"\\+?refs/(top-bases|heads/[{]top-bases[}])/\\*:refs/remotes/$r/(top-bases|[{]top-bases[}])/\\*"
		fi
	elif [ "$rf" != "$nv" ] && rf="$(git config --get-all "remote.$r.fetch" "\\+?refs/(top-bases|heads/[{]top-bases[}])/.*")"; then
		echo "remote.$r.fetch may need manual updates of:"
		printf '    %s\n' $rf
	fi
done

while read -r rn rt rh && [ -n "$rn" ] && [ -n "$rt" ] && [ -n "$rh" ]; do
	if [ -z "$orphans" ] && ! not_orphan_base "$rn"; then
		echo "skipping orphan base (use --orphans): $rn" >&2
		continue
	fi
	if [ "$rt" = "tree" ] || [ "$rt" = "blob" ]; then
		echo "ignoring base with type $rt: $rn" >&2
		continue
	fi
	if [ "$rt" = "tag" ]; then
		rnc="$(git rev-parse --verify --quiet "$rh^0" -- 2>/dev/null)" || :
		if [ -z "$rnc" ]; then
			echo "ignoring base with type tag of non-commit: $rn" >&2
			continue
		fi
		echo "warning: resolving base with type tag to commit: $rn" >&2
		rh="$rnc"
	fi
	v_transform_base newb "$rn" || die "unexpected non-bases ref: $rn"
	newbrev="$(git rev-parse --verify --quiet "$newb" --)" || :
	newbtype=
	[ -z "$newbrev" ] || newbtype="$(git cat-file -t "$newbrev")"
	if [ "$newbtype" = "tree" ] || [ "$newbtype" = "blob" ]; then
		echo "warning: $rn" >&2
		echo "    refusing to update existing ref:" >&2
		echo "    $newb" >&2
		echo "    of type $newbtype" >&2
		continue
	fi
	if [ "$newbtype" = "tag" ]; then
		newbrev="$(git rev-parse --verify --quiet "$newbrev^0" -- 2>/dev/null)" || :
		if [ -z "$newbrev" ]; then
			echo "warning: $rn" >&2
			echo "    refusing to update existing ref:" >&2
			echo "    $newb" >&2
			echo "    of type tag of non-commit" >&2
			continue
		fi
		echo "warning: $rn" >&2
		echo "    treating existing ref:" >&2
		echo "    $newb" >&2
		echo "    of type tag as the tagged commit" >&2
	fi
	if [ -n "$newbrev" ] && [ "$newbrev" != "rh" ]; then
		mb="$(git merge-base "$newbrev" "$rh" 2>/dev/null)" || :
		if [ "$mb" = "$newbrev" ]; then
			echo "warning: $rn" >&2
			echo "    ignoring existing ref:" >&2
			echo "    $newb" >&2
			echo "    since it's contained in $rn" >&2
		elif [ "$mb" = "$rh" ]; then
			echo "warning: $rn" >&2
			echo "    using existing value of ref:" >&2
			echo "    $newb" >&2
			echo "    since it contains $rn" >&2
			rh="$newbrev"
		else
			rd="$(git --no-pager log -n 1 --format='format:%ct' "$rh" --)"
			newbdt="$(git --no-pager log -n 1 --format='format:%ct' "$newbrev" --)"
			if [ "$rd" -ge "$newbdt" ]; then
				echo "warning: $rn" >&2
				echo "    ignoring existing diverged ref:" >&2
				echo "    $newb" >&2
				echo "    since it's got an older committer timestamp" >&2
			else
				echo "warning: $rn" >&2
				echo "    using existing value of diverged ref:" >&2
				echo "    $newb" >&2
				echo "    since it's got a newer committer timestamp" >&2
				rh="$newbrev"
			fi
		fi
	fi
	printf 'update: %s\n -> %s\n' "$rn" "$newb"
	if [ -n "$force" ]; then
		git update-ref "$newb" "$rh"
		if [ "$(git rev-parse --quiet --verify "$newb" --)" = "$rh" ] && [ "$newb" != "$rn" ]; then
			git update-ref -d "$rn"
		fi
	fi
done <<EOT
$(git for-each-ref --format='%(refname) %(objecttype) %(objectname)' $refpats)
EOT

maindir="$(cd "$git_common_dir" && pwd -P)"
if [ "$git_dir" = "$git_common_dir" ]; then
	headdir="$maindir"
else
	headdir="$(cd "$git_dir" && pwd -P)"
fi

# note that [ -n "$iowopt" ] will be true if linked worktrees are available
maybehaslw=
if
	[ -n "$iowopt" ] &&
	[ -d "$maindir/worktrees" ] &&
	[ $(( $(find "$maindir/worktrees" -mindepth 2 -maxdepth 2 -type f -name HEAD -print 2>/dev/null | wc -l) )) -gt 0 ]
then
	maybehaslw=1
fi

# $1 => --git-dir to process (or try to anyway)
processed=" "
process_one_symref() {
	case "$processed" in *" $1 "*) return 0; esac
	processed="$processed$1 "
	hsymref="$(git --git-dir="$1" symbolic-ref --quiet HEAD -- 2>/dev/null)" &&
	[ -n "$hsymref" ] || return 0
	v_transform_base xsymref "$hsymref" || return 0
	[ -z "$_wasrevdir" ] || [ -n "$reverse" ] || return 0
	[ -n "$_wasrevdir" ] || [ -z "$reverse" ] || return 0
	[ -z "$_wasremote" ] || [ -z "$noremotes" ] || return 0
	[ -n "$_wasremote" ] || [ -z "$remotesonly" ] || return 0

	appellation="HEAD"
	[ "$1" != "$headdir" ] || [ -z "$maybehaslw" ] || appellation="$appelation ="
	if [ -n "$maybehaslw" ]; then
		if [ "$1" = "$maindir" ]; then
			workname="main"
		else
			workname="${1##*/}"
		fi
		appellation="${appellation:+$appellation }($workname)"
	fi
	[ -z "$appellation" ] || appellation=" [$appellation]"
	printf 'symref: %s%s\n -> %s\n' "$hsymref" "$appellation" "$xsymref"
	if [ -n "$force" ]; then
		git --git-dir="$1" symbolic-ref HEAD "$xsymref" --
	fi
}

# always do our HEAD first
process_one_symref "$headdir"
# then the main HEAD (it will automatically be ignored if a duplicate)
process_one_symref "$maindir"
# then each worktree (again duplicates will be automatically ignored)
if [ -n "$maybehaslw" ]; then
	while read -r wktree && [ -n "$wktree" ]; do
		process_one_symref "${wktree%/HEAD}"
	done <<-EOT
	$(find "$maindir/worktrees" -mindepth 2 -maxdepth 2 -type f -name HEAD -print 2>/dev/null)
	EOT
fi
