#!/bin/sh
# TopGit contains command
# (C) 2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved
# GPLv2

USAGE="\
Usage: ${tgname:-tg} [...] contains [-v] [-r] [--ann] [--no-strict] [--] <committish>"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

verbose=
remotes=
strict=1
annok=

while [ $# -gt 0 ]; do case "$1" in
	-h|--help)
		usage
		;;
	-r|--remotes)
		remotes=1
		;;
	--ann|--annihilated|--annihilated-ok|--annihilated-okay)
		annok=1
		;;
	--heads)
		echo "Did you mean --verbose (-v) instead of --heads?" >&2
		usage 1
		;;
	-v|--verbose)
		verbose=$(( ${verbose:-0} + 1 ))
		;;
	-vv|-vvv|-vvvv|-vvvvv)
		verbose=$(( ${verbose:-0} + ${#1} - 1 ))
		;;
	--strict)
		strict=1
		;;
	--no-strict)
		strict=
		;;
	--)
		shift
		break
		;;
	-?*)
		echo "Unknown option: $1" >&2
		usage 1
		;;
	*)
		break
		;;
esac; shift; done
[ $# = 1 ] || usage 1
[ "$1" != "@" ] || set -- HEAD

set -e
findrev="$(git rev-parse --verify "$1"^0 --)" || exit 1

# $1 => return correct $topbases value in here on success
# $2 => remote name
# $3 => remote branch name
# succeeds if both refs/remotes/$2/$3 and refs/remotes/$2/${$1#heads/}/$3 exist
v_is_remote_tgbranch()
{
	git rev-parse --quiet --verify "refs/remotes/$2/$3^0" -- >/dev/null || return 1
	if git rev-parse --quiet --verify "refs/remotes/$2/${topbases#heads/}/$3^0" -- >/dev/null; then
		[ -z "$1" ] || eval "$1="'"$topbases"'
		return 0
	fi
	git rev-parse --quiet --verify "refs/remotes/$2/${oldbases#heads/}/$3^0" -- >/dev/null || return 1
	if [ -z "$annok" ]; then
		rmb="$(git merge-base "refs/remotes/$2/${oldbases#heads/}/$3^0" "refs/remotes/$2/$3^0" 2>/dev/null)" || :
		if [ -n "$rmb" ]; then
			rmbtree="$(git rev-parse --quiet --verify "$rmb^{tree}" --)" || :
			rbrtree=
			[ -z "$rmbtree" ] ||
			rbrtree="$(git rev-parse --quiet --verify "refs/remotes/$2/$3^{tree}" --)" || :
			[ -z "$rmbtree" ] || [ -z "$rbrtree" ] || [ "$rmbtree" != "$rbrtree" ] || return 1
		fi
	fi
	[ -z "$1" ] || eval "$1="'"$oldbases"'
}

process_dep()
{
	if [ -n "$_dep_is_tgish" ] && [ -z "$_dep_missing$_dep_annihilated" ]; then
		printf '%s\n' "$_dep ${_depchain##* }"
	fi
}

depslist=
make_deps_list()
{
	no_remotes=1
	base_remote=
	depslist="$(get_temp depslist)" || exit 1
	tg summary --topgit-heads |
	while read -r onetghead; do
		printf '%s %s\n' "$onetghead" "$onetghead"
		recurse_deps process_dep "$onetghead"
	done | sort -u >"$depslist"
}

localcnt=
remotecnt=
localb="$(get_temp localb)" || exit 1
localwide=0
remoteb=
remotewide=0
[ -z "$remotes" ] || remoteb="$(get_temp remoteb)" || exit 1
process_branches() {
	while read -r branch bremote && [ -n "$branch" ]; do case "$branch" in
		"refs/$topbases"/?*)
			continue
			;;
		"refs/heads"/?*)
			[ -z "$bremote" ] && v_verify_topgit_branch "" "$branch" -f || continue
			branch="${branch#refs/heads/}"
			[ -n "$annok" ] || ! branch_annihilated "$branch" || continue
			if contained_by "$findrev" "refs/$topbases/$branch"; then
				[ -z "$strict" ] || continue
				depth="$(git rev-list --count --ancestry-path \
					"refs/$topbases/$branch" --not "$findrev")"
				depth=$(( ${depth:-0} + 1 ))
			else
				depth=0
			fi
			localcnt=$(( ${localcnt:-0} + 1 ))
			[ ${#branch} -le $localwide ] || localwide=${#branch}
			printf '%s %s\n' "$depth" "$branch" >>"$localb"
			remotecnt=
			;;
		*)
			[ -n "$bremote" ] && [ -n "$remotes" ] && [ -z "$localcnt" ] &&
			[ "${branch#refs/remotes/}" != "$branch" ] || continue
			rbranch="${branch#refs/remotes/$bremote/}"
			[ "refs/remotes/$bremote/$rbranch" = "$branch" ] || continue
			v_is_remote_tgbranch rtopbases "$bremote" "$rbranch" || continue
			if contained_by "$findrev" "refs/remotes/$bremote/${rtopbases#heads/}/$rbranch"; then
				[ -z "$strict" ] || continue
				depth="$(git rev-list --count --ancestry-path \
					"refs/remotes/$bremote/${rtopbases#heads/}/$rbranch" --not "$findrev")"
				depth=$(( ${depth:-0} + 1 ))
			else
				depth=0
			fi
			remotecnt=$(( ${remotecnt:-0} + 1 ))
			branch="${branch#refs/}"
			[ ${#branch} -le $remotewide ] || remotewide=${#branch}
			[ -n "$remoteb" ] || remoteb="$(get_temp remoteb)" || exit 1
			printf '%s %s\n' "$depth" "remotes/$bremote/$rbranch" >>"$remoteb"
			;;
	esac; done
}
if [ -z "$remotes" ]; then
	process_branches <<EOT || exit 1
$(fer_branch_contains "$findrev")
EOT
else
	ferlist="$(get_temp ferlist)" || exit 1
	fer_branch_contains -a "$findrev" >"$ferlist" || exit 1
	process_branches <<EOT
$(	awk -v tb="${topbases#heads/}" -v ob="${oldbases#heads/}" <"$ferlist" '
		function join(a,b,e,_j,_r) {_r=""
			for (_j=b;_j<=e;++_j)_r=_r"/"a[_j];return substr(_r,2)}
		!/^refs\/remotes\/./ {next}
		{
			n=split(substr($0,14),c,/\//)
			if (n<2) next
			for (i=1;i<n;++i) {
				r=join(c,1,i); t=join(c,i+1,n)
				print "refs/remotes/"r"/"tb"/"t" "r
				print "refs/remotes/"r"/"ob"/"t" "r
			}
		}
	' | git cat-file $gcfbopt --batch-check='%(objectname) %(objecttype) %(rest)' |
	awk -v f="$ferlist" '
		function join(a,b,e,_j,_r) {_r=""
			for (_j=b;_j<=e;++_j)_r=_r"/"a[_j];return substr(_r,2)}
		!($2=="commit"&&$3!=""&&$1~/^[0-9a-f][0-9a-f][0-9a-f][0-9a-f]+$/){next}
		{p[$3]=1}
		END {
			while((e=(getline b<f))>0) {
				if(b!~/^refs\/remotes\/./){print b;continue}
				n=split(substr(b,14),c,/\//)
				if (n<2) continue
				d=0
				for (i=1;!d&&i<n;++i) {
					r=join(c,1,i)
					if(r in p) {d=1;t=join(c,i+1,n)
						print "refs/remotes/"r"/"t" "r}
				}
			}
			close(f)
			if(e<0)exit 1
			exit 0;
		}
	')
EOT
fi
[ -n "$localcnt$remotecnt" ] || exit 1
[ -z "$localcnt" ] || [ ${verbose:-0} -le 0 ] || make_deps_list
if [ -n "$localcnt" ]; then
	process="$localb"
	minwide=$localwide
else
	process="$remoteb"
	minwide=$remotewide
fi

sort -k1,1n "$process" |
while read -r depth ref; do
	[ -n "$mindepth" ] || mindepth="$depth"
	[ $depth -le $mindepth ] || continue
	printf '%s\n' "$ref"
done | sort -u |
while read -r oneresult; do
	headinfo=
	isann=
	[ -z "$annok" ] || [ -z "$depslist" ] || ! branch_annihilated "$oneresult" || isann=1
	[ -z "$depslist" ] || [ -n "$isann" ] ||
	headinfo="$(printf '%s\n' "$oneresult" | join -o 2.2 - "$depslist" |
		sort -u | paste -d , -s - | sed -e 's/,/, /g')"
	[ -z "$annok" ] || [ -z "$depslist" ] || [ -z "$isann" ] || headinfo=":annihilated:"
	if [ -z "$headinfo" ]; then
		printf '%s\n' "$oneresult"
	else
		printf '%-*s [%s]\n' $minwide "$oneresult" "$headinfo"
	fi
done
exit 0
