#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015,2016,2017
# All rights reserved.
# GPLv2

terse=
graphviz=
sort=
deps=
depsonly=
rdeps=
rdepsonce=1
head_from=
branches=
head=
heads=
headsindep=
headsonly=
exclude=
tgish=
withdeps=
verbose=0

## Parse options

usage()
{
	echo "Usage: ${tgname:-tg} [...] summary [-t | --list | --heads[-only] | --sort | --deps[-only] | --rdeps | --graphviz] [-i | -w] [--tgish-only] [--with[out]-deps] [--exclude branch]... [--all | branch...]" >&2
	exit 1
}

while [ -n "$1" ]; do
	arg="$1"
	case "$arg" in
	-i|-w)
		[ -z "$head_from" ] || die "-i and -w are mutually exclusive"
		head_from="$arg";;
	-t|--list|-l|--terse)
		terse=1;;
	-v|--verbose)
		verbose=1;;
	--heads|--topgit-heads)
		heads=1
		headsindep=;;
	--heads-independent)
		heads=1
		headsindep=1;;
	--heads-only)
		headsonly=1;;
	--with-deps)
		head=HEAD
		withdeps=1;;
	--without-deps|--no-with-deps)
		head=HEAD
		withdeps=0;;
	--graphviz)
		graphviz=1;;
	--sort)
		sort=1;;
	--deps)
		deps=1;;
	--tgish-only)
		tgish=1;;
	--deps-only)
		head=HEAD
		depsonly=1;;
	--rdeps)
		head=HEAD
		rdeps=1;;
	--rdeps-full)
		head=HEAD
		rdeps=1 rdepsonce=;;
	--rdeps-once)
		head=HEAD
		rdeps=1 rdepsonce=1;;
	--all)
		break;;
	--exclude=*)
		[ -n "${1#--exclude=}" ] || die "--exclude= requires a branch name"
		exclude="$exclude ${1#--exclude=}";;
	--exclude)
		shift
		[ -n "$1" -a "$1" != "--all" ] || die "--exclude requires a branch name"
		exclude="$exclude $1";;
	-*)
		usage;;
	*)
		break;;
	esac
	shift
done
[ $# -eq 0 ] || defwithdeps=1
[ -z "$exclude" ] || exclude="$exclude "
doingall=
if [ "$1" = "--all" ]; then
	[ -z "$withdeps" ] || die "mutually exclusive options given"
	[ $# -eq 1 ] || usage
	shift
	head=
	defwithdeps=
	doingall=1
fi
[ "$heads$rdeps" != "11" ] || head=
[ $# -ne 0 -o -z "$head" ] || set -- "$head"

[ "$terse$heads$headsonly$graphviz$sort$deps$depsonly" = "" ] ||
	[ "$terse$heads$headsonly$graphviz$sort$deps$depsonly$rdeps" = "1" ] ||
	[ "$terse$heads$headsonly$graphviz$sort$deps$depsonly$rdeps" = "11" -a "$heads$rdeps" = "11" ] ||
	die "mutually exclusive options given"
[ -z "$withdeps" -o -z "$rdeps$depsonly$heads$headsonly" ] ||
	die "mutually exclusive options given"

for b; do
	[ "$b" != "--all" ] || usage
	branches="$branches $(verify_topgit_branch "$b")"
done

get_branch_list()
{
	if [ -n "$branches" ]; then
		if [ -n "$1" ]; then
			printf '%s\n' $branches | sort -u
		else
			printf '%s\n' $branches
		fi
	else
		non_annihilated_branches
	fi
}

show_heads_independent()
{
	topics="$(get_temp topics)"
	get_branch_list | sed -e 's,^\(.*\)$,refs/heads/\1 \1,' |
	git cat-file --batch-check='%(objectname) %(rest)' |
	sort -u -b -k1,1 >"$topics"
	git merge-base --independent $(cut -d ' ' -f 1 <"$topics") |
	sort -u -b -k1,1 | join - "$topics" | sort -u -b -k2,2 |
	while read rev name; do
		case "$exclude" in *" $name "*) continue; esac
		printf '%s\n' "$name"
	done
}

show_heads_topgit()
{
	if [ -n "$branches" ]; then
		navigate_deps -s=-1 -1 -- "$branches" | sort
	else
		navigate_deps -s=-1
	fi |
	while read -r name; do
		case "$exclude" in *" $name "*) continue; esac
		printf '%s\n' "$name"
	done
}

show_heads()
{
    if [ -n "$headsindep" ]; then
	    show_heads_independent "$@"
    else
	    show_heads_topgit "$@"
    fi
}

if [ -n "$heads" -a -z "$rdeps" ]; then
	show_heads
	exit 0
fi

skip_ann=
show_dep() {
	case "$exclude" in *" $_dep "*) return; esac
	case " $seen_deps " in *" $_dep "*) return 0; esac
	seen_deps="${seen_deps:+$seen_deps }$_dep"
	[ -z "$tgish" -o -n "$_dep_is_tgish" ] || return 0
	[ -z "$skip_ann" ] || [ -z "$_dep_annihilated" ] && printf '%s\n' "$_dep"
	return 0
}

