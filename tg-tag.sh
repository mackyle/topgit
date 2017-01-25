#!/bin/sh
# TopGit tag command
# Copyright (C) 2015 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# GPLv2

USAGE="\
Usage: ${tgname:-tg} [...] tag [-s | -u <key-id>] [-f] [-q] [--no-edit] [-m <msg> | -F <file>] (<tagname> | --refs) [<branch>...]
   Or: ${tgname:-tg} [...] tag (-g | --reflog) [--reflog-message | --commit-message] [--no-type] [-n <number> | -number] [<tagname>]
   Or: ${tgname:-tg} [...] tag (--clear | --delete) <tagname>
   Or: ${tgname:-tg} [...] tag --drop <tagname>@{n}"

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
anyrefok=
defbranch=HEAD
stash=
anonymous=
reflogmsg=
notype=
setreflogmsg=
quiet=0
noneok=
clear=
delete=
drop=
anonymous=

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
		quiet=$(( $quiet + 1 ))
		;;
	--none-ok)
		noneok=1
		;;
	--clear)
		clear=1
		;;
	--delete)
		delete=1
		;;
	--drop)
		drop=1
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
	--allow-any)
		anyrefok=1
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
	--stash|--stash"@{"*"}")
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
	--anonymous)
		anonymous=1
		defbranch=--all
		quiet=2
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

[ "$stash$anonymous" != "11" ] || usage 1
[ -z "$stash$anonymous" -o -n "$reflog$drop$clear$delete" ] || { outofdateok=1; force=1; defnoedit=1; }
[ -n "$noedit" ] || noedit="$defnoedit"
[ "$noedit" != "0" ] || noedit=
[ -z "$reflog" -o -z "$drop$clear$delete$signed$keyid$force$msg$msgfile$noedit$refsonly$outofdateok" ] || usage 1
[ -n "$reflog" -o -z "$setreflogmsg$notype$maxcount" ] || usage 1
[ -z "$drop$clear$delete" -o -z "$setreflogmsg$notype$maxcount$signed$keyid$force$msg$msgfile$noedit$refsonly$outofdateok" ] || usage 1
[ -z "$reflog$drop$clear$delete" -o "$reflog$drop$clear$delete" = "1" ] || usage 1
[ -z "$maxcount" ] || is_numeric "$maxcount" || die "invalid count: $maxcount"
[ -z "$maxcount" ] || [ $maxcount -gt 0 ] || die "invalid count: $maxcount"
[ -z "$msg" -o -z "$msgfile" ] || die "only one -F or -m option is allowed."
[ -z "$refsonly" ] || set -- refs..only "$@"
[ $# -gt 0 -o -z "$reflog" ] || set -- --stash
[ -n "$1" ] || { echo "Tag name required" >&2; usage 1; }
tagname="$1"
shift
[ "$tagname" != "--stash" ] || tagname=refs/tgstash
[ "$tagname" != "--anonymous" ] || tagname=TG_STASH
case "$tagname" in --stash"@{"*"}")
	strip="${tagname#--stash??}"
	strip="${strip%?}"
	tagname="refs/tgstash@{$strip}"
esac
refname="$tagname"
sfx=
case "$refname" in [!@]*"@{"*"}")
	sfx="$refname"
	refname="${refname%@*}"
	sfx="${sfx#$refname}"
