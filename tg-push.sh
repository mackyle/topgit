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
tagsopt=
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
	--follow-tags|--no-follow-tags)
		tagsopt="$arg";;
	-4|--ipv4)
		opt4="$arg";;
	-6|--ipv6)
		opt6="$arg";;
	--tgish-only|--tgish)
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
_inclfile="$(get_temp tg-push-inclfile)"

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

# find a suitable temporary remote name to use
_rmtbase="tg-push-$(date '+%Y%m%d_%H%M%S')" || :
_rmttemp="$(git config --name-only --get-regexp '^remote\.[^.][^.]*\.' |
	awk -v b="$_rmtbase" '
		{sub(/^remote\./,"");sub(/\.[^.]*$/,"");if($0!="")r[$0]=1}
		END {
			if(b=="") exit 1
			if(!r[b]) {print b;exit 0}
			x=1
			while (r[b"-"x]) ++x
			print b"-"x
			exit 0
		}
	')" || die "unable to create temporary remote name"

# attempt to allow specifying a URL as an explicit push remote
# first see if there's a pushurl or url setting for the given
# remote and if not, use it as-is thereby treating it as a URL
_rmtnm=1
_rmturl="$(git config --get "remote.$remote.pushurl" 2>/dev/null)" || :
[ -n "$_rmturl" ] ||
_rmturl="$(git config --get "remote.$remote.url" 2>/dev/null)" || :
[ -n "$_rmturl" ] || { _rmtnm=; _rmturl="$remote"; } # use it as-is

# if we have a real remote name, check to see whether or not there is
# a fetch spec configured for the remote TopGit branches and/or bases
# and if so add suitable fetch specs for both the branches and bases
# to the temporary remote in order for the opportunistic ref updates
# to take place that would have if a temporary remote was not in use.
_rmtftc=
if
	test -n "$_rmtnm" &&
	git config --get-all "remote.$remote.fetch" 2>/dev/null |
	awk -v r="$remote" -v bl="$topbases" -v br="${topbases#heads/}" '
		BEGIN {
			x=""
			sl0="refs/heads/*:refs/remotes/"r"/*"; sl1="+"sl0
			sr0="refs/"bl"/*:refs/remotes/"r"/"br"/*"; sr1="+"sr0
		}
		function exitnow(c) {x=c;exit x}
		END {if(x!="")exit x}
		$0 == sl0 || $0 == sl1 || $0 == sr0 || $0 == sr1 {exitnow(0)}
		END {exit 1}'
then
	_rmtftc=1
fi

# remove multiple occurrences of the same branch and create
# an include file with a temporary remote listing all of them
# as push specs thereby avoiding any command line length limit
# and keeping the push entirely atomic if desired no matter how
# many branches may be involved
sort -u "$_listfile" | awk -v r="$_rmttemp" -v u="$_rmturl" -v f="$_rmtftc" \
	-v fr="$remote" -v bl="$topbases" -v br="${topbases#heads/}" '
	function q(s) {	gsub(/[\\"]/,"\\\\&",s); return "\""s"\""; }
	BEGIN {
		print "[remote "q(r)"]"
		print "\turl = "q(u)
		if (f) {
			sl="+refs/heads/*:refs/remotes/"fr"/*"
			sr="+refs/"bl"/*:refs/remotes/"fr"/"br"/*"
			print "\tfetch = "q(sl)
			print "\tfetch = "q(sr)
		}
	}
	{ print "\tpush = "q($0":"$0) }
' > "$_inclfile" || die "unable to create temporary remote include file"

# be careful to make sure the shell doesn't chain to git and clean up the
# temporary file via the EXIT trap before Git's had a chance to read it
ec=0
git -c "include.path=$_inclfile" push $opt4 $opt6 $dry_run $force $atomicopt $tagsopt $signedopt "$_rmttemp" || ec=$?
tmpdir_cleanup || :
exit ${ec:-0}