show_deps()
{
	no_remotes=1
	recurse_deps_exclude=
	get_branch_list | while read _b; do
		case "$exclude" in *" $_b "*) continue; esac
		case " $recurse_deps_exclude " in *" $_b "*) continue; esac
		seen_deps=
		save_skip="$skip_ann"
		_dep="$_b"; _dep_is_tgish=1; skip_ann=; show_dep; skip_ann="$save_skip"
		recurse_deps show_dep "$_b"
		recurse_deps_exclude="$recurse_deps_exclude $seen_deps"
	done
}

if [ -n "$depsonly" ]; then
	show_deps | sort -u -b -k1,1
	exit 0
fi

show_rdeps()
{
	case "$exclude" in *" $_dep "*) return; esac
	[ -z "$tgish" -o -n "$_dep_is_tgish" ] || return 0
	printf '%s %s\n' "$_depchain" "$_dep"
}

if [ -n "$rdeps" ]; then
	no_remotes=1
	showbreak=
	{
		if [ -n "$heads" ]; then
			show_heads
		else
			get_branch_list
		fi
	} | while read b; do
		case "$exclude" in *" $b "*) continue; esac
		[ -z "$showbreak" ] || echo
		showbreak=1 
		ref_exists "refs/heads/$b" || continue
		{
			echol "$b"
			recurse_preorder=1
			recurse_deps ${rdepsonce:+-o=-o=-1} show_rdeps "$b"
		} | sed -e 's/[^ ][^ ]*[ ]/  /g'
	done
	exit 0
fi

if [ -n "$deps" ]; then
	if [ -n "$branches" ]; then
		no_remotes=1
		recurse_deps_exclude="$exclude"
		recurse_deps_internal -n -t -m -e=2 -- $branches | sort -u
	else
		refslist=
		[ -z "$tg_read_only" ] || [ -z "$tg_ref_cache" ] || ! [ -s "$tg_ref_cache" ] ||
		refslist="-r=\"$tg_ref_cache\""
		tdopt=
		v_get_tdopt tdopt "$head_from"
		eval run_awk_topgit_deps "$refslist" "$tdopt" '-n -t -m="$mtblob" -x="$exclude" "refs/$topbases"'
	fi
	exit 0
fi

if [ -n "$headsonly" ]; then
	defwithdeps=
	branches="$(show_heads)"
fi

[ -n "$withdeps" ] || withdeps="$defwithdeps"
if [ -z "$doingall$terse$graphviz$sort$withdeps$branches" ]; then
	branches="$(tg info --heads 2>/dev/null | paste -d " " -s -)" || :
	[ -z "$branches" ] || withdeps=1
fi
[ "$withdeps" != "0" ] || withdeps=
if [ -n "$withdeps" ]; then
	savetgish="$tgish"
	tgish=1
	origbranches="$branches"
	branches="$(skip_ann=1; show_deps | sort -u -b -k1,1 | paste -d " " -s -)"
	tgish="$savetgish"
fi

curname="$(strip_ref "$(git symbolic-ref -q HEAD)")" || :

if [ -n "$graphviz" ]; then
	cat <<EOT
# GraphViz output; pipe to:
#   | dot -Tpng -o <output>
# or
#   | dot -Txlib

