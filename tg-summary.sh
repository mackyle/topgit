#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015,2016,2017,2018
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
	echo "Usage: ${tgname:-tg} [...] summary [-t | --list | --heads[-only] | --sort | --deps[-only] | --rdeps | --graphviz] [-i | -w] [--tgish-only] [--with[out]-(deps|related)] [--exclude branch]... [--all | branch...]" >&2
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
		verbose=$(( $verbose + 1 ));;
	-vl|-lv)
		terse=1 verbose=$(( $verbose + 1 ));;
	-vv)
		verbose=$(( $verbose + 2 ));;
	-vvl|-vlv|-lvv)
		terse=1 verbose=$(( $verbose + 2 ));;
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
	--with-related)
		head=HEAD
		withdeps=2;;
	--without-deps|--no-with-deps|--without-related|--no-with-related)
		head=HEAD
		withdeps=0;;
	--graphviz)
		graphviz=1;;
	--sort)
		sort=1;;
	--deps)
		deps=1;;
	--tgish-only|--tgish)
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
		[ -n "$1" ] && [ "$1" != "--all" ] || die "--exclude requires a branch name"
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
[ $# -ne 0 ] || [ z"$head" != z"" ] || doingall=1
if [ "$1" = "--all" ]; then
	[ -z "$withdeps" ] || die "mutually exclusive options given"
	[ $# -eq 1 ] || usage
	shift
	head=
	defwithdeps=
	doingall=1
fi
[ "$heads$rdeps" != "11" ] || head=
[ $# -ne 0 ] || [ -z "$head" ] || set -- "$head"
[ -z "$defwithdeps" ] || [ $# -ne 1 ] || { [ z"$1" != z"HEAD" ] && [ z"$1" != z"@" ]; } || defwithdeps=2

[ "$terse$heads$headsonly$graphviz$sort$deps$depsonly" = "" ] ||
	[ "$terse$heads$headsonly$graphviz$sort$deps$depsonly$rdeps" = "1" ] ||
	{ [ "$terse$heads$headsonly$graphviz$sort$deps$depsonly$rdeps" = "11" ] && [ "$heads$rdeps" = "11" ]; } ||
	die "mutually exclusive options given"
[ -z "$withdeps" ] || [ -z "$rdeps$depsonly$heads$headsonly" ] ||
	die "mutually exclusive options given"

for b; do
	[ "$b" != "--all" ] || usage
	v_verify_topgit_branch b "$b"
	branches="$branches $b"
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
	[ -z "$head_from" ] || [ -n "$with_deps_opts" ] ||
	v_get_tdopt with_deps_opts "$head_from"
	if [ -n "$branches" ]; then
		eval navigate_deps "$with_deps_opts" -s=-1 -1 -- '"$branches"' | sort
	else
		eval navigate_deps "$with_deps_opts" -s=-1
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

if [ -n "$heads" ] && [ -z "$rdeps" ]; then
	show_heads
	exit 0
fi

# if $1 is non-empty, show the dep only (including self), not the edge (no self)
show_deps()
{
	[ -z "$head_from" ] || [ -n "$with_deps_opts" ] ||
	v_get_tdopt with_deps_opts "$head_from"
	if [ -n "$branches" ]; then
		edgenum=2
		[ -z "$1" ] || edgenum=1
		no_remotes=1
		recurse_deps_exclude="$exclude"
		recurse_deps_internal -n ${tgish:+-t} -m ${1:+-s} -e=$edgenum -- $branches | sort -u
	else
		cutcmd=
		[ -z "$1" ] || cutcmd='| cut -d " " -f 2 | sort -u'
		refslist=
		[ -z "$tg_read_only" ] || [ -z "$tg_ref_cache" ] || ! [ -s "$tg_ref_cache" ] ||
		refslist="-r=\"$tg_ref_cache\""
		tdopt=
		eval run_awk_topgit_deps "$refslist" "$with_deps_opts" "${tgish:+-t}" \
			"${1:+-s}" '-n -x="$exclude" "refs/$topbases"' "$cutcmd"
	fi
}

if [ -n "$deps$depsonly$sort" ]; then
	eval show_deps $depsonly "${sort:+|tsort}"
	exit 0
fi

if [ -n "$rdeps" ]; then
	no_remotes=1
	recurse_preorder=1
	recurse_deps_exclude="$exclude"
	showbreak=
	v_get_tdopt with_deps_opts "$head_from"
	{
		if [ -n "$heads" ]; then
			show_heads
		else
			get_branch_list
		fi
	} | while read -r b; do
		case "$exclude" in *" $b "*) continue; esac
		ref_exists "refs/heads/$b" || continue
		[ -z "$showbreak" ] || echo
		showbreak=1 
		recurse_deps_internal ${tgish:+-t} -n -s ${rdepsonce:+-o=-1} "$b" |
		awk -v elided="$rdepsonce" '{
			if ($1 == "1" || NF < 5) next
			xvisits = $4
			dep = $5
			if ($6 != "") haschild[$6] = 1
			sub(/^[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+/, "")
			gsub(/ [^ ]+/, "  ")
			xtra = ""
			if (elided && xvisits > 0 && haschild[dep]) xtra="^"
			print $0 dep xtra
		}'
	done
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
	v_get_tdopt with_deps_opts "$head_from"
	[ "$withdeps" != "2" ] || branches="$(show_heads_topgit | paste -d " " -s -)"
	savetgish="$tgish"
	tgish=1
	origbranches="$branches"
	branches="$(show_deps 1 | paste -d " " -s -)"
	tgish="$savetgish"
fi

if [ -n "$terse" ]; then
	refslist=
	[ -z "$tg_read_only" ] || [ -z "$tg_ref_cache" ] || ! [ -s "$tg_ref_cache" ] ||
	refslist="-r=\"$tg_ref_cache\""
	cmd="run_awk_topgit_branches -n"
	if [ $verbose -gt 0 ]; then
		v_get_tmopt tm_opt "$head_from"
		cmd="run_awk_topgit_msg --list${tm_opt:+ $tm_opt}"
		[ $verbose -lt 2 ] || cmd="run_awk_topgit_msg -c -nokind${tm_opt:+ $tm_opt}"
	fi
	eval "$cmd" "$refslist" '-i="$branches" -x="$exclude" "refs/$topbases"'
	exit 0
fi

v_strip_ref curname "$(git symbolic-ref -q HEAD)"

if [ -n "$graphviz" ]; then
	printf '%s\n\n' \
'# GraphViz output; pipe to:
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
];'
	show_deps | while read -r name dep; do
		printf '"%s" -> "%s";\n' "$name" "$dep"
		if [ "$name" = "$curname" ] || [ "$dep" = "$curname" ]; then
			printf '"%s" [%s];\n' "$curname" "style=filled,fillcolor=yellow"
		fi
	done
	printf '%s\n' '}'
	exit 0
fi

compute_ahead_list()
{
	aheadlist=
	refslist=
	[ -z "$tg_read_only" ] || [ -z "$tg_ref_cache" ] || ! [ -s "$tg_ref_cache" ] ||
	refslist="-r=\"$tg_ref_cache\""
	msgsfile="$(get_temp msgslist)"
	v_get_tmopt tm_opt "$head_from"
	eval run_awk_topgit_msg "-nokind${tm_opt:+ $tm_opt}" "$refslist" '"refs/$topbases"' >"$msgsfile"
	needs_update_check_clear
	needs_update_check_no_same=1
	[ -z "$branches" ] || [ -n "$withdeps" ] || return 0
	v_get_tdopt with_deps_opts "$head_from"
	[ -n "$withdeps" ] || origbranches="$(navigate_deps -s=-1 | paste -d ' ' -s -)"
	for onehead in $origbranches; do
		case "$exclude" in *" $onehead "*) continue; esac
		needs_update_check $onehead
	done
	aheadlist=" $needs_update_ahead "
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
	[ "$remote" != 'r' ] || [ "$rem_update" = 'R' ] || {
		branch_contains "refs/remotes/$base_remote/$name" "refs/heads/$name" 2>/dev/null
	} || rem_update='L'
	needs_update_check "$name"
	deps_update=' '
	! vcontains needs_update_behind "$name" || deps_update='D'
	deps_missing=' '
	! vcontains needs_update_partial "$name" || deps_missing='!'
	base_update=' '
	branch_contains "refs/heads/$name" "refs/$topbases/$name" || base_update='B'
	ahead=' '
	case "$aheadlist" in *" $name "*) ahead='*'; esac

	printf '%-8s %s\n' "$current$nonempty$remote$rem_update$deps_update$deps_missing$base_update$ahead" \
		"$name"
}

awkpgm='
BEGIN {
	if (msgsfile != "") {
		while ((e = (getline msg <msgsfile)) > 0) {
			gsub(/[ \t]+/, " ", msg)
			sub(/^ /, "", msg)
			if (split(msg, scratch, " ") < 2 ||
			    scratch[1] == "" || scratch[2] == "") continue
			msg = substr(msg, length(scratch[1]) + 2)
			msgs[scratch[1]] = msg
		}
		close(msgsfile)
	}
}
{
	name = substr($0, 10)
	if (name != "" && name in msgs)
		printf "%-39s\t%s\n", $0, msgs[name]
	else
		print $0
}
'
msgsfile=
compute_ahead_list
cmd='get_branch_list | while read name; do process_branch; done'
[ -z "$msgsfile" ] || cmd="$cmd"' | awk -v msgsfile="$msgsfile" "$awkpgm"'
eval "$cmd"
