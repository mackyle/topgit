#!/bin/sh
# TopGit tag command
# Copyright (C) 2015,2017,2018 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# GPLv2

USAGE="\
Usage: ${tgname:-tg} [...] tag [-s | -u <key-id>] [-f] [-q] [--no-edit] [-m <msg> | -F <file>] [--tree <treeish>] (<tagname> | --refs) [<branch>...]
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
treeish=

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
	--tree|--tree=*)
		case "$1" in --tree=*)
			x="$1"
			shift
			set -- --tree "${x#--tree=}" "$@"
		esac
		if [ $# -lt 2 ]; then
			echo "The $1 option requires an argument" >&2
			usage 1
		fi
		shift
		treeish="$(git rev-parse --quiet --verify "$1^{tree}" --)" || {
			echo "Not a valid treeish: $1" >&2
			exit 1
		}
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
[ -z "$stash$anonymous" ] || [ -n "$reflog$drop$clear$delete" ] || { outofdateok=1; force=1; defnoedit=1; }
[ -n "$noedit" ] || noedit="$defnoedit"
[ "$noedit" != "0" ] || noedit=
[ -z "$reflog" ] || [ -z "$drop$clear$delete$signed$keyid$force$msg$msgfile$noedit$treeish$refsonly$outofdateok" ] || usage 1
[ -n "$reflog" ] || [ -z "$setreflogmsg$notype$maxcount" ] || usage 1
[ -z "$drop$clear$delete" ] || [ -z "$setreflogmsg$notype$maxcount$signed$keyid$force$msg$msgfile$noedit$treeish$refsonly$outofdateok" ] || usage 1
[ -z "$reflog$drop$clear$delete" ] || [ "$reflog$drop$clear$delete" = "1" ] || usage 1
[ -z "$maxcount" ] || is_numeric "$maxcount" || die "invalid count: $maxcount"
[ -z "$maxcount" ] || [ $maxcount -gt 0 ] || die "invalid count: $maxcount"
[ -z "$msg" ] || [ -z "$msgfile" ] || die "only one -F or -m option is allowed."
[ -z "$refsonly" ] || set -- refs..only "$@"
[ $# -gt 0 ] || [ -z "$reflog" ] || set -- --stash
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
sfxis0=
case "$refname" in [!@]*"@{"*"}")
	_pfx="@{"
	_refonly="${refname%%"$_pfx"*}"
	sfx="${refname#"$_refonly"}"
	refname="$_refonly"
	_numonly="${sfx#??}"
	_numonly="${_numonly%?}"
	[ "${_numonly#[0-9]}" != "$_numonly" ] && [ "${_numonly#*[!0-9]}" = "$_numonly" ] || die "invalid suffix: \"$sfx\""
	if [ "${_numonly#*[!0]}" = "$_numonly" ]; then
		# transform @{0000000} etc. into @{0}
		sfx="@{0}"
		sfxis0=1
	else
		# remove any leading zeros
		_ld0="${_numonly%%[!0]*}"
		[ -z "$_ld0" ] || _numonly="${_numonly#$_ld0}"
		sfx="@{$_numonly}"
	fi
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
[ -z "$reflog$drop$clear$delete" ] || [ $# -eq 0 ] || usage 1
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
		[ -z "$sfxis0" ] || ! git symbolic-ref -q "${refname%$sfx}" -- >/dev/null 2>&1 || sfxis0=
		git reflog delete --rewrite ${sfxis0:+--updateref} "$refname" || die "reflog drop failed"
		if [ -n "$sfxis0" ]; then
			# check if we need to clean up
			check="$(git rev-parse --verify --quiet "${refname%$sfx}" --)" || :
			[ "${check#*[!0]}" != "$check" ] || check= # all 0's or empty is bad
			# Git versions prior to 2.4.0 might need some clean up
			[ -n "$check" ] || git update-ref -d "${refname%$sfx}" >/dev/null 2>&1 || :
		fi
		printf "Dropped $reftype '%s' reflog entry (was %s)\n" "$tagname" "$old"
		exit 0
	fi
fi
if [ -n "$reflog" ]; then
	[ "$refname" = "refs/tgstash" ] || [ -n "$setreflogmsg" ] || reflogmsg=1
	git rev-parse --verify --quiet "$refname" -- >/dev/null ||
	die "no such ref: $refname"
	[ -s "$logbase/logs/$refname" ] ||
	die "no reflog present for $reftype: $tagname"
	showref="$refname"
	[ "$refname" = "HEAD" ] || showref="$(git rev-parse --revs-only --abbrev-ref=strict "$refname" --)"
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
				[ "$type" = "tag" ] || [ -n "$notype" ] ||
				extra="$hashcolor($metacolor$type$resetcolor$hashcolor)$resetcolor "
				if [ -z "$reflogmsg" ] || [ -z "$msg" ]; then
					objmsg=
					if [ "$type" = "tag" ]; then
						objmsg="$(git cat-file tag "$obj" |
							sed '1,/^$/d' | sed '/^$/,$d')"
					elif [ "$type" = "commit" ]; then
						objmsg="$(git --no-pager log -n 1 --format='format:%s' "$obj" --)"
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
[ -z "$signed" ] || [ "$reftype" = "tag" ] || die "signed tags must be under refs/tags"
[ $# -gt 0 ] || set -- $defbranch
all=
if [ $# -eq 1 ] && [ "$1" = "--all" ]; then
	eval set -- $(git for-each-ref --shell --format="%(refname)" "refs/$topbases")
	outofdateok=1
	all=1
	if [ $# -eq 0 ]; then
		if [ "$quiet" -gt 0 ] && [ -n "$noneok" ]; then
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
firstprnt=
for arg in "$@"; do
	case "$arg" in "~"?*)
		[ -z "$firstprnt" ] || die "only one first parent may be specified with ~"
		firstprnt="$(git rev-parse --verify --quiet "${arg#?}^0" -- 2>/dev/null)" && [ -n "$firstprnt" ] ||
			die "not a commit-ish: ${arg#?}"
	esac
done
while read -r obj typ ref && [ -n "$obj" ] && [ -n "$typ" ]; do
	[ -n "$ref" ] || [ "$typ" != "missing" ] || die "no such ref: ${obj%???}"
	case " $ignore " in *" $ref "*) continue; esac
	if [ "$typ" != "commit" ] && [ "$typ" != "tag" ]; then
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
		printf '%s\n' "$@" | sed 's/^~//; s/^\(.*\)$/\1^{} \1/'
		printf '%s\n' "$@" | sed 's/^~//; s/^\(.*\)$/\1 \1/'
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
	get_deps_internal "$@" | sort -u
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
	} | sort -u | sed 's/^\(.*\)$/\1^0 \1/' |
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

v_count_args() { eval "$1="'$(( $# - 1 ))'; }

tagtarget=
case "$allrefs${extrarefs:+ $extrarefs}" in
	*" "*)
		parents="$(git merge-base --independent \
			$(printf '%s^0 ' $allrefs $extrarefs))" ||
			die "failed: git merge-base --independent"
		;;
	*)
		if [ -n "$firstprnt" ]; then
			parents="$(git rev-parse --quiet --verify "$allrefs^0" --)" ||
				die "failed: git rev-parse $allrefs^0"
		else
			parents="$allrefs^0"
		fi
		;;
