#!/bin/sh
# TopGit tag command
# Copyright (C) 2015 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# GPLv2

lf="$(printf '\n.')" && lf="${lf%?}"
tab="$(printf '\t.')" && tab="${tab%?}"
USAGE="Usage: ${tgname:-tg} [...] tag [-s | -u <key-id>] [-f] [-q] [--no-edit] [-m <msg> | -F <file>] (<tagname> | --refs) [<branch>...]"
USAGE="$USAGE$lf   Or: ${tgname:-tg} [...] tag (-g | --reflog) [--reflog-message | --commit-message] [--no-type] [-n <number> | -number] [<tagname>]"

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

signed=
keyid=
force=
msg=
msgfile=
noedit=
defnoedit=
refsonly=
maxcount=
reflog=
outofdateok=
defbranch=HEAD
stash=
reflogmsg=
notype=
setreflogmsg=
quiet=
noneok=

is_numeric()
{
	[ -n "$1" ] || return 1
	while [ -n "$1" ]; do
		case "$1" in
			[0-9]*)
				set -- "${1#?}";;
			*)
				break;;
		esac
	done
	[ -z "$1" ]
}

while [ $# -gt 0 ]; do case "$1" in
	-h|--help)
		usage
		;;
	-q|--quiet)
		quiet=1
		;;
	--none-ok)
		noneok=1
		;;
	-g|--reflog|--walk-reflogs)
		reflog=1
		;;
	--reflog-message)
		reflogmsg=1
		setreflogmsg=1
		;;
	--no-reflog-message|--commit-message)
		reflogmsg=
		setreflogmsg=1
		;;
	--no-type)
		notype=1
		;;
	-s|--sign)
		signed=1
		;;
	-u|--local-user|--local-user=*)
		case "$1" in --local-user=*)
			x="$1"
			shift
			set -- --local-user "${x#--local-user=}" "$@"
		esac
		if [ $# -lt 2 ]; then
			echo "The $1 option requires an argument" >&2
			usage 1
		fi
		shift
		keyid="$1"
		;;
	-f|--force)
		force=1
		;;
	--no-edit)
		noedit=1
		;;
	--edit)
		noedit=0
		;;
	--allow-outdated)
		outofdateok=1
		;;
	--refs|--refs-only)
		refsonly=1
		;;
	-m|--message|--message=*)
		case "$1" in --message=*)
			x="$1"
			shift
			set -- --message "${x#--message=}" "$@"
		esac
		if [ $# -lt 2 ]; then
			echo "The $1 option requires an argument" >&2
			usage 1
		fi
		shift
		msg="$1"
		;;
	-F|--file|--file=*)
		case "$1" in --file=*)
			x="$1"
			shift
			set -- --file "${x#--file=}" "$@"
		esac
		if [ $# -lt 2 ]; then
			echo "The $1 option requires an argument" >&2
			usage 1
		fi
		shift
		msgfile="$1"
		;;
	-n|--max-count|--max-count=*|-[1-9]*)
		case "$1" in --max-count=*)
			x="$1"
			shift
			set -- --max-count "${x#--max-count=}" "$@"
		esac
		case "$1" in -[1-9]*)
			x="${1#-}"
			shift
			set -- -n "$x" "$@"
		esac
		if [ $# -lt 2 ]; then
			echo "The $1 option requires an argument" >&2
			usage 1
		fi
		shift
		maxcount="$1"
		;;
	--)
		shift
		break
		;;
	--all)
		break
		;;
	--stash)
		if [ -n "$reflog" ]; then
			case "$2" in -[1-9]*)
				x1="$1"
				x2="$2"
				shift
				shift
				set -- "$x2" "$x1" "$@"
				continue
			esac
		fi
		stash=1
		defbranch=--all
		break
		;;
	-?*)
		echo "Unknown option: $1" >&2
		usage 1
		;;
	*)
		if [ -n "$reflog" ]; then
			case "$2" in -[1-9]*)
				x1="$1"
				x2="$2"
				shift
				shift
				set -- "$x2" "$x1" "$@"
				continue
			esac
		fi
		break
		;;