digraph G {

graph [
  rankdir = "TB"
  label="TopGit Layout\n\n\n"
  fontsize = 14
  labelloc=top
  pad = "0.5,0.5"
];

EOT
fi

if [ -n "$sort" ]; then
	tsort_input="$(get_temp tg-summary-sort)"
	exec 4>$tsort_input
	exec 5<$tsort_input
fi

## List branches

aheadlist=
processed=' '
needslist=' '
compute_ahead_list()
{
	[ -z "$branches" ] || [ -n "$withdeps" ] || return 0
	[ -n "$withdeps" ] || origbranches="$(tg summary --topgit-heads | paste -d ' ' -s -)"
	aheadfile="$(get_temp aheadlist)"
	savebr="$base_remote"
	savenr="$no_remotes"
	base_remote=
	no_remotes=1
	for onehead in $origbranches; do
		case "$exclude" in *" $onehead "*) continue; esac
		case "$processed" in *" $onehead "*) continue; esac
		processed="${processed}$onehead "
		needs_update "$onehead" || needslist="${needslist}$onehead "
	done >"$aheadfile"
	no_remotes="$savenr"
	base_remote="$savebr"
	aheadlist=" $(cut -d ' ' -f 1 <"$aheadfile" | sort -u | paste -d ' ' -s -) "
}

process_branch()
{
	missing_deps=

	current=' '
	[ "$name" != "$curname" ] || current='>'
	from=$head_from
	[ "$name" = "$curname" ] ||
		from=
	nonempty=' '
	! branch_empty "$name" $from || nonempty='0'
	remote=' '
	[ -z "$base_remote" ] || remote='l'
	! has_remote "$name" || remote='r'
	rem_update=' '
	[ "$remote" != 'r' ] || ! ref_exists "refs/remotes/$base_remote/${topbases#heads/}/$name" || {
		branch_contains "refs/$topbases/$name" "refs/remotes/$base_remote/${topbases#heads/}/$name" &&
		branch_contains "refs/heads/$name" "refs/remotes/$base_remote/$name"
	} || rem_update='R'
	[ "$remote" != 'r' -o "$rem_update" = 'R' ] || {
		branch_contains "refs/remotes/$base_remote/$name" "refs/heads/$name" 2>/dev/null
	} || rem_update='L'
	deps_update=' '
	case "$processed" in
		*" $name "*)
			case "$needslist" in *" $name "*) deps_update='D'; esac;;
		*)
			needs_update "$name" >/dev/null || deps_update='D';;
	esac
	deps_missing=' '
	[ -z "$missing_deps" ] || deps_missing='!'
	base_update=' '
	branch_contains "refs/heads/$name" "refs/$topbases/$name" || base_update='B'
	ahead=' '
	case "$aheadlist" in *" $name "*) ahead='*'; esac

	if [ "$(ref_exists_rev "refs/heads/$name")" != "$(ref_exists_rev "refs/$topbases/$name")" ]; then
		subject="$(cat_file "refs/heads/$name:.topmsg" $from | sed -n 's/^Subject: //p')"
	else
		# No commits yet
		subject="(No commits)"
	fi

	printf '%-8s %-30s\t%s\n' "$current$nonempty$remote$rem_update$deps_update$deps_missing$base_update$ahead" \
		"$name" "$subject"
}

if [ -n "$terse" ]; then
	refslist=
	[ -z "$tg_read_only" ] || [ -z "$tg_ref_cache" ] || ! [ -s "$tg_ref_cache" ] ||
	refslist="-r=\"$tg_ref_cache\""
	cmd="run_awk_topgit_msg --list"
	[ "${verbose:-0}" != "0" ] || cmd="run_awk_topgit_branches -n"
	eval "$cmd" "$refslist" '-i="$branches" -x="$exclude" "refs/$topbases"'
	exit 0
fi

[ -n "$graphviz$sort" ] || compute_ahead_list
get_branch_list |
	while read name; do
		case "$exclude" in *" $name "*) continue; esac
		if [ -n "$graphviz$sort" ]; then
			from=$head_from
			[ "$name" = "$curname" ] ||
				from=
			cat_file "refs/heads/$name:.topdeps" $from | while read -r dep || [ -n "$dep" ]; do
				dep_is_tgish=true
				ref_exists "refs/$topbases/$dep" ||
					dep_is_tgish=false
				[ -z "$tgish" ] || [ "$dep_is_tgish" = "true" ] || continue
				if ! "$dep_is_tgish" || ! branch_annihilated $dep; then
					if [ -n "$graphviz" ]; then
						echo "\"$name\" -> \"$dep\";"
						if [ "$name" = "$curname" ] || [ "$dep" = "$curname" ]; then
							echo "\"$curname\" [style=filled,fillcolor=yellow];"
						fi
					else
						echo "$name $dep" >&4
					fi
				fi
			done
		else
			process_branch
		fi
	done

if [ -n "$graphviz" ]; then
	echo '}'
fi

if [ -n "$sort" ]; then
	tsort <&5
fi