esac
if [ -n "$firstprnt" ]; then
	oldparents="$parents"
	parents="$firstprnt"
	for acmt in $oldparents; do
		[ "$acmt" = "$firstprnt" ] || parents="$parents $acmt"
	done
	unset oldparents
fi
v_count_args pcnt $parents
if [ $pcnt -eq 1 ]; then
	tagtarget="$parents"
	[ -z "$treeish" ] ||
	[ "$(git rev-parse --quiet --verify "$tagtarget^{tree}" --)" = "$treeish" ] ||
	tagtarget=
fi
if [ -z "$tagtarget" ]; then
	tagtree="${treeish:-$firstprnt}"
	[ -n "$tagtree" ] || tagtree="$(git hash-object -t tree -w --stdin </dev/null)"
	tagtarget="$(printf '%s\n' "tg tag branch consolidation" "" $branches |
		git commit-tree $tagtree^{tree} $(printf -- '-p %s ' $parents))"
fi

init_reflog "$refname"
if [ "$reftype" = "tag" ] && [ -n "$signed" ]; then
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
	[ -z "$old" ] || [ "$quiet" -gt 0 ] || printf "Updated $reftype '%s' (was %s)\n" "$tagname" "$old"
fi
rm -f "$git_dir/TAG_EDITMSG" "$git_dir/TGTAG_FINALMSG"
