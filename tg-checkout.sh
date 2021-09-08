#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) 2013 Per Cederqvist <ceder@lysator.liu.se>
# Copyright (C) 2015,2017,2018,2021 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved
# GPLv2

## Parse options

USAGE="\
Usage: ${tgname:-tg} [...] checkout [<opt>...] [-b <branch>] (next | prev) [<steps>]
   Or: ${tgname:-tg} [...] checkout [<opt>...] (next | prev) -a
   Or: ${tgname:-tg} [...] checkout [<opt>...] [goto] [--] <pattern> | --series[=<head>]
Options:
    --iow               pass '--ignore-other-worktrees' to git >= v2.5.0
    --force / -f        pass '--force' option to git
    --merge / -m        pass '--merge' option to git
    --quiet / -q        pass '--quiet' option to git
    --branch <branch>   start at branch <branch> instead of HEAD
    -b <branch>         alias for --branch <branch>
    --all / -a          step as many times as possible"

usage()
{
	[ -z "$2" ] || printf '%s\n' "$2" >&2
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

# Parse options

branch=		# -b value
iowoptval=	# "" or "$iowopt"
forceval=	# "" or "-f"
mergeval=	# "" or "-m"
quietval=	# "" or "-q"
dashdash=	# "" or "1" if [goto] "--" [--series[=<head>]] seen

while [ $# -gt 0 ]; do case "$1" in
	-h|--help)
		usage
		;;
	-f|--force)
		forceval="-f"
		;;
	-m|--merge)
		mergeval="-m"
		;;
	-q|--quiet)
		quietval="-q"
		;;
	--ignore-other-worktrees|--iow)
		iowoptval="$iowopt"
		;;
	--branch=*)
		branch="${1#--branch=}"
		[ -n "$branch" ] || usage 1 "--branch= requires a branch name"
		;;
	--branch|-b)
		[ $# -ge 2 ] || usage 1 "$1 requires an argument"
		branch="$2"
		[ -n "$branch" ] || usage 1 "$1 requires a branch name"
		shift
		;;
	--series|--series=*)
		dashdash=1
		break
		;;
	--|goto)
		[ "$1" != "goto" ] || [ "$2" != "--" ] || shift
		shift
		dashdash=1
		break
		;;
	-[0-9]*)
		break
		;;
	-?*)
		usage 1 "Unknown option: $1"
		;;
	*)
		break
		;;
esac; shift; done
[ $# -ne 0 ] || [ -n "$dashdash" ] || {
	# deprecated "next" alias
	warn "support for \"tg checkout\" with no argument will soon be removed"
	warn "please switch to equivalent \"tg checkout +\" to avoid breakage"
	set -- "+"
}
[ $# -gt 0 ] || usage 1
pinstep=
[ -n "$dashdash" ] || {
	case "$1" in +[0-9]*|-[0-9]*)
		arg="$1"
		shift
		set -- "${arg%%[0-9]*}" "${arg#?}" "$@"
		pinstep=1
	esac
	case "$1" in
		+|n|next|push|child)			shift;;
		-|p|prev|previous|pop|parent|..)	reverse=1; shift;;
		-*)					usage 1;;
		*)					dashdash=1;;
	esac
}

choices="$(get_temp choices)"
desc=

if [ -n "$dashdash" ]; then
	[ $# -eq 1 ] || usage 1 "goto mode requires exactly one pattern"
	pattern="$1"
	[ -n "$pattern" ] || usage 1 "goto mode requires a non-empty pattern"
	case "$pattern" in
		--series|--series=*)
			tg --no-pager info "$pattern" "${branch:-HEAD}" >"$choices" || exit
			desc=1
			;;
		*)
			[ -z "$branch" ] || usage 1 "--branch not allowed in goto <pattern> mode"
			tg --no-pager summary --list | grep -e "$pattern" >"$choices" || :
			no_branch_found="No topic branch matches grep pattern '$pattern'"
			;;
	esac
else
	[ $# -gt 0 ] || set -- "1"
	[ $# -eq 1 ] || usage 1 "next/previous permits no more than one argument"
	case "$1" in
		-a|--all)
			[ -z "$branch" ] || usage 1 "--branch not allowed in --all mode"
			navigate_deps -t -s=-1 ${reverse:+-r} >"$choices"
			no_branch_found="No TopGit branches found at all!"
			;;
		[1-9]*)
			[ "$1" = "${1%%[!0-9]*}" ] || usage 1 "invalid next/previous step count"
			v_verify_topgit_branch branch "${branch:-HEAD}"
			navigate_deps -t -s="$1" ${reverse:+-r} ${pinstep:+-k} "$branch" >"$choices" || exit
			pl="s" dir="next"
			[ "$1" != 1 ] || pl=
			[ -z "$reverse" ] || dir="previous"
			no_branch_found="No $dir TopGit branch(es) found $1 step$pl away"
			;;
		*)
			usage 1 "invalid next/previous movement; must be --all or positive number"
			;;
	esac
fi

cnt=$(( $(wc -l <"$choices") ))
[ $cnt -gt 0 ] || die "$no_branch_found"

if [ $cnt -eq 1 ]; then
	read -r choice <"$choices" || :
	choice="${choice%%[ $tab]*}"
	[ -n "$choice" ] || die "$no_branch_found"
else
	echo "Please select one of the following topic branches:"
	awk -v "desc=$desc" <"$choices" '
	BEGIN { colcount = 0 }
	function cols() {
		if (colcount) return colcount
		sizer = "exec stty size 0>&2 2>/dev/null"
		info = ""
		sizer | getline info
		close(sizer)
		colcount = 0
		if (split(info, nums, " ") >= 2 && nums[2] ~ /^[1-9][0-9]*$/)
			colcount = 0 + nums[2]
		if (!colcount) colcount = 80
		return colcount
	}
	{
		if ($0 ~ /^[* ] /) {
			mark = substr($0, 1, 2)
			names = substr($0, 3)
		} else {
			mark = ""
			names = $0
		}
		cnt = split(names, name, " ")
		if (!cnt) next
		annotation = ""
		if (cnt > 1) {
			if (desc) {
				annotation = names
				sub(/^[ \t]+/, "", annotation)
				sub(/^[^ \t]+[ \t]+/, "", annotation)
				sub(/[ \t]+$/, "", annotation)
				if (annotation != "") annotation = " " annotation
			} else {
				for (i = 2; i <= cnt; ++i) {
					annotation = annotation ", " name[i]
				}
				annotation = " [" substr(annotation, 3) "]"
			}
		}
		if (desc)
			line = sprintf("%-39s%s", sprintf("%6d  %s%s", NR, mark, name[1]), annotation)
		else
			line = sprintf("%6d  %s%s%s", NR, mark, name[1], annotation)
		printf "%.*s\n", cols() - 1, line
	}'
	printf '%s' "Input the number: "
	read -r n
	[ -n "$n" ] && [ "$n" = "${n%%[!0-9]*}" ] || die "Bad input"
	[ $n -ge 1 ] && [ $n -le $cnt ] || die "Input out of range"
	choice="$(sed -n ${n}p <"$choices")" || :
	case "$choice" in "* "*|"  "*) choice="${choice#??}"; esac
	choice="${choice%%[ $tab]*}"
	[ -n "$choice" ] || die "Bad input"
fi
git checkout $quietval $iowoptval $mergeval $forceval "$choice" --
