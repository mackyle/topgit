#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015
# GPLv2

USAGE="Usage: ${tgname:-tg} [...] info [--heads] [<name>]"

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

heads=

while [ $# -gt 0 ]; do case "$1" in
	-h|--help)
		usage
		;;
	--heads)
		heads=1
		;;
	-?*)
		echo "Unknown option: $1" >&2
		usage 1
		;;
	*)
		break
		;;
esac; shift; done
[ $# -gt 0 ] || set -- HEAD
[ $# -eq 1 ] || die "name already specified ($1)"
name="$1"

# true if $1 is an ancestor of (or the same as) $2 
is_ancestor()
{
	[ -z "$(git rev-list --max-count=1 "$1" --not "$2" --)" ]
}

if [ -n "$heads" ]; then
	verify="$name"
	! test="$(verify_topgit_branch "${name:-HEAD}" -f)" || verify="refs/heads/$test"
	hash="$(git rev-parse --verify --quiet "$verify" --)" || die "no such ref: $name"
	$tg summary --tgish-only --heads |
	while read -r head; do
		if is_ancestor "$hash" "refs/heads/$head"; then
			printf '%s\n' "$head"
		fi
	done
	exit 0
fi

name="$(verify_topgit_branch "${name:-HEAD}")"
base_rev="$(git rev-parse --short --verify "refs/top-bases/$name" -- 2>/dev/null)" ||
	die "not a TopGit-controlled branch"

measure="$(measure_branch "$name" "$base_rev")"

echo "Topic Branch: $name ($measure)"
if [ "$(git rev-parse --verify --short "refs/heads/$name" --)" = "$base_rev" ]; then
	echo "* No commits."
	exit 0
fi

git cat-file blob "$name:.topmsg" | grep ^Subject: || :

echo "Base: $base_rev"
branch_contains "refs/heads/$name" "refs/top-bases/$name" ||
	echo "* Base is newer than head! Please run \`$tgdisplay update\`."

if has_remote "$name"; then
	echo "Remote Mate: $base_remote/$name"
	branch_contains "refs/top-bases/$name" "refs/remotes/$base_remote/top-bases/$name" ||
		echo "* Local base is out of date wrt. the remote base."
	branch_contains "refs/heads/$name" "refs/remotes/$base_remote/$name" ||
		echo "* Local head is out of date wrt. the remote head."
	branch_contains "refs/remotes/$base_remote/$name" "refs/heads/$name" ||
		echo "* Local head is ahead of the remote head."
fi

git cat-file blob "$name:.topdeps" 2>/dev/null |
	sed '1{ s/^/Depends: /; n; }; s/^/         /;'

depcheck="$(get_temp tg-depcheck)"
missing_deps=
needs_update "$name" >"$depcheck" || :
if [ -n "$missing_deps" ]; then
	echo "MISSING: $missing_deps"
fi
depcheck2="$(get_temp tg-depcheck2)"
sed '/^!/d' <"$depcheck" >"$depcheck2"
if [ -s "$depcheck2" ]; then
	echo "Needs update from:"
	cat "$depcheck2" |
		sed 's/ [^ ]* *$//' | # last is $name
		sed 's/^[:] //' | # don't distinguish base updates
		sed 's/^% /~/' | # but we may need special remote handling
		while read dep chain; do
			rmt=
			dep2=
			case "$dep" in "~"?*)
				rmt=1
				dep="${dep#?}"
				#dep2="refs/remotes/$base_remote/$dep"
			esac
			printf '%s' "$dep "
			[ -n "$chain" ] && printf '%s' "(<= $(echo "$chain" | sed 's/ / <= /')) "
			dep_parent="${chain%% *}"
			printf '%s' "($(measure_branch "$dep" "${dep2:-$name}"))"
			echo
		done | sed 's/^/	/'
else
	echo "Up-to-date${missing_deps:+ (except for missing dependencies)}."
fi

# vim:noet