esac
case "$refname" in HEAD|TG_STASH|refs/*);;*)
	if reftest="$(git rev-parse --revs-only --symbolic-full-name "$refname" -- 2>/dev/null)" &&
	   [ -n "$reftest" ]; then
		if [ -n "$reflog$drop$clear$delete" ]; then
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
refname="$refname$sfx"
reftype=tag
case "$refname" in refs/tags/*) tagname="${refname#refs/tags/}";; *) reftype=ref; tagname="$refname"; esac
logbase="$git_common_dir"
[ "$refname" != "HEAD" ] || logbase="$git_dir"
[ -z "$reflog$drop$clear$delete" -o $# -eq 0 ] || usage 1
if [ -n "$drop$clear$delete" ]; then
	if [ -n "$sfx" ]; then
		[ -z "$clear$delete" ] || die "invalid ref name ($sfx suffix not allowed): $refname"
	else
		[ -z "$drop" ] || die "invalid reflog name (@{n} suffix required): $refname"
	fi
	old="$(git rev-parse --verify --quiet --short "${refname%$sfx}" --)" || die "no such ref: ${refname%$sfx}"
	if [ -n "$delete" ]; then
		git update-ref -d "$refname" || die "git update-ref -d failed"
		printf "Deleted $reftype '%s' (was %s)\n" "$tagname" "$old"
		exit 0
	elif [ -n "$clear" ]; then
		[ -f "$logbase/logs/$refname" ] || die "no reflog found for: $refname"
		[ -s "$logbase/logs/$refname" ] || die "empty reflog found for: $refname"
		cp -p "$logbase/logs/$refname" "$logbase/logs/$refname^-+" || die "cp failed"
		sed -n '$p' <"$logbase/logs/$refname^-+" >"$logbase/logs/$refname" || die "reflog clear failed"
		rm -f "$logbase/logs/$refname^-+"
		printf "Cleared $reftype '%s' reflog to single @{0} entry\n" "$tagname"
		exit 0
	else
		old="$(git rev-parse --verify --short "$refname" --)" || exit 1
		git reflog delete --rewrite --updateref "$refname" || die "reflog drop failed"
		printf "Dropped $reftype '%s' reflog entry (was %s)\n" "$tagname" "$old"
		exit 0
	fi
fi
if [ -n "$reflog" ]; then
	[ "$refname" = "refs/tgstash" -o -n "$setreflogmsg" ] || reflogmsg=1
	git rev-parse --verify --quiet "$refname" -- >/dev/null ||
	die "no such ref: $refname"
	[ -s "$logbase/logs/$refname" ] ||
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
		sed 's/[^ ][^ ]* //' <"$logbase/logs/$refname" |
		awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--]}' |
		git cat-file --batch-check='%(objectname) %(objecttype) %(rest)' |
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
				[ "$type" = "tag" -o -n "$notype" ] ||
				extra="$hashcolor($metacolor$type$resetcolor$hashcolor)$resetcolor "
				if [ -z "$reflogmsg" -o -z "$msg" ]; then
					objmsg=
					if [ "$type" = "tag" ]; then
						objmsg="$(git cat-file tag "$obj" |
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
all=
if [ $# -eq 1 ] && [ "$1" = "--all" ]; then
	eval set -- $(git for-each-ref --shell --format="%(refname)" "refs/$topbases")
	outofdateok=1
	all=1
	if [ $# -eq 0 ]; then
		if [ "$quiet" -gt 0 -a -n "$noneok" ]; then
			exit 0
		else
			die "no TopGit branches found"
		fi
	fi
fi
ensure_ident_available
branches=
allrefs=
extrarefs=
tgbranches=
tgcount=0
othercount=0
ignore=
newlist=
while read -r obj typ ref && [ -n "$obj" -a -n "$typ" ]; do
	[ -n "$ref" -o "$typ" != "missing" ] || die "no such ref: ${obj%???}"
	case " $ignore " in *" $ref "*) continue; esac
	if [ "$typ" != "commit" -a "$typ" != "tag" ]; then
		[ -n "$anyrefok" ] || die "not a committish (is a '$typ') ref: $ref"
		[ "$quiet" -ge 2 ] || warn "ignoring non-committish (is a '$typ') ref: $ref"
		ignore="${ignore:+$ignore }$ref"
		continue
	fi
	case " $newlist " in *" $ref "*);;*)
		newlist="${newlist:+$newlist }$ref"
	esac
	if [ "$typ" = "tag" ]; then
		[ "$quiet" -ge 2 ] || warn "storing as lightweight tag instead of 'tag' object: $ref"
		ignore="${ignore:+$ignore }$ref"
	fi
done <<-EOT
	$({
		printf '%s\n' "$@" | sed 's/^\(.*\)$/\1^{} \1/'
		printf '%s\n' "$@" | sed 's/^\(.*\)$/\1 \1/'
	} |
	git cat-file --batch-check='%(objectname) %(objecttype) %(rest)' 2>/dev/null ||
	:)
EOT
set -- $newlist
for b; do
	sfn="$b"
	[ -n "$all" ] ||
	sfn="$(git rev-parse --revs-only --symbolic-full-name "$b" -- 2>/dev/null)" || :
	[ -n "$sfn" ] || {
		[ -n "$anyrefok" ] || die "no such symbolic ref name: $b"
		fullhash="$(git rev-parse --verify --quiet "$b" --)" || die "no such ref: $b"
		case " $extrarefs " in *" $b "*);;*)
			[ "$quiet" -ge 2 ] || warn "including non-symbolic ref only in parents calculation: $b"
			extrarefs="${extrarefs:+$extrarefs }$fullhash"
		esac
		continue
	}
	case "$sfn" in
		refs/"$topbases"/*)
			added=
			tgish=1
			ref_exists "refs/heads/${sfn#refs/$topbases/}" || tgish=
			[ -n "$anyrefok" ] || [ -n "$tgish" ] || [ "$quiet" -ge 2 ] ||
				warn "including TopGit base that's missing its head: $sfn"
			case " $allrefs " in *" $sfn "*);;*)
				allrefs="${allrefs:+$allrefs }$sfn"
			esac
			case " $branches " in *" ${sfn#refs/$topbases/} "*);;*)
				branches="${branches:+$branches }${sfn#refs/$topbases/}"
				added=1
			esac
			if [ -n "$tgish" ]; then
				case " $allrefs " in *" refs/heads/${sfn#refs/$topbases/} "*);;*)
					allrefs="${allrefs:+$allrefs }refs/heads/${sfn#refs/$topbases/}"
				esac
				case " $tgbranches " in *" ${sfn#refs/$topbases/} "*);;*)
					tgbranches="${tgbranches:+$tgbranches }${sfn#refs/$topbases/}"
					added=1
				esac
				[ -z "$added" ] || tgcount=$(( $tgcount + 1 ))
			else
				[ -z "$added" ] || othercount=$(( $othercount + 1 ))
			fi
			;;
		refs/heads/*)
			added=
			tgish=1
			ref_exists "refs/$topbases/${sfn#refs/heads/}" || tgish=
			[ -n "$anyrefok" ] || [ -n "$tgish" ] ||
				die "not a TopGit branch: ${sfn#refs/heads/} (use --allow-any option)"
			case " $allrefs " in *" $b "*);;*)
				allrefs="${allrefs:+$allrefs }$sfn"
			esac
			case " $branches " in *" ${sfn#refs/heads/} "*);;*)
				branches="${branches:+$branches }${sfn#refs/heads/}"
				added=1
			esac
			if [ -n "$tgish" ]; then
				case " $allrefs " in *" refs/$topbases/${sfn#refs/heads/} "*);;*)
					allrefs="${allrefs:+$allrefs }refs/$topbases/${sfn#refs/heads/}"
				esac
				case " $tgbranches " in *" ${sfn#refs/heads/} "*);;*)
					tgbranches="${tgbranches:+$tgbranches }${sfn#refs/heads/}"
					added=1
				esac
				[ -z "$added" ] || tgcount=$(( $tgcount + 1 ))
			else
				[ -z "$added" ] || othercount=$(( $othercount + 1 ))
			fi
			;;
		*)
			[ -n "$anyrefok" ] || die "refusing to include without --allow-any: $sfn"
			case " $allrefs " in *" $sfn "*);;*)
				allrefs="${allrefs:+$allrefs }$sfn"
			esac
			case " $branches " in *" ${sfn#refs/} "*);;*)
				branches="${branches:+$branches }${sfn#refs/}"
				othercount=$(( $othercount + 1 ))
			esac
			;;
	esac
done

[ -n "$force" ] ||
! git rev-parse --verify --quiet "$refname" -- >/dev/null ||
die "$reftype '$tagname' already exists"

desc="tg branch"
descpl="tg branches"
if [ $othercount -gt 0 ]; then
	if [ $tgcount -eq 0 ]; then
		desc="ref"
		descpl="refs"
	else
		descpl="$descpl and refs"
	fi
fi

get_dep() {
	case " $seen_deps " in *" $_dep "*) return 0; esac
	seen_deps="${seen_deps:+$seen_deps }$_dep"
	printf 'refs/heads/%s\n' "$_dep"
	[ -z "$_dep_is_tgish" ] || printf 'refs/%s/%s\n' "$topbases" "$_dep"
}

get_deps_internal()
{
	no_remotes=1
	recurse_deps_exclude=
	for _b; do
		case " $recurse_deps_exclude " in *" $_b "*) continue; esac
		seen_deps=
		_dep="$_b"; _dep_is_tgish=1; get_dep
		recurse_deps get_dep "$_b"
		recurse_deps_exclude="$recurse_deps_exclude $seen_deps"
	done
}

get_deps()
{
	get_deps_internal "$@" | LC_ALL=C sort -u
}

out_of_date=
if [ -n "$outofdateok" ]; then
	if [ -n "$tgbranches" ]; then
		while read -r dep && [ -n "$dep" ]; do
			case " $allrefs " in *" $dep "*);;*)
				! ref_exists "$dep" ||
				allrefs="${allrefs:+$allrefs }$dep"
			esac
		done <<-EOT
			$(get_deps $tgbranches)
		EOT
	fi
else
	for b in $tgbranches; do
		if ! needs_update "$b" >/dev/null; then
			out_of_date=1
			echo "branch not up-to-date: $b"
		fi
	done
fi
[ -z "$out_of_date" ] || die "all branches to be tagged must be up-to-date"

get_refs()
{
	printf '%s\n' '-----BEGIN TOPGIT REFS-----'
	{
		printf '%s\n' $allrefs
		[ -n "$outofdateok" ] || get_deps $tgbranches
	} | LC_ALL=C sort -u | sed 's/^\(.*\)$/\1^0 \1/' |
	git cat-file --batch-check='%(objectname) %(rest)' 2>/dev/null |
	grep -v ' missing$' || :
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
			printf '%s\n' "tag $descpl $branches"
			printf '%s\n' "$updmsg"
		else
			printf '%s\n' "tag $(( $(printf '%s' "$branches" | wc -w) )) $descpl" ""
			for b in $branches; do
				printf '%s\n' "$b"
			done
		fi
		;;
	*)
		printf '%s\n' "tag $desc $branches"
		;;
	esac | git stripspace >"$git_dir/TAG_EDITMSG"
	if [ -z "$noedit" ]; then
		{
			cat <<EOT

# Please enter a message for tg tag:
#   $tagname
# Lines starting with '#' will be ignored.
#
# $descpl to be tagged:
#
EOT
			for b in $branches; do
				printf '%s\n' "#     $b"
			done
		} >>"$git_dir/TAG_EDITMSG"
		stripcomments=1
		run_editor "$git_dir/TAG_EDITMSG" ||
		die "there was a problem with the editor '$tg_editor'"
	fi
fi
git stripspace ${stripcomments:+ --strip-comments} \
	<"$git_dir/TAG_EDITMSG" >"$git_dir/TGTAG_FINALMSG"
[ -s "$git_dir/TGTAG_FINALMSG" ] || die "no tag message?"
echo "" >>"$git_dir/TGTAG_FINALMSG"
get_refs >>"$git_dir/TGTAG_FINALMSG"

tagtarget=
case "$allrefs${extrarefs:+ $extrarefs}" in
	*" "*)
		parents="$(git merge-base --independent \
			$(printf '%s^0 ' $allrefs $extrarefs))" ||
			die "failed: git merge-base --independent"
		if [ $(printf '%s\n' "$parents" | wc -l) -eq 1 ]; then
			tagtarget="$parents"
		else
			mttree="$(git hash-object -t tree -w --stdin </dev/null)"
			tagtarget="$(printf '%s\n' "tg tag branch consolidation" "" $branches |
				git commit-tree $mttree $(printf -- '-p %s ' $parents))"
		fi
		;;
	*)
		tagtarget="$allrefs^0"
		;;
esac

init_reflog "$refname"
if [ "$reftype" = "tag" -a -n "$signed" ]; then
	[ "$quiet" -eq 0 ] || exec >/dev/null
	git tag -F "$git_dir/TGTAG_FINALMSG" ${signed:+-s} ${force:+-f} \
		${keyid:+-u} ${keyid} "$tagname" "$tagtarget"
else
	obj="$(git rev-parse --verify --quiet "$tagtarget" --)" ||
		die "invalid object name: $tagtarget"
	typ="$(git cat-file -t "$tagtarget" 2>/dev/null)" ||
		die "invalid object name: $tagtarget"
	id="$(git var GIT_COMMITTER_IDENT 2>/dev/null)" ||
		die "could not get GIT_COMMITTER_IDENT"
	newtag="$({
			printf '%s\n' "object $obj" "type $typ" "tag $tagname" \
				"tagger $id" ""
			cat "$git_dir/TGTAG_FINALMSG"
		} | git mktag)" || die "git mktag failed"
	old="$(git rev-parse --verify --short --quiet "$refname" --)" || :
	updmsg=
	case "$branches" in
	*" "*)
		if [ ${#branches} -le 100 ]; then
			updmsg="$(printf '%s\n' "tgtag: $branches")"
		else
			updmsg="$(printf '%s\n' "tgtag: $(( $(printf '%s' "$branches" | wc -w) )) ${descpl#tg }")"
		fi
		;;
	*)
		updmsg="$(printf '%s\n' "tgtag: $branches")"
		;;
	esac
	git update-ref -m "$updmsg" "$refname" "$newtag"
	[ -z "$old" -o "$quiet" -gt 0 ] || printf "Updated $reftype '%s' (was %s)\n" "$tagname" "$old"
fi
rm -f "$git_dir/TAG_EDITMSG" "$git_dir/TGTAG_FINALMSG"