esac; shift; done

[ -z "$stash" -o -n "$reflog" ] || { outofdateok=1; force=1; defnoedit=1; }
[ -n "$noedit" ] || noedit="$defnoedit"
[ "$noedit" != "0" ] || noedit=
[ -z "$reflog" -o -z "$signed$keyid$force$msg$msgfile$noedit$refsonly$outofdateok" ] || usage 1
[ -n "$reflog" -o -z "$setreflogmsg$notype$maxcount" ] || usage 1
[ -z "$maxcount" ] || is_numeric "$maxcount" || die "invalid count: $maxcount"
[ -z "$maxcount" ] || [ $maxcount -gt 0 ] || die "invalid count: $maxcount"
[ -z "$msg" -o -z "$msgfile" ] || die "only one -F or -m option is allowed."
[ -z "$refsonly" ] || set -- refs..only "$@"
[ $# -gt 0 -o -z "$reflog" ] || set -- --stash
[ -n "$1" ] || { echo "Tag name required" >&2; usage 1; }
tagname="$1"
shift
[ "$tagname" != "--stash" ] || tagname=refs/tgstash
refname="$tagname"
case "$refname" in HEAD|refs/*) :;; *)
	if reftest="$(git rev-parse --revs-only --symbolic-full-name "$refname" -- 2>/dev/null)" && \
	   [ -n "$reftest" ]; then
		if [ -n "$reflog" ]; then
			refname="$reftest"
		else
			case "$reftest" in
			refs/tags/*|refs/tgstash)
				refname="$reftest"
				;;
			*)
				refname="refs/tags/$refname"
			esac
		fi
	else
		refname="refs/tags/$refname"
	fi
esac
reftype=tag
case "$refname" in refs/tags/*) tagname="${refname#refs/tags/}";; *) reftype=ref; tagname="$refname"; esac
[ -z "$reflog" -o $# -eq 0 ] || usage 1
if [ -n "$reflog" ]; then
	[ "$tagname" != "refs/tgstash" -o -n "$setreflogmsg" ] || reflogmsg=1
	git rev-parse --verify --quiet "$refname" -- >/dev/null || \
	die "no such ref: $refname"
	[ -s "$git_dir/logs/$refname" ] || \
	die "no reflog present for $reftype: $tagname"
	showref="$(git rev-parse --revs-only --abbrev-ref=strict "$refname" --)"
	hashcolor=
	resetcolor=
	if git config --get-colorbool color.tgtag; then
		metacolor="$(git config --get-color color.tgtag.meta)"
		[ -n "$metacolor" ] || metacolor="$(git config --get-color color.diff.meta "bold")"
		hashcolor="$(git config --get-color color.tgtag.commit)"
		[ -n "$hashcolor" ] || hashcolor="$(git config --get-color color.diff.commit "yellow")"
		datecolor="$(git config --get-color color.tgtag.date "bold blue")"
		timecolor="$(git config --get-color color.tgtag.time "green")"
		resetcolor="$(git config --get-color "" reset)"
	fi
	setup_strftime
	output()
	{
		sed 's/[^ ][^ ]* //' <"$git_dir/logs/$refname" | \
		awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--]}' | \
		git cat-file --batch-check='%(objectname) %(objecttype) %(rest)' | \
		{
			stashnum=-1
			lastdate=
			while read -r newrev type rest; do
				stashnum=$(( $stashnum + 1 ))
				[ "$type" != "missing" ] || continue
				IFS="$tab" read -r cmmttr msg <<-~EOT~
					$rest
					~EOT~
				ne="${cmmttr% *}"
				ne="${ne% *}"
				es="${cmmttr#$ne}"
				es="${es% *}"
				es="${es# }"
				obj="$(git rev-parse --verify --quiet --short "$newrev" --)"
				extra=
				[ "$type" = "tag" -o -n "$notype" ] || \
				extra="$hashcolor($metacolor$type$resetcolor$hashcolor)$resetcolor "
				if [ -z "$reflogmsg" -o -z "$msg" ]; then
					objmsg=
					if [ "$type" = "tag" ]; then
						objmsg="$(git cat-file tag "$obj" | \
							sed '1,/^$/d' | sed '/^$/,$d')"
					elif [ "$type" = "commit" ]; then
						objmsg="$(git log -n 1 --format='format:%s' "$obj" --)"
					fi
					[ -z "$objmsg" ] || msg="$objmsg"
				fi
				read newdate newtime <<-EOT
					$(strftime "%Y-%m-%d %H:%M:%S" "$es")
				EOT
				if [ "$lastdate" != "$newdate" ]; then
					printf '%s=== %s ===%s\n' "$datecolor" "$newdate" "$resetcolor"
					lastdate="$newdate"
				fi
				printf '%s %s %s%s@{%s}: %s\n' "$hashcolor$obj$reseutcolor" \
					"$timecolor$newtime$resetcolor" \
					"$extra" "$showref" "$stashnum" "$msg"
				if [ -n "$maxcount" ]; then
					maxcount=$(( $maxcount - 1 ))
					[ $maxcount -gt 0 ] || break
				fi
			done
		}
	}
	page output
	exit 0
fi
[ -z "$signed" -o "$reftype" = "tag" ] || die "signed tags must be under refs/tags"
[ $# -gt 0 ] || set -- $defbranch
if [ $# -eq 1 ] && [ "$1" = "--all" ]; then
	set -- $(git for-each-ref --format="%(refname)" refs/top-bases |
		sed -e 's,^refs/top-bases/,,')
	outofdateok=1
	if [ $# -eq 0 ]; then
		if [ -n "$quiet" -a -n "$noneok" ]; then
			exit 0
		else
			die "no TopGit branches found"
		fi
	fi
fi
branches=
for b; do
	bname="$(verify_topgit_branch "$b")"
	case " ${branches:-..} " in *" $bname "*) :;; *)
		branches="${branches:+$branches }$bname"
	esac
done
[ -n "$force" ] || \
! git rev-parse --verify --quiet "$refname" -- >/dev/null ||
die "$reftype '$tagname' already exists"

out_of_date=
if [ -z "$outofdateok" ]; then
	for b in $branches; do
		if ! needs_update "$b" >/dev/null; then
			out_of_date=1
			echo "branch not up-to-date: $b"
		fi
	done
fi
[ -z "$out_of_date" ] || die "all branches to be tagged must be up-to-date"

show_dep()
{
	case " $seen_deps " in *" $_dep "*) return 0; esac
	seen_deps="${seen_deps:+$seen_deps }$_dep"
	printf 'refs/heads/%s refs/heads/%s\n' "$_dep" "$_dep"
	[ -z "$_dep_is_tgish" ] || \
	printf 'refs/top-bases/%s refs/top-bases/%s\n' "$_dep" "$_dep"
}

show_deps()
{
	no_remotes=1
	recurse_deps_exclude=
	for _b; do
		seen_deps=
		_dep="$_b"; _dep_is_tgish=1; show_dep
		recurse_deps show_dep "$_b"
		recurse_deps_exclude="$recurse_deps_exclude $seen_deps"
	done
}

get_refs()
{
	printf '%s\n' '-----BEGIN TOPGIT REFS-----'
	show_deps $branches | LC_ALL=C sort -u | \
	git cat-file --batch-check='%(objectname) %(rest)' | grep -v ' missing$'
	printf '%s\n' '-----END TOPGIT REFS-----'
}

if [ -n "$refsonly" ]; then
	get_refs
	exit 0
fi

stripcomments=
if [ -n "$msgfile" ]; then
	if [ "$msgfile" = "-" ]; then
		git stripspace >"$git_dir/TAG_EDITMSG"
	else
		git stripspace <"$msgfile" >"$git_dir/TAG_EDITMSG"
	fi
elif [ -n "$msg" ]; then
	printf '%s\n' "$msg" | git stripspace >"$git_dir/TAG_EDITMSG"
else
	case "$branches" in
	*" "*)
		if [ ${#branches} -le 60 ]; then
			printf '%s\n' "tag tg branches $branches"
			printf '%s\n' "$updmsg"
		else
			printf '%s\n' "tag $(( $(printf '%s' "$branches" | wc -w) )) tg branches" ""
			for b in $branches; do
				printf '%s\n' "$b"
			done
		fi
		;;
	*)
		printf '%s\n' "tag tg branch $branches"
		;;
	esac | git stripspace >"$git_dir/TAG_EDITMSG"
	if [ -z "$noedit" ]; then
		{
			cat <<EOT

# Please enter a message for tg tag:
#   $tagname
# Lines starting with '#' will be ignored.
#
# tg branches to be tagged:
#
EOT
			for b in $branches; do
				printf '%s\n' "#     $b"
			done
		} >>"$git_dir/TAG_EDITMSG"
		stripcomments=1
		run_editor "$git_dir/TAG_EDITMSG" || \
		die "there was a problem with the editor '$tg_editor'"
	fi
fi
git stripspace ${stripcomments:+ --strip-comments} \
	<"$git_dir/TAG_EDITMSG" >"$git_dir/TGTAG_FINALMSG"
[ -s "$git_dir/TGTAG_FINALMSG" ] || die "no tag message?"
echo "" >>"$git_dir/TGTAG_FINALMSG"
get_refs >>"$git_dir/TGTAG_FINALMSG"

tagtarget=
case "$branches" in
	*" "*)
		parents="$(git merge-base --independent \
			$(printf 'refs/heads/%s^0 ' $branches))" || \
			die "failed: git merge-base --independent"
		if [ $(printf '%s\n' "$parents" | wc -l) -eq 1 ]; then
			tagtarget="$parents"
		else
			mttree="$(git hash-object -t tree -w --stdin </dev/null)"
			tagtarget="$(printf '%s\n' "tg tag branch consolidation" "" $branches | \
				git commit-tree $mttree $(printf -- '-p %s ' $parents))"
		fi
		;;
	*)
		tagtarget="refs/heads/$branches^0"
		;;
esac

if [ -n "$logrefupdates" -o "$refname" = "refs/tgstash" ]; then
	mkdir -p "$git_dir/logs/$(dirname "$refname")" 2>/dev/null || :
	{ >>"$git_dir/logs/$refname" || :; } 2>/dev/null
fi
if [ "$reftype" = "tag" -a -n "$signed" ]; then
	[ -z "$quiet" ] || exec >/dev/null
	git tag -F "$git_dir/TGTAG_FINALMSG" ${signed:+-s} ${force:+-f} \
		${keyid:+-u} ${keyid} "$tagname" "$tagtarget"
else
	obj="$(git rev-parse --verify --quiet "$tagtarget" --)" || \
		die "invalid object name: $tagtarget"
	typ="$(git cat-file -t "$tagtarget" 2>/dev/null)" || \
		die "invalid object name: $tagtarget"
	id="$(git var GIT_COMMITTER_IDENT 2>/dev/null)" || \
		die "could not get GIT_COMMITTER_IDENT"
	newtag="$({
			printf '%s\n' "object $obj" "type $typ" "tag $tagname" \
				"tagger $id" ""
			cat "$git_dir/TGTAG_FINALMSG"
		} | git mktag)" || die "git mktag failed"
	old="$(git rev-parse --verify --short --quiet "$refname" -- || :)"
	updmsg=
	case "$branches" in
	*" "*)
		if [ ${#branches} -le 100 ]; then
			updmsg="$(printf '%s\n' "tgtag: $branches")"
		else
			updmsg="$(printf '%s\n' "tgtag: $(( $(printf '%s' "$branches" | wc -w) )) branches")"
		fi
		;;
	*)
		updmsg="$(printf '%s\n' "tgtag: $branches")"
		;;
	esac
	git update-ref -m "$updmsg" "$refname" "$newtag"
	[ -z "$old" -o -n "$quiet" ] || printf "Updated $reftype '%s' (was %s)\n" "$tagname" "$old"
fi
rm -f "$git_dir/TAG_EDITMSG" "$git_dir/TGTAG_FINALMSG"